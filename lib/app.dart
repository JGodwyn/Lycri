import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_spacing.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_typography.dart';

/// Root widget for Lycri.
/// Wraps the app in [ProviderScope] for Riverpod and applies the design system theme.
class LycriApp extends StatelessWidget {
  const LycriApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'Lycri',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const _FontVerificationPage(),
      ),
    );
  }
}

/// Temporary font verification page.
/// Confirms that Libre Caslon Condensed and Libre Caslon Text both load
/// correctly from bundled local assets.
/// Remove this page once real feature screens are in place.
class _FontVerificationPage extends StatelessWidget {
  const _FontVerificationPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface4,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // App title — Libre Caslon Condensed (display weight)
              Text(
                'Lycri',
                style: AppTypography.displayMd.copyWith(
                  color: AppColors.textBrand,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              Text(
                'Desktop Lyric Presentation',
                style: AppTypography.headingMd.copyWith(
                  color: AppColors.textBold,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Font check: Libre Caslon Condensed
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surface3,
                  borderRadius: BorderRadius.circular(AppSpacing.md),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Font check — Libre Caslon Condensed',
                      style: AppTypography.titleSm.copyWith(
                        color: AppColors.textSubtle,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Amazing Grace, how sweet the sound',
                      style: AppTypography.headingSm.copyWith(
                        color: AppColors.textBold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'SemiBold 600 — That saved a wretch like me',
                      style: AppTypography.titleLg.copyWith(
                        color: AppColors.textBold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Font check: Libre Caslon Text
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surface3,
                  borderRadius: BorderRadius.circular(AppSpacing.md),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Font check — Libre Caslon Text',
                      style: AppTypography.titleSm.copyWith(
                        color: AppColors.textSubtle,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'I once was lost, but now am found — was blind, but now I see.',
                      style: AppTypography.bodyLg.copyWith(
                        color: AppColors.textBold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Status indicator
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceSuccess,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Project scaffold ready — local fonts active, tokens applied',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.textSuccess,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
