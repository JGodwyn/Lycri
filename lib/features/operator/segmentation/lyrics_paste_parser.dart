import '../models/lyrics_segment.dart';
import 'section_label.dart';
import 'text_similarity.dart';

/// One line of a paste after cleanup.
sealed class PasteToken {
  const PasteToken();
}

final class LyricLine extends PasteToken {
  const LyricLine(this.text);
  final String text;
}

/// An empty line. Usually a stanza break; see [LyricsSegmenter] for
/// double-spaced pastes, where single blanks are just line breaks.
final class BlankLine extends PasteToken {
  const BlankLine();
}

/// A hard boundary: a separator line ("---"), an unknown "[Heading]", or a
/// ChordPro end-of-section directive.
final class SectionBreak extends PasteToken {
  const SectionBreak();
}

final class LabelLine extends PasteToken {
  const LabelLine(this.label);
  final SectionLabel label;
}

/// Turns pasted text into [PasteToken]s: normalizes invisible characters and
/// line endings, drops chords, ChordPro directives, site chrome (Genius,
/// SongSelect/CCLI) and repeat markers, and recognizes section labels.
abstract final class LyricsPasteParser {
  static List<PasteToken> parse(String raw, {String? title}) {
    final lines = _normalizeLines(raw);
    final chordSheet = _isChordSheet(lines);
    final chordPro = _isChordPro(lines);

    final numberedStanzas = _hasNumberedStanzas(lines);

    final tokens = <PasteToken>[];
    var sawFooter = false;

    void addLyric(String text) {
      // " // " inside a line separates stanzas, " / " separates lines.
      final stanzas = text.split(_stanzaSlash);
      for (var s = 0; s < stanzas.length; s++) {
        if (s > 0) tokens.add(const SectionBreak());
        for (final piece in stanzas[s].split(_lineSlash)) {
          final clean = _cleanLyric(piece);
          if (clean.isNotEmpty) tokens.add(LyricLine(clean));
        }
      }
    }

    for (var i = 0; i < lines.length; i++) {
      var t = lines[i].trim();
      if (t.isEmpty) {
        tokens.add(const BlankLine());
        continue;
      }

      // Genius glues the page title onto the first heading: "Song Lyrics[Verse 1]".
      if (tokens.every((token) => token is BlankLine)) {
        final glued = _gluedTitle.firstMatch(t);
        if (glued != null) t = glued.group(1)!;
      }

      if (chordPro) {
        final directive = _directive.firstMatch(t);
        if (directive != null) {
          final token = _fromDirective(
            directive.group(1)!.toLowerCase(),
            directive.group(2),
            chordSheet: chordSheet,
          );
          if (token != null) tokens.add(token);
          continue;
        }
        t =
            t.replaceAllMapped(_inlineChord, (m) {
              return _isChord(m.group(1)!) ? '' : m.group(0)!;
            }).trim();
        if (t.isEmpty) continue;
      }

      if (_separator.hasMatch(t)) {
        tokens.add(const SectionBreak());
        continue;
      }
      if (_repeatOnly.hasMatch(t)) continue;

      if (_footer.any((p) => p.hasMatch(t))) {
        sawFooter = true;
        continue;
      }
      if (_credit.any((p) => p.hasMatch(t)) ||
          (_inHeader(tokens) && _headerCredit.hasMatch(t))) {
        _dropHeader(tokens);
        continue;
      }
      if (_siteChrome.any((p) => p.hasMatch(t))) continue;

      if (chordSheet && _isChordLine(t)) continue;
      final label = SectionLabels.match(t, chordSheet: chordSheet);
      if (label != null) {
        // "[Instrumental]", "Solo": no lyrics of their own, so they never
        // take over the lines that follow.
        tokens.add(
          label.label.isInstrumental
              ? const SectionBreak()
              : LabelLine(label.label),
        );
        if (label.rest.isNotEmpty) addLyric(label.rest);
        continue;
      }
      if (_isChordLine(t)) continue;
      if (SectionLabels.isBracketHeading(t)) {
        tokens.add(const SectionBreak());
        continue;
      }

      final trailing = SectionLabels.trailingReference(
        t,
        chordSheet: chordSheet,
      );
      if (trailing != null) {
        addLyric(trailing.$1);
        tokens
          ..add(LabelLine(trailing.$2))
          ..add(const SectionBreak());
        continue;
      }

      // Hymn numbering: "2" on its own, or "2. Lyric" opening a stanza
      // ("2 Lyric" too when the paste numbers its stanzas that way).
      final atStanzaStart = tokens.isEmpty || tokens.last is! LyricLine;
      final numbered = (numberedStanzas ? _hymnNumberLoose : _hymnNumber)
          .firstMatch(t);
      if (numbered != null && (atStanzaStart || numbered.group(2) == null)) {
        tokens.add(
          LabelLine(
            SectionLabel(
              type: LyricsSegmentType.verse,
              number: int.parse(numbered.group(1)!),
            ),
          ),
        );
        if (numbered.group(2) != null) addLyric(numbered.group(2)!);
        continue;
      }

      addLyric(t);
    }

    _dropTitle(tokens, title: title, sawFooter: sawFooter);
    return tokens;
  }

