import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks the zero-based index of the currently active (highlighted) lyric line.
///
/// Both the [PresenterPanel] arrow buttons and the preview area observe this
/// provider to coordinate navigation and visual highlighting (per SKILL.md
/// Rule 3: features communicate through shared providers only).
final activeLineProvider = StateNotifierProvider<ActiveLineNotifier, int>(
  (ref) => ActiveLineNotifier(),
);

class ActiveLineNotifier extends StateNotifier<int> {
  ActiveLineNotifier() : super(0);

  /// Advance to the next line. Clamps at [maxIndex] (last line).
  void next(int maxIndex) {
    if (state < maxIndex) state = state + 1;
  }

  /// Go back to the previous line. Clamps at 0.
  void previous() {
    if (state > 0) state = state - 1;
  }

  /// Reset to the first line (e.g. when lyrics are first set or cleared).
  void reset() => state = 0;

  /// Clamp the index to [maxIndex] if it exceeds the current line count
  /// (e.g. when lines are deleted during an edit).
  void clampTo(int maxIndex) {
    if (state > maxIndex) state = maxIndex;
  }

  /// Jump directly to [index] (e.g. when a line is tapped).
  void jumpTo(int index) => state = index;
}
