import 'dart:io';
import 'package:flutter/services.dart';

/// Service that queries the OS for installed system font families
/// via a platform MethodChannel.
///
/// - **macOS**: Uses `NSFontManager.shared.availableFontFamilies` on the native side.
/// - **Windows**: Uses the `com.lycri/system_fonts` channel, which should enumerate
///   fonts via DirectWrite or GDI on the native side. Until the Windows native
///   handler is implemented, this falls back to an empty list.
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
    } on MissingPluginException {
      // Native handler not yet implemented on this platform.
      print('SystemFontService: getSystemFonts not implemented on '
          '${Platform.operatingSystem}');
      return [];
    }
  }
}
