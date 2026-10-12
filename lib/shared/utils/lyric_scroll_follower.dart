import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Glides a [ScrollController] to the active lyric, and keeps gliding when
/// the active lyric changes mid-flight.
///
/// Restarting an eased `animateTo` on every prev/next press snaps the speed
/// back to the curve's start each time, and delayed re-alignments fire after
/// newer presses — stepping fast then reads as jitter. Here a critically
/// damped spring carries its velocity across retargets, and the target is
/// re-measured from the live layout every frame, so the scroll never
/// overshoots, never backtracks to a stale line and never needs a
/// correction pass.
class LyricScrollFollower {
  LyricScrollFollower({
    required TickerProvider vsync,
    required this.controller,
    required this.target,
    this.jumpBeyondViewport = false,
  }) {
    _ticker = vsync.createTicker(_tick);
  }

  final ScrollController controller;

  /// The scroll offset to rest at, measured from the current layout; null
  /// while the target line isn't laid out yet.
  final double? Function() target;

  /// Jump rather than glide when the target is more than a viewport away,
  /// so a long sweep across the lyrics doesn't show.
  final bool jumpBeyondViewport;

  late final Ticker _ticker;

  /// Spring frequency: settles in about the old 400ms ease (98% at 5.8/ω s).
  static const double _omega = 15;

  /// How long to wait for the target line to be laid out before giving up.
  static const Duration _maxWait = Duration(milliseconds: 600);

  /// Keep tracking at least this long after each [follow], even once at
  /// rest: style changes animate the lines' layout (size, line gap) for
  /// 400ms, and the target moves with it.
  static const Duration _minFollow = Duration(milliseconds: 500);

  ScrollPosition? _position;
  double _velocity = 0;
  double? _lastPixels;
  double? _lastMaxExtent;
  Duration _lastElapsed = Duration.zero;
  Duration? _missingSince;
  Duration? _holdUntil;
  bool _restartHold = false;

  /// Starts (or keeps) following [target].
  void follow() {
    _missingSince = null;
    _restartHold = true;
    if (_ticker.isActive) return;
    _velocity = 0;
    _position = null;
    _lastPixels = null;
    _lastElapsed = Duration.zero;
    _ticker.start();
  }

  void dispose() => _ticker.dispose();

  void _tick(Duration elapsed) {
    final dt =
        elapsed == Duration.zero
            ? 1 / 60
            : math.min((elapsed - _lastElapsed).inMicroseconds / 1e6, 0.05);
    _lastElapsed = elapsed;
    if (_restartHold) {
      _holdUntil = elapsed + _minFollow;
      _restartHold = false;
    }

    if (controller.positions.length != 1) return _wait(elapsed);
    final position = controller.position;
    if (!position.hasContentDimensions || !position.hasPixels) {
      return _wait(elapsed);
    }

    if (!identical(position, _position)) {
      // A different scroll view took the controller (e.g. a section page
      // switch): start fresh from wherever it sits.
      _position = position;
      _velocity = 0;
    } else if (_lastPixels != null &&
        (position.pixels - _lastPixels!).abs() > 1 &&
        position.maxScrollExtent == _lastMaxExtent) {
      // Someone scrolled by hand — let them. (A change in content size can
      // also move the offset; that's not the user.)
      return _stop();
    }

    final to = target();
    if (to == null) return _wait(elapsed);
    _missingSince = null;

    final goal = to.clamp(position.minScrollExtent, position.maxScrollExtent);
    final x0 = position.pixels - goal;
    if (jumpBeyondViewport && x0.abs() > position.viewportDimension) {
      _jump(position, goal);
      _velocity = 0;
      return;
    }
    if (x0.abs() < 0.5 && _velocity.abs() < 10) {
      _jump(position, goal);
      _velocity = 0;
      if (elapsed >= _holdUntil!) _stop();
      return;
    }

    // Exact critically damped step, stable for any frame time.
    final decay = math.exp(-_omega * dt);
    final b = _velocity + _omega * x0;
    var next = goal + (x0 + b * dt) * decay;
    _velocity = (_velocity - _omega * b * dt) * decay;
    if (next < position.minScrollExtent || next > position.maxScrollExtent) {
      next = next.clamp(position.minScrollExtent, position.maxScrollExtent);
      _velocity = 0;
    }
    _jump(position, next);
  }

  void _jump(ScrollPosition position, double pixels) {
    if (position.pixels != pixels) position.jumpTo(pixels);
    _lastPixels = position.pixels;
    _lastMaxExtent = position.maxScrollExtent;
  }

  void _wait(Duration elapsed) {
    _missingSince ??= elapsed;
    if (elapsed - _missingSince! > _maxWait) _stop();
  }

  void _stop() {
    _ticker.stop();
    _velocity = 0;
    _position = null;
    _lastPixels = null;
    _lastMaxExtent = null;
    _missingSince = null;
    _holdUntil = null;
  }
}
