import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'lyrics_style_provider.dart';

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
  Future<void> goLive(
    String? lyrics,
    int activeLine,
    String fontFamily,
    int displayLines,
    TextAlign textAlign,
    Color fontColor,
    Color backgroundColor,
    BackgroundType backgroundType,
    GradientType gradientType,
    List<Color> gradientColors,
    String? backgroundImagePath,
    String? backgroundVideoPath,
  ) async {




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
      await syncFontFamily(fontFamily);
      await syncDisplayLines(displayLines);
      await syncTextAlign(textAlign);
      await syncFontColor(fontColor);
      await syncBackgroundColor(backgroundColor);
      await syncBackgroundType(backgroundType);
      await syncGradientType(gradientType);
      await syncGradientColors(gradientColors);
      await syncBackgroundImagePath(backgroundImagePath);
      await syncBackgroundVideoPath(backgroundVideoPath);



      if (lyrics != null && lyrics.trim().isNotEmpty) {
        await syncLyrics(lyrics, activeLine: activeLine);
      } else {
        await syncActiveLine(activeLine);
      }


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

  /// Send updated font family to the presentation window.
  Future<void> syncFontFamily(String font) async {
    if (!state || _controller == null) return;
    try {
      await _channel.invokeMethod('updateFontFamily', font);
    } catch (_) {
      // Silently ignore if the presentation window is not ready yet.
    }
  }

  /// Send updated display lines count to the presentation window.
  Future<void> syncDisplayLines(int lines) async {
    if (!state || _controller == null) return;
    try {
      await _channel.invokeMethod('updateDisplayLines', lines);
    } catch (_) {
      // Silently ignore.
    }
  }

  /// Send updated text alignment to the presentation window.
  Future<void> syncTextAlign(TextAlign align) async {
    if (!state || _controller == null) return;
    try {
      await _channel.invokeMethod('updateTextAlign', align.index);
    } catch (_) {
      // Silently ignore.
    }
  }

  /// Send updated font color to the presentation window.
  Future<void> syncFontColor(Color color) async {
    if (!state || _controller == null) return;
    try {
      await _channel.invokeMethod('updateFontColor', color.value);
    } catch (_) {
      // Silently ignore.
    }
  }

  /// Send updated background color to the presentation window.
  Future<void> syncBackgroundColor(Color color) async {
    if (!state || _controller == null) return;
    try {
      await _channel.invokeMethod('updateBackgroundColor', color.toARGB32());
    } catch (_) {
      // Silently ignore.
    }
  }

  /// Send updated background type to the presentation window.
  Future<void> syncBackgroundType(BackgroundType type) async {
    if (!state || _controller == null) return;
    try {
      await _channel.invokeMethod('updateBackgroundType', type.index);
    } catch (_) {
      // Silently ignore.
    }
  }

  /// Send updated gradient type to the presentation window.
  Future<void> syncGradientType(GradientType type) async {
    if (!state || _controller == null) return;
    try {
      await _channel.invokeMethod('updateGradientType', type.index);
    } catch (_) {
      // Silently ignore.
    }
  }


  /// Send updated gradient colors to the presentation window.
  Future<void> syncGradientColors(List<Color> colors) async {
    if (!state || _controller == null) return;
    try {
      final colorValues = colors.map((c) => c.toARGB32()).toList();
      await _channel.invokeMethod('updateGradientColors', colorValues);
    } catch (_) {
      // Silently ignore.
    }
  }

  /// Send updated background image path to the presentation window.
  Future<void> syncBackgroundImagePath(String? path) async {
    if (!state || _controller == null) return;
    try {
      await _channel.invokeMethod('updateBackgroundImagePath', path);
    } catch (_) {
      // Silently ignore.
    }
  }

  /// Send updated background video path to the presentation window.
  Future<void> syncBackgroundVideoPath(String? path) async {
    if (!state || _controller == null) return;
    try {
      await _channel.invokeMethod('updateBackgroundVideoPath', path);
    } catch (_) {
      // Silently ignore.
    }
  }


  /// Send updated lyrics text to the presentation window.

  Future<void> syncLyrics(String? text, {int? activeLine}) async {
    if (!state || _controller == null) return;
    try {
      await _channel.invokeMethod('updateLyrics', {
        'text': text,
        if (activeLine != null) 'activeLine': activeLine,
      });
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
