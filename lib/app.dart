import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/keep_alive_manager.dart';
import 'features/operator/presentation/operator_page.dart';

/// Root widget for Lycri.
/// Wraps the app in [ProviderScope] for Riverpod and applies the design system theme.
class LycriApp extends ConsumerWidget {
  const LycriApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch our keep-alive manager at the root so its logic is always active
    // when either NDI or live presentation mode is running.
    ref.watch(keepAliveManagerProvider);

    return MaterialApp(
      title: 'Lycri',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const OperatorPage(),
    );
  }
}
