import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fearflipgame/presentation/gameplay/game_screen.dart';
import 'package:fearflipgame/presentation/gameplay/widgets/game_hud.dart';

void main() {
  testWidgets('the maze fills the whole screen, no box around it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2340, 1080); // a landscape phone
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: GameScreen()));
    expect(
      tester.getSize(find.byKey(GameScreen.gameSurfaceKey)),
      tester.view.physicalSize / tester.view.devicePixelRatio,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a run plays in landscape; leaving it returns to portrait', (
    tester,
  ) async {
    final orientations = <Object?>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') {
        orientations.add(call.arguments);
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(const MaterialApp(home: GameScreen()));
    expect(orientations.last, [
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight',
    ]);

    await tester.pumpWidget(
      const MaterialApp(home: GameScreen(isActive: false)),
    );
    expect(orientations.last, [
      'DeviceOrientation.portraitUp',
      'DeviceOrientation.portraitDown',
    ]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('in landscape the pause box fits: both buttons on screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2340, 1080);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final screen = Offset.zero & (tester.view.physicalSize / 2.625);

    await tester.pumpWidget(const MaterialApp(home: GameScreen()));
    await tester.tap(find.byKey(GameHud.pauseKey));
    await tester.pump(); // the box appears...
    await tester.pump(const Duration(seconds: 1)); // ...and finishes growing
    for (final label in ['RESUME SURVIVAL', 'ABANDON RUN']) {
      final rect = tester.getRect(find.text(label));
      expect(rect.height, greaterThan(0), reason: label);
      expect(screen.contains(rect.topLeft), isTrue, reason: label);
      expect(screen.contains(rect.bottomRight), isTrue, reason: label);
    }
    await tester.pumpWidget(const SizedBox());
  });
}
