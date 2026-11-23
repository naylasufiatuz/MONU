import 'package:monu/config/iot_config.dart';
import 'package:monu/config/sensor_config.dart';
import 'package:monu/core/formatters.dart';
import 'package:monu/models/monitoring_status.dart';
import 'package:monu/models/sensor_spec.dart';

enum AlertKind { threshold, sensorFailure, deviceOffline }

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

  double? lastValue;
  double? peakValue;
  DateTime? resolvedAt;

  bool get isActive => resolvedAt == null;

  SensorSpec? get spec => sensorId == null ? null : SensorConfig.byId(sensorId!);

  String get title {
    switch (kind) {
      case AlertKind.deviceOffline:
        return 'Perangkat offline';
      case AlertKind.sensorFailure:
        return '${spec!.name} tidak terbaca';
      case AlertKind.threshold:
        return level == SensorLevel.check
            ? '${spec!.name} perlu diperiksa'
            : '${spec!.name} melewati ambang';
    }
  }

  String get message {
    switch (kind) {
      case AlertKind.deviceOffline:
        return 'Tidak ada data baru selama lebih dari '
            '${IotConfig.offlineAfter.inSeconds} detik. '
            'Periksa daya dan koneksi Wi-Fi perangkat.';
      case AlertKind.sensorFailure:
        return 'Pembacaan gagal. Nilai ditandai tidak tersedia dan tidak '
            'diganti dengan angka perkiraan.';
      case AlertKind.threshold:
        final SensorSpec s = spec!;
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