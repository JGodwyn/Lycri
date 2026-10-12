import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../features/operator/models/lyrics_segment.dart';
import '../../features/operator/segmentation/lyrics_segmenter.dart';
import '../../features/operator/segmentation/text_similarity.dart';
import '../../features/library/models/song_domain_model.dart';
import '../../features/library/providers/database_provider.dart';
import 'active_line_provider.dart';

/// Shared lyrics state — `null` means no lyrics sent yet,
/// a non-null [String] means lyrics are active and should be displayed.
final lyricsProvider = StateNotifierProvider<LyricsNotifier, String?>(
  (ref) => LyricsNotifier(),
);

/// Derived provider that splits raw lyrics into individual non-empty lines.
final lyricsLinesProvider = Provider<List<String>>((ref) {
  final raw = ref.watch(lyricsProvider);
  if (raw == null) return [];
  return raw.split('\n').where((l) => l.trim().isNotEmpty).toList();
});

/// Provider for structured, segmented lyrics (Verses/Choruses).
final segmentedLyricsProvider =
    StateNotifierProvider<SegmentedLyricsNotifier, SegmentedLyricsState>(
      (ref) => SegmentedLyricsNotifier(ref),
    );

class LyricsNotifier extends StateNotifier<String?> {
  LyricsNotifier() : super(null);

  void send(String text) {
    final trimmed = text.trim();
    if (trimmed.isNotEmpty) state = trimmed;
  }

  void update(String text) {
    state = text.isEmpty ? null : text;
  }

  void clear() => state = null;
}

class SegmentedLyricsNotifier extends StateNotifier<SegmentedLyricsState> {
  final Ref _ref;
  static const _uuid = Uuid();

  /// Cached segmented state from the last cleanup session.
  List<LyricsSegment>? _cachedSegments;

  SegmentedLyricsNotifier(this._ref) : super(SegmentedLyricsState.initial());

  /// Segments the raw lyrics into sections (see [LyricsSegmenter]).
  /// If a cached state exists, merges edits into it to preserve metadata.
  ///
  /// Edits to a lyric that's already in the library ([songId] set) are saved
  /// automatically once segmented; new lyrics still need an explicit save.
  Future<void> cleanup() async {
    final rawText = _ref.read(lyricsProvider);
    if (rawText == null || rawText.trim().isEmpty) return;

    final sections = LyricsSegmenter.segment(rawText, title: state.songTitle);
    if (sections.isEmpty) return;

    // Push the cleaned text back so the raw view shows stripped lyrics.
    _ref
        .read(lyricsProvider.notifier)
        .update(sections.map((s) => s.text).join('\n\n'));

    // Always enter the loading state so the pulse animation fires
    state = state.copyWith(isLoading: true);

    final hasCache = _cachedSegments != null && _cachedSegments!.isNotEmpty;
    // Brief delay to ensure the UI pulse animation actually runs and looks
    // intentional; shorter when re-segmenting an edit.
    await Future.delayed(Duration(milliseconds: hasCache ? 600 : 1500));

    final segments =
        hasCache ? _mergeWithCache(sections) : _toSegments(sections);
    state = state.copyWith(
      segments: segments,
      isSegmented: true,
      isLoading: false,
      isEditing: false,
    );
    _syncToRaw();
    await _autoSaveIfInLibrary();
  }

  Future<void> _autoSaveIfInLibrary() async {
    if (state.songId != null) await saveLyric(state.songTitle);
  }

  List<LyricsSegment> _toSegments(List<SegmentedSection> sections) =>
      _renumber([
        for (final s in sections)
          LyricsSegment(
            id: '${_uuid.v4()}_${s.type.name}',
            text: s.text,
            type: s.type,
            number: 0,
            label: s.label,
          ),
      ]);

  /// Numbers segments in order within each type (Verse 1, Verse 2, …).
  static List<LyricsSegment> _renumber(List<LyricsSegment> segments) {
    final counts = <LyricsSegmentType, int>{};
    return [
      for (final s in segments)
        s.copyWith(number: counts[s.type] = (counts[s.type] ?? 0) + 1),
    ];
  }

