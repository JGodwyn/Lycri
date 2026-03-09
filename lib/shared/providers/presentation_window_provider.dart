import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_retriever/screen_retriever.dart';

/// Tracks whether the presentation window is live and manages its lifecycle.
///
/// The presentation window is a separate Flutter engine sub-window created
/// by [desktop_multi_window]. Communication uses [WindowMethodChannel]
/// on the 'lycri/presentation' channel.
final presentationWindowProvider =
    StateNotifierProvider<PresentationWindowNotifier, bool>(
      (ref) => PresentationWindowNotifier(),
    );

class PresentationWindowNotifier extends StateNotifier<bool> {
  PresentationWindowNotifier() : super(false);

  WindowController? _controller;

  /// Channel name matches the one in [PresentationScreenPage].
  static const _channel = WindowMethodChannel(
    'lycri/presentation',
    mode: ChannelMode.unidirectional,
  );

  /// Open the presentation window.
  ///
  /// If a secondary display is connected, the window is positioned full-screen
  /// on it. Otherwise it opens centered on the primary display.
  /// If the window was previously hidden (End Live), it is re-shown.
  Future<void> goLive(String? lyrics) async {
    if (state) return; // Already live.

    try {
      if (_controller != null) {
        // Try re-showing the previously hidden sub-window.
        try {
          await _controller!.show();
        } catch (_) {
          // Window was closed by the user — controller is stale.
          _controller = null;
        }
      }

      if (_controller == null) {
        // Create a fresh sub-window.
        _controller = await WindowController.create(
          const WindowConfiguration(
            arguments: 'presentation',
            hiddenAtLaunch: true,
          ),
        );

        // Detect displays via screen_retriever.
        final displays = await ScreenRetriever.instance.getAllDisplays();
        final secondary = displays.length > 1 ? displays[1] : null;

        if (secondary != null) {
          // TODO: Position window on secondary display. Will be refined
          // once window_manager control in sub-windows is set up.
        }

        await _controller!.show();
      }

      state = true;

      // Send / re-sync lyrics and active line.
      if (lyrics != null && lyrics.trim().isNotEmpty) {
        await syncLyrics(lyrics);
      }
      await syncActiveLine(0);
    } catch (e) {
      state = false;
      _controller = null;
      rethrow;
    }
  }

  /// Hide the presentation window (End Live).
  Future<void> endLive() async {
    if (!state || _controller == null) return;

    try {
      await _controller!.hide();
    } catch (_) {
      // Window may already be closed.
    }
    // Keep _controller around so we can re-show on next goLive.
    state = false;
  }

  /// Send updated lyrics text to the presentation window.
  Future<void> syncLyrics(String? text) async {
    if (!state || _controller == null) return;
    try {
      await _channel.invokeMethod('updateLyrics', text);
    } catch (_) {
      // Silently ignore if the presentation window is not ready yet.
    }
  }

  /// Send the active line index to the presentation window.
  Future<void> syncActiveLine(int index) async {
    if (!state || _controller == null) return;
    try {
      await _channel.invokeMethod('updateActiveLine', index);
    } catch (_) {
      // Silently ignore if the presentation window is not ready yet.
    }
  }

  @override
  void dispose() {
    endLive();
    super.dispose();
  }
}
