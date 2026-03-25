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
final displayModeProvider = StateProvider<DisplayOutput>(
  (ref) => DisplayOutput.thisDisplay(),
);

/// Provider that fetches all available displays.
final displaysProvider = FutureProvider<List<Display>>((ref) async {
  return await ScreenRetriever.instance.getAllDisplays();
});