  /// Merges freshly segmented text into the cached segments, preserving
  /// metadata (id, type, custom name, isHidden) for sections that match
  /// cached content. A label typed into the text ("[Bridge]") overrides the
  /// cached type.
  List<LyricsSegment> _mergeWithCache(List<SegmentedSection> sections) {
    final cache = _cachedSegments!;
    final usedCacheIndices = <int>{};
    final result = <LyricsSegment>[];

    for (var f = 0; f < sections.length; f++) {
      final section = sections[f];
      int bestIndex = -1;
      double bestScore = 0.4;

      for (int i = 0; i < cache.length; i++) {
        if (usedCacheIndices.contains(i)) continue;
        final score = TextSimilarity.blockSimilarity(
          section.text,
          cache[i].text,
        );
        // Identical repeats (choruses): prefer the one in the same position.
        final closer =
            score == bestScore &&
            bestIndex != -1 &&
            (i - f).abs() < (bestIndex - f).abs();
        if (score > bestScore || closer) {
          bestScore = score;
          bestIndex = i;
        }
      }

      if (bestIndex == -1) {
        result.addAll(_toSegments([section]));
        continue;
      }
      usedCacheIndices.add(bestIndex);
      final cached = cache[bestIndex];
      result.add(
        cached.copyWith(
          text: section.text,
          type: section.isExplicit ? section.type : null,
          label: cached.label ?? section.label,
        ),
      );
    }

    return _renumber(result);
  }

  /// Reverts back to raw text mode, caching the current segmented state.
  void reset() {
    // Cache the current segments (including hidden ones).
    if (state.segments.isNotEmpty) {
      _cachedSegments = List<LyricsSegment>.from(state.segments);
    }

    // Unhide all segments so their text is restored to the paste view.
    final hasHidden = state.segments.any((s) => s.isHidden);
    if (hasHidden) {
      final restored = [
        for (final s in state.segments)
          if (s.isHidden) s.copyWith(isHidden: false) else s,
      ];
      state = state.copyWith(segments: restored);
      _syncToRaw();
    }
    state = SegmentedLyricsState.initial();
  }

