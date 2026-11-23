import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:monu/core/app_colors.dart';
import 'package:monu/core/app_dimens.dart';
import 'package:monu/core/app_text.dart';

/// Tema utama app. Dipasang sekali di MaterialApp.
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.forest,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.forest,
      onPrimary: Colors.white,
      secondary: AppColors.sage,
      surface: AppColors.fog,
      onSurface: AppColors.ink,
      error: AppColors.danger,
    );

    final ThemeData base = ThemeData(useMaterial3: true, colorScheme: scheme);

    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.small),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.fog,
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.ink,
        titleTextStyle: AppText.headline.copyWith(fontSize: 20),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.forestDeep,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 58),
          padding: const EdgeInsets.symmetric(horizontal: 28),
          shape: const StadiumBorder(),
          textStyle: AppText.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.forest,
          minimumSize: const Size(0, 50),
          shape: const StadiumBorder(),
          side: const BorderSide(color: AppColors.forest, width: 1.2),
          textStyle: AppText.label.copyWith(fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.forest,
          textStyle: AppText.label.copyWith(fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.55),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: AppText.bodySoft,
        labelStyle: AppText.bodySoft,
        border: border(Colors.white.withValues(alpha: 0.7)),
        enabledBorder: border(Colors.white.withValues(alpha: 0.7)),
        focusedBorder: border(AppColors.forest, 1.5),
        errorBorder: border(AppColors.danger),
        focusedErrorBorder: border(AppColors.danger, 1.5),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.forest,
        contentTextStyle: AppText.body.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : AppColors.sage,
        ),
        trackColor: WidgetStateProperty.resolveWith<Color>(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.forest
              : AppColors.mist,
        ),
        trackOutlineColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.forest,
        inactiveTrackColor: AppColors.sage.withValues(alpha: 0.45),
        thumbColor: AppColors.forest,
        overlayColor: AppColors.forest.withValues(alpha: 0.12),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: AppColors.mist,
        labelTextStyle: WidgetStatePropertyAll<TextStyle>(
          AppText.caption.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.forest.withValues(alpha: 0.10),
        thickness: 1,
      ),
    );
  }
}