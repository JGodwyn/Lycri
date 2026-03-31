import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_stroke.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/providers/lyrics_style_provider.dart';
import '../../../shared/providers/recent_backgrounds_provider.dart';
import '../../../shared/providers/system_fonts_provider.dart';

import '../../../shared/widgets/lycri_color_picker.dart';
import '../../../shared/widgets/lycri_dropdown.dart';
import '../../../shared/widgets/video_thumbnail_widget.dart';



/// Right panel of the operator window.
/// Hosts the lyric style editor — currently the Text section controls.
/// Background section will be added in a future iteration.
class EditorPanel extends ConsumerStatefulWidget {
  const EditorPanel({super.key});

  @override
  ConsumerState<EditorPanel> createState() => _EditorPanelState();
}

class _EditorPanelState extends ConsumerState<EditorPanel> {
  static const List<String> _lineCounts = ['Auto', '1', '2', '3', '4', '5'];

  /// Track previous background type to determine push direction.
  BackgroundType? _prevBackgroundType;

  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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

    final currentBackgroundType = ref.watch(
      lyricsStyleProvider.select((s) => s.backgroundType),
    );

    // Determine direction for push transition.
    final bool isForward =
        _prevBackgroundType == null ||
        currentBackgroundType.index >= _prevBackgroundType!.index;

