import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lycri_lyrics/features/library/models/song_domain_model.dart';
import 'package:lycri_lyrics/features/library/providers/database_provider.dart';

/// Notifier to handle search query and results for the library.
class SongSearchNotifier extends StateNotifier<AsyncValue<List<SongDomainModel>>> {
  final Ref _ref;
  String _lastQuery = "";

  SongSearchNotifier(this._ref) : super(const AsyncValue.loading()) {
    search("");
  }

  /// Search for songs matching the query.
  Future<void> search(String query) async {
    _lastQuery = query;
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(songRepositoryProvider);
      final results = query.isEmpty 
          ? await repo.getAllSongs() 
          : await repo.searchSongs(query);
      
      if (_lastQuery == query) {
        state = AsyncValue.data(results);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Delete a song and refresh the current search.
  Future<void> deleteSong(String songId) async {
    try {
      final repo = _ref.read(songRepositoryProvider);
      await repo.deleteSong(songId);
      // Refresh results
      await search(_lastQuery);
    } catch (e, st) {
      // Potentially handle error state
      state = AsyncValue.error(e, st);
    }
  }
}

/// Provider for searching and managing results in the library.
final songSearchProvider = StateNotifierProvider<SongSearchNotifier, AsyncValue<List<SongDomainModel>>>((ref) {
  return SongSearchNotifier(ref);
});
