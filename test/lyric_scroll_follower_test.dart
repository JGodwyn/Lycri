import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lycri_lyrics/shared/utils/lyric_scroll_follower.dart';

class _Harness extends StatefulWidget {
  const _Harness({super.key});

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness>
    with SingleTickerProviderStateMixin {
  static const lineHeight = 50.0;
  final controller = ScrollController();
  late final LyricScrollFollower follower;
  int active = 0;

  @override
  void initState() {
    super.initState();
    follower = LyricScrollFollower(
      vsync: this,
      controller: controller,
      target: () => active * lineHeight,
    );
  }

  void goTo(int index) {
    active = index;
    follower.follow();
  }

  @override
  void dispose() {
    follower.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        height: 300,
        child: SingleChildScrollView(
          controller: controller,
          child: Column(
            children: [
              for (var i = 0; i < 60; i++) const SizedBox(height: lineHeight),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('rapid next presses scroll forward only, then settle', (
    tester,
  ) async {
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(_Harness(key: key));
    final state = key.currentState!;

    final offsets = <double>[];
    // Ten presses, 60ms apart — faster than one 400ms glide.
    for (var i = 1; i <= 10; i++) {
      state.goTo(i);
      for (var f = 0; f < 4; f++) {
        await tester.pump(const Duration(milliseconds: 15));
        offsets.add(state.controller.offset);
      }
    }
    await tester.pumpAndSettle();
    offsets.add(state.controller.offset);

    for (var i = 1; i < offsets.length; i++) {
      expect(
        offsets[i],
        greaterThanOrEqualTo(offsets[i - 1]),
        reason: 'scrolled backwards at frame $i',
      );
    }
    expect(state.controller.offset, 10 * _HarnessState.lineHeight);
  });

  testWidgets('reversing mid-glide turns around without overshooting', (
    tester,
  ) async {
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(_Harness(key: key));
    final state = key.currentState!;

    state.goTo(4);
    await tester.pump(const Duration(milliseconds: 15));
    await tester.pump(const Duration(milliseconds: 100));
    state.goTo(3);
    await tester.pumpAndSettle();
    expect(state.controller.offset, 3 * _HarnessState.lineHeight);
  });
}
