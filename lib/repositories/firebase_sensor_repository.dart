import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:monu/config/iot_config.dart';
import 'package:monu/models/device_snapshot.dart';
import 'package:monu/repositories/sensor_repository.dart';

/// Membaca data dari Firebase Realtime Database lewat REST
/// (app mengambil data tiap beberapa detik). Cukup butuh URL database,
/// tidak perlu pengaturan FlutterFire.
///
/// Format data di database:
///   devices/{deviceId}:
///     name, updatedAt (milidetik),
///     sensors: { temperature, humidity, soilMoistureRaw,
///                soilMoisturePercent (opsional), mq2Raw }
///   history/{deviceId}/{id-otomatis}:
///     timestamp, temperature, humidity, soilMoistureRaw, mq2Raw
/// Sensor yang gagal dibaca: field dikosongkan/tidak dikirim.
class FirebaseSensorRepository implements SensorRepository {
  FirebaseSensorRepository({
    required String databaseUrl,
    required this.deviceId,
  })  : _base = databaseUrl,
        _client = http.Client();

  final String deviceId;
  final String _base;
  final http.Client _client;

  Timer? _timer;
  bool _fetching = false;

  late final StreamController<DeviceSnapshot?> _controller =
      StreamController<DeviceSnapshot?>(onListen: _start, onCancel: _stop);

  /// Merapikan URL. Mengembalikan null jika URL belum benar.
  static String? normalizeUrl(String input) {
    String url = input.trim();
    if (!url.startsWith('https://')) return null;
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url.length > 'https://'.length ? url : null;
  }

  @override
  String get modeLabel => 'Mode Asli';

  @override
  bool get supportsHistory => true;

  @override
  Stream<DeviceSnapshot?> watchLatest() => _controller.stream;

  void _start() {
    _poll();
    _timer = Timer.periodic(IotConfig.pollInterval, (_) => _poll());
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> refresh() => _poll();

  Future<void> _poll() async {
    if (_fetching || _controller.isClosed) return;
    _fetching = true;
    try {
      final DeviceSnapshot? snapshot = await _fetchLatest();
      if (!_controller.isClosed) _controller.add(snapshot);
    } catch (error) {
      if (!_controller.isClosed) _controller.addError(error);
    } finally {
      _fetching = false;
    }
  }

  Future<DeviceSnapshot?> _fetchLatest() async {
    final Uri uri =
        Uri.parse('$_base/${IotConfig.devicesPath}/$deviceId.json');
    final http.Response res =
        await _client.get(uri).timeout(const Duration(seconds: 8));
    _check(res);

    final dynamic data = jsonDecode(res.body);
    if (data == null) return null;
    if (data is! Map) {
      throw const RepositoryException(
        'Format data di database tidak sesuai. Cek struktur devices/{id}.',
      );
    }
    return DeviceSnapshot.fromMap(deviceId, data);
  }

  @override
  Future<List<DeviceSnapshot>> loadHistory(Duration range) async {
    final int limit = range <= const Duration(hours: 1)
        ? 120
        : (range <= const Duration(hours: 24) ? 1500 : 3000);

    final Uri uri = Uri.parse(
      '$_base/${IotConfig.historyPath}/$deviceId.json',
    ).replace(
      queryParameters: <String, String>{
        'orderBy': '"\$key"',
        'limitToLast': '$limit',
      },
    );

    final http.Response res =
        await _client.get(uri).timeout(const Duration(seconds: 12));
    _check(res);

    final dynamic data = jsonDecode(res.body);
    if (data is! Map) return <DeviceSnapshot>[];

    final DateTime cutoff = DateTime.now().subtract(range);
    final List<DeviceSnapshot> list = <DeviceSnapshot>[];
    for (final dynamic item in data.values) {
      if (item is Map) {
        final DeviceSnapshot s = DeviceSnapshot.fromMap(deviceId, item);
        if (s.timestamp.isAfter(cutoff)) list.add(s);
      }
    }
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }

  void _check(http.Response res) {
    if (res.statusCode == 200) return;
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw const RepositoryException(
        'Akses ditolak. Periksa "Rules" Realtime Database (izinkan baca).',
      );
    }
    if (res.statusCode == 404) {
      throw const RepositoryException(
        'Database tidak ditemukan. Periksa URL database.',
      );
    }
    throw RepositoryException('Database membalas kode ${res.statusCode}.');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _client.close();
    if (!_controller.isClosed) _controller.close();
  }
}