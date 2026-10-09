import 'package:flutter/material.dart';

/// All TextStyle definitions for Lycri.
/// Mirrors the Figma text styles (design-sync/typography.json).
///
/// Typefaces (bundled in assets/fonts/, declared in pubspec.yaml):
/// - Advent Pro — display, headings, titles, buttons, links, UI labels
/// - Gabarito — body/paragraph text
/// - Source Code Pro — code only
///
/// Text case: Figma sets Display, Heading, Title, and button styles to
/// UPPERCASE. Flutter's TextStyle has no text-case property, so callers must
/// uppercase those strings themselves (e.g. `label.toUpperCase()`). Body,
/// link, and code styles keep their original case.
class AppTypography {
  AppTypography._();

  // ─── Font Family Constants ─────────────────────────────────────────────────

  static const String fontDisplay = 'Advent Pro';
  static const String fontBody = 'Gabarito';
  static const String fontCode = 'Source Code Pro';

  /// Figma centres text within its line height; Flutter's default puts most
  /// of the extra leading above the text, which sits short words low in
  /// fixed-height boxes. `even` matches Figma.
  static const TextLeadingDistribution _figmaLeading =
      TextLeadingDistribution.even;

  // ─── Display (UPPERCASE) ──────────────────────────────────────────────────

  static const TextStyle displayLg = TextStyle(
    leadingDistribution: _figmaLeading,
    fontFamily: fontDisplay,
    fontSize: 83,
    fontWeight: FontWeight.w700,
    letterSpacing: -2.49,
    height: 88 / 83,
  );

  static const TextStyle displayMd = TextStyle(
    leadingDistribution: _figmaLeading,
    fontFamily: fontDisplay,
    fontSize: 67,
    fontWeight: FontWeight.w700,
    letterSpacing: -2.01,
    height: 72 / 67,
  );

  static const TextStyle displaySm = TextStyle(
    leadingDistribution: _figmaLeading,
    fontFamily: fontDisplay,
    fontSize: 53,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.59,
    height: 56 / 53,
  );

  // ─── Heading (UPPERCASE) ──────────────────────────────────────────────────

  static const TextStyle headingLg = TextStyle(
    leadingDistribution: _figmaLeading,
    fontFamily: fontDisplay,
    fontSize: 43,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.29,
    height: 48 / 43,
  );

  static const TextStyle headingMd = TextStyle(
    leadingDistribution: _figmaLeading,
    fontFamily: fontDisplay,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.02,
    height: 40 / 34,
  );

  static const TextStyle headingSm = TextStyle(
    leadingDistribution: _figmaLeading,
    fontFamily: fontDisplay,
    fontSize: 27,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.81,
    height: 32 / 27,
  );

  // ─── Title (UPPERCASE) ────────────────────────────────────────────────────

  static const TextStyle titleLg = TextStyle(
    leadingDistribution: _figmaLeading,
    fontFamily: fontDisplay,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.66,
    height: 28 / 22,
  );

  static const TextStyle titleMd = TextStyle(
    leadingDistribution: _figmaLeading,
    fontFamily: fontDisplay,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.51,
    height: 24 / 17,
  );

  static const TextStyle titleSm = TextStyle(
    leadingDistribution: _figmaLeading,
    fontFamily: fontDisplay,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.42,
    height: 20 / 14,
  );

  // ─── Body ─────────────────────────────────────────────────────────────────

  static const TextStyle bodyLg = TextStyle(
    leadingDistribution: _figmaLeading,
    fontFamily: fontBody,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.34,
    height: 24 / 17,
  );

  static const TextStyle bodyLgBold = TextStyle(
    leadingDistribution: _figmaLeading,
    fontFamily: fontBody,
    fontSize: 17,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.34,
    height: 24 / 17,
  );

  static const TextStyle bodyMd = TextStyle(
    leadingDistribution: _figmaLeading,
    fontFamily: fontBody,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.28,
    height: 20 / 14,
  );

  static const TextStyle bodyMdBold = TextStyle(
    leadingDistribution: _figmaLeading,
    fontFamily: fontBody,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.28,
    height: 20 / 14,
  );

  static const TextStyle bodySm = TextStyle(
    leadingDistribution: _figmaLeading,
    fontFamily: fontBody,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.22,
    height: 12 / 11,
  );

  static const TextStyle bodySmBold = TextStyle(
    leadingDistribution: _figmaLeading,
    fontFamily: fontBody,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.22,
    height: 12 / 11,
  );

  // ─── Buttons (Title case) ─────────────────────────────────────────────────
  // Apply TextCapitalization.words on the widget for title case.
  // Most buttons in the designs use titleMd / titleLg instead.

  static const TextStyle btnLg = TextStyle(
    leadingDistribution: _figmaLeading,
    fontFamily: fontDisplay,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.36,
    height: 20 / 18,
  );

  static const TextStyle btnSm = TextStyle(
    leadingDistribution: _figmaLeading,
    fontFamily: fontDisplay,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.20,
    height: 16 / 10,
  );

  // ─── Link ─────────────────────────────────────────────────────────────────

  static const TextStyle link = TextStyle(
    leadingDistribution: _figmaLeading,
    fontFamily: fontDisplay,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.51,
    height: 24 / 17,
    decoration: TextDecoration.underline,
  );

  // ─── Code ─────────────────────────────────────────────────────────────────

  static const TextStyle codeLg = TextStyle(
    leadingDistribution: _figmaLeading,
    fontFamily: fontCode,
    fontSize: 17,
    fontWeight: FontWeight.w500,
    height: 24 / 17,
  );

  static const TextStyle codeLgBold = TextStyle(
    leadingDistribution: _figmaLeading,
    fontFamily: fontCode,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 24 / 17,
  );

  static const TextStyle codeMd = TextStyle(
    leadingDistribution: _figmaLeading,
    fontFamily: fontCode,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 20 / 14,
  );

  static const TextStyle codeMdBold = TextStyle(
    leadingDistribution: _figmaLeading,
    fontFamily: fontCode,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 20 / 14,
  );

  static const TextStyle codeSm = TextStyle(
    leadingDistribution: _figmaLeading,
    fontFamily: fontCode,
    fontSize: 9,
    fontWeight: FontWeight.w500,
    height: 12 / 9,
  );

  static const TextStyle codeSmBold = TextStyle(
    leadingDistribution: _figmaLeading,
    fontFamily: fontCode,
    fontSize: 9,
    fontWeight: FontWeight.w600,
    height: 12 / 9,
  );

  static const TextStyle codeLink = TextStyle(
    leadingDistribution: _figmaLeading,
    fontFamily: fontCode,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 20 / 14,
    decoration: TextDecoration.underline,
  );

  // ─── Brand ────────────────────────────────────────────────────────────────

  /// The "Lycri" wordmark — Advent Pro Black, not a shared text style in Figma.
  static const TextStyle logo = TextStyle(
    leadingDistribution: _figmaLeading,
    fontFamily: fontDisplay,
    fontSize: 34,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.02,
    height: 40 / 34,
  );
}
