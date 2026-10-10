import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:lycri_lyrics/core/theme/app_typography.dart';
import 'package:lycri_lyrics/features/operator/providers/preset_state_provider.dart';
import 'recent_backgrounds_provider.dart';

/// The type of background used for the presentation.
///
/// [transparent] renders no background so the lyrics can be keyed over video:
/// NDI carries the alpha channel, the presentation window falls back to black.
/// New values go at the end — the index is persisted in prefs and presets.
enum BackgroundType { solidColor, gradient, image, video, transparent }

/// The type of gradient to apply.
enum GradientType { linear, radial }

/// Where the lyrics sit vertically on the output.
/// New values go at the end — the index is persisted in prefs and presets.
enum LyricsPosition {
  top,
  middle,
  bottom;

  /// Alignment of the lyric block within the output.
  Alignment get alignment => switch (this) {
    LyricsPosition.top => Alignment.topCenter,
    LyricsPosition.middle => Alignment.center,
    LyricsPosition.bottom => Alignment.bottomCenter,
  };

  /// Where the active line is held, as a fraction of the viewport height,
  /// when the lyrics overflow and scroll.
  double get scrollAnchor => switch (this) {
    LyricsPosition.top => 0.1,
    LyricsPosition.middle => 0.33,
    LyricsPosition.bottom => 0.55,
  };

  /// Top of a [band]-tall strip pinned at this position in a [viewport]-tall
  /// area, [margin] from the nearest edge (clipped continuous lyrics).
  double bandTop(double viewport, double band, double margin) => switch (this) {
    LyricsPosition.top => margin,
    LyricsPosition.middle => (viewport - band) / 2,
    LyricsPosition.bottom => viewport - margin - band,
  };
}

/// Lyric text size on the output.
/// New values go at the end — the index is persisted in prefs and presets.
enum LyricsSize {
  small,
  mid,
  big;

  /// Display style the lyric lines are set in (before any scale-down to fit).
  TextStyle get textStyle => switch (this) {
    LyricsSize.small => AppTypography.displaySm,
    LyricsSize.mid => AppTypography.displayMd,
    LyricsSize.big => AppTypography.displayLg,
  };
}

/// Colour of the readability overlay behind the lyrics.
/// New values go at the end — the index is persisted in prefs and presets.
enum LyricsOverlayTone { light, dark }

/// Holds the visual styling state for the lyrics presentation.
class LyricsStyleState {
  const LyricsStyleState({
    this.fontFamily = 'Advent Pro',
    this.displayLines = -1, // -1 = Auto, 0 = All, > 0 = Paginated
    this.textAlign = TextAlign.left,
    this.position = LyricsPosition.middle,
    this.size = LyricsSize.mid,
    this.clipped = true,
    this.overlay = false,
    this.overlayTone = LyricsOverlayTone.dark,
    this.overlayOpacity = 60,
    this.lineHeight = 40,
    this.textShadow = false,
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

  /// Vertical placement of the lyrics on the output.
  final LyricsPosition position;

  /// Lyric text size on the output.
  final LyricsSize size;

  /// Whether paging lyrics fade at the edges of the lyric block (true) or at
  /// the edges of the screen (false).
  final bool clipped;

  /// Whether a gradient overlay sits behind the lyrics (transparent
  /// background only), for readability over video.
  final bool overlay;

  /// Light or dark overlay.
  final LyricsOverlayTone overlayTone;

  /// Overlay strength where it's densest, in percent (0–100).
  final int overlayOpacity;

  /// Space between lyric lines as a percentage of the font size (10–100).
  final int lineHeight;

  /// Whether the lyrics get a soft drop shadow.
  final bool textShadow;

  /// Gap below each lyric line for the current size and [lineHeight].
  double get lineGap => size.textStyle.fontSize! * lineHeight / 100;

  /// Drop shadow for a lyric line whose text is at [textAlpha], so dimmed
  /// lines get a matching faint shadow. Empty when [textShadow] is off.
  /// [scale] shrinks it for a scaled-down rendering (the operator preview).
  List<Shadow> shadowFor(double textAlpha, {double scale = 1}) =>
      textShadow ? shadowAt(textAlpha, scale: scale) : const [];

  /// The lyric drop shadow under text at [textAlpha].
  static List<Shadow> shadowAt(double textAlpha, {double scale = 1}) => [
    Shadow(
      color: Color.fromRGBO(0, 0, 0, 0.5 * textAlpha),
      blurRadius: 16 * scale,
      offset: Offset(0, 4 * scale),
    ),
  ];

  /// The font color.
  final Color fontColor;

  /// The background type (solid color, gradient, image, video, or none).
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
    LyricsPosition? position,
    LyricsSize? size,
    bool? clipped,
    bool? overlay,
    LyricsOverlayTone? overlayTone,
    int? overlayOpacity,
    int? lineHeight,
    bool? textShadow,
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
      position: position ?? this.position,
      size: size ?? this.size,
      clipped: clipped ?? this.clipped,
      overlay: overlay ?? this.overlay,
      overlayTone: overlayTone ?? this.overlayTone,
      overlayOpacity: overlayOpacity ?? this.overlayOpacity,
      lineHeight: lineHeight ?? this.lineHeight,
      textShadow: textShadow ?? this.textShadow,
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
      return LyricsStyleNotifier(prefs, ref);
    });

class LyricsStyleNotifier extends StateNotifier<LyricsStyleState> {
  final SharedPreferences _prefs;
  final Ref _ref;
  bool _isApplyingPreset = false;

