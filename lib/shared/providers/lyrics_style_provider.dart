import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'recent_backgrounds_provider.dart';

/// The type of background used for the presentation.
enum BackgroundType { solidColor, gradient, image, video }

/// The type of gradient to apply.
enum GradientType { linear, radial }


/// Holds the visual styling state for the lyrics presentation.
class LyricsStyleState {
  const LyricsStyleState({
    this.fontFamily = 'Libre Caslon Condensed',
    this.displayLines = -1, // -1 = Auto, 0 = All, > 0 = Paginated
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

  /// The number of lines to display at once (-1 = Auto, 0 = All).
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
      final prefs = ref.watch(sharedPrefsProvider);
      return LyricsStyleNotifier(prefs);
    });

class LyricsStyleNotifier extends StateNotifier<LyricsStyleState> {
  final SharedPreferences _prefs;

  LyricsStyleNotifier(this._prefs) : super(const LyricsStyleState()) {
    _loadFromPrefs();
  }

  static const String _keyFontFamily = 'style_fontFamily';
  static const String _keyDisplayLines = 'style_displayLines';
  static const String _keyTextAlign = 'style_textAlign';
  static const String _keyFontColor = 'style_fontColor';
  static const String _keyBackgroundType = 'style_backgroundType';
  static const String _keyGradientType = 'style_gradientType';
  static const String _keyBackgroundColor = 'style_backgroundColor';
  static const String _keyGradientColors = 'style_gradientColors';
  static const String _keyBackgroundImagePath = 'style_backgroundImagePath';
  static const String _keyBackgroundVideoPath = 'style_backgroundVideoPath';

  void _loadFromPrefs() {
    final fontFamily = _prefs.getString(_keyFontFamily);
    final displayLines = _prefs.getInt(_keyDisplayLines);
    final textAlignIdx = _prefs.getInt(_keyTextAlign);
    final fontColorValue = _prefs.getInt(_keyFontColor);
    final bgTypeIdx = _prefs.getInt(_keyBackgroundType);
    final gradTypeIdx = _prefs.getInt(_keyGradientType);
    final bgColorValue = _prefs.getInt(_keyBackgroundColor);
    final gradColorsList = _prefs.getStringList(_keyGradientColors);
    final bgImagePath = _prefs.getString(_keyBackgroundImagePath);
    final bgVideoPath = _prefs.getString(_keyBackgroundVideoPath);

    state = state.copyWith(
      fontFamily: fontFamily,
      displayLines: displayLines,
      textAlign: textAlignIdx != null ? TextAlign.values[textAlignIdx] : null,
      fontColor: fontColorValue != null ? Color(fontColorValue) : null,
      backgroundType: bgTypeIdx != null ? BackgroundType.values[bgTypeIdx] : null,
      gradientType: gradTypeIdx != null ? GradientType.values[gradTypeIdx] : null,
      backgroundColor: bgColorValue != null ? Color(bgColorValue) : null,
      gradientColors: gradColorsList?.map((c) => Color(int.parse(c))).toList(),
      backgroundImagePath: bgImagePath,
      backgroundVideoPath: bgVideoPath,
    );
  }

  void _saveToPrefs() {
    _prefs.setString(_keyFontFamily, state.fontFamily);
    _prefs.setInt(_keyDisplayLines, state.displayLines);
    _prefs.setInt(_keyTextAlign, state.textAlign.index);
    _prefs.setInt(_keyFontColor, state.fontColor.toARGB32());
    _prefs.setInt(_keyBackgroundType, state.backgroundType.index);
    _prefs.setInt(_keyGradientType, state.gradientType.index);
    _prefs.setInt(_keyBackgroundColor, state.backgroundColor.toARGB32());
    _prefs.setStringList(
      _keyGradientColors,
      state.gradientColors.map((c) => c.toARGB32().toString()).toList(),
    );
    if (state.backgroundImagePath != null) {
      _prefs.setString(_keyBackgroundImagePath, state.backgroundImagePath!);
    } else {
      _prefs.remove(_keyBackgroundImagePath);
    }
    if (state.backgroundVideoPath != null) {
      _prefs.setString(_keyBackgroundVideoPath, state.backgroundVideoPath!);
    } else {
      _prefs.remove(_keyBackgroundVideoPath);
    }
  }

  /// Updates the font family used to render lyrics.
  void setFontFamily(String font) {
    if (state.fontFamily == font) return;
    state = state.copyWith(fontFamily: font);
    _saveToPrefs();
  }

  /// Updates the number of lines to display.
  void setDisplayLines(int lines) {
    if (state.displayLines == lines) return;
    state = state.copyWith(displayLines: lines);
    _saveToPrefs();
  }

  /// Updates the text alignment.
  void setTextAlign(TextAlign align) {
    if (state.textAlign == align) return;
    state = state.copyWith(textAlign: align);
    _saveToPrefs();
  }

  /// Updates the font color.
  void setFontColor(Color color) {
    if (state.fontColor == color) return;
    state = state.copyWith(fontColor: color);
    _saveToPrefs();
  }

  /// Updates the background type.
  void setBackgroundType(BackgroundType type) {
    if (state.backgroundType == type) return;
    state = state.copyWith(backgroundType: type);
    _saveToPrefs();
  }

  /// Updates the gradient type.
  void setGradientType(GradientType type) {
    if (state.gradientType == type) return;
    state = state.copyWith(gradientType: type);
    _saveToPrefs();
  }

  /// Updates the solid background color.
  void setBackgroundColor(Color color) {
    if (state.backgroundColor == color) return;
    state = state.copyWith(backgroundColor: color);
    _saveToPrefs();
  }

  /// Updates the gradient colors.
  void setGradientColors(List<Color> colors) {
    state = state.copyWith(gradientColors: colors);
    _saveToPrefs();
  }

  /// Updates the background image path.
  void setBackgroundImagePath(String? path) {
    state = state.copyWith(
      backgroundImagePath: path,
      clearBackgroundImage: path == null,
    );
    _saveToPrefs();
  }

  /// Updates the background video path.
  void setBackgroundVideoPath(String? path) {
    state = state.copyWith(
      backgroundVideoPath: path,
      clearBackgroundVideo: path == null,
    );
    _saveToPrefs();
  }
}
