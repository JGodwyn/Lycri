import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared lyrics state — `null` means no lyrics sent yet,
/// a non-null [String] means lyrics are active and should be displayed.
///
/// Both the [LyricInputPanel] and [PresenterPanel] observe this provider
/// to coordinate their views (per SKILL.md Rule 3: features communicate
/// through shared providers only).
final lyricsProvider = StateNotifierProvider<LyricsNotifier, String?>(
  (ref) => LyricsNotifier(),
);

class LyricsNotifier extends StateNotifier<String?> {
  LyricsNotifier() : super(null);

  /// Send lyrics text to the presenter. Trims whitespace.
  void send(String text) {
    final trimmed = text.trim();
    if (trimmed.isNotEmpty) state = trimmed;
  }

  /// Live-update the lyrics text (used when editing in input mode).
  void update(String text) {
    final trimmed = text.trim();
    state = trimmed.isEmpty ? null : trimmed;
  }

  /// Clear lyrics and return to empty state.
  void clear() => state = null;
}