    // Use a post frame callback to avoid updating state during build when
    // initial value is set, but since we are just tracking for the NEXT build,
    // we can update it at the end of build or in a listener.
    // ref.listen is cleaner.
    ref.listen<BackgroundType>(
      lyricsStyleProvider.select((s) => s.backgroundType),
      (prev, next) {
        if (prev != next) {
          setState(() {
            _prevBackgroundType = prev;
          });
        }
      },
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface4,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderMinimal, width: AppStroke.md),
      ),
      child: Scrollbar(
        controller: _scrollController,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(AppSpacing.lg),
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
              const SizedBox(height: AppSpacing.sm),
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
                      showSearch: true,
                      searchHint: 'Search fonts here',
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
              const SizedBox(height: AppSpacing.sm),
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
              const SizedBox(height: AppSpacing.sm),
              _AlignmentSelector(
                selectedActiveToken: ref.watch(lyricsStyleProvider).textAlign,
                onSelected:
                    (v) =>
                        ref.read(lyricsStyleProvider.notifier).setTextAlign(v),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Font color ─────────────────────────────────────────────────
              _buildLabel('Font color'),
              const SizedBox(height: AppSpacing.sm),
              LycriColorField(
                color: ref.watch(lyricsStyleProvider).fontColor,
                onColorChanged:
                    (c) =>
                        ref.read(lyricsStyleProvider.notifier).setFontColor(c),
              ),

              const SizedBox(height: AppSpacing.x3l),

              // ── Background section ──────────────────────────────────────
              const _SectionHeader(label: 'Background'),

              const SizedBox(height: AppSpacing.lg),

              // ── Background type ───────────────────────────────────────────
              _buildLabel('Background type'),
              const SizedBox(height: AppSpacing.sm),
              _BackgroundTypeSelector(
                selected: ref.watch(lyricsStyleProvider).backgroundType,
                onSelected:
                    (type) => ref
                        .read(lyricsStyleProvider.notifier)
                        .setBackgroundType(type),
                backgroundColor: ref.watch(lyricsStyleProvider).backgroundColor,
                gradientColors: ref.watch(lyricsStyleProvider).gradientColors,
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Conditional sub-controls ──────────────────────────────────
              ClipRect(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (
                    Widget? currentChild,
                    List<Widget> previousChildren,
                  ) {
                    return Stack(
                      alignment: Alignment.topLeft,
                      children: <Widget>[
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    );
                  },
                  transitionBuilder: (child, animation) {
                    // If it's the child that's coming in (it matches currentBackgroundType)
                    final bool isIncoming =
                        (child.key as ValueKey<String>?)?.value ==
                        _getBackgroundKey(currentBackgroundType);

                    // Offset based on direction.
                    // Forward: In from (1,0), Out to (-1,0)
                    // Backward: In from (-1,0), Out to (1,0)
                    final Offset beginOffset =
                        isIncoming
                            ? (isForward
                                ? const Offset(1, 0)
                                : const Offset(-1, 0))
                            : (isForward
                                ? const Offset(-1, 0)
                                : const Offset(1, 0));

                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: beginOffset,
                        end: Offset.zero,
                      ).animate(animation),
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: _buildBackgroundSubControls(ref),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Map background type to ValueKey string used in _buildBackgroundSubControls.
  String _getBackgroundKey(BackgroundType type) {
    switch (type) {
      case BackgroundType.solidColor:
        return 'bg_solid';
      case BackgroundType.gradient:
        return 'bg_gradient';
      case BackgroundType.image:
        return 'bg_image';
      case BackgroundType.video:
        return 'bg_video';
    }
  }

  /// Builds a small label above each control group.
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: AppTypography.bodyLg.copyWith(color: AppColors.textSubtle),
    );
  }

  /// Builds the sub-controls shown below the background type selector,
  /// dependent on the currently selected [BackgroundType].
  Widget _buildBackgroundSubControls(WidgetRef ref) {
    final style = ref.watch(lyricsStyleProvider);

    switch (style.backgroundType) {
      case BackgroundType.solidColor:
        return Column(
          key: const ValueKey('bg_solid'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('Choose color'),
            const SizedBox(height: AppSpacing.md),
            LycriColorField(
              color: style.backgroundColor,
              onColorChanged: (c) {
                ref.read(lyricsStyleProvider.notifier).setBackgroundColor(c);
              },
              onPickerDismissed:
                  (c) =>
                      ref.read(recentBackgroundsProvider.notifier).addColor(c),
            ),

            const SizedBox(height: AppSpacing.xl),
            _RecentlyUsedSection<Color>(
              title: 'Recently used',
              items: ref.watch(recentBackgroundsProvider).colors,
              onScale:
                  (c) => ref
                      .read(lyricsStyleProvider.notifier)
                      .setBackgroundColor(c),
              itemBuilder:
                  (c) => Container(
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
            ),
          ],
        );
      case BackgroundType.gradient:
        return Column(
          key: const ValueKey('bg_gradient'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('Gradient type'),
            const SizedBox(height: AppSpacing.md),
            _GradientTypeSelector(
              selected: style.gradientType,
              onSelected:
                  (type) => ref
                      .read(lyricsStyleProvider.notifier)
                      .setGradientType(type),
            ),
            const SizedBox(height: AppSpacing.xl),
            _buildLabel('Choose first color'),
            const SizedBox(height: AppSpacing.md),
            LycriColorField(
              color:
                  style.gradientColors.isNotEmpty
                      ? style.gradientColors[0]
                      : Colors.white,
              onColorChanged: (c) {
                final colors = List<Color>.from(style.gradientColors);
                if (colors.isEmpty) {
                  colors.addAll([c, Colors.black]);
                } else {
                  colors[0] = c;
                }
                ref
                    .read(lyricsStyleProvider.notifier)
                    .setGradientColors(colors);
              },
              onPickerDismissed: (_) {
                final colors = ref.read(lyricsStyleProvider).gradientColors;
                ref
                    .read(recentBackgroundsProvider.notifier)
                    .addGradient(style.gradientType, colors);
              },
            ),

            const SizedBox(height: AppSpacing.xl),
            _buildLabel('Choose second color'),
            const SizedBox(height: AppSpacing.md),
            LycriColorField(
              color:
                  style.gradientColors.length >= 2
                      ? style.gradientColors[1]
                      : Colors.black,
              onColorChanged: (c) {
                final colors = List<Color>.from(style.gradientColors);
                if (colors.length < 2) {
                  colors.addAll([Colors.white, c]);
                } else {
                  colors[1] = c;
                }
                ref
                    .read(lyricsStyleProvider.notifier)
                    .setGradientColors(colors);
              },
              onPickerDismissed: (_) {
                final colors = ref.read(lyricsStyleProvider).gradientColors;
                ref
                    .read(recentBackgroundsProvider.notifier)
                    .addGradient(style.gradientType, colors);
              },
            ),

            const SizedBox(height: AppSpacing.xl),
            _RecentlyUsedSection<RecentGradient>(
              title: 'Recently used',
              items: ref.watch(recentBackgroundsProvider).gradients,
              onScale: (g) {
                ref.read(lyricsStyleProvider.notifier).setGradientType(g.type);
                ref
                    .read(lyricsStyleProvider.notifier)
                    .setGradientColors(g.colors);
              },
              itemBuilder:
                  (g) => Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: AppColors.borderSubtle,
                        width: 1,
                      ),
                      gradient:
                          g.type == GradientType.linear
                              ? LinearGradient(
                                colors: g.colors,
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              )
                              : RadialGradient(colors: g.colors),
                    ),
                  ),
            ),
          ],
        );

      case BackgroundType.image:
        return Column(
          key: const ValueKey('bg_image'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('Background image'),
            const SizedBox(height: AppSpacing.md),
            _ImageBackgroundSelector(
              imagePath: style.backgroundImagePath,
              onSelect: () async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.image,
                  allowMultiple: false,
                );
                if (result != null && result.files.single.path != null) {
                  final path = result.files.single.path!;
                  ref
                      .read(lyricsStyleProvider.notifier)
                      .setBackgroundImagePath(path);
                  ref
                      .read(recentBackgroundsProvider.notifier)
                      .addImagePath(path);
                }
              },
              onRemove: () {
                ref
                    .read(lyricsStyleProvider.notifier)
                    .setBackgroundImagePath(null);
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            _RecentlyUsedSection<String>(
              title: 'Recently used',
              items: ref.watch(recentBackgroundsProvider).imagePaths,
              onScale:
                  (path) => ref
                      .read(lyricsStyleProvider.notifier)
                      .setBackgroundImagePath(path),
              itemBuilder:
                  (path) => ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Image.file(
                      File(path),
                      fit: BoxFit.fill,
                      cacheWidth: 60,
                      cacheHeight: 60,
                      errorBuilder:
                          (_, __, ___) => Container(
                            color: AppColors.surface3,
                            child: const Icon(
                              Icons.image_not_supported,
                              size: 12,
                            ),
                          ),
                    ),
                  ),
            ),
          ],
        );

      case BackgroundType.video:
        return Column(
          key: const ValueKey('bg_video'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('Video'),
            const SizedBox(height: AppSpacing.md),
            _VideoBackgroundSelector(
              videoPath: style.backgroundVideoPath,
              onSelect: () async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.video,
                  allowMultiple: false,
                );
                if (result != null && result.files.single.path != null) {
                  ref
                      .read(lyricsStyleProvider.notifier)
                      .setBackgroundVideoPath(result.files.single.path);
                  ref
                      .read(recentBackgroundsProvider.notifier)
                      .addVideoPath(result.files.single.path!);
                }
              },
              onRemove: () {
                ref
                    .read(lyricsStyleProvider.notifier)
                    .setBackgroundVideoPath(null);
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            _RecentlyUsedSection<String>(
              title: 'Recently used',
              items: ref.watch(recentBackgroundsProvider).videoPaths,
              onScale:
                  (path) => ref
                      .read(lyricsStyleProvider.notifier)
                      .setBackgroundVideoPath(path),
              itemBuilder:
                  (path) => VideoThumbnailWidget(
                    videoPath: path,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),

            ),
          ],
        );
    }
  }
}

