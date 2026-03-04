import 'package:flutter/material.dart';

/// All color tokens for Lycri.
/// Use semantic tokens in widgets — never use primitive palette values directly.
class AppColors {
  AppColors._();

  // ─── Primitive Palette ────────────────────────────────────────────────────

  // Orange scale
  static const Color orange0 = Color(0xFFFFF8F5);
  static const Color orange50 = Color(0xFFFDEEE1);
  static const Color orange100 = Color(0xFFFFD9CA);
  static const Color orange200 = Color(0xFFFFAE8F);
  static const Color orange300 = Color(0xFFFF824C);
  static const Color orange400 = Color(0xFFFF6200); // Brand primary
  static const Color orange500 = Color(0xFFC54A00);
  static const Color orange600 = Color(0xFF9D3900);
  static const Color orange700 = Color(0xFF762A00);
  static const Color orange800 = Color(0xFF521B00);
  static const Color orange900 = Color(0xFF310D00);
  static const Color orange950 = Color(0xFF210700);
  static const Color orange1000 = Color(0xFF130300);

  // Gray scale
  static const Color gray0 = Color(0xFFFFFFFF);
  static const Color gray50 = Color(0xFFEFEEEE);
  static const Color gray100 = Color(0xFFDEDDDD);
  static const Color gray200 = Color(0xFFBFBDBD);
  static const Color gray300 = Color(0xFF9F9D9D);
  static const Color gray400 = Color(0xFF827F7E);
  static const Color gray500 = Color(0xFF666261);
  static const Color gray600 = Color(0xFF4B4747);
  static const Color gray700 = Color(0xFF312D2B);
  static const Color gray800 = Color(0xFF191513);
  static const Color gray900 = Color(0xFF0E0A08);
  static const Color gray950 = Color(0xFF050302);
  static const Color gray1000 = Color(0xFF000000);

  // ─── Semantic Text Tokens ─────────────────────────────────────────────────

  static const Color textBold = gray1000;
  static const Color textSubtle = gray500;
  static const Color textMinimal = gray200;
  static const Color textInverse = gray0;
  static const Color textSuccess = Color(0xFF00A600);
  static const Color textDanger = Color(0xFFDC0000);
  static const Color textWarning = Color(0xFFA37A00);
  static const Color textBrand = orange400;
  static const Color textLink = orange1000;

  // ─── Semantic Surface Tokens ──────────────────────────────────────────────

  // Light theme — lightest to darkest
  static const Color surface4 = gray0;
  static const Color surface3 = gray50;
  static const Color surface2 = gray100;
  static const Color surface1 = gray200;
  static const Color surface0 = gray300;
  static const Color surfaceBrand = orange400;
  static const Color surfaceInverse = gray1000;
  static const Color surfaceBrandLight = orange50;

  // Semantic surfaces
  static const Color surfaceDanger = Color(0xFFBA0000);
  static const Color surfaceDangerLight = Color(0xFFFFE4E4);
  static const Color surfaceSuccess = Color(0xFF008A00);
  static const Color surfaceSuccessLight = Color(0xFFD5FFD5);
  static const Color surfaceWarning = Color(0xFFA37A00);
  static const Color surfaceWarningLight = Color(0xFFFFFADB);

  // ─── Border Tokens ────────────────────────────────────────────────────────

  static const Color borderBold = gray200;
  static const Color borderSubtle = gray100;
  static const Color borderMinimal = gray50;
  static const Color borderFocused = orange300;
  static const Color borderHover = orange100;
  static const Color borderBrand = orange400;
  static const Color borderInverse = gray0;

  // ─── Button State Tokens (brand) ──────────────────────────────────────────

  // Primary
  static const Color btnBrandPrimaryRest = orange400;
  static const Color btnBrandPrimaryHover = orange600;
  static const Color btnBrandPrimaryPressed = orange800;
  static const Color btnBrandPrimaryDisabled = gray300;

  // Secondary
  static const Color btnBrandSecondaryRest = orange100;
  static const Color btnBrandSecondaryHover = orange200;
  static const Color btnBrandSecondaryPressed = orange400;
  static const Color btnBrandSecondaryDisabled = gray100;

  // ─── Icon Tokens ──────────────────────────────────────────────────────────

  static const Color iconBold = gray900;
  static const Color iconSubtle = gray500;
  static const Color iconMinimal = gray200;
  static const Color iconInverse = gray0;
  static const Color iconBrand = orange400;

  // ─── Presentation Screen ──────────────────────────────────────────────────

  /// Background for the full-screen lyric output window
  static const Color presentationBackground = gray1000;

  /// Text color for the full-screen lyric output window
  static const Color presentationText = gray0;
}
