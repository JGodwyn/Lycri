import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_stroke.dart';
import '../../core/theme/app_typography.dart';

/// Reusable text field component for Lycri.
///
/// Used for search bars, settings inputs, and general text entry.
class LycriTextField extends StatelessWidget {
  const LycriTextField({
    super.key,
    this.controller,
    this.onChanged,
    this.hintText,
    this.prefixIcon,
    this.autoFocus = false,
    this.height = 40,
  });

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final String? hintText;
  final Widget? prefixIcon;
  final bool autoFocus;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xmd),
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surface3,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.borderSubtle, width: AppStroke.md),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              autofocus: autoFocus,
              textAlignVertical: TextAlignVertical.center,
              style: AppTypography.bodyMd.copyWith(color: AppColors.textBold),
              cursorColor: AppColors.textBrand,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.transparent,
                hoverColor: Colors.transparent,
                focusColor: Colors.transparent,
                hintText: hintText,
                hintStyle: AppTypography.bodyLg.copyWith(
                  color: AppColors.textMinimal,
                ),
                prefixIcon:
                    prefixIcon != null
                        ? Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: prefixIcon,
                        )
                        : null,
                prefixIconConstraints: const BoxConstraints(minHeight: 40),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
