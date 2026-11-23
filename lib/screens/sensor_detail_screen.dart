import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:monu/core/app_colors.dart';
import 'package:monu/core/app_dimens.dart';
import 'package:monu/core/app_text.dart';
import 'package:monu/core/formatters.dart';
import 'package:monu/models/device_snapshot.dart';
import 'package:monu/models/monitoring_status.dart';
import 'package:monu/models/sensor_spec.dart';
import 'package:monu/providers/monitor_provider.dart';
import 'package:monu/providers/settings_provider.dart';
import 'package:monu/repositories/sensor_repository.dart';
import 'package:monu/services/status_evaluator.dart';
import 'package:monu/widgets/forest_background.dart';
import 'package:monu/widgets/glass_card.dart';
import 'package:monu/widgets/page_header.dart';
import 'package:monu/widgets/status_chip.dart';
import 'package:monu/widgets/trend_chart.dart';
import 'package:provider/provider.dart';

enum _Range { hour, day, week }

extension _RangeX on _Range {
  String get label => switch (this) {
        _Range.hour => '1 jam',
        _Range.day => '24 jam',
        _Range.week => '7 hari',
      };

  Duration get duration => switch (this) {
        _Range.hour => const Duration(hours: 1),
        _Range.day => const Duration(hours: 24),
        _Range.week => const Duration(days: 7),
      };
}

/// Detail satu sensor: nilai sekarang, grafik, statistik, batas, penjelasan.
class SensorDetailScreen extends StatefulWidget {
  const SensorDetailScreen({super.key, required this.spec});

  final SensorSpec spec;

  @override
  State<SensorDetailScreen> createState() => _SensorDetailScreenState();
}

