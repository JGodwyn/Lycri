import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lycri_lyrics/core/database/app_database.dart';
import 'package:lycri_lyrics/features/library/repositories/song_repository.dart';
import 'package:lycri_lyrics/features/library/repositories/preset_repository.dart';

/// Provides a singleton instance of the AppDatabase.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  
  // Ensure the connection is closed when the provider is destroyed
  ref.onDispose(() {
    db.close();
  });
  
  return db;
});

/// Provides the SongRepository, which handles all database access logic for songs.
final songRepositoryProvider = Provider<SongRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return SongRepository(db);
});

/// Provides the PresetRepository.
final presetRepositoryProvider = Provider<PresetRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return PresetRepository(db);
});
