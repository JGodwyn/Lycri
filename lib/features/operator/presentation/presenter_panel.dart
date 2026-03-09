import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_stroke.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/providers/active_line_provider.dart';
import '../../../shared/providers/lyrics_provider.dart';
import '../../../shared/providers/presentation_window_provider.dart';
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
        ref.read(presentationWindowProvider.notifier).syncLyrics(next);
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Presenter',
                style: AppTypography.titleLg.copyWith(
                  color: AppColors.textSubtle,
                ),
              ),

              Row(
                children: [
                  // ── Clear (sweep brush) ─────────────────────────────────
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
                                ref.read(lyricsProvider.notifier).clear();
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

                  // ── Left arrow button ──────────────────────────────────
                  _ArrowButton(
                    icon: Icons.chevron_left,
                    onPressed:
                        lines.isEmpty
                            ? null
                            : () =>
                                ref
                                    .read(activeLineProvider.notifier)
                                    .previous(),
                  ),

                  const SizedBox(width: AppSpacing.sm),

                  // ── Right arrow button ─────────────────────────────────
                  _ArrowButton(
                    icon: Icons.chevron_right,
                    onPressed:
                        lines.isEmpty
                            ? null
                            : () => ref
                                .read(activeLineProvider.notifier)
                                .next(lines.length - 1),
                  ),

                  const SizedBox(width: AppSpacing.lg),

                  // ── Go Live / End Live button ──────────────────────────
                  LycriButton(
                    label: isLive ? 'End Live' : 'Go Live',
                    onPressed: () {
                      if (isLive) {
                        ref.read(presentationWindowProvider.notifier).endLive();
                      } else {
                        ref
                            .read(presentationWindowProvider.notifier)
                            .goLive(lyrics);
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
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface4,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: AppColors.borderMinimal,
                width: AppStroke.md,
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child:
                  lyrics != null
                      ? const _LyricsPreview(key: ValueKey('lyrics'))
                      : const _EmptyPresenterState(key: ValueKey('empty')),
            ),
          ),
        ),
      ],
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
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Ensure a [GlobalKey] exists for line [index].
  GlobalKey _keyFor(int index) {
    return _lineKeys.putIfAbsent(index, () => GlobalKey());
  }

  /// Smoothly scroll so the active line is roughly centered in the viewport.
  void _scrollToActive(int activeIndex) {
    // Wait one frame so the layout is up-to-date after the rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      final key = _lineKeys[activeIndex];
      if (key == null) return;

      final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) return;

      // Position of the line relative to the scroll viewport.
      final viewport = _scrollController.position;
      final lineOffset = renderBox.localToGlobal(
        Offset.zero,
        ancestor: viewport.context.storageContext.findRenderObject(),
      );

      // Target: place the line ~1/3 from the top so readers see context below.
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

  @override
  Widget build(BuildContext context) {
    final lines = ref.watch(lyricsLinesProvider);
    final activeIndex = ref.watch(activeLineProvider);

    // Trigger scroll animation whenever the active line changes.
    ref.listen<int>(activeLineProvider, (prev, next) {
      _scrollToActive(next);
    });

    // Prune stale keys when the line count shrinks.
    _lineKeys.removeWhere((k, _) => k >= lines.length);

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppSpacing.xl),
        itemCount: lines.length,
        itemBuilder: (_, i) {
          final isActive = i == activeIndex;
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => ref.read(activeLineProvider.notifier).jumpTo(i),
              child: Padding(
                key: _keyFor(i),
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: AnimatedDefaultTextStyle(
                  duration: _animDuration,
                  curve: _animCurve,
                  style: AppTypography.headingMd.copyWith(
                    color:
                        isActive ? AppColors.textBold : AppColors.textMinimal,
                  ),
                  child: Text(lines[i]),
                ),
              ),
            ),
          );
        },
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

// ─── Arrow / icon button ────────────────────────────────────────────────────

/// Compact circular button. Accepts either an [IconData] or an SVG asset path.
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
