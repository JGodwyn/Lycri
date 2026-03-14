import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the visual styling state for the lyrics presentation.
class LyricsStyleState {
  const LyricsStyleState({
    this.fontFamily = 'Libre Caslon Condensed',
  });

  /// The selected font family name.
  final String fontFamily;

  LyricsStyleState copyWith({
    String? fontFamily,
  }) {
    return LyricsStyleState(
      fontFamily: fontFamily ?? this.fontFamily,
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
}
