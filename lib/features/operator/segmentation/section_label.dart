import '../models/lyrics_segment.dart';

/// A section heading found in pasted lyrics: "[Chorus]", "Verse 2:", "V1",
/// "Repeat Chorus", "{start_of_chorus}", …
class SectionLabel {
  const SectionLabel({
    required this.type,
    this.number,
    this.name,
    this.isRepeat = false,
    this.isInstrumental = false,
  });

  final LyricsSegmentType type;

  /// "Verse 2" → 2. Picks which earlier section a repeat refers to.
  final int? number;

  /// Display name when the type's own name doesn't fit ("Tag", "Vamp").
  final String? name;

  /// "Repeat Chorus", "Chorus x2" — may refer back to an earlier section
  /// instead of introducing lyrics of its own.
  final bool isRepeat;

  /// "Instrumental", "Solo" — a heading with no lyrics of its own.
  final bool isInstrumental;
}

/// A label at the start of a line, plus any lyric that follows it on the same
/// line ("Chorus: Lift it higher" → rest "Lift it higher").
class LabelMatch {
  const LabelMatch(this.label, this.rest);

  final SectionLabel label;
  final String rest;
}

abstract final class SectionLabels {
  static const _kw =
      r'pre[\s-]?chorus|post[\s-]?chorus|chorus|refrain|hook|verse|stanza'
      r'|bridge|breakdown|break|intro|outro|ending|coda|tag|vamp|interlude'
      r'|instrumental|solo|turnaround|channel|lift|spoken|rap|ad[\s-]?libs?'
      r'|pre';

  /// Planning Center–style shorthands. Only accepted as a whole label, never
  /// in front of lyrics; "c" and "b" also read as chords on chord sheets.
  static const _short = r'pc|ch|br|v|c|b|t';

  static const _repeat =
      r'[(\[]?\s*(?:x\s?\d+|\d+\s?x|×\s?\d+|\d+\s+times|twice|repeat)\s*[)\]]?';

  /// A label word, an optional number (not "2x"), an optional repeat marker.
  static const _core =
      '(?:(repeat)\\s+(?:the\\s+)?)?($_kw|$_short)(?![\\p{L}])'
      '\\s*(\\d+(?!\\s?x\\b))?\\s*($_repeat)?';

  /// Whole bare line: "Chorus", "VERSE 2:", "Repeat Chorus x2",
  /// or `Chorus: <lyric>`.
  static final _bare = RegExp(
    '^$_core\\s*(?::\\s*(.*))?\$',
    caseSensitive: false,
    unicode: true,
  );

  /// Content of a wrapper: "Verse 1: Artist", "Chorus 2x", "Verse 1 & 2".
  static final _wrappedStrict = RegExp(
    '^$_core\\s*(?:[:\\-–—&,/+(].*)?\$',
    caseSensitive: false,
    unicode: true,
  );

  /// Square brackets are headings on lyric sites ("[Final Chorus]",
  /// "[Instrumental Break]"), so a label word anywhere in a short bracketed
  /// heading counts.
  static final _wordAnywhere = RegExp(
    '(?<![\\p{L}])($_kw)(?![\\p{L}])\\s*(\\d+(?!\\s?x\\b))?',
    caseSensitive: false,
    unicode: true,
  );

  static final _repeatWord = RegExp(
    r'\brepeat\b|\bx\s?\d|\d\s?x\b|×|\btwice\b|\btimes\b',
    caseSensitive: false,
  );

  static const _wrappers = {'[': ']', '(': ')', '{': '}', '<': '>'};

  /// Parses a label at the start of [line]. With [chordSheet], the
  /// single-letter shorthands that are also chord names ("C", "B2") are
  /// left for the chord filter.
  static LabelMatch? match(String line, {bool chordSheet = false}) {
    final t = line.trim();
    if (t.isEmpty) return null;

    final wrapped = _splitWrapper(t);
    if (wrapped != null) {
      final (content, rest) = wrapped;
      final label = _parseWrapped(
        content,
        square: t[0] == '[',
        chordSheet: chordSheet,
      );
      if (label == null) return null;
      return LabelMatch(label, rest);
    }

    final m = _bare.firstMatch(t);
    if (m == null) return null;
    final rest = (m.group(5) ?? '').trim();
    final label = _build(m, chordSheet: chordSheet, allowShort: rest.isEmpty);
    if (label == null) return null;
    return LabelMatch(label, rest);
  }

  /// Whether [line] is a square-bracketed heading at all (label or not):
  /// "[Part 2]", "[Produced by …]". Lyric sites use brackets only for these.
  static bool isBracketHeading(String line) {
    final t = line.trim();
    return t.length > 2 &&
        t.startsWith('[') &&
        t.endsWith(']') &&
        t.indexOf(']') == t.length - 1;
  }

  static final _trailing = RegExp(
    r'^(.*\S)\s*(?:\[([^\]]{1,40})\]|\(([^)]{1,40})\))$',
  );

  /// A label closing a lyric line ("…whispers of love. [Refrain]"). Hymnals
  /// mark where the refrain is sung again this way, so it's a repeat.
  static (String, SectionLabel)? trailingReference(
    String line, {
    bool chordSheet = false,
  }) {
    final m = _trailing.firstMatch(line.trim());
    if (m == null) return null;
    final square = m.group(2) != null;
    final label = _parseWrapped(
      (m.group(2) ?? m.group(3))!.trim(),
      square: square,
      chordSheet: chordSheet,
    );
    if (label == null) return null;
    return (m.group(1)!, _withRepeat(label));
  }

