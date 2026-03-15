import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_stroke.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/providers/lyrics_style_provider.dart';
import '../../../shared/providers/system_fonts_provider.dart';
import '../../../shared/widgets/lycri_dropdown.dart';

/// Right panel of the operator window.
/// Hosts the lyric style editor — currently the Text section controls.
/// Background section will be added in a future iteration.
class EditorPanel extends ConsumerStatefulWidget {
  const EditorPanel({super.key});

  @override
  ConsumerState<EditorPanel> createState() => _EditorPanelState();
}

class _EditorPanelState extends ConsumerState<EditorPanel> {
  // ── Local UI state (will move to providers when wiring functionality) ────

  String _selectedAlignment = 'Left';
  Color _selectedFontColor = const Color(0xFF000000);

  static const List<String> _lineCounts = ['Auto', '1', '2', '3', '4', '5'];

  @override
  Widget build(BuildContext context) {
    final fontsAsync = ref.watch(systemFontsProvider);
    final selectedFont = ref.watch(
      lyricsStyleProvider.select((s) => s.fontFamily),
    );
    final displayLines = ref.watch(
      lyricsStyleProvider.select((s) => s.displayLines),
    );
    final selectedLineCountStr =
        displayLines == 0 ? 'Auto' : displayLines.toString();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface4,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderMinimal, width: AppStroke.md),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title ──────────────────────────────────────────────────────
            Text(
              'Editor',
              style: AppTypography.headingSm.copyWith(
                color: AppColors.textSubtle,
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Text section ───────────────────────────────────────────────
            const _SectionHeader(label: 'Text'),

            const SizedBox(height: AppSpacing.lg),

            // ── Font Family ────────────────────────────────────────────────
            _buildLabel('Font Family'),
            const SizedBox(height: AppSpacing.md),
            fontsAsync.when(
              data:
                  (fonts) => LycriDropdown<String>(
                    items:
                        fonts
                            .map(
                              (f) => LycriDropdownItem(
                                value: f,
                                label: f,
                                fontFamily: f,
                              ),
                            )
                            .toList(),
                    selectedValue: selectedFont,
                    onChanged:
                        (font) => ref
                            .read(lyricsStyleProvider.notifier)
                            .setFontFamily(font),
                    leadingIcon: Icons.text_format,
                  ),
              loading:
                  () => const SizedBox(
                    height: 48,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
              error:
                  (_, __) => Text(
                    'Failed to load fonts',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.textDanger,
                    ),
                  ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Lyrics to display at a time ────────────────────────────────
            _buildLabel('Lyrics to display at a time'),
            const SizedBox(height: AppSpacing.md),
            _ChipRow(
              items: _lineCounts,
              selected: selectedLineCountStr,
              onSelected: (v) {
                final count = v == 'Auto' ? 0 : int.parse(v);
                ref.read(lyricsStyleProvider.notifier).setDisplayLines(count);
              },
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Alignment ──────────────────────────────────────────────────
            _buildLabel('Alignment'),
            const SizedBox(height: AppSpacing.md),
            _AlignmentSelector(
              selected: _selectedAlignment,
              onSelected: (v) => setState(() => _selectedAlignment = v),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Font color ─────────────────────────────────────────────────
            _buildLabel('Font color'),
            const SizedBox(height: AppSpacing.md),
            _ColorRow(color: _selectedFontColor),

            const SizedBox(height: AppSpacing.x3l),

            // ── Background section (placeholder) ──────────────────────────
            const _SectionHeader(label: 'Background'),

            // Background controls will be added in a future iteration.
          ],
        ),
      ),
    );
  }

  /// Builds a small label above each control group.
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: AppTypography.bodyMd.copyWith(color: AppColors.textSubtle),
    );
  }
}

// ─── Section header with dotted divider ─────────────────────────────────────

/// Renders a section title (e.g. "Text", "Background") with a dotted
/// line running alongside it.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: AppTypography.titleLg.copyWith(color: AppColors.textBold),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: CustomPaint(
            size: const Size(double.infinity, 1),
            painter: _DottedLinePainter(color: AppColors.borderBold),
          ),
        ),
      ],
    );
  }
}

/// Paints a simple horizontal dotted line.
class _DottedLinePainter extends CustomPainter {
  _DottedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = AppStroke.md
          ..strokeCap = StrokeCap.round;

    const dashWidth = 3.0;
    const dashGap = 4.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(x + dashWidth, size.height / 2),
        paint,
      );
      x += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DottedLinePainter oldDelegate) =>
      color != oldDelegate.color;
}

