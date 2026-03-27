import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_retriever/screen_retriever.dart';

/// The type of output for the presentation window.
enum DisplayType { thisDisplay, external, ndi }

/// Model representing a selected display output.
class DisplayOutput {
  final DisplayType type;
  final Display? display;

  DisplayOutput({required this.type, this.display});

  factory DisplayOutput.thisDisplay() =>
      DisplayOutput(type: DisplayType.thisDisplay);
  factory DisplayOutput.ndi() => DisplayOutput(type: DisplayType.ndi);
  factory DisplayOutput.external(Display display) =>
      DisplayOutput(type: DisplayType.external, display: display);

  String get label {
    switch (type) {
      case DisplayType.thisDisplay:
        return 'This display';
      case DisplayType.ndi:
        return 'NDI';
      case DisplayType.external:
        return display?.name ?? 'External Display';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DisplayOutput &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          display?.id == other.display?.id;

  @override
  int get hashCode => type.hashCode ^ (display?.id.hashCode ?? 0);
}

/// Provider that holds the currently-selected [DisplayOutput].
/// Automatically falls back to 'thisDisplay' if a selected external display is disconnected.
final StateProvider<DisplayOutput> displayModeProvider =
    StateProvider<DisplayOutput>((ref) {
  // Listen to common monitor changes to ensure selection remains valid.
  ref.listen(displaysProvider, (prev, next) {
    next.whenData((displays) {
      final current = ref.read(displayModeProvider.notifier).state;
      if (current.type == DisplayType.external && current.display != null) {
        // Check if the selected display is still in the list.
        final exists = displays.any((d) => d.id == current.display!.id);
        if (!exists) {
          // Fall back gracefully.
          ref.read(displayModeProvider.notifier).state =
              DisplayOutput.thisDisplay();
        }
      }
    });
  });

  return DisplayOutput.thisDisplay();
});

/// Provider that fetches all available displays and updates via native notifications.
final displaysProvider = FutureProvider<List<Display>>((ref) async {
  // Use custom native channel for real-time plug/unplug events because
  // screen_retriever@0.1.9 on macOS doesn't currently emit events.
  const eventChannel = MethodChannel('lycri/system_events');

  // Register only if it's the first time this provider is initialized.
  // We keep the listener alive locally to the provider.
  eventChannel.setMethodCallHandler((call) async {
    if (call.method == 'onScreensChanged') {
      // Re-trigger the future to fetch new display list.
      ref.invalidateSelf();
    }
  });

  ref.onDispose(() {
    eventChannel.setMethodCallHandler(null);
  });

  return await ScreenRetriever.instance.getAllDisplays();
});