class _SensorDetailScreenState extends State<SensorDetailScreen> {
  _Range _range = _Range.hour;
  late Future<List<DeviceSnapshot>> _future;
  late DateTime _rangeEnd;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _rangeEnd = DateTime.now();
    _future = context.read<MonitorProvider>().loadHistory(_range.duration);
  }

  @override
  Widget build(BuildContext context) {
    final SensorSpec spec = widget.spec;
    final MonitorProvider monitor = context.watch<MonitorProvider>();
    final SettingsProvider settings = context.watch<SettingsProvider>();
    final SensorEvaluation? ev = monitor.evaluationOf(spec.id);
    final AlertLimit limit = settings.thresholdFor(spec);
    final bool stale = monitor.isOffline;
    final SensorLevel level = ev?.level ?? SensorLevel.unavailable;
    final Color color = stale ? AppColors.inkSoft : level.color;
    final Duration? since = monitor.sinceLastUpdate;

    return Scaffold(
      body: ForestBackground(
        strong: true,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              PageHeader(
                eyebrow: 'Detail sensor',
                title: spec.name,
                leading: CircleIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ---- nilai sekarang ----
                    GlassCard(
                      padding: const EdgeInsets.all(20),
                      tint: Color.alphaBlend(
                        color.withValues(alpha: 0.14),
                        Colors.white.withValues(alpha: 0.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(spec.icon, color: color, size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Nilai sekarang',
                                  style: AppText.bodySoft,
                                ),
                              ),
                              StatusChip(
                                label: stale ? 'Data lama' : level.label,
                                color: color,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                Fmt.number(ev?.value, decimals: spec.decimals),
                                style: AppText.value.copyWith(
                                  fontSize: 40,
                                  color: stale
                                      ? AppColors.inkSoft
                                      : AppColors.ink,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  spec.unitCaption,
                                  style: AppText.bodySoft,
                                ),
                              ),
                            ],
                          ),
                          if (spec.id == 'soilMoistureRaw' &&
                              monitor.latest?.soilMoisturePercent != null)
                            Text(
                              '≈ ${Fmt.number(monitor.latest!.soilMoisturePercent, decimals: 0)} % setelah kalibrasi',
                              style: AppText.caption,
                            ),
                          const SizedBox(height: 6),
                          Text(
                            since == null
                                ? 'Belum ada data diterima'
                                : 'Diperbarui ${Fmt.ago(since)}',
                            style: AppText.caption,
                          ),
                        ],
                      ),
                    ),

                    // ---- grafik ----
                    const SectionTitle(title: 'Grafik'),
                    GlassCard(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              for (final _Range r in _Range.values)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: _RangePill(
                                    label: r.label,
                                    selected: r == _range,
                                    onTap: () => setState(() {
                                      _range = r;
                                      _reload();
                                    }),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _buildChart(spec, limit),
                        ],
                      ),
                    ),

                    // ---- batas peringatan ----
                    const SectionTitle(title: 'Batas Peringatan'),
                    GlassCard(
                      showShadow: false,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LimitRow(
                            color: AppColors.warning,
                            title: 'Waspada',
                            value:
                                '${spec.direction == ThresholdDirection.high ? '≥' : '≤'} ${Fmt.number(limit.warning, decimals: spec.decimals)} ${spec.unit}',
                          ),
                          const SizedBox(height: 10),
                          _LimitRow(
                            color: AppColors.danger,
                            title: 'Perlu Pemeriksaan',
                            value:
                                '${spec.direction == ThresholdDirection.high ? '≥' : '≤'} ${Fmt.number(limit.check, decimals: spec.decimals)} ${spec.unit}',
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Nilai awal hanya contoh. Ubah di Profil setelah kalibrasi dan pengujian sensor.',
                            style: AppText.caption,
                          ),
                          if (!spec.canTriggerCheckAlone) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Sensor ini sendirian tidak membuat status menjadi "Perlu Pemeriksaan". Statusnya naik jika ada indikator lain yang ikut melewati ambang.',
                              style: AppText.caption,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // ---- penjelasan sensor ----
                    const SectionTitle(title: 'Tentang Sensor Ini'),
                    GlassCard(
                      showShadow: false,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _InfoBlock(title: 'Fungsi', text: spec.description),
                          const SizedBox(height: 12),
                          _InfoBlock(
                            title: 'Cara membaca',
                            text: spec.interpretation,
                          ),
                          const SizedBox(height: 12),
                          _InfoBlock(title: 'Batasan', text: spec.limitation),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChart(SensorSpec spec, AlertLimit limit) {
    return FutureBuilder<List<DeviceSnapshot>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 230,
            child: Center(
              child: CircularProgressIndicator(color: AppColors.forest),
            ),
          );
        }
        if (snap.hasError) {
          return _Note(
            icon: Icons.cloud_off,
            text: describeRepositoryError(snap.error!),
          );
        }
        final List<DeviceSnapshot> list = snap.data ?? <DeviceSnapshot>[];
        if (list.isEmpty) {
          return const _Note(
            icon: Icons.hourglass_empty,
            text:
                'Belum ada riwayat pada rentang ini. Riwayat terisi saat perangkat menyimpan data ke database.',
          );
        }

        // Statistik dari seluruh data yang dimuat.
        final List<double> vals = <double>[
          for (final DeviceSnapshot s in list)
            if (s.valueOf(spec.id) != null) s.valueOf(spec.id)!,
        ];
        double? maxV;
        double? minV;
        double? avg;
        if (vals.isNotEmpty) {
          maxV = vals.reduce(math.max);
          minV = vals.reduce(math.min);
          avg = vals.fold<double>(0, (a, b) => a + b) / vals.length;
        }

        // Kurangi jumlah titik supaya grafik tetap ringan.
        final int step = math.max(1, (list.length / 240).ceil());
        final List<TrendPoint> points = <TrendPoint>[
          for (int i = 0; i < list.length; i += step)
            TrendPoint(list[i].timestamp, list[i].valueOf(spec.id)),
        ];

        return Column(
          children: [
            TrendChart(
              points: points,
              start: _rangeEnd.subtract(_range.duration),
              end: _rangeEnd,
              unit: spec.unit,
              decimals: spec.decimals,
              minSpan: (spec.maxValue - spec.minValue) * 0.06,
              warningLine: limit.warning,
              checkLine: limit.check,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatBox(
                    label: 'Tertinggi',
                    value: Fmt.number(maxV, decimals: spec.decimals),
                    unit: spec.unit,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatBox(
                    label: 'Terendah',
                    value: Fmt.number(minV, decimals: spec.decimals),
                    unit: spec.unit,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatBox(
                    label: 'Rata-rata',
                    value: Fmt.number(avg, decimals: spec.decimals),
                    unit: spec.unit,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _RangePill extends StatelessWidget {
  const _RangePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.forestDeep
              : Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: AppText.label.copyWith(
            fontSize: 12.5,
            color: selected ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.caption.copyWith(fontSize: 11)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$value $unit',
              style: AppText.label.copyWith(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _LimitRow extends StatelessWidget {
  const _LimitRow({
    required this.color,
    required this.title,
    required this.value,
  });

  final Color color;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: AppText.body)),
        Text(value, style: AppText.label),
      ],
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppText.label.copyWith(color: AppColors.forest),
        ),
        const SizedBox(height: 3),
        Text(text, style: AppText.bodySoft),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icon, size: 32, color: AppColors.inkSoft),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center, style: AppText.bodySoft),
        ],
      ),
    );
  }
}