import 'package:monu/config/sensor_config.dart';
import 'package:monu/models/sensor_spec.dart';

/// Satu pembacaan lengkap dari satu perangkat pada satu waktu.
/// Dipakai untuk data terbaru DAN untuk riwayat.
class DeviceSnapshot {
  const DeviceSnapshot({
    required this.deviceId,
    required this.deviceName,
    required this.timestamp,
    required this.values,
    this.soilMoisturePercent,
    this.relayActive = false,
    this.pumpActive = false,
    this.fireDetected = false,
    this.isWifiConnected = true,
    this.esp32Ip,
    this.deviceStatus = 'online',
  });

  final String deviceId;
  final String deviceName;

  /// Waktu pengukuran/pengiriman dari perangkat.
  final DateTime timestamp;

  /// Kunci = id sensor. Nilai null = sensor gagal dibaca (tidak tersedia).
  final Map<String, double?> values;

  /// Opsional: persen kelembapan tanah setelah kalibrasi.
  final double? soilMoisturePercent;

  /// Status relay pompa air.
  final bool relayActive;

  /// Status pompa air (mengikuti aktivasi relay).
  final bool pumpActive;

  /// Indikasi deteksi api / panas darurat pada thermocouple.
  final bool fireDetected;

  /// Status Wi-Fi pada ESP32.
  final bool isWifiConnected;

  /// IP Address aktual ESP32.
  final String? esp32Ip;

  /// Status perangkat ('online' / 'disconnected').
  final String deviceStatus;

  double? valueOf(String sensorId) => values[sensorId];

  bool get hasMissing {
    for (final SensorSpec s in SensorConfig.all) {
      if (values[s.id] == null) return true;
    }
    return false;
  }

  /// Membaca data JSON dari database Firebase / Mock.
  factory DeviceSnapshot.fromMap(String deviceId, Map<dynamic, dynamic> map) {
    final dynamic rawSensors = map['sensors'];
    final Map<dynamic, dynamic> source =
        rawSensors is Map ? rawSensors : map;

    final Map<String, double?> values = {
      for (final SensorSpec s in SensorConfig.all) s.id: _toDouble(source[s.id]),
    };

    final dynamic relayVal = map['relay'] ?? source['relay'];
    final bool isRelay = relayVal == 1 || relayVal == true || relayVal == 'ON';

    return DeviceSnapshot(
      deviceId: deviceId,
      deviceName: (map['name'] ?? map['device_name'] ?? deviceId).toString(),
      timestamp: _toTime(map['updatedAt'] ?? map['timestamp']),
      values: values,
      soilMoisturePercent: _toDouble(source['soilMoisturePercent']),
      relayActive: isRelay,
      pumpActive: isRelay,
      isWifiConnected: map['wifi_connected'] != false,
      esp32Ip: map['ip_address']?.toString(),
      deviceStatus: (map['device_status'] ?? map['status'] ?? 'online').toString(),
    );
  }

