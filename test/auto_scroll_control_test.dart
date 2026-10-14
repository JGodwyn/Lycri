import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lycri_lyrics/core/theme/app_colors.dart';
import 'package:lycri_lyrics/features/operator/presentation/presenter_panel.dart';
import 'package:lycri_lyrics/features/operator/presentation/widgets/auto_scroll_control.dart';
import 'package:lycri_lyrics/shared/providers/active_line_provider.dart';
import 'package:lycri_lyrics/shared/providers/auto_scroll_provider.dart';
import 'package:lycri_lyrics/shared/providers/display_mode_provider.dart';
import 'package:lycri_lyrics/shared/providers/lyrics_provider.dart';
import 'package:lycri_lyrics/shared/providers/recent_backgrounds_provider.dart';
import 'package:lycri_lyrics/shared/utils/auto_scroll_timing.dart';
import 'package:lycri_lyrics/shared/widgets/lycri_pill_group.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      displaysProvider.overrideWith((ref) => Future.value([])),
    ],
  );
  addTearDown(container.dispose);
  container
      .read(lyricsProvider.notifier)
      .send('one two\nthree four\nfive six\nseven eight');

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Material(color: AppColors.surface3, child: PresenterPanel()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Finder _icon(String name) => find.byWidgetPredicate(
  (w) =>
      w is SvgPicture &&
      w.bytesLoader is SvgAssetLoader &&
      (w.bytesLoader as SvgAssetLoader).assetName == 'assets/vectors/$name.svg',
);

// Real fonts: the test font is far wider than Advent Pro / Gabarito.
Future<void> _loadFonts() async {
  const fonts = {
    'Advent Pro': ['AdventPro-Bold.ttf', 'AdventPro-Black.ttf'],
    'Gabarito': ['Gabarito-Regular.ttf', 'Gabarito-Medium.ttf'],
  };
  for (final entry in fonts.entries) {
    final loader = FontLoader(entry.key);
    for (final file in entry.value) {
      loader.addFont(rootBundle.load('assets/fonts/$file'));
    }
    await loader.load();
  }
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('the chevron opens and closes the tray', (tester) async {
    await _pump(tester);
    expect(find.text('Set time'), findsNothing);

    await tester.tap(find.byType(AutoScrollChevron));
    await tester.pumpAndSettle();
    for (final label in ['Auto', '1x', '2x', '3x', 'Set time']) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.byType(AutoScrollChevron));
    await tester.pumpAndSettle();
    expect(find.text('Set time'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('speed and play/pause drive the notifier', (tester) async {
    final c = await _pump(tester);
    await tester.tap(find.byType(AutoScrollChevron));
    await tester.pumpAndSettle();

    await tester.tap(find.text('2x'));
    await tester.pump();
    expect(c.read(autoScrollProvider).mode, AutoScrollMode.x2);
    await tester.tap(find.text('Auto'));
    await tester.pump();
    expect(c.read(autoScrollProvider).mode, AutoScrollMode.auto);

    await tester.tap(_icon('play'));
    await tester.pump();
    expect(c.read(autoScrollProvider).playing, isTrue);
    expect(_icon('pause'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2100));
    expect(c.read(activeLineProvider), 1);

    // Collapsed while running: the toggle keeps its white treatment.
    bool toggleSelected() =>
        tester
            .widget<LycriPillGroup>(
              find.ancestor(
                of: find.byType(AutoScrollChevron),
                matching: find.byType(LycriPillGroup),
              ),
            )
            .segments
            .last
            .selected;
    await tester.tap(find.byType(AutoScrollChevron));
    await tester.pumpAndSettle();
    expect(toggleSelected(), isTrue);
    await tester.tap(find.byType(AutoScrollChevron));
    await tester.pumpAndSettle();

    await tester.tap(_icon('pause'));
    await tester.pump();
    expect(c.read(autoScrollProvider).playing, isFalse);

    // Stopped and collapsed: back to the plain toggle.
    await tester.tap(find.byType(AutoScrollChevron));
    await tester.pumpAndSettle();
    expect(toggleSelected(), isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Set time opens a modal that sets the length', (tester) async {
    final c = await _pump(tester);
    await tester.tap(find.byType(AutoScrollChevron));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Set time'));
    await tester.pumpAndSettle();
    expect(find.text('SET SONG TIME'), findsOneWidget);
    expect(find.textContaining('How long the song runs'), findsOneWidget);

    final minutes = find.byType(TextField).at(0);
    final seconds = find.byType(TextField).at(1);

    // No time yet: no summary line.
    expect(find.textContaining('each'), findsNothing);

    // Seconds past 59 explain themselves and can't be applied.
    await tester.enterText(seconds, '75');
    await tester.pump();
    expect(find.text('Seconds go up to 59'), findsOneWidget);

    // Two minute digits move on to seconds.
    await tester.enterText(minutes, '10');
    await tester.pump();
    expect(tester.widget<TextField>(seconds).focusNode!.hasFocus, isTrue);

    // 4 lines over 0:12 → 3s each; ↑ steps seconds.
    await tester.enterText(minutes, '0');
    await tester.enterText(seconds, '11');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(find.text('12'), findsOneWidget);
    expect(find.text('4 lines, 3.0s each'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('SET SONG TIME'), findsNothing);
    expect(c.read(autoScrollProvider).mode, AutoScrollMode.songLength);
    expect(c.read(autoScrollProvider).songLength, const Duration(seconds: 12));
    expect(find.text('0:12'), findsOneWidget); // the segment shows the time

    // Reopening shows the current time split into the two boxes.
    await tester.tap(find.text('0:12'));
    await tester.pumpAndSettle();
    expect(find.text('CLEAR'), findsNothing);
    expect(tester.widget<TextField>(minutes).controller!.text, '0');
    expect(tester.widget<TextField>(seconds).controller!.text, '12');
    await tester.pumpWidget(const SizedBox());
  });
}
