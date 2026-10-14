import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fearflipgame/domain/entities/direction4.dart';
import 'package:fearflipgame/presentation/gameplay/widgets/game_controls.dart';

Finder _asset(String name) => find.byWidgetPredicate(
  (w) =>
      w is Image &&
      w.image is AssetImage &&
      (w.image as AssetImage).assetName == 'assets/images/2d/ui/$name.png',
);

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('ArrowPad', () {
    testWidgets('holding an arm moves that way and presses the stone in', (
      tester,
    ) async {
      final held = <Direction4?>[];
      var ends = 0;
      await tester.pumpWidget(
        _host(ArrowPad(size: 150, onDirection: held.add, onEnd: () => ends++)),
      );
      expect(_asset('dpad'), findsOneWidget);

      final pad = tester.getRect(find.byType(ArrowPad));
      final press = await tester.startGesture(
        pad.centerRight.translate(-pad.width * 0.15, 0),
      );
      await tester.pump();
      expect(held, [Direction4.right]);
      expect(_asset('dpad_pressed'), findsOneWidget);
      // The pressed art's socket is drawn on the up arm: a quarter turn
      // points it right.
      expect(
        tester.widget<RotatedBox>(find.byKey(ArrowPad.artKey)).quarterTurns,
        1,
      );

      await press.up();
      await tester.pump();
      expect(ends, 1);
      expect(_asset('dpad'), findsOneWidget);
    });

    testWidgets('each arm turns the socket its own way', (tester) async {
      final held = <Direction4?>[];
      await tester.pumpWidget(
        _host(ArrowPad(size: 150, onDirection: held.add, onEnd: () {})),
      );
      final pad = tester.getRect(find.byType(ArrowPad));
      final arms = {
        Direction4.up: (pad.topCenter.translate(0, pad.height * 0.15), 0),
        Direction4.down: (pad.bottomCenter.translate(0, -pad.height * 0.15), 2),
        Direction4.left: (pad.centerLeft.translate(pad.width * 0.15, 0), 3),
      };
      for (final MapEntry(key: dir, value: (at, turns)) in arms.entries) {
        final press = await tester.startGesture(at);
        await tester.pump();
        expect(held.last, dir);
        expect(
          tester.widget<RotatedBox>(find.byKey(ArrowPad.artKey)).quarterTurns,
          turns,
        );
        await press.up();
        await tester.pump();
      }
    });
  });

  group('Joystick', () {
    testWidgets('the pearl knob on the bloody base steers', (tester) async {
      final held = <Direction4?>[];
      var ends = 0;
      await tester.pumpWidget(
        _host(Joystick(size: 140, onDirection: held.add, onEnd: () => ends++)),
      );
      expect(_asset('joystick'), findsOneWidget);
      expect(_asset('knob'), findsOneWidget);

      final centre = tester.getCenter(find.byType(Joystick));
      final drag = await tester.startGesture(centre);
      await drag.moveBy(const Offset(40, 0));
      await tester.pump();
      expect(held.last, Direction4.right);

      await drag.up();
      await tester.pump();
      expect(ends, 1);
    });
  });
}
