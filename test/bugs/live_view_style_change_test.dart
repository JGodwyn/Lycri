// Live view: changing editor settings must keep the active lyric on screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lycri_lyrics/features/operator/presentation/ndi_operator_view.dart';
import 'package:lycri_lyrics/shared/providers/active_line_provider.dart';
import 'package:lycri_lyrics/shared/providers/lyrics_provider.dart';
import 'package:lycri_lyrics/shared/providers/lyrics_style_provider.dart';
import 'package:lycri_lyrics/shared/providers/recent_backgrounds_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _lyrics = [for (var i = 0; i < 24; i++) 'Line number $i'].join('\n');

/// Sections of 3, 6, 3, 6, 6 lines (Auto pages by section; a section over 4
/// lines scrolls inside its page).
final _sectioned = [
  for (final (start, count) in [(0, 3), (3, 6), (9, 3), (12, 6), (18, 6)])
    [for (var i = start; i < start + count; i++) 'Line number $i'].join('\n'),
].join('\n\n');

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  bool sections = false,
  bool pip = false,
}) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  container.read(lyricsProvider.notifier).send(sections ? _sectioned : _lyrics);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Align(
          alignment: Alignment.topLeft,
          // The live view shows the canvas scaled down in a small window.
          child: SizedBox(
            width: pip ? 400 : LyricsOutputCanvas.width,
            height: pip ? 225 : LyricsOutputCanvas.height,
            child: const FittedBox(
              child: SizedBox(
                width: LyricsOutputCanvas.width,
                height: LyricsOutputCanvas.height,
                child: LyricsOutputCanvas(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await _frames(tester);
  if (sections) {
    final cleanup = container.read(segmentedLyricsProvider.notifier).cleanup();
    await _frames(tester, 3000);
    await cleanup;
    expect(container.read(segmentedLyricsProvider).isSegmented, isTrue);
  }
  return container;
}

/// Real frames (60fps) for [ms], so timers and animations interleave as in
/// the app.
Future<void> _frames(WidgetTester tester, [int ms = 1200]) async {
  for (var t = 0; t < ms; t += 16) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The active line's text is laid out fully inside the canvas — and, when
/// clipped, inside the visible band.
void _expectActiveOnScreen(WidgetTester tester, int active, String step) {
  final finder = find.text('Line number $active');
  expect(finder, findsWidgets, reason: '$step: active line not built');
  // Measured in the canvas's own (unscaled) coordinates.
  final canvas = tester.renderObject<RenderBox>(
    find.byType(LyricsOutputCanvas),
  );
  Rect inCanvas(RenderBox box) => MatrixUtils.transformRect(
    box.getTransformTo(canvas),
    Offset.zero & box.size,
  );
  final screen = Offset.zero & const Size(1920, 1080);
  final visible = finder.evaluate().any((e) {
    final box = e.renderObject as RenderBox;
    if (!box.attached || !box.hasSize) return false;
    final r = inCanvas(box);
    return screen.contains(r.topLeft) && screen.contains(r.bottomRight);
  });
  expect(visible, isTrue, reason: '$step: active line off screen');

  final masks = find.byType(TweenAnimationBuilder<Rect?>);
  if (masks.evaluate().isEmpty) return;
  final band = tester.widget<TweenAnimationBuilder<Rect?>>(masks.first);
  final rect = band.tween.end!;
  final inBand = finder.evaluate().any((e) {
    final box = e.renderObject as RenderBox;
    if (!box.attached || !box.hasSize) return false;
    final r = inCanvas(box);
    return r.top >= rect.top - 1 && r.bottom <= rect.bottom + 1;
  });
  expect(inBand, isTrue, reason: '$step: active line outside band $rect');
}

void main() {
  for (final pip in [false, true]) {
    for (final sections in [false, true]) {
      for (final lines in [0, -1, 2, 4]) {
        for (final clipped in [false, true]) {
          testWidgets(
            'pip=$pip sections=$sections lines=$lines clipped=$clipped',
            (tester) async {
              final c = await _pump(tester, sections: sections, pip: pip);
              final style = c.read(lyricsStyleProvider.notifier);
              style.setDisplayLines(lines);
              style.setClipped(clipped);
              await _frames(tester);
              c.read(activeLineProvider.notifier).jumpTo(13);
              await _frames(tester);
              _expectActiveOnScreen(tester, 13, 'initial');

              final steps = <String, void Function()>{
                'position top': () => style.setPosition(LyricsPosition.top),
                'position bottom':
                    () => style.setPosition(LyricsPosition.bottom),
                'position middle':
                    () => style.setPosition(LyricsPosition.middle),
                'size big': () => style.setSize(LyricsSize.big),
                'size small': () => style.setSize(LyricsSize.small),
                'line height': () => style.setLineHeight(80),
                'clip toggle': () => style.setClipped(!clipped),
                'clip back': () => style.setClipped(clipped),
                'align right': () => style.setTextAlign(TextAlign.right),
              };
              for (final MapEntry(key: name, value: apply) in steps.entries) {
                apply();
                await _frames(tester);
                _expectActiveOnScreen(tester, 13, name);
              }

              // Rapid changes, a frame or two apart, mixed with navigation.
              style.setPosition(LyricsPosition.top);
              await tester.pump(const Duration(milliseconds: 16));
              style.setSize(LyricsSize.big);
              await tester.pump(const Duration(milliseconds: 50));
              c.read(activeLineProvider.notifier).next(23);
              await tester.pump(const Duration(milliseconds: 16));
              style.setPosition(LyricsPosition.bottom);
              await tester.pump(const Duration(milliseconds: 120));
              style.setLineHeight(30);
              style.setSize(LyricsSize.mid);
              await _frames(tester);
              _expectActiveOnScreen(tester, 14, 'rapid changes');
            },
          );
        }
      }
    }
  }
}
