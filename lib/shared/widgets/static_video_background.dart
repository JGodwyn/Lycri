import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:video_player/video_player.dart';

/// A simple looping video player for backgrounds.
/// Trims playback to 15 seconds if longer.
///
/// Every background showing the same [path] in this window shares one
/// [_VideoLoop], so the presenter preview, live view and NDI output decode
/// the file once (and stay frame-synced) instead of once each.
class StaticVideoBackground extends StatefulWidget {
  final String path;
  const StaticVideoBackground({super.key, required this.path});

  @override
  State<StaticVideoBackground> createState() => StaticVideoBackgroundState();
}

class StaticVideoBackgroundState extends State<StaticVideoBackground>
    with WidgetsBindingObserver {
  late _VideoLoop _loop;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loop = _VideoLoop.acquire(widget.path)..addListener(_onLoopChanged);
  }

  @override
  void didUpdateWidget(StaticVideoBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      final old = _loop;
      _loop = _VideoLoop.acquire(widget.path)..addListener(_onLoopChanged);
      old
        ..removeListener(_onLoopChanged)
        ..release();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If the app is resumed, ensure the active video is actually playing.
    // Some platforms (like macOS/iOS) pause video when focus is lost.
    if (state == AppLifecycleState.resumed) {
      _loop.ensurePlaying();
    }
  }

  void _onLoopChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loop
      ..removeListener(_onLoopChanged)
      ..release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = _loop.controllerA;
    final b = _loop.controllerB;
    final hasA = a.value.isInitialized;
    final hasB = b.value.isInitialized;

    if (!hasA && !hasB) return Container(color: Colors.black);

    return Stack(
      children: [
        if (hasA)
          Positioned.fill(
            child: FadeTransition(
              opacity: _loop.opacityA,
              child: VideoPlayerItem(controller: a),
            ),
          ),
        if (hasB)
          Positioned.fill(
            child: FadeTransition(
              opacity: _loop.opacityB,
              child: VideoPlayerItem(controller: b),
            ),
          ),
      ],
    );
  }
}

/// Two players of one file cross-fading into each other at the loop point,
/// shared by every [StaticVideoBackground] of that file. Reference-counted:
/// disposed when the last background lets go.
class _VideoLoop extends ChangeNotifier implements TickerProvider {
  _VideoLoop._(this.path) {
    _crossFade = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    opacityA = Tween<double>(begin: 1.0, end: 0.0).animate(_crossFade);
    opacityB = Tween<double>(begin: 0.0, end: 1.0).animate(_crossFade);

    controllerA = VideoPlayerController.file(File(path))
      ..initialize().then((_) {
        if (_disposed) return;
        controllerA.setLooping(false);
        controllerA.setVolume(0);
        controllerA.play();
        controllerA.addListener(_loopListener);
        notifyListeners();
      });

    controllerB = VideoPlayerController.file(File(path))
      ..initialize().then((_) {
        if (_disposed) return;
        controllerB.setLooping(false);
        controllerB.setVolume(0);
        controllerB.addListener(_loopListener);
        notifyListeners();
      });
  }

  static final Map<String, _VideoLoop> _loops = {};

  /// The loop for [path], created on first use. Pair with [release].
  static _VideoLoop acquire(String path) {
    final loop = _loops.putIfAbsent(path, () => _VideoLoop._(path));
    loop._users++;
    return loop;
  }

  final String path;
  late final VideoPlayerController controllerA;
  late final VideoPlayerController controllerB;
  late final AnimationController _crossFade;
  late final Animation<double> opacityA;
  late final Animation<double> opacityB;

  int _users = 0;
  bool _disposed = false;
  bool _isShowingB = false;
  bool _isTransitioning = false;

  void release() {
    if (--_users > 0) return;
    _loops.remove(path);
    dispose();
  }

  void ensurePlaying() {
    final controller = _isShowingB ? controllerB : controllerA;
    if (controller.value.isInitialized && !controller.value.isPlaying) {
      controller.play();
    }
  }

  void _loopListener() {
    if (_disposed || _isTransitioning) return;

    final controller = _isShowingB ? controllerB : controllerA;
    if (!controller.value.isInitialized) return;

    final totalDuration = controller.value.duration;
    final maxPlayback =
        totalDuration < const Duration(seconds: 15)
            ? totalDuration
            : const Duration(seconds: 15);

    final transitionPoint = maxPlayback - const Duration(milliseconds: 500);

    if (controller.value.position >= transitionPoint) {
      _startTransition();
    }
  }

  void _startTransition() {
    if (_disposed) return;
    _isTransitioning = true;

    if (_isShowingB) {
      controllerA.seekTo(Duration.zero);
      controllerA.play();
      _crossFade.reverse().then((_) {
        if (_disposed) return;
        controllerB.pause();
        _isShowingB = false;
        _isTransitioning = false;
      });
    } else {
      controllerB.seekTo(Duration.zero);
      controllerB.play();
      _crossFade.forward().then((_) {
        if (_disposed) return;
        controllerA.pause();
        _isShowingB = true;
        _isTransitioning = false;
      });
    }
  }

  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);

  @override
  void dispose() {
    _disposed = true;
    controllerA.removeListener(_loopListener);
    controllerB.removeListener(_loopListener);
    controllerA.dispose();
    controllerB.dispose();
    _crossFade.dispose();
    super.dispose();
  }
}

class VideoPlayerItem extends StatelessWidget {
  final VideoPlayerController controller;
  const VideoPlayerItem({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}
