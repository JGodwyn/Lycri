import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_stroke.dart';
import '../../core/theme/app_typography.dart';

/// A single item in a [LycriDropdown].
class LycriDropdownItem<T> {
  const LycriDropdownItem({
    required this.value,
    required this.label,
    this.fontFamily,
  });

  /// The value returned when this item is selected.
  final T value;

  /// Display label for this item.
  final String label;

  /// Optional font family — when set, the label renders in this font.
  final String? fontFamily;
}

/// App-wide reusable dropdown for Lycri.
///
/// Features:
/// - Custom overlay dropdown panel (not the default [PopupMenuButton])
/// - Surface4 background, rounded corners, subtle border
/// - Dividers between items (borderMinimal)
/// - Orange checkmark on the selected item
/// - Scrollbar when content overflows the max height
/// - Chevron rotates when open
///
/// ```dart
/// LycriDropdown<String>(
///   items: fonts.map((f) => LycriDropdownItem(value: f, label: f, fontFamily: f)).toList(),
///   selectedValue: _selected,
///   onChanged: (v) => setState(() => _selected = v),
///   leadingIcon: Icons.text_format,
/// )
/// ```
class LycriDropdown<T> extends StatefulWidget {
  const LycriDropdown({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onChanged,
    this.leadingIcon,
    this.maxDropdownHeight = 300,
  });

  /// Available options.
  final List<LycriDropdownItem<T>> items;

  /// Currently selected value.
  final T selectedValue;

  /// Called when a new item is picked.
  final ValueChanged<T> onChanged;

  /// Optional leading icon shown in the trigger button.
  final IconData? leadingIcon;

  /// Maximum height of the dropdown panel before it scrolls.
  final double maxDropdownHeight;

  @override
  State<LycriDropdown<T>> createState() => _LycriDropdownState<T>();
}

