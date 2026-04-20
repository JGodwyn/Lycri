import 'dart:convert';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'features/presentation_screen/presentation/presentation_screen_app.dart';
import 'shared/providers/recent_backgrounds_provider.dart';

/// Entry point for Lycri.
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Sub-window check ─────────────────────────────────────────────────────
  // The presentation window passes JSON args that include 'type': 'presentation'.
  // We parse the JSON here so the check works correctly.
  final windowController = await WindowController.fromCurrentEngine();
  final rawArgs = windowController.arguments;
  if (rawArgs.isNotEmpty) {
    try {
      final decoded = jsonDecode(rawArgs) as Map<String, dynamic>;
      if (decoded['type'] == 'presentation') {
        runApp(const PresentationScreenApp());
        return;
      }
    } catch (_) {
      // Not valid JSON — not a sub-window we own; fall through to main app.
    }
  }

  // ── Main window init (operator) ────────────────────────────────────────

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Shared Preferences
  final sharedPrefs = await SharedPreferences.getInstance();

  // Window Manager
  await windowManager.ensureInitialized();

  // Retrieve saved window state
  final double savedWidth = sharedPrefs.getDouble('window_width') ?? 1400.0;
  final double savedHeight = sharedPrefs.getDouble('window_height') ?? 900.0;
  final double? savedX = sharedPrefs.getDouble('window_x');
  final double? savedY = sharedPrefs.getDouble('window_y');

  final WindowOptions windowOptions = WindowOptions(
    size: Size(savedWidth, savedHeight),
    minimumSize: const Size(1200, 700),
    center: savedX == null || savedY == null,
    title: 'Lycri',
    titleBarStyle: TitleBarStyle.normal,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (savedX != null && savedY != null) {
      await windowManager.setPosition(Offset(savedX, savedY));
    }
    await windowManager.show();
    await windowManager.focus();
  });

  // Register window persistence listener
  windowManager.addListener(_WindowPersistenceListener(sharedPrefs));

  // Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(sharedPrefs)],
      child: const LycriApp(),
    ),
  );
}

/// A listener that persists window size and position to [SharedPreferences].
class _WindowPersistenceListener extends WindowListener {
  final SharedPreferences prefs;

  _WindowPersistenceListener(this.prefs);

  @override
  void onWindowResized() async {
    final size = await windowManager.getSize();
    await prefs.setDouble('window_width', size.width);
    await prefs.setDouble('window_height', size.height);
  }

  @override
  void onWindowMoved() async {
    final pos = await windowManager.getPosition();
    await prefs.setDouble('window_x', pos.dx);
    await prefs.setDouble('window_y', pos.dy);
  }
}
