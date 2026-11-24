import 'package:flutter/material.dart';
import 'package:monu/config/sensor_config.dart';
import 'package:monu/core/app_colors.dart';
import 'package:monu/core/app_text.dart';
import 'package:monu/core/formatters.dart';
import 'package:monu/core/routes.dart';
import 'package:monu/models/sensor_spec.dart';
import 'package:monu/providers/monitor_provider.dart';
import 'package:monu/providers/settings_provider.dart';
import 'package:monu/screens/sensor_detail_screen.dart';
import 'package:monu/widgets/forest_background.dart';
import 'package:monu/widgets/glass_card.dart';
import 'package:monu/widgets/glass_nav_bar.dart';
import 'package:monu/widgets/page_header.dart';
import 'package:monu/widgets/sensor_card.dart';
import 'package:monu/widgets/status_chip.dart';
import 'package:provider/provider.dart';

/// Tab Sensor: semua parameter dengan nilai, satuan, status, dan batasnya.
class SensorsScreen extends StatelessWidget {
  const SensorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final MonitorProvider monitor = context.watch<MonitorProvider>();
    final SettingsProvider settings = context.watch<SettingsProvider>();
    final Duration? since = monitor.sinceLastUpdate;
    final bool offline = monitor.isOffline;

    return ForestBackground(
      strong: true,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.forest,
          onRefresh: monitor.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: kNavSpace),
            children: [
              const PageHeader(
                eyebrow: 'Pembacaan terbaru',
                title: 'Data Sensor',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StatusChip(
                          label: offline ? 'Offline' : 'Online',
                          color: offline ? AppColors.inkSoft : AppColors.safe,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            since == null
                                ? 'Belum ada data diterima'
                                : 'Diperbarui ${Fmt.ago(since)}',
                            style: AppText.caption,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    for (final SensorSpec spec in SensorConfig.all)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: SensorListCard(
                          spec: spec,
                          evaluation: monitor.evaluationOf(spec.id),
                          limit: settings.thresholdFor(spec),
                          spark: monitor.sparkValues(spec.id),
                          stale: offline,
                          soilPercent: monitor.latest?.soilMoisturePercent,
                          onTap: () => Navigator.of(context).push(
                            fadeRoute(SensorDetailScreen(spec: spec)),
                          ),
                        ),
                      ),

                    // Status Aktuator Pompa Air & Relay (GPIO 19)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: (monitor.latest?.pumpActive == true
                                        ? AppColors.safe
                                        : AppColors.inkSoft)
                                    .withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.water_drop,
                                color: monitor.latest?.pumpActive == true
                                    ? AppColors.safe
                                    : AppColors.inkSoft,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Pompa Air (Relay GPIO 19)', style: AppText.title),
                                  Text(
                                    monitor.latest?.pumpActive == true
                                        ? 'Penyiraman sedang aktif'
                                        : 'Standby / Tidak menyiram',
                                    style: AppText.caption,
                                  ),
                                ],
                              ),
                            ),
                            StatusChip(
                              label: monitor.latest?.pumpActive == true
                                  ? 'MENYIRAM (ON)'
                                  : 'OFF',
                              color: monitor.latest?.pumpActive == true
                                  ? AppColors.safe
                                  : AppColors.inkSoft,
                            ),
                          ],
                        ),
                      ),
                    ),
                    GlassCard(
                      showShadow: false,
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 18,
                            color: AppColors.inkSoft,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Kelembapan tanah dan MQ-2 ditampilkan sebagai nilai mentah ADC (belum dikalibrasi, bukan ppm). Sensor yang gagal dibaca ditandai "tidak tersedia", tidak diganti angka perkiraan.',
                              style: AppText.caption,
                            ),
                          ),
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
}