import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_stroke.dart';
import 'cassette_press.dart';
import 'fade_text.dart';
import '../../core/theme/app_typography.dart';

/// Compact 32px value pill (Figma: editor "Font color", "Colors", "Image",
/// "Recently used"): a leading preview (swatch / thumbnail) joined to a
/// value box, optionally followed by a red delete segment.
class LycriValueChip extends StatefulWidget {
  const LycriValueChip({
    super.key,
    required this.leading,
    required this.value,
    this.onTap,
    this.onDelete,
    this.tooltip,
    this.tint,
  });

  /// Square preview (swatch / thumbnail): fully rounded on the left, square
  /// where it meets the value box; the only part with a hairline border.
  final Widget leading;

  /// Text in the value box (body-lg), faded if it doesn't fit.
  final String value;

  final VoidCallback? onTap;

  /// Shows the delete segment when set.
  final VoidCallback? onDelete;

  final String? tooltip;

  /// Colour the value box is washed with (10% opacity, 20% pressed) so it
  /// reads as a lighter version of the swatch. Null → neutral `surface-3`.
  /// Near-white tints fall back to neutral, since they'd vanish on white.
  final Color? tint;

  static const double height = 32;

  @override
  State<LycriValueChip> createState() => _LycriValueChipState();
}

class _LycriValueChipState extends State<LycriValueChip> {
  /// Value box colour; darkens as the chip is pressed in ([t] 0 → 1).
  /// No hover state — feedback is the press.
  Color _boxColor(double t) {
    final p = t.clamp(0.0, 1.0);
    final tint = widget.tint;
    if (tint == null || tint.computeLuminance() > 0.9) {
      return Color.lerp(AppColors.surface3, AppColors.surface2, p)!;
    }
    return tint.withValues(alpha: 0.10 + 0.10 * p);
  }

  @override
  Widget build(BuildContext context) {
    final hasDelete = widget.onDelete != null;
    // Swatch is the chip's rounded left end; it joins the value box flush.
    const swatchRadius = BorderRadius.horizontal(
      left: Radius.circular(AppRadius.full),
    );
    const right = BorderRadius.horizontal(
      right: Radius.circular(AppRadius.full),
    );

    Widget chipBody(double t) => Row(
      children: [
        // Swatch: the only bordered part, so white values stay visible.
        ClipRRect(
          borderRadius: swatchRadius,
          child: SizedBox.square(
            dimension: LycriValueChip.height,
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: swatchRadius,
                border: Border.all(
                  color: AppColors.borderSubtle,
                  width: AppStroke.md,
                ),
              ),
              child: widget.leading,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: LycriValueChip.height,
            padding: const EdgeInsets.symmetric(horizontal: AppPadding.sm),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: _boxColor(t),
              borderRadius: hasDelete ? null : right,
            ),
            child: FadeText(
              widget.value,
              style: AppTypography.bodyLg.copyWith(color: AppColors.textSubtle),
            ),
          ),
        ),
      ],
    );

    Widget chip =
        widget.onTap == null
            ? chipBody(0)
            : MouseRegion(
              cursor: SystemMouseCursors.click,
              child: CassettePress(
                onTap: widget.onTap,
                builder: (context, t) => chipBody(t),
              ),
            );
    if (widget.tooltip != null) {
      chip = Tooltip(message: widget.tooltip!, child: chip);
    }
    if (!hasDelete) return chip;

    return Row(
      children: [
        Expanded(child: chip),
        const SizedBox(width: AppSpacing.xs),
        Tooltip(
          message: 'Remove',
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: CassettePress(
              onTap: widget.onDelete,
              builder:
                  (context, t) => Container(
                    width: 40,
                    height: LycriValueChip.height,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color:
                          Color.lerp(
                            AppColors.btnDangerSecondaryRest,
                            AppColors.btnDangerSecondaryHover,
                            t.clamp(0.0, 1.0),
                          )!,
                      borderRadius: right,
                    ),
                    child: SvgPicture.asset(
                      'assets/vectors/delete-trash.svg',
                      width: 16,
                      height: 16,
                      colorFilter: const ColorFilter.mode(
                        AppColors.iconDanger,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Solid or gradient fill for a [LycriValueChip.leading].
class ChipSwatch extends StatelessWidget {
  const ChipSwatch({super.key, this.color, this.gradient});

  final Color? color;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    // The chip draws the border; this is just the fill.
    return DecoratedBox(
      decoration: BoxDecoration(color: color, gradient: gradient),
    );
  }
}
