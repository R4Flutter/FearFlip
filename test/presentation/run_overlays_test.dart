import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fearflipgame/presentation/gameplay/widgets/run_failed_dialog.dart';
import 'package:fearflipgame/presentation/gameplay/widgets/run_paused_dialog.dart';
import 'package:fearflipgame/presentation/gameplay/widgets/stage_clear_overlay.dart';

/// The rejected look: neon green, pink, purple and cyan (RGB, any alpha).
const _neon = {
  0x33FF2B, 0xE85BDA, 0xE26AE6, 0x87ECFF, 0x79EFFF, 0xFF3D8B, 0xC5B0FF, //
  0xB7FFA8, 0xFF8A80,
};

bool _isNeon(Color? c) => c != null && _neon.contains(c.toARGB32() & 0xFFFFFF);

/// Every colour the overlay's widgets paint with.
List<Color?> _colours(WidgetTester tester) {
  final out = <Color?>[];
  void deco(Decoration? d) {
    if (d is BoxDecoration) {
      out.add(d.color);
      final b = d.border;
      if (b is Border) {
        out.addAll([b.top.color, b.left.color, b.right.color, b.bottom.color]);
      }
      out.addAll(d.boxShadow?.map((s) => s.color) ?? const []);
      out.addAll(d.gradient?.colors ?? const []);
    }
  }

  for (final e in tester.allElements) {
    final w = e.widget;
    if (w is Text) {
      out.add(w.style?.color);
      out.addAll(w.style?.shadows?.map((s) => s.color) ?? const []);
    } else if (w is Icon) {
      out.add(w.color);
    } else if (w is DecoratedBox) {
      deco(w.decoration);
    } else if (w is Container) {
      deco(w.decoration);
    }
  }
  return out;
}

Finder _asset(String name) => find.byWidgetPredicate(
  (w) =>
      w is Image &&
      w.image is AssetImage &&
      (w.image as AssetImage).assetName == 'assets/images/2d/ui/$name.png',
);

Future<void> _show(WidgetTester tester, Widget overlay) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 420, child: overlay)),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
}

RunFailedDialog _failed({bool time = false, bool trap = false}) =>
    RunFailedDialog(
      stage: 31,
      maxStage: 100,
      escapePercent: 31,
      checkpointText: '19 stages to 50',
      modeLabel: 'NORMAL',
      timeRemainingLabel: '0:42',
      lossReason: 'Devil intercepted you.',
      comebackHook: 'Try again.',
      lostByTime: time,
      lostByTrap: trap,
      trapDeathQuote: null,
      adActionInProgress: false,
      livesRemaining: 1,
      maxLives: 3,
      onRevivePressed: () async {},
      onRestartPressed: () async {},
    );

void main() {
  testWidgets('pause: the bone medallion holds the pause sign, no neon', (
    tester,
  ) async {
    await _show(
      tester,
      RunPausedDialog(
        stage: 12,
        checkpoint: 0,
        nextCheckpoint: 25,
        checkpointText: '13 stages to 25',
        modeLabel: 'NORMAL',
        timeRemainingLabel: '1:05',
        onResumePressed: () {},
        onExitPressed: () async {},
      ),
    );
    expect(_asset('medallion'), findsOneWidget);
    expect(_asset('icon_pause'), findsOneWidget);
    expect(_colours(tester).where(_isNeon), isEmpty);
  });

  testWidgets('caught: a skull for the Devil, the hourglass for time, '
      'crossed bones for the floor; hearts from the art; no neon', (
    tester,
  ) async {
    await _show(tester, _failed());
    expect(_asset('icon_skull'), findsOneWidget);
    expect(_asset('icon_heart'), findsOneWidget);
    expect(_asset('icon_heart_empty'), findsNWidgets(2));
    expect(_colours(tester).where(_isNeon), isEmpty);

    await _show(tester, _failed(time: true));
    expect(_asset('icon_hourglass'), findsOneWidget);

    await _show(tester, _failed(trap: true));
    expect(_asset('icon_cross'), findsOneWidget);
    expect(_colours(tester).where(_isNeon), isEmpty);
  });

  testWidgets('stage cleared: the trophy in the medallion, gold not neon', (
    tester,
  ) async {
    final controller = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(milliseconds: 1400),
      value: 1,
    );
    addTearDown(controller.dispose);
    await _show(
      tester,
      SizedBox(
        height: 600,
        child: Stack(
          children: [StageClearOverlay(stage: 7, controller: controller)],
        ),
      ),
    );
    expect(_asset('medallion'), findsOneWidget);
    expect(_asset('icon_trophy'), findsOneWidget);
    expect(_colours(tester).where(_isNeon), isEmpty);
  });
}
