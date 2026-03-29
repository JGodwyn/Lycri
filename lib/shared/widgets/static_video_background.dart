import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// A simple looping video player for backgrounds.
/// Trims playback to 15 seconds if longer.
class StaticVideoBackground extends StatefulWidget {
  final String path;
  const StaticVideoBackground({super.key, required this.path});

  @override
  State<StaticVideoBackground> createState() => StaticVideoBackgroundState();
}

class StaticVideoBackgroundState extends State<StaticVideoBackground>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controllerA;
  VideoPlayerController? _controllerB;
  late AnimationController _crossFadeController;
  late Animation<double> _opacityA;
  late Animation<double> _opacityB;

  bool _isShowingB = false;
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    _crossFadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _opacityA = Tween<double>(begin: 1.0, end: 0.0).animate(_crossFadeController);
    _opacityB = Tween<double>(begin: 0.0, end: 1.0).animate(_crossFadeController);

    _initControllers();
  }

  @override
  void didUpdateWidget(StaticVideoBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _initControllers();
    }
  }

  void _initControllers() {
    _controllerA?.dispose();
    _controllerB?.dispose();
    _isShowingB = false;
    _isTransitioning = false;
    _crossFadeController.reset();

    _controllerA = VideoPlayerController.file(File(widget.path))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _controllerA!.setLooping(false);
        _controllerA!.setVolume(0);
        _controllerA!.play();
        _controllerA!.addListener(_loopListener);
      });

    _controllerB = VideoPlayerController.file(File(widget.path))
      ..initialize().then((_) {
        if (!mounted) return;
        _controllerB!.setLooping(false);
        _controllerB!.setVolume(0);
        _controllerB!.addListener(_loopListener);
      });
  }

  void _loopListener() {
    if (!mounted || _isTransitioning) return;

    final controller = _isShowingB ? _controllerB : _controllerA;
    if (controller == null || !controller.value.isInitialized) return;

    final totalDuration = controller.value.duration;
    final maxPlayback =
        totalDuration < const Duration(seconds: 15) ? totalDuration : const Duration(seconds: 15);

    final transitionPoint = maxPlayback - const Duration(milliseconds: 500);

    if (controller.value.position >= transitionPoint) {
      _startTransition();
    }
  }

  void _startTransition() {
    if (!mounted) return;
    setState(() => _isTransitioning = true);

    if (_isShowingB) {
      _controllerA!.seekTo(Duration.zero);
      _controllerA!.play();
      _crossFadeController.reverse().then((_) {
        if (!mounted) return;
        _controllerB!.pause();
        setState(() {
          _isShowingB = false;
          _isTransitioning = false;
        });
      });
    } else {
      _controllerB!.seekTo(Duration.zero);
      _controllerB!.play();
      _crossFadeController.forward().then((_) {
        if (!mounted) return;
        _controllerA!.pause();
        setState(() {
          _isShowingB = true;
          _isTransitioning = false;
        });
      });
    }
  }

  @override
  void dispose() {
    _controllerA?.removeListener(_loopListener);
    _controllerB?.removeListener(_loopListener);
    _controllerA?.dispose();
    _controllerB?.dispose();
    _crossFadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasA = _controllerA != null && _controllerA!.value.isInitialized;
    final hasB = _controllerB != null && _controllerB!.value.isInitialized;

    if (!hasA && !hasB) return Container(color: Colors.black);

    return Stack(
      children: [
        if (hasA)
          Positioned.fill(
            child: FadeTransition(
              opacity: _opacityA,
              child: VideoPlayerItem(controller: _controllerA!),
            ),
          ),
        if (hasB)
          Positioned.fill(
            child: FadeTransition(
              opacity: _opacityB,
              child: VideoPlayerItem(controller: _controllerB!),
            ),
          ),
      ],
    );
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
