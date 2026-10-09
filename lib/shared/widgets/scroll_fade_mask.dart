import 'package:flutter/material.dart';

/// Fades the edges of a scrollable instead of clipping content sharply.
///
/// Wrap any scroll view (ListView, SingleChildScrollView, AnimatedList…).
/// An edge fades only while there is more content past it, so a list at
/// rest at the top shows no top fade, and the bottom fade disappears once
/// you reach the end. Fades animate in and out as you scroll.
///
/// App-wide rule: wherever content can overflow, use this for scroll areas
/// and `FadeText` for single-line text — no hard clips or ellipses.
class ScrollFadeMask extends StatefulWidget {
  const ScrollFadeMask({
    super.key,
    required this.child,
    this.axis = Axis.vertical,
    this.extent = 24,
  });

  final Widget child;
  final Axis axis;

  /// Length of each fade, in logical pixels.
  final double extent;

  @override
  State<ScrollFadeMask> createState() => _ScrollFadeMaskState();
}

class _ScrollFadeMaskState extends State<ScrollFadeMask> {
  bool _fadeStart = false;
  bool _fadeEnd = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _readInitialMetrics());
  }

  /// Scrollables don't always notify on first layout, so read the nearest
  /// one's position directly once it has been laid out.
  void _readInitialMetrics() {
    if (!mounted) return;
    ScrollableState? found;
    void visit(Element e) {
      if (found != null) return;
      if (e is StatefulElement && e.state is ScrollableState) {
        found = e.state as ScrollableState;
        return;
      }
      e.visitChildren(visit);
    }

    (context as Element).visitChildren(visit);
    final position = found?.position;
    if (position != null &&
        position.hasContentDimensions &&
        position.hasPixels) {
      _onMetrics(position, 0);
    }
  }

  bool _onMetrics(ScrollMetrics m, int depth) {
    // Only the directly wrapped scrollable, on the matching axis.
    if (depth != 0 || m.axis != widget.axis) return false;
    final start = m.pixels > m.minScrollExtent + 0.5;
    final end = m.pixels < m.maxScrollExtent - 0.5;
    if (start != _fadeStart || end != _fadeEnd) {
      setState(() {
        _fadeStart = start;
        _fadeEnd = end;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final vertical = widget.axis == Axis.vertical;

    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => _onMetrics(n.metrics, n.depth),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) => _onMetrics(n.metrics, n.depth),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: _fadeStart ? 1 : 0),
          duration: const Duration(milliseconds: 180),
          builder:
              (context, start, child) => TweenAnimationBuilder<double>(
                tween: Tween(end: _fadeEnd ? 1 : 0),
                duration: const Duration(milliseconds: 180),
                builder:
                    (context, end, child) => ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (bounds) {
                        final length = vertical ? bounds.height : bounds.width;
                        final f =
                            length <= 0
                                ? 0.0
                                : (widget.extent / length).clamp(0.0, 0.5);
                        return LinearGradient(
                          begin:
                              vertical
                                  ? Alignment.topCenter
                                  : Alignment.centerLeft,
                          end:
                              vertical
                                  ? Alignment.bottomCenter
                                  : Alignment.centerRight,
                          colors: [
                            Colors.black.withValues(alpha: 1 - start),
                            Colors.black,
                            Colors.black,
                            Colors.black.withValues(alpha: 1 - end),
                          ],
                          stops: [0, f, 1 - f, 1],
                        ).createShader(bounds);
                      },
                      child: child,
                    ),
                child: child,
              ),
          child: widget.child,
        ),
      ),
    );
  }
}
