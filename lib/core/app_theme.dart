import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App-wide color tokens
class AppColors {
  // Backgrounds
  static const bg = Color(0xFF1C1C1E);
  static const surface = Color(0xFF2C2C2E);
  static const surfaceAlt = Color(0xFF3A3A3C);
  static const border = Color(0xFF48484A);

  // Accent
  static const accent = Color(0xFF0A84FF);
  static const accentGlow = Color(0x330A84FF);
  static const accentHover = Color(0xFF409CFF);

  // Status
  static const connected = Color(0xFF30D158);
  static const disconnected = Color(0xFF636366);
  static const warning = Color(0xFFFFD60A);
  static const error = Color(0xFFFF453A);

  // Text
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF8E8E93);
  static const textTertiary = Color(0xFF48484A);

  // Sidebar
  static const sidebarBg = Color(0xFF161618);
  static const sidebarSelected = Color(0xFF2C2C2E);

  // Phone frame
  static const phoneBorder = Color(0xFF3A3A3C);
}

/// Main app theme
class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface,
        primary: AppColors.accent,
        error: AppColors.error,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme,
      ).copyWith(
        bodyLarge: GoogleFonts.inter(
          color: AppColors.textPrimary,
          fontSize: 14,
        ),
        bodyMedium: GoogleFonts.inter(
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
        titleMedium: GoogleFonts.inter(
          color: AppColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: GoogleFonts.inter(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        headlineMedium: GoogleFonts.inter(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 0.5,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(AppColors.border),
      ),
    );
  }
}
