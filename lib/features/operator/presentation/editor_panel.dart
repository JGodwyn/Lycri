import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_stroke.dart';
import '../../../core/theme/app_typography.dart';

/// Right panel of the operator window.
/// Hosts the lyric style editor — currently the Text section controls.
/// Background section will be added in a future iteration.
class EditorPanel extends StatefulWidget {
  const EditorPanel({super.key});

  @override
  State<EditorPanel> createState() => _EditorPanelState();
}

class _EditorPanelState extends State<EditorPanel> {
  // ── Local UI state (will move to providers when wiring functionality) ────

  String _selectedFont = 'Libre Caslon Condensed';
  String _selectedLineCount = 'Auto';
  String _selectedAlignment = 'Left';
  Color _selectedFontColor = const Color(0xFF000000);

  static const List<String> _fontFamilies = [
    'Libre Caslon Condensed',
    'Libre Caslon Text',
    'Source Code Pro',
  ];

  static const List<String> _lineCounts = ['Auto', '1', '2', '3', '4', '5'];

  @override
  Widget build(BuildContext context) {
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
            _FontFamilyDropdown(
              selectedFont: _selectedFont,
              fontFamilies: _fontFamilies,
              onChanged: (font) => setState(() => _selectedFont = font),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Lyrics to display at a time ────────────────────────────────
            _buildLabel('Lyrics to display at a time'),
            const SizedBox(height: AppSpacing.md),
            _ChipRow(
              items: _lineCounts,
              selected: _selectedLineCount,
              onSelected: (v) => setState(() => _selectedLineCount = v),
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

// ─── Font family dropdown ───────────────────────────────────────────────────

class _FontFamilyDropdown extends StatelessWidget {
  const _FontFamilyDropdown({
    required this.selectedFont,
    required this.fontFamilies,
    required this.onChanged,
  });

  final String selectedFont;
  final List<String> fontFamilies;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      color: AppColors.surface4,
      itemBuilder:
          (_) =>
              fontFamilies
                  .map(
                    (font) => PopupMenuItem<String>(
                      value: font,
                      child: Text(
                        font,
                        style: AppTypography.bodyMd.copyWith(
                          fontFamily: font,
                          color: AppColors.textBold,
                        ),
                      ),
                    ),
                  )
                  .toList(),
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
            // "Tt" font icon
            Text(
              'T',
              style: AppTypography.titleMd.copyWith(
                color: AppColors.textBold,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            Text(
              'T',
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.textBold,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: AppSpacing.xmd),
            Expanded(
              child: Text(
                selectedFont,
                style: AppTypography.bodyMd.copyWith(
                  fontFamily: selectedFont,
                  color: AppColors.textBold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: AppColors.iconSubtle,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Chip row (used for line count selector) ────────────────────────────────

class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final List<String> items;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children:
          items.map((item) {
            final isSelected = item == selected;
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => onSelected(item),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.surface4 : AppColors.surface4,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(
                      color:
                          isSelected
                              ? AppColors.borderBrand
                              : AppColors.borderSubtle,
                      width: isSelected ? AppStroke.lg : AppStroke.md,
                    ),
                  ),
                  child: Text(
                    item,
                    style: AppTypography.bodyMd.copyWith(
                      color:
                          isSelected
                              ? AppColors.textBold
                              : AppColors.textSubtle,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }
}

// ─── Alignment selector ─────────────────────────────────────────────────────

class _AlignmentSelector extends StatelessWidget {
  const _AlignmentSelector({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  static const _alignmentData = [
    {'label': 'Left', 'icon': Icons.format_align_left},
    {'label': 'Center', 'icon': Icons.format_align_center},
    {'label': 'Right', 'icon': Icons.format_align_right},
  ];

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < _alignmentData.length; i++) {
      final data = _alignmentData[i];
      final label = data['label'] as String;
      final icon = data['icon'] as IconData;
      final isSelected = label == selected;

      if (i > 0) {
        items.add(const SizedBox(width: AppSpacing.md));
      }

      items.add(
        Expanded(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => onSelected(label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xmd),
                decoration: BoxDecoration(
                  color: AppColors.surface4,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color:
                        isSelected
                            ? AppColors.borderBrand
                            : AppColors.borderSubtle,
                    width: isSelected ? AppStroke.lg : AppStroke.md,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 24,
                      color:
                          isSelected
                              ? AppColors.iconBold
                              : AppColors.iconSubtle,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      label,
                      style: AppTypography.bodySm.copyWith(
                        color:
                            isSelected
                                ? AppColors.textBold
                                : AppColors.textSubtle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(children: items);
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
        color: AppColors.surface4,
        borderRadius: BorderRadius.circular(AppRadius.md),
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

          const SizedBox(width: AppSpacing.xmd),

          // Hex code
          Expanded(
            child: Text(
              hex,
              style: AppTypography.bodyMd.copyWith(color: AppColors.textBold),
            ),
          ),

          // Picker icon (non-functional placeholder)
          Icon(Icons.colorize_rounded, size: 18, color: AppColors.iconSubtle),
        ],
      ),
    );
  }
}