class _LycriDropdownState<T> extends State<LycriDropdown<T>>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _triggerKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  late final AnimationController _chevronController;
  late final Animation<double> _chevronTurns;

  @override
  void initState() {
    super.initState();
    _chevronController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _chevronTurns = Tween(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _chevronController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    _chevronController.dispose();
    super.dispose();
  }

  // ── Overlay management ──────────────────────────────────────────────────

  void _toggleDropdown() {
    if (_isOpen) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    final renderBox =
        _triggerKey.currentContext!.findRenderObject() as RenderBox;
    final triggerWidth = renderBox.size.width;

    _overlayEntry = OverlayEntry(
      builder:
          (_) => _DropdownOverlay<T>(
            items: widget.items,
            selectedValue: widget.selectedValue,
            triggerWidth: triggerWidth,
            maxHeight: widget.maxDropdownHeight,
            layerLink: _layerLink,
            onSelected: (value) {
              widget.onChanged(value);
              _removeOverlay();
            },
            onDismiss: _removeOverlay,
          ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _chevronController.forward();
    setState(() => _isOpen = true);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (_isOpen) {
      _chevronController.reverse();
      setState(() => _isOpen = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  /// Resolves the display label for the current selection.
  String get _selectedLabel {
    final match = widget.items.where((i) => i.value == widget.selectedValue);
    return match.isNotEmpty ? match.first.label : '';
  }

  String? get _selectedFontFamily {
    final match = widget.items.where((i) => i.value == widget.selectedValue);
    return match.isNotEmpty ? match.first.fontFamily : null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _toggleDropdown,
          child: Container(
            key: _triggerKey,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface3,
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(
                color: AppColors.borderSubtle,
                width: AppStroke.md,
              ),
            ),
            child: Row(
              children: [
                if (widget.leadingIcon != null) ...[
                  Icon(
                    widget.leadingIcon,
                    size: 24,
                    color: AppColors.iconSubtle,
                  ),
                  const SizedBox(width: AppSpacing.xmd),
                ],
                Expanded(
                  child: Text(
                    _selectedLabel,
                    style: AppTypography.bodyMd.copyWith(
                      fontFamily: _selectedFontFamily,
                      color: AppColors.textBold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                RotationTransition(
                  turns: _chevronTurns,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: AppColors.iconSubtle,
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

// ─── Overlay panel ──────────────────────────────────────────────────────────

/// The floating panel rendered inside the [Overlay].
///
/// Entrance animation: a fast scale-up (0.95 → 1.0) + fade-in (0 → 1),
/// anchored at top-center so it appears to grow from the trigger button.
class _DropdownOverlay<T> extends StatefulWidget {
  const _DropdownOverlay({
    required this.items,
    required this.selectedValue,
    required this.triggerWidth,
    required this.maxHeight,
    required this.layerLink,
    required this.onSelected,
    required this.onDismiss,
  });

  final List<LycriDropdownItem<T>> items;
  final T selectedValue;
  final double triggerWidth;
  final double maxHeight;
  final LayerLink layerLink;
  final ValueChanged<T> onSelected;
  final VoidCallback onDismiss;

  @override
  State<_DropdownOverlay<T>> createState() => _DropdownOverlayState<T>();
}

class _DropdownOverlayState<T> extends State<_DropdownOverlay<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;
  late final ScrollController _scrollController;

  // Exact height per item (item height 48px + divider 1px).
  static const _exactItemHeight = 49.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    final curved = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    _scaleAnim = Tween(begin: 0.75, end: 1.0).animate(curved);
    _fadeAnim = Tween(begin: 0.0, end: 1.0).animate(curved);

    // ScrollController — center the selected item in the visible area.
    final selectedIndex = widget.items.indexWhere(
      (i) => i.value == widget.selectedValue,
    );
    final rawOffset =
        selectedIndex > 0 ? selectedIndex * _exactItemHeight : 0.0;
    // Shift up by half the dropdown height so the item sits in the middle.
    // initialScrollOffset is automatically bound to maxScrollExtent by Flutter during layout.
    final centeredOffset = (rawOffset -
            widget.maxHeight / 2 +
            _exactItemHeight / 2)
        .clamp(0.0, double.infinity);
    _scrollController = ScrollController(initialScrollOffset: centeredOffset);

    // Start the entrance animation immediately.
    _animController.forward();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Tap-away barrier to dismiss
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onDismiss,
            child: const SizedBox.expand(),
          ),
        ),

        // Dropdown panel
        CompositedTransformFollower(
          link: widget.layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 52),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              alignment: Alignment.topCenter,
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  width: widget.triggerWidth,
                  constraints: BoxConstraints(maxHeight: widget.maxHeight),
                  decoration: BoxDecoration(
                    color: AppColors.surface4,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: AppColors.borderSubtle,
                      width: AppStroke.md,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      radius: const Radius.circular(AppRadius.full),
                      child: ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        shrinkWrap: true,
                        itemCount: widget.items.length,
                        separatorBuilder:
                            (_, __) => Divider(
                              height: 1,
                              thickness: AppStroke.sm,
                              color: AppColors.borderMinimal,
                              indent: AppSpacing.lg,
                              endIndent: AppSpacing.lg,
                            ),
                        itemBuilder: (_, index) {
                          final item = widget.items[index];
                          final isSelected = item.value == widget.selectedValue;

                          return _DropdownMenuItem(
                            label: item.label,
                            fontFamily: item.fontFamily,
                            isSelected: isSelected,
                            onTap: () => widget.onSelected(item.value),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Individual menu item ───────────────────────────────────────────────────

class _DropdownMenuItem extends StatefulWidget {
  const _DropdownMenuItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.fontFamily,
  });

  final String label;
  final String? fontFamily;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_DropdownMenuItem> createState() => _DropdownMenuItemState();
}

class _DropdownMenuItemState extends State<_DropdownMenuItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 48.0,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          color: _hovered ? AppColors.surface3 : AppColors.surface4,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: AppTypography.bodyMd.copyWith(
                    fontFamily: widget.fontFamily,
                    color: AppColors.textBold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.isSelected)
                Icon(Icons.check, size: 18, color: AppColors.iconBrand),
            ],
          ),
        ),
      ),
    );
  }
}
