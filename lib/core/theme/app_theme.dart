import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_radius.dart';
import 'app_stroke.dart';

/// Assembles [ThemeData] from Lycri design tokens.
/// All values must reference tokens — never hardcode.
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // ─── Colors ────────────────────────────────────────────────────────────
      scaffoldBackgroundColor: AppColors.surface4,
      colorScheme: const ColorScheme.light(
        primary: AppColors.orange400,
        onPrimary: AppColors.gray0,
        secondary: AppColors.orange300,
        onSecondary: AppColors.gray0,
        surface: AppColors.surface4,
        onSurface: AppColors.textBold,
        error: AppColors.surfaceDanger,
        onError: AppColors.gray0,
        surfaceContainerHighest: AppColors.surface0,
      ),

      // ─── Typography ────────────────────────────────────────────────────────
      // Fonts are loaded from local assets (assets/fonts/) via pubspec.yaml.
      textTheme: const TextTheme().copyWith(
        displayLarge: AppTypography.displayLg.copyWith(
          color: AppColors.textBold,
        ),
        displayMedium: AppTypography.displayMd.copyWith(
          color: AppColors.textBold,
        ),
        displaySmall: AppTypography.displaySm.copyWith(
          color: AppColors.textBold,
        ),
        headlineLarge: AppTypography.headingLg.copyWith(
          color: AppColors.textBold,
        ),
        headlineMedium: AppTypography.headingMd.copyWith(
          color: AppColors.textBold,
        ),
        headlineSmall: AppTypography.headingSm.copyWith(
          color: AppColors.textBold,
        ),
        titleLarge: AppTypography.titleLg.copyWith(color: AppColors.textBold),
        titleMedium: AppTypography.titleMd.copyWith(color: AppColors.textBold),
        titleSmall: AppTypography.titleSm.copyWith(color: AppColors.textBold),
        bodyLarge: AppTypography.bodyLg.copyWith(color: AppColors.textBold),
        bodyMedium: AppTypography.bodyMd.copyWith(color: AppColors.textBold),
        bodySmall: AppTypography.bodySm.copyWith(color: AppColors.textSubtle),
        labelLarge: AppTypography.btnLg.copyWith(color: AppColors.textBold),
        labelSmall: AppTypography.btnSm.copyWith(color: AppColors.textSubtle),
      ),

      // ─── Divider ───────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSubtle,
        thickness: AppStroke.md,
      ),

      // ─── Card ──────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: AppColors.surface4,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(
            color: AppColors.borderSubtle,
            width: AppStroke.md,
          ),
        ),
      ),

      // ─── Elevated Button ───────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.btnBrandPrimaryRest,
          foregroundColor: AppColors.textInverse,
          disabledBackgroundColor: AppColors.btnBrandPrimaryDisabled,
          textStyle: AppTypography.btnLg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),

      // ─── Input Decoration ──────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface4,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(
            color: AppColors.borderBold,
            width: AppStroke.md,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(
            color: AppColors.borderSubtle,
            width: AppStroke.md,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(
            color: AppColors.borderFocused,
            width: AppStroke.lg,
          ),
        ),
      ),
    );
  }
}
