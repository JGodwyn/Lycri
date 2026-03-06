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

/// Center panel of the operator window.
/// Shows a top bar with the "Presenter" label and a "Go live" button,
/// plus a large preview area that displays either an empty state or the
/// submitted lyrics.
class PresenterPanel extends ConsumerWidget {
  const PresenterPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyrics = ref.watch(lyricsProvider);

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
                  // ── Clear button ─────────────────────────────────────────
                  LycriButton(
                    variant: LycriButtonVariant.secondary,
                    label: 'Clear',
                    onPressed: () {
                      ref.read(lyricsProvider.notifier).clear();
                    },
                    fillWidth: false,
                    height: 32,
                    disabled: lyrics == null,
                  ),

                  const SizedBox(width: AppSpacing.md),

                  // ── Go Live button ──────────────────────────────────────
                  LycriButton(
                    label: 'Go Live',
                    onPressed: () {},
                    fillWidth: false,
                    height: 32,
                    disabled: lyrics == null,
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
                      ? _LyricsPreview(
                        key: const ValueKey('lyrics'),
                        lyrics: lyrics,
                      )
                      : const _EmptyPresenterState(key: ValueKey('empty')),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Lyrics preview ─────────────────────────────────────────────────────────

class _LyricsPreview extends StatelessWidget {
  const _LyricsPreview({super.key, required this.lyrics});

  final String lyrics;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          lyrics,
          style: AppTypography.headingMd.copyWith(color: AppColors.textSubtle),
        ),
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
