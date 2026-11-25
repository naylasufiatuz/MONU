import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:monu/config/iot_config.dart';
import 'package:monu/models/alert_event.dart';
import 'package:monu/models/device_snapshot.dart';
import 'package:monu/models/monitoring_status.dart';
import 'package:monu/models/sensor_spec.dart';
import 'package:monu/providers/settings_provider.dart';
import 'package:monu/repositories/esp32_sensor_repository.dart';
import 'package:monu/repositories/firebase_sensor_repository.dart';
import 'package:monu/repositories/mock_sensor_repository.dart';
import 'package:monu/repositories/sensor_repository.dart';
import 'package:monu/repositories/supabase_sensor_repository.dart';
import 'package:monu/services/status_evaluator.dart';

/// Otak app: menerima data dari repository, menghitung status,
/// mengelola peringatan, dan menandai Offline berdasarkan waktu data terakhir.
class MonitorProvider extends ChangeNotifier {
  MonitorProvider(this._settings) {
    _settings.addListener(_onSettingsChanged);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    if (_settings.loaded) _startRepository();
  }

  final SettingsProvider _settings;

  SensorRepository? _repository;
  StreamSubscription<DeviceSnapshot?>? _subscription;
  Timer? _ticker;
  bool _disposed = false;
  bool _started = false;
  String _sourceInUse = '';

  DeviceSnapshot? _latest;
  Evaluation? _evaluation;
  DateTime _now = DateTime.now();
  String? _connectionError;
  DemoScenario _scenario = DemoScenario.normal;

  final List<DeviceSnapshot> _recent = <DeviceSnapshot>[];
  final List<AlertEvent> _alerts = <AlertEvent>[];
  final Map<String, AlertEvent> _active = <String, AlertEvent>{};
  AlertEvent? _offlineAlert;
  int _alertSeq = 0;
  bool? _lastPumpActive;
  bool _wasOffline = false;

  // ---------------------------------------------------------------------
  // Data yang dibaca tampilan
  // ---------------------------------------------------------------------

  DeviceSnapshot? get latest => _latest;
  Evaluation? get evaluation => _evaluation;
  DateTime get now => _now;
  String? get connectionError => _connectionError;
  bool get isMock => _settings.useMockData;
  bool get supportsHistory => _repository?.supportsHistory ?? false;
  String get modeLabel =>
      _repository?.modeLabel ??
      (_settings.isSupabaseMode
          ? 'Supabase (Cloud Postgres)'
          : (_settings.isEsp32Mode
              ? 'ESP32 (${_settings.esp32Ip})'
              : (_settings.useMockData ? 'Mode Demo' : 'Mode Asli')));
  String get deviceId => _settings.deviceId;
  String get deviceName => _latest?.deviceName ?? 'MONU Node';
  DemoScenario get scenario => _scenario;

  /// Offline = belum pernah ada data, atau data terakhir lebih tua dari batas.
  /// (Bukan berdasarkan halaman terbuka atau tidak.)
  bool get isOffline {
    final DeviceSnapshot? s = _latest;
    if (s == null) return true;
    return _now.difference(s.timestamp) > IotConfig.offlineAfter;
  }

  /// Umur data terakhir, atau null jika belum ada data.
  Duration? get sinceLastUpdate {
    final DeviceSnapshot? s = _latest;
    if (s == null) return null;
    final Duration d = _now.difference(s.timestamp);
    return d.isNegative ? Duration.zero : d;
  }

  MonitoringStatus get status {
    if (isOffline) return MonitoringStatus.offline;
    return _evaluation?.status ?? MonitoringStatus.offline;
  }

  SensorEvaluation? evaluationOf(String sensorId) => _evaluation?.of(sensorId);

  /// Nilai terakhir untuk grafik mini (hanya nilai yang valid).
  List<double> sparkValues(String sensorId) => <double>[
        for (final DeviceSnapshot s in _recent)
          if (s.valueOf(sensorId) != null) s.valueOf(sensorId)!,
      ];

  List<AlertEvent> get alerts => List<AlertEvent>.unmodifiable(_alerts);
  List<AlertEvent> get activeAlerts =>
      _alerts.where((a) => a.isActive).toList();
  
  List<DeviceSnapshot> get recentSnapshots =>
      List<DeviceSnapshot>.unmodifiable(_recent);

  Future<List<DeviceSnapshot>> loadHistory(Duration range) {
    final SensorRepository? repo = _repository;
    if (repo == null) return Future<List<DeviceSnapshot>>.value(<DeviceSnapshot>[]);
    return repo.loadHistory(range);
  }

  Future<void> refresh() async => _repository?.refresh();

  /// Hanya berlaku di Mode Demo.
  void setScenario(DemoScenario value) {
    _scenario = value;
    final SensorRepository? repo = _repository;
    if (repo is MockSensorRepository) {
      repo.scenario = value;
      repo.refresh();
    }
    _notify();
  }

