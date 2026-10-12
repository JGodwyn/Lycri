import 'dart:math';

import '../models/lyrics_segment.dart';
import 'lyrics_paste_parser.dart';
import 'section_label.dart';
import 'text_similarity.dart';

/// One section of a song as found by [LyricsSegmenter].
class SegmentedSection {
  const SegmentedSection({
    required this.text,
    required this.type,
    this.label,
    this.isExplicit = false,
  });

  final String text;
  final LyricsSegmentType type;

  /// Name from the paste when the type's own name doesn't fit ("Tag").
  final String? label;

  /// The type came from a label in the paste ("[Chorus]") rather than a
  /// guess.
  final bool isExplicit;
}

/// Splits pasted lyrics into song sections (verses, choruses, …).
///
/// 1. [LyricsPasteParser] cleans the paste and finds section labels.
/// 2. Lines are grouped into blocks at blank lines, labels and separators.
///    Double-spaced pastes (a blank after every line) are detected and their
///    single blanks ignored.
/// 3. Blocks are cut where a run of lines repeats elsewhere in the song (a
///    chorus glued to a verse), and anything still longer than [maxLines] is
///    split at the most natural points (rhyme, balance, content shift).
/// 4. Labelled blocks keep their type and lend it to blocks with the same
///    lyrics; the most repeated unlabelled block becomes the chorus, and
///    pre-chorus / bridge / intro / outro are inferred from position.
/// 5. Lyric-less labels ("Repeat Chorus", a bare "Chorus") are filled in
///    with the section they refer to.
abstract final class LyricsSegmenter {
  /// Longest section, in lines (8 fits most screens).
  static const maxLines = 8;

  static List<SegmentedSection> segment(String raw, {String? title}) {
    final tokens = LyricsPasteParser.parse(raw, title: title);
    var blocks = _buildBlocks(tokens);
    blocks = _splitBlocks(blocks);
    _classify(blocks);
    blocks = _resolveReferences(blocks);
    return [
      for (final b in blocks)
        SegmentedSection(
          text: b.lines.join('\n'),
          type: b.type!,
          label: b.label?.name,
          isExplicit: b.label != null,
        ),
    ];
  }

  // --- 2. Blocks ------------------------------------------------------------

  static List<_Block> _buildBlocks(List<PasteToken> tokens) {
    final doubleSpaced = _isDoubleSpaced(tokens);
    final blocks = <_Block>[];
    _Block? current;
    var blankRun = 0;

    void close() {
      final block = current;
      if (block != null && (block.lines.isNotEmpty || block.label != null)) {
        blocks.add(block);
      }
      current = null;
    }

    for (final token in tokens) {
      if (token is BlankLine) {
        blankRun++;
        continue;
      }
      if (blankRun > 0) {
        final block = current;
        // "Chorus" / blank / lyrics: the label still owns the lyrics, unless
        // it's a repeat marker that stands on its own.
        final labelAwaitingLyrics =
            block != null &&
            block.lines.isEmpty &&
            block.label != null &&
            !block.label!.isRepeat;
        final lineBreakOnly = doubleSpaced && blankRun == 1;
        if (!labelAwaitingLyrics && !lineBreakOnly) close();
        blankRun = 0;
      }
      switch (token) {
        case LyricLine(:final text):
          (current ??= _Block([])).lines.add(text);
        case LabelLine(:final label):
          close();
          current = _Block([], label: label);
        case SectionBreak():
          close();
        case BlankLine():
          break;
      }
    }
    close();
    return blocks;
  }

  /// A blank after (nearly) every line: pasted from a page that turned line
  /// breaks into paragraphs. Stanzas are then marked by 2+ blank lines.
  static bool _isDoubleSpaced(List<PasteToken> tokens) {
    var groups = 0;
    var singles = 0;
    var run = 0;
    void endGroup() {
      if (run == 0) return;
      groups++;
      if (run == 1) singles++;
      run = 0;
    }

    for (final token in tokens) {
      if (token is LyricLine) {
        run++;
      } else {
        endGroup();
      }
    }
    endGroup();
    return groups >= 6 && singles >= groups * 0.7;
  }

