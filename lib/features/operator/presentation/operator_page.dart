import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/providers/active_line_provider.dart';
import '../../../shared/providers/lyrics_provider.dart';
import 'editor_panel.dart';
import 'lyric_input_panel.dart';
import 'ndi_operator_view.dart';
import 'presenter_panel.dart';

/// Main operator (control) window for Lycri.
/// Three-column layout: lyric input sidebar | presenter preview | style editor.
///
/// Arrow keys (and Page Up / Page Down, which presentation clickers send) step
/// through the lyric lines from anywhere in the window, except while a text
/// field has focus.
class OperatorPage extends ConsumerStatefulWidget {
  const OperatorPage({super.key});

  @override
  ConsumerState<OperatorPage> createState() => _OperatorPageState();
}

class _OperatorPageState extends ConsumerState<OperatorPage> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyUpEvent) return false;
    final key = event.logicalKey;
    final int step;
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.pageUp) {
      step = -1;
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.pageDown) {
      step = 1;
    } else {
      return false;
    }

    // Leave modified arrows (word/line jumps, shortcuts) alone, and don't
    // steal keys from dialogs or menus pushed over this page.
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isMetaPressed ||
        keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isShiftPressed) {
      return false;
    }
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    if (_isEditingText()) return false;

    final lines = ref.read(lyricsLinesProvider);
    if (lines.isEmpty) return false;
    final active = ref.read(activeLineProvider.notifier);
    if (step < 0) {
      active.previous();
    } else {
      active.next(lines.length - 1);
    }
    ref.read(scrollToActiveTriggerProvider.notifier).state++;
    return true;
  }

  /// Whether keyboard focus is inside a text field (arrows move the caret).
  bool _isEditingText() {
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null) return false;
    return focused.widget is EditableText ||
        focused.findAncestorWidgetOfExactType<EditableText>() != null;
  }

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
            padding: const EdgeInsets.all(AppPadding.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Left: lyric input sidebar ──────────────────────────────────
                SizedBox(width: 320, child: const LyricInputPanel()),

                const SizedBox(width: AppSpacing.lg),

                // ── Center: presenter preview ────────────────────────────────
                Expanded(flex: 3, child: const PresenterPanel()),

                const SizedBox(width: AppSpacing.lg),

                // ── Right: style editor ──────────────────────────────────────
                SizedBox(width: 333, child: const EditorPanel()),
              ],
            ),
          ),
          const NdiOperatorView(),
        ],
      ),
    );
  }
}
