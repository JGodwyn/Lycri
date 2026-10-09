import 'package:flutter/material.dart';

/// Gaps between elements — Figma's `dist-*` tokens (auto-layout itemSpacing).
/// Names match the _Units scale 1:1: `dist-md` → [AppSpacing.md] (8).
/// For inner padding use [AppPadding] — its scale is offset from this one.
class AppSpacing {
  AppSpacing._();

  static const double none = 0;
  static const double u3xs = 0.5;
  static const double u2xs = 1;
  static const double xs = 2;
  static const double sm = 4;
  static const double md = 8;
  static const double xmd = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double x2l = 32;
  static const double x3l = 40;
  static const double x4l = 48;
  static const double x5l = 56;
  static const double x6l = 64;
  static const double x7l = 128;
  static const double x8l = 152;
  static const double x9l = 256;

  // Named layout aliases
  static const double mgnDesktop = x8l; // 152 — desktop page margin
  static const double mgnMisc = 23; // misc1 value

  /// Convenience: EdgeInsets with uniform padding
  static EdgeInsets all(double value) => EdgeInsets.all(value);

  /// Convenience: symmetric horizontal/vertical padding
  static EdgeInsets symmetric({double horizontal = 0, double vertical = 0}) =>
      EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
}

/// Inner padding — Figma's `pad-*` tokens. Note the offset from [AppSpacing]:
/// `pad-md` is 12 while `dist-md` is 8, so map frame.json tokens by name.
class AppPadding {
  AppPadding._();

  static const double none = 0; // pad-null
  static const double xxs = 2; // pad-2xs
  static const double xs = 4; // pad-xs
  static const double sm = 8; // pad-sm
  static const double md = 12; // pad-md
  static const double lg = 16; // pad-lg
  static const double xl = 24; // pad-xl
  static const double x2l = 32; // pad-2xl
  static const double x3l = 40; // pad-3xl
  static const double x4l = 48; // pad-4xl
  static const double x5l = 56; // pad-5xl
  static const double x6l = 64; // pad-6xl
  static const double x7l = 128; // pad-7xl
  static const double x8l = 152; // pad-8xl
  static const double x9l = 256; // pad-9xl

  static const double mgnDesktop = 152; // mgn-desktop
  static const double mgnMobile = 23; // mgn-mobile
}
