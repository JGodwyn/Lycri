import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks the last directory the user navigated to in a file picker dialog,
/// so subsequent picker invocations open in the same folder.
///
/// After a successful pick, call [update] with the full file path — the
/// provider will extract and store just the parent directory.
final lastPickerDirectoryProvider =
    StateNotifierProvider<LastPickerDirectoryNotifier, String?>((ref) {
  return LastPickerDirectoryNotifier();
});

class LastPickerDirectoryNotifier extends StateNotifier<String?> {
  LastPickerDirectoryNotifier() : super(null);

  /// Call with the full path of a picked file.
  /// Stores the parent directory for next time.
  void update(String filePath) {
    state = File(filePath).parent.path;
  }
}
