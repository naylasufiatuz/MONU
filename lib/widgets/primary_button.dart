import 'package:flutter/material.dart';
import 'package:monu/core/app_text.dart';

/// Tombol utama: bentuk pil, hijau tua, teks putih.
/// Gaya dasarnya diatur di AppTheme (filledButtonTheme).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.height = 58,
    this.fontSize,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final double height;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: FilledButton(
        style: FilledButton.styleFrom(
          minimumSize: Size(0, height),
          textStyle: fontSize == null
              ? null
              : AppText.button.copyWith(fontSize: fontSize),
        ),
        // Saat loading, tombol tetap berwarna tapi tidak melakukan apa-apa.
        onPressed: loading ? () {} : onPressed,
        child: loading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label),
                  if (icon != null) ...[
                    const SizedBox(width: 10),
                    Icon(icon, size: (fontSize ?? 16) + 4),
                  ],
                ],
              ),
      ),
    );
  }
}