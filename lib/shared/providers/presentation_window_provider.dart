import 'dart:convert';
import 'dart:math' as math;
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';
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
  /// - [DisplayOutputMode.thisDisplay] → opens a frameless clean-feed window
  ///   on the display the **operator window** is on.
  /// - [DisplayOutputMode.extend] → positions the window fullscreen on the
  ///   **secondary** display (like EasyWorship / ProPresenter).
  /// - [DisplayOutputMode.ndi] → activates the NDI offscreen renderer and starts streaming.
  Future<void> goLive(
    String? lyrics,
    int activeLine,
    String fontFamily,
    int displayLines,
    TextAlign textAlign,
    LyricsPosition position,
    LyricsSize size,
    bool clipped,
    bool overlay,
    LyricsOverlayTone overlayTone,
    int overlayOpacity,
    int lineHeight,
    bool textShadow,
    Color fontColor,
    Color backgroundColor,
    BackgroundType backgroundType,
    GradientType gradientType,
    List<Color> gradientColors,
    String? backgroundImagePath,
    String? backgroundVideoPath,
    bool isSegmented,
    List<int> segmentLineCounts,
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
      Map<String, double>? cleanFeedFrame;

      final operatorDisplay = await _operatorDisplay(displays);

      if (displayOutput.type == DisplayType.external) {
        // Use the specific display selected by the user, else any display
        // other than the operator's.
        targetDisplay =
            displayOutput.display ??
            displays.firstWhere(
              (d) => d.id != operatorDisplay.id,
              orElse: () => operatorDisplay,
            );
        goFullScreen = true;
      } else {
        // thisDisplay — the operator's own display (not the OS's first or
        // primary one, which can be the projector). Opens a frameless
        // clean-feed window for window capture in vMix / OBS.
        targetDisplay = operatorDisplay;
        goFullScreen = false;
        cleanFeedFrame = _cleanFeedFrame(targetDisplay);
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
          // Windows: the units the values above are in (see
          // _PresentationScreenPageState._setBoundsOnDisplay).
          'scaleFactor': (targetDisplay.scaleFactor ?? 1).toDouble(),
        },
        'cleanFeed': cleanFeedFrame != null,
        if (cleanFeedFrame != null) ...{
          'cleanFeedFrame': cleanFeedFrame,
          'cleanFeedPixels': {
            'width': cleanFeedPixels.width,
            'height': cleanFeedPixels.height,
          },
        },
        // Initial Style Data
        'fontFamily': fontFamily,
        'displayLines': displayLines,
        'textAlign': textAlign.index,
        'position': position.index,
        'size': size.index,
        'clipped': clipped,
        'overlay': overlay,
        'overlayTone': overlayTone.index,
        'overlayOpacity': overlayOpacity,
        'lineHeight': lineHeight,
        'textShadow': textShadow,
        'fontColor': fontColor.value.toRadixString(16),
        'backgroundColor': backgroundColor.value.toRadixString(16),
        'backgroundType': backgroundType.index,
        'gradientType': gradientType.index,
        'gradientColors':
            gradientColors.map((c) => c.value.toRadixString(16)).toList(),
        'backgroundImagePath': backgroundImagePath,
        'backgroundVideoPath': backgroundVideoPath,
        'isSegmented': isSegmented,
        'segmentLineCounts': segmentLineCounts,
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

  /// The display the operator window is on, else the primary display.
  ///
  /// Matched by the window's center. On Windows every display (and the
  /// window) is reported in its own monitor's scale, so a display whose
  /// scale matches the window's is preferred.
  Future<Display> _operatorDisplay(List<Display> displays) async {
    try {
      final center = (await windowManager.getBounds()).center;
      final dpr =
          WidgetsBinding
              .instance
              .platformDispatcher
              .views
              .first
              .devicePixelRatio;
      Rect area(Display d) =>
          (d.visiblePosition ?? Offset.zero) & (d.visibleSize ?? d.size);
      bool sameScale(Display d) =>
          d.scaleFactor == null || (d.scaleFactor! - dpr).abs() < 0.01;

      final containing = displays.where((d) => area(d).contains(center));
      final match =
          containing.where(sameScale).firstOrNull ?? containing.firstOrNull;
      if (match != null) return match;

      // Center off every display (e.g. dragged half off-screen): nearest.
      double distance(Display d) {
        final r = area(d);
        final dx = math.max(
          0.0,
          math.max(r.left - center.dx, center.dx - r.right),
        );
        final dy = math.max(
          0.0,
          math.max(r.top - center.dy, center.dy - r.bottom),
        );
        return dx * dx + dy * dy;
      }

      if (displays.isNotEmpty) {
        return displays.reduce((a, b) => distance(a) <= distance(b) ? a : b);
      }
    } catch (e) {
      debugPrint('Operator display lookup failed: $e');
    }
    return ScreenRetriever.instance.getPrimaryDisplay();
  }

  /// Pixel size of the clean feed captured by vMix / OBS.
  static const Size cleanFeedPixels = Size(1920, 1080);

  /// Window frame (logical units) for the clean feed, centered on [display].
  ///
  /// Capture tools grab the window at physical pixels, so the logical size is
  /// divided by the display scale to land on exactly [cleanFeedPixels].
  /// screen_retriever only reports the scale on Windows; macOS sizes the
  /// window natively from `cleanFeedPixels`.
  Map<String, double> _cleanFeedFrame(Display display) {
    final scale = (display.scaleFactor ?? 1).toDouble();
    final w = cleanFeedPixels.width / scale;
    final h = cleanFeedPixels.height / scale;
    final origin = display.visiblePosition ?? Offset.zero;
    final area = display.visibleSize ?? display.size;
    // On a 1080p screen at 100% the feed is as big as the screen; keep its
    // top edge on-screen and let the remainder run past the bottom.
    return {
      'x': origin.dx + math.max(0, (area.width - w) / 2),
      'y': origin.dy + math.max(0, (area.height - h) / 2),
      'width': w,
      'height': h,
    };
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

  /// Send updated lyrics position to the presentation window.
  Future<void> syncPosition(LyricsPosition position) async {
    if (_controller == null) return;
    try {
      await _controller!.invokeMethod('updatePosition', position.index);
    } catch (e) {
      _handleChannelError(e);
    }
  }

  /// Send updated lyric size to the presentation window.
  Future<void> syncSize(LyricsSize size) async {
    if (_controller == null) return;
    try {
      await _controller!.invokeMethod('updateSize', size.index);
    } catch (e) {
      _handleChannelError(e);
    }
  }

  /// Send updated clipping to the presentation window.
  Future<void> syncClipped(bool clipped) async {
    if (_controller == null) return;
    try {
      await _controller!.invokeMethod('updateClipped', clipped);
    } catch (e) {
      _handleChannelError(e);
    }
  }

  /// Send the overlay settings to the presentation window.
  Future<void> syncOverlay(
    bool overlay,
    LyricsOverlayTone tone,
    int opacity,
  ) async {
    if (_controller == null) return;
    try {
      await _controller!.invokeMethod('updateOverlay', {
        'overlay': overlay,
        'overlayTone': tone.index,
        'overlayOpacity': opacity,
      });
    } catch (e) {
      _handleChannelError(e);
    }
  }

  /// Send the lyric text settings (line height, shadow) to the window.
  Future<void> syncTextLayout(int lineHeight, bool textShadow) async {
    if (_controller == null) return;
    try {
      await _controller!.invokeMethod('updateTextLayout', {
        'lineHeight': lineHeight,
        'textShadow': textShadow,
      });
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
      await _controller!.invokeMethod(
        'updateBackgroundColor',
        color.toARGB32(),
      );
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
  Future<void> syncLyrics(
    String? text, {
    int? activeLine,
    bool? isSegmented,
    List<int>? segmentLineCounts,
  }) async {
    if (_controller == null) return;
    try {
      await _controller!.invokeMethod('updateLyrics', {
        'text': text,
        if (activeLine != null) 'activeLine': activeLine,
        if (isSegmented != null) 'isSegmented': isSegmented,
        if (segmentLineCounts != null) 'segmentLineCounts': segmentLineCounts,
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
