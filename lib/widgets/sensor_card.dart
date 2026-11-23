import 'package:flutter/material.dart';
import 'package:monu/core/app_colors.dart';
import 'package:monu/core/app_text.dart';
import 'package:monu/core/formatters.dart';
import 'package:monu/models/monitoring_status.dart';
import 'package:monu/models/sensor_spec.dart';
import 'package:monu/services/status_evaluator.dart';
import 'package:monu/widgets/glass_card.dart';
import 'package:monu/widgets/sparkline.dart';
import 'package:monu/widgets/status_chip.dart';

/// Teks batas peringatan, contoh: "Waspada ≥ 35 °C · Pemeriksaan ≥ 40 °C".
String limitsText(SensorSpec spec, AlertLimit t) {
  final String sign = spec.direction == ThresholdDirection.high ? '≥' : '≤';
  final String w = Fmt.number(t.warning, decimals: spec.decimals);
  final String c = Fmt.number(t.check, decimals: spec.decimals);
  return 'Waspada $sign $w ${spec.unit} · Pemeriksaan $sign $c ${spec.unit}';
}

/// Kartu sensor ringkas (dipakai di Ringkasan, 2 kolom).
class SensorCard extends StatelessWidget {
  const SensorCard({
    super.key,
    required this.spec,
    required this.evaluation,
    required this.spark,
    required this.stale,
    required this.onTap,
  });

  final SensorSpec spec;
  final SensorEvaluation? evaluation;
  final List<double> spark;

  /// true = perangkat offline, nilai yang tampil adalah data lama.
  final bool stale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final SensorLevel level = evaluation?.level ?? SensorLevel.unavailable;
    final double? value = evaluation?.value;
    final Color color = stale ? AppColors.inkSoft : level.color;
    final double minSpan = (spec.maxValue - spec.minValue) * 0.06;

    return GlassCard(
      onTap: onTap,
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(spec.icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  spec.shortName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.label,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    Fmt.number(value, decimals: spec.decimals),
                    style: AppText.value.copyWith(
                      color: stale ? AppColors.inkSoft : AppColors.ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(spec.unit, style: AppText.caption),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: StatusChip(
              label: stale ? 'Data lama' : level.label,
              color: color,
              dense: true,
            ),
          ),
          const SizedBox(height: 16),
          Sparkline(values: spark, color: color, height: 32, minSpan: minSpan),
        ],
      ),
    );
  }
}

/// Kartu sensor lebar (dipakai di tab Sensor).
class SensorListCard extends StatelessWidget {
  const SensorListCard({
    super.key,
    required this.spec,
    required this.evaluation,
    required this.limit,
    required this.spark,
    required this.stale,
    required this.soilPercent,
    required this.onTap,
  });

  final SensorSpec spec;
  final SensorEvaluation? evaluation;
  final AlertLimit limit;
  final List<double> spark;
  final bool stale;
  final double? soilPercent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final SensorLevel level = evaluation?.level ?? SensorLevel.unavailable;
    final double? value = evaluation?.value;
    final Color color = stale ? AppColors.inkSoft : level.color;
    final double minSpan = (spec.maxValue - spec.minValue) * 0.06;

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(spec.icon, size: 24, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(spec.name, style: AppText.title),
                    Text(spec.unitCaption, style: AppText.caption),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(
                label: stale ? 'Data lama' : level.label,
                color: color,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Fmt.number(value, decimals: spec.decimals),
                style: AppText.value.copyWith(
                  fontSize: 34,
                  color: stale ? AppColors.inkSoft : AppColors.ink,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(spec.unit, style: AppText.bodySoft),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Sparkline(
                  values: spark,
                  color: color,
                  height: 40,
                  minSpan: minSpan,
                ),
              ),
            ],
          ),
          if (value == null) ...[
            const SizedBox(height: 8),
            Text(
              'Sensor gagal dibaca. Nilai tidak diganti angka perkiraan.',
              style: AppText.caption.copyWith(color: AppColors.danger),
            ),
          ],
          if (spec.id == 'soilMoistureRaw' && soilPercent != null) ...[
            const SizedBox(height: 8),
            Text(
              '≈ ${Fmt.number(soilPercent, decimals: 0)} % setelah kalibrasi',
              style: AppText.caption,
            ),
          ],
          const SizedBox(height: 16),
          Divider(height: 1, color: AppColors.forest.withValues(alpha: 0.10)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.rule, size: 15, color: AppColors.inkSoft),
              const SizedBox(width: 8),
              Expanded(
                child: Text(limitsText(spec, limit), style: AppText.caption),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.inkSoft,
              ),
            ],
          ),
        ],
      ),
    );
  }
}