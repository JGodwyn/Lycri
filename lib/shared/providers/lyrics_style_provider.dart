import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the visual styling state for the lyrics presentation.
class LyricsStyleState {
  const LyricsStyleState({
    this.fontFamily = 'Libre Caslon Condensed',
    this.displayLines = 0, // 0 = Auto
  });

  /// The selected font family name.
  final String fontFamily;

  /// The number of lines to display at once (0 = Auto).
  final int displayLines;

  LyricsStyleState copyWith({String? fontFamily, int? displayLines}) {
    return LyricsStyleState(
      fontFamily: fontFamily ?? this.fontFamily,
      displayLines: displayLines ?? this.displayLines,
    );
  }
}

/// Provider for managing the [LyricsStyleState].
final lyricsStyleProvider =
    StateNotifierProvider<LyricsStyleNotifier, LyricsStyleState>((ref) {
      return LyricsStyleNotifier();
    });

class LyricsStyleNotifier extends StateNotifier<LyricsStyleState> {
  LyricsStyleNotifier() : super(const LyricsStyleState());

  /// Updates the font family used to render lyrics.
  void setFontFamily(String font) {
    if (state.fontFamily == font) return;
    state = state.copyWith(fontFamily: font);
  }

  /// Updates the number of lines to display.
  void setDisplayLines(int lines) {
    if (state.displayLines == lines) return;
    state = state.copyWith(displayLines: lines);
  }
}
