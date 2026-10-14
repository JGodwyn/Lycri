import 'dart:math' as math;

/// How auto-scroll paces the lyric lines.
enum AutoScrollMode {
  /// Natural singing pace from each line's word count.
  auto,

  /// Fixed pace: about 4s per line.
  x1,

  /// Twice 1x: about 2s per line.
  x2,

  /// Three times 1x: about 1.3s per line.
  x3,

  /// The operator's song length, spread over the lines.
  songLength,
}

/// Pure timing maths for lyric auto-scroll: how long each line stays active
/// before the next one takes over.
///
/// Every mode weighs lines by their word count, so short lines move on
/// sooner than long ones.
abstract final class AutoScrollTiming {
  /// AUTO pace.
  static const double secondsPerWord = 0.5;

  /// AUTO floor, so one-word lines stay up long enough to read.
  static const double minAutoSeconds = 2;

  /// Average seconds per line at 1x; 2x and 3x divide it.
  static const double baseSeconds = 4;

  /// Average seconds per line for the fixed speeds.
  static const Map<AutoScrollMode, double> averageSeconds = {
    AutoScrollMode.x1: baseSeconds,
    AutoScrollMode.x2: baseSeconds / 2,
    AutoScrollMode.x3: baseSeconds / 3,
  };

  /// Fixed speeds keep every line within these multiples of the average.
  static const double minFactor = 0.5;
  static const double maxFactor = 2;

  /// CJK scripts don't separate words with spaces; one character is about
  /// a syllable, so two make a word.
  static final RegExp _cjk = RegExp(r'[぀-ヿ㐀-䶿一-鿿가-힯豈-﫿]');

  /// The line's length in words (at least one).
  static double wordWeight(String line) {
    final cjk = _cjk.allMatches(line).length;
    final words =
        line
            .replaceAll(_cjk, ' ')
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .length;
    return math.max(1, words + cjk / 2);
  }

  /// How long each of [lines] stays active in [mode].
  ///
  /// [songLength] is only used by [AutoScrollMode.songLength]; without one
  /// that mode paces like [AutoScrollMode.auto].
  static List<Duration> lineDurations(
    List<String> lines, {
    required AutoScrollMode mode,
    Duration? songLength,
  }) {
    if (lines.isEmpty) return const [];
    final weights = lines.map(wordWeight).toList();
    final total = weights.fold<double>(0, (a, b) => a + b);

    final List<double> seconds;
    switch (mode) {
      case AutoScrollMode.songLength when songLength != null:
        final length = songLength.inMicroseconds / 1e6;
        seconds = [for (final w in weights) length * w / total];
      case AutoScrollMode.auto || AutoScrollMode.songLength:
        seconds = [
          for (final w in weights) math.max(minAutoSeconds, w * secondsPerWord),
        ];
      case AutoScrollMode.x1 || AutoScrollMode.x2 || AutoScrollMode.x3:
        final average = averageSeconds[mode]!;
        final mean = total / weights.length;
        seconds = [
          for (final w in weights)
            average * (w / mean).clamp(minFactor, maxFactor),
        ];
    }
    return [for (final s in seconds) Duration(microseconds: (s * 1e6).round())];
  }

  /// Reads a typed song length: `3:45`, or bare digits read from the right
  /// (`345` → 3:45, `45` → 0:45). Null when empty, zero or not a time.
  static Duration? parseSongLength(String input) {
    final text = input.trim();
    final int minutes;
    final int seconds;
    final colon = RegExp(r'^(\d{1,3}):(\d{1,2})$').firstMatch(text);
    if (colon != null) {
      minutes = int.parse(colon[1]!);
      seconds = int.parse(colon[2]!);
    } else if (RegExp(r'^\d{1,5}$').hasMatch(text)) {
      final n = int.parse(text);
      minutes = n ~/ 100;
      seconds = n % 100;
    } else {
      return null;
    }
    if (seconds >= 60) return null;
    final length = Duration(minutes: minutes, seconds: seconds);
    return length == Duration.zero ? null : length;
  }

  /// `M:SS`.
  static String formatSongLength(Duration length) {
    final seconds = length.inSeconds % 60;
    return '${length.inMinutes}:${seconds.toString().padLeft(2, '0')}';
  }
}
