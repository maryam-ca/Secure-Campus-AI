import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// SecureCampus visual identity: white backgrounds, a professional blue
/// primary, navy text, soft cards — deliberately restrained (spec §40):
/// no gradients, no glassmorphism, no decorative clutter.
class AppColors {
  AppColors._();

  static const Color primaryBlue = Color(0xFF1565C0);
  static const Color primaryBlueDark = Color(0xFF0D47A1);
  static const Color accentLightBlue = Color(0xFFE3F2FD);
  static const Color navyText = Color(0xFF0D2B4E);
  static const Color bodyText = Color(0xFF3A4A5A);
  static const Color background = Color(0xFFFAFBFC);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE3E8EE);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFEF6C00);
  static const Color error = Color(0xFFC62828);
  // Locked books: purple, so they are not confused with overdue (red) or issued (orange).
  static const Color locked = Color(0xFF6A1B9A);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryBlue,
      brightness: Brightness.light,
      primary: AppColors.primaryBlue,
      surface: AppColors.cardBackground,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',
      // Same solid colour as the sidebar header, so the top bar and the
      // sidebar read as one frame on every screen.
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primaryBlueDark,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.divider),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryBlue,
          side: const BorderSide(color: AppColors.primaryBlue),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.accentLightBlue.withValues(alpha: 0.35),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(color: AppColors.navyText, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(color: AppColors.navyText, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: AppColors.navyText, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: AppColors.bodyText),
        bodyMedium: TextStyle(color: AppColors.bodyText),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 1),
    );
  }
}
