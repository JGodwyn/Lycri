import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'lyrics_style_provider.dart';

/// Provider for SharedPreferences instance.
/// Must be overridden in the ProviderScope.
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

/// Represents a recently used gradient.
class RecentGradient {
  final GradientType type;
  final List<Color> colors;

  RecentGradient({required this.type, required this.colors});

  Map<String, dynamic> toJson() => {
    'type': type.index,
    'colors': colors.map((c) => c.toARGB32()).toList(),
  };

  factory RecentGradient.fromJson(Map<String, dynamic> json) {
    return RecentGradient(
      type: GradientType.values[json['type'] as int],
      colors: (json['colors'] as List).map((c) => Color(c as int)).toList(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecentGradient &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          _listEquals(colors, other.colors);

  @override
  int get hashCode => type.hashCode ^ colors.hashCode;

  bool _listEquals(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// State for recently used backgrounds.
class RecentBackgroundsState {
  final List<Color> colors;
  final List<RecentGradient> gradients;
  final List<String> imagePaths;
  final List<String> videoPaths;

  RecentBackgroundsState({
    this.colors = const [],
    this.gradients = const [],
    this.imagePaths = const [],
    this.videoPaths = const [],
  });

  RecentBackgroundsState copyWith({
    List<Color>? colors,
    List<RecentGradient>? gradients,
    List<String>? imagePaths,
    List<String>? videoPaths,
  }) {
    return RecentBackgroundsState(
      colors: colors ?? this.colors,
      gradients: gradients ?? this.gradients,
      imagePaths: imagePaths ?? this.imagePaths,
      videoPaths: videoPaths ?? this.videoPaths,
    );
  }
}

/// Notifier to manage recently used backgrounds.
class RecentBackgroundsNotifier extends StateNotifier<RecentBackgroundsState> {
  final SharedPreferences _prefs;
  RecentBackgroundsNotifier(this._prefs) : super(RecentBackgroundsState()) {
    _loadFromPrefs();
  }

  static const String _keyColors = 'recent_colors';
  static const String _keyGradients = 'recent_gradients';
  static const String _keyImages = 'recent_images';
  static const String _keyVideos = 'recent_videos';
  static const int _maxItems = 6;

  void addColor(Color color) {
    final newColors = [color, ...state.colors.where((c) => c != color)];
    state = state.copyWith(colors: newColors.take(_maxItems).toList());
    _saveToPrefs();
  }

  void addGradient(GradientType type, List<Color> colors) {
    final newGradient = RecentGradient(type: type, colors: colors);
    final newGradients = [
      newGradient,
      ...state.gradients.where((g) => g != newGradient),
    ];
    state = state.copyWith(gradients: newGradients.take(_maxItems).toList());
    _saveToPrefs();
  }

  void addImagePath(String path) {
    final newPaths = [path, ...state.imagePaths.where((p) => p != path)];
    state = state.copyWith(imagePaths: newPaths.take(_maxItems).toList());
    _saveToPrefs();
  }

  void addVideoPath(String path) {
    final newPaths = [path, ...state.videoPaths.where((p) => p != path)];
    state = state.copyWith(videoPaths: newPaths.take(_maxItems).toList());
    _saveToPrefs();
  }

  void _loadFromPrefs() {
    final colorsList = _prefs.getStringList(_keyColors);
    final gradientsList = _prefs.getStringList(_keyGradients);
    final imagesList = _prefs.getStringList(_keyImages);
    final videosList = _prefs.getStringList(_keyVideos);

    state = RecentBackgroundsState(
      colors: colorsList?.map((c) => Color(int.parse(c))).toList() ?? const [],
      gradients:
          gradientsList
              ?.map((g) => RecentGradient.fromJson(jsonDecode(g)))
              .toList() ??
          const [],
      imagePaths: imagesList ?? const [],
      videoPaths: videosList ?? const [],
    );
  }

  void _saveToPrefs() {
    _prefs.setStringList(
      _keyColors,
      state.colors.map((c) => c.toARGB32().toString()).toList(),
    );
    _prefs.setStringList(
      _keyGradients,
      state.gradients.map((g) => jsonEncode(g.toJson())).toList(),
    );
    _prefs.setStringList(_keyImages, state.imagePaths);
    _prefs.setStringList(_keyVideos, state.videoPaths);
  }
}

final recentBackgroundsProvider =
    StateNotifierProvider<RecentBackgroundsNotifier, RecentBackgroundsState>((
      ref,
    ) {
      final prefs = ref.watch(sharedPrefsProvider);
      return RecentBackgroundsNotifier(prefs);
    });
