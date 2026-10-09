// Repro: select a song, delete it from "Saved lyrics", then try to save —
// that and every later save (even new songs) failed to reach the database.
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lycri_lyrics/core/database/app_database.dart';
import 'package:lycri_lyrics/features/library/models/song_domain_model.dart';
import 'package:lycri_lyrics/features/library/providers/database_provider.dart';
import 'package:lycri_lyrics/features/library/providers/song_search_provider.dart';
import 'package:lycri_lyrics/features/operator/models/lyrics_segment.dart';
import 'package:lycri_lyrics/shared/providers/lyrics_provider.dart';

const _verse = "When I see the devil's eyes\nI'll look away and smile wide";

void main() {
  late ProviderContainer c;

  setUp(() {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    c = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(() async {
      c.dispose();
      await db.close();
    });
  });

  Future<List<String>> titles() async =>
      (await c.read(songRepositoryProvider).getAllSongs())
          .map((s) => s.title)
          .toList();

  test('saving still works after deleting the loaded song', () async {
    final repo = c.read(songRepositoryProvider);
    final lyrics = c.read(segmentedLyricsProvider.notifier);

    await repo.saveSong(
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
    );

    // 1. Select the song.
    lyrics.loadSong((await repo.getAllSongs()).single);
    // 2. Delete it from "Saved lyrics".
    await c.read(songSearchProvider.notifier).deleteSong('song-a');
    expect(await titles(), isEmpty);

    // 3. Edit it and save again.
    lyrics.editSavedLyric();
    c.read(lyricsProvider.notifier).update('$_verse\nYou found me');
    await lyrics.cleanup();
    await lyrics.saveLyric('Song A again');
    expect(await titles(), contains('Song A again'));

    // 4. A brand-new song saves too.
    lyrics.clearAll();
    c.read(lyricsProvider.notifier).update('A new song\nSecond line');
    await lyrics.cleanup();
    await lyrics.saveLyric('Song B');
    expect(await titles(), contains('Song B'));
  });
}
