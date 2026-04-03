import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../features/operator/models/lyrics_segment.dart';

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

  SegmentedLyricsNotifier(this._ref) : super(SegmentedLyricsState.initial());

  /// Triggers the intelligent cleanup/segmentation process.
  Future<void> cleanup() async {
    final rawText = _ref.read(lyricsProvider);
    if (rawText == null || rawText.isEmpty) return;

    state = state.copyWith(isLoading: true);

    // Simulate deep structural thinking/processing time.
    await Future.delayed(const Duration(milliseconds: 1500));

    final segments = _segmentLyrics(rawText);

    state = state.copyWith(
      segments: segments,
      isSegmented: true,
      isLoading: false,
    );
  }

  /// Reverts back to raw text mode.
  void reset() {
    state = SegmentedLyricsState.initial();
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
    final combined = state.segments.map((s) => s.text.trim()).join('\n\n');
    _ref.read(lyricsProvider.notifier).update(combined);
  }

  /// Intelligent logic to split text into structured song sections.
  List<LyricsSegment> _segmentLyrics(String rawText) {
    if (rawText.trim().isEmpty) return [];

    final lines = rawText.split('\n');
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
      // It MUST match the pattern AND contain a known section keyword to be a label.
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

    final blockStrings = rawBlocks.map((b) => b.text.toLowerCase().trim()).toList();
    final frequency = <String, int>{};
    for (var s in blockStrings) {
      frequency[s] = (frequency[s] ?? 0) + 1;
    }
    final chorusTexts = frequency.entries.where((e) => e.value > 1).map((e) => e.key).toSet();

    final segments = <LyricsSegment>[];
    final counts = <LyricsSegmentType, int>{};

    for (int i = 0; i < rawBlocks.length; i++) {
      final block = rawBlocks[i];
      final normText = block.text.toLowerCase().trim();
      LyricsSegmentType type = LyricsSegmentType.verse;

      if (block.explicitLabel != null) {
        type = _labelToType(block.explicitLabel!);
      } else if (chorusTexts.contains(normText)) {
        type = LyricsSegmentType.chorus;
      } else if (i == 0 && block.lineCount <= 2) {
        type = LyricsSegmentType.intro;
      } else if (i == rawBlocks.length - 1 && block.lineCount <= 2) {
        type = LyricsSegmentType.outro;
      } else if (i < rawBlocks.length - 1 && 
                 segments.length > 0 && 
                 chorusTexts.contains(rawBlocks[i + 1].text.toLowerCase().trim())) {
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

  /// Elastic Snapping algorithm: Splits lines into blocks by finding the most "Lyrical" break points.
  List<_RawBlock> _createLyricalBlocks(List<String> lines, String? explicitLabel) {
    if (lines.isEmpty) {
      return explicitLabel != null ? [_RawBlock(text: '', explicitLabel: explicitLabel)] : [];
    }

    final blocks = <_RawBlock>[];
    int start = 0;

    while (start < lines.length) {
      final remaining = lines.length - start;
      if (remaining <= 10) {
        // Last block: no need to score, just take it all.
        final stanza = lines.sublist(start).join('\n');
        blocks.add(_RawBlock(text: stanza, explicitLabel: start == 0 ? explicitLabel : null));
        break;
      }

      // Elastic Window: Scan potential split points between lines 4 and 10.
      int bestSplitOffset = 8;
      double bestScore = -1.0;

      for (int offset = 4; offset <= 10; offset++) {
        final currentPoint = start + offset;
        if (currentPoint >= lines.length) break;

        double score = 0.0;
        
        // 1. Even line count bonus (rhythmic balance)
        if (offset % 2 == 0) score += 2.0;

        // 2. Rhyme Preservation (Highest Priority)
        // Check if splitting AT the current point breaks a rhyme couplet (i-1 vs i)
        // Or if it completes a verse on a strong rhyme (i-1 vs i-2).
        final lineBefore = lines[currentPoint - 1];
        final lineTwoBefore = currentPoint > 1 ? lines[currentPoint - 2] : null;
        final nextLine = lines[currentPoint];

        final isCoupletEnd = lineTwoBefore != null && _RhymeAnalyzer.isRhyme(lineBefore, lineTwoBefore);
        final breaksCouplet = _RhymeAnalyzer.isRhyme(lineBefore, nextLine);
        
        if (isCoupletEnd) score += 5.0; // Ends on a satisfying rhyme
        if (breaksCouplet) score -= 8.0; // DON'T split here if it breaks a rhyme!

        // 3. Proximity to ideal size (8 lines)
        score += (8 - (offset - 8).abs()).toDouble();

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
