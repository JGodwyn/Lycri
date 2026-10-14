import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lycri_lyrics/shared/providers/active_line_provider.dart';
import 'package:lycri_lyrics/shared/providers/auto_scroll_provider.dart';
import 'package:lycri_lyrics/shared/providers/lyrics_provider.dart';
import 'package:lycri_lyrics/shared/providers/lyrics_visibility_provider.dart';
import 'package:lycri_lyrics/shared/utils/auto_scroll_timing.dart';

/// Two words per line: 2s each in AUTO.
const _lyrics = 'one two\nthree four\nfive six\nseven eight';

/// Runs [body] in fake time with lyrics loaded and the auto-scroll notifier
/// alive.
void _run(void Function(FakeAsync async, ProviderContainer c) body) {
  fakeAsync((async) {
    final c = ProviderContainer();
    c.listen(autoScrollProvider, (_, _) {});
    c.read(lyricsProvider.notifier).send(_lyrics);
    async.flushMicrotasks();
    body(async, c);
    c.dispose();
  });
}

AutoScrollNotifier _auto(ProviderContainer c) =>
    c.read(autoScrollProvider.notifier);

int _line(ProviderContainer c) => c.read(activeLineProvider);

void _wait(FakeAsync async, int ms) => async.elapse(Duration(milliseconds: ms));

void main() {
  test('advances one line per line duration, stops on the last line', () {
    _run((async, c) {
      _auto(c).play();
      expect(c.read(autoScrollProvider).playing, isTrue);
      _wait(async, 1900);
      expect(_line(c), 0);
      _wait(async, 200);
      expect(_line(c), 1);
      _wait(async, 2000);
      expect(_line(c), 2);
      _wait(async, 2000);
      expect(_line(c), 3);
      expect(c.read(autoScrollProvider).playing, isFalse);
    });
  });

  test('a manual move restarts the countdown from the new line', () {
    _run((async, c) {
      _auto(c).play();
      _wait(async, 1500);
      c.read(activeLineProvider.notifier).jumpTo(1);
      _wait(async, 1900);
      expect(_line(c), 1);
      _wait(async, 200);
      expect(_line(c), 2);
      expect(c.read(autoScrollProvider).playing, isTrue);
    });
  });

  test('pause keeps the time already spent on the line', () {
    _run((async, c) {
      _auto(c).play();
      _wait(async, 1500);
      _auto(c).pause();
      final paused = c.read(autoScrollProvider);
      expect(paused.playing, isFalse);
      expect(paused.lineProgress, closeTo(0.75, 1e-6));
      _wait(async, 10000);
      expect(_line(c), 0);
      _auto(c).play();
      _wait(async, 400);
      expect(_line(c), 0);
      _wait(async, 200);
      expect(_line(c), 1);
    });
  });

  test('changing speed mid-line keeps how far through it was', () {
    _run((async, c) {
      _auto(c).setMode(AutoScrollMode.x1); // 4s per line
      _auto(c).play();
      _wait(async, 2000);
      _auto(c).setMode(AutoScrollMode.x2); // 2s: half done → 1s left
      expect(
        c.read(autoScrollProvider).lineDuration,
        const Duration(seconds: 2),
      );
      _wait(async, 900);
      expect(_line(c), 0);
      _wait(async, 200);
      expect(_line(c), 1);
    });
  });

  test('a song length spreads over the lines and selects that mode', () {
    _run((async, c) {
      _auto(c).setSongLength(const Duration(seconds: 12));
      final s = c.read(autoScrollProvider);
      expect(s.mode, AutoScrollMode.songLength);
      expect(s.songLength, const Duration(seconds: 12));
      expect(s.lineDuration, const Duration(seconds: 3));
      _auto(c).play();
      _wait(async, 3100);
      expect(_line(c), 1);
    });
  });

  test('song-length mode needs a length', () {
    _run((async, c) {
      _auto(c).setMode(AutoScrollMode.songLength);
      expect(c.read(autoScrollProvider).mode, AutoScrollMode.auto);
    });
  });

  test('hiding the lyrics pauses; showing them does not resume', () {
    _run((async, c) {
      _auto(c).play();
      c.read(lyricsVisibilityProvider.notifier).state = false;
      expect(c.read(autoScrollProvider).playing, isFalse);
      expect(_auto(c).canPlay, isFalse);
      c.read(lyricsVisibilityProvider.notifier).state = true;
      expect(c.read(autoScrollProvider).playing, isFalse);
      _wait(async, 5000);
      expect(_line(c), 0);
    });
  });

  test('clearing the lyrics stops and forgets the song length', () {
    _run((async, c) {
      _auto(c).setSongLength(const Duration(seconds: 12));
      _auto(c).play();
      c.read(segmentedLyricsProvider.notifier).clearAll();
      final s = c.read(autoScrollProvider);
      expect(s.playing, isFalse);
      expect(s.songLength, isNull);
      expect(s.mode, AutoScrollMode.auto);
    });
  });

  test('editing the lyrics keeps the song length and keeps playing', () {
    _run((async, c) {
      _auto(c).setSongLength(const Duration(seconds: 12));
      _auto(c).play();
      c
          .read(lyricsProvider.notifier)
          .update('$_lyrics\nnine ten\neleven twelve');
      final s = c.read(autoScrollProvider);
      expect(s.playing, isTrue);
      expect(s.songLength, const Duration(seconds: 12));
      expect(s.lineDuration, const Duration(seconds: 2));
    });
  });

  test('loading a different song stops and forgets the song length', () {
    _run((async, c) {
      _auto(c).setSongLength(const Duration(seconds: 12));
      _auto(c).play();
      c.read(lyricsProvider.notifier).update('another song\nentirely new');
      final s = c.read(autoScrollProvider);
      expect(s.playing, isFalse);
      expect(s.songLength, isNull);
    });
  });

  test('cannot play from the last line', () {
    _run((async, c) {
      c.read(activeLineProvider.notifier).jumpTo(3);
      expect(_auto(c).canPlay, isFalse);
      _auto(c).play();
      expect(c.read(autoScrollProvider).playing, isFalse);
    });
  });

  test('jumping to the last line while playing stops', () {
    _run((async, c) {
      _auto(c).play();
      c.read(activeLineProvider.notifier).jumpTo(3);
      expect(c.read(autoScrollProvider).playing, isFalse);
    });
  });
}
