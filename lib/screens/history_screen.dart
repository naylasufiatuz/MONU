import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:monu/config/sensor_config.dart';
import 'package:monu/core/app_colors.dart';
import 'package:monu/core/app_dimens.dart';
import 'package:monu/core/app_text.dart';
import 'package:monu/core/formatters.dart';
import 'package:monu/models/device_snapshot.dart';
import 'package:monu/models/sensor_spec.dart';
import 'package:monu/providers/monitor_provider.dart';
import 'package:monu/providers/settings_provider.dart';
import 'package:monu/widgets/forest_background.dart';
import 'package:monu/widgets/glass_card.dart';
import 'package:monu/widgets/glass_nav_bar.dart';
import 'package:monu/widgets/page_header.dart';
import 'package:monu/widgets/status_chip.dart';
import 'package:monu/widgets/trend_chart.dart';
import 'package:provider/provider.dart';

enum _HistoryRange { hour, day, week }

extension _HistoryRangeX on _HistoryRange {
  String get label => switch (this) {
        _HistoryRange.hour => '1 jam',
        _HistoryRange.day => '24 jam',
        _HistoryRange.week => '7 hari',
      };

  Duration get duration => switch (this) {
        _HistoryRange.hour => const Duration(hours: 1),
        _HistoryRange.day => const Duration(hours: 24),
        _HistoryRange.week => const Duration(days: 7),
      };
}

