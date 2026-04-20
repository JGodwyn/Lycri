import 'dart:io';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_stroke.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/providers/active_line_provider.dart';
import '../../../shared/providers/display_mode_provider.dart';
import '../../../shared/providers/lyrics_provider.dart';
import '../../../shared/providers/lyrics_style_provider.dart';
import '../../../shared/providers/lyrics_visibility_provider.dart';
import '../../../shared/providers/presentation_window_provider.dart';
import '../../operator/models/lyrics_segment.dart';
import '../../../shared/widgets/static_video_background.dart';
import '../../../shared/widgets/lycri_button.dart';

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
        // ── Top bar ────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.md,
            top: AppSpacing.md,
            bottom: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface4,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: AppColors.borderMinimal,
              width: AppStroke.md,
            ),
          ),
          child: Row(
            children: [
              // ── "Presenter" label — fills remaining space, truncates if needed
              Expanded(
                child: Text(
                  'Presenter',
                  style: AppTypography.titleLg.copyWith(
                    color: AppColors.textSubtle,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // ── Controls block — always right-aligned, natural width ────────
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _ScreenSelector(),
                  const SizedBox(width: AppSpacing.lg),

                  // ── Clear (sweep brush) ───────────────────────────────────
                  MouseRegion(
                    cursor:
                        lyrics != null
                            ? SystemMouseCursors.click
                            : SystemMouseCursors.basic,
                    child: GestureDetector(
                      onTap:
                          lyrics == null
                              ? null
                              : () {
                                if (isLive) {
                                  ref
                                      .read(presentationWindowProvider.notifier)
                                      .endLive();
                                }
                                ref.read(segmentedLyricsProvider.notifier).clearAll();
                              },
                      child: SvgPicture.asset(
                        'assets/vectors/SweepBrush.svg',
                        width: 20,
                        height: 20,
                        colorFilter: ColorFilter.mode(
                          lyrics != null
                              ? AppColors.iconSubtle
                              : AppColors.iconMinimal,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: AppSpacing.lg),

                  // ── Left arrow ────────────────────────────────────────────
                  _ArrowButton(
                    icon: Icons.chevron_left,
                    onPressed:
                        lines.isEmpty
                            ? null
                            : () {
                              ref.read(activeLineProvider.notifier).previous();
                              ref
                                  .read(scrollToActiveTriggerProvider.notifier)
                                  .state++;
                            },
                  ),

                  const SizedBox(width: AppSpacing.sm),

                  // ── Right arrow ───────────────────────────────────────────
                  _ArrowButton(
                    icon: Icons.chevron_right,
                    onPressed:
                        lines.isEmpty
                            ? null
                            : () {
                              ref
                                  .read(activeLineProvider.notifier)
                                  .next(lines.length - 1);
                              ref
                                  .read(scrollToActiveTriggerProvider.notifier)
                                  .state++;
                            },
                  ),

                  const SizedBox(width: AppSpacing.lg),

                  // ── Go Live / End Live ────────────────────────────────────
                  LycriButton(
                    label: isLive ? 'End Live' : 'Go Live',
                    onPressed: () {
                      if (isLive) {
                        ref.read(presentationWindowProvider.notifier).endLive();
                      } else {
                        final style = ref.read(lyricsStyleProvider);
                        final segmentedState = ref.read(segmentedLyricsProvider);
                        ref.read(presentationWindowProvider.notifier).goLive(
                          lyrics,
                          ref.read(activeLineProvider),
                          style.fontFamily,
                          style.displayLines,
                          style.textAlign,
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
                    },
                    fillWidth: false,
                    height: 32,
                    disabled: !isLive && lyrics == null,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // ── Preview area ────────────────────────────────────────────────────
        Expanded(
          child: Stack(
            children: [
              // The preview container fills the whole Stack.
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
                                                  style.gradientColors.length >=
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
                                                  style.gradientColors.length >=
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

              // ── Visibility toggle — floats over top-right of the preview ──
              Positioned(
                top: AppSpacing.md,
                right: AppSpacing.md,
                child: _VisibilityToggle(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Visibility toggle ───────────────────────────────────────────────────────

/// Floating eye-button overlaid on the top-right of the presenter preview.
///
/// Active (eye visible): lyrics shown on the live screen — bright orange with glow.
/// Inactive: lyrics faded out on the live screen — neutral surface.
class _VisibilityToggle extends ConsumerWidget {
  const _VisibilityToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyricsVisible = ref.watch(lyricsVisibilityProvider);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          final next = !lyricsVisible;
          ref.read(lyricsVisibilityProvider.notifier).state = next;
          ref
              .read(presentationWindowProvider.notifier)
              .syncLyricsVisibility(next);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          width: 48,
          height: 32,
          decoration: BoxDecoration(
            color: lyricsVisible ? AppColors.surfaceBrand : AppColors.surface4,
            borderRadius: BorderRadius.circular(AppRadius.full),
            boxShadow:
                lyricsVisible
                    ? [
                      BoxShadow(
                        color: AppColors.surfaceBrand.withValues(alpha: 0.55),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: Offset.zero,
                      ),
                    ]
                    : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
          ),
          child: Center(
            child: SvgPicture.asset(
              'assets/vectors/eye.svg',
              width: 22,
              height: 22,
              colorFilter: ColorFilter.mode(
                lyricsVisible ? AppColors.textInverse : AppColors.iconSubtle,
                BlendMode.srcIn,
              ),
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

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < lines.length; i++)
              _LyricLine(
                key: _keyFor(i),
                text: lines[i],
                isActive: i == activeIndex,
                styleState: styleState,
                onTap: () => ref.read(activeLineProvider.notifier).jumpTo(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _LyricLine extends StatelessWidget {
  final String text;
  final bool isActive;
  final LyricsStyleState styleState;
  final VoidCallback onTap;

  const _LyricLine({
    super.key,
    required this.text,
    required this.isActive,
    required this.styleState,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: AnimatedDefaultTextStyle(
            duration: _LyricsPreviewState._animDuration,
            curve: _LyricsPreviewState._animCurve,
            style: AppTypography.headingMd.copyWith(
              fontFamily: styleState.fontFamily,
              color:
                  isActive
                      ? styleState.fontColor
                      : styleState.fontColor.withValues(alpha: 0.2),
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
                          'How do you want to display?',
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
        child: GestureDetector(
          key: _triggerKey,
          onTap: _toggle,
          child: Container(
            height: 32,
            padding: const EdgeInsets.only(
              left: AppSpacing.xmd,
              right: AppSpacing.xmd,
              top: AppSpacing.sm,
              bottom: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface3,
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(
                color: AppColors.borderMinimal,
                width: AppStroke.sm,
              ),
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
                      width: 20,
                      height: 20,
                      colorFilter: const ColorFilter.mode(
                        AppColors.textSubtle,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Flexible(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 40),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder:
                            (child, animation) => FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                        child: Text(
                          currentOutput.label,
                          key: ValueKey(currentOutput),
                          style: AppTypography.titleMd.copyWith(
                            color: AppColors.textSubtle,
                          ),
                          overflow: TextOverflow.ellipsis,
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
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color bg =
        widget.isSelected
            ? AppColors.surfaceBrandLight
            : _hovered
            ? AppColors.surface3
            : AppColors.surface3;

    final Color borderColor =
        widget.isSelected ? AppColors.borderBrand : Colors.transparent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
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
                    Text(
                      widget.output.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

class _ArrowButton extends StatefulWidget {
  const _ArrowButton({this.icon, this.svgAsset, this.onPressed})
    : assert(icon != null || svgAsset != null);

  /// Material icon (used for arrow buttons).
  final IconData? icon;

  /// SVG asset path (used for the sweep/clear button).
  final String? svgAsset;

  final VoidCallback? onPressed;

  @override
  State<_ArrowButton> createState() => _ArrowButtonState();
}

class _ArrowButtonState extends State<_ArrowButton> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final Color bg =
        !_enabled
            ? AppColors.btnBrandSecondaryRest.withValues(alpha: 0.5)
            : _pressed
            ? AppColors.btnBrandSecondaryPressed
            : _hovered
            ? AppColors.btnBrandSecondaryHover
            : AppColors.btnBrandSecondaryRest;

    final Color fg =
        !_enabled
            ? AppColors.textMinimal
            : _pressed
            ? AppColors.textInverse
            : AppColors.textBold;

    return MouseRegion(
      cursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) {
        setState(() {
          _hovered = false;
          _pressed = false;
        });
      },
      child: GestureDetector(
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp:
            _enabled
                ? (_) {
                  setState(() => _pressed = false);
                  widget.onPressed?.call();
                }
                : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child:
              widget.svgAsset != null
                  ? Center(
                    child: SvgPicture.asset(
                      widget.svgAsset!,
                      width: 18,
                      height: 18,
                      colorFilter: ColorFilter.mode(fg, BlendMode.srcIn),
                    ),
                  )
                  : Icon(widget.icon, size: 18, color: fg),
        ),
      ),
    );
  }
}
