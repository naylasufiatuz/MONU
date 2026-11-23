import 'package:flutter/material.dart';
import 'package:monu/core/app_colors.dart';
import 'package:monu/core/app_text.dart';
import 'package:monu/core/formatters.dart';
import 'package:monu/models/alert_event.dart';
import 'package:monu/models/monitoring_status.dart';
import 'package:monu/widgets/glass_card.dart';
import 'package:monu/widgets/status_chip.dart';

String _when(DateTime t, DateTime now) {
  final bool today =
      t.year == now.year && t.month == now.month && t.day == now.day;
  return today ? Fmt.clock(t) : Fmt.dateTime(t);
}

/// Satu baris peringatan: judul, penjelasan, waktu mulai/pulih.
class AlertTile extends StatelessWidget {
  const AlertTile({
    super.key,
    required this.event,
    this.compact = false,
    this.onExplain,
  });

  final AlertEvent event;
  final bool compact;

  /// Jika diisi, muncul tombol "Tanya MONU soal ini".
  final VoidCallback? onExplain;

  @override
  Widget build(BuildContext context) {
    final Color color = event.level.color;
    final DateTime now = DateTime.now();
    final IconData icon = event.kind == AlertKind.deviceOffline
        ? Icons.wifi_off
        : event.level.icon;

    final double? peak = event.peakValue;
    final bool showPeak = !compact &&
        event.kind == AlertKind.threshold &&
        peak != null &&
        peak != event.value;

    return GlassCard(
      radius: 22,
      padding: EdgeInsets.all(compact ? 14 : 16),
      showShadow: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: AppText.label.copyWith(fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusChip(
                      label: event.isActive ? 'Aktif' : 'Selesai',
                      color: event.isActive ? color : AppColors.safe,
                      dense: true,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  event.message,
                  maxLines: compact ? 2 : null,
                  overflow: compact ? TextOverflow.ellipsis : null,
                  style: AppText.bodySoft.copyWith(fontSize: 12.5),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    _Meta(
                      icon: Icons.schedule,
                      text: 'Mulai ${_when(event.startedAt, now)}',
                    ),
                    if (event.resolvedAt != null)
                      _Meta(
                        icon: Icons.check,
                        text: 'Pulih ${_when(event.resolvedAt!, now)}',
                      ),
                    if (showPeak)
                      _Meta(
                        icon: Icons.trending_up,
                        text:
                            'Puncak ${Fmt.number(peak, decimals: event.spec!.decimals)} ${event.spec!.unit}',
                      ),
                  ],
                ),
                if (onExplain != null && !compact) ...[
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: onExplain,
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('Tanya MONU soal ini'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.inkSoft),
        const SizedBox(width: 4),
        Text(text, style: AppText.caption.copyWith(fontSize: 11.5)),
      ],
    );
  }
}