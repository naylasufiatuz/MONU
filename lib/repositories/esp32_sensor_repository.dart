import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:monu/config/iot_config.dart';
import 'package:monu/models/device_snapshot.dart';
import 'package:monu/repositories/sensor_repository.dart';

/// Repository untuk membaca data sensor langsung dari ESP32 via HTTP REST API.
/// Mengambil data secara periodik dari endpoint: `http://<IP_ESP32>/api/status`
class Esp32SensorRepository implements SensorRepository {
  Esp32SensorRepository({
    required this.ipAddress,
    required this.deviceId,
    this.pollInterval = IotConfig.esp32PollInterval,
  }) : _client = http.Client();

  final String ipAddress;
  final String deviceId;
  final Duration pollInterval;
  final http.Client _client;

  Timer? _timer;
  bool _fetching = false;
  final List<DeviceSnapshot> _history = <DeviceSnapshot>[];

  late final StreamController<DeviceSnapshot?> _controller =
      StreamController<DeviceSnapshot?>(onListen: _start, onCancel: _stop);

  @override
  String get modeLabel => 'ESP32 Langsung ($ipAddress)';

  @override
  bool get supportsHistory => true;

  @override
  Stream<DeviceSnapshot?> watchLatest() => _controller.stream;

  void _start() {
    _poll();
    _timer = Timer.periodic(pollInterval, (_) => _poll());
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> refresh() => _poll();

  Future<void> _poll() async {
    // Mencegah request berulang jika request sebelumnya masih berjalan
    if (_fetching || _controller.isClosed) return;
    _fetching = true;
    try {
      final DeviceSnapshot? snapshot = await _fetchLatest();
      if (!_controller.isClosed) {
        if (snapshot != null) {
          _history.add(snapshot);
          // Batasi riwayat di memori lokal agar hemat RAM
          if (_history.length > 300) {
            _history.removeAt(0);
          }
        }
        _controller.add(snapshot);
      }
    } catch (error) {
      if (!_controller.isClosed) {
        _controller.addError(error);
      }
    } finally {
      _fetching = false;
    }
  }

  Future<DeviceSnapshot?> _fetchLatest() async {
    final String clean = cleanIp(ipAddress);
    if (clean.isEmpty) {
      throw const RepositoryException(
        'IP Address ESP32 belum diisi. Silakan masukkan IP di menu Koneksi Perangkat.',
      );
    }

    final Uri uri = Uri.parse('http://$clean/api/status');
    final http.Response res =
        await _client.get(uri).timeout(const Duration(seconds: 4));

    if (res.statusCode != 200) {
      throw RepositoryException(
        'ESP32 merespons dengan kode status ${res.statusCode}',
      );
    }

    final dynamic data = jsonDecode(res.body);
    if (data == null || data is! Map) {
      throw const RepositoryException(
        'Format respons ESP32 tidak valid. Diharapkan objek JSON.',
      );
    }

    return DeviceSnapshot.fromEsp32Map(deviceId, data);
  }

  @override
  Future<List<DeviceSnapshot>> loadHistory(Duration range) async {
    final DateTime cutoff = DateTime.now().subtract(range);
    final List<DeviceSnapshot> list = _history
        .where((s) => s.timestamp.isAfter(cutoff))
        .toList();
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _client.close();
    if (!_controller.isClosed) {
      _controller.close();
    }
  }

  /// Membersihkan input IP dari skema atau slash
  static String cleanIp(String input) {
    String s = input.trim();
    if (s.startsWith('http://')) {
      s = s.substring(7);
    } else if (s.startsWith('https://')) {
      s = s.substring(8);
    }
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }
}
