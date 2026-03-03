import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_stroke.dart';
import '../../../core/theme/app_typography.dart';

/// Left panel of the operator window.
/// Contains the app title, a hint, a lyrics text field, and a Continue button.
class LyricInputPanel extends StatelessWidget {
  const LyricInputPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface4,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderMinimal, width: AppStroke.md),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── App title ───────────────────────────────────────────────────
          Text(
            'Lycri',
            style: AppTypography.headingMd.copyWith(color: AppColors.textBold),
          ),

          const SizedBox(height: AppSpacing.sm),

          // ── Hint row ────────────────────────────────────────────────────
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 13,
                color: AppColors.iconSubtle,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Start by pasting a lyric below…',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.textSubtle,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Lyrics text field ────────────────────────────────────────────
          Expanded(
            child: TextField(
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
                contentPadding: const EdgeInsets.all(AppSpacing.xmd),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(
                    color: AppColors.borderSubtle,
                    width: AppStroke.md,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(
                    color: AppColors.borderSubtle,
                    width: AppStroke.md,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(
                    color: AppColors.borderFocused,
                    width: AppStroke.md,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Continue button ──────────────────────────────────────────────
          SizedBox(width: double.infinity, child: _ContinueButton()),
        ],
      ),
    );
  }
}

class _ContinueButton extends StatefulWidget {
  @override
  State<_ContinueButton> createState() => _ContinueButtonState();
}

class _ContinueButtonState extends State<_ContinueButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: _hovered ? AppColors.surface0 : AppColors.surface1,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Continue',
              style: AppTypography.btnSm.copyWith(color: AppColors.textSubtle),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.arrow_forward, size: 12, color: AppColors.iconSubtle),
          ],
        ),
      ),
    );
  }
}
