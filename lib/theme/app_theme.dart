import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class AppTheme {
  AppTheme._();

  static TextStyle display(double size, {Color? color}) =>
      GoogleFonts.bebasNeue(fontSize: size, color: color ?? AppColors.text, letterSpacing: 0.5);

  static TextStyle body(double size, {Color? color, FontWeight? weight}) =>
      GoogleFonts.inter(fontSize: size, color: color ?? AppColors.text, fontWeight: weight);

  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.black,
      primaryColor: AppColors.green,
      fontFamily: GoogleFonts.inter().fontFamily,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.green,
        secondary: AppColors.amber,
        error: AppColors.red,
        surface: AppColors.surface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.black.withValues(alpha: 0.97),
        elevation: 0,
        titleTextStyle: display(26),
      ),
      textTheme: TextTheme(
        headlineLarge: display(30),
        headlineMedium: display(21),
        bodyMedium: body(14),
        bodySmall: body(12, color: AppColors.sub),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.green),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: AppColors.black,
          textStyle: display(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
