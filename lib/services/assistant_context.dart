import 'dart:math' as math;

import 'package:monu/config/sensor_config.dart';
import 'package:monu/core/formatters.dart';
import 'package:monu/models/alert_event.dart';
import 'package:monu/models/device_snapshot.dart';
import 'package:monu/models/monitoring_status.dart';
import 'package:monu/models/sensor_spec.dart';
import 'package:monu/providers/monitor_provider.dart';
import 'package:monu/providers/settings_provider.dart';
import 'package:monu/services/status_evaluator.dart';

/// Fakta tentang satu sensor pada saat pertanyaan diajukan.
class SensorFacts {
  const SensorFacts({
    required this.spec,
    required this.value,
    required this.level,
    required this.limit,
    required this.trend,
    required this.hourCount,
    this.hourMin,
    this.hourMax,
    this.hourAvg,
  });

  final SensorSpec spec;
  final double? value;
  final SensorLevel level;
  final AlertLimit limit;
  final String trend;
  final int hourCount;
  final double? hourMin;
  final double? hourMax;
  final double? hourAvg;

  String fmt(double? v) => v == null
      ? 'tidak tersedia'
      : '${Fmt.number(v, decimals: spec.decimals)} ${spec.unit}';

  String get valueText => fmt(value);

  String get _sign => spec.direction == ThresholdDirection.high ? '≥' : '≤';

  String get warningText => '$_sign ${fmt(limit.warning)}';
  String get checkText => '$_sign ${fmt(limit.check)}';

  String get hourText => hourCount < 2
      ? ''
      : 'terendah ${fmt(hourMin)}, tertinggi ${fmt(hourMax)}, rata-rata ${fmt(hourAvg)} (dari $hourCount pembacaan)';
}

/// Seluruh data yang diketahui asisten saat menjawab.
class AssistantData {
  const AssistantData({
    required this.now,
    required this.deviceName,
    required this.deviceId,
    required this.modeLabel,
    required this.hasData,
    required this.offline,
    required this.sinceText,
    required this.lastTime,
    required this.status,
    required this.sensors,
    required this.activeAlerts,
    required this.recentAlerts,
    this.soilPercent,
    this.connectionError,
  });

  final DateTime now;
  final String deviceName;
  final String deviceId;
  final String modeLabel;
  final bool hasData;
  final bool offline;
  final String sinceText;
  final DateTime? lastTime;
  final MonitoringStatus status;
  final List<SensorFacts> sensors;
  final List<AlertEvent> activeAlerts;
  final List<AlertEvent> recentAlerts;
  final double? soilPercent;
  final String? connectionError;

  SensorFacts factsOf(String sensorId) =>
      sensors.firstWhere((s) => s.spec.id == sensorId);

  /// Teks data untuk dikirim ke AI.
  String toPrompt() {
    final StringBuffer b = StringBuffer();
    b.writeln('Waktu sekarang: ${Fmt.dateTime(now)}');
    b.writeln('Perangkat: $deviceName (ID: $deviceId). Sumber data: $modeLabel.');

    if (!hasData) {
      b.writeln('Koneksi: BELUM ADA DATA dari perangkat.');
      if (connectionError != null) {
        b.writeln('Masalah koneksi: $connectionError');
      }
    } else {
      b.writeln(
        'Koneksi: ${offline ? 'OFFLINE' : 'ONLINE'}. Data terakhir diterima $sinceText (pukul ${Fmt.clock(lastTime!)}).'
        '${offline ? ' Angka di bawah adalah DATA LAMA, bukan kondisi terbaru.' : ''}',
      );
    }

    b.writeln('Status keseluruhan: ${status.label}. ${status.description}');
    b.writeln();
    b.writeln('Sensor:');
    for (final SensorFacts s in sensors) {
      b.write('- ${s.spec.name}: ${s.valueText}');
      if (s.spec.isRaw) b.write(' (nilai mentah ADC)');
      b.write(' | tingkat: ${s.level.label}');
      b.write(
        ' | ambang waspada ${s.warningText}, ambang pemeriksaan ${s.checkText}',
      );
      b.write(' | tren: ${s.trend}');
      if (s.hourText.isNotEmpty) b.write(' | 1 jam terakhir: ${s.hourText}');
      b.writeln();
    }
    if (soilPercent != null) {
      b.writeln(
        'Catatan: kelembapan tanah kira-kira ${soilPercent!.toStringAsFixed(0)} % (kalibrasi contoh, belum final).',
      );
    }

    b.writeln();
    if (activeAlerts.isEmpty) {
      b.writeln('Peringatan aktif: tidak ada.');
    } else {
      b.writeln('Peringatan aktif:');
      for (final AlertEvent a in activeAlerts) {
        b.writeln(
          '- ${a.title} [${a.level.label}] sejak ${Fmt.clock(a.startedAt)}: ${a.message}',
        );
      }
    }
    if (recentAlerts.isNotEmpty) {
      b.writeln('Peringatan yang sudah pulih (terbaru):');
      for (final AlertEvent a in recentAlerts) {
        b.writeln(
          '- ${a.title}: mulai ${Fmt.clock(a.startedAt)}, pulih ${a.resolvedAt == null ? '-' : Fmt.clock(a.resolvedAt!)}',
        );
      }
    }
    return b.toString();
  }
}

