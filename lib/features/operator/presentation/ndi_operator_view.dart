import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ndi/ndi_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/providers/active_line_provider.dart';
import '../../../shared/providers/lyrics_provider.dart';
import '../../../shared/providers/lyrics_style_provider.dart';

class NdiOperatorView extends ConsumerStatefulWidget {
  const NdiOperatorView({super.key});

  @override
  ConsumerState<NdiOperatorView> createState() => _NdiOperatorViewState();
}

class _NdiOperatorViewState extends ConsumerState<NdiOperatorView> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(ndiServiceProvider)) {
        _captureFrame();
      }
    });
  }

  void _captureFrame() async {
    try {
      final boundary = _repaintBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      if (boundary.debugNeedsPaint) {
         WidgetsBinding.instance.addPostFrameCallback((_) => _captureFrame());
         return;
      }

      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData != null) {
        debugPrint('NDI: Captured frame ${image.width}x${image.height}');
        ref.read(ndiServiceProvider.notifier).updateFrameBuffer(byteData.buffer.asUint8List());
      }
    } catch (e) {
      debugPrint('NDI Frame Capture Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(lyricsProvider, (previous, current) => _captureFrame());
    ref.listen(activeLineProvider, (previous, current) => _captureFrame());
    ref.listen(scrollToActiveTriggerProvider, (previous, current) => _captureFrame());
    ref.listen(lyricsStyleProvider, (previous, current) => _captureFrame());
    
    ref.listen(ndiServiceProvider, (previous, current) {
      if (current && !(previous ?? false)) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _captureFrame());
      }
    });

    final isNdiEnabled = ref.watch(ndiServiceProvider);
    if (!isNdiEnabled) return const SizedBox.shrink();

    final lyrics = ref.watch(lyricsProvider);
    final style = ref.watch(lyricsStyleProvider);

    // We position this 1080p canvas way off-screen so it's not visible to the user,
    // but Flutter still performs layout and paint, allowing RepaintBoundary to capture it.
    return Positioned(
      left: -2000,
      top: -2000,
      child: RepaintBoundary(
        key: _repaintBoundaryKey,
        child: SizedBox(
          width: 1920,
          height: 1080,
          child: Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                // Background layer
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: style.backgroundType == BackgroundType.solidColor
                          ? style.backgroundColor
                          : Colors.black, // Default to black if no other background
                      gradient: style.backgroundType == BackgroundType.gradient
                          ? (style.gradientType == GradientType.linear
                              ? LinearGradient(
                                  colors: style.gradientColors.length >= 2
                                      ? style.gradientColors
                                      : [Colors.white, Colors.black],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                )
                              : RadialGradient(
                                  colors: style.gradientColors.length >= 2
                                      ? style.gradientColors
                                      : [Colors.white, Colors.black],
                                  center: Alignment.center,
                                  radius: 0.8,
                                ))
                          : null,
                      image: style.backgroundType == BackgroundType.image &&
                              style.backgroundImagePath != null
                          ? DecorationImage(
                              image: FileImage(File(style.backgroundImagePath!)),
                              fit: BoxFit.cover)
                          : null,
                    ),
                  ),
                ),
                // Lyrics
                Positioned.fill(
                  child: lyrics != null
                      ? const _NdiLyricsPreview()
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NdiLyricsPreview extends ConsumerStatefulWidget {
  const _NdiLyricsPreview();

  @override
  ConsumerState<_NdiLyricsPreview> createState() => _NdiLyricsPreviewState();
}

class _NdiLyricsPreviewState extends ConsumerState<_NdiLyricsPreview> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _lineKeys = {};

  static const _animDuration = Duration(milliseconds: 400);
  static const _animCurve = Curves.easeOutCubic;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToActive(ref.read(activeLineProvider));
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(int index) {
    return _lineKeys.putIfAbsent(index, () => GlobalKey());
  }

  void _scrollToActive(int activeIndex) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final key = _lineKeys[activeIndex];
      if (key == null) return;
      final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) return;
      
      final viewport = _scrollController.position;
      final lineOffset = renderBox.localToGlobal(
        Offset.zero,
        ancestor: viewport.context.storageContext.findRenderObject(),
      );
      final targetOffset = _scrollController.offset + lineOffset.dy - (viewport.viewportDimension * 0.33);
      
      _scrollController.animateTo(
        targetOffset.clamp(0.0, viewport.maxScrollExtent),
        duration: _animDuration,
        curve: _animCurve,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final lines = ref.watch(lyricsLinesProvider);
    final activeIndex = ref.watch(activeLineProvider);
    final styleState = ref.watch(lyricsStyleProvider);

    ref.listen<int>(activeLineProvider, (prev, next) => _scrollToActive(next));
    ref.listen<int>(scrollToActiveTriggerProvider, (prev, next) => _scrollToActive(ref.read(activeLineProvider)));

    _lineKeys.removeWhere((k, _) => k >= lines.length);

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppSpacing.x5l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < lines.length; i++)
              Padding(
                key: _keyFor(i),
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: AnimatedDefaultTextStyle(
                  duration: _animDuration,
                  curve: _animCurve,
                  style: AppTypography.displayMd.copyWith(
                    fontFamily: styleState.fontFamily,
                    color: i == activeIndex ? styleState.fontColor : styleState.fontColor.withValues(alpha: 0.2),
                    height: 1.4,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(lines[i], textAlign: styleState.textAlign, softWrap: true),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
