import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lycri_lyrics/shared/providers/last_directory_provider.dart';
import 'package:lycri_lyrics/core/theme/app_colors.dart';
import 'package:lycri_lyrics/core/theme/app_radius.dart';
import 'package:lycri_lyrics/core/theme/app_spacing.dart';
import 'package:lycri_lyrics/core/theme/app_stroke.dart';
import 'package:lycri_lyrics/core/theme/app_typography.dart';
import 'package:lycri_lyrics/features/library/models/preset_domain_model.dart';
import 'package:lycri_lyrics/features/library/providers/preset_search_provider.dart';
import 'package:lycri_lyrics/shared/providers/lyrics_style_provider.dart';
import 'package:lycri_lyrics/features/operator/providers/preset_state_provider.dart';
import 'package:lycri_lyrics/features/library/providers/database_provider.dart';
import 'package:lycri_lyrics/shared/widgets/lycri_text_field.dart';

class PresetSearchDialog extends ConsumerStatefulWidget {
  const PresetSearchDialog({super.key});

  @override
  ConsumerState<PresetSearchDialog> createState() => _PresetSearchDialogState();
}

class _PresetSearchDialogState extends ConsumerState<PresetSearchDialog> {
  final _searchController = TextEditingController();
  final _listKey = GlobalKey<AnimatedListState>();
  final _scrollController = ScrollController();
  final List<PresetDomainModel> _items = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(presetSearchProvider.notifier).search(""));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncList(List<PresetDomainModel> newPresets) {
    for (int i = _items.length - 1; i >= 0; i--) {
      final oldPreset = _items[i];
      if (!newPresets.any((p) => p.id == oldPreset.id)) {
        final removedItem = _items.removeAt(i);
        _listKey.currentState?.removeItem(
          i,
          (context, animation) => _buildItem(
            removedItem,
            animation,
            showDivider: i < _items.length,
          ),
          duration: const Duration(milliseconds: 250),
        );
      }
    }
    for (int i = 0; i < newPresets.length; i++) {
      final newPreset = newPresets[i];
      if (!_items.any((p) => p.id == newPreset.id)) {
        _items.insert(i, newPreset);
        _listKey.currentState?.insertItem(
          i,
          duration: const Duration(milliseconds: 200),
        );
      }
    }
  }

  Future<void> _handleExport() async {
    final lastDir = ref.read(lastPickerDirectoryProvider);
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Presets',
      fileName: 'lycri_presets_export.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
      initialDirectory: lastDir,
    );
    if (path != null) {
      ref.read(lastPickerDirectoryProvider.notifier).update(path);
      final jsonStr =
          await ref.read(presetRepositoryProvider).exportPresetsToJson();
      final file = File(path);
      await file.writeAsString(jsonStr);
    }
  }

  Future<void> _handleImport() async {
    final lastDir = ref.read(lastPickerDirectoryProvider);
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import Presets',
      type: FileType.custom,
      allowedExtensions: ['json'],
      initialDirectory: lastDir,
    );
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      ref.read(lastPickerDirectoryProvider.notifier).update(path);
      final file = File(path);
      final jsonStr = await file.readAsString();
      await ref.read(presetRepositoryProvider).importPresetsFromJson(jsonStr);
      ref.read(presetSearchProvider.notifier).search(_searchController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(presetSearchProvider);

    ref.listen<AsyncValue<List<PresetDomainModel>>>(presetSearchProvider, (
      prev,
      next,
    ) {
      next.whenData((presets) => _syncList(presets));
    });

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 480,
        height: 560,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface3,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Saved presets',
                        style: AppTypography.headingSm.copyWith(
                          color: AppColors.textBold,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: _handleImport,
                            icon: SvgPicture.asset(
                              'assets/vectors/Import-down.svg',
                              width: 18,
                              height: 18,
                              colorFilter: const ColorFilter.mode(
                                AppColors.iconSubtle,
                                BlendMode.srcIn,
                              ),
                            ),
                            tooltip: 'Import presets',
                            visualDensity: VisualDensity.compact,
                            splashRadius: 18,
                          ),
                          IconButton(
                            onPressed: _handleExport,
                            icon: SvgPicture.asset(
                              'assets/vectors/Export-up.svg',
                              width: 18,
                              height: 18,
                              colorFilter: const ColorFilter.mode(
                                AppColors.iconSubtle,
                                BlendMode.srcIn,
                              ),
                            ),
                            tooltip: 'Export presets',
                            visualDensity: VisualDensity.compact,
                            splashRadius: 18,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: AppColors.iconSubtle,
                              size: 20,
                            ),
                            visualDensity: VisualDensity.compact,
                            splashRadius: 18,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  LycriTextField(
                    controller: _searchController,
                    hintText: 'Search presets here',
                    autoFocus: true,
                    onChanged:
                        (val) =>
                            ref.read(presetSearchProvider.notifier).search(val),
                    prefixIcon: SvgPicture.asset(
                      'assets/vectors/magnifyingglass.svg',
                      width: 18,
                      height: 18,
                      colorFilter: const ColorFilter.mode(
                        AppColors.iconSubtle,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(
                  bottom: AppSpacing.lg,
                  top: AppSpacing.md,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeOut,
                    child: searchResults.when(
                      data: (presets) {
                        if (presets.isEmpty)
                          return _buildEmptyState(key: const ValueKey('empty'));
                        return Scrollbar(
                          key: const ValueKey('data'),
                          controller: _scrollController,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                              ),
                              child: AnimatedSize(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeInOutCubic,
                                alignment: Alignment.topCenter,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.surface4,
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.xl,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.05,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: ScrollConfiguration(
                                    behavior: ScrollConfiguration.of(
                                      context,
                                    ).copyWith(scrollbars: false),
                                    child: AnimatedList(
                                      key: _listKey,
                                      controller: _scrollController,
                                      initialItemCount: _items.length,
                                      shrinkWrap: true,
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      padding: EdgeInsets.zero,
                                      itemBuilder: (context, index, animation) {
                                        if (index >= _items.length)
                                          return const SizedBox.shrink();
                                        final preset = _items[index];
                                        return _buildItem(
                                          preset,
                                          animation,
                                          showDivider:
                                              index < _items.length - 1,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      loading:
                          () => const Center(
                            key: ValueKey('loading'),
                            child: CircularProgressIndicator(
                              color: AppColors.surfaceBrand,
                            ),
                          ),
                      error:
                          (e, _) => Center(
                            key: const ValueKey('error'),
                            child: Text(
                              "Error: $e",
                              style: AppTypography.bodySm.copyWith(
                                color: AppColors.textDanger,
                              ),
                            ),
                          ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(
    PresetDomainModel preset,
    Animation<double> animation, {
    bool showDivider = true,
  }) {
    return FadeTransition(
      opacity: animation,
      child: SizeTransition(
        sizeFactor: CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubic,
        ),
        axisAlignment: 0.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PresetListItem(
              preset: preset,
              onTap: () {
                ref.read(presetStateProvider.notifier).applyPreset(preset);
                ref
                    .read(lyricsStyleProvider.notifier)
                    .applyPresetData(preset.data);
                Navigator.of(context).pop();
              },
              onDelete:
                  () => ref
                      .read(presetSearchProvider.notifier)
                      .deletePreset(preset.id),
            ),
            if (showDivider)
              const Divider(
                height: 1,
                thickness: AppStroke.md,
                color: AppColors.borderMinimal,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({Key? key}) {
    return Center(
      key: key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/vectors/magnifyingglass.svg',
            width: 48,
            height: 48,
            colorFilter: ColorFilter.mode(
              AppColors.iconMinimal.withValues(alpha: 0.5),
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            "No presets found",
            style: AppTypography.bodyLg.copyWith(color: AppColors.textSubtle),
          ),
        ],
      ),
    );
  }
}

class _PresetListItem extends StatelessWidget {
  final PresetDomainModel preset;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PresetListItem({
    required this.preset,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          color: Colors.transparent,
          height: 48,
          padding: const EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.md,
          ),
          child: Row(
            children: [
              SvgPicture.asset(
                'assets/vectors/slider.svg',
                width: 20,
                height: 20,
                colorFilter: const ColorFilter.mode(
                  AppColors.iconMinimal,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  preset.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyLg.copyWith(
                    color: AppColors.textBold,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              IconButton(
                onPressed: onDelete,
                icon: SvgPicture.asset(
                  'assets/vectors/delete-trash.svg',
                  width: 18,
                  height: 18,
                  colorFilter: const ColorFilter.mode(
                    AppColors.iconMinimal,
                    BlendMode.srcIn,
                  ),
                ),
                splashRadius: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
