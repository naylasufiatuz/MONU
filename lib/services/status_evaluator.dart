import 'package:monu/config/sensor_config.dart';
import 'package:monu/models/device_snapshot.dart';
import 'package:monu/models/monitoring_status.dart';
import 'package:monu/models/sensor_spec.dart';

class SensorEvaluation {
  const SensorEvaluation({
    required this.spec,
    required this.value,
    required this.level,
  });

  final SensorSpec spec;
  final double? value;
  final SensorLevel level;
}

class Evaluation {
  const Evaluation({required this.status, required this.sensors});

  final MonitoringStatus status;
  final List<SensorEvaluation> sensors;

  SensorEvaluation of(String sensorId) =>
      sensors.firstWhere((e) => e.spec.id == sensorId);

  List<SensorEvaluation> get alerting =>
      sensors.where((e) => e.level.isAlert).toList();
}

/// Aturan status sesuai PRD bagian 11.
class StatusEvaluator {
  StatusEvaluator._();

  /// Level satu sensor dibanding ambangnya.
  static SensorLevel levelFor(SensorSpec spec, double? value, AlertLimit t) {
    if (value == null || value.isNaN) return SensorLevel.unavailable;

    if (spec.direction == ThresholdDirection.high) {
      if (value >= t.check) return SensorLevel.check;
      if (value >= t.warning) return SensorLevel.warning;
      return SensorLevel.normal;
    }

    if (value <= t.check) return SensorLevel.check;
    if (value <= t.warning) return SensorLevel.warning;
    return SensorLevel.normal;
  }

  /// Status keseluruhan (tanpa memperhitungkan Offline, itu dihitung dari waktu).
  ///
  /// - Tidak ada yang melewati ambang  -> Normal (atau Data Tidak Lengkap
  ///   kalau ada sensor gagal; tidak boleh dinyatakan Normal).
  /// - "Perlu Pemeriksaan" bila ada sensor (selain MQ-2) di level pemeriksaan,
  ///   ATAU dua indikator atau lebih muncul bersamaan.
  /// - Selain itu -> Waspada.
  /// MQ-2 sendirian tidak bisa menaikkan status ke "Perlu Pemeriksaan".
  static Evaluation evaluate(
    DeviceSnapshot snapshot,
    AlertLimit Function(SensorSpec spec) thresholdOf,
  ) {
    final List<SensorEvaluation> sensors = [
      for (final SensorSpec spec in SensorConfig.all)
        SensorEvaluation(
          spec: spec,
          value: snapshot.valueOf(spec.id),
          level: levelFor(spec, snapshot.valueOf(spec.id), thresholdOf(spec)),
        ),
    ];

    final List<SensorEvaluation> alerting =
        sensors.where((e) => e.level.isAlert).toList();
    final bool hasMissing =
        sensors.any((e) => e.level == SensorLevel.unavailable);

    MonitoringStatus status;
    if (alerting.isEmpty) {
      status = hasMissing ? MonitoringStatus.incomplete : MonitoringStatus.normal;
    } else {
      final bool strong = alerting.any(
        (e) => e.level == SensorLevel.check && e.spec.canTriggerCheckAlone,
      );
      status = (strong || alerting.length >= 2)
          ? MonitoringStatus.check
          : MonitoringStatus.warning;
    }

    return Evaluation(status: status, sensors: sensors);
  }
}