  // ---------------------------------------------------------------------
  // Sumber data
  // ---------------------------------------------------------------------

  String _sourceKey() =>
      '${_settings.connectionMode}|${_settings.esp32Ip}|${_settings.useMockData}|${_settings.databaseUrl}|${_settings.deviceId}';

  void _onSettingsChanged() {
    if (_disposed || !_settings.loaded) return;
    if (!_started || _sourceKey() != _sourceInUse) {
      _startRepository();
    } else {
      _reevaluate(); // ambang batas mungkin berubah
    }
  }

  void _startRepository() {
    _started = true;
    _sourceInUse = _sourceKey();

    _subscription?.cancel();
    _subscription = null;
    _repository?.dispose();
    _repository = null;

    _latest = null;
    _evaluation = null;
    _recent.clear();
    _alerts.clear();
    _active.clear();
    _offlineAlert = null;
    _connectionError = null;
    _lastPumpActive = null;

    final SensorRepository repo;
    if (_settings.isSupabaseMode) {
      repo = SupabaseSensorRepository(
        deviceId: _settings.deviceId,
      );
    } else if (_settings.isEsp32Mode) {
      repo = Esp32SensorRepository(
        ipAddress: _settings.esp32Ip,
        deviceId: _settings.deviceId,
      );
    } else if (_settings.useMockData) {
      final MockSensorRepository mock =
          MockSensorRepository(deviceId: _settings.deviceId);
      mock.scenario = _scenario;
      repo = mock;
    } else {
      final String? base =
          FirebaseSensorRepository.normalizeUrl(_settings.databaseUrl);
      if (base == null) {
        _connectionError =
            'URL database belum diisi. Buka Profil > Pengaturan Koneksi IoT.';
        _notify();
        return;
      }
      repo = FirebaseSensorRepository(
        databaseUrl: base,
        deviceId: _settings.deviceId,
      );
    }

    _repository = repo;
    _subscription = repo.watchLatest().listen(_onSnapshot, onError: _onError);
    _seedRecent(repo);
    _notify();
  }

  /// Mengisi grafik mini dengan data 15 menit terakhir supaya tidak kosong.
  void _seedRecent(SensorRepository repo) {
    repo.loadHistory(const Duration(minutes: 15)).then((List<DeviceSnapshot> seed) {
      if (_disposed || !identical(repo, _repository)) return;
      final DateTime? firstLive =
          _recent.isEmpty ? null : _recent.first.timestamp;
      final List<DeviceSnapshot> older = seed
          .where((s) => firstLive == null || s.timestamp.isBefore(firstLive))
          .toList();
      _recent.insertAll(0, older);
      _trimRecent();
      _notify();
    }).catchError((Object _) {});
  }

  void _trimRecent() {
    while (_recent.length > IotConfig.sparklinePoints) {
      _recent.removeAt(0);
    }
  }

  void _onSnapshot(DeviceSnapshot? snapshot) {
    _connectionError = null;
    _now = DateTime.now();

    if (snapshot == null) {
      _latest = null;
      _evaluation = null;
      _notify();
      return;
    }

    _latest = snapshot;
    if (_recent.isEmpty || snapshot.timestamp != _recent.last.timestamp) {
      _recent.add(snapshot);
      _trimRecent();
    }

    final Evaluation eval =
        StatusEvaluator.evaluate(snapshot, _settings.thresholdFor);
    _evaluation = eval;

    // Deteksi perubahan kondisi pompa air / relay untuk notifikasi
    if (_lastPumpActive != null) {
      if (!_lastPumpActive! && snapshot.pumpActive) {
        // Penyiraman otomatis dimulai
        final AlertEvent wateringStart = AlertEvent(
          id: ++_alertSeq,
          kind: AlertKind.wateringStarted,
          level: SensorLevel.warning,
          startedAt: snapshot.timestamp,
        );
        _alerts.insert(0, wateringStart);
      } else if (_lastPumpActive! && !snapshot.pumpActive) {
        // Penyiraman selesai
        final AlertEvent wateringEnd = AlertEvent(
          id: ++_alertSeq,
          kind: AlertKind.wateringFinished,
          level: SensorLevel.normal,
          startedAt: snapshot.timestamp,
          resolvedAt: snapshot.timestamp,
        );
        _alerts.insert(0, wateringEnd);
      }
    }
    _lastPumpActive = snapshot.pumpActive;

    _updateOfflineAlert();
    _updateSensorAlerts(snapshot, eval);
    _notify();
  }

  void _onError(Object error) {
    _connectionError = describeRepositoryError(error);
    _notify();
  }