  // --- Normalization -------------------------------------------------------

  static final _lineBreaks = RegExp('[  \u000B\u000C\u0085]');
  static final _invisible = RegExp('[​-‍⁠﻿­]');
  static final _oddSpaces = RegExp('[  -   　\t]');

  static List<String> _normalizeLines(String raw) => raw
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(_lineBreaks, '\n')
      .replaceAll(_invisible, '')
      .replaceAll(_oddSpaces, ' ')
      .split('\n');

  static final _spaces = RegExp(r'\s{2,}');
  static final _lineSlash = RegExp(r'\s+/\s+');
  static final _stanzaSlash = RegExp(r'\s+//\s+');

  /// "Lyric (x2)", "Lyric x2", "Lyric [Repeat]" — the repeat is the
  /// operator's call, not something to put on screen.
  static final _trailingRepeat = RegExp(
    r'\s*(?:[(\[]\s*(?:x\s?\d+|\d+\s?x|×\s?\d+|repeat(?:\s*x?\d+x?)?|twice|\d+\s+times)\s*[)\]]|\s(?:x\d+|\d+x|×\d+))\s*$',
    caseSensitive: false,
  );

  /// Genius appends "123Embed" to the last lyric line.
  static final _embedSuffix = RegExp(r'(?:\d+|(?<=[a-z.!?,]))Embed$');

  static String _cleanLyric(String line) {
    var t = SectionLabels.stripInlineLabels(line);
    t = t.replaceFirst(_embedSuffix, '');
    t = t.replaceFirst(_youMightAlsoLike, '');
    t = t.replaceFirst(_trailingRepeat, '');
    return t.replaceAll(_spaces, ' ').trim();
  }

  // --- Line classes ---------------------------------------------------------

  static final _separator = RegExp(r'^[\s\-–—_=*~•·#.]+$');

  static final _repeatOnly = RegExp(
    r'^[(\[*]?\s*(?:x\s?\d+|\d+\s?x|×\s?\d+|repeat(?:\s+(?:x\s?\d+|\d+\s?x|twice|\d+\s+times))?|twice|\d+\s+times)\s*[)\]*]?\.?$',
    caseSensitive: false,
  );

  static final _hymnNumber = RegExp(r'^(\d{1,2})(?:[.)]\s+(\S.*)|[.)]?)$');

  static final _hymnNumberLoose = RegExp(
    r'^(\d{1,2})(?:[.)]?\s+(\S.*)|[.)]?)$',
  );

