import 'package:flutter/material.dart';

/// Paints a Figma-style inner shadow over [child], clipped to [borderRadius].
///
/// Flutter's [BoxShadow] only draws outside a box. This paints a blurred ring
/// whose hole is the box shifted by [offset], so the shadow shows along the
/// edge opposite the offset — e.g. `Offset(0, -2)` darkens the bottom edge.
///
/// [blurRadius] uses Figma's "blur" value; it is converted to a Gaussian sigma.
class InnerShadow extends StatelessWidget {
  const InnerShadow({
    super.key,
    required this.child,
    required this.color,
    required this.borderRadius,
    this.blurRadius = 4,
    this.offset = const Offset(0, -2),
  });

  final Widget child;
  final Color color;
  final BorderRadius borderRadius;
  final double blurRadius;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _InnerShadowPainter(
        color: color,
        borderRadius: borderRadius,
        blurRadius: blurRadius,
        offset: offset,
      ),
      child: child,
    );
  }
}

class _InnerShadowPainter extends CustomPainter {
  _InnerShadowPainter({
    required this.color,
    required this.borderRadius,
    required this.blurRadius,
    required this.offset,
  });

  final Color color;
  final BorderRadius borderRadius;
  final double blurRadius;
  final Offset offset;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = borderRadius.toRRect(Offset.zero & size);
    final spread = blurRadius * 2 + offset.distance;

    canvas.save();
    canvas.clipRRect(rrect);
    final ring =
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(rrect.outerRect.inflate(spread))
          ..addRRect(rrect.shift(offset));
    canvas.drawPath(
      ring,
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurRadius / 2),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InnerShadowPainter old) =>
      old.color != color ||
      old.borderRadius != borderRadius ||
      old.blurRadius != blurRadius ||
      old.offset != offset;
}
