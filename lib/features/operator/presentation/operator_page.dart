import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import 'editor_panel.dart';
import 'lyric_input_panel.dart';
import 'presenter_panel.dart';

/// Main operator (control) window for Lycri.
/// Three-column layout: lyric input sidebar | presenter preview | style editor.
class OperatorPage extends StatelessWidget {
  const OperatorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface3,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Left: lyric input sidebar ──────────────────────────────────
            SizedBox(width: 280, child: const LyricInputPanel()),

            const SizedBox(width: AppSpacing.md),

            // ── Center: presenter preview ────────────────────────────────
            Expanded(flex: 3, child: const PresenterPanel()),

            const SizedBox(width: AppSpacing.md),

            // ── Right: style editor ──────────────────────────────────────
            SizedBox(width: 280, child: const EditorPanel()),
          ],
        ),
      ),
    );
  }
}
