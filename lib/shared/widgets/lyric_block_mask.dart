import 'package:flutter/material.dart';

/// "Clipped" lyrics on the output: fades everything outside the resting
/// lyric block, so paging lyrics enter and leave through soft edges just
/// above and below the block instead of at the screen edges.
///
/// Wrap the paging view. [measure] returns the active page's lyric block
/// in that page's coordinates (see [blockRect]); pages fill the view, so at
/// rest that is also its rect in the view. It returns null while the page
/// isn't laid out yet (the current band is kept), or [showAll] when the page
/// has no block to clip to (continuous mode, a large segment that scrolls on
/// its own). It's re-read after each build and while [listenable] (the page
/// controller) ticks — the incoming page is only built once it scrolls into
/// view. The visible band animates between blocks of different heights.
///
/// Continuous lyrics (no pages) use it too: [measure] then returns the
/// band the active lines are scrolled to (see [bandHeight]).
///
/// With [enabled] false the whole view shows.
class LyricBlockMask extends StatefulWidget {
  const LyricBlockMask({
    super.key,
    required this.enabled,
    required this.measure,
    required this.child,
    this.listenable,
    this.fade = defaultFade,
    this.duration = const Duration(milliseconds: 400),
    this.curve = Curves.easeOutCubic,
  });

  final bool enabled;
  final Rect? Function() measure;
  final Listenable? listenable;
  final Widget child;

  /// Length of the fade above and below the block.
  final double fade;
  final Duration duration;
  final Curve curve;

  /// Default [fade]; also the gap a pinned band keeps from the screen edge.
  static const double defaultFade = 64;

  /// Returned by [measure] when the whole view should show.
  static const Rect showAll = Rect.largest;

  /// Lines in the band of clipped continuous lyrics.
  static const int continuousBandLines = 3;

  /// First and last line of the band around [active] (of [count] lines),
  /// with the active line in band row [slot]: 0 top, 1 middle, 2 bottom
  /// (matching the lyrics position). Near the start or end of the song the
  /// band stays full and the active line moves within it.
  static (int, int) bandRange(int active, int count, {required int slot}) {
    final size = continuousBandLines < count ? continuousBandLines : count;
    final first = (active - slot).clamp(0, count - size);
    return (first, first + size - 1);
  }

  /// Height of the band from line [first] through line [last] (keys from
  /// [lineKey]), or null if they aren't laid out. Independent of scroll and
  /// of any scaling above the lyrics. The lines must share a parent.
  static double? bandHeight(
    GlobalKey? Function(int index) lineKey,
    int first,
    int last,
  ) {
    final top = lineKey(first)?.currentContext?.findRenderObject();
    final bottom = lineKey(last)?.currentContext?.findRenderObject();
    if (top is! RenderBox || bottom is! RenderBox) return null;
    if (!top.hasSize || !bottom.hasSize || !top.attached || !bottom.attached) {
      return null;
    }
    // Measure in the lines' shared parent (the lyric column), not globally:
    // a scaled-down output (the live view preview) would shrink the band.
    final column = top.parent;
    if (column is! RenderBox) return null;
    final topY = top.localToGlobal(Offset.zero, ancestor: column).dy;
    final bottomY =
        bottom
            .localToGlobal(Offset(0, bottom.size.height), ancestor: column)
            .dy;
    return bottomY - topY;
  }

  /// [block]'s bounds in [page]'s coordinates, or null if either isn't laid
  /// out. Accounts for transforms between them (e.g. a scale-down FittedBox).
  static Rect? blockRect(GlobalKey? block, GlobalKey? page) {
    final blockBox = block?.currentContext?.findRenderObject();
    final pageBox = page?.currentContext?.findRenderObject();
    if (blockBox is! RenderBox || pageBox is! RenderBox) return null;
    if (!blockBox.hasSize || !pageBox.attached || !blockBox.attached) {
      return null;
    }
    return MatrixUtils.transformRect(
      blockBox.getTransformTo(pageBox),
      Offset.zero & blockBox.size,
    );
  }

  @override
  State<LyricBlockMask> createState() => _LyricBlockMaskState();
}

class _LyricBlockMaskState extends State<LyricBlockMask> {
  /// Vertical extent of the block; null → show everything.
  Rect? _block;

  @override
  void initState() {
    super.initState();
    widget.listenable?.addListener(_scheduleMeasure);
  }

  @override
  void didUpdateWidget(LyricBlockMask oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listenable != widget.listenable) {
      oldWidget.listenable?.removeListener(_scheduleMeasure);
      widget.listenable?.addListener(_scheduleMeasure);
    }
  }

  @override
  void dispose() {
    widget.listenable?.removeListener(_scheduleMeasure);
    super.dispose();
  }

  bool _measureScheduled = false;

  void _scheduleMeasure() {
    if (_measureScheduled) return;
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (!mounted) return;
      final Rect? next;
      if (!widget.enabled) {
        next = null;
      } else {
        final measured = widget.measure();
        // Incoming page not built yet: keep the current band until it is.
        if (measured == null) return;
        next = measured == LyricBlockMask.showAll ? null : measured;
      }
      if (!_same(next, _block)) setState(() => _block = next);
    });
  }

  static bool _same(Rect? a, Rect? b) {
    if (a == null || b == null) return a == b;
    return (a.top - b.top).abs() < 0.5 && (a.bottom - b.bottom).abs() < 0.5;
  }

  @override
  Widget build(BuildContext context) {
    _scheduleMeasure();
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        // "Show everything" is a band reaching past both edges, so turning
        // clipping on or off animates like any other change.
        final full = Rect.fromLTRB(
          0,
          -widget.fade * 2,
          0,
          height + widget.fade * 2,
        );
        final target = _block ?? full;
        return TweenAnimationBuilder<Rect?>(
          tween: RectTween(end: target),
          duration: widget.duration,
          curve: widget.curve,
          child: widget.child,
          builder: (context, band, child) {
            band ??= target;
            return ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) => _gradient(band!, bounds),
              child: child,
            );
          },
        );
      },
    );
  }

  Shader _gradient(Rect band, Rect bounds) {
    final h = bounds.height <= 0 ? 1.0 : bounds.height;
    double at(double y) => (y / h).clamp(0.0, 1.0);
    const clear = Color(0x00000000);
    const solid = Color(0xFF000000);
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [clear, solid, solid, clear],
      stops: [
        at(band.top - widget.fade),
        at(band.top),
        at(band.bottom),
        at(band.bottom + widget.fade),
      ],
    ).createShader(bounds);
  }
}
