// Renders the lyric panel in each design state to PNG for side-by-side
// comparison with design-sync/ screenshots.
//
//   flutter test test/design --update-goldens
//
// Output: test/design/goldens/*.png
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lycri_lyrics/core/theme/app_colors.dart';
import 'package:lycri_lyrics/features/library/models/song_domain_model.dart';
import 'package:lycri_lyrics/features/operator/models/lyrics_segment.dart';
import 'package:lycri_lyrics/features/operator/presentation/lyric_input_panel.dart';
import 'package:lycri_lyrics/features/operator/presentation/editor_panel.dart';
import 'package:lycri_lyrics/features/operator/presentation/presenter_panel.dart';
import 'package:lycri_lyrics/shared/providers/lyrics_style_provider.dart';
import 'package:lycri_lyrics/shared/providers/system_fonts_provider.dart';
import 'package:lycri_lyrics/shared/providers/display_mode_provider.dart';
import 'package:lycri_lyrics/shared/providers/lyrics_provider.dart';
import 'package:lycri_lyrics/shared/providers/presentation_window_provider.dart';
import 'package:lycri_lyrics/shared/providers/recent_backgrounds_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pretends the presentation window is open, without launching one.
class _FakeLiveWindow extends PresentationWindowNotifier {
  _FakeLiveWindow(super.ref) {
    state = true;
  }

  // No real window/NDI stream to tear down.
  @override
  Future<void> endLive() async => state = false;
}

