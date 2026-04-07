import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lycri_lyrics/core/theme/app_colors.dart';
import 'package:lycri_lyrics/core/theme/app_radius.dart';
import 'package:lycri_lyrics/core/theme/app_spacing.dart';
import 'package:lycri_lyrics/core/theme/app_stroke.dart';
import 'package:lycri_lyrics/core/theme/app_typography.dart';
import 'package:lycri_lyrics/features/library/models/song_domain_model.dart';
import 'package:lycri_lyrics/features/library/providers/song_search_provider.dart';
import 'package:lycri_lyrics/shared/providers/lyrics_provider.dart';
import 'package:lycri_lyrics/shared/utils/dialog_utils.dart';
import 'package:lycri_lyrics/shared/widgets/lycri_text_field.dart';

class LyricSearchDialog extends ConsumerStatefulWidget {
  const LyricSearchDialog({super.key});

  @override
  ConsumerState<LyricSearchDialog> createState() => _LyricSearchDialogState();
}

class _LyricSearchDialogState extends ConsumerState<LyricSearchDialog> {
  final _searchController = TextEditingController();

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

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(songSearchProvider);

    return Dialog(
      backgroundColor: AppColors.surface3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      elevation: 0,
      child: Container(
        width: 500,
        height: 600,
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
              child: searchResults.when(
                data: (songs) {
                  if (songs.isEmpty) return _buildEmptyState();

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface4,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: songs.length,
                        separatorBuilder:
                            (context, index) => const Divider(
                              height: 1,
                              thickness: AppStroke.sm,
                              color: AppColors.borderSubtle,
                              indent: AppSpacing.xl,
                              endIndent: AppSpacing.xl,
                            ),
                        itemBuilder: (context, index) {
                          final song = songs[index];
                          return _SongListItem(
                            song: song,
                            onTap: () {
                              ref
                                  .read(segmentedLyricsProvider.notifier)
                                  .loadSong(song);
                              Navigator.of(context).pop();
                            },
                            onDelete:
                                () => ref
                                    .read(songSearchProvider.notifier)
                                    .deleteSong(song.id),
                          );
                        },
                      ),
                    ),
                  );
                },
                loading:
                    () => const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.surfaceBrand,
                      ),
                    ),
                error:
                    (e, _) => Center(
                      child: Text(
                        "Error: $e",
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.textDanger,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
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
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
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
                onPressed: () => _confirmDelete(context),
                icon: SvgPicture.asset(
                  'assets/vectors/delete-trash.svg',
                  width: 18,
                  height: 18,
                  colorFilter: const ColorFilter.mode(
                    AppColors.iconMinimal,
                    BlendMode.srcIn,
                  ),
                ),
                tooltip: 'Delete',
                splashRadius: 20,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) async {
    final confirmed = await showLycriDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors.surface4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            title: const Text('Delete Song?'),
            content: Text(
              'Are you sure you want to delete "${song.title}"? This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textSubtle),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: AppColors.textDanger),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      onDelete();
    }
  }
}
