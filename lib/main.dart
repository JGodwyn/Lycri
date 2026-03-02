import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';

/// Entry point for Lycri.
/// Responsibilities:
///   1. Load environment variables (.env)
///   2. Initialize window_manager for macOS desktop windowing
///   3. Scaffold Supabase init (inactive — auth not built yet)
///   4. Call runApp()
///
/// Keep this file minimal — no widget logic belongs here.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Load environment variables ────────────────────────────────────────────
  await dotenv.load(fileName: '.env');

  // ── Window Manager ────────────────────────────────────────────────────────
  // Must be called before any window configuration.
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

  // ── Supabase (scaffold only — auth not active yet) ────────────────────────
  // Credentials are injected from .env. Do NOT hardcode them.
  // Auth UI is not built yet; this init just ensures no startup errors later.
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  runApp(const LycriApp());
}
