import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_stroke.dart';
import '../../core/theme/app_typography.dart';

/// A color field that displays the current color and opens a custom color
/// picker popup when tapped. This serves as a drop-in replacement for the
/// previous font color control in the EditorPanel.
class LycriColorField extends StatefulWidget {
  final Color color;
  final ValueChanged<Color> onColorChanged;

  const LycriColorField({
    super.key,
    required this.color,
    required this.onColorChanged,
  });

  @override
  State<LycriColorField> createState() => _LycriColorFieldState();
}

class _LycriColorFieldState extends State<LycriColorField> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  void _toggleOverlay() {
    if (_overlayEntry != null) {
      _closeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Full screen dismiss barrier
            GestureDetector(
              onTap: _closeOverlay,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
            // Popup anchoring
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              // Align the right edge of the popup with the right edge of the field
              offset: Offset(size.width - 260, size.height + AppSpacing.sm),
              child: Material(
                color: Colors.transparent,
                child: _LycriColorPickerPopup(
                  initialColor: widget.color,
                  onColorChanged: widget.onColorChanged,
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _closeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _closeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hex =
        '#${widget.color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _toggleOverlay,
          child: Container(
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
                // Swatch
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: AppColors.borderSubtle,
                      width: AppStroke.sm,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Hex text
                Expanded(
                  child: Text(
                    hex,
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.textBold,
                    ),
                  ),
                ),
                // Icon
                const Icon(
                  Icons.palette,
                  size: 18,
                  color: AppColors.iconSubtle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LycriColorPickerPopup extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorChanged;

  const _LycriColorPickerPopup({
    required this.initialColor,
    required this.onColorChanged,
  });

  @override
  State<_LycriColorPickerPopup> createState() => _LycriColorPickerPopupState();
}

class _LycriColorPickerPopupState extends State<_LycriColorPickerPopup> {
  late HSVColor hsvColor;

  @override
  void initState() {
    super.initState();
    hsvColor = HSVColor.fromColor(widget.initialColor);
  }

  void _handleColorChanged(HSVColor newHsv) {
    setState(() {
      hsvColor = newHsv;
    });
    widget.onColorChanged(newHsv.toColor());
  }

  @override
  Widget build(BuildContext context) {
    final hex =
        '#${hsvColor.toColor().toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

    return Container(
      width: 260,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface4,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.borderSubtle, width: AppStroke.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // HSV Area
          SizedBox(
            height: 150,
            width: double.infinity,
            child: _SVArea(
              hsvColor: hsvColor,
              onColorChanged: _handleColorChanged,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Hue Slider
          SizedBox(
            height: 24,
            width: double.infinity,
            child: _HueSlider(
              hsvColor: hsvColor,
              onColorChanged: _handleColorChanged,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Hex & Swatch Output
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface3,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hex,
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.textBold,
                    ),
                  ),
                ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: hsvColor.toColor(),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.borderSubtle,
                      width: AppStroke.sm,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SVArea extends StatelessWidget {
  final HSVColor hsvColor;
  final ValueChanged<HSVColor> onColorChanged;

  const _SVArea({required this.hsvColor, required this.onColorChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        void handlePan(Offset localPosition) {
          final x = localPosition.dx.clamp(0.0, width);
          final y = localPosition.dy.clamp(0.0, height);

          final s = x / width;
          final v = 1.0 - (y / height); // 1 = top, 0 = bottom

          onColorChanged(hsvColor.withSaturation(s).withValue(v));
        }

        final thumbX = hsvColor.saturation * width;
        final thumbY = (1.0 - hsvColor.value) * height;

        return GestureDetector(
          onPanDown: (details) => handlePan(details.localPosition),
          onPanUpdate: (details) => handlePan(details.localPosition),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Gradients clipped nicely
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Stack(
                  children: [
                    // Hue Color Layer
                    Container(
                      color:
                          HSVColor.fromAHSV(
                            1.0,
                            hsvColor.hue,
                            1.0,
                            1.0,
                          ).toColor(),
                    ),
                    // Saturation Gradient (White to Transparent)
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.white, Colors.transparent],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                    // Value Gradient (Transparent to Black)
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Colors.black],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Thumb
              Positioned(
                left: thumbX - 12,
                top: thumbY - 12,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: hsvColor.toColor(),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HueSlider extends StatelessWidget {
  final HSVColor hsvColor;
  final ValueChanged<HSVColor> onColorChanged;

  const _HueSlider({required this.hsvColor, required this.onColorChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        void handlePan(Offset localPosition) {
          final x = localPosition.dx.clamp(0.0, width);
          final h = (x / width) * 360.0;
          onColorChanged(hsvColor.withHue(h.clamp(0.0, 359.9)));
        }

        final thumbX = (hsvColor.hue / 360.0) * width;

        return GestureDetector(
          onPanDown: (details) => handlePan(details.localPosition),
          onPanUpdate: (details) => handlePan(details.localPosition),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              // Track
              Center(
                child: Container(
                  height: 12,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFF0000), // 0 Red
                        Color(0xFFFFFF00), // 60 Yellow
                        Color(0xFF00FF00), // 120 Green
                        Color(0xFF00FFFF), // 180 Cyan
                        Color(0xFF0000FF), // 240 Blue
                        Color(0xFFFF00FF), // 300 Magenta
                        Color(0xFFFF0000), // 360 Red
                      ],
                      stops: [0.0, 0.166, 0.333, 0.5, 0.666, 0.833, 1.0],
                    ),
                    border: Border.all(
                      color: AppColors.borderSubtle,
                      width: AppStroke.sm,
                    ),
                  ),
                ),
              ),
              // Thumb
              Positioned(
                left: thumbX - 12,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color:
                        HSVColor.fromAHSV(
                          1.0,
                          hsvColor.hue,
                          1.0,
                          1.0,
                        ).toColor(),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface4, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
