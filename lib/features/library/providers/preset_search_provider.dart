import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lycri_lyrics/features/library/models/preset_domain_model.dart';
import 'package:lycri_lyrics/features/library/providers/database_provider.dart';

class PresetSearchNotifier extends StateNotifier<AsyncValue<List<PresetDomainModel>>> {
  final Ref _ref;

  PresetSearchNotifier(this._ref) : super(const AsyncValue.loading());

  Future<void> search(String query) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(presetRepositoryProvider);
      final results = query.isEmpty
          ? await repo.getAllPresets()
          : await repo.searchPresets(query);
      if (mounted) {
        state = AsyncValue.data(results);
      }
    } catch (e, st) {
      if (mounted) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> deletePreset(String id) async {
    try {
      await _ref.read(presetRepositoryProvider).deletePreset(id);
      // Re-fetch current data
      state.whenData((currentList) {
        final newList = currentList.where((p) => p.id != id).toList();
        state = AsyncValue.data(newList);
      });
    } catch (_) {}
  }
}

final presetSearchProvider =
    StateNotifierProvider<PresetSearchNotifier, AsyncValue<List<PresetDomainModel>>>((ref) {
  return PresetSearchNotifier(ref);
});
