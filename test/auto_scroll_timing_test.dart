import 'package:flutter_test/flutter_test.dart';
import 'package:lycri_lyrics/shared/utils/auto_scroll_timing.dart';

double _secs(Duration d) => d.inMicroseconds / 1e6;

void main() {
  group('wordWeight', () {
    test('counts whitespace-separated words', () {
      expect(AutoScrollTiming.wordWeight('Amazing grace how sweet'), 4);
      expect(AutoScrollTiming.wordWeight('  spaced   out  '), 2);
    });

    test('a CJK character counts as half a word', () {
      expect(AutoScrollTiming.wordWeight('主耶穌我愛祢'), 3);
      expect(AutoScrollTiming.wordWeight('Hallelujah 哈利路亞'), 3);
    });

    test('never weighs less than one word', () {
      expect(AutoScrollTiming.wordWeight('Oh'), 1);
      expect(AutoScrollTiming.wordWeight('!'), 1);
    });
  });

  group('AUTO', () {
    test('half a second per word', () {
      final d = AutoScrollTiming.lineDurations([
        'one two three four five six seven eight',
        'one two three four five six',
      ], mode: AutoScrollMode.auto);
      expect(_secs(d[0]), 4);
      expect(_secs(d[1]), 3);
    });

    test('at least two seconds per line', () {
      final d = AutoScrollTiming.lineDurations([
        'Oh',
        'Holy holy',
      ], mode: AutoScrollMode.auto);
      expect(_secs(d[0]), 2);
      expect(_secs(d[1]), 2);
    });
  });

  group('1X / 2X / 3X', () {
    const even = ['a b c d', 'e f g h', 'i j k l'];

    test('2X and 3X are two and three times as fast as 1X', () {
      expect(
        AutoScrollTiming.lineDurations(
          even,
          mode: AutoScrollMode.x1,
        ).map(_secs),
        everyElement(4),
      );
      expect(
        AutoScrollTiming.lineDurations(
          even,
          mode: AutoScrollMode.x2,
        ).map(_secs),
        everyElement(2),
      );
      expect(
        AutoScrollTiming.lineDurations(
          even,
          mode: AutoScrollMode.x3,
        ).map(_secs),
        everyElement(closeTo(4 / 3, 1e-6)),
      );
    });

    test('weighted by length, kept within half and double the average', () {
      final d = AutoScrollTiming.lineDurations([
        'a',
        'a b c d e f g h i j k l m n o p q r s t',
        'a b c d e f',
        'a b c d e f',
      ], mode: AutoScrollMode.x2);
      // Mean weight 8.25: shortest clamps to 0.5×, longest to 2×.
      expect(_secs(d[0]), 1);
      expect(_secs(d[1]), 4);
      expect(_secs(d[2]), closeTo(2 * 6 / 8.25, 1e-6));
    });
  });

  group('song length', () {
    test('spreads the length over the lines by word count', () {
      final d = AutoScrollTiming.lineDurations(
        ['a b', 'a b c d e f', 'a b'],
        mode: AutoScrollMode.songLength,
        songLength: const Duration(seconds: 50),
      );
      expect(_secs(d[0]), 10);
      expect(_secs(d[1]), 30);
      expect(_secs(d[2]), 10);
    });

    test('falls back to AUTO without a length', () {
      final d = AutoScrollTiming.lineDurations([
        'a b c d e f g h',
      ], mode: AutoScrollMode.songLength);
      expect(_secs(d[0]), 4);
    });
  });

  test('no lines, no durations', () {
    expect(
      AutoScrollTiming.lineDurations(const [], mode: AutoScrollMode.x1),
      isEmpty,
    );
  });

  group('parseSongLength', () {
    test('M:SS', () {
      expect(
        AutoScrollTiming.parseSongLength('3:45'),
        const Duration(minutes: 3, seconds: 45),
      );
      expect(
        AutoScrollTiming.parseSongLength(' 12:05 '),
        const Duration(minutes: 12, seconds: 5),
      );
    });

    test('bare digits read as M:SS from the right', () {
      expect(
        AutoScrollTiming.parseSongLength('345'),
        const Duration(minutes: 3, seconds: 45),
      );
      expect(
        AutoScrollTiming.parseSongLength('45'),
        const Duration(seconds: 45),
      );
      expect(
        AutoScrollTiming.parseSongLength('1205'),
        const Duration(minutes: 12, seconds: 5),
      );
    });

    test('rejects empty, zero, and invalid seconds', () {
      expect(AutoScrollTiming.parseSongLength(''), isNull);
      expect(AutoScrollTiming.parseSongLength('0:00'), isNull);
      expect(AutoScrollTiming.parseSongLength('3:75'), isNull);
      expect(AutoScrollTiming.parseSongLength('abc'), isNull);
    });
  });

  test('formatSongLength', () {
    expect(
      AutoScrollTiming.formatSongLength(const Duration(minutes: 3, seconds: 5)),
      '3:05',
    );
  });
}
