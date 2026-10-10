import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'cassette_press.dart';
import 'fade_text.dart';
import 'inner_shadow.dart';

/// Colour treatment for a [LycriPillGroup].
enum LycriPillTone {
  /// `surface-3` fill with subtle icons — used on white panels.
  light,

  /// `Gray600` fill with inverse icons — used on inverse (black) bars.
  dark,

  /// `Gray500` fill with inverse icons — used on `Gray600` bars.
  muted,
}

/// One button inside a [LycriPillGroup].
class LycriPillSegment {
  const LycriPillSegment({
    this.svgAsset,
    this.label,
    this.trailingSvgAsset,
    this.onTap,
    this.enabled = true,
    this.tooltip,
    this.width,
    this.labelMaxWidth = 160,
  }) : assert(svgAsset != null || label != null);

  /// Leading icon (24×24).
  final String? svgAsset;

  /// Optional label, rendered in `title-lg` uppercase.
  final String? label;

  /// Optional trailing icon (24×24), e.g. `unfold-more`.
  final String? trailingSvgAsset;

  final VoidCallback? onTap;
  final bool enabled;
  final String? tooltip;

  /// Fixed width; icon-only segments default to 48.
  final double? width;

  /// Labels wider than this fade out rather than grow the pill.
  final double labelMaxWidth;
}

/// A row of joined pill buttons (Figma: segmented "Button" frames).
///
/// Segments sit 2px apart (`dist-xs`); only the outer ends are rounded, so the
/// group reads as one pill. Each segment has the design's bottom inner shadow
/// and depresses like a cassette key when tapped ([CassettePress]).
class LycriPillGroup extends StatelessWidget {
  const LycriPillGroup({
    super.key,
    required this.segments,
    this.tone = LycriPillTone.light,
    this.height = 40,
    this.iconSize = 24,
  });

  final List<LycriPillSegment> segments;
  final LycriPillTone tone;
  final double height;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < segments.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.xs),
          _PillSegmentButton(
            segment: segments[i],
            tone: tone,
            height: height,
            iconSize: iconSize,
            borderRadius: BorderRadius.horizontal(
              left: Radius.circular(i == 0 ? AppRadius.full : AppRadius.none),
              right: Radius.circular(
                i == segments.length - 1 ? AppRadius.full : AppRadius.none,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PillSegmentButton extends StatefulWidget {
  const _PillSegmentButton({
    required this.segment,
    required this.tone,
    required this.height,
    required this.iconSize,
    required this.borderRadius,
  });

  final LycriPillSegment segment;
  final LycriPillTone tone;
  final double height;
  final double iconSize;
  final BorderRadius borderRadius;

  @override
  State<_PillSegmentButton> createState() => _PillSegmentButtonState();
}

class _PillSegmentButtonState extends State<_PillSegmentButton> {
  bool get _enabled => widget.segment.enabled && widget.segment.onTap != null;

  /// Resting colour, darkening towards the pressed colour as the key sinks
  /// ([t] 0 → 1). No hover state: feedback is the press itself.
  Color _background(double t) {
    final (rest, pressed) = switch (widget.tone) {
      LycriPillTone.light => (AppColors.surface3, AppColors.surface1),
      LycriPillTone.dark => (AppColors.gray600, AppColors.gray800),
      LycriPillTone.muted => (AppColors.gray500, AppColors.gray700),
    };
    return Color.lerp(rest, pressed, t.clamp(0.0, 1.0))!;
  }

  Color get _foreground {
    if (!_enabled) {
      return switch (widget.tone) {
        LycriPillTone.light || LycriPillTone.muted => AppColors.iconMinimal,
        LycriPillTone.dark => AppColors.iconSubtle,
      };
    }
    return widget.tone == LycriPillTone.light
        ? AppColors.iconSubtle
        : AppColors.iconInverse;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.segment;
    final iconOnly = s.label == null && s.trailingSvgAsset == null;
    final fg = _foreground;

    Widget icon(String asset) => SvgPicture.asset(
      asset,
      width: widget.iconSize,
      height: widget.iconSize,
      colorFilter: ColorFilter.mode(fg, BlendMode.srcIn),
    );

    Widget button = MouseRegion(
      cursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: CassettePress(
        enabled: _enabled,
        onTap: s.onTap,
        builder:
            (context, t) => InnerShadow(
              color: Colors.black.withValues(
                alpha: CassettePress.shadowAlpha(0.15, t),
              ),
              offset: CassettePress.shadowOffset(t),
              borderRadius: widget.borderRadius,
              // Plain Container: colour follows the press animation frame by frame.
              child: Container(
                height: widget.height,
                width: s.width ?? (iconOnly ? 48 : null),
                padding:
                    iconOnly
                        ? EdgeInsets.zero
                        : const EdgeInsets.symmetric(horizontal: AppPadding.md),
                decoration: BoxDecoration(
                  color: _background(t),
                  borderRadius: widget.borderRadius,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (s.svgAsset != null) icon(s.svgAsset!),
                    if (s.svgAsset != null && s.label != null)
                      const SizedBox(width: AppSpacing.md),
                    if (s.label != null)
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: s.labelMaxWidth),
                        child: FadeText(
                          s.label!.toUpperCase(),
                          style: AppTypography.titleLg.copyWith(
                            color:
                                _enabled
                                    ? (widget.tone == LycriPillTone.light
                                        ? AppColors.textSubtle
                                        : AppColors.textInverse)
                                    : fg,
                          ),
                        ),
                      ),
                    if (s.trailingSvgAsset != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      icon(s.trailingSvgAsset!),
                    ],
                  ],
                ),
              ),
            ),
      ),
    );

    if (s.tooltip != null) {
      button = Tooltip(message: s.tooltip!, child: button);
    }
    return button;
  }
}
