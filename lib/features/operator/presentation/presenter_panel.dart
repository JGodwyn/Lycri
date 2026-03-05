import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_stroke.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/lycri_button.dart';

/// Center panel of the operator window.
/// Shows a top bar with the "Presenter" label and a "Go live" button,
/// plus a large preview area that displays an empty state when no lyrics
/// have been loaded yet.
class PresenterPanel extends StatelessWidget {
  const PresenterPanel({super.key});

  @override
  Widget build(BuildContext context) {
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
              // ── Go Live button ──────────────────────────────────────────────
              LycriButton(
                label: 'Go Live',
                onPressed: () {},
                fillWidth: false,
                height: 32,
                disabled: true,
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
            child: const _EmptyPresenterState(),
          ),
        ),
      ],
    );
  }
}

/// Empty state shown in the presenter area before any lyrics are loaded.
class _EmptyPresenterState extends StatelessWidget {
  const _EmptyPresenterState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Waving hand — using the emoji rendered as a large Text widget
          Text(
            '\u{1F44B}',
            style: TextStyle(fontSize: 48, color: AppColors.iconMinimal),
          ),

          const SizedBox(height: AppSpacing.lg),

          Text(
            'Hi there. Waiting fork your lyrics!',
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
