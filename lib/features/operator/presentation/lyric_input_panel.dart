import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_stroke.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/providers/lyrics_provider.dart';
import '../../../shared/widgets/lycri_button.dart';
import 'widgets/segmented_lyrics_view.dart';

/// Left panel of the operator window.
/// Contains the app title, a hint, and a lyrics text field.
/// Text changes are pushed to the presenter in real time.
class LyricInputPanel extends ConsumerStatefulWidget {
  const LyricInputPanel({super.key});

  @override
  ConsumerState<LyricInputPanel> createState() => _LyricInputPanelState();
}

class _LyricInputPanelState extends ConsumerState<LyricInputPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    // Initialize controller with current lyrics if any
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final current = ref.read(lyricsProvider);
      if (current != null) {
        _controller.text = current;
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_clearing) return;
    ref.read(lyricsProvider.notifier).update(_controller.text);
    // Trigger rebuild to update button enabled/disabled state based on text.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final segmentedState = ref.watch(segmentedLyricsProvider);
    final isSegmented = segmentedState.isSegmented;

    // When lyrics are cleared externally or updated from segments,
    // sync the text field.
    ref.listen<String?>(lyricsProvider, (prev, next) {
      if (next == null && _controller.text.trim().isNotEmpty) {
        _clearing = true;
        _controller.clear();
        _clearing = false;
      } else if (next != null && next != _controller.text) {
        _clearing = true;
        _controller.text = next;
        _clearing = false;
      }
    });

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface4,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.borderMinimal, width: AppStroke.md),
      ),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Row(
              children: [
                if (isSegmented) ...[
                  IconButton(
                    onPressed:
                        () =>
                            ref.read(segmentedLyricsProvider.notifier).reset(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    color: AppColors.iconSubtle,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                Text(
                  'Lycri',
                  style: AppTypography.headingMd.copyWith(
                    color: AppColors.textBold,
                  ),
                ),
                const Spacer(),
                SvgPicture.asset(
                  'assets/vectors/info-fill.svg',
                  width: 20,
                  height: 20,
                  colorFilter: const ColorFilter.mode(
                    AppColors.iconMinimal,
                    BlendMode.srcIn,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Hint row ────────────────────────────────────────────────────
          if (!isSegmented) const SizedBox(height: AppSpacing.lg),

          // ── Content Switcher ────────────────────────────────────────────
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child:
                  isSegmented
                      ? const SegmentedLyricsView()
                      : Column(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _focusNode.requestFocus(),
                              behavior: HitTestBehavior.opaque,
                              child: ScrollConfiguration(
                                behavior: ScrollConfiguration.of(
                                  context,
                                ).copyWith(scrollbars: true),
                                child: Scrollbar(
                                  controller: _scrollController,
                                  child: SingleChildScrollView(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.xl,
                                    ),
                                    child: TextField(
                                      controller: _controller,
                                      focusNode: _focusNode,
                                      maxLines: null,
                                      // 🚫 Disable internal scrolling
                                      scrollPhysics:
                                          const NeverScrollableScrollPhysics(),
                                      textAlignVertical: TextAlignVertical.top,
                                      style: AppTypography.bodyLg.copyWith(
                                        color: AppColors.textBold,
                                        height: 1.5,
                                      ),
                                      decoration: const InputDecoration(
                                        hintText:
                                            'Start typing or paste your lyric here',
                                        hintStyle: TextStyle(
                                          color: AppColors.textMinimal,
                                        ),
                                        hoverColor: Colors.transparent,
                                        fillColor: Colors.transparent,
                                        filled: false,
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: AnimatedBuilder(
                                  animation: animation,
                                  builder: (context, _) {
                                    final blurAmount =
                                        (1.0 - animation.value) * 8.0;
                                    return ImageFiltered(
                                      imageFilter: ImageFilter.blur(
                                        sigmaX: blurAmount,
                                        sigmaY: blurAmount,
                                      ),
                                      child: child,
                                    );
                                  },
                                ),
                              );
                            },
                            child:
                                _controller.text.trim().isEmpty
                                    ? const SizedBox.shrink()
                                    : Padding(
                                      key: const ValueKey('clean_up_btn'),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.xl,
                                      ),
                                      child: LycriButton(
                                        label: 'Clean up',
                                        leadingSvg:
                                            'assets/vectors/Magic-cap.svg',
                                        fillWidth: true,
                                        isLoading: segmentedState.isLoading,
                                        onPressed:
                                            () =>
                                                ref
                                                    .read(
                                                      segmentedLyricsProvider
                                                          .notifier,
                                                    )
                                                    .cleanup(),
                                      ),
                                    ),
                          ),
                        ],
                      ),
            ),
          ),
        ],
      ),
    );
  }
}
