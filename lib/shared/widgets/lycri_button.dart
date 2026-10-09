import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_stroke.dart';
import '../../core/theme/app_typography.dart';
import 'cassette_press.dart';
import 'inner_shadow.dart';

/// Button variant — primary (filled brand) or secondary (light tint).
enum LycriButtonVariant { primary, secondary }

/// App-wide reusable button for Lycri.
///
/// Supports primary/secondary variants with rest, hover, pressed, and disabled
/// states. Leading and trailing icons are hidden by default and shown only when
/// their corresponding [IconData] is supplied.
///
/// ```dart
/// LycriButton(
///   label: 'Continue',
///   onPressed: () {},
///   trailingIcon: Icons.arrow_forward,
/// )
/// ```
class LycriButton extends StatefulWidget {
  const LycriButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = LycriButtonVariant.primary,
    this.leadingIcon,
    this.leadingSvg,
    this.trailingIcon,
    this.fillWidth = false,
    this.height = 40,
    this.disabled = false,
    this.isLoading = false,
    this.labelStyle = AppTypography.titleLg,
  });

  /// The text displayed inside the button.
  final String label;

  /// Called when the button is tapped. Pass `null` to disable the button.
  final VoidCallback? onPressed;

  /// Visual variant — [LycriButtonVariant.primary] or
  /// [LycriButtonVariant.secondary].
  final LycriButtonVariant variant;

  /// Optional icon shown before the label. Hidden when `null`.
  final IconData? leadingIcon;

  /// Optional SVG asset shown before the label. Hidden when `null`.
  final String? leadingSvg;

  /// Optional icon shown after the label. Hidden when `null`.
  final IconData? trailingIcon;

  /// When `true`, the button stretches to fill its parent's width.
  /// Defaults to `false` (intrinsic width).
  final bool fillWidth;

  /// The height of the button. Defaults to `40`.
  final double height;

  /// When `true`, the button is visually and functionally disabled.
  /// Defaults to `false`.
  final bool disabled;

  /// When `true`, the button shows a loading spinner and is disabled.
  /// Defaults to `false`.
  final bool isLoading;

  /// Label text style (uppercased). Defaults to `title-lg`, the app's
  /// button text style.
  final TextStyle labelStyle;

  @override
  State<LycriButton> createState() => _LycriButtonState();
}

/// Primary button inner shadow. Raw hex from the Figma frame — the design
/// doesn't bind it to a variable (closest token is Orange600 #9D3900).
const Color _primaryInnerShadow = Color(0xFF993B00);

class _LycriButtonState extends State<LycriButton> {
  /// Press progress from [CassettePress] (0 rest → 1 pressed in).
  double _t = 0;
  bool get _pressed => _t > 0.5;

  bool get _enabled =>
      !widget.disabled && widget.onPressed != null && !widget.isLoading;

  /// Disabled buttons keep their resting look at 20% opacity (Figma: the
  /// empty-state "Clean up" button). Loading buttons stay fully opaque.
  bool get _dimmed =>
      !widget.isLoading && (widget.disabled || widget.onPressed == null);

  bool get _isPrimary => widget.variant == LycriButtonVariant.primary;

  // ── Colour resolution ────────────────────────────────────────────────────

  Color get _backgroundColor {
    // No hover state: feedback is the cassette press.
    final rest =
        _isPrimary
            ? AppColors.btnBrandPrimaryRest
            : AppColors.btnBrandSecondaryRest;
    final pressed =
        _isPrimary
            ? AppColors.btnBrandPrimaryPressed
            : AppColors.btnBrandSecondaryPressed;
    // Only part-way to the pressed token: a full Orange800 reads as brown,
    // and the sink + flipped shadow already sell the press.
    return Color.lerp(rest, pressed, 0.4 * _t.clamp(0.0, 1.0))!;
  }

  Color get _foregroundColor {
    // Primary always uses inverse (white) text.
    if (widget.variant == LycriButtonVariant.primary) {
      return AppColors.textInverse;
    }

    // Secondary uses bold (dark) text normally, inverse (white) when pressed
    // to keep contrast against the solid orange pressed background.
    if (_enabled && _pressed) {
      return AppColors.textInverse;
    }
    return AppColors.textBold;
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: _dimmed ? 0.2 : 1.0,
        child: CassettePress(
          enabled: _enabled,
          onTap: widget.onPressed,
          builder: (context, t) {
            _t = t;
            return InnerShadow(
              color: _isPrimary ? _primaryInnerShadow : Colors.transparent,
              offset: CassettePress.shadowOffset(t),
              borderRadius: BorderRadius.circular(AppRadius.full),
              blurRadius: widget.height >= 40 ? 12 : 8,
              child: Container(
                height: widget.height,
                padding: const EdgeInsets.symmetric(horizontal: AppPadding.lg),
                decoration: BoxDecoration(
                  color: _backgroundColor,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border:
                      _isPrimary
                          ? Border.all(
                            color: AppColors.orange100,
                            width: AppStroke.lg,
                          )
                          : null,
                ),
                child: Row(
                  mainAxisSize:
                      widget.fillWidth ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Leading icon — hidden when null
                    if (widget.leadingIcon != null ||
                        widget.leadingSvg != null) ...[
                      if (widget.leadingIcon != null)
                        Icon(
                          widget.leadingIcon,
                          size: 20,
                          color: _foregroundColor,
                        )
                      else if (widget.leadingSvg != null)
                        SvgPicture.asset(
                          widget.leadingSvg!,
                          width: 24,
                          height: 24,
                          colorFilter: ColorFilter.mode(
                            _foregroundColor,
                            BlendMode.srcIn,
                          ),
                        ),
                      const SizedBox(width: AppSpacing.md),
                    ],

                    // Label — uppercase (Figma text case)
                    Text(
                      widget.label.toUpperCase(),
                      style: widget.labelStyle.copyWith(
                        color: _foregroundColor,
                      ),
                    ),

                    // Trailing icon — hidden when null
                    if (widget.trailingIcon != null) ...[
                      const SizedBox(width: AppSpacing.md),
                      Icon(
                        widget.trailingIcon,
                        size: 20,
                        color: _foregroundColor,
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
