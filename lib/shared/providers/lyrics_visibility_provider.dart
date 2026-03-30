import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks whether lyrics are visible on the presentation output.
final lyricsVisibilityProvider = StateProvider<bool>((ref) => true);
