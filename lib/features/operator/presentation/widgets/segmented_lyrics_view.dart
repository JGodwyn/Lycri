import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_stroke.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/providers/active_line_provider.dart';
import '../../../../shared/providers/lyrics_provider.dart';
import '../../models/lyrics_segment.dart';
import '../../../../shared/widgets/lycri_action_menu.dart';

class SegmentedLyricsView extends ConsumerStatefulWidget {
  const SegmentedLyricsView({super.key});

  @override
  ConsumerState<SegmentedLyricsView> createState() =>
      _SegmentedLyricsViewState();
}

class _SegmentedLyricsViewState extends ConsumerState<SegmentedLyricsView> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _itemKeys = {};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActive(SegmentedLyricsState state, int activeLineIndex) {
    int currentLine = 0;
    for (final segment in state.segments) {
      if (segment.isHidden) continue; // Skip hidden segments for scroll tracking

      final count = segment.lineCount;
      final start = currentLine;
      final end = currentLine + count - 1;

      if (activeLineIndex >= start && activeLineIndex <= end && count > 0) {
        final key = _itemKeys[segment.id];
        final context = key?.currentContext;
        if (context != null && context.mounted) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
            alignment: 0.5,
          );
        }
        break;
      }
      currentLine += count;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(segmentedLyricsProvider);

    // Synchronize scroll keys
    final activeIds = state.segments.map((s) => s.id).toSet();
    _itemKeys.removeWhere((id, _) => !activeIds.contains(id));
    for (final s in state.segments) {
      _itemKeys.putIfAbsent(s.id, () => GlobalKey());
    }

    // Trigger scroll when active line changes
    ref.listen(activeLineProvider, (prev, next) {
      _scrollToActive(state, next);
    });

    // Calculate line ranges for each segment to determine the active one.
    int currentLineOffset = 0;
    final List<({String id, int start, int end})> segmentRanges = [];
    for (final s in state.segments) {
      final count = s.lineCount;
      if (count > 0 && !s.isHidden) {
        segmentRanges.add((
          id: s.id,
          start: currentLineOffset,
          end: currentLineOffset + count - 1,
        ));
        currentLineOffset += count;
      } else {
        segmentRanges.add((id: s.id, start: -1, end: -1));
      }
    }

    return ReorderableListView.builder(
      scrollController: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      itemCount: state.segments.length,
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) {
        ref.read(segmentedLyricsProvider.notifier).reorder(oldIndex, newIndex);
      },
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final double animValue = animation.value;
            // 🎨 Slight tilt (approx 3 degrees) and custom premium shadow
            return Transform.rotate(
              angle: animValue * 0.052,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15 * animValue),
                        blurRadius: 24 * animValue,
                        spreadRadius:
                            -12 *
                            animValue, // 🪄 Pulls the shadow in from the sides
                        offset: Offset(
                          0,
                          16 * animValue,
                        ), // 🏗️ Increases vertical loft
                      ),
                    ],
                  ),
                  child: child,
                ),
              ),
            );
          },
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final segment = state.segments[index];
        final range = segmentRanges[index];
        final activeLineIndex = ref.watch(activeLineProvider);
        final isActive =
            !segment.isHidden &&
            activeLineIndex >= range.start &&
            activeLineIndex <= range.end &&
            range.start != -1;

        return _SegmentCard(
          key: ValueKey(segment.id),
          scrollKey: _itemKeys[segment.id]!,
          segment: segment,
          index: index,
          isActive: isActive,
          onTap: () {
            if (range.start != -1) {
              ref.read(activeLineProvider.notifier).jumpTo(range.start);
            }
          },
          onChanged: (val) {
            ref
                .read(segmentedLyricsProvider.notifier)
                .updateSegment(segment.id, val);
          },
        );
      },
    );
  }
}

class _SegmentCard extends ConsumerStatefulWidget {
  final LyricsSegment segment;
  final int index;
  final bool isActive;
  final VoidCallback onTap;
  final ValueChanged<String> onChanged;
  final GlobalKey scrollKey;

  const _SegmentCard({
    super.key,
    required this.segment,
    required this.index,
    required this.isActive,
    required this.onTap,
    required this.onChanged,
    required this.scrollKey,
  });

  @override
  ConsumerState<_SegmentCard> createState() => _SegmentCardState();
}

