import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'cassette_press.dart';
import 'fade_text.dart';
import 'inner_shadow.dart';

/// − value + stepper (Figma: "Steper").
///
/// Two 40×32 cassette keys joined 2px apart (`dist-xs`) to a value cell that
/// fills the rest; only the outer ends are rounded. Steps [value] by [step]
/// within [min]–[max]; a key greys out at its limit. [format] renders the
/// value (e.g. `'40%'`).
class LycriStepper extends StatelessWidget {
  const LycriStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 100,
    this.step = 10,
    this.format,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;
  final String Function(int value)? format;

  static const double _height = 32;
  static const double _keyWidth = 40;

  @override
  Widget build(BuildContext context) {
    final canDecrease = value > min;
    final canIncrease = value < max;
    return SizedBox(
      height: _height,
      child: Row(
        children: [
          _StepKey(
            svgAsset: 'assets/vectors/minus.svg',
            tooltip: 'Decrease',
            enabled: canDecrease,
            onTap: () => onChanged((value - step).clamp(min, max)),
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(AppRadius.full),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Container(
              height: _height,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: AppPadding.sm),
              color: AppColors.surface3,
              child: FadeText(
                format?.call(value) ?? '$value',
                style: AppTypography.bodyLg.copyWith(
                  color: AppColors.textSubtle,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          _StepKey(
            svgAsset: 'assets/vectors/plus.svg',
            tooltip: 'Increase',
            enabled: canIncrease,
            onTap: () => onChanged((value + step).clamp(min, max)),
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(AppRadius.full),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepKey extends StatelessWidget {
  const _StepKey({
    required this.svgAsset,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
    required this.borderRadius,
  });

  final String svgAsset;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: CassettePress(
          enabled: enabled,
          onTap: onTap,
          builder:
              (context, t) => InnerShadow(
                color: Colors.black.withValues(
                  alpha: CassettePress.shadowAlpha(0.15, t),
                ),
                offset: CassettePress.shadowOffset(t),
                borderRadius: borderRadius,
                child: Container(
                  width: LycriStepper._keyWidth,
                  height: LycriStepper._height,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      AppColors.surface3,
                      AppColors.surface1,
                      t.clamp(0.0, 1.0),
                    ),
                    borderRadius: borderRadius,
                  ),
                  child: SvgPicture.asset(
                    svgAsset,
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(
                      enabled ? AppColors.iconSubtle : AppColors.iconMinimal,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
        ),
      ),
    );
  }
}
