import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../providers/lyrics_style_provider.dart'
    show LyricsOverlayTone, LyricsPosition;

/// Scrim between the background and the lyrics, so they stay readable over
/// busy video. Strongest where the lyrics sit ([position]) and easing off
/// away from them: a band through the middle, or a wash from the top or
/// bottom edge. Animates when the position or tone changes, and fades out
/// when [visible] is false (no lyrics, or lyrics hidden).
class LyricsOverlay extends StatelessWidget {
  const LyricsOverlay({
    super.key,
    required this.position,
    required this.tone,
    required this.visible,
    this.opacity = 0.6,
  });

  final LyricsPosition position;
  final LyricsOverlayTone tone;
  final bool visible;

  /// Opacity setting where the scrim is strongest (0–1); see [alphaFor].
  final double opacity;

  static const Duration _duration = Duration(milliseconds: 400);

  /// Alpha for an opacity setting [p] (0–1). How much background still
  /// shows through shrinks by a steady proportion per step, so the top steps
  /// (90 → 100) are as gentle as the rest, and 100% is fully solid.
  static double alphaFor(double p) {
    final x = p.clamp(0.0, 1.0);
    return 1 - math.pow(1 - x, 1.5).toDouble();
  }

  /// Gradient samples: enough that the straight runs between stops can't be
  /// seen as corners.
  static const int _samples = 32;

  /// Evenly spaced stops, shared by every position so changes lerp cleanly.
  static final List<double> _stops = [
    for (var i = 0; i < _samples; i++) i / (_samples - 1),
  ];

  /// Eased fade from 1 (dense) to 0 (clear) as [t] goes 0 → 1: smoothstep,
  /// flat at both ends so neither the dense side nor the clear side shows an
  /// edge.
  static double _fade(double t) {
    final x = t.clamp(0.0, 1.0);
    return 1 - x * x * (3 - 2 * x);
  }

  /// Alpha at a point of the fade, [strength] 1 (dense) → 0 (clear).
  /// Interpolates in perceived lightness (≈ cube root of what shows through)
  /// rather than raw alpha: the eye is most sensitive near the dense end, so
  /// a plain alpha ramp reads as an edge there. This spreads the visible
  /// change evenly along the fade.
  ///
  /// Near a solid peak (≈ 90–100%) the full cube-root curve would hold black
  /// for most of the fade and then lighten all at once, so the exponent eases
  /// from 3 towards 1.5 there; lower settings keep the full curve.
  static double _alphaAt(double peak, double strength) {
    final t = ((peak - 0.85) / 0.15).clamp(0.0, 1.0);
    final k = 3 - 1.5 * t * t * (3 - 2 * t);
    final dense = math.pow(1 - peak, 1 / k).toDouble();
    final through = dense + (1 - dense) * (1 - strength);
    return 1 - math.pow(through, k).toDouble();
  }

  /// Overlay strength (0–1) at height [y] (0 top → 1 bottom): a dense core
  /// over the lyrics — the outer 22% (top / bottom) or the middle 24% — and a
  /// long eased fade, clear by 85% of the way across or at the edges.
  static double _strength(LyricsPosition position, double y) =>
      switch (position) {
        LyricsPosition.top => _fade((y - 0.22) / 0.63),
        LyricsPosition.bottom => _fade((0.78 - y) / 0.63),
        LyricsPosition.middle => _fade(((y - 0.5).abs() - 0.12) / 0.38),
      };

  @override
  Widget build(BuildContext context) {
    final base = tone == LyricsOverlayTone.dark ? Colors.black : Colors.white;
    final peak = alphaFor(opacity);
    final colors = [
      for (final y in _stops)
        base.withValues(alpha: _alphaAt(peak, _strength(position, y))),
    ];

    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: _duration,
        curve: Curves.easeInOut,
        child: AnimatedContainer(
          duration: _duration,
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: colors,
              stops: _stops,
            ),
          ),
        ),
      ),
    );
  }
}