// ─── Chip row (used for line count selector) ────────────────────────────────

/// A pill-shaped tray with a light brand tint. A white pill indicator
/// slides smoothly to the selected item instead of snapping.
class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final List<String> items;
  final String selected;
  final ValueChanged<String> onSelected;

  static const _animDuration = Duration(milliseconds: 300);
  static const _animCurve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = items.indexOf(selected).clamp(0, items.length - 1);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceBrandLight,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / items.length;

          return SizedBox(
            height: 40,
            child: Stack(
              children: [
                // ── Sliding indicator pill ─────────────────────────────────
                AnimatedPositioned(
                  duration: _animDuration,
                  curve: _animCurve,
                  left: selectedIndex * itemWidth,
                  top: 0,
                  bottom: 0,
                  width: itemWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface4,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(
                        color: AppColors.borderBrand,
                        width: AppStroke.lg,
                      ),
                    ),
                  ),
                ),

                // ── Text labels ────────────────────────────────────────────
                Row(
                  children:
                      items.map((item) {
                        final isSelected = item == selected;
                        return Expanded(
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onSelected(item),
                              child: Center(
                                child: AnimatedDefaultTextStyle(
                                  duration: _animDuration,
                                  curve: _animCurve,
                                  style: AppTypography.bodyMd.copyWith(
                                    color:
                                        isSelected
                                            ? AppColors.textBold
                                            : AppColors.textSubtle,
                                  ),
                                  child: Text(item),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Alignment selector ─────────────────────────────────────────────────────

/// Alignment selector with a `surfaceBrandLight` tray and a sliding white
/// pill indicator that glides to the selected option.
class _AlignmentSelector extends StatelessWidget {
  const _AlignmentSelector({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  static const _animDuration = Duration(milliseconds: 300);
  static const _animCurve = Curves.easeOutCubic;

  static const _alignmentData = [
    {'label': 'Left', 'icon': Icons.format_align_left},
    {'label': 'Center', 'icon': Icons.format_align_center},
    {'label': 'Right', 'icon': Icons.format_align_right},
  ];

  @override
  Widget build(BuildContext context) {
    final labels = _alignmentData.map((d) => d['label'] as String).toList();
    final selectedIndex = labels.indexOf(selected).clamp(0, labels.length - 1);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceBrandLight,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / _alignmentData.length;

          return SizedBox(
            height: 64,
            child: Stack(
              children: [
                // ── Sliding indicator pill ─────────────────────────────────
                AnimatedPositioned(
                  duration: _animDuration,
                  curve: _animCurve,
                  left: selectedIndex * itemWidth,
                  top: 0,
                  bottom: 0,
                  width: itemWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface4,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(
                        color: AppColors.borderBrand,
                        width: AppStroke.lg,
                      ),
                    ),
                  ),
                ),

                // ── Icon + label cells ─────────────────────────────────────
                Row(
                  children:
                      _alignmentData.map((data) {
                        final label = data['label'] as String;
                        final icon = data['icon'] as IconData;
                        final isSelected = label == selected;

                        return Expanded(
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onSelected(label),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedSwitcher(
                                    duration: _animDuration,
                                    child: Icon(
                                      icon,
                                      key: ValueKey('${label}_$isSelected'),
                                      size: 24,
                                      color:
                                          isSelected
                                              ? AppColors.iconBold
                                              : AppColors.iconSubtle,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  AnimatedDefaultTextStyle(
                                    duration: _animDuration,
                                    curve: _animCurve,
                                    style: AppTypography.bodySm.copyWith(
                                      color:
                                          isSelected
                                              ? AppColors.textBold
                                              : AppColors.textSubtle,
                                    ),
                                    child: Text(label),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Color row ──────────────────────────────────────────────────────────────

/// Displays a color swatch, its hex code, and a picker icon.
/// Non-functional for now — serves as UI placeholder.
class _ColorRow extends StatelessWidget {
  const _ColorRow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    // Convert the colour to a 6-digit hex string.
    final hex =
        '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface3,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.borderSubtle, width: AppStroke.md),
      ),
      child: Row(
        children: [
          // Color swatch
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: AppColors.borderSubtle,
                width: AppStroke.sm,
              ),
            ),
          ),

          const SizedBox(width: AppSpacing.md),

          // Hex code
          Expanded(
            child: Text(
              hex,
              style: AppTypography.bodyMd.copyWith(color: AppColors.textBold),
            ),
          ),

          // Picker icon (non-functional placeholder)
          Icon(Icons.palette, size: 18, color: AppColors.iconSubtle),
        ],
      ),
    );
  }
}
