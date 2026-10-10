import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_stroke.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/providers/active_line_provider.dart';
import '../../../shared/providers/display_mode_provider.dart';
import '../../../shared/providers/live_view_provider.dart';
import '../../../shared/providers/lyrics_provider.dart';
import '../../../shared/providers/lyrics_style_provider.dart';
import '../../../shared/providers/lyrics_visibility_provider.dart';
import '../../../shared/providers/presentation_window_provider.dart';
import '../../operator/models/lyrics_segment.dart';
import 'widgets/live_view_pip.dart';
import '../../../shared/widgets/static_video_background.dart';
import '../../../shared/widgets/cassette_press.dart';
import '../../../shared/widgets/inner_shadow.dart';
import '../../../shared/widgets/lycri_button.dart';
import '../../../shared/widgets/scroll_fade_mask.dart';
import '../../../shared/widgets/fade_text.dart';
import '../../../shared/widgets/lycri_pill_group.dart';
import '../../../shared/widgets/checkerboard.dart';

/// Center panel of the operator window.
/// Shows a top bar with the "Presenter" label and a "Go live" button,
/// plus a large preview area that displays either an empty state or the
/// submitted lyrics.
class PresenterPanel extends ConsumerWidget {
  const PresenterPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyrics = ref.watch(lyricsProvider);
    final lines = ref.watch(lyricsLinesProvider);
    final isLive = ref.watch(presentationWindowProvider);
    final lyricsVisible = ref.watch(lyricsVisibilityProvider);

    // Keep active line position stable during edits.
    // Only reset to 0 when lyrics are first set or fully cleared.
    // On edits, clamp the index so it stays within the new line count.
    ref.listen<String?>(lyricsProvider, (prev, next) {
      final wasEmpty = prev == null || prev.trim().isEmpty;
      final isNowEmpty = next == null || next.trim().isEmpty;

      if (wasEmpty && !isNowEmpty) {
        // First paste — start from line 0.
        ref.read(activeLineProvider.notifier).reset();
      } else if (isNowEmpty) {
        // Cleared — reset.
        ref.read(activeLineProvider.notifier).reset();
      } else {
        // Edit — clamp active index to the new line count.
        final newLines =
            next.split('\n').where((l) => l.trim().isNotEmpty).length;
        final currentIndex = ref.read(activeLineProvider);
        if (currentIndex >= newLines && newLines > 0) {
          ref.read(activeLineProvider.notifier).clampTo(newLines - 1);
        }
      }

      if (ref.read(presentationWindowProvider)) {
        final segmentedState = ref.read(segmentedLyricsProvider);
        ref
            .read(presentationWindowProvider.notifier)
            .syncLyrics(
              next,
              activeLine: ref.read(activeLineProvider),
              isSegmented: segmentedState.isSegmented,
              segmentLineCounts:
                  segmentedState.segments
                      .where((s) => !s.isHidden)
                      .map((s) => s.lineCount)
                      .toList(),
            );
        ref
            .read(presentationWindowProvider.notifier)
            .syncActiveLine(ref.read(activeLineProvider));
      }
    });

    // Sync active line position to the presentation window.
    ref.listen<int>(activeLineProvider, (prev, next) {
      if (ref.read(presentationWindowProvider)) {
        ref.read(presentationWindowProvider.notifier).syncActiveLine(next);
      }
    });

    // Sync segmentation info to the presentation window.
    ref.listen<SegmentedLyricsState>(segmentedLyricsProvider, (prev, next) {
      if (ref.read(presentationWindowProvider)) {
        ref
            .read(presentationWindowProvider.notifier)
            .syncLyrics(
              ref.read(lyricsProvider),
              activeLine: ref.read(activeLineProvider),
              isSegmented: next.isSegmented,
              segmentLineCounts:
                  next.segments
                      .where((s) => !s.isHidden)
                      .map((s) => s.lineCount)
                      .toList(),
            );
      }
    });

