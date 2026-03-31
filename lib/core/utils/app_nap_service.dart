import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A service to control macOS "App Nap".
///
/// App Nap is a macOS feature that throttles background applications to save power.
/// For a broadcast app like Lycri, this causes video backgrounds and NDI streams
/// to pause or stutter when the operator window is not focused.
///
/// This service uses a native MethodistChannel to tell macOS to treat Lycri
/// as a "User Initiated" activity, preventing it from napping.
class AppNapService extends StateNotifier<bool> {
  AppNapService() : super(false);

  static const _channel = MethodChannel('lycri/app_nap');

  /// Disables App Nap. Call this when going live or starting NDI.
  Future<void> disableAppNap() async {
    if (state) return;
    try {
      print('AppNapService: Disabling macOS App Nap');
      await _channel.invokeMethod('disableAppNap');
      state = true;
    } catch (e) {
      print('AppNapService: Failed to disable App Nap: $e');
    }
  }

  /// Enables App Nap (default). Call this when ending live session or stopping NDI.
  Future<void> enableAppNap() async {
    if (!state) return;
    try {
      print('AppNapService: Re-enabling macOS App Nap');
      await _channel.invokeMethod('enableAppNap');
      state = false;
    } catch (e) {
      print('AppNapService: Failed to enable App Nap: $e');
    }
  }
}

/// Provider for the AppNapService.
final appNapServiceProvider = StateNotifierProvider<AppNapService, bool>((ref) {
  return AppNapService();
});
