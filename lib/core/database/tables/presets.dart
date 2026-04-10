import 'package:drift/drift.dart';

@DataClassName('PresetEntry')
class Presets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get data => text()(); // Will hold JSON
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
