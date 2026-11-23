import 'package:flutter/material.dart';
import 'package:monu/core/app_colors.dart';

/// Simbol logo MONU (daun + sinyal).
class MonuMark extends StatelessWidget {
  const MonuMark({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/monu_mark.png',
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) =>
          Icon(Icons.eco_outlined, size: size, color: AppColors.forest),
    );
  }
}