  LyricsStyleNotifier(this._prefs, this._ref)
    : super(const LyricsStyleState()) {
    _loadFromPrefs();
  }

  static const String _keyFontFamily = 'style_fontFamily';
  static const String _keyDisplayLines = 'style_displayLines';
  static const String _keyTextAlign = 'style_textAlign';
  static const String _keyPosition = 'style_position';
  static const String _keySize = 'style_size';
  static const String _keyClipped = 'style_clipped';
  static const String _keyOverlay = 'style_overlay';
  static const String _keyOverlayTone = 'style_overlayTone';
  static const String _keyOverlayOpacity = 'style_overlayOpacity';
  static const String _keyLineHeight = 'style_lineHeight';
  static const String _keyTextShadow = 'style_textShadow';
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
    final positionIdx = _prefs.getInt(_keyPosition);
    final sizeIdx = _prefs.getInt(_keySize);
    final clipped = _prefs.getBool(_keyClipped);
    final overlay = _prefs.getBool(_keyOverlay);
    final overlayToneIdx = _prefs.getInt(_keyOverlayTone);
    final overlayOpacity = _prefs.getInt(_keyOverlayOpacity);
    final lineHeight = _prefs.getInt(_keyLineHeight);
    final textShadow = _prefs.getBool(_keyTextShadow);
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
      position: positionIdx != null ? LyricsPosition.values[positionIdx] : null,
      size: sizeIdx != null ? LyricsSize.values[sizeIdx] : null,
      clipped: clipped,
      overlay: overlay,
      overlayTone:
          overlayToneIdx != null
              ? LyricsOverlayTone.values[overlayToneIdx]
              : null,
      overlayOpacity: overlayOpacity,
      lineHeight: lineHeight,
      textShadow: textShadow,
      fontColor: fontColorValue != null ? Color(fontColorValue) : null,
      backgroundType:
          bgTypeIdx != null ? BackgroundType.values[bgTypeIdx] : null,
      gradientType:
          gradTypeIdx != null ? GradientType.values[gradTypeIdx] : null,
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
    _prefs.setInt(_keyPosition, state.position.index);
    _prefs.setInt(_keySize, state.size.index);
    _prefs.setBool(_keyClipped, state.clipped);
    _prefs.setBool(_keyOverlay, state.overlay);
    _prefs.setInt(_keyOverlayTone, state.overlayTone.index);
    _prefs.setInt(_keyOverlayOpacity, state.overlayOpacity);
    _prefs.setInt(_keyLineHeight, state.lineHeight);
    _prefs.setBool(_keyTextShadow, state.textShadow);
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

    if (!_isApplyingPreset) {
      _ref.read(presetStateProvider.notifier).markDirty();
    }
  }

