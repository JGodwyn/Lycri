import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_retriever/screen_retriever.dart';

/// State for presentation-specific settings.
class PresentationSettingsState {
  const PresentationSettingsState({
    this.targetDisplayId,
    this.enableExternalScreen = true,
  });

  /// The ID of the display to use for presentation.
  /// If null, it defaults to the first available non-primary display.
  final int? targetDisplayId;

  /// Whether to attempt extending to an external screen.
  final bool enableExternalScreen;

  PresentationSettingsState copyWith({
    int? targetDisplayId,
    bool? enableExternalScreen,
    bool clearTargetDisplay = false,
  }) {
    return PresentationSettingsState(
      targetDisplayId: clearTargetDisplay ? null : (targetDisplayId ?? this.targetDisplayId),
      enableExternalScreen: enableExternalScreen ?? this.enableExternalScreen,
    );
  }
}

/// Notifier for managing presentation settings.
class PresentationSettingsNotifier extends StateNotifier<PresentationSettingsState> {
  PresentationSettingsNotifier() : super(const PresentationSettingsState());

  void setTargetDisplay(int? id) {
    state = state.copyWith(targetDisplayId: id, clearTargetDisplay: id == null);
  }

  void setEnableExternalScreen(bool enable) {
    state = state.copyWith(enableExternalScreen: enable);
  }
}

/// Provider for presentation settings.
final presentationSettingsProvider =
    StateNotifierProvider<PresentationSettingsNotifier, PresentationSettingsState>((ref) {
  return PresentationSettingsNotifier();
});

/// Provider that lists all available displays.
final screensProvider = FutureProvider<List<Display>>((ref) async {
  return await ScreenRetriever.instance.getAllDisplays();
});