const _fonts = {
  'Advent Pro': ['AdventPro-Bold.ttf', 'AdventPro-Black.ttf'],
  'Gabarito': [
    'Gabarito-Regular.ttf',
    'Gabarito-Medium.ttf',
    'Gabarito-SemiBold.ttf',
    'Gabarito-Bold.ttf',
  ],
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

const _verse =
    "When I see the devil's eyes\nI'll look away and smile wide\nYou found me";

SongDomainModel _song() => SongDomainModel(
  id: 'song-1',
  title: 'Drag Path',
  originalText: '[Verse 1]\n$_verse\n\n[Chorus]\n$_verse',
  segments: const [
    LyricsSegment(id: 'v1', text: _verse, type: LyricsSegmentType.verse, number: 1),
    LyricsSegment(id: 'c1', text: _verse, type: LyricsSegmentType.chorus, number: 1),
    LyricsSegment(id: 'v2', text: _verse, type: LyricsSegmentType.verse, number: 2),
  ],
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Future<void> _render(
  WidgetTester tester,
  String name,
  void Function(ProviderContainer c) setUp, {
  Widget panel = const LyricInputPanel(),
  Size size = const Size(352, 1024),
  bool live = false,
  void Function()? check,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      displaysProvider.overrideWith((ref) => Future.value([])),
      systemFontsProvider.overrideWith(
        (ref) => Future.value(['Advent Pro', 'Gabarito']),
      ),
      if (live)
        presentationWindowProvider.overrideWith((ref) => _FakeLiveWindow(ref)),
    ],
  );
  addTearDown(container.dispose);
  setUp(container);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Material(
          color: AppColors.surface3,
          child: Padding(padding: const EdgeInsets.all(16), child: panel),
        ),
      ),
    ),
  );
  // SVGs decode asynchronously; give them real time, then settle animations.
  await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
  await tester.pumpAndSettle();
  await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
  await tester.pumpAndSettle();

  await expectLater(
    find.byWidget(panel),
    matchesGoldenFile('goldens/$name.png'),
  );
  check?.call();
  // Unmount before the container is disposed in tearDown.
  await tester.pumpWidget(const SizedBox());
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('add a lyric (empty)', (tester) async {
    await _render(tester, 'add_a_lyric', (_) {});
  });

  testWidgets('editing a saved lyric', (tester) async {
    await _render(tester, 'editing_saved', (c) {
      c.read(segmentedLyricsProvider.notifier).loadSong(_song());
      c.read(segmentedLyricsProvider.notifier).editSavedLyric();
    });
  });

  testWidgets('segmented saved lyric', (tester) async {
    await _render(tester, 'segmented', (c) {
      c.read(segmentedLyricsProvider.notifier).loadSong(_song());
    });
  });

  testWidgets('presenter — empty', (tester) async {
    await _render(
      tester,
      'presenter_empty',
      (_) {},
      panel: const PresenterPanel(),
      size: const Size(699, 1024),
    );
  });

  testWidgets('presenter — lyrics loaded', (tester) async {
    await _render(
      tester,
      'presenter_base',
      (c) => c.read(segmentedLyricsProvider.notifier).loadSong(_song()),
      panel: const PresenterPanel(),
      size: const Size(699, 1024),
    );
  });

  testWidgets('presenter — live', (tester) async {
    await _render(
      tester,
      'presenter_live',
      (c) => c.read(segmentedLyricsProvider.notifier).loadSong(_song()),
      panel: const PresenterPanel(),
      size: const Size(699, 1024),
      live: true,
    );
  });

  const editorSize = Size(421, 1024);
  void recentColors(ProviderContainer c) {
    for (var i = 0; i < 7; i++) {
      c.read(recentBackgroundsProvider.notifier).addColor(
        Color(0xFFFFAE8F + i), // near-identical oranges, like the design
      );
    }
  }

  testWidgets('editor — solid color', (tester) async {
    await _render(
      tester,
      'editor_base',
      recentColors,
      panel: const EditorPanel(),
      size: editorSize,
    );
  });

  testWidgets('editor — video', (tester) async {
    await _render(
      tester,
      'editor_video',
      (c) {
        recentColors(c);
        final style = c.read(lyricsStyleProvider.notifier);
        style.setBackgroundType(BackgroundType.video);
        style.setBackgroundVideoPath('/videos/name of video truncated at the end.mp4');
      },
      panel: const EditorPanel(),
      size: editorSize,
    );
  });

  testWidgets('editor — gradient (EditorWindow1)', (tester) async {
    await _render(
      tester,
      'editor_gradient',
      (c) {
        final style = c.read(lyricsStyleProvider.notifier);
        style.setBackgroundType(BackgroundType.gradient);
        style.setGradientType(GradientType.radial);
        for (var i = 0; i < 7; i++) {
          c.read(recentBackgroundsProvider.notifier).addGradient(
            i.isEven ? GradientType.linear : GradientType.radial,
            [Color(0xFFFF6200 + i), const Color(0xFF000000)],
          );
        }
      },
      panel: const EditorPanel(),
      size: editorSize,
    );
  });

  testWidgets('editor — image (EditorWindow3)', (tester) async {
    await _render(
      tester,
      'editor_image',
      (c) {
        final style = c.read(lyricsStyleProvider.notifier);
        style.setBackgroundType(BackgroundType.image);
        style.setBackgroundImagePath('/images/Image name.png');
      },
      panel: const EditorPanel(),
      size: editorSize,
    );
  });

  testWidgets('lyric panel — long list fades at the edge', (tester) async {
    await _render(tester, 'segmented_long', (c) {
      final song = _song();
      c.read(segmentedLyricsProvider.notifier).loadSong(
        SongDomainModel(
          id: song.id,
          title: 'A song title long enough to fade out at the end',
          originalText: song.originalText,
          segments: [
            for (var i = 0; i < 8; i++)
              LyricsSegment(
                id: 's$i',
                text: _verse,
                type: i.isOdd ? LyricsSegmentType.chorus : LyricsSegmentType.verse,
                number: i + 1,
              ),
          ],
          createdAt: song.createdAt,
          updatedAt: song.updatedAt,
        ),
      );
    }, check: () {
      // The overflowing title fades out instead of clipping.
      expect(
        find.ancestor(
          of: find.text('A SONG TITLE LONG ENOUGH TO FADE OUT AT THE END'),
          matching: find.byType(ShaderMask),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('editor — switching background type glides', (tester) async {
    tester.view.physicalSize = editorSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        systemFontsProvider.overrideWith((ref) => Future.value(['Advent Pro'])),
      ],
    );
    addTearDown(container.dispose);
    final style = container.read(lyricsStyleProvider.notifier);
    style.setBackgroundType(BackgroundType.gradient);
    final recents = container.read(recentBackgroundsProvider.notifier);
    recents.addColor(const Color(0xFFFF6200));
    recents.addGradient(GradientType.linear, const [Colors.white, Colors.black]);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Material(
            color: AppColors.surface3,
            child: Padding(padding: EdgeInsets.all(16), child: EditorPanel()),
          ),
        ),
      ),
    );
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();

    double recentsY() => tester.getTopLeft(find.text('RECENTLY USED')).dy;
    final before = recentsY();

    await tester.tap(find.byTooltip('Color'));
    await tester.pump(); // switch starts
    final ys = <double>[];
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      ys.add(recentsY());
      if (i == 1) {
        await expectLater(
          find.byType(EditorPanel),
          matchesGoldenFile('goldens/editor_switch_midway.png'),
        );
      }
    }
    await tester.pumpAndSettle();
    final after = recentsY();

    // Moves up straight away (no waiting for the old controls to leave)…
    expect(ys.first, lessThan(before));
    // …glides rather than jumping…
    expect(ys.first, greaterThan(after));
    // …and has settled by ~240ms (the old delay was 350ms+).
    expect(ys.last, closeTo(after, 0.5));

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('cassette press — header buttons held down', (tester) async {
    tester.view.physicalSize = const Size(1430, 260);
    tester.view.devicePixelRatio = 2;
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
    container.read(segmentedLyricsProvider.notifier).loadSong(_song());

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Material(
            color: AppColors.surface3,
            child: Padding(
              padding: EdgeInsets.all(8),
              child: OverflowBox(
                alignment: Alignment.topCenter,
                maxHeight: 400,
                child: SizedBox(height: 400, child: PresenterPanel()),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();

    // Hold "next line" and "Go live" down mid-stroke.
    final next = await tester.startGesture(
      tester.getCenter(find.byTooltip('Next line')),
    );
    final goLive = await tester.startGesture(
      tester.getCenter(find.text('GO LIVE')),
    );
    await tester.pump(); // ticker starts on this frame
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/cassette_pressed.png'),
    );
    await next.cancel();
    await goLive.cancel();
    await tester.pumpWidget(const SizedBox());
  });
}
