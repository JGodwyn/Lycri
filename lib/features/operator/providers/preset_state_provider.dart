import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lycri_lyrics/features/library/models/preset_domain_model.dart';
import 'package:lycri_lyrics/features/library/providers/database_provider.dart';

class PresetState {
  final PresetDomainModel? currentPreset;
  final bool isDirty;
  
  const PresetState({this.currentPreset, this.isDirty = false});
  
  PresetState copyWith({
    PresetDomainModel? currentPreset,
    bool clearPreset = false,
    bool? isDirty,
  }) {
    return PresetState(
      currentPreset: clearPreset ? null : (currentPreset ?? this.currentPreset),
      isDirty: isDirty ?? this.isDirty,
    );
  }
}

final presetStateProvider = StateNotifierProvider<PresetStateNotifier, PresetState>((ref) {
  return PresetStateNotifier(ref);
});

class PresetStateNotifier extends StateNotifier<PresetState> {
  final Ref _ref;

  PresetStateNotifier(this._ref) : super(const PresetState(isDirty: false));

  void markDirty() {
    if (!state.isDirty) {
      state = state.copyWith(isDirty: true);
    }
  }
  
  void applyPreset(PresetDomainModel preset) {
    state = state.copyWith(currentPreset: preset, isDirty: false, clearPreset: false);
  }

  Future<void> saveCurrentAsPreset(String name, String data) async {
    final repo = _ref.read(presetRepositoryProvider);
    final savedPreset = await repo.savePreset(name, data);
    state = state.copyWith(currentPreset: savedPreset, isDirty: false, clearPreset: false);
  }

  void clearPreset() {
    state = state.copyWith(clearPreset: true, isDirty: false);
  }
}
