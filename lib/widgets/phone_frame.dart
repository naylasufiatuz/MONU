import 'package:flutter/material.dart';
import 'package:monu/core/app_colors.dart';

/// Di layar lebar (Chrome di laptop), app tampil dalam bingkai HP berukuran
/// HP asli (390 x 844). Bingkai dikecilkan utuh mengikuti jendela, jadi
/// ukuran huruf dan tata letaknya sama seperti di HP sungguhan.
/// Di HP asli (layar sempit), bingkai ini tidak muncul.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});

  final Widget child;

  static const double breakpoint = 600;
  static const double phoneWidth = 390;
  static const double phoneHeight = 844;
  static const double bezel = 8;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    if (mq.size.width <= breakpoint) return child;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E1A12), AppColors.forest, Color(0xFF0E1A12)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              width: phoneWidth + bezel * 2,
              height: phoneHeight + bezel * 2,
              padding: const EdgeInsets.all(bezel),
              decoration: BoxDecoration(
                color: const Color(0xFF0A110C),
                borderRadius: BorderRadius.circular(46),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 40,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(38),
                child: MediaQuery(
                  data: mq.copyWith(
                    size: const Size(phoneWidth, phoneHeight),
                    padding: const EdgeInsets.only(top: 32, bottom: 12),
                    viewPadding: const EdgeInsets.only(top: 32, bottom: 12),
                    viewInsets: EdgeInsets.zero,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}