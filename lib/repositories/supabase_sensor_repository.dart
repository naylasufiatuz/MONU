import 'dart:async';

import 'package:monu/models/device_snapshot.dart';
import 'package:monu/repositories/sensor_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Membaca data sensor dan mendengarkan pembaruan realtime dari Supabase PostgreSQL.
class SupabaseSensorRepository implements SensorRepository {
  SupabaseSensorRepository({
    required this.deviceId,
    SupabaseClient? client,
  }) : _client = client ?? Supabase.instance.client;

  final String deviceId;
  final SupabaseClient _client;

  StreamSubscription<List<Map<String, dynamic>>>? _streamSub;
  Timer? _pollingTimer;
  bool _fetching = false;

  late final StreamController<DeviceSnapshot?> _controller =
      StreamController<DeviceSnapshot?>(onListen: _start, onCancel: _stop);

  @override
  String get modeLabel => 'Supabase (PostgreSQL)';

  @override
  bool get supportsHistory => true;

  @override
  Stream<DeviceSnapshot?> watchLatest() => _controller.stream;

  void _start() {
    _fetchLatestData();

    // Stream Realtime dari tabel sensor_readings
    try {
      _streamSub = _client
          .from('sensor_readings')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .limit(1)
          .listen(
        (data) {
          if (data.isNotEmpty) {
            final snapshot = _mapToSnapshot(data.first);
            if (!_controller.isClosed) _controller.add(snapshot);
          }
        },
        onError: (err) {
          if (!_controller.isClosed) {
            _controller.addError(err);
          }
          _startPollingFallback();
        },
      );
    } catch (e) {
      if (!_controller.isClosed) {
        _controller.addError(RepositoryException(
          'Supabase belum dikonfigurasi atau tabel sensor_readings belum dibuat. '
          'Jalankan SQL di supabase_schema.sql terlebih dahulu. Error: $e',
        ));
      }
      _startPollingFallback();
    }
  }

  void _startPollingFallback() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _fetchLatestData(),
    );
  }

  void _stop() {
    _streamSub?.cancel();
    _streamSub = null;
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  @override
  Future<void> refresh() => _fetchLatestData();

  Future<void> _fetchLatestData() async {
    if (_fetching || _controller.isClosed) return;
    _fetching = true;
    try {
      final List<dynamic> rows = await _client
          .from('sensor_readings')
          .select()
          .eq('device_id', deviceId)
          .order('created_at', ascending: false)
          .limit(1);

      if (rows.isNotEmpty) {
        final DeviceSnapshot snap =
            _mapToSnapshot(rows.first as Map<String, dynamic>);
        if (!_controller.isClosed) _controller.add(snap);
      } else {
        // Tabel ada tapi belum ada data dari device ini
        if (!_controller.isClosed) _controller.add(null);
      }
    } catch (e) {
      if (!_controller.isClosed) {
        _controller.addError(RepositoryException(
          'Gagal membaca data dari Supabase. '
          'Pastikan tabel sensor_readings sudah dibuat dan Anon Key benar. '
          'Error: $e',
        ));
      }
    } finally {
      _fetching = false;
    }
  }

  DeviceSnapshot _mapToSnapshot(Map<dynamic, dynamic> map) {
    final double? temp = _toDouble(map['temperature']);
    final double? hum = _toDouble(map['humidity']);
    final double? soilRaw =
        _toDouble(map['soil_moisture_raw'] ?? map['soilMoistureRaw']);
    final double? mq2Raw = _toDouble(map['mq2_raw'] ?? map['mq2Raw']);
    final double? thermo = _toDouble(map['thermocouple']);

    double? soilPercent = _toDouble(
        map['soil_moisture_percent'] ?? map['soilMoisturePercent']);
    if (soilPercent == null && soilRaw != null) {
      soilPercent =
          ((3300 - soilRaw) / (3300 - 1300) * 100).clamp(0, 100).toDouble();
      soilPercent = double.parse(soilPercent.toStringAsFixed(0));
    }

    final DateTime ts = map['created_at'] != null
        ? DateTime.tryParse(map['created_at'].toString())?.toLocal() ??
            DateTime.now()
        : DateTime.now();

    final bool relay = map['relay_active'] == true ||
        map['relay'] == true ||
        map['pump_active'] == true;

    return DeviceSnapshot(
      deviceId: (map['device_id'] ?? deviceId).toString(),
      deviceName: (map['device_name'] ?? 'ESP32 MONU Node').toString(),
      timestamp: ts,
      values: {
        'temperature': temp,
        'humidity': hum,
        'soilMoistureRaw': soilRaw,
        'mq2Raw': mq2Raw,
        'thermocouple': thermo,
      },
      soilMoisturePercent: soilPercent,
      relayActive: relay,
      pumpActive: relay,
      isWifiConnected: map['wifi_connected'] != false,
      esp32Ip: map['ip_address']?.toString(),
      deviceStatus: (map['device_status'] ?? 'online').toString(),
    );
  }

  @override
  Future<List<DeviceSnapshot>> loadHistory(Duration range) async {
    final DateTime cutoff = DateTime.now().subtract(range);
    try {
      final List<dynamic> rows = await _client
          .from('sensor_readings')
          .select()
          .eq('device_id', deviceId)
          .gte('created_at', cutoff.toIso8601String())
          .order('created_at', ascending: true)
          .limit(2000);

      return rows
          .whereType<Map<String, dynamic>>()
          .map(_mapToSnapshot)
          .toList();
    } catch (_) {
      return <DeviceSnapshot>[];
    }
  }

  static double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.'));
    return null;
  }

  @override
  void dispose() {
    _stop();
    if (!_controller.isClosed) _controller.close();
  }
}
