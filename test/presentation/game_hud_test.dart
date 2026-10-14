import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fearflipgame/presentation/gameplay/widgets/game_hud.dart';

Finder _asset(String name) => find.byWidgetPredicate(
  (w) =>
      w is Image &&
      w.image is AssetImage &&
      (w.image as AssetImage).assetName == 'assets/images/2d/ui/$name.png',
);

Future<void> _pump(
  WidgetTester tester, {
  int stage = 27,
  int checkpoint = 25,
  int remaining = 80,
  int total = 105,
  bool paused = false,
  int lives = -1,
  int maxLives = 0,
  VoidCallback? onPause,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 200,
        child: GameHud(
          stage: stage,
          checkpoint: checkpoint,
          remainingSeconds: remaining,
          totalSeconds: total,
          isPaused: paused,
          onPauseTap: onPause ?? () {},
          livesRemaining: lives,
          maxLives: maxLives,
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('stage and checkpoint are icons and numbers, no word labels', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('27'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
    expect(_asset('icon_maze'), findsOneWidget);
    expect(_asset('icon_flag'), findsOneWidget);
    for (final word in ['STAGE', 'CHECKPOINT', 'TIME']) {
      expect(find.text(word), findsNothing);
    }
  });

  testWidgets('before the first checkpoint there is no flag', (tester) async {
    await _pump(tester, stage: 3, checkpoint: 0);
    expect(_asset('icon_flag'), findsNothing);
  });

  testWidgets('lives show as full and empty hearts, none when unlimited', (
    tester,
  ) async {
    await _pump(tester, lives: 2, maxLives: 3);
    expect(_asset('icon_heart'), findsNWidgets(2));
    expect(_asset('icon_heart_empty'), findsOneWidget);

    await _pump(tester);
    expect(_asset('icon_heart'), findsNothing);
  });

  testWidgets('the hourglass bar drains with the clock', (tester) async {
    await _pump(tester, remaining: 21, total: 105);
    expect(tester.widget<TimeBar>(find.byType(TimeBar)).fraction, 0.2);
    expect(find.text('21'), findsOneWidget);
  });

  testWidgets('the last ten seconds turn the time red', (tester) async {
    await _pump(tester, remaining: 9);
    expect(tester.widget<Text>(find.text('09')).style!.color, NightHud.blood);
    expect(tester.widget<TimeBar>(find.byType(TimeBar)).panic, isTrue);
  });

  testWidgets('the stone button pauses, and looks pressed while paused', (
    tester,
  ) async {
    var taps = 0;
    await _pump(tester, onPause: () => taps++);
    expect(_asset('button'), findsOneWidget);
    await tester.tap(find.byKey(GameHud.pauseKey));
    expect(taps, 1);

    await _pump(tester, paused: true);
    expect(_asset('button_pressed'), findsOneWidget);
  });
}
