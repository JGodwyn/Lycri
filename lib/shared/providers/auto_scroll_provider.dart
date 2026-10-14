import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/auto_scroll_timing.dart';
import 'active_line_provider.dart';
import 'lyrics_provider.dart';
import 'lyrics_visibility_provider.dart';

/// Lyric auto-scroll: steps the active line forward on a timer, exactly as
/// if the operator pressed next, so the preview, output window and NDI all
/// follow through the existing active-line sync.
final autoScrollProvider =
    StateNotifierProvider<AutoScrollNotifier, AutoScrollState>(
      (ref) => AutoScrollNotifier(ref),
    );

/// Whether auto-scroll can start: lyrics are showing and there's a line
/// after the active one.
final autoScrollCanPlayProvider = Provider<bool>(
  (ref) => _canPlay(
    lines: ref.watch(lyricsLinesProvider),
    active: ref.watch(activeLineProvider),
    visible: ref.watch(lyricsVisibilityProvider),
  ),
);

bool _canPlay({
  required List<String> lines,
  required int active,
  required bool visible,
}) => visible && active < lines.length - 1;

class AutoScrollState {
  const AutoScrollState({
    this.mode = AutoScrollMode.auto,
    this.songLength,
    this.playing = false,
    this.lineDuration = Duration.zero,
    this.lineProgress = 0,
  });

  final AutoScrollMode mode;

  /// The operator's song length, kept until the lyrics are cleared or
  /// replaced.
  final Duration? songLength;

  final bool playing;

  /// How long the active line stays up at the current pace.
  final Duration lineDuration;

  /// How far through [lineDuration] the active line was when this state was
  /// emitted (0–1). While [playing] it keeps rising at real time from here.
  final double lineProgress;

  AutoScrollState copyWith({
    AutoScrollMode? mode,
    Duration? songLength,
    bool clearSongLength = false,
    bool? playing,
    Duration? lineDuration,
    double? lineProgress,
  }) {
    return AutoScrollState(
      mode: mode ?? this.mode,
      songLength: clearSongLength ? null : (songLength ?? this.songLength),
      playing: playing ?? this.playing,
      lineDuration: lineDuration ?? this.lineDuration,
      lineProgress: lineProgress ?? this.lineProgress,
    );
  }
}

class AutoScrollNotifier extends StateNotifier<AutoScrollState> {
  AutoScrollNotifier(this._ref) : super(const AutoScrollState()) {
    _durations = _computeDurations();
    state = state.copyWith(lineDuration: _activeDuration);

    // Any move — ours, prev/next, a tapped line — starts the new line's
    // countdown from zero.
    _ref.listen<int>(activeLineProvider, (_, _) => _onLineChanged());

    // New, cleared or replaced lyrics end the song. Saving, cleanup and
    // edits keep lines in common, so they don't.
    _ref.listen<String?>(lyricsProvider, (prev, next) {
      if (!_sharesLines(prev, next)) _forgetSong();
    });
    _ref.listen<List<String>>(lyricsLinesProvider, (_, _) => _onLinesEdited());

    // Hidden lyrics usually mean an instrumental break.
    _ref.listen<bool>(lyricsVisibilityProvider, (_, visible) {
      if (!visible) pause();
    });
  }

  final Ref _ref;
  Timer? _timer;
  List<Duration> _durations = const [];

  /// Time spent on the active line before the current run.
  Duration _banked = Duration.zero;
  DateTime? _runStartedAt;

  /// Read from the sources rather than [autoScrollCanPlayProvider]: inside
  /// an active-line listener that provider hasn't recomputed yet.
  bool get canPlay => _canPlay(
    lines: _ref.read(lyricsLinesProvider),
    active: _ref.read(activeLineProvider),
    visible: _ref.read(lyricsVisibilityProvider),
  );

  void play() {
    if (state.playing || !canPlay) return;
    _runStartedAt = clock.now();
    _schedule();
    state = state.copyWith(playing: true, lineProgress: _progress);
  }

  void pause() {
    if (!state.playing) return;
    _banked = _elapsed;
    _runStartedAt = null;
    _timer?.cancel();
    state = state.copyWith(playing: false, lineProgress: _progress);
  }

  void toggle() => state.playing ? pause() : play();

  /// Switches pace; the active line keeps how far through it was.
  /// [AutoScrollMode.songLength] needs a [AutoScrollState.songLength].
  void setMode(AutoScrollMode mode) {
    if (mode == AutoScrollMode.songLength && state.songLength == null) return;
    final fraction = _progress;
    state = state.copyWith(mode: mode);
    _repace(fraction);
  }

  void setSongLength(Duration length) {
    state = state.copyWith(songLength: length);
    setMode(AutoScrollMode.songLength);
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  List<Duration> _computeDurations() => AutoScrollTiming.lineDurations(
    _ref.read(lyricsLinesProvider),
    mode: state.mode,
    songLength: state.songLength,
  );

  Duration get _activeDuration {
    if (_durations.isEmpty) return Duration.zero;
    final i = _ref.read(activeLineProvider).clamp(0, _durations.length - 1);
    return _durations[i];
  }

  Duration get _elapsed =>
      _runStartedAt == null
          ? _banked
          : _banked + clock.now().difference(_runStartedAt!);

  double get _progress {
    final total = state.lineDuration.inMicroseconds;
    if (total == 0) return 0;
    return (_elapsed.inMicroseconds / total).clamp(0.0, 1.0);
  }

  /// Recomputes the line times, keeping the active line at [fraction].
  void _repace(double fraction) {
    _durations = _computeDurations();
    final duration = _activeDuration;
    _banked = duration * fraction;
    if (state.playing) _runStartedAt = clock.now();
    state = state.copyWith(lineDuration: duration, lineProgress: fraction);
    if (state.playing) _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final remaining = state.lineDuration - _elapsed;
    _timer = Timer(remaining.isNegative ? Duration.zero : remaining, _advance);
  }

  void _advance() {
    final lines = _ref.read(lyricsLinesProvider);
    _ref.read(activeLineProvider.notifier).next(lines.length - 1);
    _ref.read(scrollToActiveTriggerProvider.notifier).state++;
  }

  void _onLineChanged() {
    _banked = Duration.zero;
    if (state.playing) {
      if (!canPlay) return _stop();
      _runStartedAt = clock.now();
    }
    state = state.copyWith(lineDuration: _activeDuration, lineProgress: 0);
    if (state.playing) _schedule();
  }

  void _onLinesEdited() {
    if (state.playing && !canPlay) _stop();
    _repace(_progress);
  }

  static Set<String> _lineSet(String? text) =>
      (text ?? '')
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toSet();

  static bool _sharesLines(String? a, String? b) {
    final before = _lineSet(a);
    return _lineSet(b).any(before.contains);
  }

  /// New or cleared lyrics: stop, and drop the old song's length.
  void _forgetSong() {
    _stop();
    state = state.copyWith(
      clearSongLength: true,
      mode:
          state.mode == AutoScrollMode.songLength ? AutoScrollMode.auto : null,
    );
    _repace(0);
  }

  void _stop() {
    _timer?.cancel();
    _banked = Duration.zero;
    _runStartedAt = null;
    state = state.copyWith(playing: false, lineProgress: 0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
