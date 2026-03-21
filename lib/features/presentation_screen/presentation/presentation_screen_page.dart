import 'dart:io';
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Full-screen presentation window shown on the secondary display.
///
/// Receives lyrics and the active line index from the operator window via
/// [WindowMethodChannel]. Renders all lyric lines in a scrollable list and
/// smoothly scrolls to keep the active line centred, with crossfade transitions
/// on text color — matching the operator presenter panel's Spotify-style feel.
///
/// This window has no OS chrome and is not closeable by the user directly
/// (per SKILL.md Rule 4).
class PresentationScreenPage extends StatefulWidget {
  const PresentationScreenPage({super.key});

  @override
  State<PresentationScreenPage> createState() => _PresentationScreenPageState();
}

class _PresentationScreenPageState extends State<PresentationScreenPage> {
  /// Raw lyrics text received from the operator.
  String? _rawLyrics;

  /// Parsed non-empty lyric lines.
  List<String> _lines = [];

  /// The font family used to render the lyrics.
  String _fontFamily = 'Libre Caslon Condensed';

  /// Number of lines to display simultaneously (0 = Auto).
  int _displayLines = 0;

  /// Text alignment for the lyrics.
  TextAlign _textAlign = TextAlign.left;

  /// Font color for the lyrics.
  Color _fontColor = const Color(0xFF000000);

  /// Background color for the presentation.
  Color _backgroundColor = const Color(0xFFFFFFFF);

  /// Background type for the presentation.
  int _backgroundType = 0; // 0 = solidColor

  /// Gradient colors for gradient background.
  List<Color> _gradientColors = const [Color(0xFFFFFFFF), Color(0xFF000000)];

  /// Gradient type for gradient background.
  int _gradientType = 0; // 0 = linear

  /// Background image path.
  String? _backgroundImagePath;

  /// Index of the currently active (highlighted) line.
  int _activeLine = 0;

  /// Scroll controller for smooth auto-scrolling to the active line.
  final ScrollController _scrollController = ScrollController();

  /// Page controller for smoothly paginating via full pushes.
  PageController _pageController = PageController();

  /// Keys for each line — used to measure position for scroll targeting.
  final Map<int, GlobalKey> _lineKeys = {};

  /// Animation duration & curve for Spotify-style smooth transitions.
  static const _animDuration = Duration(milliseconds: 400);
  static const _animCurve = Curves.easeOutCubic;