class _SegmentCardState extends ConsumerState<_SegmentCard> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.segment.text);
  }

  @override
  void didUpdateWidget(_SegmentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.segment.text != widget.segment.text && !_isEditing) {
      _controller.text = widget.segment.text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.segment.type;
    final isSpecial =
        type == LyricsSegmentType.chorus || type == LyricsSegmentType.bridge;
    final backgroundColor = isSpecial ? AppColors.orange50 : AppColors.orange0;
    final headerColor = AppColors.orange400;

    final typeLabel = switch (type) {
      LyricsSegmentType.intro => 'Intro',
      LyricsSegmentType.verse => 'Verse',
      LyricsSegmentType.preChorus => 'Pre-Chorus',
      LyricsSegmentType.chorus => 'Chorus',
      LyricsSegmentType.bridge => 'Bridge',
      LyricsSegmentType.outro => 'Outro',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.sm,
      ),
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: () {
          setState(() {
            _isEditing = true;
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: _controller.text.length),
            );
          });
          _focusNode.requestFocus();
        },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: widget.segment.isHidden ? 0.5 : 1.0,
          child: AnimatedContainer(
            key: widget.scrollKey,
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color:
                    widget.isActive ? AppColors.orange200 : Colors.transparent,
                width: AppStroke.lg,
              ),
            ),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Text(
                      '$typeLabel ${widget.segment.number}',
                      style: AppTypography.titleMd.copyWith(
                        color: headerColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xmd),
                    LycriActionMenu(
                      actions: [
                        LycriMenuAction(
                          label: 'Edit',
                          iconPath: 'assets/vectors/edit-pen.svg',
                          onTap: () {
                            setState(() => _isEditing = true);
                            _focusNode.requestFocus();
                          },
                        ),
                        LycriMenuAction(
                          label: widget.segment.isHidden ? 'Show' : 'Hide',
                          iconPath:
                              widget.segment.isHidden
                                  ? 'assets/vectors/eye.svg'
                                  : 'assets/vectors/eye-off.svg',
                          onTap: () {
                            ref
                                .read(segmentedLyricsProvider.notifier)
                                .toggleHideSegment(widget.segment.id);
                          },
                        ),
                        LycriMenuAction(
                          label: 'Set as chorus',
                          iconPath: 'assets/vectors/Starred-message.svg',
                          onTap: () {
                            // TODO: Implement Set as chorus
                            debugPrint('Set as chorus tapped');
                          },
                        ),
                        LycriMenuAction(
                          label: 'Remove chorus',
                          iconPath: 'assets/vectors/Message.svg',
                          onTap: () {
                            // TODO: Implement Remove chorus
                            debugPrint('Remove chorus tapped');
                          },
                        ),
                        LycriMenuAction(
                          label: 'Remove',
                          iconPath: 'assets/vectors/delete-trash-2.svg',
                          isDestructive: true,
                          onTap: () {
                            // TODO: Implement Remove
                            debugPrint('Remove tapped');
                          },
                        ),
                      ],
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: SvgPicture.asset(
                          'assets/vectors/more-horizontal.svg',
                          width: 20,
                          height: 20,
                          colorFilter: const ColorFilter.mode(
                            AppColors.iconSubtle,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    ReorderableDragStartListener(
                      index: widget.index,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.grab,
                        child: SvgPicture.asset(
                          'assets/vectors/drag-drop-horizontal.svg',
                          width: 20,
                          height: 20,
                          colorFilter: const ColorFilter.mode(
                            AppColors.iconSubtle,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // Content
                if (_isEditing)
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: null,
                    autofocus: true,
                    cursorColor: AppColors.orange400,
                    cursorWidth: 2.0,
                    style: AppTypography.bodyLg.copyWith(
                      color: AppColors.textBold,
                      height: 1.5,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      filled: false,
                    ),
                    onChanged: (val) => widget.onChanged(val),
                    onSubmitted: (_) => setState(() => _isEditing = false),
                    onTapOutside: (_) {
                      if (_isEditing) {
                        setState(() => _isEditing = false);
                        FocusScope.of(context).unfocus();
                      }
                    },
                  )
                else
                  Text(
                    widget.segment.text,
                    style: AppTypography.bodyLg.copyWith(
                      color: AppColors.textBold,
                      height: 1.5,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
