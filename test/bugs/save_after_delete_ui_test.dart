// UI-level repro of the save-after-delete bug, against a real (in-memory) DB.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lycri_lyrics/core/database/app_database.dart';
import 'package:lycri_lyrics/features/library/models/song_domain_model.dart';
import 'package:lycri_lyrics/features/library/providers/database_provider.dart';
import 'package:lycri_lyrics/features/library/providers/song_search_provider.dart';
import 'package:lycri_lyrics/features/operator/models/lyrics_segment.dart';
import 'package:lycri_lyrics/features/operator/presentation/lyric_input_panel.dart';
import 'package:lycri_lyrics/shared/providers/lyrics_provider.dart';

const _verse = "When I see the devil's eyes\nI'll look away and smile wide";

void main() {
  testWidgets('select → delete → edit → save reaches the database', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(352, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final c = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(c.dispose);
    final repo = c.read(songRepositoryProvider);

    Future<List<String>> titles() async => (await tester.runAsync(
      () async => (await repo.getAllSongs()).map((s) => s.title).toList(),
    ))!;

    await tester.runAsync(
      () => repo.saveSong(
        SongDomainModel(
          id: 'song-a',
          title: 'Song A',
          originalText: _verse,
          segments: const [
            LyricsSegment(
              id: 'a1',
              text: _verse,
              type: LyricsSegmentType.verse,
              number: 1,
            ),
          ],
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Material(child: LyricInputPanel())),
      ),
    );

    // 1. Select the song.
    final song = (await tester.runAsync(() => repo.getAllSongs()))!.single;
    c.read(segmentedLyricsProvider.notifier).loadSong(song);
    await tester.pumpAndSettle();

    // 2. Delete it from "Saved lyrics".
    await tester.runAsync(
      () => c.read(songSearchProvider.notifier).deleteSong('song-a'),
    );
    await tester.pumpAndSettle();
    expect(await titles(), isEmpty);

    // 3. Edit it (pen) and save.
    debugPrint('state after delete: ${_describe(c)}');
    await tester.tap(find.byTooltip('Edit lyric text'));
    await tester.pumpAndSettle();
    debugPrint('state after edit tap: ${_describe(c)}');
    await tester.enterText(find.byType(TextField).last, '$_verse\nYou found me');
    await tester.pump();

    final save = find.byTooltip('Save lyric');
    debugPrint('save buttons found: ${save.evaluate().length}');
    await tester.tap(save);
    await tester.pumpAndSettle();
    debugPrint('menu open: ${find.text('NAME THIS LYRIC').evaluate().isNotEmpty}');
    await tester.enterText(find.byType(TextField).last, 'Song A');
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 400)));
    await tester.pump(const Duration(milliseconds: 400));
    debugPrint('save lyric enabled: ${find.text('SAVE LYRIC').evaluate().length}');
    await tester.tap(find.text('SAVE LYRIC'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 2)));
    await tester.pump(const Duration(seconds: 2));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    debugPrint('state after save: ${_describe(c)}');

    expect(await titles(), contains('Song A'));
    await tester.pump(const Duration(seconds: 2));
  });
}

String _describe(ProviderContainer c) {
  final s = c.read(segmentedLyricsProvider);
  return 'segmented=${s.isSegmented} editing=${s.isEditing} saved=${s.isSaved} '
      'id=${s.songId} title=${s.songTitle} loading=${s.isLoading} '
      'segments=${s.segments.length}';
}