  /// Strips bracketed labels left inside a lyric line ("… sing [Chorus]").
  static String stripInlineLabels(String line) {
    return line.replaceAllMapped(RegExp(r'\s*\[([^\]]{1,40})\]\s*'), (m) {
      final label = _parseWrapped(m.group(1)!, square: true, chordSheet: true);
      return label == null ? m.group(0)! : ' ';
    }).trim();
  }

  static final _emphasis = RegExp(
    r'^(\*{1,2}|_{1,2})\s*([^*_]+?)\s*\1\s*(.*)$',
  );

  /// Splits "[Chorus] text", "(Verse 2):", "**Bridge**" into the wrapped
  /// content and whatever follows it.
  static (String, String)? _splitWrapper(String t) {
    final emphasis = _emphasis.firstMatch(t);
    if (emphasis != null) {
      return (emphasis.group(2)!, _trimLead(emphasis.group(3)!));
    }
    final close = _wrappers[t[0]];
    if (close == null) return null;
    final end = t.indexOf(close, 1);
    if (end == -1) return null;
    return (t.substring(1, end).trim(), _trimLead(t.substring(end + 1)));
  }

  static String _trimLead(String s) =>
      s.replaceFirst(RegExp(r'^\s*[:\-–—]?\s*'), '').trim();

  static SectionLabel? _parseWrapped(
    String content, {
    required bool square,
    required bool chordSheet,
  }) {
    final strict = _wrappedStrict.firstMatch(content);
    if (strict != null) {
      final label = _build(strict, chordSheet: chordSheet, allowShort: true);
      if (label != null) {
        final isRepeat = label.isRepeat || _repeatWord.hasMatch(content);
        return isRepeat ? _withRepeat(label) : label;
      }
    }
    if (!square || content.split(RegExp(r'\s+')).length > 5) return null;
    final loose = _wordAnywhere.firstMatch(content);
    if (loose == null) return null;
    final label = _fromWord(
      loose.group(1)!,
      number: int.tryParse(loose.group(2) ?? ''),
      isRepeat: _repeatWord.hasMatch(content),
    );
    return label;
  }

  static SectionLabel? _build(
    RegExpMatch m, {
    required bool chordSheet,
    required bool allowShort,
  }) {
    final word = m.group(2)!.toLowerCase();
    final isShort = RegExp('^(?:$_short)\$').hasMatch(word);
    if (isShort && !allowShort) return null;
    if (isShort && chordSheet && (word == 'c' || word == 'b')) return null;
    return _fromWord(
      word,
      number: int.tryParse(m.group(3) ?? ''),
      isRepeat: m.group(1) != null || m.group(4) != null,
    );
  }

  static SectionLabel? _fromWord(
    String word, {
    int? number,
    bool isRepeat = false,
  }) {
    final key = word.toLowerCase().replaceAll(RegExp(r'[\s-]'), '');
    final entry = _types[key == 'adlibs' ? 'adlib' : key];
    if (entry == null) return null;
    final (type, name, instrumental) = entry;
    return SectionLabel(
      type: type,
      number: number,
      name: name,
      isRepeat: isRepeat,
      isInstrumental: instrumental,
    );
  }

  static SectionLabel _withRepeat(SectionLabel l) => SectionLabel(
    type: l.type,
    number: l.number,
    name: l.name,
    isRepeat: true,
    isInstrumental: l.isInstrumental,
  );

  static const _types = <String, (LyricsSegmentType, String?, bool)>{
    'verse': (LyricsSegmentType.verse, null, false),
    'stanza': (LyricsSegmentType.verse, null, false),
    'v': (LyricsSegmentType.verse, null, false),
    'spoken': (LyricsSegmentType.verse, 'Spoken', false),
    'rap': (LyricsSegmentType.verse, 'Rap', false),
    'chorus': (LyricsSegmentType.chorus, null, false),
    'refrain': (LyricsSegmentType.chorus, null, false),
    'hook': (LyricsSegmentType.chorus, null, false),
    'c': (LyricsSegmentType.chorus, null, false),
    'ch': (LyricsSegmentType.chorus, null, false),
    'postchorus': (LyricsSegmentType.chorus, 'Post-Chorus', false),
    'prechorus': (LyricsSegmentType.preChorus, null, false),
    'pre': (LyricsSegmentType.preChorus, null, false),
    'pc': (LyricsSegmentType.preChorus, null, false),
    'channel': (LyricsSegmentType.preChorus, 'Channel', false),
    'lift': (LyricsSegmentType.preChorus, 'Lift', false),
    'bridge': (LyricsSegmentType.bridge, null, false),
    'b': (LyricsSegmentType.bridge, null, false),
    'br': (LyricsSegmentType.bridge, null, false),
    'break': (LyricsSegmentType.bridge, 'Break', false),
    'breakdown': (LyricsSegmentType.bridge, 'Breakdown', false),
    'vamp': (LyricsSegmentType.bridge, 'Vamp', false),
    'interlude': (LyricsSegmentType.bridge, 'Interlude', false),
    'adlib': (LyricsSegmentType.bridge, 'Ad-lib', false),
    'instrumental': (LyricsSegmentType.bridge, 'Instrumental', true),
    'solo': (LyricsSegmentType.bridge, 'Solo', true),
    'turnaround': (LyricsSegmentType.bridge, 'Turnaround', true),
    'intro': (LyricsSegmentType.intro, null, false),
    'outro': (LyricsSegmentType.outro, null, false),
    'ending': (LyricsSegmentType.outro, 'Ending', false),
    'coda': (LyricsSegmentType.outro, 'Coda', false),
    'tag': (LyricsSegmentType.outro, 'Tag', false),
    't': (LyricsSegmentType.outro, 'Tag', false),
  };
}
