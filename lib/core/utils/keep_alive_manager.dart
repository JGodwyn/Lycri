import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ndi/ndi_service.dart';
import '../../../shared/providers/presentation_window_provider.dart';
import 'app_nap_service.dart';

/// A reactive provider that manages the application's "Keep Alive" state.
///
/// It listens to both the NDI streaming state and the live presentation window
/// state and tells the [AppNapService] to disable macOS App Nap during active
/// broadcast or presentation. This ensures video backgrounds and NDI frames
/// continue to render smoothly even when the operator window is inactive.
final keepAliveManagerProvider = Provider<void>((ref) {
  final isNdi = ref.watch(ndiServiceProvider);
  final isLive = ref.watch(presentationWindowProvider);
  final napService = ref.read(appNapServiceProvider.notifier);

  // Debug logging to verify state is being tracked
  print('KeepAliveManager: isNdi=$isNdi, isLive=$isLive');

  if (isNdi || isLive) {
    napService.disableAppNap();
  } else {
    napService.enableAppNap();
  }
});
