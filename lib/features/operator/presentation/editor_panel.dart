import 'dart:io';
import '../../../shared/providers/last_directory_provider.dart';
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
import '../../../shared/widgets/lycri_pill_group.dart';
import '../../../shared/widgets/lycri_segmented_tray.dart';
import '../../../shared/widgets/lycri_stepper.dart';
import '../../../shared/widgets/lycri_value_chip.dart';
import '../../../shared/widgets/scroll_fade_mask.dart';
import '../../../shared/widgets/video_thumbnail_widget.dart';
import '../../../shared/utils/dialog_utils.dart';
import '../providers/preset_state_provider.dart';
import 'widgets/preset_search_dialog.dart';
import '../../../shared/widgets/fade_text.dart';
import '../../../shared/widgets/checkerboard.dart';
import 'widgets/save_preset_menu.dart';

/// Right panel of the operator window (Figma: "EditorWindow1–3").
/// Sections: LYRIC (font, colour, lines, alignment), BACKGROUND (type plus
/// per-type controls) and RECENTLY USED, separated by dashed rules.
class EditorPanel extends ConsumerStatefulWidget {
  const EditorPanel({super.key});

  @override
  ConsumerState<EditorPanel> createState() => _EditorPanelState();
}

class _EditorPanelState extends ConsumerState<EditorPanel>
    with SingleTickerProviderStateMixin {
  static const List<String> _lineCounts = ['Auto', '1', '2', '3', '4', 'All'];

  /// Width of the label column in inline rows (Figma: 96).
  static const double _labelColumn = 96;

  /// Track previous background type to determine push direction.
  BackgroundType? _prevBackgroundType;

  final ScrollController _scrollController = ScrollController();

  /// Runs for one background-type switch; drives the edge fade on the
  /// per-type controls area while the panels slide.
  late final AnimationController _switchFade = AnimationController(
    vsync: this,
    duration: _switchDuration,
  );

  @override
  void dispose() {
    _switchFade.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontsAsync = ref.watch(systemFontsProvider);
    final style = ref.watch(lyricsStyleProvider);
    final recents = ref.watch(recentBackgroundsProvider);
    final selectedLineCountStr =
        style.displayLines == -1
            ? 'Auto'
            : (style.displayLines == 0 ? 'All' : style.displayLines.toString());

    final presetState = ref.watch(presetStateProvider);
    final presetName = presetState.currentPreset?.name ?? 'Presets';

    final currentBackgroundType = style.backgroundType;

    // Determine direction for push transition.
    final bool isForward =
        _prevBackgroundType == null ||
        currentBackgroundType.index >= _prevBackgroundType!.index;

    ref.listen<BackgroundType>(
      lyricsStyleProvider.select((s) => s.backgroundType),
      (prev, next) {
        if (prev != next) {
          setState(() {
            _prevBackgroundType = prev;
          });
          _switchFade.forward(from: 0);
        }
      },
    );

    final recentChips = _recentChips(style.backgroundType, recents);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface4,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: AppColors.borderSubtle,
          width: AppStroke.sm,
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20),
        ],
      ),
      child: ScrollConfiguration(
        // No scrollbar: the edge fade signals more content.
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: ScrollFadeMask(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(AppPadding.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ───────────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: FadeText(
                        'Editor'.toUpperCase(),
                        style: AppTypography.headingSm.copyWith(
                          color: AppColors.textSubtle,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    _EditorHeaderActions(
                      canSave: presetState.isDirty,
                      presetName: presetName,
                      onOpenPresets:
                          () => showLycriDialog(
                            context: context,
                            builder: (context) => const PresetSearchDialog(),
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                // ── Lyric ────────────────────────────────────────────────────
                _Section(
                  title: 'Lyric',
                  gap: AppSpacing.md,
                  children: [
                    _StackedField(
                      label: 'Lyrics to display at a time',
                      child: LycriSegmentedTray<String>(
                        options: [
                          for (final c in _lineCounts)
                            LycriTrayOption(value: c, label: c),
                        ],
                        selected: selectedLineCountStr,
                        onSelected: (v) {
                          final count =
                              v == 'Auto'
                                  ? -1
                                  : (v == 'All' ? 0 : int.parse(v));
                          ref
                              .read(lyricsStyleProvider.notifier)
                              .setDisplayLines(count);
                        },
                      ),
                    ),
                    _InlineField(
                      label: 'Size',
                      labelWidth: _labelColumn,
                      child: LycriSegmentedTray<LyricsSize>(
                        options: const [
                          LycriTrayOption(
                            value: LyricsSize.small,
                            label: 'Small',
                          ),
                          LycriTrayOption(value: LyricsSize.mid, label: 'Mid'),
                          LycriTrayOption(value: LyricsSize.big, label: 'Big'),
                        ],
                        selected: style.size,
                        onSelected:
                            (v) => ref
                                .read(lyricsStyleProvider.notifier)
                                .setSize(v),
                      ),
                    ),
                    _InlineField(
                      label: 'Position',
                      labelWidth: _labelColumn,
                      gap: AppSpacing.sm,
                      child: LycriSegmentedTray<LyricsPosition>(
                        options: [
                          for (final (value, label, icon) in const [
                            (LyricsPosition.top, 'Top', 'position-top'),
                            (
                              LyricsPosition.middle,
                              'Middle',
                              'position-middle',
                            ),
                            (
                              LyricsPosition.bottom,
                              'Bottom',
                              'position-bottom',
                            ),
                          ])
                            LycriTrayOption(
                              value: value,
                              label: label,
                              iconBuilder: (color, _) => _svgIcon(icon, color),
                            ),
                        ],
                        selected: style.position,
                        onSelected:
                            (v) => ref
                                .read(lyricsStyleProvider.notifier)
                                .setPosition(v),
                      ),
                    ),
                    _InlineField(
                      label: 'Clipped',
                      labelWidth: _labelColumn,
                      info:
                          'Yes: when the lyrics change, they fade in and out '
                          'just above and below the lyrics. No: they slide '
                          'all the way to the edges of the screen.',
                      child: LycriSegmentedTray<bool>(
                        options: const [
                          LycriTrayOption(value: true, label: 'Yes'),
                          LycriTrayOption(value: false, label: 'No'),
                        ],
                        selected: style.clipped,
                        onSelected:
                            (v) => ref
                                .read(lyricsStyleProvider.notifier)
                                .setClipped(v),
                      ),
                    ),
                  ],
                ),

                const _Divider(),

                // ── Typography ───────────────────────────────────────────────
                _Section(
                  title: 'Typography',
                  gap: AppSpacing.md,
                  children: [
                    fontsAsync.when(
                      data:
                          (fonts) => LycriDropdown<String>(
                            items: [
                              for (final f in fonts)
                                LycriDropdownItem(
                                  value: f,
                                  label: f,
                                  fontFamily: f,
                                ),
                            ],
                            selectedValue: style.fontFamily,
                            onChanged:
                                (font) => ref
                                    .read(lyricsStyleProvider.notifier)
                                    .setFontFamily(font),
                            leadingSvg: 'assets/vectors/format-font-size.svg',
                            showSearch: true,
                            searchHint: 'Search fonts here',
                          ),
                      loading:
                          () => const SizedBox(
                            height: 40,
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                      error:
                          (_, _) => Text(
                            'Failed to load fonts',
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.textDanger,
                            ),
                          ),
                    ),
                    _InlineField(
                      label: 'Font color',
                      labelWidth: _labelColumn,
                      child: LycriColorField(
                        compact: true,
                        color: style.fontColor,
                        onColorChanged:
                            (c) => ref
                                .read(lyricsStyleProvider.notifier)
                                .setFontColor(c),
                      ),
                    ),
                    _InlineField(
                      label: 'Alignment',
                      labelWidth: _labelColumn,
                      gap: AppSpacing.sm,
                      child: LycriSegmentedTray<TextAlign>(
                        options: [
                          for (final (value, label, icon) in const [
                            (TextAlign.left, 'Left', 'format-align-left'),
                            (TextAlign.center, 'Center', 'format-align-center'),
                            (TextAlign.right, 'Right', 'format-align-right'),
                          ])
                            LycriTrayOption(
                              value: value,
                              label: label,
                              iconBuilder: (color, _) => _svgIcon(icon, color),
                            ),
                        ],
                        selected: style.textAlign,
                        onSelected:
                            (v) => ref
                                .read(lyricsStyleProvider.notifier)
                                .setTextAlign(v),
                      ),
                    ),
                    _InlineField(
                      label: 'Line height',
                      labelWidth: _labelColumn,
                      child: LycriStepper(
                        value: style.lineHeight,
                        min: 10,
                        max: 100,
                        format: (v) => '$v%',
                        onChanged:
                            ref
                                .read(lyricsStyleProvider.notifier)
                                .setLineHeight,
                      ),
                    ),
                    _InlineField(
                      label: 'Shadow',
                      labelWidth: _labelColumn,
                      child: LycriSegmentedTray<bool>(
                        options: const [
                          LycriTrayOption(value: true, label: 'Yes'),
                          LycriTrayOption(value: false, label: 'No'),
                        ],
                        selected: style.textShadow,
                        onSelected:
                            ref
                                .read(lyricsStyleProvider.notifier)
                                .setTextShadow,
                      ),
                    ),
                  ],
                ),

                const _Divider(),

                // ── Background ───────────────────────────────────────────────
                _Section(
                  title: 'Background',
                  gap: AppSpacing.md,
                  children: [
                    _StackedField(
                      label: 'Background type',
                      child: LycriSegmentedTray<BackgroundType>(
                        options: [
                          LycriTrayOption(
                            value: BackgroundType.solidColor,
                            label: 'Color',
                            iconBuilder:
                                (_, selected) => _TypeSwatch(
                                  color:
                                      selected
                                          ? AppColors.gray0
                                          : AppColors.gray400,
                                ),
                          ),
                          const LycriTrayOption(
                            value: BackgroundType.gradient,
                            label: 'Gradient',
                            iconBuilder: _gradientTypeSwatch,
                          ),
                          LycriTrayOption(
                            value: BackgroundType.image,
                            label: 'Image',
                            iconBuilder:
                                (color, _) => _svgIcon('ImageVector', color),
                          ),
                          LycriTrayOption(
                            value: BackgroundType.video,
                            label: 'Video',
                            iconBuilder:
                                (color, _) => _svgIcon('videoVector', color),
                          ),
                          const LycriTrayOption(
                            value: BackgroundType.transparent,
                            label: 'Transparent',
                            iconBuilder: _transparentTypeSwatch,
                          ),
                        ],
                        selected: currentBackgroundType,
                        onSelected:
                            (type) => ref
                                .read(lyricsStyleProvider.notifier)
                                .setBackgroundType(type),
                      ),
                    ),

                    // ── Per-type controls ─────────────────────────────────────
                    // Height follows the incoming controls straight away and
                    // animates, so the divider and everything below glide
                    // rather than waiting for the outgoing controls to leave.
                    // The area itself stays put: it fades its left/right edges
                    // while a switch runs and clips horizontally exactly where
                    // that fade is fully transparent — so sliding panels
                    // dissolve at the edge instead of running past the editor.
                    _SwitchEdgeFade(
                      animation: _switchFade,
                      child: AnimatedSize(
                        duration: _resizeDuration,
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        clipBehavior: Clip.none,
                        child: AnimatedSwitcher(
                          duration: _switchDuration,
                          reverseDuration: const Duration(milliseconds: 200),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          layoutBuilder: _sizeToCurrent,
                          transitionBuilder: (child, animation) {
                            final isIncoming =
                                (child.key as ValueKey<String>?)?.value ==
                                _getBackgroundKey(currentBackgroundType);
                            final beginOffset =
                                isIncoming
                                    ? Offset(isForward ? 1 : -1, 0)
                                    : Offset(isForward ? -1 : 1, 0);
                            return SlideTransition(
                              position: Tween<Offset>(
                                begin: beginOffset,
                                end: Offset.zero,
                              ).animate(animation),
                              // Outgoing controls fade in the first half so
                              // they're gone before the content below moves
                              // up underneath them.
                              child: FadeTransition(
                                opacity:
                                    isIncoming
                                        ? animation
                                        : CurvedAnimation(
                                          parent: animation,
                                          curve: const Interval(0.5, 1),
                                        ),
                                child: child,
                              ),
                            );
                          },
                          child: _buildBackgroundSubControls(style),
                        ),
                      ),
                    ),
                  ],
                ),

                // ── Recently used ────────────────────────────────────────────
                AnimatedSize(
                  duration: _resizeDuration,
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  clipBehavior: Clip.none,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    layoutBuilder: _sizeToCurrent,
                    child: Column(
                      // Only appearing/disappearing swaps this block; the
                      // divider and title stay put between types.
                      key: ValueKey(recentChips.isEmpty),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (recentChips.isNotEmpty) ...[
                          const _Divider(),
                          _Section(
                            title: 'Recently used',
                            children: [
                              // Chips cross-fade when the background type
                              // changes; height is animated by AnimatedSize.
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                layoutBuilder: _sizeToCurrent,
                                child: LayoutBuilder(
                                  key: ValueKey(currentBackgroundType),
                                  builder: (context, constraints) {
                                    // Chips carry a value (hex, file name),
                                    // so at most two per row.
                                    const columns = 2;
                                    final width =
                                        (constraints.maxWidth -
                                            AppSpacing.md * (columns - 1)) /
                                        columns;
                                    return Wrap(
                                      spacing: AppSpacing.md,
                                      runSpacing: AppSpacing.md,
                                      children: [
                                        for (final chip in recentChips)
                                          SizedBox(width: width, child: chip),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const _resizeDuration = Duration(milliseconds: 220);
  static const _switchDuration = Duration(milliseconds: 350);

  /// AnimatedSwitcher layout that sizes to the incoming child only: outgoing
  /// children are positioned (they don't hold the height open), so a
  /// wrapping [AnimatedSize] starts resizing immediately.
  static Widget _sizeToCurrent(
    Widget? currentChild,
    List<Widget> previousChildren,
  ) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topLeft,
      children: [
        for (final child in previousChildren)
          Positioned(top: 0, left: 0, right: 0, child: child),
        if (currentChild != null) currentChild,
      ],
    );
  }

  Widget _svgIcon(String name, Color color) {
    return SvgPicture.asset(
      'assets/vectors/$name.svg',
      width: 20,
      height: 20,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
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
      case BackgroundType.transparent:
        return 'bg_transparent';
    }
  }

  static String _fileName(String path) =>
      path.split(Platform.pathSeparator).last;

  Future<void> _pickFile(BackgroundType type) async {
    final isImage = type == BackgroundType.image;
    final lastDir = ref.read(lastPickerDirectoryProvider);
    final result = await FilePicker.platform.pickFiles(
      type: isImage ? FileType.image : FileType.video,
      allowMultiple: false,
      initialDirectory: lastDir,
    );
    final path = result?.files.single.path;
    if (path == null) return;
    ref.read(lastPickerDirectoryProvider.notifier).update(path);
    final style = ref.read(lyricsStyleProvider.notifier);
    final recents = ref.read(recentBackgroundsProvider.notifier);
    if (isImage) {
      style.setBackgroundImagePath(path);
      recents.addImagePath(path);
    } else {
      style.setBackgroundVideoPath(path);
      recents.addVideoPath(path);
    }
  }

  /// Controls under the background type selector, per [BackgroundType].
  Widget _buildBackgroundSubControls(LyricsStyleState style) {
    final notifier = ref.read(lyricsStyleProvider.notifier);
    final recents = ref.read(recentBackgroundsProvider.notifier);

    switch (style.backgroundType) {
      case BackgroundType.solidColor:
        return _InlineField(
          key: const ValueKey('bg_solid'),
          label: 'Color',
          labelWidth: _labelColumn,
          child: LycriColorField(
            compact: true,
            color: style.backgroundColor,
            onColorChanged: notifier.setBackgroundColor,
            onPickerDismissed: recents.addColor,
          ),
        );

      case BackgroundType.gradient:
        final colors =
            style.gradientColors.length >= 2
                ? style.gradientColors
                : const [Colors.white, Colors.black];
        void setColor(int index, Color c) {
          final next = List<Color>.from(colors)..[index] = c;
          notifier.setGradientColors(next);
        }

        void remember(Color _) => recents.addGradient(
          style.gradientType,
          ref.read(lyricsStyleProvider).gradientColors,
        );

        return Column(
          key: const ValueKey('bg_gradient'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _InlineField(
              label: 'Gradient type',
              child: LycriSegmentedTray<GradientType>(
                options: const [
                  LycriTrayOption(value: GradientType.linear, label: 'Linear'),
                  LycriTrayOption(value: GradientType.radial, label: 'Radial'),
                ],
                selected: style.gradientType,
                onSelected: notifier.setGradientType,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _InlineField(
              label: 'Colors',
              labelWidth: _labelColumn,
              child: Row(
                children: [
                  for (var i = 0; i < 2; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: LycriColorField(
                        compact: true,
                        color: colors[i],
                        onColorChanged: (c) => setColor(i, c),
                        onPickerDismissed: remember,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );

      case BackgroundType.image:
      case BackgroundType.video:
        final isImage = style.backgroundType == BackgroundType.image;
        final path =
            isImage ? style.backgroundImagePath : style.backgroundVideoPath;
        final hasFile = path != null && path.isNotEmpty;
        return _InlineField(
          key: ValueKey(isImage ? 'bg_image' : 'bg_video'),
          label: isImage ? 'Image' : 'Video',
          labelWidth: _labelColumn,
          child: LycriValueChip(
            leading:
                hasFile
                    ? _FileThumb(path: path, isImage: isImage)
                    : ColoredBox(
                      color: AppColors.surface3,
                      child: Center(
                        child: _svgIcon(
                          isImage ? 'image-plus' : 'videoVector',
                          AppColors.iconSubtle,
                        ),
                      ),
                    ),
            value:
                hasFile
                    ? _fileName(path)
                    : (isImage ? 'Choose an image' : 'Choose a video'),
            tooltip: hasFile ? path : null,
            onTap: () => _pickFile(style.backgroundType),
            onDelete:
                hasFile
                    ? () =>
                        isImage
                            ? notifier.setBackgroundImagePath(null)
                            : notifier.setBackgroundVideoPath(null)
                    : null,
          ),
        );

      case BackgroundType.transparent:
        return Column(
          key: const ValueKey('bg_transparent'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _InlineField(
              label: 'Overlay',
              labelWidth: _labelColumn,
              info:
                  'A soft gradient behind the lyrics, so they stay readable '
                  'over busy video. It sits where the lyrics are positioned.',
              child: LycriSegmentedTray<bool>(
                options: const [
                  LycriTrayOption(value: true, label: 'Yes'),
                  LycriTrayOption(value: false, label: 'No'),
                ],
                selected: style.overlay,
                onSelected: notifier.setOverlay,
              ),
            ),
            // Tone row only while the overlay is on.
            AnimatedSize(
              duration: _resizeDuration,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child:
                  style.overlay
                      ? Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _InlineField(
                              label: 'Color',
                              labelWidth: _labelColumn,
                              child: LycriSegmentedTray<LyricsOverlayTone>(
                                options: const [
                                  LycriTrayOption(
                                    value: LyricsOverlayTone.light,
                                    label: 'Light',
                                  ),
                                  LycriTrayOption(
                                    value: LyricsOverlayTone.dark,
                                    label: 'Dark',
                                  ),
                                ],
                                selected: style.overlayTone,
                                onSelected: notifier.setOverlayTone,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _InlineField(
                              label: 'Opacity',
                              labelWidth: _labelColumn,
                              child: LycriStepper(
                                value: style.overlayOpacity,
                                format: (v) => '$v%',
                                onChanged: notifier.setOverlayOpacity,
                              ),
                            ),
                          ],
                        ),
                      )
                      : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Only the NDI output is transparent, ready to layer over video '
              'in vMix, OBS or a switcher. Screens and projectors show a '
              'black background.',
              style: AppTypography.bodyLg.copyWith(color: AppColors.textSubtle),
            ),
          ],
        );
    }
  }

  /// Recently used values for the current background type, as chips.
  List<Widget> _recentChips(BackgroundType type, RecentBackgroundsState r) {
    final notifier = ref.read(lyricsStyleProvider.notifier);
    switch (type) {
      case BackgroundType.solidColor:
        return [
          for (final c in r.colors)
            LycriValueChip(
              leading: ChipSwatch(color: c),
              tint: c,
              value: _hex(c),
              onTap: () => notifier.setBackgroundColor(c),
            ),
        ];
      case BackgroundType.gradient:
        return [
          for (final g in r.gradients)
            LycriValueChip(
              leading: ChipSwatch(gradient: _gradientOf(g.type, g.colors)),
              tint: g.colors.first,
              value: g.type == GradientType.linear ? 'Linear' : 'Radial',
              tooltip: g.colors.map(_hex).join(' → '),
              onTap: () {
                notifier.setGradientType(g.type);
                notifier.setGradientColors(g.colors);
              },
            ),
        ];
      case BackgroundType.image:
        return [
          for (final p in r.imagePaths)
            LycriValueChip(
              leading: _FileThumb(path: p, isImage: true),
              value: _fileName(p),
              tooltip: p,
              onTap: () => notifier.setBackgroundImagePath(p),
            ),
        ];
      case BackgroundType.video:
        return [
          for (final p in r.videoPaths)
            LycriValueChip(
              leading: _FileThumb(path: p, isImage: false),
              value: _fileName(p),
              tooltip: p,
              onTap: () => notifier.setBackgroundVideoPath(p),
            ),
        ];
      case BackgroundType.transparent:
        return const [];
    }
  }

  static String _hex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  static Gradient _gradientOf(GradientType type, List<Color> colors) =>
      type == GradientType.linear
          ? LinearGradient(
            colors: colors,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          )
          : RadialGradient(colors: colors);
}

/// Static gradient glyph for the background-type tray (doesn't follow the
/// chosen gradient — the tray shows the type, not the value).
Widget _gradientTypeSwatch(Color _, bool selected) => _TypeSwatch(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors:
        selected
            ? const [AppColors.gray0, AppColors.gray400]
            : const [AppColors.gray200, AppColors.gray500],
  ),
);

/// Checkerboard glyph for the "Transparent" background type.
Widget _transparentTypeSwatch(Color _, bool selected) => Padding(
  padding: const EdgeInsets.all(1.5),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(AppRadius.sm),
    child: Checkerboard(
      cellSize: 4.25,
      light: selected ? AppColors.gray0 : AppColors.gray400,
      dark: selected ? AppColors.gray400 : AppColors.gray600,
    ),
  ),
);

// ─── Layout pieces ──────────────────────────────────────────────────────────

/// Edge fade for the background controls area during a type switch.
///
/// Fades the left/right [_extent] px while [animation] runs (off at rest, so
/// labels at x=0 aren't faded) and clips horizontally at the area's edges,
/// where the fade is fully transparent — panels sliding out dissolve rather
/// than running past the editor. No vertical clip, so the height animation
/// isn't cut.
class _SwitchEdgeFade extends StatelessWidget {
  const _SwitchEdgeFade({required this.animation, required this.child});

  final AnimationController animation;
  final Widget child;

  static const double _extent = 40;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        // Full fade for most of the switch, easing off as panels settle.
        final t = animation.value;
        final strength =
            animation.isAnimating ? (t < 0.8 ? 1.0 : (1 - t) / 0.2) : 0.0;
        final edge = Colors.black.withValues(alpha: 1 - strength);
        // Same widget structure at rest and mid-switch: swapping it would
        // rebuild the AnimatedSize below and kill its height animation.
        return ClipRect(
          clipper: const _HorizontalClipper(),
          clipBehavior: strength > 0 ? Clip.hardEdge : Clip.none,
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) {
              final f =
                  bounds.width <= 0
                      ? 0.0
                      : (_extent / bounds.width).clamp(0.0, 0.5);
              return LinearGradient(
                colors: [edge, Colors.black, Colors.black, edge],
                stops: [0, f, 1 - f, 1],
              ).createShader(bounds);
            },
            child: child,
          ),
        );
      },
    );
  }
}

/// Clips left/right only; vertically unbounded.
class _HorizontalClipper extends CustomClipper<Rect> {
  const _HorizontalClipper();

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, -100000, size.width, size.height + 100000);

  @override
  bool shouldReclip(_HorizontalClipper oldClipper) => false;
}

/// Titled editor group (Figma: "LYRIC", "BACKGROUND", "RECENTLY USED").
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.gap = AppSpacing.lg,
  });

  final String title;
  final List<Widget> children;

  /// Space between the title and each row.
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title.toUpperCase(),
          style: AppTypography.titleLg.copyWith(color: AppColors.textMinimal),
        ),
        for (final child in children) ...[SizedBox(height: gap), child],
      ],
    );
  }
}

/// Dashed rule between sections, 24px above and below.
class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: CustomPaint(
        size: const Size(double.infinity, 1),
        painter: _DottedLinePainter(color: AppColors.borderBold),
      ),
    );
  }
}

/// Label above its control (4px gap).
class _StackedField extends StatelessWidget {
  const _StackedField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(label),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}

/// Label and control side by side. Without [labelWidth] they split the row
/// evenly; with it the label column is fixed and the control fills the rest
/// (Figma: 96). [gap] separates
/// them — 8, or 4 beside the icon trays.
class _InlineField extends StatelessWidget {
  const _InlineField({
    super.key,
    required this.label,
    required this.child,
    this.labelWidth,
    this.gap = AppSpacing.md,
    this.info,
  });

  final String label;
  final Widget child;
  final double? labelWidth;
  final double gap;
  final String? info;

  @override
  Widget build(BuildContext context) {
    final labelWidget = _FieldLabel(label, info: info);
    return Row(
      children: [
        if (labelWidth != null)
          SizedBox(width: labelWidth, child: labelWidget)
        else
          Expanded(child: labelWidget),
        SizedBox(width: gap),
        Expanded(child: child),
      ],
    );
  }
}

/// Field label, with an info icon (4px after) whose tooltip is [info].
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.info});

  final String text;
  final String? info;

  @override
  Widget build(BuildContext context) {
    final label = FadeText(
      text,
      style: AppTypography.bodyLg.copyWith(color: AppColors.textSubtle),
    );
    if (info == null) return label;
    return Row(
      children: [
        Flexible(child: label),
        const SizedBox(width: AppSpacing.sm),
        Tooltip(
          message: info!,
          child: SvgPicture.asset(
            'assets/vectors/info-circle.svg',
            width: 16,
            height: 16,
            colorFilter: const ColorFilter.mode(
              AppColors.iconSubtle,
              BlendMode.srcIn,
            ),
          ),
        ),
      ],
    );
  }
}