  void _onTick() {
    if (_disposed) return;
    _now = DateTime.now();
    _updateOfflineAlert();
    _notify();
  }

  void _reevaluate() {
    final DeviceSnapshot? snapshot = _latest;
    if (snapshot == null) {
      _notify();
      return;
    }
    final Evaluation eval =
        StatusEvaluator.evaluate(snapshot, _settings.thresholdFor);
    _evaluation = eval;
    _updateSensorAlerts(snapshot, eval);
    _notify();
  }

  // ---------------------------------------------------------------------
  // Mesin peringatan
  // Aturan pemulihan: peringatan aktif ditutup (diberi waktu selesai) saat
  // nilai kembali normal. Kalau levelnya berubah (Waspada <-> Perlu
  // Pemeriksaan), peringatan lama ditutup dan dibuat yang baru.
  // ---------------------------------------------------------------------

  void _updateSensorAlerts(DeviceSnapshot snapshot, Evaluation eval) {
    for (final SensorEvaluation e in eval.sensors) {
      final String id = e.spec.id;
      final AlertEvent? current = _active[id];

      if (e.level == SensorLevel.normal) {
        if (current != null) {
          current.resolvedAt = snapshot.timestamp;
          _active.remove(id);
        }
        continue;
      }

      if (current != null && current.level == e.level) {
        if (e.value != null) {
          current.lastValue = e.value;
          current.peakValue = _worse(e.spec, current.peakValue, e.value);
        }
        continue;
      }

      if (current != null) current.resolvedAt = snapshot.timestamp;

      final AlertLimit t = _settings.thresholdFor(e.spec);
      final AlertEvent created = AlertEvent(
        id: ++_alertSeq,
        kind: e.level == SensorLevel.unavailable
            ? AlertKind.sensorFailure
            : AlertKind.threshold,
        level: e.level,
        startedAt: snapshot.timestamp,
        sensorId: id,
        value: e.value,
        thresholdValue: e.level == SensorLevel.check
            ? t.check
            : (e.level == SensorLevel.warning ? t.warning : null),
      );
      _active[id] = created;
      _alerts.insert(0, created);
    }

    // Deteksi darurat api pada thermocouple (suhu >= 50°C atau fireDetected)
    final double? thermoVal = snapshot.valueOf('thermocouple');
    final bool isFireNow = snapshot.fireDetected || (thermoVal != null && thermoVal >= 50.0);
    final AlertEvent? currentFire = _active['fireEmergency'];

    if (!isFireNow) {
      if (currentFire != null) {
        currentFire.resolvedAt = snapshot.timestamp;
        _active.remove('fireEmergency');
      }
    } else {
      if (currentFire == null) {
        final AlertEvent fireEvent = AlertEvent(
          id: ++_alertSeq,
          kind: AlertKind.fireEmergency,
          level: SensorLevel.warning,
          startedAt: snapshot.timestamp,
          sensorId: 'thermocouple',
          value: thermoVal,
          thresholdValue: 50.0,
        );
        _active['fireEmergency'] = fireEvent;
        _alerts.insert(0, fireEvent);
      } else {
        if (thermoVal != null) {
          currentFire.lastValue = thermoVal;
          if (currentFire.peakValue == null || thermoVal > currentFire.peakValue!) {
            currentFire.peakValue = thermoVal;
          }
        }
      }
    }

    while (_alerts.length > 200) {
      _alerts.removeLast();
    }
  }

  double? _worse(SensorSpec spec, double? a, double? b) {
    if (a == null) return b;
    if (b == null) return a;
    return spec.direction == ThresholdDirection.high
        ? (b > a ? b : a)
        : (b < a ? b : a);
  }

  void _updateOfflineAlert() {
    final bool offline = isOffline;
    if (offline && _latest != null && _offlineAlert == null) {
      final AlertEvent created = AlertEvent(
        id: ++_alertSeq,
        kind: AlertKind.deviceOffline,
        level: SensorLevel.unavailable,
        startedAt: DateTime.now(),
      );
      _offlineAlert = created;
      _alerts.insert(0, created);
      _wasOffline = true;
    } else if (!offline && _offlineAlert != null) {
      _offlineAlert!.resolvedAt = DateTime.now();
      _offlineAlert = null;
      if (_wasOffline) {
        // Notifikasi koneksi ESP32 berhasil kembali
        final AlertEvent backOnline = AlertEvent(
          id: ++_alertSeq,
          kind: AlertKind.deviceOnline,
          level: SensorLevel.normal,
          startedAt: DateTime.now(),
          resolvedAt: DateTime.now(),
        );
        _alerts.insert(0, backOnline);
        _wasOffline = false;
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _settings.removeListener(_onSettingsChanged);
    _ticker?.cancel();
    _subscription?.cancel();
    _repository?.dispose();
    super.dispose();
  }
}