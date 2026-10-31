import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// FUSKAMO design foundations: clear content hierarchy, soft geometry,
/// restrained depth and motion that never competes with football content.
class AppTheme {
  AppTheme._();

  static const double radiusSmall = 10;
  static const double radiusMedium = 16;
  static const double radiusLarge = 22;
  static const double radiusExtraLarge = 28;

  static TextStyle display(double size, {Color? color}) =>
      GoogleFonts.bebasNeue(
        fontSize: size,
        color: color ?? AppColors.text,
        letterSpacing: 0.35,
      );

  static TextStyle body(double size, {Color? color, FontWeight? weight}) =>
      GoogleFonts.inter(
        fontSize: size,
        color: color ?? AppColors.text,
        fontWeight: weight,
        height: 1.42,
      );

  static ThemeData get dark {
    final scheme = ColorScheme.dark(
      primary: AppColors.green,
      secondary: AppColors.amber,
      error: AppColors.red,
      surface: AppColors.surface,
      onSurface: AppColors.text,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.black,
      primaryColor: AppColors.green,
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      splashFactory: InkSparkle.splashFactory,
      fontFamily: GoogleFonts.inter().fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.black.withValues(alpha: 0.84),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: display(25),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 7, horizontal: 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      textTheme: TextTheme(
        headlineLarge: display(32),
        headlineMedium: display(24),
        titleLarge: body(20, weight: FontWeight.w700),
        titleMedium: body(16, weight: FontWeight.w600),
        bodyLarge: body(16),
        bodyMedium: body(14),
        bodySmall: body(12, color: AppColors.sub),
        labelLarge: body(14, weight: FontWeight.w600),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: AppColors.green, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: AppColors.red),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          backgroundColor: AppColors.green,
          foregroundColor: AppColors.black,
          textStyle: body(15, weight: FontWeight.w700),
          elevation: 0,
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          foregroundColor: AppColors.text,
          side: const BorderSide(color: AppColors.border),
          shape: const StadiumBorder(),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: const StadiumBorder(),
          textStyle: body(15, weight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          side: const BorderSide(color: AppColors.border),
        ),
        side: const BorderSide(color: AppColors.border),
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.green.withValues(alpha: 0.16),
        labelStyle: body(13),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 0.8,
        space: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        modalBackgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusExtraLarge),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.card,
        contentTextStyle: body(14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}