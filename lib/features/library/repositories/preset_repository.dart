import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:lycri_lyrics/core/database/app_database.dart';
import 'package:lycri_lyrics/features/library/models/preset_domain_model.dart';

class PresetRepository {
  final AppDatabase _db;
  final _uuid = const Uuid();

  PresetRepository(this._db);

  /// Returns all presets ordered by time added (newest first).
  Future<List<PresetDomainModel>> getAllPresets() async {
    final query = _db.select(_db.presets)
      ..orderBy([(p) => OrderingTerm(expression: p.createdAt, mode: OrderingMode.desc)]);
    final entries = await query.get();

    return entries.map((e) => PresetDomainModel(
      id: e.id,
      name: e.name,
      data: e.data,
      createdAt: e.createdAt,
      updatedAt: e.updatedAt,
    )).toList();
  }

  /// Searches presets by name
  Future<List<PresetDomainModel>> searchPresets(String queryStr) async {
    final query = _db.select(_db.presets)
      ..where((p) => p.name.like('%$queryStr%'))
      ..orderBy([(p) => OrderingTerm(expression: p.createdAt, mode: OrderingMode.desc)]);
    
    final entries = await query.get();

    return entries.map((e) => PresetDomainModel(
      id: e.id,
      name: e.name,
      data: e.data,
      createdAt: e.createdAt,
      updatedAt: e.updatedAt,
    )).toList();
  }

  /// Check if a preset name already exists
  Future<bool> doesNameExist(String name) async {
    final countExp = _db.presets.id.count();
    final query = _db.selectOnly(_db.presets)
      ..addColumns([countExp])
      ..where(_db.presets.name.equals(name));
    final count = await query.map((row) => row.read(countExp)).getSingle();
    return (count ?? 0) > 0;
  }

  /// Adds a new preset. Does not allow overwriting.
  Future<PresetDomainModel> savePreset(String name, String data) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    final entry = PresetEntry(
      id: id,
      name: name,
      data: data,
      createdAt: now,
      updatedAt: now,
    );

    await _db.into(_db.presets).insert(entry);

    return PresetDomainModel(
      id: id,
      name: name,
      data: data,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Deletes a preset by id.
  Future<void> deletePreset(String id) async {
    await (_db.delete(_db.presets)..where((p) => p.id.equals(id))).go();
  }

  /// Exports all presets into a JSON string formatted for external backup.
  Future<String> exportPresetsToJson() async {
    final presets = await getAllPresets();
    final jsonList = presets.map((p) => p.toJson()).toList();
    return jsonEncode(jsonList);
  }

  /// Imports a JSON string backup, auto-incrementing duplicate titles.
  Future<int> importPresetsFromJson(String jsonStr) async {
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! List) return 0;
      
      int importedCount = 0;

      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        
        final tempPreset = PresetDomainModel.fromJson(item);
        
        // Handle name collisions
        String candidate = tempPreset.name.trim();
        if (candidate.isEmpty) candidate = "Untitled Preset";
        
        int count = 1;
        while (await doesNameExist(candidate)) {
          candidate = "${tempPreset.name.trim()} $count";
          count++;
        }
        
        await savePreset(candidate, tempPreset.data);
        importedCount++;
      }
      return importedCount;
    } catch (e) {
      return 0;
    }
  }
}
