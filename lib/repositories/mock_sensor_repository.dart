import 'dart:async';
import 'dart:math' as math;

import 'package:monu/config/iot_config.dart';
import 'package:monu/config/sensor_config.dart';
import 'package:monu/models/device_snapshot.dart';
import 'package:monu/models/sensor_spec.dart';
import 'package:monu/repositories/sensor_repository.dart';

/// Skenario uji di Mode Demo (sesuai rencana pengujian PRD).
enum DemoScenario { normal, warning, check, sensorFail, offline }

extension DemoScenarioX on DemoScenario {
  String get label => switch (this) {
        DemoScenario.normal => 'Normal',
        DemoScenario.warning => 'Waspada',
        DemoScenario.check => 'Perlu Pemeriksaan',
        DemoScenario.sensorFail => 'Sensor gagal',
        DemoScenario.offline => 'Putus koneksi',
      };
}

/// Data palsu yang berubah-ubah otomatis. Ini DEFAULT supaya app langsung
/// jalan tanpa alat.
class MockSensorRepository implements SensorRepository {
  MockSensorRepository({required this.deviceId});

  final String deviceId;
  final math.Random _random = math.Random();

  DemoScenario scenario = DemoScenario.normal;

  Map<String, double>? _current;
  Timer? _timer;

  late final StreamController<DeviceSnapshot?> _controller =
      StreamController<DeviceSnapshot?>(onListen: _start, onCancel: _stop);

  @override
  String get modeLabel => 'Mode Demo';

  @override
  bool get supportsHistory => true;

  @override
  Stream<DeviceSnapshot?> watchLatest() => _controller.stream;

  void _start() {
    Future<void>.microtask(_emit);
    _timer = Timer.periodic(IotConfig.mockInterval, (_) => _emit());
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> refresh() async => _emit();

  void _emit() {
    if (_controller.isClosed || !_controller.hasListener) return;
    // Skenario "putus koneksi": perangkat berhenti mengirim data.
    if (scenario == DemoScenario.offline) return;

    final Map<String, double> current = _current ??= _baseNow();
    final Map<String, double> target = _targetFor(scenario);

    for (final SensorSpec spec in SensorConfig.all) {
      final double now = current[spec.id]!;
      final double goal = target[spec.id] ?? now;
      final double noise =
          (_random.nextDouble() - 0.5) * 2 * _noiseFor(spec.id);
      final double next = now + (goal - now) * 0.35 + noise;
      current[spec.id] = next.clamp(spec.minValue, spec.maxValue).toDouble();
    }

    final Map<String, double?> values = {
      for (final MapEntry<String, double> e in current.entries)
        e.key: _round(e.value, SensorConfig.byId(e.key).decimals),
    };

    // Skenario "sensor gagal": DHT11 tidak terbaca (nilai kosong, bukan angka palsu).
    if (scenario == DemoScenario.sensorFail) {
      values['temperature'] = null;
      values['humidity'] = null;
    }

    final double? soil = values['soilMoistureRaw'];

    _controller.add(
      DeviceSnapshot(
        deviceId: deviceId,
        deviceName: 'MONU Node 1 (Demo)',
        timestamp: DateTime.now(),
        values: values,
        soilMoisturePercent: soil == null ? null : _soilPercent(soil),
      ),
    );
  }

  Map<String, double> _targetFor(DemoScenario s) {
    switch (s) {
      case DemoScenario.warning:
        return {..._baseNow(), 'temperature': 37.0};
      case DemoScenario.check:
        return const {
          'temperature': 41.5,
          'humidity': 27,
          'soilMoistureRaw': 3400,
          'mq2Raw': 2700,
        };
      case DemoScenario.normal:
      case DemoScenario.sensorFail:
      case DemoScenario.offline:
        return _baseNow();
    }
  }

  double _noiseFor(String id) => switch (id) {
        'temperature' => 0.25,
        'humidity' => 1.0,
        'soilMoistureRaw' => 25.0,
        _ => 30.0,
      };

  // Kalibrasi contoh: 3300 = kering (0%), 1300 = basah (100%).
  double _soilPercent(double raw) {
    final double p = ((3300 - raw) / (3300 - 1300) * 100).clamp(0, 100).toDouble();
    return _round(p, 0);
  }

  static double _round(double v, int decimals) =>
      double.parse(v.toStringAsFixed(decimals));

  // ---------------------------------------------------------------------
  // Riwayat palsu: kurva halus yang bergantung waktu (siang lebih hangat).
  // ---------------------------------------------------------------------

  Map<String, double> _baseNow() {
    final DeviceSnapshot s = _syntheticAt(DateTime.now());
    return {
      for (final MapEntry<String, double?> e in s.values.entries)
        e.key: e.value ?? 0,
    };
  }

  DeviceSnapshot _syntheticAt(DateTime t) {
    final double ms = t.millisecondsSinceEpoch.toDouble();
    final double hour = t.hour + t.minute / 60.0;
    final double daily = math.sin((hour - 9) / 24 * 2 * math.pi);

    final Map<String, double?> values = {
      'temperature':
          _round(30.5 + 3.2 * daily + 0.4 * math.sin(ms / 90000), 1),
      'humidity': _round(72 - 9 * daily + 1.2 * math.sin(ms / 70000), 0),
      'soilMoistureRaw': _round(
        2100 + 150 * math.sin(ms / 30000000) + 40 * math.sin(ms / 120000),
        0,
      ),
      'mq2Raw': _round(
        550 + 70 * math.sin(ms / 50000) + 40 * math.sin(ms / 21000),
        0,
      ),
    };

    return DeviceSnapshot(
      deviceId: deviceId,
      deviceName: 'MONU Node 1 (Demo)',
      timestamp: t,
      values: values,
      soilMoisturePercent: _soilPercent(values['soilMoistureRaw']!),
    );
  }

  @override
  Future<List<DeviceSnapshot>> loadHistory(Duration range) async {
    final DateTime now = DateTime.now();
    final int step = range <= const Duration(hours: 1)
        ? 60
        : (range <= const Duration(hours: 24) ? 15 * 60 : 2 * 3600);
    final int count = range.inSeconds ~/ step;

    return <DeviceSnapshot>[
      for (int i = count; i >= 0; i--)
        _syntheticAt(now.subtract(Duration(seconds: i * step))),
    ];
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    if (!_controller.isClosed) _controller.close();
  }
}