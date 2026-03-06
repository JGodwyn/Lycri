import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_stroke.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/providers/lyrics_provider.dart';

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
  bool _clearing = false;

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
    if (_clearing) return;
    ref.read(lyricsProvider.notifier).update(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    // When lyrics are cleared externally (e.g. Clear button on presenter),
    // also clear the text field.
    ref.listen<String?>(lyricsProvider, (prev, next) {
      if (next == null && _controller.text.trim().isNotEmpty) {
        _clearing = true;
        _controller.clear();
        _clearing = false;
      }
    });
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface4,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.borderMinimal, width: AppStroke.md),
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
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
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.textSubtle,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Lyrics text field ────────────────────────────────────────────
          Expanded(
            child: TextField(
              controller: _controller,
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
        ],
      ),
    );
  }
}