class AssistantDataBuilder {
  AssistantDataBuilder._();

  static Future<AssistantData> build(
    MonitorProvider monitor,
    SettingsProvider settings,
  ) async {
    List<DeviceSnapshot> hour = <DeviceSnapshot>[];
    try {
      hour = await monitor
          .loadHistory(const Duration(hours: 1))
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      hour = <DeviceSnapshot>[];
    }

    final List<DeviceSnapshot> recent = monitor.recentSnapshots;
    final List<SensorFacts> sensors = <SensorFacts>[
      for (final SensorSpec spec in SensorConfig.all)
        _facts(spec, monitor, settings, recent, hour),
    ];

    final List<AlertEvent> all = monitor.alerts;
    final Duration? since = monitor.sinceLastUpdate;

    return AssistantData(
      now: DateTime.now(),
      deviceName: monitor.deviceName,
      deviceId: monitor.deviceId,
      modeLabel: monitor.modeLabel,
      hasData: monitor.latest != null,
      offline: monitor.isOffline,
      sinceText: since == null ? 'belum ada data' : Fmt.ago(since),
      lastTime: monitor.latest?.timestamp,
      status: monitor.status,
      sensors: sensors,
      activeAlerts: all.where((a) => a.isActive).toList(),
      recentAlerts: all.where((a) => !a.isActive).take(5).toList(),
      soilPercent: monitor.latest?.soilMoisturePercent,
      connectionError: monitor.connectionError,
    );
  }

  static SensorFacts _facts(
    SensorSpec spec,
    MonitorProvider monitor,
    SettingsProvider settings,
    List<DeviceSnapshot> recent,
    List<DeviceSnapshot> hour,
  ) {
    final SensorEvaluation? ev = monitor.evaluationOf(spec.id);

    final List<double> hv = <double>[
      for (final DeviceSnapshot s in hour)
        if (s.valueOf(spec.id) != null) s.valueOf(spec.id)!,
    ];
    double? mn;
    double? mx;
    double? avg;
    if (hv.isNotEmpty) {
      mn = hv.reduce(math.min);
      mx = hv.reduce(math.max);
      avg = hv.fold<double>(0, (a, b) => a + b) / hv.length;
    }

    return SensorFacts(
      spec: spec,
      value: ev?.value,
      level: ev?.level ?? SensorLevel.unavailable,
      limit: settings.thresholdFor(spec),
      trend: _trend(spec, recent),
      hourCount: hv.length,
      hourMin: mn,
      hourMax: mx,
      hourAvg: avg,
    );
  }

  static String _trend(SensorSpec spec, List<DeviceSnapshot> snaps) {
    final List<DeviceSnapshot> pts =
        snaps.where((s) => s.valueOf(spec.id) != null).toList();
    if (pts.length < 3) return 'belum cukup data untuk melihat tren';

    final double first = pts.first.valueOf(spec.id)!;
    final double last = pts.last.valueOf(spec.id)!;
    double lo = first;
    double hi = first;
    for (final DeviceSnapshot s in pts) {
      final double v = s.valueOf(spec.id)!;
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }

    final Duration span = pts.last.timestamp.difference(pts.first.timestamp);
    final String spanText = span.inMinutes >= 1
        ? '${span.inMinutes} menit'
        : '${span.inSeconds} detik';
    final double delta = last - first;
    final double range = spec.maxValue - spec.minValue;

    String f(double v) =>
        '${Fmt.number(v, decimals: spec.decimals)} ${spec.unit}';

    if (delta.abs() < range * 0.03) {
      return 'stabil selama $spanText terakhir (${f(lo)} sampai ${f(hi)})';
    }
    return '${delta > 0 ? 'naik' : 'turun'} ${f(delta.abs())} dalam $spanText terakhir (sekarang ${f(last)})';
  }
}