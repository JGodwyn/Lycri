import 'package:drift/drift.dart';
import 'package:lycri_lyrics/core/database/app_database.dart';
import 'package:lycri_lyrics/features/library/models/song_domain_model.dart';
import 'package:lycri_lyrics/features/operator/models/lyrics_segment.dart';

class SongRepository {
  final AppDatabase _db;

  SongRepository(this._db);

  /// Get all songs ordered by created date (newest first).
  Future<List<SongDomainModel>> getAllSongs() async {
    final query = _db.select(_db.songs)
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]);
    
    final songEntries = await query.get();
    
    List<SongDomainModel> results = [];
    for (final songEntry in songEntries) {
      final segments = await _getSegmentsForSong(songEntry.id);
      results.add(_mapToDomain(songEntry, segments));
    }
    
    return results;
  }

  /// Search songs by title or original text.
  Future<List<SongDomainModel>> searchSongs(String queryStr) async {
    final query = _db.select(_db.songs)
      ..where((t) => t.title.contains(queryStr) | t.originalText.contains(queryStr))
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]);
      
    final songEntries = await query.get();
    
    List<SongDomainModel> results = [];
    for (final songEntry in songEntries) {
      final segments = await _getSegmentsForSong(songEntry.id);
      results.add(_mapToDomain(songEntry, segments));
    }
    
    return results;
  }

  /// Check if a song exactly matches the given title (case-insensitive)
  Future<bool> doesTitleExist(String title) async {
    final query = _db.select(_db.songs)..where((t) => t.title.equals(title));
    final result = await query.get();
    return result.isNotEmpty;
  }

  /// Save (insert or update) a song and its segments.
  Future<void> saveSong(SongDomainModel model) async {
    await _db.transaction(() async {
      // 1. Insert or Replace the Song
      await _db.into(_db.songs).insertOnConflictUpdate(
        SongsCompanion.insert(
          id: model.id,
          title: model.title,
          originalText: model.originalText,
          artist: Value(model.artist),
          createdAt: model.createdAt,
          updatedAt: model.updatedAt,
        ),
      );

      // 2. Delete existing segments for this song (to replace them cleanly)
      await (_db.delete(_db.lyricsSegments)
            ..where((t) => t.songId.equals(model.id)))
          .go();

      // 3. Insert new segments
      for (var i = 0; i < model.segments.length; i++) {
        final segment = model.segments[i];
        await _db.into(_db.lyricsSegments).insert(
          LyricsSegmentsCompanion.insert(
            id: segment.id,
            songId: model.id,
            textContent: segment.text,
            type: segment.type,
            segmentNumber: segment.number,
            isHidden: Value(segment.isHidden),
            orderIndex: i, // Ensure explicit ordering
          ),
        );
      }
    });
  }

  /// Delete a song and its segments.
  Future<void> deleteSong(String songId) async {
    await (_db.delete(_db.songs)..where((t) => t.id.equals(songId))).go();
    // We already have Cascade Delete referenced, but handling manual cleanup for safety.
    await (_db.delete(_db.lyricsSegments)..where((t) => t.songId.equals(songId))).go();
  }

  // ==== Internals ====

  Future<List<LyricsSegment>> _getSegmentsForSong(String songId) async {
    final query = _db.select(_db.lyricsSegments)
      ..where((t) => t.songId.equals(songId))
      ..orderBy([(t) => OrderingTerm(expression: t.orderIndex, mode: OrderingMode.asc)]);
      
    final segmentEntries = await query.get();
    
    return segmentEntries.map((e) => LyricsSegment(
      id: e.id,
      text: e.textContent,
      type: e.type,
      number: e.segmentNumber,
      isHidden: e.isHidden,
    )).toList();
  }

  SongDomainModel _mapToDomain(SongEntry entry, List<LyricsSegment> segments) {
    return SongDomainModel(
      id: entry.id,
      title: entry.title,
      originalText: entry.originalText,
      artist: entry.artist,
      segments: segments,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    );
  }

  // ==== Placeholders for Future Features ====

  /// Parse an external file (PDF, JSON, TXT) and convert it into a SongDomainModel.
  /// (Placeholder implemented as per requirements)
  Future<SongDomainModel?> parseFileToSong(String filePath) async {
    // To be implemented when UI is ready
    return null;
  }
}