  /// Membaca data JSON langsung dari respons HTTP ESP32 (/api/status).
  factory DeviceSnapshot.fromEsp32Map(String fallbackDeviceId, Map<dynamic, dynamic> map) {
    final String deviceId = (map['device_id'] ?? fallbackDeviceId).toString();
    final String deviceName = (map['device_name'] ?? 'ESP32 MONU Node').toString();
    final DateTime timestamp = DateTime.now();

    final dynamic rawSensors = map['sensors'];
    final Map<dynamic, dynamic> sensorMap =
        rawSensors is Map ? rawSensors : <dynamic, dynamic>{};

    double? temp;
    double? hum;
    double? soilRaw;
    double? mq2Raw;
    double? thermo;

    // 1. DHT11
    final dynamic dht = sensorMap['dht11'] ?? map['dht11'];
    if (dht is Map) {
      if (dht['status'] != 'belum_tersedia') {
        temp = _toDouble(dht['temperature']);
        hum = _toDouble(dht['humidity']);
      }
    } else {
      temp = _toDouble(map['temperature']);
      hum = _toDouble(map['humidity']);
    }

    // 2. Soil Moisture
    final dynamic soil =
        sensorMap['soil_moisture'] ?? map['soil_moisture'] ?? map['soilMoistureRaw'];
    if (soil is Map) {
      if (soil['status'] != 'belum_tersedia') {
        soilRaw = _toDouble(soil['raw_adc'] ?? soil['value']);
      }
    } else {
      soilRaw = _toDouble(soil);
    }

    // 3. MQ-2
    final dynamic mq2 =
        sensorMap['mq2'] ?? map['mq2'] ?? map['mq2Raw'];
    if (mq2 is Map) {
      if (mq2['status'] != 'belum_tersedia') {
        mq2Raw = _toDouble(mq2['raw_adc'] ?? mq2['value']);
      }
    } else {
      mq2Raw = _toDouble(mq2);
    }

    // 4. Thermocouple
    final dynamic thermoData =
        sensorMap['thermocouple'] ?? map['thermocouple'];
    if (thermoData is Map) {
      if (thermoData['status'] != 'belum_tersedia') {
        thermo = _toDouble(thermoData['temperature'] ?? thermoData['value']);
      }
    } else {
      thermo = _toDouble(thermoData);
    }

    final Map<String, double?> values = {
      'temperature': temp,
      'humidity': hum,
      'soilMoistureRaw': soilRaw,
      'mq2Raw': mq2Raw,
      'thermocouple': thermo,
    };

    // Relay & Pompa Air (Mendukung format PRD pump_status, pump objek, dan relay)
    final dynamic actuators = map['actuators'];
    final dynamic pumpObj = (actuators is Map) ? actuators['relay'] : (map['pump'] ?? map['relay']);
    bool isRelayOn = map['pump_status'] == true || map['pump_status'] == 1 || map['pump_status'] == 'ON';
    if (!isRelayOn && pumpObj is Map) {
      final dynamic state = pumpObj['state'] ?? pumpObj['active'];
      isRelayOn = state == 1 || state == true || pumpObj['state_label'] == 'ON';
    } else if (!isRelayOn && pumpObj != null) {
      isRelayOn = pumpObj == 1 || pumpObj == true || pumpObj == 'ON';
    }

    // Status Jaringan
    final dynamic wifi = map['wifi'];
    final bool wifiOk = map['wifi_connected'] == true ||
        (wifi is Map && (wifi['connected'] == true || wifi['status'] == 'terhubung')) ||
        map['device_status'] == 'online' ||
        map['status'] == 'online';
    final String? ip = (wifi is Map ? wifi['ip_address']?.toString() : null) ??
        map['ip_address']?.toString();

    // Persen Kelembapan Tanah (jika raw tersedia)
    double? soilPercent;
    if (soilRaw != null) {
      soilPercent =
          ((3300 - soilRaw) / (3300 - 1300) * 100).clamp(0, 100).toDouble();
      soilPercent = double.parse(soilPercent.toStringAsFixed(0));
    }

    final bool isFire = map['fire_detected'] == true ||
        (thermoData is Map && (thermoData['fire_detected'] == true || thermoData['status'] == 'FIRE_ALERT')) ||
        (thermo != null && thermo >= 50.0);

    return DeviceSnapshot(
      deviceId: deviceId,
      deviceName: deviceName,
      timestamp: timestamp,
      values: values,
      soilMoisturePercent: soilPercent,
      relayActive: isRelayOn,
      pumpActive: isRelayOn,
      fireDetected: isFire,
      isWifiConnected: wifiOk,
      esp32Ip: ip,
      deviceStatus: (map['device_status'] ?? map['status'] ?? (wifiOk ? 'online' : 'offline')).toString(),
    );
  }

  static double? _toDouble(dynamic v) {
    if (v is num) {
      final double d = v.toDouble();
      return (d.isNaN || d.isInfinite) ? null : d;
    }
    if (v is String) return double.tryParse(v.replaceAll(',', '.'));
    return null;
  }

  static DateTime _toTime(dynamic v) {
    int ms = 0;
    if (v is num) {
      ms = v.toInt();
    } else if (v is String) {
      ms = int.tryParse(v) ?? 0;
    }
    // Kalau perangkat mengirim detik (bukan milidetik), ubah ke milidetik.
    if (ms > 0 && ms < 100000000000) ms *= 1000;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }
}