/// Halaman Riwayat: grafik tren per sensor, statistik rentang waktu, dan riwayat pembacaan.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late SensorSpec _selectedSpec;
  _HistoryRange _range = _HistoryRange.hour;
  late Future<List<DeviceSnapshot>> _future;
  late DateTime _rangeEnd;
  String? _lastModeLabel;

  @override
  void initState() {
    super.initState();
    _selectedSpec = SensorConfig.all.first;
    _reload();
  }

  void _reload() {
    _rangeEnd = DateTime.now();
    _future = context.read<MonitorProvider>().loadHistory(_range.duration);
  }

  @override
  Widget build(BuildContext context) {
    final MonitorProvider monitor = context.watch<MonitorProvider>();
    final SettingsProvider settings = context.watch<SettingsProvider>();
    final AlertLimit limit = settings.thresholdFor(_selectedSpec);

    if (_lastModeLabel != null && _lastModeLabel != monitor.modeLabel) {
      _lastModeLabel = monitor.modeLabel;
      _reload();
    } else {
      _lastModeLabel ??= monitor.modeLabel;
    }

    return ForestBackground(
      strong: true,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.forest,
          onRefresh: () async {
            await monitor.refresh();
            setState(_reload);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: kNavSpace),
            children: [
              PageHeader(
                eyebrow: 'Analisis & Tren Sensor',
                title: 'Riwayat',
                trailing: CircleIconButton(
                  icon: Icons.refresh_rounded,
                  onTap: () => setState(_reload),
                ),
              ),

              // Pemilih Sensor (Chips)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    for (final SensorSpec s in SensorConfig.all)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _SensorChoiceChip(
                          spec: s,
                          selected: s.id == _selectedSpec.id,
                          onTap: () {
                            if (_selectedSpec.id != s.id) {
                              setState(() => _selectedSpec = s);
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Pemilih Rentang Waktu
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text('Rentang:', style: AppText.caption),
                    const SizedBox(width: 10),
                    for (final _HistoryRange r in _HistoryRange.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(r.label),
                          selected: _range == r,
                          onSelected: (val) {
                            if (val && _range != r) {
                              setState(() {
                                _range = r;
                                _reload();
                              });
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: FutureBuilder<List<DeviceSnapshot>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const GlassCard(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: CircularProgressIndicator(color: AppColors.forest),
                        ),
                      );
                    }

                    final List<DeviceSnapshot> loaded = snapshot.data ?? <DeviceSnapshot>[];
                    final DateTime endTime = DateTime.now().isAfter(_rangeEnd)
                        ? DateTime.now()
                        : _rangeEnd;
                    final DateTime start = endTime.subtract(_range.duration);

                    // Gabungkan riwayat dari repository dengan snapshot live terbaru
                    // agar mode ESP32 langsung menampilkan titik data secara real-time.
                    final Map<int, DeviceSnapshot> mergedMap = <int, DeviceSnapshot>{
                      for (final DeviceSnapshot s in loaded)
                        s.timestamp.millisecondsSinceEpoch: s,
                      for (final DeviceSnapshot s in monitor.recentSnapshots)
                        if (!s.timestamp.isBefore(start))
                          s.timestamp.millisecondsSinceEpoch: s,
                    };
                    final List<DeviceSnapshot> list = mergedMap.values.toList()
                      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

                    // Buat titik grafik
                    final List<TrendPoint> points = <TrendPoint>[
                      for (final DeviceSnapshot snap in list)
                        TrendPoint(snap.timestamp, snap.valueOf(_selectedSpec.id)),
                    ];

                    // Kumpulkan nilai yang valid untuk statistik
                    final List<double> validValues = points
                        .where((p) => p.value != null)
                        .map((p) => p.value!)
                        .toList();

                    // Hitung statistik
                    final double? minVal = validValues.isEmpty
                        ? null
                        : validValues.reduce(math.min);
                    final double? maxVal = validValues.isEmpty
                        ? null
                        : validValues.reduce(math.max);
                    final double? avgVal = validValues.isEmpty
                        ? null
                        : validValues.reduce((a, b) => a + b) / validValues.length;

                    final double? currentVal = monitor.latest?.valueOf(_selectedSpec.id);

                    // Hitung jumlah data dan aktivitas pompa
                    final int pumpActiveCount = list.where((s) => s.pumpActive).length;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Kartu Grafik Utama
                        GlassCard(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(_selectedSpec.icon, color: AppColors.forest, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Grafik ${_selectedSpec.name}',
                                      style: AppText.title,
                                    ),
                                  ),
                                  Text(
                                    currentVal != null
                                        ? '${Fmt.number(currentVal, decimals: _selectedSpec.decimals)} ${_selectedSpec.unit}'
                                        : 'Tidak tersedia',
                                    style: AppText.label.copyWith(color: AppColors.forest),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (points.isEmpty || validValues.isEmpty)
                                SizedBox(
                                  height: 200,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.show_chart,
                                          size: 40,
                                          color: AppColors.inkSoft,
                                        ),
                                        const SizedBox(height: 10),
                                        Text('Belum ada riwayat data', style: AppText.body),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Data akan terakumulasi seiring perangkat ESP32 berjalan.',
                                          textAlign: TextAlign.center,
                                          style: AppText.caption,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                TrendChart(
                                  points: points,
                                  start: start,
                                  end: endTime,
                                  unit: _selectedSpec.unit,
                                  decimals: _selectedSpec.decimals,
                                  minSpan: _selectedSpec.decimals == 0 ? 5 : 2,
                                  color: AppColors.forest,
                                  warningLine: limit.warning,
                                  checkLine: limit.check,
                                  height: 220,
                                ),
                              const SizedBox(height: 10),
                              // Keterangan garis ambang batas
                              Wrap(
                                spacing: 14,
                                runSpacing: 6,
                                children: [
                                  _LegendItem(
                                    color: AppColors.forest,
                                    label: 'Nilai Terbaca',
                                  ),
                                  _LegendItem(
                                    color: AppColors.warning,
                                    label: 'Waspada (≥ ${Fmt.number(limit.warning, decimals: _selectedSpec.decimals)} ${_selectedSpec.unit})',
                                  ),
                                  _LegendItem(
                                    color: AppColors.danger,
                                    label: 'Pemeriksaan (≥ ${Fmt.number(limit.check, decimals: _selectedSpec.decimals)} ${_selectedSpec.unit})',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Ringkasan Statistik
                        Text('Statistik (${_range.label})', style: AppText.title),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                label: 'Rata-rata',
                                value: avgVal != null
                                    ? Fmt.number(avgVal, decimals: _selectedSpec.decimals)
                                    : '-',
                                unit: _selectedSpec.unit,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StatCard(
                                label: 'Minimum',
                                value: minVal != null
                                    ? Fmt.number(minVal, decimals: _selectedSpec.decimals)
                                    : '-',
                                unit: _selectedSpec.unit,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StatCard(
                                label: 'Maksimum',
                                value: maxVal != null
                                    ? Fmt.number(maxVal, decimals: _selectedSpec.decimals)
                                    : '-',
                                unit: _selectedSpec.unit,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Aktivitas Pompa Air pada Rentang Terpilih
                        GlassCard(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.safe.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.water_drop,
                                  color: AppColors.safe,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Aktivitas Pompa Air', style: AppText.title),
                                    Text(
                                      pumpActiveCount > 0
                                          ? 'Terdeteksi $pumpActiveCount siklus penyiraman aktif pada rentang ${_range.label}.'
                                          : 'Pompa dalam kondisi siaga (standby) selama ${_range.label} terakhir.',
                                      style: AppText.caption,
                                    ),
                                  ],
                                ),
                              ),
                              StatusChip(
                                label: monitor.latest?.pumpActive == true ? 'Aktif' : 'Standby',
                                color: monitor.latest?.pumpActive == true
                                    ? AppColors.safe
                                    : AppColors.inkSoft,
                                dense: true,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Tabel Log Titik Data Terakhir
                        Text('Log Titik Pengukuran Terakhir', style: AppText.title),
                        const SizedBox(height: 8),
                        if (list.isEmpty)
                          GlassCard(
                            padding: const EdgeInsets.all(20),
                            child: Center(
                              child: Text(
                                'Tidak ada log pembacaan.',
                                style: AppText.bodySoft,
                              ),
                            ),
                          )
                        else
                          Builder(
                            builder: (context) {
                              final List<DeviceSnapshot> latestLogs =
                                  list.reversed.take(8).toList();
                              return GlassCard(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                child: Column(
                                  children: [
                                    for (int i = 0; i < latestLogs.length; i++) ...[
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.access_time_rounded,
                                              size: 16,
                                              color: AppColors.inkSoft,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              Fmt.clock(latestLogs[i].timestamp),
                                              style: AppText.caption,
                                            ),
                                            const Spacer(),
                                            Text(
                                              latestLogs[i].valueOf(_selectedSpec.id) != null
                                                  ? '${Fmt.number(latestLogs[i].valueOf(_selectedSpec.id), decimals: _selectedSpec.decimals)} ${_selectedSpec.unit}'
                                                  : 'Tidak tersedia',
                                              style: AppText.label.copyWith(
                                                color: latestLogs[i].valueOf(_selectedSpec.id) == null
                                                    ? AppColors.inkSoft
                                                    : AppColors.ink,
                                              ),
                                            ),
                                            if (latestLogs[i].fireDetected) ...[
                                              const SizedBox(width: 6),
                                              const Icon(
                                                Icons.local_fire_department,
                                                size: 14,
                                                color: AppColors.danger,
                                              ),
                                            ],
                                            if (latestLogs[i].pumpActive) ...[
                                              const SizedBox(width: 6),
                                              const Icon(
                                                Icons.water_drop,
                                                size: 14,
                                                color: AppColors.safe,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (i < latestLogs.length - 1)
                                        Divider(
                                          height: 1,
                                          color: AppColors.forest.withValues(alpha: 0.08),
                                        ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SensorChoiceChip extends StatelessWidget {
  const _SensorChoiceChip({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final SensorSpec spec;
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              spec.icon,
              size: 16,
              color: selected ? Colors.white : AppColors.ink,
            ),
            const SizedBox(width: 6),
            Text(
              spec.shortName,
              style: AppText.label.copyWith(
                fontSize: 13,
                color: selected ? Colors.white : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      child: Column(
        children: [
          Text(label, style: AppText.caption),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppText.title.copyWith(fontSize: 18),
            ),
          ),
          Text(unit, style: AppText.caption.copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: AppText.caption.copyWith(fontSize: 11)),
      ],
    );
  }
}
