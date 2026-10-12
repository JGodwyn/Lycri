/// Messy pastes used to exercise the segmentation engine. Lyrics are invented
/// placeholders, except [blessedAssurance] (Fanny Crosby, 1873, public
/// domain).
library;

const verse1 = '''Morning breaks across the valley floor
Every shadow running for the door
I was lost but now the light is near
Calling out my name so I can hear''';

const verse2 = '''Rivers rise and mountains bow down low
Every season tells me what I know
Though the night was long I'm standing here
Singing loud above the doubt and fear''';

const verse3 = '''When the storm is raging on the sea
Still your voice is calling out to me
Every wave will settle at your word
Every cry from heaven will be heard''';

const chorus = '''Lift it higher, let the whole world sing
You are faithful, you are everything
Lift it higher, let the anthem ring
You are faithful, our forever King''';

const bridge = '''Nothing can stand against you
Nothing can separate
Nothing can stand against you
Love that will never break''';

final corpus = <String, String>{
  // Genius-style labels, no blank lines between sections.
  'labels_no_blanks': '''[Verse 1]
$verse1
[Chorus]
$chorus
[Verse 2]
$verse2
[Chorus]
$chorus
[Bridge]
$bridge
[Chorus]
$chorus''',

  // Genius header/footer junk + artist-annotated labels.
  'genius_junk': '''12 ContributorsTranslationsEspañolHigher Lyrics
[Verse 1: Some Artist]
$verse1

[Chorus: Some Artist & Choir]
$chorus

You might also like
[Verse 2]
$verse2

[Chorus]
$chorus
42Embed''',

  // Whole song pasted with no blank lines and no labels.
  'no_blanks_no_labels': '$verse1\n$chorus\n$verse2\n$chorus\n$bridge\n$chorus',

  // Each line separated by a blank line; stanzas by two blank lines.
  'double_spaced': [
    verse1,
    chorus,
    verse2,
    chorus,
  ].map((s) => s.split('\n').join('\n\n')).join('\n\n\n'),

  // Worship-team format: bare labels, colon labels, repeat markers.
  'worship_bare_labels': '''Verse 1
$verse1

CHORUS:
$chorus

Verse 2:
$verse2

Repeat Chorus

Bridge (x3)
$bridge

Chorus''',

  // Short labels (Planning Center style).
  'short_labels': '''V1
$verse1
C
$chorus
V2
$verse2
C
$chorus''',

  // Lyric lines that happen to be parenthesised.
  'parenthesised_lyrics': '''$verse1
(Breaking every chain)
(Prepare the way)

$chorus
(Lift your hands)

$verse2

$chorus''',

  // Chord sheet + CCLI footer.
  'chords_and_ccli': '''Higher
Words and Music by Someone Else

Verse 1
G           D/F#
Morning breaks across the valley floor
Em          C
Every shadow running for the door
G           D/F#        Em
I was lost but now the light is near
C                 D
Calling out my name so I can hear

Chorus
G     D     Em    C
$chorus

CCLI Song # 1234567
© 2019 Some Publishing (Admin. by Someone)
For use solely with the SongSelect® Terms of Use. All rights reserved. www.ccli.com
CCLI License # 7654321''',

  // ChordPro inline chords and directives.
  'chordpro': '''{title: Higher}
{start_of_verse}
[G]Morning breaks across the [D/F#]valley floor
[Em]Every shadow running [C]for the door
{end_of_verse}
{start_of_chorus}
[G]Lift it higher, let the [D]whole world sing
[Em]You are faithful, you are [C]everything
{end_of_chorus}''',

  // Well-formed: verse directly before chorus every time.
  'well_formed': [verse1, chorus, verse2, chorus, bridge, chorus].join('\n\n'),

  // Final chorus sung twice in one block.
  'final_chorus_doubled': [
    verse1,
    chorus,
    verse2,
    chorus,
    '$chorus\n$chorus',
  ].join('\n\n'),

  // Slash-separated lines (quoted from a website / message).
  'slash_separated':
      '${verse1.split('\n').join(' / ')}\n\n${chorus.split('\n').join(' / ')}',

  // Windows line endings, NBSP / zero-width "blank" lines, separator lines.
  'windows_and_invisible':
      '$verse1\r\n​\r\n$chorus\r\n \r\n$verse2\r\n---\r\n$chorus'
          .replaceAll('\n', '\r\n')
          .replaceAll('\r\r\n', '\r\n'),

  // Repeat markers on lines.
  'repeat_markers': '''$verse1

Lift it higher, let the whole world sing (x2)
You are faithful, you are everything x2
Lift it higher [2x]
Hallelujah (Repeat)''',

  // 9 lines in one block: check for orphan tails.
  'nine_line_block': '$verse1\n$verse2\nAmen',
};

/// Hymnary.org layout: unpunctuated stanza numbers, "Refrain:" heading, and
/// "[Refrain]" closing a stanza where the refrain is sung again.
const blessedAssurance = '''1 Blessed assurance, Jesus is mine!
O what a foretaste of glory divine!
Heir of salvation, purchase of God,
born of His Spirit, washed in His blood.

Refrain:
This is my story, this is my song,
praising my Savior all the day long;
this is my story, this is my song,
praising my Savior all the day long.

2 Perfect submission, perfect delight,
visions of rapture now burst on my sight;
angels descending bring from above
echoes of mercy, whispers of love. [Refrain]

3 Perfect submission, all is at rest;
I in my Savior am happy and blest,
watching and waiting, looking above,
filled with His goodness, lost in His love. [Refrain]''';
