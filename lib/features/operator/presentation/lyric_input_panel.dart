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

class _LyricInputPanelState extends ConsumerState<LyricInputPanel>
    with TickerProviderStateMixin {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  late final AnimationController _pulseController;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
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
    _pulseController.dispose();
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
    final isLoading = segmentedState.isLoading;

    if (isLoading) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.value = 0;
    }

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
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Row(
              children: [
                Text(
                  'Lycri',
                  style: AppTypography.headingMd.copyWith(
                    color: AppColors.textBold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: AnimatedBuilder(
                        animation: animation,
                        builder: (context, _) {
                          final blurAmount = (1.0 - animation.value) * 8.0;
                          return ImageFiltered(
                            imageFilter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
                            child: child,
                          );
                        },
                      ),
                    );
                  },
                  child: isSegmented
                      ? GestureDetector(
                          key: const ValueKey('back_btn'),
                          onTap: () => ref.read(segmentedLyricsProvider.notifier).reset(),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: AppColors.surface3,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: SvgPicture.asset(
                              'assets/vectors/Go-back.svg',
                              width: 20,
                              height: 20,
                              colorFilter: const ColorFilter.mode(
                                AppColors.iconSubtle,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.none),

          // ── Content Switcher ────────────────────────────────────────────
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              switchInCurve: Curves.easeInOutCubic,
              switchOutCurve: Curves.easeInOutCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: AnimatedBuilder(
                    animation: animation,
                    builder: (context, _) {
                      final blurAmount = (1.0 - animation.value) * 15.0;
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
                  isSegmented
                      ? const SegmentedLyricsView(key: ValueKey('segmented'))
                      : Column(
                        key: const ValueKey('raw_input'),
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _focusNode.requestFocus(),
                              behavior: HitTestBehavior.opaque,
                              child: AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, child) {
                                  final pulse = _pulseController.value;
                                  final opacity =
                                      isLoading
                                          ? 0.5 + (0.3 * (1 - pulse))
                                          : 1.0;
                                  final blur = isLoading ? (pulse * 6.0) : 0.0;

                                  return Opacity(
                                    opacity: opacity,
                                    child: ImageFiltered(
                                      imageFilter: ImageFilter.blur(
                                        sigmaX: blur,
                                        sigmaY: blur,
                                      ),
                                      child: child,
                                    ),
                                  );
                                },
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
                                        scrollPhysics:
                                            const NeverScrollableScrollPhysics(),
                                        textAlignVertical:
                                            TextAlignVertical.top,
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
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                            child:
                                _controller.text.trim().isEmpty || isLoading
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
                                        isLoading: isLoading,
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
