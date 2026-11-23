import 'package:flutter/material.dart';
import 'package:monu/core/app_colors.dart';
import 'package:monu/core/app_dimens.dart';
import 'package:monu/core/app_text.dart';
import 'package:monu/models/alert_event.dart';
import 'package:monu/models/monitoring_status.dart';
import 'package:monu/providers/monitor_provider.dart';
import 'package:monu/widgets/alert_tile.dart';
import 'package:monu/widgets/forest_background.dart';
import 'package:monu/widgets/glass_card.dart';
import 'package:monu/widgets/glass_nav_bar.dart';
import 'package:monu/widgets/page_header.dart';
import 'package:provider/provider.dart';
import 'package:monu/screens/assistant_screen.dart';

enum _AlertFilter { all, active, resolved, warning, check }

extension _AlertFilterX on _AlertFilter {
  String get label => switch (this) {
        _AlertFilter.all => 'Semua',
        _AlertFilter.active => 'Aktif',
        _AlertFilter.resolved => 'Selesai',
        _AlertFilter.warning => 'Waspada',
        _AlertFilter.check => 'Perlu Pemeriksaan',
      };
}

/// Tab Peringatan: daftar kejadian, bisa difilter.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  _AlertFilter _filter = _AlertFilter.all;

  bool _match(AlertEvent e) => switch (_filter) {
        _AlertFilter.all => true,
        _AlertFilter.active => e.isActive,
        _AlertFilter.resolved => !e.isActive,
        _AlertFilter.warning => e.level == SensorLevel.warning,
        _AlertFilter.check => e.level == SensorLevel.check,
      };

  @override
  Widget build(BuildContext context) {
    final MonitorProvider monitor = context.watch<MonitorProvider>();
    final int activeCount = monitor.activeAlerts.length;
    final List<AlertEvent> shown = monitor.alerts.where(_match).toList();

    return ForestBackground(
      strong: true,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: kNavSpace),
          children: [
            const PageHeader(
              eyebrow: 'Kejadian yang terdeteksi',
              title: 'Peringatan',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _SummaryCard(activeCount: activeCount),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  for (final _AlertFilter f in _AlertFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _FilterPill(
                        label: f.label,
                        selected: f == _filter,
                        onTap: () => setState(() => _filter = f),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  if (shown.isEmpty)
                    GlassCard(
                      padding: const EdgeInsets.all(24),
                      showShadow: false,
                      child: Column(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            size: 36,
                            color: AppColors.safe,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            monitor.alerts.isEmpty
                                ? 'Belum ada peringatan'
                                : 'Tidak ada peringatan pada filter ini',
                            style: AppText.title,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Peringatan muncul saat ada pembacaan yang melewati ambang.',
                            textAlign: TextAlign.center,
                            style: AppText.bodySoft,
                          ),
                        ],
                      ),
                    )
                  else
                    for (final AlertEvent e in shown)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AlertTile(
                          event: e,
                          onExplain: () => openAssistant(
                            context,
                            question:
                                'Jelaskan peringatan "${e.title}": apa artinya, kemungkinan penyebabnya, dan apa yang perlu kuperiksa?',
                          ),
                        ),
                      ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppColors.inkSoft,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Peringatan adalah tanda untuk memeriksa kondisi prototipe, bukan konfirmasi kebakaran. Peringatan tercatat selama app terbuka.',
                          style: AppText.caption,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.activeCount});

  final int activeCount;

  @override
  Widget build(BuildContext context) {
    final bool clear = activeCount == 0;
    final Color color = clear ? AppColors.safe : AppColors.warning;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      tint: Color.alphaBlend(
        color.withValues(alpha: 0.14),
        Colors.white.withValues(alpha: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              clear
                  ? Icons.check_circle_outline
                  : Icons.notifications_active_outlined,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clear
                      ? 'Tidak ada peringatan aktif'
                      : '$activeCount peringatan aktif',
                  style: AppText.title,
                ),
                Text(
                  clear
                      ? 'Semua pembacaan dalam batas.'
                      : 'Periksa parameter yang melewati ambang.',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.forestDeep
              : Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: AppText.label.copyWith(
            fontSize: 13,
            color: selected ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }
}