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
import 'widgets/save_lyric_menu.dart';

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

  Widget _headerActionTransition(Widget child, Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          // Blur from 8.0 to 0.0 as it appears (animation.value 0 -> 1)
          // Blur from 0.0 to 8.0 as it leaves (animation.value 1 -> 0)
          final blurAmount = (1.0 - animation.value) * 8.0;
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
  }

  @override
  Widget build(BuildContext context) {
    final segmentedState = ref.watch(segmentedLyricsProvider);
    final isSegmented = segmentedState.isSegmented;
    final isLoading = segmentedState.isLoading;

    // Listen for loading state changes to trigger/stop animations correctly.
    ref.listen(segmentedLyricsProvider, (prev, next) {
      final wasLoading = prev?.isLoading ?? false;
      final isNowLoading = next.isLoading;

      if (!wasLoading && isNowLoading) {
        if (!_pulseController.isAnimating) {
          _pulseController.repeat(reverse: true);
        }
      } else if (wasLoading && !isNowLoading) {
        if (_pulseController.isAnimating) {
          _pulseController.stop();
          _pulseController.reset();
        }
      }
    });

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
                SizedBox(
                  width: 140, // Space for 3 icons + spacing
                  height: 40,
                  child: Stack(
                    alignment: Alignment.centerRight,
                    children: [
                      // Save Button (Appears 88px from right)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeInOutCubic,
                        right: isSegmented ? 88.0 : 0.0,
                        top: 0,
                        bottom: 0,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: _headerActionTransition,
                          child:
                              isSegmented
                                  ? const _SaveActionButton(
                                    key: ValueKey('save_action_wrapper'),
                                  )
                                  : const SizedBox.shrink(),
                        ),
                      ),

                      // Search Button (Positions 44px from right if segmented, or at 0 if raw)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeInOutCubic,
                        right: isSegmented ? 44.0 : 0.0,
                        top: 0,
                        bottom: 0,
                        child: _CircularIconButton(
                          key: const ValueKey('search_btn'),
                          onTap: () {}, // TODO: Implement search
                          svgAsset: 'assets/vectors/magnifyingglass.svg',
                        ),
                      ),

                      // Back Button (Always at 0.0 when present)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeInOutCubic,
                        right: 0.0,
                        top: 0,
                        bottom: 0,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: _headerActionTransition,
                          child:
                              isSegmented
                                  ? _CircularIconButton(
                                    key: const ValueKey('back_btn'),
                                    onTap:
                                        () =>
                                            ref
                                                .read(
                                                  segmentedLyricsProvider
                                                      .notifier,
                                                )
                                                .reset(),
                                    svgAsset: 'assets/vectors/Go-back.svg',
                                  )
                                  : const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
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
                      ? Column(
                        key: const ValueKey('segmented'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (segmentedState.songTitle != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: AppSpacing.xl,
                                right: AppSpacing.xl,
                                bottom: AppSpacing.md,
                              ),
                              child: Text(
                                segmentedState.songTitle!,
                                style: AppTypography.headingSm.copyWith(
                                  color: AppColors.textBold,
                                ),
                              ),
                            ),
                          const Expanded(child: SegmentedLyricsView()),
                        ],
                      )
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
                            duration: const Duration(milliseconds: 300),
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
                                (isSegmented || _controller.text.trim().isEmpty)
                                    ? const SizedBox.shrink()
                                    : AnimatedBuilder(
                                      key: const ValueKey('clean_up_btn'),
                                      animation: _pulseController,
                                      builder: (context, child) {
                                        final pulse = _pulseController.value;
                                        final opacity = isLoading ? 0.6 : 1.0;
                                        final blur =
                                            isLoading ? (pulse * 4.0) : 0.0;

                                        return Opacity(
                                          opacity: opacity,
                                          child: ImageFiltered(
                                            imageFilter: ImageFilter.blur(
                                              sigmaX: blur,
                                              sigmaY: blur,
                                            ),
                                            child: child!,
                                          ),
                                        );
                                      },
                                      child: Padding(
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
                                              isLoading
                                                  ? null
                                                  : () =>
                                                      ref
                                                          .read(
                                                            segmentedLyricsProvider
                                                                .notifier,
                                                          )
                                                          .cleanup(),
                                        ),
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

/// A circular icon button with hover and click feedback.
class _CircularIconButton extends StatefulWidget {
  final VoidCallback onTap;
  final String svgAsset;

  const _CircularIconButton({
    super.key,
    required this.onTap,
    required this.svgAsset,
  });

  @override
  State<_CircularIconButton> createState() => _CircularIconButtonState();
}

class _CircularIconButtonState extends State<_CircularIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.surface2 : AppColors.surface3,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: SvgPicture.asset(
            widget.svgAsset,
            width: 20,
            height: 20,
            colorFilter: const ColorFilter.mode(
              AppColors.iconSubtle,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveActionButton extends ConsumerStatefulWidget {
  const _SaveActionButton({super.key});

  @override
  ConsumerState<_SaveActionButton> createState() => _SaveActionButtonState();
}

class _SaveActionButtonState extends ConsumerState<_SaveActionButton>
    with TickerProviderStateMixin {
  bool _showSuccess = false;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isMenuOpen = false;

  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 250),
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
    _closeMenu();
    _animController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    if (_isMenuOpen) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  void _openMenu() {
    _overlayEntry = OverlayEntry(
      builder:
          (context) => Stack(
            children: [
              // Tap-away barrier
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _closeMenu,
                  child: const SizedBox.expand(),
                ),
              ),
              // Positioned menu
              Positioned(
                width: 280,
                child: CompositedTransformFollower(
                  link: _layerLink,
                  showWhenUnlinked: false,
                  targetAnchor: Alignment.bottomLeft,
                  followerAnchor: Alignment.topLeft,
                  offset: const Offset(0, 4), // Directly below with a 4px gap
                  child: Material(
                    color: Colors.transparent,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: ScaleTransition(
                        scale: _scaleAnim,
                        child: SaveLyricMenu(
                          onClose: _closeMenu,
                          onSave: (title) => _confirmSave(title),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _animController.forward();
    setState(() => _isMenuOpen = true);
  }

  void _closeMenu() {
    if (!_isMenuOpen) return;
    _animController.reverse().then((_) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
    if (mounted) setState(() => _isMenuOpen = false);
  }

  Future<void> _confirmSave(String title) async {
    _closeMenu();

    // Tiny delay to ensure menu closes before success animation starts
    await Future.delayed(const Duration(milliseconds: 100));

    await ref.read(segmentedLyricsProvider.notifier).saveLyric(title);

    if (mounted) {
      setState(() => _showSuccess = true);
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        setState(() => _showSuccess = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaved = ref.watch(segmentedLyricsProvider).isSaved;

    Widget child;

    if (_showSuccess) {
      child = Container(
        key: const ValueKey('success'),
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: AppColors.surfaceSuccess,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: SvgPicture.asset(
          'assets/vectors/check-large.svg',
          width: 20,
          height: 20,
          colorFilter: const ColorFilter.mode(
            AppColors.iconInverse,
            BlendMode.srcIn,
          ),
        ),
      );
    } else if (isSaved) {
      child = Container(
        key: const ValueKey('saved'),
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: AppColors.surface3,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: SvgPicture.asset(
          'assets/vectors/save.svg',
          width: 20,
          height: 20,
          colorFilter: const ColorFilter.mode(
            AppColors.iconMinimal,
            BlendMode.srcIn,
          ),
        ),
      );
    } else {
      child = CompositedTransformTarget(
        link: _layerLink,
        child: _CircularIconButton(
          key: const ValueKey('not_saved'),
          onTap: _toggleMenu,
          svgAsset: 'assets/vectors/save.svg',
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: child,
    );
  }
}
