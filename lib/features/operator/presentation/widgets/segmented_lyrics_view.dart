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

class SegmentedLyricsView extends ConsumerWidget {
  const SegmentedLyricsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(segmentedLyricsProvider);
    final activeLineIndex = ref.watch(activeLineProvider);

    // Calculate line ranges for each segment to determine the active one.
    int currentLineOffset = 0;
    final List<({String id, int start, int end})> segmentRanges = [];
    for (final s in state.segments) {
      final count = s.lineCount;
      if (count > 0) {
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
                        color: Colors.black.withValues(alpha: 0.12 * animValue),
                        blurRadius: 16 * animValue,
                        spreadRadius: 2 * animValue,
                        offset: Offset(0, 4 * animValue),
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
        final isActive =
            activeLineIndex >= range.start &&
            activeLineIndex <= range.end &&
            range.start != -1;

        return _SegmentCard(
          key: ValueKey(segment.id),
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

class _SegmentCard extends StatefulWidget {
  final LyricsSegment segment;
  final int index;
  final bool isActive;
  final VoidCallback onTap;
  final ValueChanged<String> onChanged;

  const _SegmentCard({
    super.key,
    required this.segment,
    required this.index,
    required this.isActive,
    required this.onTap,
    required this.onChanged,
  });

  @override
  State<_SegmentCard> createState() => _SegmentCardState();
}

class _SegmentCardState extends State<_SegmentCard> {
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
    final isChorus = widget.segment.type == LyricsSegmentType.chorus;
    final backgroundColor = isChorus ? AppColors.orange50 : AppColors.orange0;
    final headerColor = AppColors.orange400;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: widget.isActive ? AppColors.orange200 : Colors.transparent,
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
                    '${isChorus ? 'Chorus' : 'Verse'} ${widget.segment.number}',
                    style: AppTypography.titleMd.copyWith(
                      color: headerColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xmd),
                  SvgPicture.asset(
                    'assets/vectors/more-horizontal.svg',
                    width: 20,
                    height: 20,
                    colorFilter: const ColorFilter.mode(
                      AppColors.iconSubtle,
                      BlendMode.srcIn,
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
    );
  }
}
