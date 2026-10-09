import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lycri_lyrics/features/library/models/song_domain_model.dart';
import 'package:lycri_lyrics/features/library/providers/database_provider.dart';
import 'package:lycri_lyrics/features/library/repositories/song_repository.dart';
import 'package:lycri_lyrics/features/operator/models/lyrics_segment.dart';
import 'package:lycri_lyrics/features/operator/presentation/lyric_input_panel.dart';
import 'package:lycri_lyrics/shared/providers/lyrics_provider.dart';

/// In-memory stand-in for the Drift-backed repository.
class _FakeSongRepository implements SongRepository {
  final saved = <SongDomainModel>[];

  @override
  Future<void> saveSong(SongDomainModel model) async => saved.add(model);

  @override
  Future<bool> doesTitleExist(String title) async =>
      saved.any((s) => s.title == title);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A library that rejects every save, like an un-migrated database file.
class _FailingSongRepository extends _FakeSongRepository {
  @override
  Future<void> saveSong(SongDomainModel model) async =>
      throw StateError('no such column: label');
}

const _verse = "When I see the devil's eyes\nI'll look away and smile wide";

SongDomainModel _savedSong() => SongDomainModel(
  id: 'song-1',
  title: 'Drag Path',
  originalText: _verse,
  segments: const [
    LyricsSegment(
      id: 'v1',
      text: _verse,
      type: LyricsSegmentType.verse,
      number: 1,
    ),
  ],
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Future<(ProviderContainer, _FakeSongRepository)> _pumpPanel(
  WidgetTester tester, {
  _FakeSongRepository? repository,
}) async {
  tester.view.physicalSize = const Size(352, 1024);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repo = repository ?? _FakeSongRepository();
  final container = ProviderContainer(
    overrides: [songRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: LyricInputPanel())),
    ),
  );
  return (container, repo);
}

void main() {
  testWidgets('editing a saved lyric enables Save, which cleans up and saves', (
    tester,
  ) async {
    final (container, repo) = await _pumpPanel(tester);
    final notifier = container.read(segmentedLyricsProvider.notifier);
    notifier.loadSong(_savedSong());
    notifier.editSavedLyric();
    await tester.pumpAndSettle();

    // Typing in the raw view of a saved lyric.
    await tester.enterText(find.byType(TextField), '$_verse\nYou found me');
    await tester.pump();

    final save = find.byTooltip('Save lyric');
    expect(save, findsOneWidget, reason: 'Save is enabled while editing');

    await tester.tap(save);
    await tester.pump(const Duration(seconds: 2)); // clean-up delay
    await tester.pumpAndSettle();

    final state = container.read(segmentedLyricsProvider);
    expect(state.isSegmented, isTrue);
    expect(repo.saved, hasLength(1));
    expect(repo.saved.single.id, 'song-1'); // same library entry
    expect(repo.saved.single.title, 'Drag Path');
    expect(repo.saved.single.originalText, contains('You found me'));
  });

  testWidgets('Clean up on an edited saved lyric auto-saves it', (
    tester,
  ) async {
    final (container, repo) = await _pumpPanel(tester);
    final notifier = container.read(segmentedLyricsProvider.notifier);
    notifier.loadSong(_savedSong());
    notifier.editSavedLyric();
    await tester.pumpAndSettle();

    await tester.tap(find.text('CLEAN UP'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(repo.saved, hasLength(1));
  });

  testWidgets('Clean up on a new lyric does not save it', (tester) async {
    final (_, repo) = await _pumpPanel(tester);

    await tester.enterText(find.byType(TextField), _verse);
    await tester.pump();
    await tester.tap(find.text('CLEAN UP'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(repo.saved, isEmpty);
  });

  testWidgets('a pasted new lyric can be saved: named, cleaned up, added', (
    tester,
  ) async {
    final (container, repo) = await _pumpPanel(tester);

    await tester.enterText(find.byType(TextField), _verse);
    await tester.pump();

    final save = find.byTooltip('Save lyric');
    expect(save, findsOneWidget, reason: 'Save is enabled once there is text');
    await tester.tap(save);
    await tester.pumpAndSettle();

    // The name-this-lyric menu opens; name it and confirm.
    expect(find.text('NAME THIS LYRIC'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Drag Path');
    await tester.pump(const Duration(milliseconds: 400)); // title check
    await tester.tap(find.text('SAVE LYRIC'));
    await tester.pump(const Duration(seconds: 2)); // clean-up delay
    await tester.pumpAndSettle();

    final state = container.read(segmentedLyricsProvider);
    expect(state.isSegmented, isTrue, reason: 'cleaned up into cards');
    expect(state.isSaved, isTrue);
    expect(repo.saved, hasLength(1));
    expect(repo.saved.single.title, 'Drag Path');
    expect(repo.saved.single.segments, isNotEmpty);

    await tester.pump(const Duration(seconds: 2)); // let the saved tick clear
  });

  testWidgets('a lyric named via "Tap to name" saves without the name menu', (
    tester,
  ) async {
    final (container, repo) = await _pumpPanel(tester);

    await tester.enterText(find.byType(TextField), _verse);
    await tester.pump();

    // Name it from the title bar first.
    await tester.tap(find.text('TAP TO NAME'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField).first, 'Drag Path');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(container.read(segmentedLyricsProvider).songTitle, 'Drag Path');

    await tester.tap(find.byTooltip('Save lyric'));
    await tester.pump();
    expect(find.text('NAME THIS LYRIC'), findsNothing, reason: 'no menu');
    await tester.pump(const Duration(seconds: 2)); // clean-up delay
    await tester.pumpAndSettle();

    expect(container.read(segmentedLyricsProvider).isSegmented, isTrue);
    expect(repo.saved, hasLength(1));
    expect(repo.saved.single.title, 'Drag Path');

    await tester.pump(const Duration(seconds: 2)); // let the saved tick clear
  });

  testWidgets('a save the library rejects is reported, not silent', (
    tester,
  ) async {
    final (container, _) = await _pumpPanel(
      tester,
      repository: _FailingSongRepository(),
    );
    final notifier = container.read(segmentedLyricsProvider.notifier);
    notifier.loadSong(_savedSong());
    notifier.editSavedLyric();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Save lyric'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(
      find.text("Couldn't save to the library. Restart Lycri and try again."),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 5)); // let the snackbar go
    await tester.pumpAndSettle();
  });
}
