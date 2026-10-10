import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ndi/ndi_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/providers/active_line_provider.dart';
import '../../../shared/providers/lyrics_provider.dart';
import '../../../shared/providers/lyrics_style_provider.dart';
import '../../../shared/providers/lyrics_visibility_provider.dart';
import '../../../shared/widgets/checkerboard.dart';
import '../../../shared/widgets/lyric_block_mask.dart';
import '../../../shared/widgets/lyrics_overlay.dart';
import '../../../shared/widgets/scroll_fade_mask.dart';
import '../../../shared/widgets/static_video_background.dart';

class NdiOperatorView extends ConsumerStatefulWidget {
  const NdiOperatorView({super.key});

  @override
  ConsumerState<NdiOperatorView> createState() => _NdiOperatorViewState();
}

/// Frames this isolate has drawn. Flutter only draws when something changed,
/// so an unchanged count means the output canvas is unchanged too.
int _drawnFrames = 0;
bool _frameCounterInstalled = false;

void _installFrameCounter() {
  if (_frameCounterInstalled) return;
  _frameCounterInstalled = true;
  SchedulerBinding.instance.addPersistentFrameCallback((_) => _drawnFrames++);
}

class _NdiOperatorViewState extends ConsumerState<NdiOperatorView> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  Timer? _captureTimer;
  bool _isCapturing = false;

  /// [_drawnFrames] at the last capture; null forces the next one.
  int? _capturedFrame;

  @override
  void initState() {
    super.initState();
    _installFrameCounter();
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
    _capturedFrame = null;
    // Run at ~30fps
    _captureTimer = Timer.periodic(
      const Duration(milliseconds: 33),
      (_) => _captureFrame(),
    );
  }

  void _stopCaptureLoop() {
    _captureTimer?.cancel();
    _captureTimer = null;
  }

  Future<void> _captureFrame() async {
    if (_isCapturing) return;

    // Reading 1080p back from the GPU is the expensive part, so skip it
    // while nothing changed. Video textures update without a Flutter frame,
    // so a video background always captures.
    final isVideo =
        ref.read(lyricsStyleProvider).backgroundType == BackgroundType.video;
    // The last frame is still re-sent every tick: receivers that pace by
    // timestamp (OBS) buffer and lag behind a stream with gaps.
    if (!isVideo && _capturedFrame == _drawnFrames) {
      ref.read(ndiServiceProvider.notifier).resendLastFrame();
      return;
    }

    _isCapturing = true;
    // Taken before the async capture: frames drawn meanwhile trigger another.
    _capturedFrame = _drawnFrames;

    try {
      final boundary =
          _repaintBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null || !boundary.attached) {
        _isCapturing = false;
        return;
      }

      final image = await boundary.toImage(pixelRatio: 1.0);
      // NDI's RGBA FourCC expects straight alpha; rawRgba is premultiplied,
      // which darkens soft edges once a transparent frame is keyed.
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );

      if (byteData != null) {
        ref
            .read(ndiServiceProvider.notifier)
            .updateFrameBuffer(byteData.buffer.asUint8List());
      }
      image.dispose();
    } catch (e) {
      print('NDI: Frame capture error: $e');
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

    return Positioned(
      left: -2000,
      top: -2000,
      child: RepaintBoundary(
        key: _repaintBoundaryKey,
        child: const SizedBox(
          width: LyricsOutputCanvas.width,
          height: LyricsOutputCanvas.height,
          child: LyricsOutputCanvas(),
        ),
      ),
    );
  }
}

/// The audience-facing output (background + lyrics) as rendered on the
/// presentation window, at [width] × [height]. Drives NDI capture and the
/// operator's live view, which scales it down with a [FittedBox].
///
/// With [BackgroundType.transparent] the canvas paints no background, so the
/// NDI frame carries alpha. Set [showTransparency] on on-screen views to show
/// a checkerboard there instead.
class LyricsOutputCanvas extends ConsumerWidget {
  const LyricsOutputCanvas({super.key, this.showTransparency = false});

  final bool showTransparency;

