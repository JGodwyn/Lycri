import 'package:flutter/material.dart';

/// All TextStyle definitions for Lycri.
///
/// Two typefaces:
/// - Libre Caslon Condensed — headings, titles, display, buttons, UI labels
/// - Libre Caslon Text — body/paragraph text
/// - Source Code Pro — code blocks only
///
/// Fonts must be loaded via `google_fonts` at runtime (see app.dart).
/// These TextStyles use the fontFamily string directly; GoogleFonts wraps them.
class AppTypography {
  AppTypography._();

  // ─── Font Family Constants ─────────────────────────────────────────────────

  static const String fontDisplay = 'Libre Caslon Condensed';
  static const String fontBody = 'Libre Caslon Text';
  static const String fontCode = 'Source Code Pro';

  // ─── Display ──────────────────────────────────────────────────────────────

  static const TextStyle displayLg = TextStyle(
    fontFamily: fontDisplay,
    fontSize: 83,
    fontWeight: FontWeight.w600,
    letterSpacing: -2.49,
    height: 88 / 83,
  );

  static const TextStyle displayMd = TextStyle(
    fontFamily: fontDisplay,
    fontSize: 67,
    fontWeight: FontWeight.w600,
    letterSpacing: -2.01,
    height: 72 / 67,
  );

  static const TextStyle displaySm = TextStyle(
    fontFamily: fontDisplay,
    fontSize: 53,
    fontWeight: FontWeight.w600,
    letterSpacing: -1.59,
    height: 56 / 53,
  );

  // ─── Heading ──────────────────────────────────────────────────────────────

  static const TextStyle headingLg = TextStyle(
    fontFamily: fontDisplay,
    fontSize: 43,
    fontWeight: FontWeight.w600,
    letterSpacing: -1.29,
    height: 48 / 43,
  );

  static const TextStyle headingMd = TextStyle(
    fontFamily: fontDisplay,
    fontSize: 34,
    fontWeight: FontWeight.w600,
    letterSpacing: -1.02,
    height: 40 / 34,
  );

  static const TextStyle headingSm = TextStyle(
    fontFamily: fontDisplay,
    fontSize: 27,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.81,
    height: 32 / 27,
  );

  // ─── Title ────────────────────────────────────────────────────────────────

  static const TextStyle titleLg = TextStyle(
    fontFamily: fontDisplay,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.66,
    height: 28 / 22,
  );

  static const TextStyle titleMd = TextStyle(
    fontFamily: fontDisplay,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.51,
    height: 24 / 17,
  );

  static const TextStyle titleSm = TextStyle(
    fontFamily: fontDisplay,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.42,
    height: 20 / 14,
  );

  // ─── Body ─────────────────────────────────────────────────────────────────

  static const TextStyle bodyLg = TextStyle(
    fontFamily: fontBody,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.32,
    height: 24 / 16,
  );

  static const TextStyle bodyLgBold = TextStyle(
    fontFamily: fontBody,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.32,
    height: 24 / 16,
  );

  static const TextStyle bodyMd = TextStyle(
    fontFamily: fontBody,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.28,
    height: 20 / 14,
  );

  static const TextStyle bodyMdBold = TextStyle(
    fontFamily: fontBody,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.28,
    height: 20 / 14,
  );

  static const TextStyle bodySm = TextStyle(
    fontFamily: fontBody,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.22,
    height: 12 / 11,
  );

  static const TextStyle bodySmBold = TextStyle(
    fontFamily: fontBody,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.22,
    height: 12 / 11,
  );

  // ─── Buttons ──────────────────────────────────────────────────────────────
  // Apply TextCapitalization.words on the widget for capitalize case

  static const TextStyle btnLg = TextStyle(
    fontFamily: fontDisplay,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.36,
    height: 20 / 18,
  );

  static const TextStyle btnSm = TextStyle(
    fontFamily: fontDisplay,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.20,
    height: 16 / 10,
  );

  // ─── Link ─────────────────────────────────────────────────────────────────

  static const TextStyle link = TextStyle(
    fontFamily: fontDisplay,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.51,
    height: 24 / 17,
    decoration: TextDecoration.underline,
  );
}
