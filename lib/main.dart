import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'features/presentation_screen/presentation/presentation_screen_app.dart';

/// Entry point for Lycri.
///
/// Responsibilities:
///   1. Detect whether this process is a sub-window (presentation) or main
///   2. Load environment variables (.env)
///   3. Initialize window_manager for macOS desktop windowing
///   4. Scaffold Supabase init (inactive — auth not built yet)
///   5. Call runApp()
///
/// Keep this file minimal — no widget logic belongs here.
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Sub-window check ────────────────────────────────────────────────────
  // desktop_multi_window passes arguments to sub-window processes.
  // If this is a sub-window, run the appropriate app directly.
  final windowController = await WindowController.fromCurrentEngine();
  if (windowController.arguments == 'presentation') {
    // This is the presentation sub-window — skip operator init.
    runApp(const PresentationScreenApp());
    return;
  }

  // ── Main window init (operator) ────────────────────────────────────────

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Window Manager — must be called before any window configuration.
  await windowManager.ensureInitialized();

  const WindowOptions windowOptions = WindowOptions(
    size: Size(1280, 800),
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

  // Supabase (scaffold only — auth not active yet)
  // Credentials are injected from .env. Do NOT hardcode them.
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  runApp(const LycriApp());
}