  static const double width = 1920;
  static const double height = 1080;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyrics = ref.watch(lyricsProvider);
    final style = ref.watch(lyricsStyleProvider);
    final isVisible = ref.watch(lyricsVisibilityProvider);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 1. Background layer
          if (style.backgroundType == BackgroundType.transparent)
            if (showTransparency)
              const Positioned.fill(child: Checkerboard(cellSize: 48))
            else
              const SizedBox.shrink()
          else
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color:
                      style.backgroundType == BackgroundType.solidColor
                          ? style.backgroundColor
                          : Colors.black,
                  gradient:
                      style.backgroundType == BackgroundType.gradient
                          ? (style.gradientType == GradientType.linear
                              ? LinearGradient(
                                colors:
                                    style.gradientColors.length >= 2
                                        ? style.gradientColors
                                        : [Colors.white, Colors.black],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              )
                              : RadialGradient(
                                colors:
                                    style.gradientColors.length >= 2
                                        ? style.gradientColors
                                        : [Colors.white, Colors.black],
                                center: Alignment.center,
                                radius: 0.8,
                              ))
                          : null,
                  image:
                      style.backgroundType == BackgroundType.image &&
                              style.backgroundImagePath != null
                          ? DecorationImage(
                            image: FileImage(File(style.backgroundImagePath!)),
                            fit: BoxFit.cover,
                          )
                          : null,
                ),
              ),
            ),

          // 2. Video Background (if active)
          if (style.backgroundType == BackgroundType.video &&
              style.backgroundVideoPath != null)
            Positioned.fill(
              child: StaticVideoBackground(path: style.backgroundVideoPath!),
            ),

          // 3. Readability overlay (transparent background only)
          if (style.backgroundType == BackgroundType.transparent)
            Positioned.fill(
              child: LyricsOverlay(
                position: style.position,
                tone: style.overlayTone,
                opacity: style.overlayOpacity / 100,
                visible: style.overlay && lyrics != null && isVisible,
              ),
            ),

          // 4. Lyrics layer
          Positioned.fill(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: isVisible ? 1.0 : 0.0,
              child:
                  lyrics != null
                      ? const _NdiLyricsPreview()
                      : const SizedBox.shrink(),
            ),
          ),
        ],
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

  /// Per page: the page root and its lyric block, for [LyricBlockMask].
  final Map<int, GlobalKey> _pageKeys = {};
  final Map<int, GlobalKey> _blockKeys = {};

  static const _animDuration = Duration(milliseconds: 400);
  static const _animCurve = Curves.easeOutCubic;

  /// Fade length where scrolling lyrics run past the canvas edge.
  static const _overflowFade = 120.0;

  @override
  void initState() {
    super.initState();
    final style = ref.read(lyricsStyleProvider);
    final lines = ref.read(lyricsLinesProvider);
    final activeIndex = ref.read(activeLineProvider);

    final segmented = ref.read(segmentedLyricsProvider);

    _pageController = PageController(
      initialPage:
          (style.displayLines > 0 && lines.isNotEmpty)
              ? activeIndex ~/ style.displayLines
              : (style.displayLines == -1 &&
                  segmented.isSegmented &&
                  lines.isNotEmpty)
              ? _getSegmentPageIndex(
                activeIndex,
                segmented.segments
                    .where((s) => !s.isHidden)
                    .map((s) => s.lineCount)
                    .toList(),
              )
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
      final activeSegIdx = _getSegmentPageIndex(
        activeIndex,
        segmented.segments
            .where((s) => !s.isHidden)
            .map((s) => s.lineCount)
            .toList(),
      );

      if (_pageController.hasClients &&
          _pageController.page?.round() != activeSegIdx) {
        _pageController.animateToPage(
          activeSegIdx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }

      // Sync large segment scrolling IMMEDIATELY during page slide.
      if (segmented.segments[activeSegIdx].lineCount > 4) {
        _scrollToLine(activeIndex);
      }
    } else {
      _scrollToLine(activeIndex);
    }
  }

  void _scrollToLine(int lineIndex) {
    // First attempt immediately after build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _performLineScrollAnimation(lineIndex);
    });

    // Also retry after a small delay for segment switches.
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _performLineScrollAnimation(lineIndex);
    });

    // Final check for slow page transitions.
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _performLineScrollAnimation(lineIndex);
    });
  }

  void _performLineScrollAnimation(int lineIndex) {
    if (!_scrollController.hasClients) return;

    // Clipped continuous lyrics pin their band's first line; otherwise the
    // active line is the anchor.
    final band = _clippedContinuous ? _bandHeight(lineIndex) : null;
    final count = ref.read(lyricsLinesProvider).length;
    final anchor =
        band != null
            ? LyricBlockMask.bandRange(
              lineIndex,
              count,
              slot: ref.read(lyricsStyleProvider).position.index,
            ).$1
            : lineIndex;

    final key = _lineKeys[anchor];
    if (key == null || key.currentContext == null) return;

    final renderBox = key.currentContext!.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final viewport = _scrollController.position;
    final scrollObject = viewport.context.storageContext.findRenderObject();
    if (scrollObject == null) return;

    final lineOffset = renderBox.localToGlobal(
      Offset.zero,
      ancestor: scrollObject,
    );

    // Where the line should rest: clipped continuous lyrics pin their band
    // at the position; otherwise the line sits at the scroll anchor.
    final position = ref.read(lyricsStyleProvider).position;
    final restY =
        band != null
            ? position.bandTop(
              viewport.viewportDimension,
              band,
              LyricBlockMask.defaultFade,
            )
            : viewport.viewportDimension * position.scrollAnchor;

    final targetOffset = (_scrollController.offset + lineOffset.dy - restY)
        .clamp(0.0, viewport.maxScrollExtent);

    // Jump instantly for large switches to hide correction glance.
    if ((_scrollController.offset - targetOffset).abs() >
        viewport.viewportDimension) {
      _scrollController.jumpTo(targetOffset);
    } else {
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// Continuous mode (All, or Auto without sections) with clipping on: the
  /// lines scroll through a band pinned at the position.
  bool get _clippedContinuous {
    final style = ref.read(lyricsStyleProvider);
    if (!style.clipped || style.displayLines > 0) return false;
    return !(style.displayLines == -1 &&
        ref.read(segmentedLyricsProvider).isSegmented);
  }

  /// Height of the band around the active line.
  double? _bandHeight(int activeIndex) {
    final count = ref.read(lyricsLinesProvider).length;
    if (count == 0) return null;
    final (first, last) = LyricBlockMask.bandRange(
      activeIndex,
      count,
      slot: ref.read(lyricsStyleProvider).position.index,
    );
    return LyricBlockMask.bandHeight((i) => _lineKeys[i], first, last);
  }

  /// The pinned band in the view, for [LyricBlockMask] in continuous mode.
  Rect? _measureContinuousBand() {
    if (!_scrollController.hasClients) return null;
    final band = _bandHeight(ref.read(activeLineProvider));
    if (band == null) return null;
    final top = ref
        .read(lyricsStyleProvider)
        .position
        .bandTop(
          _scrollController.position.viewportDimension,
          band,
          LyricBlockMask.defaultFade,
        );
    return Rect.fromLTWH(0, top, 0, band);
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

  @override
  Widget build(BuildContext context) {
    final lines = ref.watch(lyricsLinesProvider);
    final activeIndex = ref.watch(activeLineProvider);
    final styleState = ref.watch(lyricsStyleProvider);

    ref.listen<int>(activeLineProvider, (prev, next) => _handleMovement(next));
    ref.listen<int>(
      scrollToActiveTriggerProvider,
      (prev, next) => _handleMovement(ref.read(activeLineProvider)),
    );

    // Ensure the active lyric stays on screen when display lines or lyrics change.
    ref.listen<LyricsStyleState>(lyricsStyleProvider, (prev, next) {
      if (prev?.displayLines != next.displayLines) {
        setState(() {
          final lines = ref.read(lyricsLinesProvider);
          final activeIndex = ref.read(activeLineProvider);
          final oldController = _pageController;

          final segmented = ref.read(segmentedLyricsProvider);

          _pageController = PageController(
            initialPage:
                (next.displayLines > 0 && lines.isNotEmpty)
                    ? activeIndex ~/ next.displayLines
                    : (next.displayLines == -1 &&
                        segmented.isSegmented &&
                        lines.isNotEmpty)
                    ? _getSegmentPageIndex(
                      activeIndex,
                      segmented.segments
                          .where((s) => !s.isHidden)
                          .map((s) => s.lineCount)
                          .toList(),
                    )
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
    final positionAlignment = styleState.position.alignment;

    // Re-anchor the active line when the position, size or clipping changes.
    ref.listen<(LyricsPosition, LyricsSize, bool, int)>(
      lyricsStyleProvider.select(
        (s) => (s.position, s.size, s.clipped, s.lineHeight),
      ),
      (prev, next) => _handleMovement(ref.read(activeLineProvider)),
    );

    final segmentedState = ref.watch(segmentedLyricsProvider);
    bool shouldPaginate = false;
    int totalPages = 1;

    if (styleState.displayLines > 0) {
      shouldPaginate = true;
      totalPages = (lines.length / styleState.displayLines).ceil();
    } else if (styleState.displayLines == -1 &&
        segmentedState.isSegmented &&
        lines.isNotEmpty) {
      // Always paginate by segment in Auto mode.
      shouldPaginate = true;
      totalPages = segmentedState.segments.length;
    }

    if (shouldPaginate) {
      final visibleCounts =
          segmentedState.segments
              .where((s) => !s.isHidden)
              .map((s) => s.lineCount)
              .toList();
      final activePage =
          styleState.displayLines > 0
              ? activeIndex ~/ styleState.displayLines
              : _getSegmentPageIndex(activeIndex, visibleCounts);
      return LyricBlockMask(
        enabled: styleState.clipped,
        listenable: _pageController,
        duration: _animDuration,
        curve: _animCurve,
        measure: () {
          if (activePage >= totalPages) return null;
          // Large segments scroll inside their page; nothing to clip to.
          if (styleState.displayLines == -1 &&
              activePage < visibleCounts.length &&
              visibleCounts[activePage] > 4) {
            return LyricBlockMask.showAll;
          }
          return LyricBlockMask.blockRect(
            _blockKeys[activePage],
            _pageKeys[activePage],
          );
        },
        child: PageView.builder(
          key: ValueKey(
            'ndi_paginated_view_${styleState.displayLines}_${segmentedState.isSegmented}',
          ),
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
              // Segmented paging - only consider visible segments
              final visibleSegments =
                  segmentedState.segments.where((s) => !s.isHidden).toList();
              startIdx = 0;
              for (int i = 0; i < pageIndex; i++) {
                startIdx += visibleSegments[i].lineCount;
              }
              endIdx = startIdx + visibleSegments[pageIndex].lineCount;
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

                      final EdgeInsets pagePadding =
                          isAutoLargeSegment
                              ? EdgeInsets.zero
                              : const EdgeInsets.symmetric(
                                vertical: AppSpacing.x2l,
                              );

                      final Widget pageWidget = Builder(
                        builder: (context) {
                          final Widget lineList = Column(
                            key:
                                isAutoLargeSegment
                                    ? null
                                    : _blockKeys.putIfAbsent(
                                      pageIndex,
                                      GlobalKey.new,
                                    ),
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
                                _buildLine(
                                  i,
                                  lines[i],
                                  activeIndex,
                                  styleState,
                                  useKey: isAutoLargeSegment,
                                ),
                            ],
                          );

                          if (isAutoLargeSegment) {
                            final bool isActivePage =
                                pageIndex ==
                                _getSegmentPageIndex(
                                  activeIndex,
                                  segmentedState.segments
                                      .where((s) => !s.isHidden)
                                      .map((s) => s.lineCount)
                                      .toList(),
                                );
                            // Center the content if it fits within the
                            // available height; only scroll when it overflows.
                            return ScrollConfiguration(
                              behavior: ScrollConfiguration.of(
                                context,
                              ).copyWith(scrollbars: false),
                              child: ScrollFadeMask(
                                extent: _overflowFade,
                                child: CustomScrollView(
                                  controller:
                                      isActivePage ? _scrollController : null,
                                  slivers: [
                                    SliverFillRemaining(
                                      hasScrollBody: false,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: AppSpacing.x2l,
                                        ),
                                        child: Align(
                                          alignment: positionAlignment,
                                          child: lineList,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return Align(
                            alignment: positionAlignment,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.x2l,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: positionAlignment,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints.tightFor(
                                    width: constraints.maxWidth,
                                  ),
                                  child: lineList,
                                ),
                              ),
                            ),
                          );
                        },
                      );

                      return SizedBox.expand(
                        key: _pageKeys.putIfAbsent(pageIndex, GlobalKey.new),
                        child: Padding(padding: pagePadding, child: pageWidget),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return LyricBlockMask(
      enabled: styleState.clipped,
      listenable: _scrollController,
      measure: _measureContinuousBand,
      duration: _animDuration,
      curve: _animCurve,
      child: LayoutBuilder(
        builder:
            (context, constraints) => Align(
              alignment: positionAlignment,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(scrollbars: false),
                  child: ScrollFadeMask(
                    // Clipped: the band mask does the fading.
                    extent: styleState.clipped ? 0 : _overflowFade,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      // Clipped: a screen of slack at both ends, so even the first
                      // and last lines can sit in the pinned band.
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.x5l,
                        vertical:
                            styleState.clipped
                                ? constraints.maxHeight
                                : AppSpacing.x2l,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (int i = 0; i < lines.length; i++)
                            _buildLine(
                              i,
                              lines[i],
                              activeIndex,
                              styleState,
                              useKey: true,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildLine(
    int i,
    String line,
    int activeIndex,
    LyricsStyleState styleState, {
    bool useKey = false,
  }) {
    return AnimatedPadding(
      key: useKey ? _keyFor(i) : null,
      duration: _animDuration,
      curve: _animCurve,
      padding: EdgeInsets.only(bottom: styleState.lineGap),
      child: AnimatedDefaultTextStyle(
        duration: _animDuration,
        curve: _animCurve,
        style: styleState.size.textStyle.copyWith(
          fontFamily: styleState.fontFamily,
          color:
              i == activeIndex
                  ? styleState.fontColor
                  : styleState.fontColor.withValues(alpha: 0.2),
          height: 1.4,
          shadows: styleState.shadowFor(i == activeIndex ? 1 : 0.2),
        ),
        child: SizedBox(
          width: double.infinity,
          child: Text(line, textAlign: styleState.textAlign, softWrap: true),
        ),
      ),
    );
  }
}
