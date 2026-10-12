import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lycri_lyrics/features/operator/models/lyrics_segment.dart';
import 'package:lycri_lyrics/shared/providers/lyrics_provider.dart';

import 'corpus.dart';

void main() {
  late ProviderContainer container;
  SegmentedLyricsNotifier notifier() =>
      container.read(segmentedLyricsProvider.notifier);
  List<LyricsSegment> segments() =>
      container.read(segmentedLyricsProvider).segments;

  Future<void> cleanUp(String text) async {
    container.read(lyricsProvider.notifier).update(text);
    await notifier().cleanup();
  }

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('fresh cleanup numbers each type in order', () async {
    await cleanUp([verse1, chorus, verse2, chorus].join('\n\n'));
    expect(segments().map((s) => '${s.type.name} ${s.number}'), [
      'verse 1',
      'chorus 1',
      'verse 2',
      'chorus 2',
    ]);
  });

  test('re-cleaning an edit keeps names and hidden flags, renumbers', () async {
    await cleanUp([verse1, chorus, verse2, chorus].join('\n\n'));
    final firstVerse = segments()[0];
    notifier().renameSegment(firstVerse.id, 'Opening');
    notifier().toggleHideSegment(segments()[3].id);

    notifier().reset();
    // Add a new verse at the top, then clean up again.
    final raw = container.read(lyricsProvider)!;
    await cleanUp('$verse3\n\n$raw');

    final after = segments();
    expect(after.map((s) => '${s.type.name} ${s.number}'), [
      'verse 1',
      'verse 2',
      'chorus 1',
      'verse 3',
      'chorus 2',
    ]);
    expect(after[1].id, firstVerse.id);
    expect(after[1].label, 'Opening');
    expect(after[4].isHidden, isTrue);
  });

  test('a label typed into the edit overrides the cached type', () async {
    await cleanUp([verse1, chorus, verse2, chorus].join('\n\n'));
    notifier().reset();
    await cleanUp([verse1, chorus, '[Bridge]\n$verse2', chorus].join('\n\n'));
    expect(segments()[2].type, LyricsSegmentType.bridge);
  });
}
