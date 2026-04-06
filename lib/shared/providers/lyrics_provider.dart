import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../features/operator/models/lyrics_segment.dart';
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

  /// Triggers the intelligent cleanup/segmentation process.
  /// If a cached state exists, merges edits into it to preserve metadata.
  Future<void> cleanup() async {
    final rawText = _ref.read(lyricsProvider);
    if (rawText == null || rawText.isEmpty) return;

    // Pre-process: strip [Chorus], [Verse], etc. and clean up whitespace.
    final cleanedText = _preprocessText(rawText);
    if (cleanedText.isEmpty) return;

    // Push the cleaned text back so the raw view shows stripped lyrics.
    _ref.read(lyricsProvider.notifier).update(cleanedText);

    // Always enter the loading state so the pulse animation fires
    state = state.copyWith(isLoading: true);

    // If we have a cache, merge the (possibly edited) text into it.
    if (_cachedSegments != null && _cachedSegments!.isNotEmpty) {
      // Brief delay to ensure the UI pulse animation actually runs and looks intentional
      await Future.delayed(const Duration(milliseconds: 600));

      final merged = _mergeWithCache(cleanedText);
      state = state.copyWith(
        segments: merged,
        isSegmented: true,
        isLoading: false,
      );
      _syncToRaw();
      return;
    }

    // No cache — fresh segmentation.
    await Future.delayed(const Duration(milliseconds: 1500));

    final segments = _segmentLyrics(cleanedText);
    state = state.copyWith(
      segments: segments,
      isSegmented: true,
      isLoading: false,
    );
  }

  /// Merges new raw text into cached segments, preserving metadata
  /// (isHidden, type) for blocks that match cached content.
  /// Uses _segmentLyrics for smart splitting (including elastic snapping),
  /// then overlays cached metadata on matched segments.
  List<LyricsSegment> _mergeWithCache(String newRawText) {
    // Run full segmentation logic (elastic snapping, chorus detection, etc.).
    final freshSegments = _segmentLyrics(newRawText);
    if (freshSegments.isEmpty) return [];

    final usedCacheIndices = <int>{};
    final result = <LyricsSegment>[];

    for (final segment in freshSegments) {
      int bestIndex = -1;
      double bestScore = 0.0;

      for (int i = 0; i < _cachedSegments!.length; i++) {
        if (usedCacheIndices.contains(i)) continue;
        final score = _textSimilarity(segment.text, _cachedSegments![i].text);
        if (score > bestScore && score > 0.4) {
          bestScore = score;
          bestIndex = i;
        }
      }

      if (bestIndex != -1) {
        // Matched — preserve cached metadata (type, isHidden), update text.
        usedCacheIndices.add(bestIndex);
        result.add(_cachedSegments![bestIndex].copyWith(text: segment.text));
      } else {
        // No cache match — keep the freshly-detected segment as-is.
        result.add(segment);
      }
    }

    return result;
  }

  /// Calculates similarity between two text blocks (0.0 – 1.0)
  /// using fuzzy line matching via normalized Levenshtein distance.
  /// A line is considered a match if its edit distance ≤ 20% (per SMAP 2013).
  double _textSimilarity(String a, String b) {
    final linesA =
        a.split('\n').map((l) => _normalizeLine(l)).where((l) => l.isNotEmpty).toList();
    final linesB =
        b.split('\n').map((l) => _normalizeLine(l)).where((l) => l.isNotEmpty).toList();
    if (linesA.isEmpty && linesB.isEmpty) return 1.0;
    if (linesA.isEmpty || linesB.isEmpty) return 0.0;

    int matches = 0;
    final usedB = <int>{};
    for (final lineA in linesA) {
      double bestDist = 1.0;
      int bestIdx = -1;
      for (int j = 0; j < linesB.length; j++) {
        if (usedB.contains(j)) continue;
        final dist = _normalizedLevenshtein(lineA, linesB[j]);
        if (dist < bestDist) {
          bestDist = dist;
          bestIdx = j;
        }
      }
      if (bestDist <= 0.2 && bestIdx != -1) {
        matches++;
        usedB.add(bestIdx);
      }
    }
    final maxLen = linesA.length > linesB.length ? linesA.length : linesB.length;
    return matches / maxLen;
  }

  /// Normalizes a line for comparison: lowercase, strip punctuation.
  static String _normalizeLine(String line) {
    return line.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), '');
  }

  /// Normalized Levenshtein distance (0.0 = identical, 1.0 = completely different).
  /// Standard DP edit-distance divided by the length of the longer string.
  static double _normalizedLevenshtein(String a, String b) {
    if (a == b) return 0.0;
    if (a.isEmpty) return 1.0;
    if (b.isEmpty) return 1.0;

    final m = a.length;
    final n = b.length;
    // Use single-row DP for memory efficiency.
    var prev = List<int>.generate(n + 1, (j) => j);
    var curr = List<int>.filled(n + 1, 0);

    for (int i = 1; i <= m; i++) {
      curr[0] = i;
      for (int j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = min(min(curr[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[n] / max(m, n);
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
  Future<void> saveLyric(String title) async {
    final rawText = _ref.read(lyricsProvider) ?? '';
    
    // Regenerate segment IDs to prevent UNIQUE constraint collisions
    // if the user re-saves or saves multiple times.
    final freshSegments = state.segments.map((s) {
      return s.copyWith(id: '${_uuid.v4()}_${s.type.name}_${s.number}');
    }).toList();

    // We update the state to indicate it's saved. Save state doesn't need
    // loading indicators here; the UI handles the quick check transition.
    final model = SongDomainModel(
      id: _uuid.v4(),
      title: title,
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
      songTitle: title,
      isSaved: true,
    );
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
    final combined =
        state.segments
            .where((s) => !s.isHidden)
            .map((s) => s.text.trim())
            .join('\n\n');
    _ref.read(lyricsProvider.notifier).update(combined);
  }

  /// Regex matching structural section tags: [Chorus], [Verse 1], (Bridge), etc.
  /// Used both for label detection and for stripping from output text.
  static final _sectionTagPattern = RegExp(
    r'\[\s*(?:verse|chorus|hook|bridge|intro|outro|pre[- ]?chorus|refrain|lift|break|interlude|instrumental|solo|tag|coda|ad[- ]?lib)(?:\s*\d*)\s*\]'
    r'|'
    r'\(\s*(?:verse|chorus|hook|bridge|intro|outro|pre[- ]?chorus|refrain|lift|break|interlude|instrumental|solo|tag|coda|ad[- ]?lib)(?:\s*\d*)\s*\)',
    caseSensitive: false,
  );

  /// Pre-processes raw lyrics text before segmentation:
  /// 1. Strips all bracketed/parenthesized section tags ([Chorus], (Verse 2), etc.)
  /// 2. Collapses runs of blank lines into a single blank line
  /// 3. Trims trailing whitespace from each line
  String _preprocessText(String rawText) {
    // Strip section tags (both standalone and inline).
    var cleaned = rawText.replaceAll(_sectionTagPattern, '');

    // Normalize each line: trim trailing whitespace.
    final lines = cleaned.split('\n').map((l) => l.trimRight()).toList();

    // Collapse multiple consecutive blank lines into one.
    final result = <String>[];
    bool lastWasBlank = false;
    for (final line in lines) {
      if (line.trim().isEmpty) {
        if (!lastWasBlank) {
          result.add('');
          lastWasBlank = true;
        }
      } else {
        result.add(line);
        lastWasBlank = false;
      }
    }

    return result.join('\n').trim();
  }

  /// Calculates fuzzy block similarity (0.0 – 1.0) for chorus grouping.
  /// Uses normalized Levenshtein on the full block text.
  double _blockSimilarity(String a, String b) {
    final na = _normalizeLine(a);
    final nb = _normalizeLine(b);
    if (na.isEmpty && nb.isEmpty) return 1.0;
    if (na.isEmpty || nb.isEmpty) return 0.0;
    return 1.0 - _normalizedLevenshtein(na, nb);
  }

  /// Intelligent logic to split text into structured song sections.
  /// Pre-processes text to strip section tags, then uses fuzzy
  /// repetition detection (Levenshtein ≤ 20%) to auto-identify choruses.
  List<LyricsSegment> _segmentLyrics(String rawText) {
    if (rawText.trim().isEmpty) return [];

    // Pre-process: strip [Chorus], [Verse], etc. and normalize whitespace.
    final cleanedText = _preprocessText(rawText);
    if (cleanedText.isEmpty) return [];

    final lines = cleanedText.split('\n');
    final rawBlocks = <_RawBlock>[];
    var currentLines = <String>[];
    String? currentLabel;

    for (var line in lines) {
      final t = line.trim();
      if (t.isEmpty) {
        if (currentLines.isNotEmpty || currentLabel != null) {
          rawBlocks.addAll(_createLyricalBlocks(currentLines, currentLabel));
          currentLines = [];
          currentLabel = null;
        }
        continue;
      }

      // Check if line is an explicit structural label (e.g. [Chorus], (Verse 1))
      // After pre-processing these should already be stripped, but handle edge cases.
      if (_isExplicitLabel(t)) {
        if (currentLines.isNotEmpty || currentLabel != null) {
          rawBlocks.addAll(_createLyricalBlocks(currentLines, currentLabel));
          currentLines = [];
        }
        currentLabel = t.replaceAll(RegExp(r'[\[\]()]'), '').trim();
      } else {
        currentLines.add(t);
      }
    }
    if (currentLines.isNotEmpty || currentLabel != null) {
      rawBlocks.addAll(_createLyricalBlocks(currentLines, currentLabel));
    }

    if (rawBlocks.isEmpty) return [];

    // --- Fuzzy chorus detection (SMAP 2013 approach) ---
    // Group blocks by similarity: blocks with ≥ 80% similarity are in the
    // same group. Groups with 2+ members are auto-tagged as choruses.
    final chorusIndices = <int>{};
    final grouped = <int>{}; // Tracks blocks already assigned to a group.

    for (int i = 0; i < rawBlocks.length; i++) {
      if (grouped.contains(i) || rawBlocks[i].explicitLabel != null) continue;
      final group = <int>[i];
      for (int j = i + 1; j < rawBlocks.length; j++) {
        if (grouped.contains(j) || rawBlocks[j].explicitLabel != null) continue;
        final sim = _blockSimilarity(rawBlocks[i].text, rawBlocks[j].text);
        if (sim >= 0.8) {
          group.add(j);
        }
      }
      if (group.length >= 2) {
        chorusIndices.addAll(group);
        grouped.addAll(group);
      }
    }

    final segments = <LyricsSegment>[];
    final counts = <LyricsSegmentType, int>{};

    for (int i = 0; i < rawBlocks.length; i++) {
      final block = rawBlocks[i];
      LyricsSegmentType type = LyricsSegmentType.verse;

      if (block.explicitLabel != null) {
        type = _labelToType(block.explicitLabel!);
      } else if (chorusIndices.contains(i)) {
        type = LyricsSegmentType.chorus;
      } else if (i == 0 && block.lineCount <= 2) {
        type = LyricsSegmentType.intro;
      } else if (i == rawBlocks.length - 1 && block.lineCount <= 2) {
        type = LyricsSegmentType.outro;
      } else if (i < rawBlocks.length - 1 && 
                 segments.isNotEmpty && 
                 chorusIndices.contains(i + 1)) {
        type = block.lineCount <= 4 ? LyricsSegmentType.preChorus : LyricsSegmentType.bridge;
      }

      counts[type] = (counts[type] ?? 0) + 1;
      segments.add(LyricsSegment(
        id: '${_uuid.v4()}_${type.name}_${counts[type]}',
        text: block.text,
        type: type,
        number: counts[type]!,
      ));
    }
    return segments;
  }

  /// Elastic Snapping algorithm: Splits lines into blocks by finding the most
  /// "lyrical" break points. Uses rhyme preservation, rhythmic balance, and
  /// content-shift detection to find natural stanza boundaries.
  List<_RawBlock> _createLyricalBlocks(List<String> lines, String? explicitLabel) {
    if (lines.isEmpty) {
      return explicitLabel != null ? [_RawBlock(text: '', explicitLabel: explicitLabel)] : [];
    }

    // Max stanza size for presentation (8 lines fits most screens well).
    const maxStanza = 8;

    final blocks = <_RawBlock>[];
    int start = 0;

    while (start < lines.length) {
      final remaining = lines.length - start;
      if (remaining <= maxStanza) {
        // Last block: small enough to keep whole.
        final stanza = lines.sublist(start).join('\n');
        blocks.add(_RawBlock(text: stanza, explicitLabel: start == 0 ? explicitLabel : null));
        break;
      }

      // Elastic Window: Score split points between lines 3 and maxStanza.
      int bestSplitOffset = 4; // Default to couplet-aligned (4 lines).
      double bestScore = -100.0;

      for (int offset = 3; offset <= maxStanza; offset++) {
        final currentPoint = start + offset;
        if (currentPoint >= lines.length) break;

        double score = 0.0;

        // 1. Even line count bonus (couplet-aligned / rhythmic balance).
        if (offset % 2 == 0) score += 2.0;

        // 2. Proximity to ideal stanza size (4 lines = one quatrain).
        //    Biases toward 4-line stanzas but allows up to maxStanza.
        score += (4.0 - (offset - 4).abs()) * 1.5;

        // 3. Rhyme Preservation (Highest Priority)
        final lineBefore = lines[currentPoint - 1];
        final lineTwoBefore = currentPoint > 1 ? lines[currentPoint - 2] : null;
        final nextLine = lines[currentPoint];

        final isCoupletEnd = lineTwoBefore != null && _RhymeAnalyzer.isRhyme(lineBefore, lineTwoBefore);
        final breaksCouplet = _RhymeAnalyzer.isRhyme(lineBefore, nextLine);

        if (isCoupletEnd) score += 5.0; // Ends on a satisfying rhyme.
        if (breaksCouplet) score -= 8.0; // DON'T split here if it breaks a rhyme!

        // 4. Content-shift signal: if the vocabulary between the line before
        //    and the line after the split is very different, there's likely a
        //    natural section change (e.g., verse → refrain). Reward that.
        final wordsBefore = _normalizeLine(lineBefore).split(RegExp(r'\s+')).toSet();
        final wordsAfter = _normalizeLine(nextLine).split(RegExp(r'\s+')).toSet();
        if (wordsBefore.isNotEmpty && wordsAfter.isNotEmpty) {
          final overlap = wordsBefore.intersection(wordsAfter).length;
          final maxWords = max(wordsBefore.length, wordsAfter.length);
          final similarity = overlap / maxWords;
          // Low overlap → likely a section change → bonus.
          if (similarity < 0.15) score += 3.0;
        }

        if (score > bestScore) {
          bestScore = score;
          bestSplitOffset = offset;
        }
      }

      final stanza = lines.sublist(start, start + bestSplitOffset).join('\n');
      blocks.add(_RawBlock(text: stanza, explicitLabel: start == 0 ? explicitLabel : null));
      start += bestSplitOffset;
    }
    return blocks;
  }

  bool _isExplicitLabel(String line) {
    final t = line.trim();
    if (!(RegExp(r'^\[.*\]$').hasMatch(t) || RegExp(r'^\(.*\)$').hasMatch(t))) {
      return false;
    }

    final content = t.replaceAll(RegExp(r'[\[\]()]'), '').toLowerCase();
    // A label must contain a songwriting keyword to be considered structural.
    const keywords = [
      'verse',
      'chorus',
      'hook',
      'bridge',
      'intro',
      'outro',
      'pre',
      'lift',
      'break',
      'refrain',
    ];
    return keywords.any((k) => content.contains(k));
  }

  LyricsSegmentType _labelToType(String label) {
    final l = label.toLowerCase();
    if (l.contains('chorus') || l.contains('hook') || l.contains('refrain')) {
      return LyricsSegmentType.chorus;
    }
    if (l.contains('intro')) return LyricsSegmentType.intro;
    if (l.contains('outro')) return LyricsSegmentType.outro;
    if (l.contains('pre')) return LyricsSegmentType.preChorus;
    if (l.contains('bridge') || l.contains('break')) {
      return LyricsSegmentType.bridge;
    }
    return LyricsSegmentType.verse;
  }
}

/// Offline Phonetic Heuristic to identify rhymes and vowel patterns.
class _RhymeAnalyzer {
  static bool isRhyme(String l1, String l2) {
    final w1 = _clean(l1.split(' ').last);
    final w2 = _clean(l2.split(' ').last);
    if (w1.length < 2 || w2.length < 2) return false;

    // Perfect suffix match (last 2-3 chars)
    if (w1.endsWith(w2.substring(w2.length - (w2.length >= 3 ? 3 : 2))) ||
        w2.endsWith(w1.substring(w1.length - (w1.length >= 3 ? 3 : 2)))) {
      return true;
    }

    // Slant rhyme check: Vowel pattern match
    final v1 = _extractVowels(w1);
    final v2 = _extractVowels(w2);
    if (v1.length >= 1 && v1 == v2) return true;

    return false;
  }

  static String _clean(String w) => w.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

  static String _extractVowels(String w) {
    final vowels = RegExp(r'[aeiouy]+');
    final matches = vowels.allMatches(w);
    if (matches.isEmpty) return '';
    return matches.last.group(0)!; // Focus on the last vowel sound
  }
}

class _RawBlock {
  final String text;
  final String? explicitLabel;

  _RawBlock({required this.text, this.explicitLabel});

  int get lineCount => text.split('\n').where((l) => l.trim().isNotEmpty).length;
}
