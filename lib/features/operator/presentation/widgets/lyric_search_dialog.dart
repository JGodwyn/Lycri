import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lycri_lyrics/core/theme/app_colors.dart';
import 'package:lycri_lyrics/core/theme/app_radius.dart';
import 'package:lycri_lyrics/core/theme/app_spacing.dart';
import 'package:lycri_lyrics/core/theme/app_stroke.dart';
import 'package:lycri_lyrics/core/theme/app_typography.dart';
import 'package:lycri_lyrics/features/library/models/song_domain_model.dart';
import 'package:lycri_lyrics/features/library/providers/song_search_provider.dart';
import 'package:lycri_lyrics/features/library/providers/database_provider.dart';
import 'package:lycri_lyrics/shared/providers/lyrics_provider.dart';
import 'package:lycri_lyrics/shared/widgets/lycri_text_field.dart';

class LyricSearchDialog extends ConsumerStatefulWidget {
  const LyricSearchDialog({super.key});

  @override
  ConsumerState<LyricSearchDialog> createState() => _LyricSearchDialogState();
}

class _LyricSearchDialogState extends ConsumerState<LyricSearchDialog> {
  final _searchController = TextEditingController();
  final _listKey = GlobalKey<AnimatedListState>();
  final List<SongDomainModel> _items = [];

  @override
  void initState() {
    super.initState();
    // Refresh list on open
    Future.microtask(() => ref.read(songSearchProvider.notifier).search(""));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _syncList(List<SongDomainModel> newSongs) {
    // Basic sync logic: we update _items and inform the AnimatedListState
    // for a high-end feel. For simplicity in this logic, we compare current vs new.

    // 1. Handle removals
    for (int i = _items.length - 1; i >= 0; i--) {
      final oldSong = _items[i];
      if (!newSongs.any((s) => s.id == oldSong.id)) {
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

    // 2. Handle additions
    for (int i = 0; i < newSongs.length; i++) {
      final newSong = newSongs[i];
      if (!_items.any((s) => s.id == newSong.id)) {
        _items.insert(i, newSong);
        _listKey.currentState?.insertItem(
          i,
          duration: const Duration(milliseconds: 200),
        );
      }
    }
  }

  Future<void> _handleExport() async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Library',
      fileName: 'lycri_library_export.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (path != null) {
      final jsonStr = await ref.read(songRepositoryProvider).exportLibraryToJson();
      final file = File(path);
      await file.writeAsString(jsonStr);
    }
  }

  Future<void> _handleImport() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import Library',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final jsonStr = await file.readAsString();
      await ref.read(songRepositoryProvider).importLibraryFromJson(jsonStr);
      // Refresh the list to show newly imported lyrics smoothly
      ref.read(songSearchProvider.notifier).search(_searchController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(songSearchProvider);

    // Listen for data changes to sync the animated list
    ref.listen<AsyncValue<List<SongDomainModel>>>(songSearchProvider, (
      prev,
      next,
    ) {
      next.whenData((songs) => _syncList(songs));
    });

    return Dialog(
      backgroundColor: AppColors.surface3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      elevation: 0,
      child: Container(
        width: 480,
        height: 560,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          children: [
            // --- Header & Search ---
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Saved lyrics',
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
                            tooltip: 'Import Library',
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
                            tooltip: 'Export Library',
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
                    hintText: 'Search lyrics here',
                    autoFocus: true,
                    onChanged:
                        (val) =>
                            ref.read(songSearchProvider.notifier).search(val),
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

            // --- List Area ---
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOut,
                child: searchResults.when(
                  data: (songs) {
                    if (songs.isEmpty) {
                      return _buildEmptyState(key: const ValueKey('empty'));
                    }

                    return Align(
                      key: const ValueKey('data'),
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          0,
                          AppSpacing.lg,
                          AppSpacing.lg,
                        ),
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOutCubic,
                          alignment: Alignment.topCenter,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface4,
                              borderRadius: BorderRadius.circular(AppRadius.xl),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: AnimatedList(
                              key: _listKey,
                              initialItemCount: _items.length,
                              shrinkWrap: true,
                              physics: const ClampingScrollPhysics(),
                              padding: EdgeInsets.zero,
                              itemBuilder: (context, index, animation) {
                                // Double check index safety due to async syncing
                                if (index >= _items.length) {
                                  return const SizedBox.shrink();
                                }
                                final song = _items[index];
                                return _buildItem(
                                  song,
                                  animation,
                                  showDivider: index < _items.length - 1,
                                );
                              },
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
          ],
        ),
      ),
    );
  }

  Widget _buildItem(
    SongDomainModel song,
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
            _SongListItem(
              song: song,
              onTap: () {
                ref.read(segmentedLyricsProvider.notifier).loadSong(song);
                Navigator.of(context).pop();
              },
              onDelete:
                  () =>
                      ref.read(songSearchProvider.notifier).deleteSong(song.id),
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
            "No songs found",
            style: AppTypography.bodyLg.copyWith(color: AppColors.textSubtle),
          ),
        ],
      ),
    );
  }
}

class _SongListItem extends StatelessWidget {
  final SongDomainModel song;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SongListItem({
    required this.song,
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
          color: Colors.transparent, // For hit testing
          height: 48,
          padding: const EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.md,
          ),
          child: Row(
            children: [
              SvgPicture.asset(
                'assets/vectors/list-check.svg',
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
                  song.title,
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