/// 17px rounded glyph inset in a 20px box (Figma "Frame 1279").
class _TypeSwatch extends StatelessWidget {
  const _TypeSwatch({this.color, this.gradient});

  final Color? color;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          gradient: gradient,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    );
  }
}

/// Image or video thumbnail filling a chip's leading square.
class _FileThumb extends StatelessWidget {
  const _FileThumb({required this.path, required this.isImage});

  final String path;
  final bool isImage;

  @override
  Widget build(BuildContext context) {
    if (!isImage) {
      return VideoThumbnailWidget(
        videoPath: path,
        width: LycriValueChip.height,
        height: LycriValueChip.height,
      );
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      cacheWidth: 48,
      errorBuilder:
          (_, _, _) => const ColoredBox(
            color: AppColors.surface2,
            child: Icon(
              Icons.image_not_supported,
              size: 12,
              color: AppColors.iconSubtle,
            ),
          ),
    );
  }
}

// ─── Dashed divider ─────────────────────────────────────────────────────────

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

    const dashWidth = 4.0;
    const dashGap = 12.0;
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

// ─── Header actions: save preset + presets ──────────────────────────────────

/// Joined [save | PRESETS ⇕] pill (Figma: Editor header). Save opens the
/// name-your-preset menu and flashes a check once saved.
class _EditorHeaderActions extends ConsumerStatefulWidget {
  const _EditorHeaderActions({
    required this.canSave,
    required this.presetName,
    required this.onOpenPresets,
  });

