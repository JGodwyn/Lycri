import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/system_font_service.dart';

/// Provider that loads available system fonts once and caches the result.
///
/// Returns a [Future] list of font family names installed on macOS.
/// The bundled app fonts are prepended at the top of the list so they
/// always appear first in the dropdown.
final systemFontsProvider = FutureProvider<List<String>>((ref) async {
  const bundledFonts = [
    'Libre Caslon Condensed',
    'Libre Caslon Text',
    'Source Code Pro',
  ];

  final systemFonts = await SystemFontService.getSystemFonts();

  // Remove duplicates of bundled fonts from the system list.
  final bundledSet = bundledFonts.toSet();
  final filtered = systemFonts.where((f) => !bundledSet.contains(f)).toList();

  return [...bundledFonts, ...filtered];
});
