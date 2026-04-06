import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_stroke.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/lycri_button.dart';

class SaveLyricDialog extends StatefulWidget {
  const SaveLyricDialog({super.key});

  @override
  State<SaveLyricDialog> createState() => _SaveLyricDialogState();
}

class _SaveLyricDialogState extends State<SaveLyricDialog> {
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

    return Dialog(
      backgroundColor: AppColors.surface4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: const BorderSide(color: AppColors.borderMinimal, width: AppStroke.md),
      ),
      elevation: 0,
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Save Lyric',
              style: AppTypography.headingMd.copyWith(
                color: AppColors.textBold,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.borderBold),
              ),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: TextField(
                controller: _controller,
                autofocus: true,
                style: AppTypography.bodyMd.copyWith(color: AppColors.textBold),
                decoration: const InputDecoration(
                  hintText: 'Enter lyric name',
                  hintStyle: TextStyle(color: AppColors.textMinimal),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    Navigator.of(context).pop(value.trim());
                  }
                },
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.borderBold),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: AppTypography.bodyMd.copyWith(color: AppColors.textBold),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: LycriButton(
                    label: 'Save',
                    onPressed: isValid ? () => Navigator.of(context).pop(title) : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
