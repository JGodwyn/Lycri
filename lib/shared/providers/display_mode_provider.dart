import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The output mode the operator has chosen for the presentation window.
///
/// - [thisDisplay]  → opens a windowed overlay on the primary display (debug/preview).
/// - [extend]       → goes fullscreen on the secondary (connected) display.
/// - [ndi]          → streams via NDI (not yet implemented; shows a notice).
enum DisplayOutputMode { thisDisplay, extend, ndi }

/// Provider that holds the currently-selected [DisplayOutputMode].
/// Updated by [_ScreenSelector] in the presenter panel.
final displayModeProvider = StateProvider<DisplayOutputMode>(
  (ref) => DisplayOutputMode.thisDisplay,
);
