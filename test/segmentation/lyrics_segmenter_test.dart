import 'package:flutter_test/flutter_test.dart';
import 'package:lycri_lyrics/features/operator/models/lyrics_segment.dart';
import 'package:lycri_lyrics/features/operator/segmentation/lyrics_segmenter.dart';
import 'package:lycri_lyrics/features/operator/segmentation/section_label.dart';

import 'corpus.dart';

/// "type:lineCount" per section, for compact structure assertions.
List<String> shape(String raw, {String? title}) => [
  for (final s in LyricsSegmenter.segment(raw, title: title))
    '${s.type.name}:${s.text.split('\n').length}',
];

List<String> texts(String raw) =>
    LyricsSegmenter.segment(raw).map((s) => s.text).toList();

const _vcvcbc = [
  'verse:4',
  'chorus:4',
  'verse:4',
  'chorus:4',
  'bridge:4',
  'chorus:4',
];

void main() {
  group('structure', () {
    test('well-formed song: verse before a chorus stays a verse', () {
      expect(shape(corpus['well_formed']!), _vcvcbc);
    });

    test('labels are kept, even with no blank lines between sections', () {
      expect(shape(corpus['labels_no_blanks']!), _vcvcbc);
      expect(
        LyricsSegmenter.segment(
          corpus['labels_no_blanks']!,
        ).every((s) => s.isExplicit),
        isTrue,
      );
    });

    test('no blank lines, no labels: cut at the repeated chorus', () {
      expect(shape(corpus['no_blanks_no_labels']!), _vcvcbc);
    });

    test('double-spaced paste is rejoined into stanzas', () {
      expect(shape(corpus['double_spaced']!), [
        'verse:4',
        'chorus:4',
        'verse:4',
        'chorus:4',
      ]);
    });

    test('a doubled final chorus becomes two choruses', () {
      expect(shape(corpus['final_chorus_doubled']!), [
        'verse:4',
        'chorus:4',
        'verse:4',
        'chorus:4',
        'chorus:4',
        'chorus:4',
      ]);
    });

    test('a third verse is not mistaken for a bridge', () {
      final song = [
        verse1,
        chorus,
        verse2,
        chorus,
        verse3,
        chorus,
      ].join('\n\n');
      expect(shape(song), [
        'verse:4',
        'chorus:4',
        'verse:4',
        'chorus:4',
        'verse:4',
        'chorus:4',
      ]);
    });

    test('a repeated block between verse and chorus is a pre-chorus', () {
      const pre = 'Here it comes now\nFeel the ground begin to shake';
      final song = [verse1, pre, chorus, verse2, pre, chorus].join('\n\n');
      expect(shape(song), [
        'verse:4',
        'preChorus:2',
        'chorus:4',
        'verse:4',
        'preChorus:2',
        'chorus:4',
      ]);
    });

    test('a verse glued to a chorus is cut where the chorus starts', () {
      final song = '$verse1\n\n$chorus\n\n$verse2\n$chorus';
      expect(shape(song), ['verse:4', 'chorus:4', 'verse:4', 'chorus:4']);
    });

    test('long unstructured block splits without a one-line tail', () {
      expect(shape(corpus['nine_line_block']!), ['verse:4', 'verse:5']);
      final long = [verse1, verse2, verse3, bridge].join('\n');
      for (final s in shape(long)) {
        final lines = int.parse(s.split(':').last);
        expect(lines, inInclusiveRange(2, LyricsSegmenter.maxLines));
      }
    });

    test('short first and last blocks are intro and outro', () {
      final song = [
        'Oh oh oh',
        verse1,
        chorus,
        verse2,
        chorus,
        'Amen',
      ].join('\n\n');
      expect(shape(song).first, 'intro:1');
      expect(shape(song).last, 'outro:1');
    });

    test('non-Latin lyrics are not all grouped as choruses', () {
      const a =
          'Αλφα βητα γαμμα\nΔελτα εψιλον ζητα\nΗτα θητα ιωτα\nΚαππα λαμδα μυ';
      const b = 'Νυ ξι ομικρον\nΠι ρω σιγμα\nΤαυ υψιλον φι\nΧι ψι ωμεγα';
      const c =
          'Ουρανός και γη\nΘάλασσα και φως\nΆνεμος και βροχή\nΝύχτα και αυγή';
      expect(shape([a, b, c].join('\n\n')), ['verse:4', 'verse:4', 'verse:4']);
      expect(shape([a, b, a, c].join('\n\n')), [
        'chorus:4',
        'verse:4',
        'chorus:4',
        'verse:4',
      ]);
    });
  });

  group('labels', () {
    test('bare, colon, short and repeat labels', () {
      expect(shape(corpus['worship_bare_labels']!), _vcvcbc);
      expect(shape(corpus['short_labels']!), [
        'verse:4',
        'chorus:4',
        'verse:4',
        'chorus:4',
      ]);
    });

    test('label followed by a blank line still owns the lyrics', () {
      final song = 'Chorus\n\n$chorus\n\nVerse 2\n\n$verse2';
      expect(shape(song), ['chorus:4', 'verse:4']);
    });

    test('labelled once, unlabelled copies inherit the type', () {
      final song = '[Chorus]\n$chorus\n\n$verse1\n\n$chorus\n\n$verse2';
      expect(shape(song), ['chorus:4', 'verse:4', 'chorus:4', 'verse:4']);
    });

    test('inline label: "Chorus: first line"', () {
      final lines = chorus.split('\n');
      final song =
          '$verse1\n\nChorus: ${lines.first}\n${lines.skip(1).join('\n')}';
      expect(shape(song), ['verse:4', 'chorus:4']);
      expect(texts(song).last.split('\n').first, lines.first);
    });

    test('"Repeat Verse 1" copies the numbered verse', () {
      final song = 'Verse 1\n$verse1\n\nVerse 2\n$verse2\n\nRepeat Verse 1';
      expect(texts(song).last, verse1);
    });

    test('"Chorus x2" before an unlabelled chorus labels it', () {
      final song = '$verse1\n\nChorus x2\n\n$chorus';
      expect(shape(song), ['verse:4', 'chorus:4']);
    });

    test('instrumental headings and unknown [headings] are boundaries', () {
      final song = '$verse1\n[Instrumental]\n$verse2\n[Part 2]\n$verse3';
      expect(shape(song), ['verse:4', 'verse:4', 'verse:4']);
    });

    test('Tag and Vamp keep their names', () {
      final song = '$verse1\n\nTag\n$bridge\n\nVamp:\n$chorus';
      final segs = LyricsSegmenter.segment(song);
      expect(segs[1].label, 'Tag');
      expect(segs[2].label, 'Vamp');
    });

    test('hymn stanza numbers', () {
      final song = '1. $verse1\n\n2\n$verse2';
      final segs = LyricsSegmenter.segment(song);
      expect(shape(song), ['verse:4', 'verse:4']);
      expect(segs.first.text, verse1);
    });

    test('hymnal layout: unpunctuated numbers and [Refrain] repeats', () {
      final segs = LyricsSegmenter.segment(blessedAssurance);
      expect(shape(blessedAssurance), [
        'verse:4',
        'chorus:4',
        'verse:4',
        'chorus:4',
        'verse:4',
        'chorus:4',
      ]);
      expect(segs[0].text, startsWith('Blessed assurance'));
      expect(segs[2].text, endsWith('whispers of love.'));
      expect(segs[3].text, segs[1].text);
    });

    test('parenthesised lyric lines are kept', () {
      final all = texts(corpus['parenthesised_lyrics']!).join('\n');
      expect(all, contains('(Breaking every chain)'));
      expect(all, contains('(Prepare the way)'));
      expect(all, contains('(Lift your hands)'));
    });

    test('label parser rejects lyrics that start with a label word', () {
      for (final lyric in [
        'Bridge over troubled water',
        '(Breaking every chain)',
        '(Prepare the way)',
        '(Lift your hands)',
        'Chorus of angels sing',
        'Tag, you are it',
        'Be still',
        'Verses',
      ]) {
        expect(SectionLabels.match(lyric), isNull, reason: lyric);
      }
    });

    test('label parser accepts common heading styles', () {
      final cases = {
        '[Verse 1: Some Artist]': LyricsSegmentType.verse,
        '[Chorus 2x]': LyricsSegmentType.chorus,
        '(Pre-Chorus)': LyricsSegmentType.preChorus,
        'PRE CHORUS:': LyricsSegmentType.preChorus,
        '**Bridge**': LyricsSegmentType.bridge,
        'V2': LyricsSegmentType.verse,
        'PC': LyricsSegmentType.preChorus,
        'Repeat Chorus': LyricsSegmentType.chorus,
        '[Final Chorus]': LyricsSegmentType.chorus,
        'Outro': LyricsSegmentType.outro,
        'Intro:': LyricsSegmentType.intro,
      };
      cases.forEach((line, type) {
        expect(SectionLabels.match(line)?.label.type, type, reason: line);
      });
      expect(SectionLabels.match('Chorus x2')!.label.isRepeat, isTrue);
      expect(SectionLabels.match('Verse 2')!.label.number, 2);
      expect(SectionLabels.match('Chorus 2x')!.label.number, isNull);
    });
  });

  group('cleanup', () {
    test('site chrome, title and credits are removed', () {
      expect(shape(corpus['genius_junk']!), [
        'verse:4',
        'chorus:4',
        'verse:4',
        'chorus:4',
      ]);
      expect(shape(corpus['chords_and_ccli']!), ['verse:4', 'chorus:4']);
    });

    test('ChordPro chords and directives', () {
      final segs = LyricsSegmenter.segment(corpus['chordpro']!);
      expect(segs.map((s) => s.type), [
        LyricsSegmentType.verse,
        LyricsSegmentType.chorus,
      ]);
      expect(segs.first.text, startsWith('Morning breaks across the valley'));
      expect(segs.any((s) => s.text.contains('[')), isFalse);
    });

    test('slash-separated lines are split', () {
      expect(shape(corpus['slash_separated']!), ['verse:4', 'verse:4']);
    });

    test('CRLF, zero-width and NBSP blank lines, separator lines', () {
      expect(shape(corpus['windows_and_invisible']!), [
        'verse:4',
        'chorus:4',
        'verse:4',
        'chorus:4',
      ]);
      final all = texts(corpus['windows_and_invisible']!).join('\n');
      expect(all, isNot(contains('\r')));
      expect(all, isNot(contains('​')));
    });

    test('repeat markers are stripped from lyric lines', () {
      final last = texts(corpus['repeat_markers']!).last;
      expect(
        last,
        isNot(matches(RegExp(r'x2|2x|Repeat', caseSensitive: false))),
      );
    });

    test('title line matching the song name is dropped', () {
      expect(shape('Higher\n\n$verse1\n\n$chorus', title: 'Higher'), [
        'verse:4',
        'verse:4',
      ]);
    });

    test('credit-like lyric lines past the header are kept', () {
      final song = '$verse1\n\nWritten by the hand of God\nCarved in stone';
      expect(texts(song).last, startsWith('Written by the hand of God'));
    });

    test('accents survive and lines stay intact', () {
      const v = 'Canción de la mañana\nÁngeles cantan aquí';
      expect(texts('$v\n\n$verse1').first, v);
    });

    test('paste with nothing but junk yields nothing', () {
      expect(LyricsSegmenter.segment('CCLI Song # 123\n\n---\n'), isEmpty);
      expect(LyricsSegmenter.segment('   \n\n'), isEmpty);
    });

    test('a 300-line paste segments quickly', () {
      final big = List.generate(
        12,
        (_) => [verse1, chorus].join('\n'),
      ).join('\n');
      final sw = Stopwatch()..start();
      LyricsSegmenter.segment('$big\n$big\n$big');
      expect(sw.elapsedMilliseconds, lessThan(500));
    });
  });
}
