import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The type of background used for the presentation.
enum BackgroundType { solidColor, gradient, image, video }

/// The type of gradient to apply.
enum GradientType { linear, radial }


/// Holds the visual styling state for the lyrics presentation.
class LyricsStyleState {
  const LyricsStyleState({
    this.fontFamily = 'Libre Caslon Condensed',
    this.displayLines = 0, // 0 = Auto
    this.textAlign = TextAlign.left,
    this.fontColor = const Color(0xFF000000), // Default to purely black
    this.backgroundType = BackgroundType.solidColor,
    this.gradientType = GradientType.linear,
    this.backgroundColor = const Color(0xFFFFFFFF),
    this.gradientColors = const [Color(0xFFFFFFFF), Color(0xFF000000)],

    this.backgroundImagePath,
    this.backgroundVideoPath,
  });

  /// The selected font family name.
  final String fontFamily;

  /// The number of lines to display at once (0 = Auto).
  final int displayLines;

  /// The text alignment.
  final TextAlign textAlign;

  /// The font color.
  final Color fontColor;

  /// The background type (solid color, gradient, image, or video).
  final BackgroundType backgroundType;

  /// The type of gradient (linear or radial).
  final GradientType gradientType;


  /// Solid background color.
  final Color backgroundColor;

  /// Gradient colors (start → end).
  final List<Color> gradientColors;

  /// File path for background image.
  final String? backgroundImagePath;

  /// File path for background video.
  final String? backgroundVideoPath;

  LyricsStyleState copyWith({
    String? fontFamily,
    int? displayLines,
    TextAlign? textAlign,
    Color? fontColor,
    BackgroundType? backgroundType,
    GradientType? gradientType,
    Color? backgroundColor,
    List<Color>? gradientColors,
    String? backgroundImagePath,
    bool clearBackgroundImage = false,
    String? backgroundVideoPath,
    bool clearBackgroundVideo = false,
  }) {
    return LyricsStyleState(
      fontFamily: fontFamily ?? this.fontFamily,
      displayLines: displayLines ?? this.displayLines,
      textAlign: textAlign ?? this.textAlign,
      fontColor: fontColor ?? this.fontColor,
      backgroundType: backgroundType ?? this.backgroundType,
      gradientType: gradientType ?? this.gradientType,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      gradientColors: gradientColors ?? this.gradientColors,
      backgroundImagePath:
          clearBackgroundImage
              ? null
              : (backgroundImagePath ?? this.backgroundImagePath),
      backgroundVideoPath:
          clearBackgroundVideo
              ? null
              : (backgroundVideoPath ?? this.backgroundVideoPath),
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

  /// Updates the text alignment.
  void setTextAlign(TextAlign align) {
    if (state.textAlign == align) return;
    state = state.copyWith(textAlign: align);
  }

  /// Updates the font color.
  void setFontColor(Color color) {
    if (state.fontColor == color) return;
    state = state.copyWith(fontColor: color);
  }

  /// Updates the background type.
  void setBackgroundType(BackgroundType type) {
    if (state.backgroundType == type) return;
    state = state.copyWith(backgroundType: type);
  }

  /// Updates the gradient type.
  void setGradientType(GradientType type) {
    if (state.gradientType == type) return;
    state = state.copyWith(gradientType: type);
  }


  /// Updates the solid background color.
  void setBackgroundColor(Color color) {
    if (state.backgroundColor == color) return;
    state = state.copyWith(backgroundColor: color);
  }

  /// Updates the gradient colors.
  void setGradientColors(List<Color> colors) {
    state = state.copyWith(gradientColors: colors);
  }

  /// Updates the background image path.
  void setBackgroundImagePath(String? path) {
    state = state.copyWith(
      backgroundImagePath: path,
      clearBackgroundImage: path == null,
    );
  }


  /// Updates the background video path.
  void setBackgroundVideoPath(String? path) {
    state = state.copyWith(
      backgroundVideoPath: path,
      clearBackgroundVideo: path == null,
    );
  }

}
