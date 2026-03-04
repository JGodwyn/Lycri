import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_stroke.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/lycri_button.dart';

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
          LycriButton(
            label: 'Continue',
            onPressed: () {},
            trailingIcon: Icons.arrow_forward,
          ),
        ],
      ),
    );
  }
}
