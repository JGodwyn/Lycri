import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_stroke.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/providers/auto_scroll_provider.dart';
import '../../../../shared/providers/lyrics_provider.dart';
import '../../../../shared/utils/auto_scroll_timing.dart';
import '../../../../shared/utils/dialog_utils.dart';
import '../../../../shared/widgets/fade_text.dart';
import '../../../../shared/widgets/lycri_button.dart';
import '../../../../shared/widgets/lycri_pill_group.dart';

/// `8s`, `2.7s`: whole seconds without a trailing `.0`.
String _seconds(double s) =>
    s == s.roundToDouble() ? '${s.round()}s' : '${s.toStringAsFixed(1)}s';

/// Height of the bottom-bar pills the auto-scroll control sits in.
const double _pillHeight = 32;
const double _iconSize = 20;

// ─── Toggle icon ────────────────────────────────────────────────────────────

/// The auto-scroll toggle's icon (Figma: autoscroll): a double chevron, the
/// back one in `icon-minimal`, the front one in the segment's icon colour.
class AutoScrollChevron extends StatelessWidget {
  const AutoScrollChevron({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _ChevronPainter(color));
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on the export's 20-unit grid.
    canvas.scale(size.width / 20);
    Paint stroke(Color c, double width) =>
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(
      Path()
        ..moveTo(5.14, 4)
        ..lineTo(9.71, 8.57)
        ..lineTo(14.29, 4),
      stroke(AppColors.iconMinimal, 1.83),
    );
    canvas.drawPath(
      Path()
        ..moveTo(4, 9.71)
        ..lineTo(9.71, 15.43)
        ..lineTo(15.43, 9.71),
      stroke(color, 2.29),
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter old) => old.color != color;
}

// ─── Tray ───────────────────────────────────────────────────────────────────

/// The auto-scroll options that slide out of the toggle, continuing its pill
/// (Figma: autoscroll): play/pause · Auto · 1x · 2x · 3x · Set time, each
/// segment fading in a beat after the one before.
class AutoScrollTray extends ConsumerStatefulWidget {
  const AutoScrollTray({super.key, required this.open});

  final bool open;

