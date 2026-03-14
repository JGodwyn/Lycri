import 'package:flutter/services.dart';

/// Service that queries macOS for installed system font families
/// via a platform MethodChannel.
///
/// Uses `NSFontManager.shared.availableFontFamilies` on the native side.
class SystemFontService {
  SystemFontService._();

  static const _channel = MethodChannel('com.lycri/system_fonts');

  /// Returns a sorted list of all font family names installed on the system.
  /// Falls back to an empty list if the platform call fails.
  static Future<List<String>> getSystemFonts() async {
    try {
      final List<dynamic> fonts = await _channel.invokeMethod('getSystemFonts');
      return fonts.cast<String>();
    } on PlatformException {
      return [];
    }
  }
}
