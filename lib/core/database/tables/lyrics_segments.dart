import 'package:drift/drift.dart';
import 'package:lycri_lyrics/features/operator/models/lyrics_segment.dart';
import 'package:lycri_lyrics/core/database/tables/songs.dart';

@DataClassName('LyricsSegmentEntry')
class LyricsSegments extends Table {
  TextColumn get id => text()();
  TextColumn get songId => text().references(Songs, #id)();
  TextColumn get textContent => text()();
  IntColumn get type => intEnum<LyricsSegmentType>()();
  IntColumn get segmentNumber => integer()();
  BoolColumn get isHidden => boolean().withDefault(const Constant(false))();
  IntColumn get orderIndex => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
