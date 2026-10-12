import 'dart:math';

/// Text comparison helpers shared by the segmenter and the cache merge.
abstract final class TextSimilarity {
  static final _nonWord = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);
  static final _spaces = RegExp(r'\s+');

  /// Lowercase with punctuation stripped and whitespace collapsed.
  ///
  /// Unicode-aware: an ASCII-only filter turns non-Latin lyrics into empty
  /// strings, which then all compare as identical.
  static String normalize(String line) =>
      line
          .toLowerCase()
          .replaceAll(_nonWord, '')
          .replaceAll(_spaces, ' ')
          .trim();

  /// Normalized Levenshtein distance (0.0 = identical, 1.0 = completely
  /// different): edit distance divided by the length of the longer string.
  static double distance(String a, String b) {
    if (a == b) return 0.0;
    if (a.isEmpty || b.isEmpty) return 1.0;

    final m = a.length;
    final n = b.length;
    // Single-row DP for memory efficiency.
    var prev = List<int>.generate(n + 1, (j) => j);
    var curr = List<int>.filled(n + 1, 0);

    for (int i = 1; i <= m; i++) {
      curr[0] = i;
      for (int j = 1; j <= n; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        curr[j] = min(min(curr[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[n] / max(m, n);
  }

  /// Whether two normalized lines are the same line give or take a typo:
  /// edit distance ≤ 20% (per SMAP 2013).
  static bool sameLine(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    if (a == b) return true;
    // A length gap over 20% can't be within 20% edits; skip the DP.
    if ((a.length - b.length).abs() > max(a.length, b.length) * 0.2) {
      return false;
    }
    return distance(a, b) <= 0.2;
  }

  /// Counts lines of [a] that have a matching line in [b], each line of [b]
  /// used at most once. Both lists hold normalized lines.
  static int matchingLines(List<String> a, List<String> b) {
    int matches = 0;
    final usedB = <int>{};
    for (final lineA in a) {
      double bestDist = 1.0;
      int bestIdx = -1;
      for (int j = 0; j < b.length; j++) {
        if (usedB.contains(j) || !sameLine(lineA, b[j])) continue;
        final dist = distance(lineA, b[j]);
        if (dist < bestDist || bestIdx == -1) {
          bestDist = dist;
          bestIdx = j;
        }
      }
      if (bestIdx != -1) {
        matches++;
        usedB.add(bestIdx);
      }
    }
    return matches;
  }

  /// Similarity of two text blocks (0.0 – 1.0): the share of lines that match
  /// a line in the other block, over the longer block's line count.
  static double blockSimilarity(String a, String b) {
    final linesA = _lines(a);
    final linesB = _lines(b);
    if (linesA.isEmpty && linesB.isEmpty) return 1.0;
    if (linesA.isEmpty || linesB.isEmpty) return 0.0;
    return matchingLines(linesA, linesB) / max(linesA.length, linesB.length);
  }

  static List<String> _lines(String text) =>
      text.split('\n').map(normalize).where((l) => l.isNotEmpty).toList();
}
