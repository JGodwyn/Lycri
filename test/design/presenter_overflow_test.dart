// The presenter header must fit at the smallest operator window without a
// RenderFlex overflow, even with a long output-display name.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lycri_lyrics/core/theme/app_colors.dart';
import 'package:lycri_lyrics/features/operator/presentation/presenter_panel.dart';
import 'package:lycri_lyrics/shared/providers/display_mode_provider.dart';
import 'package:lycri_lyrics/shared/providers/presentation_window_provider.dart';
import 'package:lycri_lyrics/shared/providers/recent_backgrounds_provider.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeLiveWindow extends PresentationWindowNotifier {
  _FakeLiveWindow(super.ref) {
    state = true;
  }

  @override
  Future<void> endLive() async => state = false;
}

// Real fonts: the test font's glyphs are far wider than Advent Pro's.
const _fonts = {
  'Advent Pro': ['AdventPro-Bold.ttf', 'AdventPro-Black.ttf'],
  'Gabarito': ['Gabarito-Regular.ttf', 'Gabarito-Medium.ttf'],
};

Future<void> _loadFonts() async {
  for (final entry in _fonts.entries) {
    final loader = FontLoader(entry.key);
    for (final file in entry.value) {
      loader.addFont(rootBundle.load('assets/fonts/$file'));
    }
    await loader.load();
  }
}

final _longDisplay = Display(
  id: 2,
  name: 'LG UltraFine 27UK850 Ultra HD Display (Thunderbolt)',
  size: const Size(3840, 2160),
);

Future<void> _pump(
  WidgetTester tester, {
  required bool live,
  double width = 563,
}) async {
  // Minimum window 1280 − padding 2×16 − lyric column 320 − editor 333 −
  // gaps 2×16 = 563.
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      displaysProvider.overrideWith((ref) => Future.value([_longDisplay])),
      if (live)
        presentationWindowProvider.overrideWith((ref) => _FakeLiveWindow(ref)),
    ],
  );
  addTearDown(container.dispose);
  container.read(displayModeProvider.notifier).state = DisplayOutput.external(
    _longDisplay,
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Material(color: AppColors.surface3, child: PresenterPanel()),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox());
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('presenter header fits at minimum width', (tester) async {
    await _pump(tester, live: false);
  });

  testWidgets('presenter header fits at minimum width while live', (
    tester,
  ) async {
    await _pump(tester, live: true);
  });

  // A narrower column (e.g. a window still at the old 1200px minimum, or a
  // small display): the title fades rather than overflowing.
  testWidgets('presenter header fits in a narrow column while live', (
    tester,
  ) async {
    await _pump(tester, live: true, width: 440);
  });
}
