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
  static const String _kEsp32Ip = 'esp32_ip';
  static const String _kConnMode = 'connection_mode';

  static String _thresholdKey(String sensorId) => 'threshold_$sensorId';

  SharedPreferences? _prefs;
  bool _loaded = false;
  bool _useMockData = false;
  String _databaseUrl = IotConfig.firebaseDatabaseUrl;
  String _deviceId = IotConfig.deviceId;
  String _esp32Ip = IotConfig.defaultEsp32Ip;
  // Default: supabase — saat pertama install langsung pakai Supabase Cloud
  // User bisa ubah ke 'esp32' atau 'mock' dari halaman Profil
  String _connectionMode = 'supabase'; // 'supabase', 'esp32', 'mock', 'firebase'
  final Map<String, AlertLimit> _custom = <String, AlertLimit>{};

  bool get loaded => _loaded;
  bool get useMockData => _connectionMode == 'mock' || _useMockData;
  String get databaseUrl => _databaseUrl;
  String get deviceId => _deviceId;
  String get esp32Ip => _esp32Ip;
  String get connectionMode => _connectionMode;
  bool get isEsp32Mode => _connectionMode == 'esp32';
  bool get isSupabaseMode => _connectionMode == 'supabase';

  Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _prefs = prefs;

    _esp32Ip = prefs.getString(_kEsp32Ip) ?? IotConfig.defaultEsp32Ip;
    // Default pertama kali install → supabase (agar langsung bisa pantau cloud)
    _connectionMode = prefs.getString(_kConnMode) ?? 'supabase';
    _useMockData = prefs.getBool(_kMock) ?? (_connectionMode == 'mock');
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
    _connectionMode = value ? 'mock' : 'esp32';
    notifyListeners();
    await _prefs?.setBool(_kMock, value);
    await _prefs?.setString(_kConnMode, _connectionMode);
  }

  Future<void> setEsp32Ip(String value) async {
    final String clean = value.trim().replaceAll('http://', '').replaceAll('/', '');
    _esp32Ip = clean.isEmpty ? IotConfig.defaultEsp32Ip : clean;
    _connectionMode = 'esp32';
    _useMockData = false;
    notifyListeners();
    await _prefs?.setString(_kEsp32Ip, _esp32Ip);
    await _prefs?.setString(_kConnMode, 'esp32');
    await _prefs?.setBool(_kMock, false);
  }

  Future<void> setConnectionMode(String mode) async {
    _connectionMode = mode;
    _useMockData = (mode == 'mock');
    notifyListeners();
    await _prefs?.setString(_kConnMode, mode);
    await _prefs?.setBool(_kMock, _useMockData);
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