  @override
  ConsumerState<AutoScrollTray> createState() => _AutoScrollTrayState();
}

class _AutoScrollTrayState extends ConsumerState<AutoScrollTray>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 200),
    value: widget.open ? 1 : 0,
  );

  late final Animation<double> _size = CurvedAnimation(
    parent: _reveal,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  /// Segments, in order: play, Auto, 1x, 2x, 3x, Set time.
  static const _segmentCount = 6;

  /// Each segment fades and slides in over this share of the reveal, the
  /// next starting a beat later.
  static const _segmentSpan = 0.5;

  @override
  void didUpdateWidget(AutoScrollTray old) {
    super.didUpdateWidget(old);
    if (widget.open != old.open) {
      widget.open ? _reveal.forward() : _reveal.reverse();
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  Widget _stagger(int index, Widget child) {
    final start = (1 - _segmentSpan) * index / (_segmentCount - 1);
    final curved = CurvedAnimation(
      parent: _reveal,
      curve: Interval(start, start + _segmentSpan, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(-0.35, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _reveal,
      builder: (context, child) {
        if (_reveal.isDismissed) return const SizedBox.shrink();
        return ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: _size.value,
            child: child,
          ),
        );
      },
      child: _buildSegments(),
    );
  }

  Widget _buildSegments() {
    final auto = ref.watch(autoScrollProvider);
    final notifier = ref.read(autoScrollProvider.notifier);
    final canPlay = ref.watch(autoScrollCanPlayProvider);

    LycriPillSegment text(
      String label, {
      required bool selected,
      required VoidCallback onTap,
      String? tooltip,
    }) => LycriPillSegment(
      label: label,
      labelStyle: AppTypography.bodyLg,
      horizontalPadding: AppPadding.sm,
      selected: selected,
      tooltip: tooltip,
      onTap: onTap,
    );

    LycriPillSegment speed(AutoScrollMode mode, String label, String tip) =>
        text(
          label,
          selected: auto.mode == mode,
          tooltip: tip,
          onTap: () => notifier.setMode(mode),
        );

    String perLine(AutoScrollMode mode) =>
        'About ${_seconds(AutoScrollTiming.averageSeconds[mode]!)} per line';

    final length = auto.songLength;
    final items = [
      LycriPillSegment(
        svgAsset:
            auto.playing
                ? 'assets/vectors/pause.svg'
                : 'assets/vectors/play.svg',
        width: 36,
        enabled: auto.playing || canPlay,
        onTap: notifier.toggle,
      ),
      speed(
        AutoScrollMode.auto,
        'Auto',
        "Natural pace from each line's length",
      ),
      speed(AutoScrollMode.x1, '1x', perLine(AutoScrollMode.x1)),
      speed(AutoScrollMode.x2, '2x', perLine(AutoScrollMode.x2)),
      speed(AutoScrollMode.x3, '3x', perLine(AutoScrollMode.x3)),
      text(
        length == null ? 'Set time' : AutoScrollTiming.formatSongLength(length),
        selected: auto.mode == AutoScrollMode.songLength,
        onTap:
            () => showLycriDialog<void>(
              context: context,
              builder: (_) => const SongTimeDialog(),
            ),
      ),
    ];

    // Continues the toggle's pill: joined by `dist-xs`, round only at the end.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          const SizedBox(width: AppSpacing.xs),
          _stagger(
            i,
            LycriPillGroup(
              tone: LycriPillTone.muted,
              height: _pillHeight,
              iconSize: _iconSize,
              roundStart: false,
              roundEnd: i == items.length - 1,
              segments: [items[i]],
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Set time ───────────────────────────────────────────────────────────────

/// Modal for the song length auto-scroll spreads the lyrics over: separate
/// minutes and seconds boxes.
class SongTimeDialog extends ConsumerStatefulWidget {
  const SongTimeDialog({super.key});

  @override
  ConsumerState<SongTimeDialog> createState() => _SongTimeDialogState();
}

class _SongTimeDialogState extends ConsumerState<SongTimeDialog> {
  final _minutes = TextEditingController();
  final _seconds = TextEditingController();
  final _minutesFocus = FocusNode();
  final _secondsFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final length = ref.read(autoScrollProvider).songLength;
    if (length != null) {
      _minutes.text = '${length.inMinutes}';
      _seconds.text = (length.inSeconds % 60).toString().padLeft(2, '0');
    }
    _minutes.addListener(_onMinutesChanged);
    _seconds.addListener(() => setState(() {}));
    _secondsFocus.addListener(() {
      // "5" reads as 0:05 once you leave the box.
      if (!_secondsFocus.hasFocus && _seconds.text.length == 1) {
        _seconds.text = _seconds.text.padLeft(2, '0');
      }
    });
  }

  @override
  void dispose() {
    _minutes.dispose();
    _seconds.dispose();
    _minutesFocus.dispose();
    _secondsFocus.dispose();
    super.dispose();
  }

  /// Two minute digits cover any song: move on to seconds.
  void _onMinutesChanged() {
    setState(() {});
    if (_minutesFocus.hasFocus && _minutes.text.length == 2) {
      _secondsFocus.requestFocus();
    }
  }

  int get _min => int.tryParse(_minutes.text) ?? 0;
  int get _sec => int.tryParse(_seconds.text) ?? 0;
  bool get _secondsTooHigh => _sec >= 60;

  Duration? get _length {
    if (_secondsTooHigh) return null;
    final length = Duration(minutes: _min, seconds: _sec);
    return length == Duration.zero ? null : length;
  }

  void _apply() {
    final length = _length;
    if (length == null) return;
    ref.read(autoScrollProvider.notifier).setSongLength(length);
    Navigator.of(context).pop();
  }

  /// What the time works out to, or what's wrong with it; null (hidden)
  /// until a time is entered.
  Widget? _helper(int lineCount) {
    final length = _length;
    final String message;
    var color = AppColors.textSubtle;
    if (_secondsTooHigh) {
      message = 'Seconds go up to 59';
      color = AppColors.textDanger;
    } else if (length != null && lineCount > 0) {
      final seconds = length.inMilliseconds / 1000 / lineCount;
      message =
          '$lineCount ${lineCount == 1 ? 'line' : 'lines'}, '
          '${seconds.toStringAsFixed(1)}s each';
    } else {
      return null;
    }
    return Text(
      message,
      textAlign: TextAlign.center,
      style: AppTypography.bodyLg.copyWith(color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lineCount = ref.watch(lyricsLinesProvider).length;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(AppPadding.lg),
          decoration: BoxDecoration(
            color: AppColors.surface4,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: AppColors.borderMinimal,
              width: AppStroke.md,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title centred on the card; an empty slot balances the close
              // button.
              Row(
                children: [
                  const SizedBox(width: _CloseButton.size),
                  Expanded(
                    child: Center(
                      child: FadeText(
                        'Set song time'.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: AppTypography.titleLg.copyWith(
                          color: AppColors.textBold,
                        ),
                      ),
                    ),
                  ),
                  _CloseButton(onTap: () => Navigator.of(context).pop()),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'How long the song runs. Auto-scroll spreads the lines '
                'across this time.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyLg.copyWith(
                  color: AppColors.textSubtle,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TimeUnitField(
                    label: 'Minutes',
                    controller: _minutes,
                    focusNode: _minutesFocus,
                    maxDigits: 3,
                    autofocus: true,
                    onSubmitted: _apply,
                    // ":" (or ".") jumps to seconds, like typing 3:45.
                    onSeparator: _secondsFocus.requestFocus,
                  ),
                  SizedBox(
                    width: AppSpacing.xl,
                    height: _TimeUnitField.height,
                    child: Center(
                      child: Text(
                        ':',
                        style: AppTypography.headingSm.copyWith(
                          color: AppColors.textSubtle,
                        ),
                      ),
                    ),
                  ),
                  _TimeUnitField(
                    label: 'Seconds',
                    controller: _seconds,
                    focusNode: _secondsFocus,
                    maxDigits: 2,
                    max: 59,
                    invalid: _secondsTooHigh,
                    onSubmitted: _apply,
                    // Backspace past the start goes back to minutes.
                    onBackspaceWhenEmpty: _minutesFocus.requestFocus,
                  ),
                ],
              ),
              if (_helper(lineCount) case final helper?) ...[
                const SizedBox(height: AppSpacing.md),
                helper,
              ],
              const SizedBox(height: AppSpacing.lg),
              LycriButton(
                label: 'Set time',
                fillWidth: true,
                onPressed: _length == null ? null : _apply,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One box of the song-time entry: big centred digits, its unit below.
/// Digits only; ↑/↓ step the value.
class _TimeUnitField extends StatelessWidget {
  const _TimeUnitField({
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.maxDigits,
    required this.onSubmitted,
    this.max,
    this.invalid = false,
    this.autofocus = false,
    this.onSeparator,
    this.onBackspaceWhenEmpty,
  });

  static const double height = 56;

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final int maxDigits;
  final VoidCallback onSubmitted;

  /// Highest value ↑ steps to.
  final int? max;
  final bool invalid;
  final bool autofocus;
  final VoidCallback? onSeparator;
  final VoidCallback? onBackspaceWhenEmpty;

  void _step(int by) {
    final current = int.tryParse(controller.text) ?? 0;
    final next = (current + by).clamp(0, max ?? 999);
    final text = maxDigits == 2 ? '$next'.padLeft(2, '0') : '$next';
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) {
      _step(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _step(-1);
      return KeyEventResult.handled;
    }
    if (onSeparator != null &&
        (event.character == ':' || event.character == '.')) {
      onSeparator!();
      return KeyEventResult.handled;
    }
    if (onBackspaceWhenEmpty != null &&
        key == LogicalKeyboardKey.backspace &&
        controller.text.isEmpty) {
      onBackspaceWhenEmpty!();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.headingSm.copyWith(color: AppColors.textBold);
    return Column(
      children: [
        Focus(
          onKeyEvent: _onKey,
          skipTraversal: true,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 88,
            height: height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface3,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color:
                    invalid ? AppColors.borderDanger : AppColors.borderSubtle,
                width: AppStroke.md,
              ),
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: autofocus,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: style,
              cursorColor: AppColors.textBrand,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(maxDigits),
              ],
              onTap:
                  () =>
                      controller.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: controller.text.length,
                      ),
              onSubmitted: (_) => onSubmitted(),
              // The box above is the field: drop the theme's white fill and
              // outline so there's no field inside the field.
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                hintText: maxDigits == 2 ? '00' : '0',
                hintStyle: style.copyWith(color: AppColors.textMinimal),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          label,
          style: AppTypography.bodyMd.copyWith(color: AppColors.textSubtle),
        ),
      ],
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  static const double size = 32;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(AppPadding.xs),
          decoration: const BoxDecoration(
            color: AppColors.surface3,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close, size: 18, color: AppColors.iconSubtle),
        ),
      ),
    );
  }
}
