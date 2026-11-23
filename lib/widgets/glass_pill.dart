import 'package:flutter/material.dart';
import 'package:monu/core/app_colors.dart';
import 'package:monu/core/app_dimens.dart';
import 'package:monu/widgets/glass_card.dart';

/// Pil transparan berefek kaca (dipakai untuk badge dan subjudul).
class GlassPill extends StatelessWidget {
  const GlassPill({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
    this.tint,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: AppRadius.pill,
      blur: 14,
      padding: padding,
      showShadow: false,
      tint: tint ?? AppColors.mist.withValues(alpha: 0.55),
      child: child,
    );
  }
}