  final bool canSave;
  final String presetName;
  final VoidCallback onOpenPresets;

  @override
  ConsumerState<_EditorHeaderActions> createState() =>
      _EditorHeaderActionsState();
}

class _EditorHeaderActionsState extends ConsumerState<_EditorHeaderActions>
    with TickerProviderStateMixin {
  bool _showSuccess = false;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isMenuOpen = false;

  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    final curved = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _scaleAnim = Tween(begin: 0.92, end: 1.0).animate(curved);
    _fadeAnim = Tween(begin: 0.0, end: 1.0).animate(curved);
  }

  @override
  void dispose() {
    _closeMenu();
    _animController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    if (_isMenuOpen) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  void _openMenu() {
    _overlayEntry = OverlayEntry(
      builder:
          (context) => Stack(
            children: [
              // Tap-away barrier
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _closeMenu,
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned(
                width: 280,
                child: CompositedTransformFollower(
                  link: _layerLink,
                  showWhenUnlinked: false,
                  targetAnchor: Alignment.bottomRight,
                  followerAnchor: Alignment.topRight,
                  offset: const Offset(0, AppSpacing.sm),
                  child: Material(
                    color: Colors.transparent,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: ScaleTransition(
                        scale: _scaleAnim,
                        child: SavePresetMenu(
                          onClose: _closeMenu,
                          onSave: (title) => _confirmSave(title),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _animController.forward();
    setState(() => _isMenuOpen = true);
  }

  void _closeMenu() {
    if (!_isMenuOpen) return;
    _animController.reverse().then((_) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
    _isMenuOpen = false;
    if (mounted) setState(() {});
  }

  Future<void> _confirmSave(String title) async {
    _closeMenu();

    final data = ref.read(lyricsStyleProvider.notifier).exportPresetData();
    await ref
        .read(presetStateProvider.notifier)
        .saveCurrentAsPreset(title, data);

    if (mounted) {
      setState(() => _showSuccess = true);
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        setState(() => _showSuccess = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: LycriPillGroup(
        segments: [
          LycriPillSegment(
            svgAsset:
                _showSuccess
                    ? 'assets/vectors/check-large.svg'
                    : 'assets/vectors/save.svg',
            tooltip: widget.canSave ? 'Save as preset' : 'No changes to save',
            enabled: widget.canSave && !_showSuccess,
            onTap: _toggleMenu,
          ),
          LycriPillSegment(
            label: widget.presetName,
            labelMaxWidth: 112,
            trailingSvgAsset: 'assets/vectors/unfold-more.svg',
            tooltip: 'Presets',
            onTap: widget.onOpenPresets,
          ),
        ],
      ),
    );
  }
}
