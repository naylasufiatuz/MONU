import 'package:flutter/material.dart';
import 'package:monu/core/app_colors.dart';

/// Latar belakang foto hutan berkabut.
///
/// strong = false -> gaya onboarding: foto menempel di bawah, bagian atas
///                   kabut putih (sesuai desain).
/// strong = true  -> untuk halaman berisi data: foto penuh + lapisan kabut
///                   tebal supaya tulisan mudah dibaca.
///
/// Kalau gambar belum ada, otomatis pakai gradient hijau (tidak error).
class ForestBackground extends StatelessWidget {
  const ForestBackground({
    super.key,
    required this.child,
    this.strong = false,
  });

  final Widget child;
  final bool strong;

  static const String imagePath = 'assets/images/hutan_bg.png';
  static const Color _fog = Color(0xFFEEF2EF);

  @override
  Widget build(BuildContext context) {
    if (strong) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            imagePath,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                const _FallbackGradient(),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.fog.withValues(alpha: 0.86),
                  AppColors.fog.withValues(alpha: 0.78),
                  AppColors.mist.withValues(alpha: 0.86),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
          child,
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: _fog),
        // Foto selebar layar, menempel di bawah. Sisa ruang di atas = kabut.
        Positioned.fill(
          child: Image.asset(
            imagePath,
            fit: BoxFit.fitWidth,
            alignment: Alignment.bottomCenter,
            errorBuilder: (context, error, stackTrace) =>
                const _FallbackGradient(),
          ),
        ),
        // Kabut putih di bagian atas.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _fog,
                  _fog.withValues(alpha: 0.92),
                  _fog.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.2, 0.5],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _FallbackGradient extends StatelessWidget {
  const _FallbackGradient();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.fog, AppColors.mist, AppColors.sage],
        ),
      ),
    );
  }
}