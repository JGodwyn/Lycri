import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:lycri_lyrics/core/theme/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Full-screen presentation window shown on the secondary display.
///
/// Listens for lyrics updates from the operator window via
/// [WindowMethodChannel] and renders them centered.
/// This window has no OS chrome and is not closeable by the user directly
/// (per SKILL.md Rule 4).
class PresentationScreenPage extends StatefulWidget {
  const PresentationScreenPage({super.key});

  @override
  State<PresentationScreenPage> createState() => _PresentationScreenPageState();
}

class _PresentationScreenPageState extends State<PresentationScreenPage> {
  String? _lyrics;

  /// Channel for receiving lyrics updates from the operator.
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
    super.dispose();
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'updateLyrics':
        setState(() => _lyrics = call.arguments as String?);
        return null;
      default:
        throw MissingPluginException('Not implemented: ${call.method}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface4,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            top: AppSpacing.x3l,
            bottom: AppSpacing.none,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child:
                _lyrics != null && _lyrics!.isNotEmpty
                    ? Text(
                      _lyrics!,
                      key: ValueKey(_lyrics),
                      style: AppTypography.displayMd.copyWith(
                        color: AppColors.textSubtle,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.left,
                    )
                    : const SizedBox.shrink(key: ValueKey('empty')),
          ),
        ),
      ),
    );
  }
}
