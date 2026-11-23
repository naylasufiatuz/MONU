import 'package:flutter/material.dart';
import 'package:monu/config/sensor_config.dart';
import 'package:monu/core/app_colors.dart';
import 'package:monu/core/app_text.dart';
import 'package:monu/core/formatters.dart';
import 'package:monu/core/routes.dart';
import 'package:monu/models/alert_event.dart';
import 'package:monu/models/device_snapshot.dart';
import 'package:monu/models/monitoring_status.dart';
import 'package:monu/models/sensor_spec.dart';
import 'package:monu/providers/auth_provider.dart';
import 'package:monu/providers/monitor_provider.dart';
import 'package:monu/screens/profile_screen.dart';
import 'package:monu/screens/sensor_detail_screen.dart';
import 'package:monu/widgets/alert_tile.dart';
import 'package:monu/widgets/fade_slide_in.dart';
import 'package:monu/widgets/forest_background.dart';
import 'package:monu/widgets/glass_card.dart';
import 'package:monu/widgets/glass_nav_bar.dart';
import 'package:monu/widgets/monu_mark.dart';
import 'package:monu/widgets/page_header.dart';
import 'package:monu/widgets/sensor_card.dart';
import 'package:monu/widgets/status_chip.dart';
import 'package:provider/provider.dart';
import 'package:monu/screens/assistant_screen.dart';

/// Tab Ringkasan: status keseluruhan, kartu sensor, peringatan terbaru.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onSeeAlerts});

  final VoidCallback onSeeAlerts;

  @override
  Widget build(BuildContext context) {
    final MonitorProvider monitor = context.watch<MonitorProvider>();
    final AuthProvider auth = context.watch<AuthProvider>();
    final String initial =
        auth.name.isEmpty ? '?' : auth.name.substring(0, 1).toUpperCase();
    final List<AlertEvent> latestAlerts = monitor.alerts.take(3).toList();

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
              PageHeader(
                eyebrow: 'Halo, ${auth.name}',
                title: 'Ringkasan',
                leading: const MonuMark(size: 40),
                trailing: _AvatarButton(
                  initial: initial,
                  onTap: () => Navigator.of(context)
                      .push(fadeRoute(const ProfileScreen())),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FadeSlideIn(child: _StatusCard(monitor: monitor)),
                    const SizedBox(height: 16),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 80),
                      child: _AssistantCard(
                        onTap: () => openAssistant(context),
                      ),
                    ),
                    const SectionTitle(title: 'Data Sensor'),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 120),
                      child: _SensorGrid(monitor: monitor),
                    ),
                    SectionTitle(
                      title: 'Peringatan Terbaru',
                      trailing: TextButton(
                        onPressed: onSeeAlerts,
                        child: const Text('Lihat semua'),
                      ),
                    ),
                    if (latestAlerts.isEmpty)
                      GlassCard(
                        showShadow: false,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              color: AppColors.safe,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Belum ada peringatan.',
                                style: AppText.body,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      for (final AlertEvent e in latestAlerts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AlertTile(event: e, compact: true),
                        ),
                    const SizedBox(height: 14),
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
                            'MONU adalah indikator untuk memeriksa kondisi prototipe, bukan konfirmasi kebakaran. Nilai hanya mewakili sekitar sensor pada miniatur.',
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
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({required this.initial, required this.onTap});

  final String initial;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.forest,
          border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
        ),
        child: Text(
          initial,
          style: AppText.label.copyWith(color: Colors.white, fontSize: 15),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kartu status besar
// ---------------------------------------------------------------------------

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.monitor});

  final MonitorProvider monitor;

  @override
  Widget build(BuildContext context) {
    final MonitoringStatus status = monitor.status;
    final Color color = status.color;
    final bool offline = monitor.isOffline;
    final Duration? since = monitor.sinceLastUpdate;
    final DeviceSnapshot? snap = monitor.latest;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      tint: Color.alphaBlend(
        color.withValues(alpha: 0.16),
        Colors.white.withValues(alpha: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(status.icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      monitor.deviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.title,
                    ),
                    Text(
                      'ID: ${monitor.deviceId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(
                label: offline ? 'Offline' : 'Online',
                color: offline ? AppColors.inkSoft : AppColors.safe,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Status pemantauan', style: AppText.caption),
          const SizedBox(height: 2),
          Text(
            status.label,
            style: AppText.display.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(status.description, style: AppText.bodySoft),
          if (monitor.connectionError != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 16,
                  color: AppColors.danger,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    monitor.connectionError!,
                    style: AppText.caption.copyWith(color: AppColors.danger),
                  ),
                ),
              ],
            ),
          ],
          if (offline && snap != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.inkSoft.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 16, color: AppColors.inkSoft),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Menampilkan data terakhir, bukan data terbaru.',
                      style: AppText.caption,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Divider(height: 1, color: AppColors.forest.withValues(alpha: 0.12)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: _MetaItem(
                  label: 'Pembaruan terakhir',
                  value: since == null ? 'Belum ada data' : Fmt.ago(since),
                  sub: snap == null ? null : Fmt.clock(snap.timestamp),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: _MetaItem(
                  label: 'Sumber data',
                  value: monitor.modeLabel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.label, required this.value, this.sub});

  final String label;
  final String value;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.caption),
        const SizedBox(height: 2),
        Text(value, style: AppText.label.copyWith(fontSize: 13.5)),
        if (sub != null) Text(sub!, style: AppText.caption),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Kartu sensor 2 kolom
// ---------------------------------------------------------------------------

class _SensorGrid extends StatelessWidget {
  const _SensorGrid({required this.monitor});

  final MonitorProvider monitor;

  @override
  Widget build(BuildContext context) {
    final List<SensorSpec> specs = SensorConfig.all;

    Widget card(BuildContext context, SensorSpec spec) {
      return SensorCard(
        spec: spec,
        evaluation: monitor.evaluationOf(spec.id),
        spark: monitor.sparkValues(spec.id),
        stale: monitor.isOffline,
        onTap: () => Navigator.of(context)
            .push(fadeRoute(SensorDetailScreen(spec: spec))),
      );
    }

    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < specs.length; i += 2) {
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: card(context, specs[i])),
              const SizedBox(width: 16),
              Expanded(
                child: i + 1 < specs.length
                    ? card(context, specs[i + 1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
      if (i + 2 < specs.length) rows.add(const SizedBox(height: 16));
    }
    return Column(children: rows);
  }
  class _AssistantCard extends StatelessWidget {
  const _AssistantCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.forest,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tanya MONU', style: AppText.title),
                const SizedBox(height: 2),
                Text(
                  'Asisten AI untuk memahami data dan peringatan',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.inkSoft),
        ],
      ),
    );
  }
}
}