import 'package:flutter/material.dart';

/// All color tokens for Lycri.
/// Generated from the Figma variables export (design-sync/_file-context/variables.json).
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
  static const Color orange400 = Color(0xFFFF6200);
  static const Color orange500 = Color(0xFFC54A00);
  static const Color orange600 = Color(0xFF9D3900);
  static const Color orange700 = Color(0xFF762A00);
  static const Color orange800 = Color(0xFF521B00);
  static const Color orange900 = Color(0xFF310D00);
  static const Color orange950 = Color(0xFF210700);
  static const Color orange1000 = Color(0xFF130300);

  // Gray scale
  static const Color gray0 = Color(0xFFFFFFFF);
  static const Color gray50 = Color(0xFFF5F4F4);
  static const Color gray100 = Color(0xFFDEDEDD);
  static const Color gray200 = Color(0xFFBFBDBD);
  static const Color gray300 = Color(0xFFA09E9D);
  static const Color gray400 = Color(0xFF827F7E);
  static const Color gray500 = Color(0xFF666261);
  static const Color gray600 = Color(0xFF4B4745);
  static const Color gray700 = Color(0xFF312D2B);
  static const Color gray800 = Color(0xFF191513);
  static const Color gray900 = Color(0xFF0E0A08);
  static const Color gray950 = Color(0xFF050302);
  static const Color gray1000 = Color(0xFF000000);

  // Green scale
  static const Color green0 = Color(0xFFFFFFFF);
  static const Color green50 = Color(0xFFD5FED5);
  static const Color green100 = Color(0xFFABFDAB);
  static const Color green200 = Color(0xFF6AF26A);
  static const Color green300 = Color(0xFF30E630);
  static const Color green400 = Color(0xFF00DB00);
  static const Color green500 = Color(0xFF00C000);
  static const Color green600 = Color(0xFF00A600);
  static const Color green700 = Color(0xFF008B00);
  static const Color green800 = Color(0xFF007000);
  static const Color green900 = Color(0xFF005600);
  static const Color green1000 = Color(0xFF003B00);
  static const Color green1100 = Color(0xFF002000);
  static const Color green1150 = Color(0xFF001000);
  static const Color green1200 = Color(0xFF000000);

  // Amber scale
  static const Color amber0 = Color(0xFFFFFFFF);
  static const Color amber50 = Color(0xFFFFFBDB);
  static const Color amber100 = Color(0xFFFFF6B5);
  static const Color amber200 = Color(0xFFFFE273);
  static const Color amber300 = Color(0xFFFFD036);
  static const Color amber400 = Color(0xFFFFBF00);
  static const Color amber500 = Color(0xFFE0A800);
  static const Color amber600 = Color(0xFFC29100);
  static const Color amber700 = Color(0xFFA37A00);
  static const Color amber800 = Color(0xFF846300);
  static const Color amber900 = Color(0xFF664C00);
  static const Color amber1000 = Color(0xFF473500);
  static const Color amber1100 = Color(0xFF281E00);
  static const Color amber1150 = Color(0xFF140F00);
  static const Color amber1200 = Color(0xFF000000);

  // Red scale
  static const Color red0 = Color(0xFFFFFFFF);
  static const Color red50 = Color(0xFFFFE4E4);
  static const Color red100 = Color(0xFFFFC7C7);
  static const Color red200 = Color(0xFFFF8D8D);
  static const Color red300 = Color(0xFFFF5858);
  static const Color red400 = Color(0xFFFF2929);
  static const Color red500 = Color(0xFFFF0000);
  static const Color red600 = Color(0xFFDC0000);
  static const Color red700 = Color(0xFFBA0000);
  static const Color red800 = Color(0xFF970000);
  static const Color red900 = Color(0xFF750000);
  static const Color red1000 = Color(0xFF520000);
  static const Color red1100 = Color(0xFF300000);
  static const Color red1150 = Color(0xFF180000);
  static const Color red1200 = Color(0xFF000000);

  // ─── Semantic Tokens (Figma "Theme" collection) ─────────────────────────

  // Text
  static const Color textBold = gray1000; // Text/text-bold
  static const Color textSubtle = gray500; // Text/text-subtle
  static const Color textMinimal = gray200; // Text/text-minimal
  static const Color textInverse = gray0; // Text/text-inverse
  static const Color textSuccess = green600; // Text/text-success
  static const Color textDanger = red600; // Text/text-danger
  static const Color textWarning = amber700; // Text/text-warning
  static const Color textBrand = orange400; // Text/text-brand
  static const Color textLink = orange1000; // Text/text-link

  // Icon
  static const Color iconInverse = gray0; // Icon/icon-inverse
  static const Color iconMinimal = gray200; // Icon/icon-minimal
  static const Color iconSubtle = gray500; // Icon/icon-subtle
  static const Color iconBold = gray900; // Icon/icon-bold
  static const Color iconSuccess = green600; // Icon/icon-success
  static const Color iconDanger = red600; // Icon/icon-danger
  static const Color iconWarning = amber600; // Icon/icon-warning
  static const Color iconBrand = orange400; // Icon/icon-brand
  static const Color iconLink = gray1000; // Icon/icon-link

  // Surface
  static const Color surface4 = gray0; // Surface/surface-4
  static const Color surface3 = gray50; // Surface/surface-3
  static const Color surface2 = gray100; // Surface/surface-2
  static const Color surface1 = gray200; // Surface/surface-1
  static const Color surface0 = gray300; // Surface/surface-0
  static const Color surfaceBrand = orange400; // Surface/surface-brand
  static const Color surfaceInverse = gray1000; // Surface/surface-inverse
  static const Color surfaceBrandLight =
      orange50; // Surface/surface-brand-light
  static const Color surfaceDanger = red700; // Surface/surface-danger
  static const Color surfaceDangerLight = red50; // Surface/surface-danger-light
  static const Color surfaceSuccess = green600; // Surface/surface-success
  static const Color surfaceSuccessLight =
      green50; // Surface/surface-success-light
  static const Color surfaceWarning = amber600; // Surface/surface-warning
  static const Color surfaceWarningLight =
      amber50; // Surface/surface-warning-light

  // Border
  static const Color borderBold = gray200; // Border/border-bold
  static const Color borderSubtle = gray100; // Border/border-subtle
  static const Color borderMinimal = gray50; // Border/border-minimal

  // Button
  static const Color btnBrandPrimaryRest =
      orange400; // Button/brand-primary-rest
  static const Color btnBrandPrimaryHover =
      orange600; // Button/brand-primary-hover
  static const Color btnBrandPrimaryPressed =
      orange800; // Button/brand-primary-pressed
  static const Color btnBrandPrimaryFocused =
      orange1000; // Button/brand-primary-focused
  static const Color btnBrandPrimaryDisabled =
      gray300; // Button/brand-primary-disabled

  // Border
  static const Color borderFocused = orange300; // Border/border-focused
  static const Color borderHover = orange100; // Border/border-hover

  // Button
  static const Color btnBrandSecondaryRest =
      orange100; // Button/brand-secondary-rest
  static const Color btnBrandSecondaryHover =
      orange200; // Button/brand-secondary-hover
  static const Color btnBrandSecondaryPressed =
      orange400; // Button/brand-secondary-pressed
  static const Color btnBrandSecondaryFocused =
      orange100; // Button/brand-secondary-focused
  static const Color btnBrandSecondaryDisabled =
      gray300; // Button/brand-secondary-disabled
  static const Color btnBrandGhostHover = orange200; // Button/brand-ghost-hover
  static const Color btnBrandGhostPressed =
      orange400; // Button/brand-ghost-pressed
  static const Color btnBrandStrokeHover =
      orange200; // Button/brand-stroke-hover
  static const Color btnBrandStrokePressed =
      orange400; // Button/brand-stroke-pressed
  static const Color btnSuccessPrimaryRest =
      green700; // Button/success-primary-rest
  static const Color btnSuccessPrimaryHover =
      green800; // Button/success-primary-hover
  static const Color btnSuccessPrimaryPressed =
      green900; // Button/success-primary-pressed

  // Border
  static const Color borderSuccess = green500; // Border/border-success

  // Button
  static const Color btnSuccessPrimaryFocused =
      green700; // Button/success-primary-focused
  static const Color btnSuccessPrimaryDisabled =
      gray300; // Button/success-primary-disabled
  static const Color btnSuccessSecondaryRest =
      green50; // Button/success-secondary-rest
  static const Color btnSuccessSecondaryHover =
      green200; // Button/success-secondary-hover
  static const Color btnSuccessSecondaryPressed =
      green400; // Button/success-secondary-pressed
  static const Color btnSuccessSecondaryFocused =
      green50; // Button/success-secondary-focused
  static const Color btnSuccessSecondaryDisabled =
      gray300; // Button/success-secondary-disabled
  static const Color btnSuccessGhostHover =
      green200; // Button/success-ghost-hover
  static const Color btnSuccessGhostPressed =
      green400; // Button/success-ghost-pressed
  static const Color btnSuccessStrokeHover =
      green200; // Button/success-stroke-hover
  static const Color btnSuccessStrokePressed =
      green400; // Button/success-stroke-pressed
  static const Color btnDangerPrimaryRest =
      red600; // Button/danger-primary-rest
  static const Color btnDangerPrimaryHover =
      red800; // Button/danger-primary-hover
  static const Color btnDangerPrimaryPressed =
      red900; // Button/danger-primary-pressed
  static const Color btnDangerPrimaryFocused =
      red600; // Button/danger-primary-focused
  static const Color btnDangerPrimaryDisabled =
      gray300; // Button/danger-primary-disabled
  static const Color btnDangerSecondaryRest =
      red50; // Button/danger-secondary-rest
  static const Color btnDangerSecondaryHover =
      red200; // Button/danger-secondary-hover
  static const Color btnDangerSecondaryPressed =
      red400; // Button/danger-secondary-pressed
  static const Color btnDangerSecondaryFocused =
      red50; // Button/danger-secondary-focused
  static const Color btnDangerSecondaryDisabled =
      gray300; // Button/danger-secondary-disabled
  static const Color btnDangerGhostHover = red200; // Button/danger-ghost-hover
  static const Color btnDangerGhostPressed =
      red400; // Button/danger-ghost-pressed
  static const Color btnDangerStrokeHover =
      red200; // Button/danger-stroke-hover
  static const Color btnDangerStrokePressed =
      red400; // Button/danger-stroke-pressed
  static const Color btnWarningPrimaryRest =
      amber700; // Button/warning-primary-rest
  static const Color btnWarningPrimaryHover =
      amber800; // Button/warning-primary-hover
  static const Color btnWarningPrimaryPressed =
      amber900; // Button/warning-primary-pressed
  static const Color btnWarningPrimaryFocused =
      amber700; // Button/warning-primary-focused
  static const Color btnWarningPrimaryDisabled =
      gray300; // Button/warning-primary-disabled
  static const Color btnWarningSecondaryRest =
      amber100; // Button/warning-secondary-rest
  static const Color btnWarningSecondaryHover =
      amber200; // Button/warning-secondary-hover
  static const Color btnWarningSecondaryPressed =
      amber400; // Button/warning-secondary-pressed
  static const Color btnWarningSecondaryFocused =
      amber100; // Button/warning-secondary-focused
  static const Color btnWarningSecondaryDisabled =
      gray300; // Button/warning-secondary-disabled
  static const Color btnWarningGhostHover =
      amber200; // Button/warning-ghost-hover
  static const Color btnWarningGhostPressed =
      amber400; // Button/warning-ghost-pressed
  static const Color btnWarningStrokeHover =
      amber200; // Button/warning-stroke-hover
  static const Color btnWarningStrokePressed =
      amber400; // Button/warning-stroke-pressed

  // Border
  static const Color borderSuccessFocused =
      green200; // Border/border-success-focused
  static const Color borderDanger = red500; // Border/border-danger
  static const Color borderDangerFocused =
      red100; // Border/border-danger-focused
  static const Color borderWarning = amber500; // Border/border-warning
  static const Color borderWarningFocused =
      amber200; // Border/border-warning-focused
  static const Color borderBrand = orange400; // Border/border-brand
  static const Color borderInverse = gray0; // Border/border-inverse

  // Badge
  static const Color badgeBrandPrimary = orange400; // Badge/brand-primary
  static const Color badgeBrandSecondary = orange50; // Badge/brand-secondary
  static const Color badgeGrayPrimary = gray1000; // Badge/gray-primary
  static const Color badgeGraySecondary = gray50; // Badge/gray-secondary
  static const Color badgeGreenPrimary = green700; // Badge/green-primary
  static const Color badgeGreenSecondary = green50; // Badge/green-secondary
  static const Color badgeRedPrimary = red600; // Badge/red-primary
  static const Color badgeRedSecondary = red50; // Badge/red-secondary
  static const Color badgeAmberPrimary = amber600; // Badge/amber-primary
  static const Color badgeAmberSecondary = amber100; // Badge/amber-secondary

  // Indicator
  static const Color indicatorBrandPrimary =
      orange400; // Indicator/brand-primary
  static const Color indicatorBrandSecondary =
      orange50; // Indicator/brand-secondary
  static const Color indicatorGrayPrimary = gray1000; // Indicator/gray-primary
  static const Color indicatorGraySecondary =
      gray50; // Indicator/gray-secondary
  static const Color indicatorGreenPrimary =
      green600; // Indicator/green-primary
  static const Color indicatorGreenSecondary =
      green50; // Indicator/green-secondary
  static const Color indicatorRedPrimary = red600; // Indicator/red-primary
  static const Color indicatorRedSecondary = red50; // Indicator/red-secondary
  static const Color indicatorAmberPrimary =
      amber500; // Indicator/amber-primary
  static const Color indicatorAmberSecondary =
      amber100; // Indicator/amber-secondary

  // TextInput
  static const Color textinputSurfaceRest = gray50; // TextInput/surface-rest
  static const Color textinputSurfaceHover = gray100; // TextInput/surface-hover

  // Toggle
  static const Color toggleKnobRest = gray0; // Toggle/knob-rest
  static const Color toggleKnobDisabled = gray400; // Toggle/knob-disabled
  static const Color toggleSurfaceChecked =
      orange1000; // Toggle/surface-checked
  static const Color toggleSurfaceUnchecked =
      gray200; // Toggle/surface-unchecked
  static const Color toggleSurfaceUncheckedDisabled =
      gray100; // Toggle/surface-unchecked-disabled
  static const Color toggleSurfaceCheckedDisabled =
      gray200; // Toggle/surface-checked-disabled

  // List
  static const Color listSurfaceRest = gray0; // List/surface-rest
  static const Color listSurfaceHover = gray50; // List/surface-hover
  static const Color listSurfacePressed = gray100; // List/surface-pressed

  // Date
  static const Color calendarItemSurfaceRest =
      gray0; // Date/Calendar-item/surface-rest
  static const Color calendarItemSurfaceHover =
      orange50; // Date/Calendar-item/surface-hover
  static const Color calendarItemSurfaceRange =
      orange100; // Date/Calendar-item/surface-range
  static const Color calendarItemSurfaceSelected =
      orange1000; // Date/Calendar-item/surface-selected

  // Menu
  static const Color menuSurfaceRest = gray0; // Menu/surface-rest
  static const Color menuSurfaceHover = gray50; // Menu/surface-hover
  static const Color menuSurfacePressed = gray100; // Menu/surface-pressed

  // Table
  static const Color tableSurfaceCellRest = gray0; // Table/surface-cell-rest
  static const Color tableSurfaceCellHover = gray50; // Table/surface-cell-hover
  static const Color tableSurfaceCellSelected =
      orange1000; // Table/surface-cell-selected
  static const Color tableSurfaceHeaderRest =
      gray50; // Table/surface-header-rest
  static const Color tableSurfaceHeaderHover =
      gray100; // Table/surface-header-hover
  static const Color tableSurfaceHeaderSelected =
      orange1000; // Table/surface-header-selected

  // ─── Presentation Screen ──────────────────────────────────────────────────

  /// Background for the full-screen lyric output window
  static const Color presentationBackground = gray1000;

  /// Text color for the full-screen lyric output window
  static const Color presentationText = gray0;
}
