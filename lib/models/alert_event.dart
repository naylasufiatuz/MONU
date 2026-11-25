import 'package:monu/config/iot_config.dart';
import 'package:monu/config/sensor_config.dart';
import 'package:monu/core/formatters.dart';
import 'package:monu/models/monitoring_status.dart';
import 'package:monu/models/sensor_spec.dart';

enum AlertKind {
  threshold,
  sensorFailure,
  deviceOffline,
  deviceOnline,
  wateringStarted,
  wateringFinished,
  drySoil,
  fireEmergency,
}

/// Satu kejadian peringatan. Punya waktu mulai dan (kalau sudah pulih) waktu selesai.
class AlertEvent {
  AlertEvent({
    required this.id,
    required this.kind,
    required this.level,
    required this.startedAt,
    this.sensorId,
    this.value,
    this.thresholdValue,
    this.customTitle,
    this.customMessage,
    this.resolvedAt,
  })  : lastValue = value,
        peakValue = value;

  final int id;
  final AlertKind kind;

  /// warning / check untuk ambang, unavailable untuk sensor gagal dan offline.
  final SensorLevel level;
  final DateTime startedAt;
  final String? sensorId;

  /// Nilai saat peringatan mulai.
  final double? value;
  final double? thresholdValue;
  final String? customTitle;
  final String? customMessage;

  double? lastValue;
  double? peakValue;
  DateTime? resolvedAt;

  bool get isActive => resolvedAt == null;

  SensorSpec? get spec => sensorId == null ? null : SensorConfig.byId(sensorId!);

  String get title {
    if (customTitle != null) return customTitle!;
    switch (kind) {
      case AlertKind.deviceOffline:
        return 'Koneksi ESP32 terputus';
      case AlertKind.deviceOnline:
        return 'Koneksi ESP32 terhubung kembali';
      case AlertKind.wateringStarted:
        return 'Penyiraman otomatis dimulai';
      case AlertKind.wateringFinished:
        return 'Penyiraman selesai';
      case AlertKind.drySoil:
        return 'Tanah terdeteksi kering';
      case AlertKind.fireEmergency:
        return 'DARURAT: Api Terdeteksi (Thermocouple)!';
      case AlertKind.sensorFailure:
        return '${spec?.name ?? "Sensor"} tidak terbaca';
      case AlertKind.threshold:
        if (sensorId == 'soilMoistureRaw') {
          return 'Tanah terdeteksi kering';
        } else if (sensorId == 'temperature') {
          return 'Suhu DHT11 melebihi ambang batas';
        } else if (sensorId == 'mq2Raw') {
          return 'Terdeteksi indikasi gas atau asap';
        } else if (sensorId == 'thermocouple') {
          return 'Suhu thermocouple melebihi batas';
        }
        return level == SensorLevel.check
            ? '${spec?.name ?? "Sensor"} perlu diperiksa'
            : '${spec?.name ?? "Sensor"} melewati ambang';
    }
  }

  String get message {
    if (customMessage != null) return customMessage!;
    switch (kind) {
      case AlertKind.deviceOffline:
        return 'Tidak ada data baru dari ESP32 selama lebih dari '
            '${IotConfig.offlineAfter.inSeconds} detik. '
            'Periksa daya dan jaringan Wi-Fi perangkat.';
      case AlertKind.deviceOnline:
        return 'Perangkat ESP32 kembali online dan dapat berkomunikasi dengan aplikasi.';
      case AlertKind.wateringStarted:
        return 'Relay aktif (GPIO 19). Pompa air sedang menyiram tanah secara otomatis.';
      case AlertKind.wateringFinished:
        return 'Relay mati. Penyiraman selesai, kelembapan aman telah tercapai.';
      case AlertKind.drySoil:
        return 'Kelembapan tanah rendah melewati batas normal. Sistem menyiram otomatis.';
      case AlertKind.fireEmergency:
        return 'Thermocouple mendeteksi panas api tinggi (>= 50°C). Sistem menyalakan pompa air untuk pemadaman dan membunyikan sirine darurat!';
      case AlertKind.sensorFailure:
        return 'Pembacaan gagal atau modul sensor belum terpasang. Nilai ditandai belum tersedia.';
      case AlertKind.threshold:
        final SensorSpec? s = spec;
        if (s == null) return 'Nilai sensor melewati ambang batas.';
        final String shown =
            '${Fmt.number(value, decimals: s.decimals)} ${s.unit}';
        final String limit =
            '${Fmt.number(thresholdValue, decimals: s.decimals)} ${s.unit}';
        final String word =
            s.direction == ThresholdDirection.high ? 'melewati' : 'di bawah';
        final String grade =
            level == SensorLevel.check ? 'pemeriksaan' : 'waspada';
        final String extra = s.canTriggerCheckAlone
            ? ''
            : ' Ini indikator tambahan, bukan konfirmasi kebakaran.';
        return 'Terbaca $shown, $word ambang $grade $limit.$extra';
    }
  }
}