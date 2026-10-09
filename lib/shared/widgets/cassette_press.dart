import 'package:flutter/material.dart';

/// Cassette-deck key interaction for the inner-shadowed "cassette" buttons.
///
/// On press the key sinks: it drops [depth] px and its inner shadow flips
/// from the bottom edge to the top edge, so it reads as pushed into the
/// panel. On release it springs back up with a slight overshoot. A quick tap
/// still travels the full stroke before popping back, so it never feels
/// skipped.
///
/// [builder] receives `t` — 0 at rest, 1 fully depressed — to drive the
/// button's own colours. Use [CassettePress.shadowOffset] and
/// [CassettePress.shadowAlpha] for the matching inner shadow.
class CassettePress extends StatefulWidget {
  const CassettePress({
    super.key,
    required this.builder,
    this.onTap,
    this.enabled = true,
    this.depth = 1.5,
  });

  final Widget Function(BuildContext context, double t) builder;
  final VoidCallback? onTap;
  final bool enabled;

  /// How far the key travels down, in logical pixels.
  final double depth;

  /// Inner shadow offset at [t]: bottom edge (0, -2) at rest → top edge (0, 2)
  /// when pressed in.
  static Offset shadowOffset(double t) =>
      Offset.lerp(const Offset(0, -2), const Offset(0, 2), t)!;

  /// Inner shadow strength at [t], scaled from the resting [alpha].
  static double shadowAlpha(double alpha, double t) => alpha * (1 + t);

  @override
  State<CassettePress> createState() => _CassettePressState();
}

class _CassettePressState extends State<CassettePress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 70),
    reverseDuration: const Duration(milliseconds: 260),
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
    // Spring back with a small overshoot, like a key popping up.
    reverseCurve: Curves.easeOutBack.flipped,
  );

  bool get _active => widget.enabled && widget.onTap != null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // The key sinks on raw pointer down — no 100ms tap-recognition delay —
  // while the action still fires through a normal tap (so drags-off cancel).
  void _down() => _controller.forward();

  Future<void> _release() async {
    // Finish the stroke on quick taps before springing back.
    if (_controller.value < 1) await _controller.forward();
    if (mounted) _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _active ? (_) => _down() : null,
      onPointerUp: _active ? (_) => _release() : null,
      onPointerCancel: _active ? (_) => _controller.reverse() : null,
      child: GestureDetector(
        onTap: _active ? widget.onTap : null,
        child: AnimatedBuilder(
          animation: _t,
          builder:
              (context, _) => Transform.translate(
                offset: Offset(0, widget.depth * _t.value),
                child: widget.builder(context, _t.value),
              ),
        ),
      ),
    );
  }
}