  /// Channel for receiving updates from the operator.
  static const _channel = WindowMethodChannel(
    'lycri/presentation',
    mode: ChannelMode.unidirectional,
  );

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'updateLyrics':
        final text = call.arguments as String?;
        setState(() {
          _rawLyrics = text;
          _lines =
              (text ?? '')
                  .split('\n')
                  .where((l) => l.trim().isNotEmpty)
                  .toList();
          _activeLine = 0;
          _lineKeys.clear();

          if (_displayLines > 0) {
            final oldController = _pageController;
            _pageController = PageController(initialPage: 0);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              oldController.dispose();
            });
          }
        });

        if (_displayLines == 0) {
          _scrollToActive(0);
        }
        return null;

      case 'updateActiveLine':
        final newIndex = (call.arguments as int?) ?? 0;
        setState(() => _activeLine = newIndex);
        _scrollToActive(newIndex);
        return null;

      case 'updateFontFamily':
        final newFont = call.arguments as String?;
        if (newFont != null) {
          setState(() => _fontFamily = newFont);
        }
        return null;

      case 'updateDisplayLines':
        final newLines = call.arguments as int?;
        if (newLines != null && newLines != _displayLines) {
          setState(() {
            _displayLines = newLines;
            if (newLines > 0) {
              final oldController = _pageController;
              _pageController = PageController(
                initialPage: _lines.isNotEmpty ? _activeLine ~/ newLines : 0,
              );
              WidgetsBinding.instance.addPostFrameCallback((_) {
                oldController.dispose();
              });
            }
          });

          if (newLines == 0) {
            _scrollToActive(_activeLine);
          }
        }
        return null;

      case 'updateTextAlign':
        final alignIndex = call.arguments as int?;
        if (alignIndex != null) {
          final newAlign = TextAlign.values[alignIndex];
          setState(() => _textAlign = newAlign);
        }
        return null;

      case 'updateFontColor':
        final colorValue = call.arguments as int?;
        if (colorValue != null) {
          setState(() => _fontColor = Color(colorValue));
        }
        return null;

      case 'updateBackgroundColor':
        final colorValue = call.arguments as int?;
        if (colorValue != null) {
          setState(() => _backgroundColor = Color(colorValue));
        }
        return null;

      case 'updateBackgroundType':
        final typeIndex = call.arguments as int?;
        if (typeIndex != null) {
          setState(() => _backgroundType = typeIndex);
        }
        return null;

      case 'updateGradientType':
        final typeIndex = call.arguments as int?;
        if (typeIndex != null) {
          setState(() => _gradientType = typeIndex);
        }
        return null;

      case 'updateGradientColors':
        final rawColors = call.arguments as List?;
        if (rawColors != null) {
          setState(() {
            _gradientColors =
                rawColors.cast<int>().map((v) => Color(v)).toList();
          });
        }
        return null;
      case 'updateBackgroundImagePath':
        final newPath = call.arguments as String?;
        setState(() => _backgroundImagePath = newPath);
        return null;

      default:
        throw MissingPluginException('Not implemented: ${call.method}');
    }
  }

  /// Ensure a [GlobalKey] exists for line [index].
  GlobalKey _keyFor(int index) {
    return _lineKeys.putIfAbsent(index, () => GlobalKey());
  }

  /// Smoothly scroll or paginate so the active line is visible.
  void _scrollToActive(int activeIndex) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_displayLines > 0) {
        // We are in pagination mode. Push the page up/down.
        if (!_pageController.hasClients) return;
        final targetPage = activeIndex ~/ _displayLines;
        if (_pageController.page?.round() != targetPage) {
          _pageController.animateToPage(
            targetPage,
            duration: _animDuration,
            curve: _animCurve,
          );
        }
        return;
      }

      // Continuous scrolling mode:
      if (!_scrollController.hasClients) return;

      final key = _lineKeys[activeIndex];
      if (key == null) return;

      final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) return;

      // Position of the line relative to the scroll viewport.
      final viewport = _scrollController.position;
      final lineOffset = renderBox.localToGlobal(
        Offset.zero,
        ancestor: viewport.context.storageContext.findRenderObject(),
      );

      // Target: place the line ~1/3 from the top so readers see context below.
      final targetOffset =
          _scrollController.offset +
          lineOffset.dy -
          (viewport.viewportDimension * 0.33);

      _scrollController.animateTo(
        targetOffset.clamp(0.0, viewport.maxScrollExtent),
        duration: _animDuration,
        curve: _animCurve,
      );
    });
  }

  CrossAxisAlignment get _crossAxisAlignment {
    switch (_textAlign) {
      case TextAlign.center:
        return CrossAxisAlignment.center;
      case TextAlign.right:
        return CrossAxisAlignment.end;
      default:
        return CrossAxisAlignment.start;
    }
  }

  Widget _buildLyricLine(int i, {bool useGlobalKey = false}) {
    return Padding(
      key: useGlobalKey ? _keyFor(i) : null,
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: AnimatedDefaultTextStyle(
        duration: _animDuration,
        curve: _animCurve,
        style: AppTypography.displayMd.copyWith(
          fontFamily: _fontFamily,
          color:
              i == _activeLine ? _fontColor : _fontColor.withValues(alpha: 0.2),
          height: 1.4,
        ),
        child: SizedBox(
          width: double.infinity,
          child: Text(_lines[i], textAlign: _textAlign, softWrap: true),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasLyrics = _rawLyrics != null && _lines.isNotEmpty;

    // Prune stale keys when line count shrinks.
    _lineKeys.removeWhere((k, _) => k >= _lines.length);

    int totalPages = 1;
    if (_displayLines > 0 && _lines.isNotEmpty) {
      totalPages = (_lines.length / _displayLines).ceil();
    }

    Widget content;
    if (_displayLines > 0) {
      content = PageView.builder(
        key: ValueKey('paginated_view_$_displayLines'),
        controller: _pageController,
        scrollDirection: Axis.vertical,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: totalPages,
        itemBuilder: (context, pageIndex) {
          int startIdx = pageIndex * _displayLines;
          int endIdx = startIdx + _displayLines;
          if (endIdx > _lines.length) endIdx = _lines.length;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x5l,
                  vertical: AppSpacing.x2l,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: _crossAxisAlignment,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = startIdx; i < endIdx; i++)
                      _buildLyricLine(i, useGlobalKey: false),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } else {
      content = Center(
        key: const ValueKey('continuous_view'),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x5l,
                vertical: AppSpacing.x2l,
              ),
              child: Column(
                crossAxisAlignment: _crossAxisAlignment,
                children: [
                  for (int i = 0; i < _lines.length; i++)
                    _buildLyricLine(i, useGlobalKey: true),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Determine background decoration based on background type.
    final bool isGradient = _backgroundType == 1; // 1 = gradient
    final decoration =
        isGradient
            ? BoxDecoration(
              gradient:
                  _gradientType ==
                          0 // linear
                      ? LinearGradient(
                        colors:
                            _gradientColors.length >= 2
                                ? _gradientColors
                                : [Colors.white, Colors.black],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 1.0],
                      )
                      : RadialGradient(
                        colors:
                            _gradientColors.length >= 2
                                ? _gradientColors
                                : [Colors.white, Colors.black],
                        stops: const [0.0, 1.0],
                      ),
            )
            : _backgroundType == 2 &&
                _backgroundImagePath !=
                    null // 2 = image
            ? BoxDecoration(
              image: DecorationImage(
                image: FileImage(File(_backgroundImagePath!)),
                fit: BoxFit.cover,
              ),
            )
            : BoxDecoration(color: _backgroundColor);

    return Scaffold(
      body: Container(
        decoration: decoration,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child:
              hasLyrics
                  ? content
                  : const SizedBox.shrink(key: ValueKey('empty')),
        ),
      ),
    );
  }
}
