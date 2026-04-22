import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_stroke.dart';
import '../../core/theme/app_typography.dart';

/// A single action in a [LycriActionMenu].
class LycriMenuAction {
  const LycriMenuAction({
    required this.label,
    required this.iconPath,
    required this.onTap,
    this.isDestructive = false,
  });

  final String label;
  final String iconPath;
  final VoidCallback onTap;
  final bool isDestructive;
}

/// A premium, overlay-based action menu for Lycri.
/// Matches the design seen in segment cards.
class LycriActionMenu extends StatefulWidget {
  const LycriActionMenu({
    super.key,
    required this.actions,
    required this.child,
  });

  final List<LycriMenuAction> actions;
  final Widget child;

  @override
  State<LycriActionMenu> createState() => LycriActionMenuState();
}

class LycriActionMenuState extends State<LycriActionMenu>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  void toggleMenu() {
    if (_isOpen) {
      _hideMenu();
    } else {
      _showMenu();
    }
  }

  void _showMenu() {
    _overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        // Measure the trigger's position to decide where to place the menu
        final RenderBox renderBox = context.findRenderObject() as RenderBox;
        final Offset offset = renderBox.localToGlobal(Offset.zero);
        final Size screenSize = MediaQuery.of(overlayContext).size;

        const double menuWidth = 200.0;
        // Estimate menu height based on number of actions + dividers + padding
        final double menuHeight =
            (widget.actions.length * 48.0) + (widget.actions.length - 1) + 32.0;
        const double gap = AppSpacing.sm;

        final double spaceBelow =
            screenSize.height - (offset.dy + renderBox.size.height + gap);
        final double spaceAbove = offset.dy - gap;

        final bool showAbove =
            spaceBelow < menuHeight && spaceAbove > spaceBelow;

        // Calculate horizontal offset (left-align by default)
        double dx = 0.0;
        final double globalLeft = offset.dx + dx;
        if (globalLeft + menuWidth > screenSize.width - AppSpacing.md) {
          dx = renderBox.size.width - menuWidth;
        }

        // Final clamp
        final double finalGlobalLeft = offset.dx + dx;
        if (finalGlobalLeft < AppSpacing.md) {
          dx = -offset.dx + AppSpacing.md;
        }

        return _LycriMenuOverlay(
          layerLink: _layerLink,
          actions: widget.actions,
          onDismiss: _hideMenu,
          dx: dx,
          showAbove: showAbove,
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  void _hideMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() => _isOpen = false);
    }
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap:
            () {}, // Swallows the tap to prevent propagation to parent widgets (like cards)
        behavior: HitTestBehavior.opaque,
        child: Listener(
          onPointerDown: (_) => toggleMenu(),
          behavior: HitTestBehavior.opaque,
          child: widget.child,
        ),
      ),
    );
  }
}

class _LycriMenuOverlay extends StatefulWidget {
  const _LycriMenuOverlay({
    required this.layerLink,
    required this.actions,
    required this.onDismiss,
    required this.dx,
    required this.showAbove,
  });

  final LayerLink layerLink;
  final List<LycriMenuAction> actions;
  final VoidCallback onDismiss;
  final double dx;
  final bool showAbove;

  @override
  State<_LycriMenuOverlay> createState() => _LycriMenuOverlayState();
}

class _LycriMenuOverlayState extends State<_LycriMenuOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

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

    _scaleAnim = Tween(begin: 0.85, end: 1.0).animate(curved);
    _fadeAnim = Tween(begin: 0.0, end: 1.0).animate(curved);

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Barrier
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
        // Menu Panel
        CompositedTransformFollower(
          link: widget.layerLink,
          showWhenUnlinked: false,
          targetAnchor:
              widget.showAbove ? Alignment.topLeft : Alignment.bottomLeft,
          followerAnchor:
              widget.showAbove ? Alignment.bottomLeft : Alignment.topLeft,
          offset: Offset(
            widget.dx,
            widget.showAbove ? -AppSpacing.sm : AppSpacing.sm,
          ),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              alignment:
                  widget.showAbove ? Alignment.bottomLeft : Alignment.topLeft,
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  width: 200,
                  decoration: BoxDecoration(
                    color: AppColors.surface4,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: AppColors.borderSubtle,
                      width: AppStroke.sm,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.md,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(widget.actions.length, (index) {
                        final action = widget.actions[index];
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _MenuActionTile(
                              action: action,
                              onTap: () {
                                action.onTap();
                                widget.onDismiss();
                              },
                            ),
                            if (index < widget.actions.length - 1)
                              Divider(
                                height: 1,
                                thickness: AppStroke.sm,
                                color: AppColors.borderMinimal,
                                indent: AppSpacing.md,
                                endIndent: AppSpacing.md,
                              ),
                          ],
                        );
                      }),
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

class _MenuActionTile extends StatefulWidget {
  const _MenuActionTile({required this.action, required this.onTap});

  final LycriMenuAction action;
  final VoidCallback onTap;

  @override
  State<_MenuActionTile> createState() => _MenuActionTileState();
}

class _MenuActionTileState extends State<_MenuActionTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          color: _isHovered ? AppColors.surface3 : AppColors.surface4,
          child: Row(
            children: [
              SvgPicture.asset(
                widget.action.iconPath,
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(
                  widget.action.isDestructive
                      ? AppColors.textDanger
                      : AppColors.iconSubtle,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  widget.action.label,
                  style: AppTypography.bodyLg.copyWith(
                    color:
                        widget.action.isDestructive
                            ? AppColors.textDanger
                            : AppColors.textBold,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
