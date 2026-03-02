import 'package:flutter/material.dart';

/// All spacing/distance constants for Lycri.
/// Based on Figma's _Units token collection.
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
