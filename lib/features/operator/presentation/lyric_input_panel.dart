import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_stroke.dart';
import '../../../core/theme/app_typography.dart';
import 'package:lycri_lyrics/shared/providers/lyrics_provider.dart';
import 'package:lycri_lyrics/shared/utils/dialog_utils.dart';
import '../../../shared/widgets/lycri_button.dart';
import '../../../shared/widgets/lycri_pill_group.dart';
import 'package:lycri_lyrics/features/operator/presentation/widgets/lyric_search_dialog.dart';
import '../models/lyrics_segment.dart';
import 'widgets/segmented_lyrics_view.dart';
import '../../../shared/widgets/scroll_fade_mask.dart';
import '../../../shared/widgets/fade_text.dart';
import '../../../shared/utils/caps_text_controller.dart';
import 'widgets/save_lyric_menu.dart';

/// Left panel of the operator window (Figma: "LyricWindow").
///
/// Header (logo + new/search), a title bar for the current lyric
/// (name + edit/save), then either the raw text input with "Clean up"
/// or the segmented card list. Text changes reach the presenter in real time.
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
  final _titleFocusNode = FocusNode();
  // Title is set in title-lg (uppercase): show caps while renaming,
  // but save what was typed.
  final _titleController = CapsTextEditingController();
  late final AnimationController _pulseController;
  bool _clearing = false;
  bool _isEditingTitle = false;

  // ── Save menu (anchored under the title bar) ──────────────────────────────
  final LayerLink _saveMenuLink = LayerLink();
  OverlayEntry? _saveMenuEntry;
  bool _isSaveMenuOpen = false;
  bool _showSaveSuccess = false;
  late final AnimationController _saveMenuController;
  late final Animation<double> _saveMenuScale;
  late final Animation<double> _saveMenuFade;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _saveMenuController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    final curved = CurvedAnimation(
      parent: _saveMenuController,
      curve: Curves.easeOutCubic,
    );
    _saveMenuScale = Tween(begin: 0.92, end: 1.0).animate(curved);
    _saveMenuFade = Tween(begin: 0.0, end: 1.0).animate(curved);
    _titleFocusNode.addListener(_onTitleFocusChanged);
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
    _closeSaveMenu();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _titleFocusNode.dispose();
    _titleController.dispose();
    _pulseController.dispose();
    _saveMenuController.dispose();
    super.dispose();
  }

  // ── Title editing ─────────────────────────────────────────────────────────

  void _onTitleFocusChanged() {
    if (!_titleFocusNode.hasFocus && _isEditingTitle) {
      _finishEditingTitle();
    }
  }

  void _startEditingTitle(String? currentTitle) {
    _titleController.text = currentTitle ?? '';
    setState(() {
      _isEditingTitle = true;
    });
    // Request focus after the text field is rendered
    Future.delayed(const Duration(milliseconds: 50), () {
      _titleFocusNode.requestFocus();
    });
  }

  void _finishEditingTitle() {
    if (!_isEditingTitle) return;

    final newTitle = _titleController.text.trim();
    if (newTitle.isNotEmpty) {
      ref.read(segmentedLyricsProvider.notifier).updateTitle(newTitle);
    }

    setState(() {
      _isEditingTitle = false;
    });
  }

  void _onTextChanged() {
    if (_clearing) return;
    ref.read(lyricsProvider.notifier).update(_controller.text);
    // Trigger rebuild to update button enabled/disabled state based on text.
    if (mounted) setState(() {});
  }

  // ── Header / title bar actions ────────────────────────────────────────────

  void _startNewLyric() {
    ref.read(segmentedLyricsProvider.notifier).clearAll();
    _focusNode.requestFocus();
  }

  void _openSearch() {
    showLycriDialog(
      context: context,
      builder: (context) => const LyricSearchDialog(),
    );
  }

  void _editLyric(SegmentedLyricsState state) {
    final notifier = ref.read(segmentedLyricsProvider.notifier);
    if (state.isSaved) {
      notifier.editSavedLyric();
    } else {
      notifier.reset();
    }
  }

  /// Save works from the typing view too: a lyric already in the library is
  /// cleaned up (which auto-saves it); a new one is named first (unless it
  /// was already named via "Tap to name"), then cleaned up and added to the
  /// library in [_confirmSave].
  void _onSavePressed(SegmentedLyricsState state) {
    if (!state.isSegmented && state.songId != null) {
      _cleanUp(state);
      return;
    }
    if (state.songId != null) {
      _confirmSave(null);
    } else if (state.songTitle != null) {
      // Already named via "Tap to name" — no need to ask again.
      _confirmSave(state.songTitle);
    } else if (_isSaveMenuOpen) {
      _closeSaveMenu();
    } else {
      _openSaveMenu(state.songTitle);
    }
  }

  void _openSaveMenu(String? initialTitle) {
    _saveMenuEntry = OverlayEntry(
      builder:
          (context) => Stack(
            children: [
              // Tap-away barrier
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _closeSaveMenu,
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned(
                width: 288,
                child: CompositedTransformFollower(
                  link: _saveMenuLink,
                  showWhenUnlinked: false,
                  targetAnchor: Alignment.bottomLeft,
                  followerAnchor: Alignment.topLeft,
                  offset: const Offset(0, AppSpacing.sm),
                  child: Material(
                    color: Colors.transparent,
                    child: FadeTransition(
                      opacity: _saveMenuFade,
                      child: ScaleTransition(
                        scale: _saveMenuScale,
                        child: SaveLyricMenu(
                          initialTitle: initialTitle,
                          onClose: _closeSaveMenu,
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

    Overlay.of(context).insert(_saveMenuEntry!);
    _saveMenuController.forward();
    setState(() => _isSaveMenuOpen = true);
  }

  void _closeSaveMenu() {
    if (!_isSaveMenuOpen) return;
    _saveMenuController.reverse().then((_) {
      _saveMenuEntry?.remove();
      _saveMenuEntry = null;
    });
    _isSaveMenuOpen = false;
    if (mounted) setState(() {});
  }

  Future<void> _confirmSave(String? title) async {
    _closeSaveMenu();

    // Tiny delay to ensure menu closes before success animation starts
    await Future.delayed(const Duration(milliseconds: 100));

    final notifier = ref.read(segmentedLyricsProvider.notifier);
    final saved = await _reportSaveErrors(() async {
      // Saved from the typing view: clean up into cards first — saving
      // stores the segments.
      if (!ref.read(segmentedLyricsProvider).isSegmented) {
        await notifier.cleanup();
      }
      await notifier.saveLyric(title);
    });
    if (saved) await _flashSaved();
  }

  /// Runs a save and tells the user if the library rejected it, instead of
  /// failing silently. Returns whether it succeeded.
  Future<bool> _reportSaveErrors(Future<void> Function() save) async {
    try {
      await save();
      return true;
    } catch (e, st) {
      debugPrint('Lycri: saving to the library failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't save to the library. Restart Lycri and try again.",
            ),
          ),
        );
      }
      return false;
    }
  }

  /// Segments the text; lyrics already in the library are saved as part of
  /// that (see [SegmentedLyricsNotifier.cleanup]), so flash the save tick.
  Future<void> _cleanUp(SegmentedLyricsState state) async {
    final inLibrary = state.songId != null;
    final ok = await _reportSaveErrors(
      () => ref.read(segmentedLyricsProvider.notifier).cleanup(),
    );
    if (inLibrary && ok) await _flashSaved();
  }

  /// Shows the check on the save button for a moment.
  Future<void> _flashSaved() async {
    if (!mounted) return;
    setState(() => _showSaveSuccess = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _showSaveSuccess = false);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final segmentedState = ref.watch(segmentedLyricsProvider);
    final isSegmented = segmentedState.isSegmented;

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
        border: Border.all(
          color: AppColors.borderSubtle,
          width: AppStroke.sm,
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20),
        ],
      ),
      padding: const EdgeInsets.all(AppPadding.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(segmentedState),
          const SizedBox(height: AppSpacing.lg),
          _buildTitleBar(segmentedState),
          const SizedBox(height: AppSpacing.lg),

          // ── Content: raw input ⇄ segmented cards ─────────────────────────
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
                      : _buildRawInput(segmentedState),
            ),
          ),
        ],
      ),
    );
  }

  /// Logo + new lyric / search.
  Widget _buildHeader(SegmentedLyricsState state) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Lycri'.toUpperCase(),
            style: AppTypography.logo.copyWith(color: AppColors.textBrand),
          ),
        ),
        LycriPillGroup(
          segments: [
            LycriPillSegment(
              svgAsset: 'assets/vectors/plus.svg',
              tooltip: 'New lyric',
              width: 56,
              onTap: _startNewLyric,
            ),
            LycriPillSegment(
              svgAsset: 'assets/vectors/magnifyingglass.svg',
              tooltip: 'Search saved lyrics',
              width: 56,
              // Loading a song mid-edit would silently drop the edit.
              enabled: !state.isEditing,
              onTap: _openSearch,
            ),
          ],
        ),
      ],
    );
  }

  /// Inverse pill: lyric name (tap to rename) + edit / save.
  Widget _buildTitleBar(SegmentedLyricsState state) {
    final titleStyle = AppTypography.titleLg.copyWith(
      color: AppColors.textInverse,
    );
    // Segmented: unsaved or changed. Typing: whenever there's text — Save
    // cleans it up and saves (naming it first if it's new).
    final canSave =
        state.isSegmented
            ? (!state.isSaved || state.hasChanges)
            : (_controller.text.trim().isNotEmpty && !state.isLoading);

    return CompositedTransformTarget(
      link: _saveMenuLink,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppPadding.md,
          AppPadding.xs,
          AppPadding.xs,
          AppPadding.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceInverse,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(
          children: [
            SvgPicture.asset(
              'assets/vectors/music.svg',
              width: 20,
              height: 20,
              colorFilter: const ColorFilter.mode(
                AppColors.iconMinimal,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child:
                  _isEditingTitle
                      ? TextField(
                        controller: _titleController,
                        focusNode: _titleFocusNode,
                        style: titleStyle,
                        cursorColor: AppColors.textInverse,
                        decoration: const InputDecoration(
                          isDense: true,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                        onSubmitted: (_) => _finishEditingTitle(),
                      )
                      : MouseRegion(
                        cursor: SystemMouseCursors.text,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _startEditingTitle(state.songTitle),
                          child: FadeText(
                            (state.songTitle ?? 'Tap to name').toUpperCase(),
                            // The placeholder is subtle; a real name is inverse.
                            style:
                                state.songTitle == null
                                    ? titleStyle.copyWith(
                                      color: AppColors.textSubtle,
                                    )
                                    : titleStyle,
                          ),
                        ),
                      ),
            ),
            const SizedBox(width: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.all(AppStroke.md),
              child: LycriPillGroup(
                tone: LycriPillTone.dark,
                segments: [
                  LycriPillSegment(
                    svgAsset: 'assets/vectors/edit-pen.svg',
                    tooltip: 'Edit lyric text',
                    enabled: state.isSegmented,
                    onTap: () => _editLyric(state),
                  ),
                  LycriPillSegment(
                    svgAsset:
                        _showSaveSuccess
                            ? 'assets/vectors/check-large.svg'
                            : 'assets/vectors/save.svg',
                    tooltip: state.isSaved && !canSave ? 'Saved' : 'Save lyric',
                    enabled: canSave && !_showSaveSuccess,
                    onTap: () => _onSavePressed(state),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Status label, raw text field, and the "Clean up" action.
  Widget _buildRawInput(SegmentedLyricsState state) {
    final isLoading = state.isLoading;
    final hasText = _controller.text.trim().isNotEmpty;

    return Column(
      key: const ValueKey('raw_input'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          (state.isEditing ? 'Editing a saved lyric' : 'Adding a new lyric')
              .toUpperCase(),
          style: AppTypography.titleMd.copyWith(color: AppColors.textMinimal),
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: GestureDetector(
            onTap: () => _focusNode.requestFocus(),
            behavior: HitTestBehavior.opaque,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final pulse = _pulseController.value;
                final opacity = isLoading ? 0.5 + (0.3 * (1 - pulse)) : 1.0;
                final blur = isLoading ? (pulse * 6.0) : 0.0;

                return Opacity(
                  opacity: opacity,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                    child: child,
                  ),
                );
              },
              child: ScrollConfiguration(
                // No scrollbar: the edge fade signals there's more to scroll.
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(scrollbars: false),
                child: ScrollFadeMask(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      maxLines: null,
                      scrollPhysics: const NeverScrollableScrollPhysics(),
                      textAlignVertical: TextAlignVertical.top,
                      cursorColor: AppColors.textBrand,
                      style: AppTypography.bodyLg.copyWith(
                        color: AppColors.textBold,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'Start typing, paste your lyric, or search for a saved lyric…',
                        hintStyle: AppTypography.bodyLg.copyWith(
                          color: AppColors.textMinimal,
                        ),
                        hintMaxLines: 3,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
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
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final blur = isLoading ? (_pulseController.value * 4.0) : 0.0;
            return Opacity(
              opacity: isLoading ? 0.6 : 1.0,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: child!,
              ),
            );
          },
          child: LycriButton(
            label: 'Clean up',
            leadingSvg: 'assets/vectors/Magic-wand.svg',
            fillWidth: true,
            isLoading: isLoading,
            onPressed: (isLoading || !hasText) ? null : () => _cleanUp(state),
          ),
        ),
      ],
    );
  }
}
