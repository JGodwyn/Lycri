import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'presentation_screen_page.dart';

/// Minimal app wrapper for the presentation sub-window.
/// Applies the Lycri theme and renders the full-screen lyrics view.
class PresentationScreenApp extends StatelessWidget {
  const PresentationScreenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lycri Presentation',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const PresentationScreenPage(),
    );
  }
}
