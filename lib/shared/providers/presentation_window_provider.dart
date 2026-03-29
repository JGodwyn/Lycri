import 'dart:convert';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_retriever/screen_retriever.dart';
import '../../core/ndi/ndi_service.dart';
import 'display_mode_provider.dart';
import 'lyrics_style_provider.dart';

/// Tracks whether the presentation window is live and manages its lifecycle.
///
/// The presentation window is a separate Flutter engine sub-window created
/// by [desktop_multi_window]. Communication uses [WindowMethodChannel]
/// on the 'lycri/presentation' channel.
final presentationWindowProvider =
    StateNotifierProvider<PresentationWindowNotifier, bool>(
      (ref) => PresentationWindowNotifier(ref),
    );

class PresentationWindowNotifier extends StateNotifier<bool> {
  PresentationWindowNotifier(this.ref) : super(false);

  final Ref ref;
  WindowController? _controller;
  bool _isLaunching = false;
  num? _lastDisplayId;

  /// Open the presentation window.
  ///
  /// Behaviour depends on the currently selected [DisplayOutputMode]:
  ///
  /// - [DisplayOutputMode.thisDisplay] → opens a windowed (non-fullscreen)
  ///   overlay on the **primary** display. Useful for debugging/preview.
  /// - [DisplayOutputMode.extend] → positions the window fullscreen on the
  ///   **secondary** display (like EasyWorship / ProPresenter).
  /// - [DisplayOutputMode.ndi] → activates the NDI offscreen renderer and starts streaming.
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
    if (state || _isLaunching) return; // Already live or busy starting.
    _isLaunching = true;

    final displayOutput = ref.read(displayModeProvider);

    if (displayOutput.type == DisplayType.ndi) {
      await ref.read(ndiServiceProvider.notifier).startStreaming();
      state = true;
      _isLaunching = false;
      return;
    }

