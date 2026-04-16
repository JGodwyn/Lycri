import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import 'editor_panel.dart';
import 'lyric_input_panel.dart';
import 'ndi_operator_view.dart';
import 'presenter_panel.dart';

/// Main operator (control) window for Lycri.
/// Three-column layout: lyric input sidebar | presenter preview | style editor.
class OperatorPage extends StatelessWidget {
  const OperatorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface3,
      body: Stack(
        // Clip.none is required so the NdiOperatorView's offscreen
        // RepaintBoundary (at -2000,-2000) is still painted in release
        // mode. With the default Clip.hardEdge, Flutter may skip
        // painting content outside the clip region as an optimization,
        // causing toImage() to return blank (black) frames.
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Left: lyric input sidebar ──────────────────────────────────
                SizedBox(width: 320, child: const LyricInputPanel()),

                const SizedBox(width: AppSpacing.md),

                // ── Center: presenter preview ────────────────────────────────
                Expanded(flex: 3, child: const PresenterPanel()),

                const SizedBox(width: AppSpacing.md),

                // ── Right: style editor ──────────────────────────────────────
                SizedBox(width: 368, child: const EditorPanel()),
              ],
            ),
          ),
          const NdiOperatorView(),
        ],
      ),
    );
  }
}
