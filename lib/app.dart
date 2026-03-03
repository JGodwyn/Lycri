import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/operator/presentation/operator_page.dart';

/// Root widget for Lycri.
/// Wraps the app in [ProviderScope] for Riverpod and applies the design system theme.
class LycriApp extends StatelessWidget {
  const LycriApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'Lycri',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const OperatorPage(),
      ),
    );
  }
}
