import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';

/// The app's tooltip: a rounded black bubble with a tip pointing at its
/// target. Padding, text style, max width and delays come from the theme's
/// [TooltipThemeData].
///
/// Use instead of [Tooltip]: the tip follows where the tooltip actually
/// lands — below the target, or above it when there's no room, and shifted
/// sideways near the window edges.
class LycriTooltip extends StatefulWidget {
  const LycriTooltip({super.key, required this.message, required this.child});

  /// At most 2 lines at the theme's 240px max width (about 60 characters);
  /// 3 only when it can't be said shorter.
  final String message;
  final Widget child;

  /// Corner radius (clamped to half the bubble's height).
  static const double radius = AppRadius.lg;

  /// Size of the tip.
  static const double tipWidth = 14;
  static const double tipHeight = 7;

  static const List<BoxShadow> shadows = [
    BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x40000000), blurRadius: 32, offset: Offset(0, 12)),
  ];

  @override
  State<LycriTooltip> createState() => _LycriTooltipState();
}

class _LycriTooltipState extends State<LycriTooltip> {
  /// Filled in while positioning, read when painting the bubble.
  final _TipPlacement _placement = _TipPlacement();

  Offset _position(TooltipPositionContext c) {
    final offset = positionDependentBox(
      size: c.overlaySize,
      childSize: c.tooltipSize,
      target: c.target,
      // Leave room for the tip between the target and the bubble.
      verticalOffset: c.verticalOffset + LycriTooltip.tipHeight,
      preferBelow: c.preferBelow,
    );
    _placement
      ..below = offset.dy >= c.target.dy
      ..tipX = c.target.dx - offset.dx;
    return offset;
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.message,
      positionDelegate: _position,
      decoration: ShapeDecoration(
        color: AppColors.surfaceInverse,
        shape: _TipBubbleBorder(_placement),
        shadows: LycriTooltip.shadows,
      ),
      child: widget.child,
    );
  }
}

/// Which side of the bubble the tip is on, and where along it.
class _TipPlacement {
  bool below = true;
  double? tipX;
}

/// Rounded rect with a tip on the side facing the target. The tip is drawn
/// outside the rect, in the gap the position delegate leaves for it.
class _TipBubbleBorder extends ShapeBorder {
  const _TipBubbleBorder(this.placement);

  final _TipPlacement placement;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    const tipW = LycriTooltip.tipWidth;
    const tipH = LycriTooltip.tipHeight;
    final r = math.min(LycriTooltip.radius, rect.height / 2);

    // Keep the tip clear of the rounded corners.
    final minX = rect.left + r + tipW / 2;
    final maxX = rect.right - r - tipW / 2;
    final x =
        minX > maxX
            ? rect.center.dx
            : (rect.left + (placement.tipX ?? rect.width / 2)).clamp(
              minX,
              maxX,
            );

    final bubble =
        Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(r)));
    final baseY = placement.below ? rect.top : rect.bottom;
    final apexY = placement.below ? rect.top - tipH : rect.bottom + tipH;
    // Overlap the bubble by a pixel so the seam doesn't show.
    final overlap = placement.below ? 1.0 : -1.0;
    // Straight sides meeting in a softly rounded point.
    final dir = placement.below ? -1.0 : 1.0;
    final shoulderY = apexY - dir * 2;
    final tip =
        Path()
          ..moveTo(x - tipW / 2, baseY + overlap)
          ..lineTo(x - tipW / 2, baseY)
          ..lineTo(x - 1.6, shoulderY)
          ..quadraticBezierTo(x, apexY, x + 1.6, shoulderY)
          ..lineTo(x + tipW / 2, baseY)
          ..lineTo(x + tipW / 2, baseY + overlap)
          ..close();
    return Path.combine(PathOperation.union, bubble, tip);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}