  // --- 3. Splitting -----------------------------------------------------------

  /// Shortest run of lines that counts as a repeated section.
  static const _minRun = 3;

  static List<_Block> _splitBlocks(List<_Block> blocks) {
    // Flatten every lyric line, remembering which block it came from.
    final lines = <String>[];
    final owner = <int>[];
    final blockStart = <int>[];
    for (var b = 0; b < blocks.length; b++) {
      blockStart.add(lines.length);
      lines.addAll(blocks[b].norm);
      owner.addAll(List.filled(blocks[b].lines.length, b));
    }

    final cuts = _repetitionCuts(lines, owner, blockStart, blocks);

    final result = <_Block>[];
    for (var b = 0; b < blocks.length; b++) {
      final block = blocks[b];
      if (block.lines.isEmpty) {
        result.add(block);
        continue;
      }
      final start = blockStart[b];
      final local = (cuts[b] ?? <int>{}).map((c) => c - start).toList()..sort();
      for (final piece in _cutAt(block.lines, local)) {
        for (final part in _splitLong(piece)) {
          result.add(_Block(part, label: block.label));
        }
      }
    }
    return result;
  }

  /// Finds runs of [_minRun]+ lines that repeat elsewhere and returns, per
  /// block, the line indices where a run starts or ends inside it.
  ///
  /// A block is only cut when that's clearly right: it's too long anyway, or
  /// the repeat elsewhere is a whole block of its own (a chorus pasted with
  /// blank lines once, and glued to a verse another time).
  static Map<int, Set<int>> _repetitionCuts(
    List<String> lines,
    List<int> owner,
    List<int> blockStart,
    List<_Block> blocks,
  ) {
    final n = lines.length;
    final cuts = <int, Set<int>>{};
    if (n < _minRun * 2) return cuts;

    bool same(int i, int j) => TextSimilarity.sameLine(lines[i], lines[j]);

    // run[i][j]: length of the matching run starting at lines i and j.
    final run = List.generate(n + 1, (_) => List<int>.filled(n + 1, 0));
    for (var i = n - 1; i >= 0; i--) {
      for (var j = n - 1; j > i; j--) {
        if (same(i, j)) run[i][j] = run[i + 1][j + 1] + 1;
      }
    }

    bool isWholeBlock(int start, int length) {
      final b = owner[start];
      return blockStart[b] == start && blocks[b].lines.length == length;
    }

    void addCut(int at) {
      if (at <= 0 || at >= n) return;
      final b = owner[at];
      if (blockStart[b] == at) return; // already a boundary
      (cuts[b] ??= {}).add(at);
    }

    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        final length = run[i][j];
        if (length < _minRun) continue;
        // Only the start of a maximal run.
        if (i > 0 && run[i - 1][j - 1] > 0) continue;
        // Overlapping copies are a line pattern, not a repeated section.
        if (j < i + length) continue;
        // "Hallelujah" ×4 isn't a section boundary either.
        if (lines.sublist(i, i + length).toSet().length < 2) continue;

        for (final (at, other) in [(i, j), (j, i)]) {
          final b = owner[at];
          final tooLong = blocks[b].lines.length > maxLines;
          if (tooLong || isWholeBlock(other, length)) {
            addCut(at);
            addCut(at + length);
          }
        }
      }
    }
    return cuts;
  }

  /// Cuts [lines] at [cuts], skipping cuts that would leave a single line.
  static List<List<String>> _cutAt(List<String> lines, List<int> cuts) {
    final pieces = <List<String>>[];
    var start = 0;
    for (final cut in cuts) {
      if (cut - start < 2 || lines.length - cut < 2) continue;
      pieces.add(lines.sublist(start, cut));
      start = cut;
    }
    pieces.add(lines.sublist(start));
    return pieces;
  }

  /// Splits a block longer than [maxLines] into stanzas of 2–[maxLines]
  /// lines, choosing the split points with the lowest total cost (dynamic
  /// programming, so a good early split can't strand a one-line tail).
  static List<List<String>> _splitLong(List<String> lines) {
    final n = lines.length;
    if (n <= maxLines) return [lines];

    final cost = List<double>.filled(n + 1, double.infinity);
    final from = List<int>.filled(n + 1, -1);
    cost[0] = 0;
    for (var end = 2; end <= n; end++) {
      for (var size = 2; size <= maxLines && size <= end; size++) {
        final start = end - size;
        if (cost[start] == double.infinity) continue;
        final c =
            cost[start] +
            _sizeCost(size) +
            (start > 0 ? _boundaryCost(lines, start) : 0);
        if (c < cost[end]) {
          cost[end] = c;
          from[end] = start;
        }
      }
    }

    final pieces = <List<String>>[];
    for (var end = n; end > 0; end = from[end]) {
      pieces.insert(0, lines.sublist(from[end], end));
    }
    return pieces;
  }

  /// Quatrains first, then other even sizes; tiny or odd stanzas cost more.
  static double _sizeCost(int size) => switch (size) {
    4 => 0,
    6 => 1,
    8 => 2,
    5 => 2,
    3 => 2.5,
    7 => 3,
    _ => 4,
  };

  /// Cost of a stanza break before `lines[at]`.
  static double _boundaryCost(List<String> lines, int at) {
    final before = lines[at - 1];
    final after = lines[at];
    var cost = 0.0;
    // Never split a rhyming couplet.
    if (_Rhyme.rhymes(before, after)) cost += 6;
    // Ending on a completed couplet / ABAB quatrain is natural.
    if (at >= 2 && _Rhyme.rhymes(lines[at - 2], before)) cost -= 2;
    if (at >= 3 && _Rhyme.rhymes(lines[at - 3], before)) cost -= 1.5;
    // A sentence carrying over the break.
    if (before.endsWith(',')) cost += 1;
    if (RegExp(r'[.!?]$').hasMatch(before)) cost -= 1;
    // Little shared vocabulary → likely a section change.
    final a = TextSimilarity.normalize(before).split(' ').toSet();
    final b = TextSimilarity.normalize(after).split(' ').toSet();
    if (a.isNotEmpty && b.isNotEmpty) {
      final overlap = a.intersection(b).length / max(a.length, b.length);
      if (overlap < 0.15) cost -= 2;
    }
    return cost;
  }

  // --- 4. Classification ------------------------------------------------------

  static void _classify(List<_Block> blocks) {
    final content = [
      for (var i = 0; i < blocks.length; i++)
        if (blocks[i].lines.isNotEmpty) i,
    ];

    // Group blocks with (nearly) the same lyrics.
    final groupOf = <int, List<int>>{};
    final parent = {for (final i in content) i: i};
    int root(int i) => parent[i] == i ? i : parent[i] = root(parent[i]!);
    for (var x = 0; x < content.length; x++) {
      for (var y = x + 1; y < content.length; y++) {
        if (_similar(blocks[content[x]], blocks[content[y]])) {
          parent[root(content[y])] = root(content[x]);
        }
      }
    }
    for (final i in content) {
      (groupOf[root(i)] ??= []).add(i);
    }
    final groups = groupOf.values.toList();

    // Labels win, and lend their type to unlabelled copies.
    for (final block in blocks) {
      block.type = block.label?.type;
    }
    for (final group in groups) {
      final labelled = [
        for (final i in group)
          if (blocks[i].label != null) blocks[i].label!.type,
      ];
      if (labelled.isEmpty) continue;
      final type = _mostCommon(labelled);
      for (final i in group) {
        blocks[i].type ??= type;
      }
    }

    // Unlabelled repeats: the most repeated becomes the chorus (if the
    // labels didn't name one), the rest go by position.
    final repeated =
        groups
            .where((g) => g.length > 1 && blocks[g.first].type == null)
            .toList()
          ..sort((a, b) => a.first.compareTo(b.first));
    if (!blocks.any((b) => b.type == LyricsSegmentType.chorus) &&
        repeated.isNotEmpty) {
      final chorus = repeated.reduce((a, b) {
        if (a.length != b.length) return a.length > b.length ? a : b;
        final linesA = _lineTotal(blocks, a);
        final linesB = _lineTotal(blocks, b);
        if (linesA != linesB) return linesA > linesB ? a : b;
        return a.first > b.first ? a : b; // a chorus follows its pre-chorus
      });
      for (final i in chorus) {
        blocks[i].type = LyricsSegmentType.chorus;
      }
      repeated.remove(chorus);
    }

    List<int> choruses() => [
      for (var i = 0; i < blocks.length; i++)
        if (blocks[i].type == LyricsSegmentType.chorus) i,
    ];

    for (final group in repeated) {
      final chorusAt = choruses();
      final type = _repeatedType(blocks, group, chorusAt);
      for (final i in group) {
        blocks[i].type = type;
      }
    }

    // Everything else appears once.
    final chorusAt = choruses();
    final secondChorus = chorusAt.length >= 2 ? chorusAt[1] : null;
    final verses = [
      for (var i = 0; i < blocks.length; i++)
        if (blocks[i].lines.isNotEmpty &&
            (blocks[i].type == LyricsSegmentType.verse ||
                (blocks[i].type == null &&
                    (secondChorus == null || i < secondChorus))))
          blocks[i],
    ];
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      if (block.type != null) continue;
      final isLast = i == blocks.length - 1;
      final short = block.lines.length <= 2 && blocks.length >= 3;
      if (i == 0 && short) {
        block.type = LyricsSegmentType.intro;
      } else if (isLast && short) {
        block.type = LyricsSegmentType.outro;
      } else if (secondChorus != null &&
          i > secondChorus &&
          _bridgeLike(block, verses.where((v) => v != block).toList())) {
        block.type = LyricsSegmentType.bridge;
      } else {
        block.type = LyricsSegmentType.verse;
      }
    }
  }

  /// Type for an unlabelled section that repeats but isn't the chorus.
  static LyricsSegmentType _repeatedType(
    List<_Block> blocks,
    List<int> group,
    List<int> chorusAt,
  ) {
    bool isChorus(int i) =>
        i >= 0 &&
        i < blocks.length &&
        blocks[i].type == LyricsSegmentType.chorus;

    // Always between a verse and the chorus.
    final leadsIntoChorus = group.every(
      (i) => isChorus(i + 1) && i > 0 && !isChorus(i - 1),
    );
    if (leadsIntoChorus && _lineTotal(blocks, group) / group.length <= 6) {
      return LyricsSegmentType.preChorus;
    }
    // Only turns up late, after the second chorus.
    if (chorusAt.length >= 2 && group.first > chorusAt[1]) {
      return LyricsSegmentType.bridge;
    }
    // A verse sung again ("Verse 1" reprised at the end).
    if (chorusAt.isEmpty || group.first < chorusAt.first) {
      return LyricsSegmentType.verse;
    }
    return LyricsSegmentType.chorus;
  }

  /// Bridges break the verse pattern: they repeat lines internally, or have
  /// a different length or line length than the verses.
  static bool _bridgeLike(_Block block, List<_Block> verses) {
    final norm = block.norm.where((l) => l.isNotEmpty).toList();
    for (var i = 0; i < norm.length; i++) {
      for (var j = i + 1; j < norm.length; j++) {
        if (TextSimilarity.sameLine(norm[i], norm[j])) return true;
      }
    }
    if (verses.isEmpty) return true;

    final counts = <int, int>{};
    for (final v in verses) {
      counts[v.lines.length] = (counts[v.lines.length] ?? 0) + 1;
    }
    final typicalCount =
        counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    if (block.lines.length != typicalCount) return true;

    double avgLength(Iterable<String> lines) =>
        lines.fold(0, (sum, l) => sum + l.length) / max(lines.length, 1);
    final verseLength = avgLength(verses.expand((v) => v.lines));
    return avgLength(block.lines) < verseLength * 0.8;
  }

  static bool _similar(_Block a, _Block b) {
    final la = a.norm.length;
    final lb = b.norm.length;
    final matches = TextSimilarity.matchingLines(a.norm, b.norm);
    if (matches / max(la, lb) >= 0.75) return true;
    // One contains the other: a chorus with an extra tag line.
    final shorter = min(la, lb);
    return shorter >= 3 && matches / shorter >= 0.9;
  }

  static int _lineTotal(List<_Block> blocks, List<int> group) =>
      group.fold(0, (sum, i) => sum + blocks[i].lines.length);

  static T _mostCommon<T>(List<T> items) {
    final counts = <T, int>{};
    for (final item in items) {
      counts[item] = (counts[item] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  // --- 5. References ----------------------------------------------------------

  /// Fills lyric-less labels ("Repeat Chorus", a trailing "Chorus") with
  /// the section they name. A label with nothing to refer to is handed to
  /// the next unlabelled block, or dropped.
  static List<_Block> _resolveReferences(List<_Block> blocks) {
    final result = <_Block>[];
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      if (block.lines.isNotEmpty) {
        result.add(block);
        continue;
      }
      final label = block.label!;
      final source = _findSource(blocks, i, label);
      if (source != null) {
        result.add(
          _Block(List.of(source.lines), label: label)..type = label.type,
        );
        continue;
      }
      // "Chorus x2" / blank / lyrics with no chorus before it: the label
      // was meant for the lyrics after all.
      if (i + 1 < blocks.length &&
          blocks[i + 1].lines.isNotEmpty &&
          blocks[i + 1].label == null) {
        blocks[i + 1]
          ..label = label
          ..type = label.type;
      }
    }
    return result;
  }

  static _Block? _findSource(List<_Block> blocks, int at, SectionLabel label) {
    final candidates = [
      for (final b in blocks)
        if (b.lines.isNotEmpty && b.type == label.type) b,
    ];
    if (candidates.isEmpty) return null;
    final number = label.number;
    if (number != null) {
      for (final b in candidates) {
        if (b.label?.number == number) return b;
      }
      if (number <= candidates.length) return candidates[number - 1];
    }
    // The latest one before the reference, else the first after it.
    final before = blocks.sublist(0, at).reversed;
    for (final b in before) {
      if (candidates.contains(b)) return b;
    }
    return candidates.first;
  }
}

class _Block {
  _Block(this.lines, {this.label});

  final List<String> lines;
  SectionLabel? label;
  LyricsSegmentType? type;

  List<String>? _norm;
  List<String> get norm =>
      _norm ??= lines.map(TextSimilarity.normalize).toList();
}

/// Offline rhyme heuristic: compares the rime (last vowel group onwards) of
/// each line's final word, ignoring a silent trailing "e".
abstract final class _Rhyme {
  static final _vowelGroup = RegExp(r'[aeiouy]+[^aeiouy]*$');
  static final _hasVowel = RegExp(r'[aeiouy]');

  static bool rhymes(String a, String b) {
    final ka = _key(a);
    final kb = _key(b);
    return ka.isNotEmpty && ka == kb;
  }

  static String _key(String line) {
    final words = TextSimilarity.normalize(line).split(' ');
    var w = words.last;
    if (w.isEmpty) return '';
    // "love" ~ "above", "grace" ~ "place": drop a silent final e.
    if (w.length > 2 &&
        w.endsWith('e') &&
        !'aeiouy'.contains(w[w.length - 2]) &&
        _hasVowel.hasMatch(w.substring(0, w.length - 1))) {
      w = w.substring(0, w.length - 1);
    }
    // Non-Latin words have no vowel match: the whole word is the key.
    return _vowelGroup.firstMatch(w)?.group(0) ?? w;
  }
}
