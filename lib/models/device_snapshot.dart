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
  });

  final String deviceId;
  final String deviceName;

  /// Waktu pengukuran/pengiriman dari perangkat.
  final DateTime timestamp;

  /// Kunci = id sensor. Nilai null = sensor gagal dibaca (tidak tersedia).
  final Map<String, double?> values;

  /// Opsional: persen kelembapan tanah setelah kalibrasi.
  final double? soilMoisturePercent;

  double? valueOf(String sensorId) => values[sensorId];

  bool get hasMissing {
    for (final SensorSpec s in SensorConfig.all) {
      if (values[s.id] == null) return true;
    }
    return false;
  }

  /// Membaca data JSON dari database.
  /// Mendukung bentuk bersarang (devices/{id}: { sensors: {...} })
  /// dan bentuk datar (history/{id}/{pushId}: { temperature: ... }).
  factory DeviceSnapshot.fromMap(String deviceId, Map<dynamic, dynamic> map) {
    final dynamic rawSensors = map['sensors'];
    final Map<dynamic, dynamic> source =
        rawSensors is Map ? rawSensors : map;

    final Map<String, double?> values = {
      for (final SensorSpec s in SensorConfig.all) s.id: _toDouble(source[s.id]),
    };

    return DeviceSnapshot(
      deviceId: deviceId,
      deviceName: (map['name'] ?? deviceId).toString(),
      timestamp: _toTime(map['updatedAt'] ?? map['timestamp']),
      values: values,
      soilMoisturePercent: _toDouble(source['soilMoisturePercent']),
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