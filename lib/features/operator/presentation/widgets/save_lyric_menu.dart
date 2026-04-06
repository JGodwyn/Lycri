import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_stroke.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/lycri_button.dart';
import '../../../../shared/widgets/lycri_text_field.dart';

class SaveLyricMenu extends StatefulWidget {
  final VoidCallback onClose;
  final Function(String) onSave;

  const SaveLyricMenu({super.key, required this.onClose, required this.onSave});

  @override
  State<SaveLyricMenu> createState() => _SaveLyricMenuState();
}

class _SaveLyricMenuState extends State<SaveLyricMenu> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _controller.text.trim();
    final isValid = title.isNotEmpty;

    return Container(
      width: 280,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface4,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: AppColors.borderMinimal, width: AppStroke.md),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Name this lyric',
                style: AppTypography.titleLg.copyWith(
                  color: AppColors.textBold,
                ),
              ),
              GestureDetector(
                onTap: widget.onClose,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    width: 32,
                    height: 32,
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.surface3,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: AppColors.iconSubtle,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LycriTextField(
            controller: _controller,
            autoFocus: true,
            hintText: 'Enter name here',
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                widget.onSave(value.trim());
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          LycriButton(
            label: 'Save Lyric',
            onPressed: isValid ? () => widget.onSave(title) : null,
          ),
        ],
      ),
    );
  }
}