    // Sync font family and display lines to the presentation window.
    ref.listen<LyricsStyleState>(lyricsStyleProvider, (prev, next) {
      if (ref.read(presentationWindowProvider)) {
        if (prev?.fontFamily != next.fontFamily) {
          ref
              .read(presentationWindowProvider.notifier)
              .syncFontFamily(next.fontFamily);
        }
        if (prev?.displayLines != next.displayLines) {
          ref
              .read(presentationWindowProvider.notifier)
              .syncDisplayLines(next.displayLines);
        }
        if (prev?.textAlign != next.textAlign) {
          ref
              .read(presentationWindowProvider.notifier)
              .syncTextAlign(next.textAlign);
        }
        if (prev?.position != next.position) {
          ref
              .read(presentationWindowProvider.notifier)
              .syncPosition(next.position);
        }
        if (prev?.size != next.size) {
          ref.read(presentationWindowProvider.notifier).syncSize(next.size);
        }
        if (prev?.overlay != next.overlay ||
            prev?.overlayTone != next.overlayTone ||
            prev?.overlayOpacity != next.overlayOpacity) {
          ref
              .read(presentationWindowProvider.notifier)
              .syncOverlay(next.overlay, next.overlayTone, next.overlayOpacity);
        }
        if (prev?.lineHeight != next.lineHeight ||
            prev?.textShadow != next.textShadow) {
          ref
              .read(presentationWindowProvider.notifier)
              .syncTextLayout(next.lineHeight, next.textShadow);
        }
        if (prev?.clipped != next.clipped) {
          ref
              .read(presentationWindowProvider.notifier)
              .syncClipped(next.clipped);
        }
        if (prev?.fontColor != next.fontColor) {
          ref
              .read(presentationWindowProvider.notifier)
              .syncFontColor(next.fontColor);
        }
        if (prev?.backgroundColor != next.backgroundColor) {
          ref
              .read(presentationWindowProvider.notifier)
              .syncBackgroundColor(next.backgroundColor);
        }
        if (prev?.backgroundType != next.backgroundType) {
          ref
              .read(presentationWindowProvider.notifier)
              .syncBackgroundType(next.backgroundType);
        }
        if (prev?.gradientColors != next.gradientColors) {
          ref
              .read(presentationWindowProvider.notifier)
              .syncGradientColors(next.gradientColors);
        }
        if (prev?.gradientType != next.gradientType) {
          ref
              .read(presentationWindowProvider.notifier)
              .syncGradientType(next.gradientType);
        }
        if (prev?.backgroundImagePath != next.backgroundImagePath) {
          ref
              .read(presentationWindowProvider.notifier)
              .syncBackgroundImagePath(next.backgroundImagePath);
        }
        if (prev?.backgroundVideoPath != next.backgroundVideoPath) {
          ref
              .read(presentationWindowProvider.notifier)
              .syncBackgroundVideoPath(next.backgroundVideoPath);
        }
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header bar ────────────────────────────────────────────────────
        Container(
          height: 56,
          padding: const EdgeInsets.fromLTRB(
            AppPadding.xl,
            AppPadding.sm,
            AppPadding.sm,
            AppPadding.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface4,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: AppColors.borderSubtle,
              width: AppStroke.sm,
              strokeAlign: BorderSide.strokeAlignOutside,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
              ),
            ],
          ),
          // When space runs out the screen selector's label fades first,
          // then the title.
          child: _PresenterHeaderLayout(
            gap: AppSpacing.md,
            selectorMinWidth: _ScreenSelector.minWidth,
            children: [
              FadeText(
                'Presenter'.toUpperCase(),
                style: AppTypography.headingSm.copyWith(
                  color: AppColors.textSubtle,
                ),
              ),

              // ── Clear everything ─────────────────────────────────────────
              LycriPillGroup(
                segments: [
                  LycriPillSegment(
                    svgAsset: 'assets/vectors/SweepBrush.svg',
                    tooltip: 'Clear lyrics',
                    enabled: lyrics != null,
                    onTap: () {
                      if (isLive) {
                        ref.read(presentationWindowProvider.notifier).endLive();
                      }
                      ref.read(segmentedLyricsProvider.notifier).clearAll();
                    },
                  ),
                ],
              ),

              const _ScreenSelector(),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Previous / next line ─────────────────────────────────────
                  LycriPillGroup(
                    segments: [
                      LycriPillSegment(
                        svgAsset: 'assets/vectors/chevron-left.svg',
                        tooltip: 'Previous line',
                        enabled: lines.isNotEmpty,
                        onTap: () {
                          ref.read(activeLineProvider.notifier).previous();
                          ref
                              .read(scrollToActiveTriggerProvider.notifier)
                              .state++;
                        },
                      ),
                      LycriPillSegment(
                        svgAsset: 'assets/vectors/chevron-right.svg',
                        tooltip: 'Next line',
                        enabled: lines.isNotEmpty,
                        onTap: () {
                          ref
                              .read(activeLineProvider.notifier)
                              .next(lines.length - 1);
                          ref
                              .read(scrollToActiveTriggerProvider.notifier)
                              .state++;
                        },
                      ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.md),

                  // ── Go live ⇄ LIVE + stop ────────────────────────────────────
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child:
                        isLive
                            ? _LiveControls(
                              key: const ValueKey('live'),
                              onStop:
                                  () =>
                                      ref
                                          .read(
                                            presentationWindowProvider.notifier,
                                          )
                                          .endLive(),
                            )
                            : LycriButton(
                              key: const ValueKey('go_live'),
                              label: 'Go live',
                              height: 40,
                              disabled: lyrics == null,
                              onPressed: () => _goLive(ref, lyrics),
                            ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // ── Preview area (+ live view picture-in-picture) ───────────────────
        Expanded(
          // Clip to the preview's rounded shape, so the live view is cut by
          // the same corners when it overshoots the edges.
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Builder(
                    builder: (context) {
                      final style = ref.watch(lyricsStyleProvider);
                      return Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                        ),
                        child: Stack(
                          children: [
                            // Transparent background: keyed over video
                            // downstream, so show a checkerboard here.
                            if (style.backgroundType ==
                                BackgroundType.transparent)
                              const Positioned.fill(child: Checkerboard()),
                            // Background layer (Color/Gradient/Image/Video)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color:
                                      style.backgroundType ==
                                              BackgroundType.solidColor
                                          ? style.backgroundColor
                                          : null,
                                  gradient:
                                      style.backgroundType ==
                                              BackgroundType.gradient
                                          ? (style.gradientType ==
                                                  GradientType.linear
                                              ? LinearGradient(
                                                colors:
                                                    style
                                                                .gradientColors
                                                                .length >=
                                                            2
                                                        ? style.gradientColors
                                                        : [
                                                          Colors.white,
                                                          Colors.black,
                                                        ],
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                stops: const [0.0, 1.0],
                                              )
                                              : RadialGradient(
                                                colors:
                                                    style
                                                                .gradientColors
                                                                .length >=
                                                            2
                                                        ? style.gradientColors
                                                        : [
                                                          Colors.white,
                                                          Colors.black,
                                                        ],
                                                center: Alignment.center,
                                                radius: 0.8,
                                                stops: const [0.0, 1.0],
                                              ))
                                          : null,
                                  image:
                                      style.backgroundType ==
                                                  BackgroundType.image &&
                                              style.backgroundImagePath != null
                                          ? DecorationImage(
                                            image: FileImage(
                                              File(style.backgroundImagePath!),
                                            ),
                                            fit: BoxFit.cover,
                                          )
                                          : null,
                                ),
                              ),
                            ),
                            // Video Layer (if applicable)
                            if (style.backgroundType == BackgroundType.video &&
                                style.backgroundVideoPath != null)
                              Positioned.fill(
                                child: StaticVideoBackground(
                                  path: style.backgroundVideoPath!,
                                ),
                              ),
                            // Lyrics/Content switcher
                            Positioned.fill(
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 250),
                                opacity: lyricsVisible ? 1.0 : 0.6,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  child:
                                      lyrics != null
                                          ? const _LyricsPreview(
                                            key: ValueKey('lyrics'),
                                          )
                                          : const _EmptyPresenterState(
                                            key: ValueKey('empty'),
                                          ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const Positioned.fill(child: LiveViewPip()),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // ── Bottom bar ──────────────────────────────────────────────────────
        const _PresenterBottomBar(),
      ],
    );
  }

  void _goLive(WidgetRef ref, String? lyrics) {
    final style = ref.read(lyricsStyleProvider);
    final segmentedState = ref.read(segmentedLyricsProvider);
    ref
        .read(presentationWindowProvider.notifier)
        .goLive(
          lyrics,
          ref.read(activeLineProvider),
          style.fontFamily,
          style.displayLines,
          style.textAlign,
          style.position,
          style.size,
          style.clipped,
          style.overlay,
          style.overlayTone,
          style.overlayOpacity,
          style.lineHeight,
          style.textShadow,
          style.fontColor,
          style.backgroundColor,
          style.backgroundType,
          style.gradientType,
          style.gradientColors,
          style.backgroundImagePath,
          style.backgroundVideoPath,
          segmentedState.isSegmented,
          segmentedState.segments
              .where((s) => !s.isHidden)
              .map((s) => s.lineCount)
              .toList(),
        );
  }
}

// ─── Live controls ──────────────────────────────────────────────────────────

/// Shown in place of "Go live" while presenting: a green LIVE status joined
/// to a red stop button (Figma: live-view header).
class _LiveControls extends StatelessWidget {
  const _LiveControls({super.key, required this.onStop});

  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    const liveRadius = BorderRadius.horizontal(
      left: Radius.circular(AppRadius.full),
      right: Radius.circular(AppRadius.md),
    );
    const stopRadius = BorderRadius.horizontal(
      left: Radius.circular(AppRadius.md),
      right: Radius.circular(AppRadius.full),
    );
    final shadow = Colors.black.withValues(alpha: 0.15);

    return Container(
      padding: const EdgeInsets.all(AppStroke.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSuccessLight,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InnerShadow(
            color: shadow,
            borderRadius: liveRadius,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: AppPadding.md),
              decoration: const BoxDecoration(
                color: AppColors.surfaceSuccess,
                borderRadius: liveRadius,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.surface4,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'Live'.toUpperCase(),
                    style: AppTypography.titleLg.copyWith(
                      color: AppColors.textInverse,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppStroke.md),
          _StopButton(onTap: onStop, borderRadius: stopRadius),
        ],
      ),
    );
  }
}

class _StopButton extends StatefulWidget {
  const _StopButton({required this.onTap, required this.borderRadius});

  final VoidCallback onTap;
  final BorderRadius borderRadius;

  @override
  State<_StopButton> createState() => _StopButtonState();
}

class _StopButtonState extends State<_StopButton> {
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'End live',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: CassettePress(
          onTap: widget.onTap,
          builder:
              (context, t) => InnerShadow(
                color: Colors.black.withValues(
                  alpha: CassettePress.shadowAlpha(0.15, t),
                ),
                offset: CassettePress.shadowOffset(t),
                borderRadius: widget.borderRadius,
                child: Container(
                  width: 44,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      AppColors.red500,
                      AppColors.red700,
                      t.clamp(0.0, 1.0),
                    ),
                    borderRadius: widget.borderRadius,
                  ),
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.surface4,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                  ),
                ),
              ),
        ),
      ),
    );
  }
}

