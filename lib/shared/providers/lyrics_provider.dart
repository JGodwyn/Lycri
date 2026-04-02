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

    // Simulate thinking/processing time for a "nice" feel.
    await Future.delayed(const Duration(milliseconds: 800));

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

  /// Heuristic logic to split text into Verses and Choruses.
  List<LyricsSegment> _segmentLyrics(String rawText) {
    final blocks = rawText
        .split(RegExp(r'\n\s*\n'))
        .where((b) => b.trim().isNotEmpty)
        .map((b) => b.trim())
        .toList();

    if (blocks.isEmpty) return [];

    final segments = <LyricsSegment>[];
    int verseCount = 0;
    int chorusCount = 0;

    // 1. Basic tagging by keywords.
    // 2. Identify repeating blocks as choruses.
    final blockFrequency = <String, int>{};
    for (final b in blocks) {
      blockFrequency[b] = (blockFrequency[b] ?? 0) + 1;
    }

    // A block is a chorus if it repeats OR starts with "Chorus".
    final chorusTexts =
        blockFrequency.entries
            .where((e) => e.value > 1)
            .map((e) => e.key)
            .toSet();

    for (final block in blocks) {
      final isChorusHeader =
          block.toLowerCase().startsWith('chorus') ||
          block.toLowerCase().startsWith('[chorus]');

      final actualText =
          isChorusHeader
              ? block.replaceFirst(RegExp(r'^\[?chorus\]?:?\s*', caseSensitive: false), '').trim()
              : block;

      final isChorus = isChorusHeader || chorusTexts.contains(actualText);

      if (isChorus) {
        chorusCount++;
        segments.add(
          LyricsSegment(
            id: _uuid.v4(),
            text: actualText,
            type: LyricsSegmentType.chorus,
            number: chorusCount,
          ),
        );
      } else {
        verseCount++;
        segments.add(
          LyricsSegment(
            id: _uuid.v4(),
            text: actualText,
            type: LyricsSegmentType.verse,
            number: verseCount,
          ),
        );
      }
    }

    return segments;
  }
}
