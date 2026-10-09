import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'fade_text.dart';
import 'inner_shadow.dart';

/// One option in a [LycriSegmentedTray].
class LycriTrayOption<T> {
  const LycriTrayOption({
    required this.value,
    required this.label,
    this.iconBuilder,
  });

  final T value;

  /// Shown as text, or — for icon options — as the tooltip.
  /// Uppercased only when the tray's label style is a display/title style.
  final String label;

  /// Makes this an icon-only option (Figma: alignment / background type).
  /// Receives the icon colour for the option's state (inverse when selected,
  /// subtle otherwise).
  final Widget Function(Color color, bool selected)? iconBuilder;
}

/// Single-choice selector (Figma: "Lyrics to display", "Alignment",
/// "Background type", "Gradient type"): a 40px `surface-3` track with a
/// Gray700 pill that slides to the selected option.
class LycriSegmentedTray<T> extends StatelessWidget {
  const LycriSegmentedTray({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.labelStyle = AppTypography.bodyLg,
  });

  final List<LycriTrayOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;

  /// Option label style — `body-lg` by default (editor controls).
  /// Advent Pro (display/title) styles are rendered uppercase.
  final TextStyle labelStyle;

  static const _animDuration = Duration(milliseconds: 300);
  static const _animCurve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = options
        .indexWhere((o) => o.value == selected)
        .clamp(0, options.length - 1);
    final pillRadius = BorderRadius.circular(AppRadius.full);

    return Container(
      padding: const EdgeInsets.all(AppPadding.xs),
      decoration: BoxDecoration(
        color: AppColors.surface3,
        borderRadius: pillRadius,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / options.length;

          return SizedBox(
            height: 32,
            child: Stack(
              children: [
                // ── Sliding selected pill ──────────────────────────────────
                AnimatedPositioned(
                  duration: _animDuration,
                  curve: _animCurve,
                  left: selectedIndex * itemWidth,
                  top: 0,
                  bottom: 0,
                  width: itemWidth,
                  child: InnerShadow(
                    color: Colors.white.withValues(alpha: 0.75),
                    borderRadius: pillRadius,
                    blurRadius: 5,
                    offset: const Offset(0, 1),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.gray700,
                        borderRadius: pillRadius,
                      ),
                    ),
                  ),
                ),

                // ── Options ────────────────────────────────────────────────
                Row(
                  children: [
                    for (final option in options)
                      Expanded(
                        child: _TrayCell(
                          option: option,
                          isSelected: option.value == selected,
                          labelStyle: labelStyle,
                          onTap: () => onSelected(option.value),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TrayCell<T> extends StatelessWidget {
  const _TrayCell({
    required this.option,
    required this.isSelected,
    required this.labelStyle,
    required this.onTap,
  });

  final LycriTrayOption<T> option;
  final bool isSelected;
  final TextStyle labelStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = isSelected ? AppColors.textInverse : AppColors.textSubtle;
    final iconColor = isSelected ? AppColors.iconInverse : AppColors.iconSubtle;

    final cell = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child:
              option.iconBuilder != null
                  ? SizedBox(
                    width: 20,
                    height: 20,
                    child: option.iconBuilder!(iconColor, isSelected),
                  )
                  : AnimatedDefaultTextStyle(
                    duration: LycriSegmentedTray._animDuration,
                    curve: LycriSegmentedTray._animCurve,
                    style: labelStyle.copyWith(color: textColor),
                    child: FadeText(
                      labelStyle.fontFamily == AppTypography.fontDisplay
                          ? option.label.toUpperCase()
                          : option.label,
                    ),
                  ),
        ),
      ),
    );

    return option.iconBuilder != null
        ? Tooltip(message: option.label, child: cell)
        : cell;
  }
}