// ─── Bottom bar ─────────────────────────────────────────────────────────────

/// `Gray600` bar under the preview: lyric visibility + more on the left,
/// live-view toggle on the right.
class _PresenterBottomBar extends ConsumerWidget {
  const _PresenterBottomBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyricsVisible = ref.watch(lyricsVisibilityProvider);
    final showLive = ref.watch(liveViewVisibleProvider);

    return Container(
      padding: const EdgeInsets.all(AppPadding.xs),
      decoration: BoxDecoration(
        color: AppColors.gray600,
        borderRadius: BorderRadius.circular(AppRadius.full),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          LycriPillGroup(
            tone: LycriPillTone.muted,
            height: 32,
            iconSize: 20,
            segments: [
              LycriPillSegment(
                svgAsset: 'assets/vectors/list-play.svg',
                label: lyricsVisible ? 'Hide lyrics' : 'Show lyrics',
                onTap: () {
                  final next = !lyricsVisible;
                  ref.read(lyricsVisibilityProvider.notifier).state = next;
                  ref
                      .read(presentationWindowProvider.notifier)
                      .syncLyricsVisibility(next);
                },
              ),
              // TODO(design): the "…" menu's contents aren't specified yet.
              const LycriPillSegment(
                svgAsset: 'assets/vectors/more-horizontal.svg',
                tooltip: 'More',
                enabled: false,
                width: 40,
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: _LiveViewToggle(
              active: showLive,
              onTap:
                  () =>
                      ref.read(liveViewVisibleProvider.notifier).state =
                          !showLive,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Show live view" (Gray500) ⇄ "Hide live view" (Gray0, subtle text).
class _LiveViewToggle extends StatelessWidget {
  const _LiveViewToggle({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = active ? AppColors.textSubtle : AppColors.textInverse;
    final radius = BorderRadius.circular(AppRadius.full);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: CassettePress(
        onTap: onTap,
        builder:
            (context, t) => InnerShadow(
              color: Colors.black.withValues(
                alpha: CassettePress.shadowAlpha(0.15, t),
              ),
              offset: CassettePress.shadowOffset(t),
              borderRadius: radius,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: AppPadding.md),
                decoration: BoxDecoration(
                  color: Color.lerp(
                    active ? AppColors.gray0 : AppColors.gray500,
                    active ? AppColors.surface2 : AppColors.gray700,
                    t.clamp(0.0, 1.0),
                  ),
                  borderRadius: radius,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      'assets/vectors/eye.svg',
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.mode(fg, BlendMode.srcIn),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Flexible(
                      child: FadeText(
                        (active ? 'Hide live view' : 'Show live view')
                            .toUpperCase(),
                        style: AppTypography.titleLg.copyWith(color: fg),
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

// ─── Lyrics preview ─────────────────────────────────────────────────────────

/// Renders each lyric line with Spotify-style smooth transitions.
///
/// - Active line crossfades to bold text; inactive lines crossfade to dimmed.
/// - The list auto-scrolls to keep the active line visible/centered.
class _LyricsPreview extends ConsumerStatefulWidget {
  const _LyricsPreview({super.key});

  @override
  ConsumerState<_LyricsPreview> createState() => _LyricsPreviewState();
}

class _LyricsPreviewState extends ConsumerState<_LyricsPreview> {
  final ScrollController _scrollController = ScrollController();

  /// Keys attached to each line so we can measure their positions.
  final Map<int, GlobalKey> _lineKeys = {};

  /// Duration & curve matching a Spotify-style smooth feel.
  static const _animDuration = Duration(milliseconds: 400);
  static const _animCurve = Curves.easeOutCubic;

  @override
  void initState() {
    super.initState();
    // Scroll to starting active line if any.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToActive(ref.read(activeLineProvider));
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Ensure a [GlobalKey] exists for line [index].
  GlobalKey _keyFor(int index) {
    return _lineKeys.putIfAbsent(index, () => GlobalKey());
  }

  void _scrollToActive(int activeIndex) {
    if (!mounted) return;

    // Retry multiple times to ensure we catch the layout after a lyric update
    void attemptScroll(int retryCount) {
      if (!mounted || retryCount <= 0) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;

        final key = _lineKeys[activeIndex];
        if (key == null || key.currentContext == null) {
          // If the key isn't found, the UI likely haven't rebuilt with the new lines yet.
          // Retry after a short delay.
          Future.delayed(
            const Duration(milliseconds: 50),
            () => attemptScroll(retryCount - 1),
          );
          return;
        }

        final renderBox = key.currentContext!.findRenderObject() as RenderBox?;
        if (renderBox == null || !renderBox.hasSize) {
          Future.delayed(
            const Duration(milliseconds: 50),
            () => attemptScroll(retryCount - 1),
          );
          return;
        }

        final viewport = _scrollController.position;
        final storageContext = viewport.context.storageContext;
        final scrollObject = storageContext.findRenderObject();
        if (scrollObject == null) return;

        final lineOffset = renderBox.localToGlobal(
          Offset.zero,
          ancestor: scrollObject,
        );

        final targetOffset =
            _scrollController.offset +
            lineOffset.dy -
            (viewport.viewportDimension * 0.33);

        _scrollController.animateTo(
          targetOffset.clamp(0.0, viewport.maxScrollExtent),
          duration: _animDuration,
          curve: _animCurve,
        );
      });
    }

    attemptScroll(5); // Try up to 5 times (250ms total) to find the new layout
  }

  @override
  Widget build(BuildContext context) {
    final lines = ref.watch(lyricsLinesProvider);
    final activeIndex = ref.watch(activeLineProvider);
    final styleState = ref.watch(lyricsStyleProvider);

    // Trigger scroll animation whenever the active line changes OR the trigger increments.
    ref.listen<int>(activeLineProvider, (prev, next) {
      _scrollToActive(next);
    });

    ref.listen<int>(scrollToActiveTriggerProvider, (prev, next) {
      _scrollToActive(ref.read(activeLineProvider));
    });

    // Re-scroll after lyrics text changes (e.g. segment hidden/shown).
    ref.listen<List<String>>(lyricsLinesProvider, (prev, next) {
      if (prev != null && prev.length != next.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToActive(ref.read(activeLineProvider));
        });
      }
    });

    // Prune stale keys when the line count shrinks.
    _lineKeys.removeWhere((k, _) => k >= lines.length);

    // In segmented mode, separate verses/choruses with a gap (dist-xl).
    final segmentedState = ref.watch(segmentedLyricsProvider);
    final segmentStarts = <int>{};
    if (segmentedState.isSegmented) {
      var offset = 0;
      for (final segment in segmentedState.segments) {
        if (segment.isHidden || segment.lineCount == 0) continue;
        segmentStarts.add(offset);
        offset += segment.lineCount;
      }
    }

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ScrollFadeMask(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(AppPadding.x2l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < lines.length; i++)
                _LyricLine(
                  key: _keyFor(i),
                  text: lines[i],
                  isActive: i == activeIndex,
                  topGap:
                      i > 0 && segmentStarts.contains(i) ? AppSpacing.xl : 0,
                  styleState: styleState,
                  onTap: () => ref.read(activeLineProvider.notifier).jumpTo(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LyricLine extends StatelessWidget {
  final String text;
  final bool isActive;
  final double topGap;
  final LyricsStyleState styleState;
  final VoidCallback onTap;

  const _LyricLine({
    super.key,
    required this.text,
    required this.isActive,
    this.topGap = 0,
    required this.styleState,
    required this.onTap,
  });

  /// The preview sets Mid in `heading-sm`; other sizes, the line gap and
  /// the shadow scale from the output by the same ratio.
  static final double _previewScale =
      AppTypography.headingSm.fontSize! / LyricsSize.mid.textStyle.fontSize!;

  @override
  Widget build(BuildContext context) {
    final fontSize = styleState.size.textStyle.fontSize! * _previewScale;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedPadding(
          duration: _LyricsPreviewState._animDuration,
          curve: _LyricsPreviewState._animCurve,
          padding: EdgeInsets.only(
            top: topGap,
            bottom: styleState.lineGap * _previewScale,
          ),
          child: AnimatedDefaultTextStyle(
            duration: _LyricsPreviewState._animDuration,
            curve: _LyricsPreviewState._animCurve,
            style: AppTypography.headingSm.copyWith(
              fontFamily: styleState.fontFamily,
              fontSize: fontSize,
              color:
                  isActive
                      ? styleState.fontColor
                      : styleState.fontColor.withValues(alpha: 0.2),
              shadows: styleState.shadowFor(
                isActive ? 1 : 0.2,
                scale: _previewScale,
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: Text(text, textAlign: styleState.textAlign),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Empty state ────────────────────────────────────────────────────────────

/// Empty state shown in the presenter area before any lyrics are loaded.
class _EmptyPresenterState extends StatelessWidget {
  const _EmptyPresenterState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Waving hand
          SvgPicture.asset(
            'assets/vectors/HandWaving.svg',
            width: 48,
            height: 48,
            colorFilter: ColorFilter.mode(
              AppColors.iconMinimal,
              BlendMode.srcIn,
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          Text(
            'Hi there. Waiting for your lyrics!',
            style: AppTypography.bodyMd.copyWith(color: AppColors.textMinimal),
            textAlign: TextAlign.center,
          ),
          Text(
            'Paste them on the left.',
            style: AppTypography.bodyMd.copyWith(color: AppColors.textMinimal),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Screen selector ────────────────────────────────────────────────────────

class _ScreenSelector extends ConsumerStatefulWidget {
  const _ScreenSelector();

  /// Padding + icon + divider, with no label showing.
  static const double minWidth =
      AppPadding.md * 2 + 24 + AppSpacing.md * 2 + AppStroke.md;

  @override
  ConsumerState<_ScreenSelector> createState() => _ScreenSelectorState();
}

class _ScreenSelectorState extends ConsumerState<_ScreenSelector>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _triggerKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    final curved = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _scaleAnim = Tween(begin: 0.92, end: 1.0).animate(curved);
    _fadeAnim = Tween(begin: 0.0, end: 1.0).animate(curved);
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _animController.dispose();
    super.dispose();
  }

  // ── Overlay management ──────────────────────────────────────────────────

  void _toggle() {
    if (_isOpen) {
      _closeOverlay();
    } else {
      _openOverlay();
    }
  }

  void _openOverlay() {
    _overlayEntry = OverlayEntry(builder: (_) => _buildOverlay());
    Overlay.of(context).insert(_overlayEntry!);
    _animController.forward(from: 0);
    setState(() => _isOpen = true);
  }

  void _closeOverlay({DisplayOutput? pendingSelection}) {
    _animController.reverse().then((_) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      // Apply the selection only after the panel is fully gone,
      // so the trigger button never resizes while the overlay is visible.
      if (pendingSelection != null && mounted) {
        ref.read(displayModeProvider.notifier).state = pendingSelection;
      }
    });
    setState(() => _isOpen = false);
  }

  void _selectMode(DisplayOutput output) {
    _closeOverlay(pendingSelection: output);
  }

  // ── Overlay content ─────────────────────────────────────────────────────

  Widget _buildOverlay() {
    return Stack(
      children: [
        // Tap-away barrier
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _closeOverlay,
            child: const SizedBox.expand(),
          ),
        ),
        // Floating panel anchored below the trigger
        CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 40),
          child: Align(
            alignment: Alignment.topLeft,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                alignment: Alignment.topLeft,
                child: Material(
                  type: MaterialType.transparency,
                  child: Container(
                    width: 480,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.surface4,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border: Border.all(
                        color: AppColors.borderSubtle,
                        width: AppStroke.sm,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 32,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How do you want to display?'.toUpperCase(),
                          style: AppTypography.titleLg.copyWith(
                            color: AppColors.textBold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xmd),
                        ref
                            .watch(displaysProvider)
                            .when(
                              data: (displays) {
                                // 1. Custom list of outputs: primary display, secondary displays, then NDI.
                                final List<DisplayOutput> options = [
                                  DisplayOutput.thisDisplay(),
                                  ...displays
                                      .where((d) => d.id != displays[0].id)
                                      .map((d) => DisplayOutput.external(d)),
                                  DisplayOutput.ndi(),
                                ];

                                return LayoutBuilder(
                                  builder: (context, constraints) {
                                    final int crossAxisCount =
                                        options.length < 3 ? options.length : 3;
                                    final double totalSpacing =
                                        AppSpacing.md * (crossAxisCount - 1);
                                    final double itemWidth =
                                        (constraints.maxWidth - totalSpacing) /
                                        crossAxisCount;

                                    return Wrap(
                                      spacing: AppSpacing.md,
                                      runSpacing: AppSpacing.md,
                                      children:
                                          options.map((output) {
                                            final currentOutput = ref.watch(
                                              displayModeProvider,
                                            );
                                            final isSelected =
                                                currentOutput == output;

                                            return SizedBox(
                                              width: itemWidth,
                                              child: _DisplayCard(
                                                output: output,
                                                isSelected: isSelected,
                                                onTap:
                                                    () => _selectMode(output),
                                              ),
                                            );
                                          }).toList(),
                                    );
                                  },
                                );
                              },
                              loading:
                                  () => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                              error:
                                  (e, _) => Text(
                                    'Error loading displays: $e',
                                    style: const TextStyle(color: Colors.red),
                                  ),
                            ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Trigger button ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Warm up the displays provider so it's ready when the overlay opens.
    ref.watch(displaysProvider);

    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: KeyedSubtree(
          key: _triggerKey,
          child: CassettePress(
            onTap: _toggle,
            builder:
                (context, t) => InnerShadow(
                  color: Colors.black.withValues(
                    alpha: CassettePress.shadowAlpha(0.15, t),
                  ),
                  offset: CassettePress.shadowOffset(t),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppPadding.md,
                    ),
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        _isOpen ? AppColors.surface2 : AppColors.surface3,
                        AppColors.surface1,
                        t.clamp(0.0, 1.0),
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Builder(
                      builder: (context) {
                        // Read the shared provider to keep the trigger label in sync.
                        final currentOutput = ref.watch(displayModeProvider);
                        final svgAsset =
                            currentOutput.type == DisplayType.thisDisplay
                                ? 'assets/vectors/monitor.svg'
                                : currentOutput.type == DisplayType.ndi
                                ? 'assets/vectors/monitorStack.svg'
                                : 'assets/vectors/monitorOutline.svg';

                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SvgPicture.asset(
                              svgAsset,
                              width: 24,
                              height: 24,
                              colorFilter: const ColorFilter.mode(
                                AppColors.iconSubtle,
                                BlendMode.srcIn,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Container(
                              width: AppStroke.md,
                              height: 12,
                              color: AppColors.borderBold,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Flexible(
                              // Long display names fade rather than grow the
                              // trigger.
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 140,
                                ),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 40),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  transitionBuilder:
                                      (child, animation) => FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      ),
                                  child: FadeText(
                                    currentOutput.label.toUpperCase(),
                                    key: ValueKey(currentOutput),
                                    style: AppTypography.titleLg.copyWith(
                                      color: AppColors.textSubtle,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
          ),
        ),
      ),
    );
  }
}

// ─── Individual display option card ─────────────────────────────────────────

class _DisplayCard extends StatefulWidget {
  const _DisplayCard({
    required this.output,
    required this.isSelected,
    required this.onTap,
  });

  final DisplayOutput output;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_DisplayCard> createState() => _DisplayCardState();
}

class _DisplayCardState extends State<_DisplayCard> {
  @override
  Widget build(BuildContext context) {
    final Color bg =
        widget.isSelected ? AppColors.surfaceBrandLight : AppColors.surface3;

    final Color borderColor =
        widget.isSelected ? AppColors.borderBrand : Colors.transparent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 80,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: borderColor, width: AppStroke.xl),
          ),
          child: Stack(
            children: [
              // Card content
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  top: AppSpacing.md,
                  bottom: AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SvgPicture.asset(
                      widget.output.type == DisplayType.thisDisplay
                          ? 'assets/vectors/monitor.svg'
                          : widget.output.type == DisplayType.ndi
                          ? 'assets/vectors/monitorStack.svg'
                          : 'assets/vectors/monitorOutline.svg',
                      width: 24,
                      height: 24,
                      colorFilter: ColorFilter.mode(
                        widget.isSelected
                            ? AppColors.textBrand
                            : AppColors.textSubtle,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FadeText(
                      widget.output.label.toUpperCase(),
                      style: AppTypography.titleMd.copyWith(
                        color:
                            widget.isSelected
                                ? AppColors.textBrand
                                : AppColors.textSubtle,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              // Orange checkmark badge (selected only)
              if (widget.isSelected)
                Positioned(
                  top: AppSpacing.md,
                  right: AppSpacing.md,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceBrand,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 14,
                      color: AppColors.textInverse,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Header layout ──────────────────────────────────────────────────────────

/// Lays out the presenter header: [title] on the left, then the controls
/// right-aligned as [clear] · [selector] · [trailing], [gap] apart.
///
/// Children are `[title, clear, selector, trailing]`. Spare width goes to the
/// title first. When short, the selector shrinks first (its label fades), down
/// to [selectorMinWidth], and only then does the title fade.
class _PresenterHeaderLayout extends MultiChildRenderObjectWidget {
  const _PresenterHeaderLayout({
    required this.gap,
    required this.selectorMinWidth,
    required super.children,
  }) : assert(children.length == 4);

  final double gap;
  final double selectorMinWidth;

  @override
  _RenderPresenterHeader createRenderObject(BuildContext context) =>
      _RenderPresenterHeader(gap: gap, selectorMinWidth: selectorMinWidth);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPresenterHeader renderObject,
  ) {
    renderObject
      ..gap = gap
      ..selectorMinWidth = selectorMinWidth;
  }
}

class _HeaderParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderPresenterHeader extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _HeaderParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _HeaderParentData> {
  _RenderPresenterHeader({
    required double gap,
    required double selectorMinWidth,
  }) : _gap = gap,
       _selectorMinWidth = selectorMinWidth;

  double _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  double _selectorMinWidth;
  set selectorMinWidth(double value) {
    if (value == _selectorMinWidth) return;
    _selectorMinWidth = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _HeaderParentData) {
      child.parentData = _HeaderParentData();
    }
  }

  @override
  void performLayout() {
    final title = firstChild!;
    final clear = childAfter(title)!;
    final selector = childAfter(clear)!;
    final trailing = childAfter(selector)!;

    final width = constraints.maxWidth;
    final loose = BoxConstraints(maxHeight: constraints.maxHeight);

    clear.layout(loose, parentUsesSize: true);
    trailing.layout(loose, parentUsesSize: true);
    title.layout(loose.copyWith(maxWidth: width), parentUsesSize: true);

    // Width left for selector + title once the fixed controls and the three
    // gaps (title|clear|selector|trailing) are placed.
    final shared = width - clear.size.width - trailing.size.width - _gap * 3;

    // Selector takes what the title doesn't need, but never less than its
    // label-less minimum.
    final selectorMax = math.max(_selectorMinWidth, shared - title.size.width);
    selector.layout(
      loose.copyWith(maxWidth: selectorMax),
      parentUsesSize: true,
    );

    // Title gets the remainder; it fades if that's less than it wants.
    final titleMax = math.max(0.0, shared - selector.size.width);
    if (title.size.width > titleMax) {
      title.layout(loose.copyWith(maxWidth: titleMax), parentUsesSize: true);
    }

    final height = constraints.constrainHeight(
      [
        title,
        clear,
        selector,
        trailing,
      ].map((c) => c.size.height).reduce(math.max),
    );
    size = constraints.constrain(Size(width, height));

    void place(RenderBox child, double x) {
      (child.parentData! as _HeaderParentData).offset = Offset(
        x,
        (height - child.size.height) / 2,
      );
    }

    // Title left; controls right-aligned.
    place(title, 0);
    var x = width - trailing.size.width;
    place(trailing, x);
    x -= _gap + selector.size.width;
    place(selector, x);
    x -= _gap + clear.size.width;
    place(clear, x);
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
