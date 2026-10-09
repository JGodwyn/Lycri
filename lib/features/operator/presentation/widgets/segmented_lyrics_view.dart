import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
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
import '../../../../shared/widgets/scroll_fade_mask.dart';
import '../../../../shared/widgets/lycri_action_menu.dart';
import '../../../../shared/widgets/fade_text.dart';
import '../../../../shared/utils/caps_text_controller.dart';

class SegmentedLyricsView extends ConsumerStatefulWidget {
  const SegmentedLyricsView({super.key});

  @override
  ConsumerState<SegmentedLyricsView> createState() =>
      _SegmentedLyricsViewState();
}

class _SegmentedLyricsViewState extends ConsumerState<SegmentedLyricsView> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _itemKeys = {};
  final GlobalKey _stackKey = GlobalKey();

  /// How close (px) the pointer must be to a card's top/bottom edge for the
  /// insert button to show.
  static const double _insertHoverZone = 20;

  /// Gap the insert button targets: 0 = before the first card,
  /// n = after the last. Null when hidden.
  int? _insertGap;
  Offset _insertAnchor = Offset.zero;

  /// Newly inserted segment that should open straight into edit mode.
  String? _pendingEditId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_hideInsertButton);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _hideInsertButton() {
    if (_insertGap != null) setState(() => _insertGap = null);
  }

  /// Finds the card edge nearest the pointer and anchors the insert button
  /// in the gap on that side.
  void _updateInsertHover(Offset local, List<LyricsSegment> segments) {
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return;

    int? gap;
    Offset anchor = Offset.zero;
    double best = _insertHoverZone;
    for (int i = 0; i < segments.length; i++) {
      final box =
          _itemKeys[segments[i].id]?.currentContext?.findRenderObject()
              as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) continue;
      final rect =
          box.localToGlobal(Offset.zero, ancestor: stackBox) & box.size;
      if (local.dx < rect.left || local.dx > rect.right) continue;

      // Anchor on the centre of the gap between cards (dist-md split
      // above/below each card).
      final topDist = (local.dy - rect.top).abs();
      if (topDist < best) {
        best = topDist;
        gap = i;
        anchor = Offset(rect.center.dx, rect.top - AppSpacing.sm);
      }
      final bottomDist = (local.dy - rect.bottom).abs();
      if (bottomDist < best) {
        best = bottomDist;
        gap = i + 1;
        anchor = Offset(rect.center.dx, rect.bottom + AppSpacing.sm);
      }
    }

    // Keep the button inside the list at the first/last gap.
    const half = _AddSegmentButton.size / 2;
    if (stackBox.size.height > _AddSegmentButton.size) {
      anchor = Offset(
        anchor.dx,
        anchor.dy.clamp(half, stackBox.size.height - half),
      );
    }

    if (gap != _insertGap || (gap != null && anchor != _insertAnchor)) {
      setState(() {
        _insertGap = gap;
        if (gap != null) _insertAnchor = anchor;
      });
    }
  }

  void _insertSegmentAt(int gap) {
    final id = ref.read(segmentedLyricsProvider.notifier).insertSegment(gap);
    setState(() {
      _pendingEditId = id;
      _insertGap = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _pendingEditId = null);
  }

  void _scrollToActive(SegmentedLyricsState state, int activeLineIndex) {
    int currentLine = 0;
    for (final segment in state.segments) {
      // Skip hidden segments for scroll tracking
      if (segment.isHidden) continue;

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

    // No scrollbar: the edge fade signals there's more to scroll.
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ScrollFadeMask(
        child: MouseRegion(
          onHover: (e) => _updateInsertHover(e.localPosition, state.segments),
          onExit: (_) => _hideInsertButton(),
          child: Stack(
            key: _stackKey,
            children: [
              _buildList(state, segmentRanges),
              Positioned(
                left: _insertAnchor.dx - _AddSegmentButton.size / 2,
                top: _insertAnchor.dy - _AddSegmentButton.size / 2,
                child: _AddSegmentButton(
                  gap: _insertGap,
                  onTap: () {
                    final gap = _insertGap;
                    if (gap != null) _insertSegmentAt(gap);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(
    SegmentedLyricsState state,
    List<({String id, int start, int end})> segmentRanges,
  ) {
    return ReorderableListView.builder(
      scrollController: _scrollController,
      padding: EdgeInsets.zero,
      itemCount: state.segments.length,
      buildDefaultDragHandles: false,
      onReorderStart: (_) => _hideInsertButton(),
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

        // Calculate dynamic numbering (instance count of this type up to this index)
        int displayNumber = 0;
        for (int j = 0; j <= index; j++) {
          if (state.segments[j].type == segment.type) {
            displayNumber++;
          }
        }

        return Container(
          key: ValueKey(segment.id),
          child: _SegmentCard(
            segment: segment,
            index: index,
            displayNumber: displayNumber,
            isActive: isActive,
            isNew: segment.id == _pendingEditId,
            scrollKey: _itemKeys[segment.id],
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
            onRemove: () {
              ref
                  .read(segmentedLyricsProvider.notifier)
                  .removeSegment(segment.id);
            },
          ),
        );
      },
    );
  }
}

class _SegmentCard extends ConsumerStatefulWidget {
  final LyricsSegment segment;
  final int index;
  final int displayNumber;
  final bool isActive;

  /// Just inserted: animates in and opens in edit mode.
  final bool isNew;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final ValueChanged<String> onChanged;
  final GlobalKey? scrollKey;

  const _SegmentCard({
    required this.segment,
    required this.index,
    required this.displayNumber,
    required this.isActive,
    this.isNew = false,
    required this.onTap,
    required this.onRemove,
    required this.onChanged,
    this.scrollKey,
  });

  @override
  ConsumerState<_SegmentCard> createState() => _SegmentCardState();
}

class _SegmentCardState extends ConsumerState<_SegmentCard>
    with TickerProviderStateMixin {
  late TextEditingController _controller;
  final CapsTextEditingController _nameController = CapsTextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  bool _isRenaming = false;

  /// Body text and name, used to map a double-click to a caret position.
  final GlobalKey _bodyTextKey = GlobalKey();
  final GlobalKey _nameKey = GlobalKey();
  Offset? _doubleTapPosition;
  final FocusNode _focusNode = FocusNode();
  bool _isEditing = false;
  late AnimationController _exitController;
  late Animation<double> _exitAnimation;
  bool _isRemoving = false;
  final GlobalKey<LycriActionMenuState> _menuKey = GlobalKey();

  /// Taps on this card or its menu don't end editing — only taps elsewhere.
  final Object _tapGroup = Object();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.segment.text);
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _exitAnimation = CurvedAnimation(
      parent: _exitController,
      curve: Curves.easeInOutCubic,
    );
    if (widget.isNew) {
      // Play the exit animation backwards as the entrance.
      _isEditing = true;
      _exitController.value = 1;
      _exitController.addListener(_keepEntranceVisible);
      _exitController.reverse().whenComplete(
        () => _exitController.removeListener(_keepEntranceVisible),
      );
    }
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
    _nameController.dispose();
    _nameFocusNode.dispose();
    _exitController.dispose();
    super.dispose();
  }

  void _handleRemoveRequested() {
    if (_isRemoving) return;
    setState(() => _isRemoving = true);
    _exitController.forward().then((_) {
      widget.onRemove();
    });
  }

  /// While a new card grows in, scroll just enough to keep its bottom on
  /// screen (e.g. adding after the last verse). No-op if already visible.
  void _keepEntranceVisible() {
    if (!mounted) return;
    Scrollable.ensureVisible(
      context,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
  }

  void _startRenaming(String currentName) {
    _nameController.value = TextEditingValue(
      text: currentName,
      selection: TextSelection(baseOffset: 0, extentOffset: currentName.length),
    );
    setState(() => _isRenaming = true);
    _nameFocusNode.requestFocus();
  }

  /// Saves the name; blank restores the default.
  void _finishRenaming({bool cancel = false}) {
    if (!_isRenaming) return;
    if (!cancel) {
      ref
          .read(segmentedLyricsProvider.notifier)
          .renameSegment(widget.segment.id, _nameController.text);
    }
    setState(() => _isRenaming = false);
  }

  /// Double-click on the name renames; elsewhere edits the lyrics with the
  /// caret where the click landed (end of text if not over the text).
  void _handleDoubleTap(String currentName) {
    final position = _doubleTapPosition;
    if (position != null && _hits(_nameKey, position)) {
      _startRenaming(currentName);
      return;
    }

    int offset = _controller.text.length;
    final paragraph = _bodyTextKey.currentContext?.findRenderObject();
    if (position != null && paragraph is RenderParagraph) {
      offset = paragraph
          .getPositionForOffset(paragraph.globalToLocal(position))
          .offset
          .clamp(0, _controller.text.length);
    }
    setState(() {
      _isEditing = true;
      _controller.selection = TextSelection.collapsed(offset: offset);
    });
    _focusNode.requestFocus();
  }

  bool _hits(GlobalKey key, Offset globalPosition) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return false;
    return (Offset.zero & box.size).contains(box.globalToLocal(globalPosition));
  }

  /// Leaves edit mode; a segment left empty is removed.
  void _finishEditing() {
    if (!_isEditing) return;
    setState(() => _isEditing = false);
    if (_controller.text.trim().isEmpty) _handleRemoveRequested();
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.segment.type;
    final isSpecial =
        type == LyricsSegmentType.chorus || type == LyricsSegmentType.bridge;
    final backgroundColor = isSpecial ? AppColors.orange50 : AppColors.orange0;
    final headerColor = AppColors.orange500;

    final typeLabel = switch (type) {
      LyricsSegmentType.intro => 'Intro',
      LyricsSegmentType.verse => 'Verse',
      LyricsSegmentType.preChorus => 'Pre-Chorus',
      LyricsSegmentType.chorus => 'Chorus',
      LyricsSegmentType.bridge => 'Bridge',
      LyricsSegmentType.outro => 'Outro',
    };

    final name = widget.segment.label ?? '$typeLabel ${widget.displayNumber}';

    final List<LycriMenuAction> actions = [
      LycriMenuAction(
        label: 'Rename',
        iconPath: 'assets/vectors/format-letter-spacing.svg',
        onTap: () => _startRenaming(name),
      ),
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
        label:
            widget.segment.type == LyricsSegmentType.chorus
                ? 'Remove chorus'
                : 'Set as chorus',
        iconPath:
            widget.segment.type == LyricsSegmentType.chorus
                ? 'assets/vectors/Message.svg'
                : 'assets/vectors/Starred-message.svg',
        onTap: () {
          ref
              .read(segmentedLyricsProvider.notifier)
              .toggleChorus(widget.segment.id);
        },
      ),
      LycriMenuAction(
        label: 'Remove',
        iconPath: 'assets/vectors/delete-trash-2.svg',
        isDestructive: true,
        onTap: _handleRemoveRequested,
      ),
    ];

    return SizeTransition(
      sizeFactor: Tween<double>(begin: 1.0, end: 0.0).animate(_exitAnimation),
      child: FadeTransition(
        opacity: Tween<double>(begin: 1.0, end: 0.0).animate(_exitAnimation),
        child: AnimatedBuilder(
          animation: _exitAnimation,
          builder: (context, child) {
            final blur = _exitAnimation.value * 10.0;
            return ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: child,
            );
          },
          child: Padding(
            // dist-md (8) between cards, split above/below each one.
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: GestureDetector(
              onTap: widget.onTap,
              onSecondaryTap: () => _menuKey.currentState?.toggleMenu(),
              // Off while a field is open so its own double-click (word
              // selection) isn't overridden.
              onDoubleTapDown:
                  _isEditing || _isRenaming
                      ? null
                      : (d) => _doubleTapPosition = d.globalPosition,
              onDoubleTap:
                  _isEditing || _isRenaming
                      ? null
                      : () => _handleDoubleTap(name),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: widget.segment.isHidden ? 0.5 : 1.0,
                child: TapRegion(
                  groupId: _tapGroup,
                  child: AnimatedContainer(
                    key: widget.scrollKey,
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color:
                            widget.isActive
                                ? AppColors.orange200
                                : Colors.transparent,
                        width: AppStroke.lg,
                      ),
                    ),
                    padding: const EdgeInsets.all(AppPadding.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: name + menu take the free width so the
                        // dragger stays pinned right.
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  if (_isRenaming)
                                    Flexible(
                                      child: IntrinsicWidth(
                                        child: Focus(
                                          onKeyEvent: (_, event) {
                                            if (event is KeyDownEvent &&
                                                event.logicalKey ==
                                                    LogicalKeyboardKey.escape) {
                                              _finishRenaming(cancel: true);
                                              return KeyEventResult.handled;
                                            }
                                            return KeyEventResult.ignored;
                                          },
                                          child: TextField(
                                            controller: _nameController,
                                            focusNode: _nameFocusNode,
                                            autofocus: true,
                                            maxLines: 1,
                                            cursorColor: AppColors.textBrand,
                                            cursorWidth: 2.0,
                                            style: AppTypography.titleMd
                                                .copyWith(color: headerColor),
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              enabledBorder: InputBorder.none,
                                              focusedBorder: InputBorder.none,
                                              isDense: true,
                                              contentPadding: EdgeInsets.zero,
                                              filled: false,
                                            ),
                                            onSubmitted:
                                                (_) => _finishRenaming(),
                                            onTapOutside: (_) {
                                              _finishRenaming();
                                              _nameFocusNode.unfocus();
                                            },
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    Flexible(
                                      child: KeyedSubtree(
                                        key: _nameKey,
                                        child: FadeText(
                                          name.toUpperCase(),
                                          style: AppTypography.titleMd.copyWith(
                                            color: headerColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: AppSpacing.md),
                                  LycriActionMenu(
                                    key: _menuKey,
                                    actions: actions,
                                    tapRegionGroupId: _tapGroup,
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
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
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
                        const SizedBox(height: AppSpacing.sm),
                        // Content
                        if (_isEditing)
                          TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            groupId: _tapGroup,
                            maxLines: null,
                            autofocus: true,
                            cursorColor: AppColors.textBrand,
                            cursorWidth: 2.0,
                            style: AppTypography.bodyLg.copyWith(
                              color: AppColors.textBold,
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
                            onSubmitted: (_) => _finishEditing(),
                            onTapOutside: (_) {
                              if (_isEditing) {
                                _finishEditing();
                                FocusScope.of(context).unfocus();
                              }
                            },
                          )
                        else
                          Text(
                            widget.segment.text,
                            key: _bodyTextKey,
                            style: AppTypography.bodyLg.copyWith(
                              color: AppColors.textBold,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Orange circular "+" that rises into the gap between two cards.
class _AddSegmentButton extends StatefulWidget {
  static const double size = 24;

  /// Target gap; null hides the button. A new gap replays the entrance.
  final int? gap;
  final VoidCallback onTap;

  const _AddSegmentButton({required this.gap, required this.onTap});

  @override
  State<_AddSegmentButton> createState() => _AddSegmentButtonState();
}

class _AddSegmentButtonState extends State<_AddSegmentButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    reverseDuration: const Duration(milliseconds: 140),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeIn,
  );
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    if (widget.gap != null) _controller.forward();
  }

  @override
  void didUpdateWidget(_AddSegmentButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.gap == oldWidget.gap) return;
    if (widget.gap == null) {
      _controller.reverse();
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) {
        final t = _curve.value;
        if (_controller.isDismissed) return const SizedBox.shrink();
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            // Rises up into place.
            offset: Offset(0, (1 - t) * 10),
            child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
          ),
        );
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: _AddSegmentButton.size,
            height: _AddSegmentButton.size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  _hovered
                      ? AppColors.btnBrandPrimaryHover
                      : AppColors.btnBrandPrimaryRest,
            ),
            child: SvgPicture.asset(
              'assets/vectors/plus.svg',
              width: 16,
              height: 16,
              colorFilter: const ColorFilter.mode(
                AppColors.iconInverse,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