  /// Hymnals (hymnary.org) number stanzas "1 Blessed assurance…" with no
  /// period. Only trusted when stanzas 1 and 2 both start that way.
  static bool _hasNumberedStanzas(List<String> lines) {
    final numbers = <int>{};
    var stanzaStart = true;
    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) {
        stanzaStart = true;
        continue;
      }
      final m = RegExp(r'^(\d{1,2})\s+\p{L}', unicode: true).firstMatch(t);
      if (stanzaStart && m != null) numbers.add(int.parse(m.group(1)!));
      stanzaStart = false;
    }
    return numbers.contains(1) && numbers.contains(2);
  }

  static final _gluedTitle = RegExp(r'^.+?\bLyrics(\[.+\].*)$');

  /// Copyright / licensing footers (SongSelect, CCLI).
  static final _footer = [
    RegExp(r'\bccli\b', caseSensitive: false),
    RegExp(r'^(?:©|\(c\)\s|copyright\b)', caseSensitive: false),
    RegExp(r'all rights reserved', caseSensitive: false),
    RegExp(r'used by permission', caseSensitive: false),
    RegExp(r'songselect', caseSensitive: false),
    RegExp(r'\b(?:admin\.?|administered) by\b', caseSensitive: false),
  ];

  /// Credits and sheet metadata, usually right under the title.
  static final _credit = [
    RegExp(
      r'^(?:words(?:\s*(?:&|and)\s*music)?|music(?:\s*(?:&|and)\s*words)?|lyrics)\s+by\b',
      caseSensitive: false,
    ),
    RegExp(
      r'^(?:title|artist|album|authors?|writers?|songwriters?|composers?)\s*:',
      caseSensitive: false,
    ),
    RegExp(
      r'^(?:key|tempo|bpm|time(?:\s+signature)?|time\s+sig|capo|tuning|meter)\s*[:\-=]',
      caseSensitive: false,
    ),
    RegExp(r'^\d+\s*bpm$', caseSensitive: false),
  ];

  /// Credits that could also open a lyric ("Written by the hand of God"),
  /// so only trusted in the header.
  static final _headerCredit = RegExp(
    r'^(?:written|composed|produced|arranged)\s+by\b',
    caseSensitive: false,
  );

  static bool _inHeader(List<PasteToken> tokens) =>
      tokens.whereType<LyricLine>().length <= 2 &&
      tokens.every((t) => t is LyricLine || t is BlankLine);

  static final _youMightAlsoLike = RegExp(
    r'^You might also like(?=\p{Lu})',
    unicode: true,
  );

  /// Page chrome copied along with lyrics from Genius and similar sites.
  static final _siteChrome = [
    RegExp(r'^\d*\s*contributors?\b', caseSensitive: false),
    RegExp(r'^translations\b', caseSensitive: false),
    RegExp(r'^you might also like$', caseSensitive: false),
    RegExp(r'^\d*\s*embed$', caseSensitive: false),
    RegExp(r'^see .{1,60} live$', caseSensitive: false),
    RegExp(r'^get tickets as low as\b', caseSensitive: false),
    RegExp(r'^\[?produced by\b', caseSensitive: false),
  ];

  // --- Chords ---------------------------------------------------------------

  static final _chord = RegExp(
    r'^\(?[A-G](?:#|b|♯|♭)?(?:maj|min|m|M|dim|aug|sus|add|°|ø|\+|-)?\d{0,2}'
    r'(?:(?:sus|add|maj|dim|aug|b|#|\+|-)\d{1,2})*(?:/[A-G](?:#|b|♯|♭)?)?\)?$',
  );

  static final _chordFiller = RegExp(
    r'^(?:\|+|/+|-+|–|%|\.+|n\.?c\.?|:?\|\|?:?|[(\[]?x\d+[)\]]?|\d+x)$',
    caseSensitive: false,
  );

  static bool _isChord(String token) => _chord.hasMatch(token);

  static bool _isChordLine(String line) {
    var chords = 0;
    for (final token in line.split(RegExp(r'\s+'))) {
      if (token.isEmpty || _chordFiller.hasMatch(token)) continue;
      if (!_isChord(token)) return false;
      chords++;
    }
    return chords > 0;
  }

  /// Chord sheets have chord lines over the lyrics. A lone "C" or "B" is a
  /// chord there, not a Planning Center label.
  static bool _isChordSheet(List<String> lines) {
    var chordLines = 0;
    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty || !_isChordLine(t)) continue;
      // Several chords on a line, or one chord that can't be a label.
      if (t.contains(RegExp(r'\s')) || !RegExp(r'^[A-G]\d?$').hasMatch(t)) {
        chordLines++;
      }
    }
    return chordLines >= 2;
  }

  // --- ChordPro -------------------------------------------------------------

  static final _directive = RegExp(
    r'^\{\s*([a-z_]+)\s*(?::\s*(.*?))?\s*\}$',
    caseSensitive: false,
  );
  static final _inlineChord = RegExp(r'\[([^\]\s]{1,10})\]');

  static bool _isChordPro(List<String> lines) {
    var inlineChords = 0;
    for (final line in lines) {
      final t = line.trim();
      if (_directive.hasMatch(t)) return true;
      for (final m in _inlineChord.allMatches(t)) {
        if (_isChord(m.group(1)!)) inlineChords++;
      }
    }
    return inlineChords >= 3;
  }

  static PasteToken? _fromDirective(
    String name,
    String? value, {
    required bool chordSheet,
  }) {
    /// The directive's own label ("{soc: Chorus 2}"), else [fallback].
    LabelLine label(String fallback) {
      final own =
          value == null || value.isEmpty
              ? null
              : SectionLabels.match(value, chordSheet: chordSheet);
      return LabelLine(
        (own ?? SectionLabels.match(fallback, chordSheet: chordSheet)!).label,
      );
    }

    switch (name) {
      case 'soc' || 'start_of_chorus':
        return label('Chorus');
      case 'sov' || 'start_of_verse':
        return label('Verse');
      case 'sob' || 'start_of_bridge':
        return label('Bridge');
      case 'chorus':
        return LabelLine(
          SectionLabels.match('Repeat Chorus', chordSheet: chordSheet)!.label,
        );
      case 'c' ||
          'comment' ||
          'ci' ||
          'comment_italic' ||
          'cb' ||
          'comment_box':
        final m =
            value == null
                ? null
                : SectionLabels.match(value, chordSheet: chordSheet);
        return m == null ? null : LabelLine(m.label);
    }
    if (name.startsWith('end_of_') || name.startsWith('eo')) {
      return const SectionBreak();
    }
    // Metadata: title, artist, key, tempo, capo, …
    return null;
  }

  // --- Title / header -------------------------------------------------------

  /// A credit line near the top means whatever came before it was the title
  /// and artist.
  static void _dropHeader(List<PasteToken> tokens) {
    if (_inHeader(tokens) &&
        tokens.whereType<LyricLine>().every(
          (l) => l.text.split(' ').length <= 10,
        )) {
      tokens.clear();
    }
  }

  /// Drops a title line at the top: one matching the song's name, a Genius
  /// "<Title> Lyrics" header, or a lone first line on a SongSelect sheet
  /// (detected by its copyright footer).
  static void _dropTitle(
    List<PasteToken> tokens, {
    required String? title,
    required bool sawFooter,
  }) {
    final first = tokens.indexWhere((t) => t is! BlankLine);
    if (first == -1 || tokens[first] is! LyricLine) return;
    final line = (tokens[first] as LyricLine).text;
    final normalized = TextSimilarity.normalize(line);

    final next = first + 1 < tokens.length ? tokens[first + 1] : null;
    final standsAlone = next == null || next is! LyricLine;

    final wantTitle = title == null ? null : TextSimilarity.normalize(title);
    final isTitle =
        (wantTitle != null &&
            wantTitle.isNotEmpty &&
            (normalized == wantTitle || normalized == '$wantTitle lyrics')) ||
        (RegExp(r'\sLyrics$').hasMatch(line) && line.split(' ').length <= 10) ||
        (sawFooter && standsAlone && line.split(' ').length <= 8);

    if (isTitle) tokens.removeAt(first);
  }
}