    try {
      // ── Determine which display to use ──────────────────────────────────
      final displays = await ScreenRetriever.instance.getAllDisplays();

      Display targetDisplay;
      bool goFullScreen;

      if (displayOutput.type == DisplayType.external) {
        // Use the specific display selected by the user.
        targetDisplay =
            displayOutput.display ??
            (displays.length > 1 ? displays[1] : displays[0]);
        goFullScreen = true;
      } else {
        // thisDisplay — always primary. Opens as a non-fullscreen debug preview.
        targetDisplay = displays[0];
        goFullScreen = false;
      }

      // ── Build window arguments ──────────────────────────────────────────
      final Map<String, dynamic> windowArguments = {
        'type': 'presentation',
        'displayMode': displayOutput.type.index,
        'goFullScreen': goFullScreen,
        'targetDisplay': {
          'x': targetDisplay.visiblePosition?.dx ?? 0.0,
          'y': targetDisplay.visiblePosition?.dy ?? 0.0,
          'width': targetDisplay.size.width,
          'height': targetDisplay.size.height,
        },
        // Initial Style Data
        'fontFamily': fontFamily,
        'displayLines': displayLines,
        'textAlign': textAlign.index,
        'fontColor': fontColor.value.toRadixString(16),
        'backgroundColor': backgroundColor.value.toRadixString(16),
        'backgroundType': backgroundType.index,
        'gradientType': gradientType.index,
        'gradientColors': gradientColors.map((c) => c.value.toRadixString(16)).toList(),
        'backgroundImagePath': backgroundImagePath,
        'backgroundVideoPath': backgroundVideoPath,
        // Initial Content
        'lyrics': lyrics,
        'activeLine': activeLine,
      };

      bool displayChanged = false;
      if (_lastDisplayId != null && _lastDisplayId != targetDisplay.id) {
        displayChanged = true;
      }
      _lastDisplayId = targetDisplay.id;

      if (_controller != null) {
        if (displayChanged) {
          try {
            await _controller!.invokeMethod('closeWindow');
          } catch (_) {}
          _controller = null; // Force window recreation for the new display
        } else {
          // Try re-configuring the existing window.
          try {
            await _controller!.invokeMethod('setupWindow', windowArguments);
          } catch (_) {
            // If update fails, the window might have been closed by the user.
            _controller = null;
          }
        }
      }

      if (_controller == null) {
        _controller = await WindowController.create(
          WindowConfiguration(
            arguments: jsonEncode(windowArguments),
            hiddenAtLaunch: true,
          ),
        );
      }

      // Show the window once everything is ready.
      await _controller!.show();
      state = true;
    } catch (e) {
      state = false;
      _controller = null;
      debugPrint('Failed to go live: $e');
    } finally {
      _isLaunching = false;
    }
  }

  /// Hide the presentation window (End Live).
  Future<void> endLive() async {
    if (!state) return;

    if (ref.read(ndiServiceProvider)) {
      ref.read(ndiServiceProvider.notifier).stopStreaming();
    }

    if (_controller != null) {
      try {
        await _controller!.hide();
      } catch (_) {
        // Window may already be closed.
      }
    }
    // Keep _controller around so we can re-show on next goLive.
    state = false;
  }

  /// Send updated font family to the presentation window.
  Future<void> syncFontFamily(String font) async {
    if (_controller == null) return;
    try {
      await _controller!.invokeMethod('updateFontFamily', font);
    } catch (e) {
      _handleChannelError(e);
    }
  }

  /// Send updated display lines count to the presentation window.
  Future<void> syncDisplayLines(int lines) async {
    if (_controller == null) return;
    try {
      await _controller!.invokeMethod('updateDisplayLines', lines);
    } catch (e) {
      _handleChannelError(e);
    }
  }

  /// Send updated text alignment to the presentation window.
  Future<void> syncTextAlign(TextAlign align) async {
    if (_controller == null) return;
    try {
      await _controller!.invokeMethod('updateTextAlign', align.index);
    } catch (e) {
      _handleChannelError(e);
    }
  }

  /// Send updated font color to the presentation window.
  Future<void> syncFontColor(Color color) async {
    if (_controller == null) return;
    try {
      await _controller!.invokeMethod('updateFontColor', color.value);
    } catch (e) {
      _handleChannelError(e);
    }
  }

  /// Send updated background color to the presentation window.
  Future<void> syncBackgroundColor(Color color) async {
    if (_controller == null) return;
    try {
      await _controller!.invokeMethod('updateBackgroundColor', color.toARGB32());
    } catch (e) {
      _handleChannelError(e);
    }
  }

  /// Send updated background type to the presentation window.
  Future<void> syncBackgroundType(BackgroundType type) async {
    if (_controller == null) return;
    try {
      await _controller!.invokeMethod('updateBackgroundType', type.index);
    } catch (e) {
      _handleChannelError(e);
    }
  }

  /// Send updated gradient type to the presentation window.
  Future<void> syncGradientType(GradientType type) async {
    if (_controller == null) return;
    try {
      await _controller!.invokeMethod('updateGradientType', type.index);
    } catch (e) {
      _handleChannelError(e);
    }
  }

  /// Send updated gradient colors to the presentation window.
  Future<void> syncGradientColors(List<Color> colors) async {
    if (_controller == null) return;
    try {
      final colorValues = colors.map((c) => c.toARGB32()).toList();
      await _controller!.invokeMethod('updateGradientColors', colorValues);
    } catch (e) {
      _handleChannelError(e);
    }
  }

  /// Send updated background image path to the presentation window.
  Future<void> syncBackgroundImagePath(String? path) async {
    if (_controller == null) return;
    try {
      await _controller!.invokeMethod('updateBackgroundImagePath', path);
    } catch (e) {
      _handleChannelError(e);
    }
  }

  /// Send updated background video path to the presentation window.
  Future<void> syncBackgroundVideoPath(String? path) async {
    if (_controller == null) return;
    try {
      await _controller!.invokeMethod('updateBackgroundVideoPath', path);
    } catch (e) {
      _handleChannelError(e);
    }
  }

  /// Toggle lyrics opacity on the presentation window.
  Future<void> syncLyricsVisibility(bool visible) async {
    if (_controller == null) return;
    try {
      await _controller!.invokeMethod('updateLyricsVisibility', visible);
    } catch (e) {
      _handleChannelError(e);
    }
  }

  /// Send updated lyrics text to the presentation window.
  Future<void> syncLyrics(String? text, {int? activeLine}) async {
    if (_controller == null) return;
    try {
      await _controller!.invokeMethod('updateLyrics', {
        'text': text,
        if (activeLine != null) 'activeLine': activeLine,
      });
    } catch (e) {
      _handleChannelError(e);
    }
  }

  /// Send the active line index to the presentation window.
  Future<void> syncActiveLine(int index) async {
    if (_controller == null) return;
    try {
      await _controller!.invokeMethod('updateActiveLine', index);
    } catch (e) {
      _handleChannelError(e);
    }
  }

  /// Detects if the sub-window channel throws an error.
  void _handleChannelError(dynamic e) {
    debugPrint('Presentation channel error: $e');
    // Transient errors (like CHANNEL_UNREGISTERED during engine startup)
    // shouldn't destroy the active state. The window is chromeless, so users
    // cannot manually close it.
  }

  @override
  void dispose() {
    endLive();
    super.dispose();
  }
}
