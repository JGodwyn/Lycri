import 'dart:async';
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
import '../../../shared/providers/lyrics_visibility_provider.dart';
import '../../../shared/widgets/static_video_background.dart';

class NdiOperatorView extends ConsumerStatefulWidget {
  const NdiOperatorView({super.key});

  @override
  ConsumerState<NdiOperatorView> createState() => _NdiOperatorViewState();
}

class _NdiOperatorViewState extends ConsumerState<NdiOperatorView> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  Timer? _captureTimer;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(ndiServiceProvider)) {
        _startCaptureLoop();
      }
    });
  }

  @override
  void dispose() {
    _stopCaptureLoop();
    super.dispose();
  }

  void _startCaptureLoop() {
    _stopCaptureLoop();
    // Run at ~30fps
    _captureTimer = Timer.periodic(const Duration(milliseconds: 33), (_) => _captureFrame());
  }

  void _stopCaptureLoop() {
    _captureTimer?.cancel();
    _captureTimer = null;
  }

  Future<void> _captureFrame() async {
    if (_isCapturing) return;
    _isCapturing = true;

    try {
      final boundary = _repaintBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        _isCapturing = false;
        return;
      }
      
      // If the boundary is not yet laid out, wait.
      if (!boundary.attached || boundary.debugNeedsPaint) {
        _isCapturing = false;
        return;
      }

      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      
      if (byteData != null) {
        ref.read(ndiServiceProvider.notifier).updateFrameBuffer(byteData.buffer.asUint8List());
      }
      image.dispose(); // Important to dispose image to avoid memory leaks
    } catch (e) {
      // Silently fail if frame isn't ready
    } finally {
      _isCapturing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(ndiServiceProvider, (previous, current) {
      if (current) {
        _startCaptureLoop();
      } else {
        _stopCaptureLoop();
      }
    });

    final isNdiEnabled = ref.watch(ndiServiceProvider);
    if (!isNdiEnabled) return const SizedBox.shrink();

    final lyrics = ref.watch(lyricsProvider);
    final style = ref.watch(lyricsStyleProvider);
    final isVisible = ref.watch(lyricsVisibilityProvider);

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
                // 1. Background layer
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: style.backgroundType == BackgroundType.solidColor
                          ? style.backgroundColor
                          : Colors.black,
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

                // 2. Video Background (if active)
                if (style.backgroundType == BackgroundType.video && style.backgroundVideoPath != null)
                  Positioned.fill(
                    child: StaticVideoBackground(path: style.backgroundVideoPath!),
                  ),

                // 3. Lyrics layer
                Positioned.fill(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: isVisible ? 1.0 : 0.0,
                    child: lyrics != null ? const _NdiLyricsPreview() : const SizedBox.shrink(),
                  ),
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
  late PageController _pageController;
  final Map<int, GlobalKey> _lineKeys = {};

  static const _animDuration = Duration(milliseconds: 400);
  static const _animCurve = Curves.easeOutCubic;

  @override
  void initState() {
    super.initState();
    final style = ref.read(lyricsStyleProvider);
    final lines = ref.read(lyricsLinesProvider);
    final activeIndex = ref.read(activeLineProvider);
    
    final segmented = ref.read(segmentedLyricsProvider);

    _pageController = PageController(
      initialPage: (style.displayLines > 0 && lines.isNotEmpty)
          ? activeIndex ~/ style.displayLines
          : (style.displayLines == -1 && segmented.isSegmented && lines.isNotEmpty)
              ? _getSegmentPageIndex(activeIndex, segmented.segments.map((s) => s.lineCount).toList())
              : 0,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleMovement(activeIndex);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(int index) {
    return _lineKeys.putIfAbsent(index, () => GlobalKey());
  }

  void _handleMovement(int activeIndex) {
    final style = ref.read(lyricsStyleProvider);
    final segmented = ref.read(segmentedLyricsProvider);

    if (style.displayLines > 0) {
      _scrollToPage(activeIndex, style.displayLines);
    } else if (style.displayLines == -1 && segmented.isSegmented) {
      final activeSegIdx = _getSegmentPageIndex(activeIndex, segmented.segments.map((s) => s.lineCount).toList());
      
      // Always animate to the current segment's page.
      _scrollToExactPage(activeSegIdx);
      
      // If the segment is large (> 4 lines), also handle internal scrolling.
      if (segmented.segments[activeSegIdx].lineCount > 4) {
        _scrollToLine(activeIndex);
      }
    } else {
      _scrollToLine(activeIndex);
    }
  }

  void _scrollToExactPage(int targetPage) {
    if (!_pageController.hasClients) return;
    if (_pageController.page?.round() != targetPage) {
      _pageController.animateToPage(
        targetPage,
        duration: _animDuration,
        curve: _animCurve,
      );
    }
  }

  int _getSegmentPageIndex(int activeIndex, List<int> segmentLineCounts) {
    if (segmentLineCounts.isEmpty) return 0;
    int currentSum = 0;
    for (int i = 0; i < segmentLineCounts.length; i++) {
        currentSum += segmentLineCounts[i];
        if (activeIndex < currentSum) return i;
    }
    return 0;
  }

  void _scrollToPage(int activeIndex, int displayLines) {
    if (!_pageController.hasClients) return;
    final targetPage = activeIndex ~/ displayLines;
    if (_pageController.page?.round() != targetPage) {
      _pageController.animateToPage(
        targetPage,
        duration: _animDuration,
        curve: _animCurve,
      );
    }
  }

  void _scrollToLine(int activeIndex) {
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

    ref.listen<int>(activeLineProvider, (prev, next) => _handleMovement(next));
    ref.listen<int>(scrollToActiveTriggerProvider, (prev, next) => _handleMovement(ref.read(activeLineProvider)));

    // Ensure the active lyric stays on screen when display lines or lyrics change.
    ref.listen<LyricsStyleState>(lyricsStyleProvider, (prev, next) {
      if (prev?.displayLines != next.displayLines) {
        setState(() {
          final lines = ref.read(lyricsLinesProvider);
          final activeIndex = ref.read(activeLineProvider);
          final oldController = _pageController;
          
          final segmented = ref.read(segmentedLyricsProvider);

          _pageController = PageController(
            initialPage: (next.displayLines > 0 && lines.isNotEmpty)
                ? activeIndex ~/ next.displayLines
                : (next.displayLines == -1 && segmented.isSegmented && lines.isNotEmpty)
                    ? _getSegmentPageIndex(activeIndex, segmented.segments.map((s) => s.lineCount).toList())
                    : 0,
          );
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            oldController.dispose();
            _handleMovement(activeIndex);
          });
        });
      }
    });

    ref.listen<List<String>>(lyricsLinesProvider, (prev, next) {
      if (prev?.length != next.length) {
        _handleMovement(ref.read(activeLineProvider));
      }
    });

    _lineKeys.removeWhere((k, _) => k >= lines.length);

    final segmentedState = ref.watch(segmentedLyricsProvider);
    bool shouldPaginate = false;
    int totalPages = 1;

    if (styleState.displayLines > 0) {
      shouldPaginate = true;
      totalPages = (lines.length / styleState.displayLines).ceil();
    } else if (styleState.displayLines == -1 && segmentedState.isSegmented && lines.isNotEmpty) {
      // Always paginate by segment in Auto mode.
      shouldPaginate = true;
      totalPages = segmentedState.segments.length;
    }

    if (shouldPaginate) {
      return PageView.builder(
        key: ValueKey('ndi_paginated_view_${styleState.displayLines}_${segmentedState.isSegmented}'),
        controller: _pageController,
        scrollDirection: Axis.vertical,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: totalPages,
        itemBuilder: (context, pageIndex) {
          int startIdx;
          int endIdx;

          if (styleState.displayLines > 0) {
            startIdx = pageIndex * styleState.displayLines;
            endIdx = startIdx + styleState.displayLines;
          } else {
             // Segmented paging
             startIdx = 0;
             for (int i = 0; i < pageIndex; i++) {
                 startIdx += segmentedState.segments[i].lineCount;
             }
             endIdx = startIdx + segmentedState.segments[pageIndex].lineCount;
          }

          if (endIdx > lines.length) endIdx = lines.length;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x5l,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isAutoLargeSegment = 
                        styleState.displayLines == -1 &&
                        segmentedState.segments[pageIndex].lineCount > 4;

                    final EdgeInsets pagePadding = isAutoLargeSegment 
                        ? EdgeInsets.zero 
                        : const EdgeInsets.symmetric(vertical: AppSpacing.x2l);

                    final Widget pageWidget = Builder(builder: (context) {
                      final Widget lineList = Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment:
                            styleState.textAlign == TextAlign.center
                                ? CrossAxisAlignment.center
                                : styleState.textAlign == TextAlign.right
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                        children: [
                          for (int i = startIdx; i < endIdx; i++)
                            _buildLine(i, lines[i], activeIndex, styleState, useKey: isAutoLargeSegment),
                        ],
                      );

                      if (isAutoLargeSegment) {
                        final bool isActivePage = pageIndex == _getSegmentPageIndex(activeIndex, segmentedState.segments.map((s) => s.lineCount).toList());
                        return ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.x2l,
                            ),
                            controller: isActivePage ? _scrollController : null,
                            child: lineList,
                          ),
                        );
                      }

                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2l),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.center,
                            child: ConstrainedBox(
                              constraints: BoxConstraints.tightFor(
                                width: constraints.maxWidth,
                              ),
                              child: lineList,
                            ),
                          ),
                        ),
                      );
                    });

                    return SizedBox.expand(
                      child: Padding(
                        padding: pagePadding,
                        child: pageWidget,
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x5l,
              vertical: AppSpacing.x2l,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < lines.length; i++)
                  _buildLine(i, lines[i], activeIndex, styleState, useKey: true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLine(int i, String line, int activeIndex, LyricsStyleState styleState, {bool useKey = false}) {
    return Padding(
      key: useKey ? _keyFor(i) : null,
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
          child: Text(line, textAlign: styleState.textAlign, softWrap: true),
        ),
      ),
    );
  }
}
