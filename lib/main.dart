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

  // ── Sub-window check ────────────────────────────────────────────────────
  final windowController = await WindowController.fromCurrentEngine();
  if (windowController.arguments == 'presentation') {
    runApp(const PresentationScreenApp());
    return;
  }

  // ── Main window init (operator) ────────────────────────────────────────

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Shared Preferences
  final sharedPrefs = await SharedPreferences.getInstance();

  // Window Manager
  await windowManager.ensureInitialized();

  const WindowOptions windowOptions = WindowOptions(
    size: Size(1400, 1100),
    minimumSize: Size(960, 600),
    center: true,
    title: 'Lycri',
    titleBarStyle: TitleBarStyle.normal,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

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

