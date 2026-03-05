import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

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
    this.trailingIcon,
    this.fillWidth = false,
    this.height = 40,
    this.disabled = false,
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

  @override
  State<LycriButton> createState() => _LycriButtonState();
}

class _LycriButtonState extends State<LycriButton> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _enabled => !widget.disabled && widget.onPressed != null;

  // ── Colour resolution ────────────────────────────────────────────────────

  Color get _backgroundColor {
    if (!_enabled) {
      return AppColors.btnBrandPrimaryDisabled;
    }
    if (_pressed) {
      return widget.variant == LycriButtonVariant.primary
          ? AppColors.btnBrandPrimaryPressed
          : AppColors.btnBrandSecondaryPressed;
    }
    if (_hovered) {
      return widget.variant == LycriButtonVariant.primary
          ? AppColors.btnBrandPrimaryHover
          : AppColors.btnBrandSecondaryHover;
    }
    return widget.variant == LycriButtonVariant.primary
        ? AppColors.btnBrandPrimaryRest
        : AppColors.btnBrandSecondaryRest;
  }

  Color get _foregroundColor {
    if (!_enabled) {
      return AppColors.textInverse;
    }

    // Primary always uses inverse (white) text.
    if (widget.variant == LycriButtonVariant.primary) {
      return AppColors.textInverse;
    }

    // Secondary uses bold (dark) text normally, inverse (white) when pressed
    // to keep contrast against the solid orange pressed background.
    if (_pressed) {
      return AppColors.textInverse;
    }
    return AppColors.textBold;
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) {
        setState(() {
          _hovered = false;
          _pressed = false;
        });
      },
      child: GestureDetector(
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp:
            _enabled
                ? (_) {
                  setState(() => _pressed = false);
                  widget.onPressed?.call();
                }
                : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Row(
            mainAxisSize:
                widget.fillWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Leading icon — hidden when null
              if (widget.leadingIcon != null) ...[
                Icon(widget.leadingIcon, size: 16, color: _foregroundColor),
                const SizedBox(width: AppSpacing.md),
              ],

              // Label
              Text(
                widget.label,
                style: AppTypography.btnLg.copyWith(color: _foregroundColor),
              ),

              // Trailing icon — hidden when null
              if (widget.trailingIcon != null) ...[
                const SizedBox(width: AppSpacing.md),
                Icon(widget.trailingIcon, size: 16, color: _foregroundColor),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