// ─── Recently Used Widgets ──────────────────────────────────────────────────

class _RecentlyUsedSection<T> extends StatelessWidget {
  final String title;
  final List<T> items;
  final Widget Function(T) itemBuilder;
  final ValueChanged<T> onScale;

  const _RecentlyUsedSection({
    required this.title,
    required this.items,
    required this.itemBuilder,
    required this.onScale,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.bodyLg.copyWith(color: AppColors.textSubtle),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final item = items[index];
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => onScale(item),
                  child: SizedBox(
                    width: 48,
                    height: 40,
                    child: itemBuilder(item),
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
      padding: const EdgeInsets.all(AppSpacing.md),
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
  const _AlignmentSelector({
    required this.selectedActiveToken,
    required this.onSelected,
  });

  final TextAlign selectedActiveToken;
  final ValueChanged<TextAlign> onSelected;

  static const _animDuration = Duration(milliseconds: 300);
  static const _animCurve = Curves.easeOutCubic;

  static const _alignmentData = [
    {
      'label': 'Left',
      'icon': 'assets/vectors/format-align-left.svg',
      'value': TextAlign.left,
    },
    {
      'label': 'Center',
      'icon': 'assets/vectors/format-align-center.svg',
      'value': TextAlign.center,
    },
    {
      'label': 'Right',
      'icon': 'assets/vectors/format-align-right.svg',
      'value': TextAlign.right,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final values = _alignmentData.map((d) => d['value'] as TextAlign).toList();
    final selectedIndex = values
        .indexOf(selectedActiveToken)
        .clamp(0, values.length - 1);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
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
                        final icon = data['icon'] as String;
                        final val = data['value'] as TextAlign;

                        final isSelected = val == selectedActiveToken;

                        return Expanded(
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onSelected(val),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedSwitcher(
                                    duration: _animDuration,
                                    child: SvgPicture.asset(
                                      icon,
                                      key: ValueKey('${label}_$isSelected'),
                                      width: 24,
                                      height: 24,
                                      colorFilter: ColorFilter.mode(
                                        isSelected
                                            ? AppColors.iconBold
                                            : AppColors.iconSubtle,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: AppSpacing.xs),
                                  AnimatedDefaultTextStyle(
                                    duration: _animDuration,
                                    curve: _animCurve,
                                    style: AppTypography.bodyMd.copyWith(
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
// ─── Background type selector ───────────────────────────────────────────────

/// A `surfaceBrandLight` tray with icon + label items and a sliding
/// white pill indicator — matches the alignment selector pattern.
/// Uses dynamic color/gradient swatches and SVG icons for Image/Video.
class _BackgroundTypeSelector extends StatelessWidget {
  const _BackgroundTypeSelector({
    required this.selected,
    required this.onSelected,
    required this.backgroundColor,
    required this.gradientColors,
  });

  final BackgroundType selected;
  final ValueChanged<BackgroundType> onSelected;

  /// Current solid background color — used for the Color swatch.
  final Color backgroundColor;

  /// Current gradient colors — used for the Gradient swatch.
  final List<Color> gradientColors;

  static const _animDuration = Duration(milliseconds: 300);
  static const _animCurve = Curves.easeOutCubic;

  static const _labels = ['Solid', 'Flow', 'Image', 'Video'];
  static const _values = [
    BackgroundType.solidColor,
    BackgroundType.gradient,
    BackgroundType.image,
    BackgroundType.video,
  ];

  /// Builds the visual icon/swatch for each background type.
  Widget _buildIcon(int index, bool isSelected) {
    switch (_values[index]) {
      case BackgroundType.solidColor:
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color:
                  isSelected ? AppColors.borderBrand : AppColors.borderSubtle,
              width: AppStroke.sm,
            ),
          ),
        );
      case BackgroundType.gradient:
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            gradient: LinearGradient(
              colors:
                  gradientColors.length >= 2
                      ? gradientColors
                      : [Colors.white, Colors.black],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color:
                  isSelected ? AppColors.borderBrand : AppColors.borderSubtle,
              width: AppStroke.sm,
            ),
          ),
        );
      case BackgroundType.image:
        return SvgPicture.asset(
          'assets/vectors/ImageVector.svg',
          width: 20,
          height: 20,
          colorFilter: ColorFilter.mode(
            isSelected ? AppColors.iconBrand : AppColors.iconSubtle,
            BlendMode.srcIn,
          ),
        );
      case BackgroundType.video:
        return SvgPicture.asset(
          'assets/vectors/videoVector.svg',
          width: 20,
          height: 20,
          colorFilter: ColorFilter.mode(
            isSelected ? AppColors.iconBrand : AppColors.iconSubtle,
            BlendMode.srcIn,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _values
        .indexOf(selected)
        .clamp(0, _values.length - 1);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceBrandLight,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / _values.length;

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
                  children: List.generate(_values.length, (i) {
                    final isSelected = _values[i] == selected;

                    return Expanded(
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onSelected(_values[i]),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedSwitcher(
                                duration: _animDuration,
                                child: KeyedSubtree(
                                  key: ValueKey('${_labels[i]}_$isSelected'),
                                  child: _buildIcon(i, isSelected),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              AnimatedDefaultTextStyle(
                                duration: _animDuration,
                                curve: _animCurve,
                                style: AppTypography.bodyMd.copyWith(
                                  color:
                                      isSelected
                                          ? AppColors.textSubtle
                                          : AppColors.textSubtle,
                                ),
                                child: Text(_labels[i]),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Gradient type selector ───────────────────────────────────────────────

/// Matches the segmented bar pattern used for alignment and background type.
class _GradientTypeSelector extends StatelessWidget {
  const _GradientTypeSelector({
    required this.selected,
    required this.onSelected,
  });

  final GradientType selected;
  final ValueChanged<GradientType> onSelected;

  static const _animDuration = Duration(milliseconds: 300);
  static const _animCurve = Curves.easeOutCubic;

  static const _labels = ['Linear', 'Radial'];
  static const _values = [GradientType.linear, GradientType.radial];
  static const _icons = [Icons.linear_scale, Icons.vignette];

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _values
        .indexOf(selected)
        .clamp(0, _values.length - 1);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceBrandLight,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / _values.length;

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
                        width: AppStroke.sm,
                      ),
                    ),
                  ),
                ),

                // ── Label cells ────────────────────────────────────────────
                Row(
                  children: List.generate(_values.length, (i) {
                    final isSelected = _values[i] == selected;
                    return Expanded(
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onSelected(_values[i]),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // const SizedBox(height: AppSpacing.sm),
                              AnimatedDefaultTextStyle(
                                duration: _animDuration,
                                curve: _animCurve,
                                style: AppTypography.bodyMd.copyWith(
                                  color:
                                      isSelected
                                          ? AppColors.textBold
                                          : AppColors.textSubtle,
                                ),
                                child: Text(_labels[i]),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Image background selector ──────────────────────────────────────────

/// UI for selecting or removing a background image.
class _ImageBackgroundSelector extends StatelessWidget {
  const _ImageBackgroundSelector({
    required this.imagePath,
    required this.onSelect,
    required this.onRemove,
  });

  final String? imagePath;
  final VoidCallback onSelect;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    bool hasImage = imagePath != null && imagePath!.isNotEmpty;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface3,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.borderMinimal, width: AppStroke.md),
      ),
      child: Row(
        children: [
          if (hasImage) ...[
            // Thumbnail & Name clickable area
            Expanded(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onSelect,
                  child: Row(
                    children: [
                      // Thumbnail
                      Container(
                        width: 32,
                        height: 24,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          color: AppColors.surface2,
                        ),
                        child: Image.file(
                          File(imagePath!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: AppColors.surface0,
                              child: const Icon(Icons.broken_image, size: 16),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      // Filename
                      Expanded(
                        child: Text(
                          imagePath!.split('/').last,
                          style: AppTypography.bodyMd.copyWith(
                            color: AppColors.textSubtle,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Separate Delete button (unwrapped from global gesture)
            IconButton(
              onPressed: onRemove,
              icon: SvgPicture.asset(
                'assets/vectors/delete-trash.svg',
                width: 20,
                height: 20,
                colorFilter: const ColorFilter.mode(
                  AppColors.textDanger,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ] else ...[
            // Empty state clickable area
            Expanded(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onSelect,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Tap to select an image',
                          style: AppTypography.bodyLg.copyWith(
                            color: AppColors.textSubtle,
                          ),
                        ),
                      ),
                      SvgPicture.asset(
                        'assets/vectors/image-plus.svg',
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                          AppColors.iconMinimal,
                          BlendMode.srcIn,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
// ─── Video Background Selector ────────────────────────────────────────────────

class _VideoBackgroundSelector extends StatelessWidget {
  const _VideoBackgroundSelector({
    required this.videoPath,
    required this.onSelect,
    required this.onRemove,
  });

  final String? videoPath;
  final VoidCallback onSelect;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    bool hasVideo = videoPath != null && videoPath!.isNotEmpty;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface3,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.borderMinimal, width: AppStroke.md),
      ),
      child: Row(
        children: [
          if (hasVideo) ...[
            // Clickable area for changing the video
            Expanded(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onSelect,
                  child: Row(
                    children: [
                      // Video icon circle
                      VideoThumbnailWidget(
                        videoPath: videoPath!,
                        width: 32,
                        height: 24,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),

                      const SizedBox(width: AppSpacing.md),
                      // Filename
                      Expanded(
                        child: Text(
                          videoPath!.split('/').last,
                          style: AppTypography.bodyMd.copyWith(
                            color: AppColors.textSubtle,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Delete button
            IconButton(
              onPressed: onRemove,
              icon: SvgPicture.asset(
                'assets/vectors/delete-trash.svg',
                width: 20,
                height: 20,
                colorFilter: const ColorFilter.mode(
                  AppColors.textDanger,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ] else ...[
            // Empty state
            Expanded(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onSelect,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Tap to select a video',
                          style: AppTypography.bodyLg.copyWith(
                            color: AppColors.textSubtle,
                          ),
                        ),
                      ),
                      SvgPicture.asset(
                        'assets/vectors/videoVector.svg',
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                          AppColors.iconMinimal,
                          BlendMode.srcIn,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
