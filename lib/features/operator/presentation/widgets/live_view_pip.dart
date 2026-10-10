import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_stroke.dart';
import '../../../../shared/providers/live_view_provider.dart';
import '../ndi_operator_view.dart' show LyricsOutputCanvas;

/// Floating picture-in-picture of the audience output, toggled from the
/// presenter's "Show live view" button.
///
/// Fills its parent (a [Stack] layer over the presenter preview, which clips
/// it) but only the PiP itself takes pointer events. It keeps the output's
/// 16:9 shape and:
/// - drags with momentum (mouse or two-finger trackpad pan) — fling it and it
///   glides, rubber-bands past the preview's edges and springs back inside;
/// - resizes from any edge or corner (invisible hit zones that switch the
///   cursor), anchoring the opposite side, or with a trackpad pinch;
/// - remembers where it sits *relative to the free space*, so a PiP docked
///   on an edge stays on that edge as it (or the window) grows and shrinks.
///
/// Position and size survive closing and reopening.
class LiveViewPip extends ConsumerStatefulWidget {
  const LiveViewPip({super.key});

  @override
  ConsumerState<LiveViewPip> createState() => _LiveViewPipState();
}

class _LiveViewPipState extends ConsumerState<LiveViewPip>
    with TickerProviderStateMixin {
  static const _aspect = LyricsOutputCanvas.width / LyricsOutputCanvas.height;
  static const _minWidth = 240.0;
  static const _margin = AppPadding.sm;

  /// Resize hit zones: edge band thickness and corner square size.
  static const _edge = 8.0;
  static const _corner = 16.0;

  /// Drag resistance once the PiP is pulled past the preview's edges.
  static const _overscrollResistance = 0.5;

  static final _spring = SpringDescription.withDampingRatio(
    mass: 0.5,
    stiffness: 100,
    ratio: 1.1,
  );

  late final AnimationController _visibility = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: ref.read(liveViewVisibleProvider) ? 1 : 0,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _visibility,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeOutCubic.flipped,
  );
  late final Animation<double> _scale = Tween(
    begin: 0.92,
    end: 1.0,
  ).animate(_curve);

  /// Top-left corner in pixels while a drag or glide is moving it — one
  /// unbounded controller per axis so flings can run physics simulations.
  late final AnimationController _x = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _y = AnimationController.unbounded(
    vsync: this,
  );

  /// Resting position as a fraction of the free space on each axis:
  /// 0 = against the left/top margin, 1 = against the right/bottom margin.
  /// Opens in the bottom-right corner.
  double _fx = 1;
  double _fy = 1;

  double _width = 400;
  double _gestureStartWidth = 400;

  /// True while a mouse drag or trackpad gesture moves the PiP (pixels in
  /// [_x]/[_y] are the source of truth).
  bool _dragging = false;
  bool _hovered = false;

  /// macOS has no diagonal resize cursor, so over a corner the system cursor
  /// is hidden and one is drawn here: where (in this widget's space) and
  /// which diagonal (1 = ↖↘, -1 = ↗↙). Null when not over a corner.
  Offset? _cornerCursorAt;
  int _cornerCursorDiagonal = 1;
  bool _resizingCorner = false;

  /// Latest layout bounds, for gesture handlers.
  Size _bounds = Size.zero;

  @override
  void initState() {
    super.initState();
    _x.addStatusListener(_onGlideStatus);
    _y.addStatusListener(_onGlideStatus);
  }

  @override
  void dispose() {
    _visibility.dispose();
    _x.dispose();
    _y.dispose();
    super.dispose();
  }

  // ── Geometry ──────────────────────────────────────────────────────────────

  Size get _size {
    final width = _clampWidth(_width);
    return Size(width, width / _aspect);
  }

  double get _maxWidth {
    final max = [
      _bounds.width - _margin * 2,
      (_bounds.height - _margin * 2) * _aspect,
    ].reduce((a, b) => a < b ? a : b);
    return max < _minWidth ? _minWidth : max;
  }

  double _clampWidth(double width) => width.clamp(_minWidth, _maxWidth);

  /// Allowed range for the top-left corner on each axis.
  (double, double) _rangeX(Size size) =>
      _range(_margin, _bounds.width - size.width - _margin);
  (double, double) _rangeY(Size size) =>
      _range(_margin, _bounds.height - size.height - _margin);
  (double, double) _range(double lo, double hi) => (lo, hi < lo ? lo : hi);

  double _fromFraction(double f, (double, double) range) =>
      range.$1 + f * (range.$2 - range.$1);

  double _toFraction(double value, (double, double) range, double fallback) {
    final span = range.$2 - range.$1;
    if (span <= 0) return fallback;
    return ((value - range.$1) / span).clamp(0.0, 1.0);
  }

  bool get _moving => _dragging || _x.isAnimating || _y.isAnimating;

  /// Where the PiP is drawn: raw pixels while it is being dragged or is
  /// gliding/springing back, otherwise derived from the stored fractions —
  /// which keeps it inside the preview and on its edge through any resize.
  Offset _displayPosition(Size size) {
    if (_moving) return Offset(_x.value, _y.value);
    return Offset(
      _fromFraction(_fx, _rangeX(size)),
      _fromFraction(_fy, _rangeY(size)),
    );
  }

  /// Pins the pixel controllers to what's on screen before a gesture moves
  /// them.
  void _settle() {
    final position = _displayPosition(_size);
    _x.stop();
    _y.stop();
    _x.value = position.dx;
    _y.value = position.dy;
  }

  /// Converts the pixel position back into fractions once it comes to rest.
  void _storeFractions() {
    final size = _size;
    _fx = _toFraction(_x.value, _rangeX(size), _fx);
    _fy = _toFraction(_y.value, _rangeY(size), _fy);
  }

  // ── Drag with momentum + trackpad pan/pinch ───────────────────────────────
  //
  // One scale recognizer handles both: a mouse drag reports one pointer; a
  // trackpad gesture reports two and carries both a pan and a pinch.

  void _onScaleStart(ScaleStartDetails d) {
    _settle();
    _gestureStartWidth = _size.width;
    setState(() => _dragging = true);
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount >= 2 && d.scale != 1) {
      _rescaleInPlace(_clampWidth(_gestureStartWidth * d.scale));
    }
    final size = _size;
    _x.value = _rubberBand(_x.value, d.focalPointDelta.dx, _rangeX(size));
    _y.value = _rubberBand(_y.value, d.focalPointDelta.dy, _rangeY(size));
  }

  /// Changes the width mid-gesture while keeping the PiP's place relative to
  /// the free space (so a docked edge stays docked), plus any overshoot the
  /// user is currently pulling it past an edge.
  void _rescaleInPlace(double width) {
    final oldSize = _size;
    final newSize = Size(width, width / _aspect);
    double follow(
      double value,
      (double, double) from,
      (double, double) to,
      double fallback,
    ) {
      final inside = value.clamp(from.$1, from.$2);
      final f = _toFraction(inside, from, fallback);
      return _fromFraction(f, to) + (value - inside);
    }

    final x = follow(_x.value, _rangeX(oldSize), _rangeX(newSize), _fx);
    final y = follow(_y.value, _rangeY(oldSize), _rangeY(newSize), _fy);
    setState(() => _width = width);
    _x.value = x;
    _y.value = y;
  }

  double _rubberBand(double value, double delta, (double, double) range) {
    final (lo, hi) = range;
    final outward = (value <= lo && delta < 0) || (value >= hi && delta > 0);
    return value + (outward ? delta * _overscrollResistance : delta);
  }

  void _onScaleEnd(ScaleEndDetails d) {
    if (!_dragging) return;
    final size = _size;
    final velocity = d.velocity.pixelsPerSecond;
    final (xLo, xHi) = _rangeX(size);
    final (yLo, yHi) = _rangeY(size);
    _x.animateWith(_glide(_x.value, velocity.dx, xLo, xHi));
    _y.animateWith(_glide(_y.value, velocity.dy, yLo, yHi));
    setState(() => _dragging = false);
    // An axis with nothing to do finishes at once; both may already be done.
    if (!_moving) _storeFractions();
  }

  /// Records the resting spot once both axes have settled.
  void _onGlideStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_moving) _storeFractions();
  }

  /// Friction glide that springs back once it passes [lo]/[hi] — the same
  /// physics as an iOS-style scroll overscroll.
  Simulation _glide(double position, double velocity, double lo, double hi) {
    return BouncingScrollSimulation(
      position: position,
      velocity: velocity,
      leadingExtent: lo,
      trailingExtent: hi,
      spring: _spring,
    );
  }

  // ── Edge / corner resize ──────────────────────────────────────────────────

  /// Resizes from the handle at ([hx], [hy]) — each -1 (left/top),
  /// 0 (centre) or 1 (right/bottom) — keeping 16:9. The opposite side stays
  /// put; for an edge handle the perpendicular axis stays centred. Growth is
  /// capped by the room between the anchor and the preview's edges.
  void _resize(int hx, int hy, Offset delta) {
    final size = _size;
    final position = _displayPosition(size);

    final dx = delta.dx * hx;
    final dy = delta.dy * hy * _aspect;
    final grow =
        hx == 0
            ? dy
            : hy == 0
            ? dx
            : (dx.abs() > dy.abs() ? dx : dy);

    final (anchorX, roomX) = _anchor(
      hx,
      position.dx,
      size.width,
      _bounds.width,
    );
    final (anchorY, roomY) = _anchor(
      hy,
      position.dy,
      size.height,
      _bounds.height,
    );
    final room = [roomX, roomY * _aspect].reduce((a, b) => a < b ? a : b);

    final width = _clampWidth(
      (size.width + grow).clamp(_minWidth, room < _minWidth ? _minWidth : room),
    );
    final newSize = Size(width, width / _aspect);

    setState(() {
      _width = width;
      _fx = _toFraction(
        _placeFrom(hx, anchorX, newSize.width),
        _rangeX(newSize),
        _fx,
      );
      _fy = _toFraction(
        _placeFrom(hy, anchorY, newSize.height),
        _rangeY(newSize),
        _fy,
      );
    });
  }

  /// The fixed point for handle side [h] along one axis, and how much
  /// length is available from it.
  (double, double) _anchor(int h, double start, double length, double bound) {
    return switch (h) {
      1 => (start, bound - _margin - start),
      -1 => (start + length, start + length - _margin),
      _ => () {
        final centre = start + length / 2;
        final half = [
          centre - _margin,
          bound - _margin - centre,
        ].reduce((a, b) => a < b ? a : b);
        return (centre, half * 2);
      }(),
    };
  }

  double _placeFrom(int h, double anchor, double length) => switch (h) {
    1 => anchor,
    -1 => anchor - length,
    _ => anchor - length / 2,
  };

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(liveViewVisibleProvider, (_, show) {
      show ? _visibility.forward() : _visibility.reverse();
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        _bounds = constraints.biggest;
        return AnimatedBuilder(
          animation: Listenable.merge([_visibility, _x, _y]),
          builder: (context, _) {
            // Stay built until fully closed, so closing mirrors opening.
            if (_visibility.isDismissed) return const SizedBox.shrink();
            final size = _size;
            final position = _displayPosition(size);
            return Stack(
              children: [
                Positioned(
                  left: position.dx,
                  top: position.dy,
                  width: size.width,
                  height: size.height,
                  child: FadeTransition(
                    opacity: _curve,
                    child: ScaleTransition(
                      scale: _scale,
                      alignment: Alignment.bottomRight,
                      child: IgnorePointer(
                        ignoring: !_visibility.isCompleted,
                        child: _buildPip(),
                      ),
                    ),
                  ),
                ),
                if (_cornerCursorAt case final at?)
                  Positioned(
                    left: at.dx - _DiagonalCursorPainter.size / 2,
                    top: at.dy - _DiagonalCursorPainter.size / 2,
                    child: IgnorePointer(
                      child: CustomPaint(
                        size: const Size.square(_DiagonalCursorPainter.size),
                        painter: _DiagonalCursorPainter(_cornerCursorDiagonal),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPip() {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: AppColors.borderInverse,
            width: AppStroke.lg,
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Stack(
            children: [
              // ── Output (drag to move, pinch to resize) ─────────────────────
              Positioned.fill(
                child: MouseRegion(
                  cursor:
                      _dragging
                          ? SystemMouseCursors.grabbing
                          : SystemMouseCursors.grab,
                  child: GestureDetector(
                    // The output ignores pointers, so claim the whole area.
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: _onScaleStart,
                    onScaleUpdate: _onScaleUpdate,
                    onScaleEnd: _onScaleEnd,
                    child: const FittedBox(
                      child: SizedBox(
                        width: LyricsOutputCanvas.width,
                        height: LyricsOutputCanvas.height,
                        child: IgnorePointer(
                          child: LyricsOutputCanvas(showTransparency: true),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Close ──────────────────────────────────────────────────────
              Positioned(
                top: AppSpacing.md,
                left: 0,
                right: 0,
                child: _HoverFade(
                  visible: _hovered && !_dragging,
                  child: Center(
                    child: _CloseButton(
                      onTap:
                          () =>
                              ref.read(liveViewVisibleProvider.notifier).state =
                                  false,
                    ),
                  ),
                ),
              ),

              // ── Resize zones: edges, then corners on top ───────────────────
              for (final (hx, hy) in const [
                (-1, 0),
                (1, 0),
                (0, -1),
                (0, 1),
                (-1, -1),
                (1, -1),
                (-1, 1),
                (1, 1),
              ])
                _resizeZone(hx, hy),
            ],
          ),
        ),
      ),
    );
  }

  Offset _toLocal(Offset global) =>
      (context.findRenderObject() as RenderBox).globalToLocal(global);

  void _showCornerCursor(Offset global, int diagonal) => setState(() {
    _cornerCursorAt = _toLocal(global);
    _cornerCursorDiagonal = diagonal;
  });

  void _hideCornerCursor() {
    if (_cornerCursorAt != null) setState(() => _cornerCursorAt = null);
  }

  Widget _resizeZone(int hx, int hy) {
    final isCorner = hx != 0 && hy != 0;
    final diagonal = hx == hy ? 1 : -1;
    final cursor =
        isCorner
            ? SystemMouseCursors.none
            : hx == 0
            ? SystemMouseCursors.resizeUpDown
            : SystemMouseCursors.resizeLeftRight;

    // Edge bands run between the corner squares.
    double? along(int h) => h == 0 ? _corner : null;

    return Positioned(
      left: hx == -1 ? 0 : along(hx),
      right: hx == 1 ? 0 : along(hx),
      top: hy == -1 ? 0 : along(hy),
      bottom: hy == 1 ? 0 : along(hy),
      width: hx != 0 ? (isCorner ? _corner : _edge) : null,
      height: hy != 0 ? (isCorner ? _corner : _edge) : null,
      child: MouseRegion(
        cursor: cursor,
        onHover:
            isCorner ? (e) => _showCornerCursor(e.position, diagonal) : null,
        onExit:
            isCorner
                ? (_) {
                  if (!_resizingCorner) _hideCornerCursor();
                }
                : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (_) {
            // Catch a glide mid-flight, then resize from where it stopped.
            if (_x.isAnimating || _y.isAnimating) {
              _settle();
              _storeFractions();
            }
          },
          onPanStart: (_) => _resizingCorner = isCorner,
          onPanUpdate: (d) {
            _resize(hx, hy, d.delta);
            if (isCorner) _showCornerCursor(d.globalPosition, diagonal);
          },
          onPanEnd: (_) => _endResize(),
          onPanCancel: _endResize,
        ),
      ),
    );
  }

  void _endResize() {
    if (!_resizingCorner) return;
    _resizingCorner = false;
    _hideCornerCursor();
  }
}

/// A macOS-style diagonal double arrow (black, white outline) — stands in
/// for the diagonal resize cursor macOS doesn't provide.
class _DiagonalCursorPainter extends CustomPainter {
  const _DiagonalCursorPainter(this.diagonal);

  static const double size = 24;

  /// 1 = top-left ↔ bottom-right, -1 = top-right ↔ bottom-left.
  final int diagonal;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    const half = 8.5, head = 5.0, wing = 4.5, shaft = 1.25;
    final arrow =
        Path()
          ..moveTo(-half, 0)
          ..lineTo(-half + head, -wing)
          ..lineTo(-half + head, -shaft)
          ..lineTo(half - head, -shaft)
          ..lineTo(half - head, -wing)
          ..lineTo(half, 0)
          ..lineTo(half - head, wing)
          ..lineTo(half - head, shaft)
          ..lineTo(-half + head, shaft)
          ..lineTo(-half + head, wing)
          ..close();

    canvas
      ..save()
      ..translate(canvasSize.width / 2, canvasSize.height / 2)
      ..rotate(diagonal * math.pi / 4)
      ..drawPath(
        arrow,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawPath(arrow, Paint()..color = Colors.black)
      ..restore();
  }

  @override
  bool shouldRepaint(_DiagonalCursorPainter oldDelegate) =>
      oldDelegate.diagonal != diagonal;
}

class _HoverFade extends StatelessWidget {
  const _HoverFade({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: visible ? 1 : 0,
      child: IgnorePointer(ignoring: !visible, child: child),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Hide live view',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceInverse.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(
              'assets/vectors/close.svg',
              width: 16,
              height: 16,
              colorFilter: const ColorFilter.mode(
                AppColors.iconInverse,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
