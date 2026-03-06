import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_stroke.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/providers/lyrics_provider.dart';
import '../../../shared/widgets/lycri_button.dart';

/// Left panel of the operator window.
/// Two modes:
/// - **Input** — title, hint, text field, Send button (when no lyrics sent)
/// - **Display** — back arrow + title, scrollable read-only lyrics text
class LyricInputPanel extends ConsumerStatefulWidget {
  const LyricInputPanel({super.key});

  @override
  ConsumerState<LyricInputPanel> createState() => _LyricInputPanelState();
}

class _LyricInputPanelState extends ConsumerState<LyricInputPanel> {
  final _controller = TextEditingController();
  bool _hasText = false;
  bool _isSent = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
    // Live-update the presenter when we're back in input mode
    // after having sent lyrics at least once.
    if (!_isSent && ref.read(lyricsProvider) != null) {
      ref.read(lyricsProvider.notifier).update(_controller.text);
    }
  }

  void _sendLyrics() {
    ref.read(lyricsProvider.notifier).send(_controller.text);
    setState(() => _isSent = true);
  }

  void _goBack() {
    setState(() => _isSent = false);
    // Lyrics stay in the provider — presenter keeps displaying them.
  }

  @override
  Widget build(BuildContext context) {
    final lyrics = ref.watch(lyricsProvider);

    // If lyrics were cleared externally (e.g. Clear button on presenter),
    // reset to input mode.
    if (lyrics == null && _isSent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _isSent = false);
      });
    }

    final showDisplay = _isSent && lyrics != null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface4,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.borderMinimal, width: AppStroke.md),
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child:
            showDisplay
                ? _LyricsDisplayView(
                  key: const ValueKey('display'),
                  lyrics: lyrics,
                  onBack: _goBack,
                )
                : _LyricsInputView(
                  key: const ValueKey('input'),
                  controller: _controller,
                  hasText: _hasText,
                  onSend: _sendLyrics,
                ),
      ),
    );
  }
}

// ─── Input mode ────────────────────────────────────────────────────────────────

class _LyricsInputView extends StatelessWidget {
  const _LyricsInputView({
    super.key,
    required this.controller,
    required this.hasText,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool hasText;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── App title ───────────────────────────────────────────────────
        Text(
          'Lycri',
          style: AppTypography.headingMd.copyWith(color: AppColors.textBold),
        ),

        const SizedBox(height: AppSpacing.lg),

        // ── Hint row ────────────────────────────────────────────────────
        Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: AppColors.iconMinimal,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Start by pasting a lyric below…',
              style: AppTypography.bodyMd.copyWith(color: AppColors.textSubtle),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.lg),

        // ── Lyrics text field ────────────────────────────────────────────
        Expanded(
          child: TextField(
            controller: controller,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: AppTypography.bodyMd.copyWith(color: AppColors.textBold),
            decoration: InputDecoration(
              hintText: 'Paste your lyrics here',
              hintStyle: AppTypography.bodyMd.copyWith(
                color: AppColors.textMinimal,
              ),
              filled: true,
              fillColor: AppColors.surface3,
              contentPadding: const EdgeInsets.only(
                left: AppSpacing.md,
                right: AppSpacing.md,
                top: AppSpacing.lg,
                bottom: AppSpacing.lg,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(
                  color: AppColors.borderSubtle,
                  width: AppStroke.md,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                borderSide: BorderSide(
                  color: AppColors.borderSubtle,
                  width: AppStroke.md,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                borderSide: BorderSide(
                  color: AppColors.borderSubtle,
                  width: AppStroke.lg,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // ── Send button — disabled until lyrics are entered ─────────────
        LycriButton(
          label: 'Send',
          onPressed: onSend,
          trailingIcon: Icons.arrow_forward,
          fillWidth: true,
          disabled: !hasText,
        ),
      ],
    );
  }
}

// ─── Display mode (after sending) ──────────────────────────────────────────────

class _LyricsDisplayView extends StatelessWidget {
  const _LyricsDisplayView({
    super.key,
    required this.lyrics,
    required this.onBack,
  });

  final String lyrics;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Back arrow + title ──────────────────────────────────────────
        Row(
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onBack,

                // wrap this icon in a gray frame
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface3,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Icon(
                    Icons.arrow_back,
                    size: 20,
                    color: AppColors.iconSubtle,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Text(
              'Lycri',
              style: AppTypography.headingMd.copyWith(
                color: AppColors.textBold,
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.x3l),

        // ── Scrollable lyrics text ─────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            child: Text(
              lyrics,
              style: AppTypography.bodyMd.copyWith(color: AppColors.textSubtle),
            ),
          ),
        ),
      ],
    );
  }
}
