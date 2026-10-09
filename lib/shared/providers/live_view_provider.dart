import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the presenter panel shows the live (audience output) view beside
/// the editing preview.
final liveViewVisibleProvider = StateProvider<bool>((ref) => false);
