import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_nap_service.dart';

/// A reactive provider that manages the application's "Keep Alive" state.
///
/// It listens to both the NDI streaming state and the live presentation window
/// state and tells the [AppNapService] to disable macOS App Nap during active
/// broadcast or presentation. This ensures video backgrounds and NDI frames
/// continue to render smoothly even when the operator window is inactive.
final keepAliveManagerProvider = Provider<void>((ref) {
  final napService = ref.read(appNapServiceProvider.notifier);

  // Per user request, the app should NEVER sleep or nap, regardless of state.
  // This ensures all live feeds (Presentation, NDI, windowed) are always smooth.
  napService.disableAppNap();
});
