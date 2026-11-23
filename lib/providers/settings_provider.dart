import 'package:flutter/foundation.dart';
import 'package:monu/config/iot_config.dart';
import 'package:monu/config/sensor_config.dart';
import 'package:monu/models/sensor_spec.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pengaturan yang tersimpan di HP: mode data, URL database, dan ambang batas.
/// Kalau belum pernah diubah, nilainya diambil dari IotConfig dan SensorConfig.
class SettingsProvider extends ChangeNotifier {
  static const String _kMock = 'use_mock_data';
  static const String _kUrl = 'database_url';
  static const String _kDevice = 'device_id';

  static String _thresholdKey(String sensorId) => 'threshold_$sensorId';

  SharedPreferences? _prefs;
  bool _loaded = false;
  bool _useMockData = IotConfig.useMockData;
  String _databaseUrl = IotConfig.firebaseDatabaseUrl;
  String _deviceId = IotConfig.deviceId;
  final Map<String, AlertLimit> _custom = <String, AlertLimit>{};

  bool get loaded => _loaded;
  bool get useMockData => _useMockData;
  String get databaseUrl => _databaseUrl;
  String get deviceId => _deviceId;

  Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _prefs = prefs;

    _useMockData = prefs.getBool(_kMock) ?? IotConfig.useMockData;
    _databaseUrl = prefs.getString(_kUrl) ?? IotConfig.firebaseDatabaseUrl;
    _deviceId = prefs.getString(_kDevice) ?? IotConfig.deviceId;

    for (final SensorSpec spec in SensorConfig.all) {
      final String? raw = prefs.getString(_thresholdKey(spec.id));
      if (raw == null) continue;
      final List<String> parts = raw.split('|');
      if (parts.length != 2) continue;
      final double? warning = double.tryParse(parts[0]);
      final double? check = double.tryParse(parts[1]);
      if (warning != null && check != null) {
        _custom[spec.id] = AlertLimit(warning: warning, check: check);
      }
    }

    _loaded = true;
    notifyListeners();
  }

  Future<void> setUseMockData(bool value) async {
    _useMockData = value;
    notifyListeners();
    await _prefs?.setBool(_kMock, value);
  }

  Future<void> setDatabaseUrl(String value) async {
    _databaseUrl = value.trim();
    notifyListeners();
    await _prefs?.setString(_kUrl, _databaseUrl);
  }

  Future<void> setDeviceId(String value) async {
    final String id = value.trim().isEmpty ? IotConfig.deviceId : value.trim();
    _deviceId = id;
    notifyListeners();
    await _prefs?.setString(_kDevice, id);
  }

  // ---- Ambang batas ----

  AlertLimit thresholdFor(SensorSpec spec) =>
      _custom[spec.id] ?? spec.defaultThreshold;

  bool isCustom(SensorSpec spec) => _custom.containsKey(spec.id);

  Future<void> setThreshold(
    SensorSpec spec, {
    required double warning,
    required double check,
  }) async {
    _custom[spec.id] = AlertLimit(warning: warning, check: check);
    notifyListeners();
    await _prefs?.setString(_thresholdKey(spec.id), '$warning|$check');
  }

  Future<void> resetThresholds() async {
    _custom.clear();
    notifyListeners();
    for (final SensorSpec spec in SensorConfig.all) {
      await _prefs?.remove(_thresholdKey(spec.id));
    }
  }
}