  void applyPresetData(String data) {
    _isApplyingPreset = true;
    try {
      final map = jsonDecode(data);
      final fontFamily = map['fontFamily'] as String?;
      final displayLines = map['displayLines'] as int?;
      final textAlignIdx = map['textAlign'] as int?;
      // Presets saved before positions existed default to middle.
      final positionIdx =
          (map['position'] as int?) ?? LyricsPosition.middle.index;
      // Likewise for size and clipping: the defaults.
      final sizeIdx = (map['size'] as int?) ?? LyricsSize.mid.index;
      final clipped = (map['clipped'] as bool?) ?? true;
      final overlay = (map['overlay'] as bool?) ?? false;
      final overlayToneIdx =
          (map['overlayTone'] as int?) ?? LyricsOverlayTone.dark.index;
      final overlayOpacity = (map['overlayOpacity'] as int?) ?? 60;
      final lineHeight = (map['lineHeight'] as int?) ?? 40;
      final textShadow = (map['textShadow'] as bool?) ?? false;
      final fontColorValue = map['fontColor'] as int?;
      final bgTypeIdx = map['backgroundType'] as int?;
      final gradTypeIdx = map['gradientType'] as int?;
      final bgColorValue = map['backgroundColor'] as int?;
      final gradColorsList =
          (map['gradientColors'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList();
      final bgImagePath = map['backgroundImagePath'] as String?;
      final bgVideoPath = map['backgroundVideoPath'] as String?;

      state = state.copyWith(
        fontFamily: fontFamily,
        displayLines: displayLines,
        textAlign: textAlignIdx != null ? TextAlign.values[textAlignIdx] : null,
        position: LyricsPosition.values[positionIdx],
        size: LyricsSize.values[sizeIdx],
        clipped: clipped,
        overlay: overlay,
        overlayTone: LyricsOverlayTone.values[overlayToneIdx],
        overlayOpacity: overlayOpacity,
        lineHeight: lineHeight,
        textShadow: textShadow,
        fontColor: fontColorValue != null ? Color(fontColorValue) : null,
        backgroundType:
            bgTypeIdx != null ? BackgroundType.values[bgTypeIdx] : null,
        gradientType:
            gradTypeIdx != null ? GradientType.values[gradTypeIdx] : null,
        backgroundColor: bgColorValue != null ? Color(bgColorValue) : null,
        gradientColors: gradColorsList?.map((c) => Color(c)).toList(),
        backgroundImagePath: bgImagePath,
        clearBackgroundImage: bgImagePath == null,
        backgroundVideoPath: bgVideoPath,
        clearBackgroundVideo: bgVideoPath == null,
      );
      _saveToPrefs();
    } finally {
      _isApplyingPreset = false;
    }
  }

  String exportPresetData() {
    return jsonEncode({
      'fontFamily': state.fontFamily,
      'displayLines': state.displayLines,
      'textAlign': state.textAlign.index,
      'position': state.position.index,
      'size': state.size.index,
      'clipped': state.clipped,
      'overlay': state.overlay,
      'overlayTone': state.overlayTone.index,
      'overlayOpacity': state.overlayOpacity,
      'lineHeight': state.lineHeight,
      'textShadow': state.textShadow,
      'fontColor': state.fontColor.toARGB32(),
      'backgroundType': state.backgroundType.index,
      'gradientType': state.gradientType.index,
      'backgroundColor': state.backgroundColor.toARGB32(),
      'gradientColors': state.gradientColors.map((c) => c.toARGB32()).toList(),
      'backgroundImagePath': state.backgroundImagePath,
      'backgroundVideoPath': state.backgroundVideoPath,
    });
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

  /// Updates the lyric text size.
  void setSize(LyricsSize size) {
    if (state.size == size) return;
    state = state.copyWith(size: size);
    _saveToPrefs();
  }

  /// Sets whether paging lyrics fade at the lyric block's edges.
  void setClipped(bool clipped) {
    if (state.clipped == clipped) return;
    state = state.copyWith(clipped: clipped);
    _saveToPrefs();
  }

  /// Turns the readability overlay on or off.
  void setOverlay(bool overlay) {
    if (state.overlay == overlay) return;
    state = state.copyWith(overlay: overlay);
    _saveToPrefs();
  }

  /// Sets the overlay to light or dark.
  void setOverlayTone(LyricsOverlayTone tone) {
    if (state.overlayTone == tone) return;
    state = state.copyWith(overlayTone: tone);
    _saveToPrefs();
  }

  /// Sets the overlay strength (percent, clamped to 0–100).
  void setOverlayOpacity(int percent) {
    final v = percent.clamp(0, 100);
    if (state.overlayOpacity == v) return;
    state = state.copyWith(overlayOpacity: v);
    _saveToPrefs();
  }

  /// Sets the space between lyric lines (percent, clamped to 10–100).
  void setLineHeight(int percent) {
    final v = percent.clamp(10, 100);
    if (state.lineHeight == v) return;
    state = state.copyWith(lineHeight: v);
    _saveToPrefs();
  }

  /// Turns the lyric drop shadow on or off.
  void setTextShadow(bool on) {
    if (state.textShadow == on) return;
    state = state.copyWith(textShadow: on);
    _saveToPrefs();
  }

  /// Updates the vertical position of the lyrics.
  void setPosition(LyricsPosition position) {
    if (state.position == position) return;
    state = state.copyWith(position: position);
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
