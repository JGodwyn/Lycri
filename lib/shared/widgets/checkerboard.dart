import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Checkerboard fill that stands in for "no background" — shown wherever a
/// transparent output is previewed on screen (presenter preview, live view,
/// editor swatch). The NDI output itself stays truly transparent.
class Checkerboard extends StatelessWidget {
  const Checkerboard({
    super.key,
    this.cellSize = 12,
    this.light = AppColors.gray0,
    this.dark = AppColors.gray100,
  });

  final double cellSize;
  final Color light;
  final Color dark;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CheckerboardPainter(cellSize, light, dark),
      child: const SizedBox.expand(),
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  _CheckerboardPainter(this.cellSize, this.light, this.dark);

  final double cellSize;
  final Color light;
  final Color dark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = light);
    final paint = Paint()..color = dark;
    final cols = (size.width / cellSize).ceil();
    final rows = (size.height / cellSize).ceil();
    for (var y = 0; y < rows; y++) {
      for (var x = y.isEven ? 1 : 0; x < cols; x += 2) {
        canvas.drawRect(
          Rect.fromLTWH(x * cellSize, y * cellSize, cellSize, cellSize),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerboardPainter old) =>
      old.cellSize != cellSize || old.light != light || old.dark != dark;
}