  /// Saves the current lyric segments to the database.
  Future<void> saveLyric([String? title]) async {
    final rawText = _ref.read(lyricsProvider) ?? '';

    final toSaveTitle = title ?? state.songTitle ?? 'Untitled';
    final songId = state.songId ?? _uuid.v4();

    // Regenerate segment IDs to prevent UNIQUE constraint collisions
    // if the user re-saves or saves multiple times.
    final freshSegments =
        state.segments.map((s) {
          return s.copyWith(id: '${_uuid.v4()}_${s.type.name}_${s.number}');
        }).toList();

    // We update the state to indicate it's saved. Save state doesn't need
    // loading indicators here; the UI handles the quick check transition.
    final model = SongDomainModel(
      id: songId,
      title: toSaveTitle,
      originalText: rawText,
      segments: freshSegments,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Persist to the local Drift database
    await _ref.read(songRepositoryProvider).saveSong(model);

    // Update the local state to show it's saved with the given title
    // Also store the newly generated segment IDs back in memory.
    state = state.copyWith(
      segments: freshSegments,
      songTitle: toSaveTitle,
      isSaved: true,
      songId: songId,
      originalSegments: freshSegments,
    );
  }

  /// Updates the song title in the current state and persists to database if already saved.
  /// Automatically resolves title collisions by appending/incrementing a number.
  Future<void> updateTitle(String newTitle) async {
    final trimmedTitle = newTitle.trim();
    if (trimmedTitle.isEmpty || state.songTitle == trimmedTitle) return;

    final repo = _ref.read(songRepositoryProvider);
    String candidate = trimmedTitle;
    int count = 1;

    // Resolve collisions with existing entries in the database.
    // If we're renaming an already saved song, we don't collision check against itself.
    while (await repo.doesTitleExist(candidate)) {
      // If the candidate matches our CURRENT name, we stop here (no real collision)
      if (candidate == state.songTitle) break;

      candidate = "$trimmedTitle $count";
      count++;
    }

    state = state.copyWith(songTitle: candidate);

    // Auto-save if it's already an identified song in the library
    if (state.songId != null) {
      await saveLyric(candidate);
    }
  }

  /// Called when the currently loaded song is deleted from the database.
  /// We keep the text but mark it as unsaved and remove its identity.
  void handleCurrentSongDeleted() {
    // We cannot use copyWith here because copyWith's `??` logic prevents
    // setting fields to null.
    state = SegmentedLyricsState(
      segments: state.segments,
      isSegmented: state.isSegmented,
      isLoading: false,
      songTitle: null,
      isSaved: false,
      songId: null,
      isEditing: state.isEditing,
      originalSegments: null,
    );
  }

  /// Loads an existing lyric from the database and jumps directly to segmented view.
  void loadSong(SongDomainModel song) {
    _cachedSegments = List.from(song.segments);
    state = SegmentedLyricsState(
      segments: song.segments,
      isSegmented: true,
      isLoading: false,
      songTitle: song.title,
      isSaved: true,
      songId: song.id,
      isEditing: false,
      originalSegments: song.segments,
    );
    _syncToRaw();
    _ref.read(activeLineProvider.notifier).jumpTo(0);
  }

  /// Switches to raw-text editing mode for an already saved lyric.
  void editSavedLyric() {
    // Cache the segments (just like `reset()` does)
    if (state.segments.isNotEmpty) {
      _cachedSegments = List<LyricsSegment>.from(state.segments);
    }

    // Ensure hidden text is visible in raw view
    final hasHidden = state.segments.any((s) => s.isHidden);
    if (hasHidden) {
      final restored = [
        for (final s in state.segments)
          if (s.isHidden) s.copyWith(isHidden: false) else s,
      ];
      state = state.copyWith(segments: restored);
      _syncToRaw();
    }

    // Go to un-segmented view but keep save info!
    state = state.copyWith(isSegmented: false, isEditing: true);
  }

  /// Cancels editing mode. Leaves the current text in the view but
  /// disconnects it from the saved lyric by dropping all edit metadata.
  void cancelEdit() {
    _cachedSegments = null;
    state = SegmentedLyricsState.initial();
  }

  /// Completely wipes all lyrics, clears the cache, and returns to bare view.
  void clearAll() {
    _cachedSegments = null;
    state = SegmentedLyricsState.initial();
    _ref.read(lyricsProvider.notifier).clear();
    _ref.read(activeLineProvider.notifier).jumpTo(0);
  }

  /// Updates a specific segment's text and syncs back to global lyricsProvider.
  void updateSegment(String id, String newText) {
    final newSegments = [
      for (final s in state.segments)
        if (s.id == id) s.copyWith(text: newText) else s,
    ];
    state = state.copyWith(segments: newSegments);
    _syncToRaw();
  }

  void toggleHideSegment(String id) {
    final oldSegments = state.segments;
    final activeIndex = _ref.read(activeLineProvider);

    // 1. Identify which segment and line the activeIndex currently points to
    String? currentSegId;
    int lineInSeg = 0;
    int currentOffset = 0;

    for (final s in oldSegments) {
      if (s.isHidden) continue;
      final count = s.lineCount;
      if (activeIndex >= currentOffset && activeIndex < currentOffset + count) {
        currentSegId = s.id;
        lineInSeg = activeIndex - currentOffset;
        break;
      }
      currentOffset += count;
    }

    // 2. Perform the toggle
    final newSegments = [
      for (final s in oldSegments)
        if (s.id == id) s.copyWith(isHidden: !s.isHidden) else s,
    ];
    state = state.copyWith(segments: newSegments);

    // 3. Recalculate correctly and update the activeLineProvider synchronously
    int newActiveIndex = -1;
    if (currentSegId != null) {
      int newOffset = 0;
      LyricsSegment? activeSeg;
      int activeSegIdx = -1;

      for (int i = 0; i < newSegments.length; i++) {
        final s = newSegments[i];
        if (s.id == currentSegId) {
          activeSeg = s;
          activeSegIdx = i;
          if (!s.isHidden) {
            newActiveIndex = newOffset + lineInSeg;
          }
          break;
        }
        if (!s.isHidden) {
          newOffset += s.lineCount;
        }
      }

      // If the segment we were on is now hidden, jump to next/prev visible
      if (newActiveIndex == -1 && activeSeg != null) {
        int nextVisibleOffset = newOffset;
        bool foundNext = false;
        for (int i = activeSegIdx + 1; i < newSegments.length; i++) {
          final s = newSegments[i];
          if (!s.isHidden) {
            newActiveIndex = nextVisibleOffset;
            foundNext = true;
            break;
          }
          nextVisibleOffset += s.lineCount;
        }

        if (!foundNext) {
          int lastVisibleIndex = -1;
          int runningOffset = 0;
          for (int i = 0; i < activeSegIdx; i++) {
            final s = newSegments[i];
            if (!s.isHidden) {
              lastVisibleIndex = runningOffset + s.lineCount - 1;
            }
            runningOffset += s.lineCount;
          }
          newActiveIndex = lastVisibleIndex != -1 ? lastVisibleIndex : 0;
        }
      }
    }

    // 4. Sync raw text FIRST so all listeners see the new lyrics when
    //    activeLineProvider fires.
    _syncToRaw();

    // 5. Now update the active line — listeners will see correct lyrics.
    if (newActiveIndex != -1) {
      _ref.read(activeLineProvider.notifier).jumpTo(newActiveIndex);
      // Force scroll-to-active for views that only listen to this trigger.
      _ref.read(scrollToActiveTriggerProvider.notifier).state++;
    }
  }

  /// Toggles a segment between chorus and its previous type (defaults to verse).
  void toggleChorus(String id) {
    final newSegments = [
      for (final s in state.segments)
        if (s.id == id)
          s.copyWith(
            type:
                s.type == LyricsSegmentType.chorus
                    ? LyricsSegmentType.verse
                    : LyricsSegmentType.chorus,
          )
        else
          s,
    ];
    state = state.copyWith(segments: newSegments);
  }

  /// Removes a segment entirely and maintains active line stability.
  void removeSegment(String id) {
    final oldSegments = state.segments;
    final activeIndex = _ref.read(activeLineProvider);

    // 1. Determine the current active segment before removal.
    String? currentSegId;
    int lineInSeg = 0;
    int currentOffset = 0;

    for (final s in oldSegments) {
      if (s.isHidden) continue;
      final count = s.lineCount;
      if (activeIndex >= currentOffset && activeIndex < currentOffset + count) {
        currentSegId = s.id;
        lineInSeg = activeIndex - currentOffset;
        break;
      }
      currentOffset += count;
    }

    // 2. Remove the segment.
    final newSegments = oldSegments.where((s) => s.id != id).toList();
    if (newSegments.isEmpty) {
      // If all segments are removed, reset to paste view.
      state = SegmentedLyricsState.initial();
      _ref.read(lyricsProvider.notifier).clear();
      return;
    }
    state = state.copyWith(segments: newSegments);

    // 3. Recalculate active line index.
    int newActiveIndex = 0;
    if (currentSegId == id) {
      // The active segment was removed — jump to the first visible line.
      int offset = 0;
      for (final s in newSegments) {
        if (!s.isHidden && s.lineCount > 0) {
          newActiveIndex = offset;
          break;
        }
        if (!s.isHidden) offset += s.lineCount;
      }
    } else if (currentSegId != null) {
      // Active segment still exists — find its new offset.
      int offset = 0;
      for (final s in newSegments) {
        if (s.id == currentSegId) {
          newActiveIndex = offset + lineInSeg;
          break;
        }
        if (!s.isHidden) offset += s.lineCount;
      }
    }

    // 4. Sync and update selection.
    _syncToRaw();
    _ref.read(activeLineProvider.notifier).jumpTo(newActiveIndex);
    _ref.read(scrollToActiveTriggerProvider.notifier).state++;
  }

  /// Sets a segment's custom name; blank restores the default name.
  void renameSegment(String id, String name) {
    final trimmed = name.trim();
    state = state.copyWith(
      segments: [
        for (final s in state.segments)
          if (s.id == id)
            s.copyWith(label: trimmed, clearLabel: trimmed.isEmpty)
          else
            s,
      ],
    );
  }

  /// Inserts an empty verse at [index] and returns its id. Nothing is synced
  /// until it gets text — empty segments are left out of the raw lyrics.
  String insertSegment(int index) {
    final number =
        state.segments.where((s) => s.type == LyricsSegmentType.verse).length +
        1;
    final segment = LyricsSegment(
      id: '${_uuid.v4()}_verse_$number',
      text: '',
      type: LyricsSegmentType.verse,
      number: number,
    );
    final list = List<LyricsSegment>.from(state.segments)
      ..insert(index.clamp(0, state.segments.length), segment);
    state = state.copyWith(segments: list);
    return segment.id;
  }

  /// Reorders segments and syncs back to global lyricsProvider.
  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final list = List<LyricsSegment>.from(state.segments);
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    state = state.copyWith(segments: list);
    _syncToRaw();
  }

  /// Synchronizes the segmented order/content back to the raw lyricsProvider.
  void _syncToRaw() {
    final combined = state.segments
        .where((s) => !s.isHidden && s.text.trim().isNotEmpty)
        .map((s) => s.text.trim())
        .join('\n\n');
    _ref.read(lyricsProvider.notifier).update(combined);
  }
}
