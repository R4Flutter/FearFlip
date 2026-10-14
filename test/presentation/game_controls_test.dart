import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fearflipgame/domain/entities/direction4.dart';
import 'package:fearflipgame/presentation/gameplay/widgets/game_controls.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    backgroundColor: Colors.black,
    body: Center(child: child),
  ),
);

/// Fill opacity of a d-pad arm.
double _armFill(WidgetTester tester, Direction4 dir) =>
    (tester.widget<Container>(find.byKey(ArrowPad.armKey(dir))).decoration!
            as BoxDecoration)
        .color!
        .a;

void main() {
  group('ArrowPad', () {
    testWidgets('see-through, drawn in code: no images', (tester) async {
      await tester.pumpWidget(
        _host(ArrowPad(size: 150, onDirection: (_) {}, onEnd: () {})),
      );
      expect(find.byType(Image), findsNothing);
      for (final dir in Direction4.values) {
        expect(_armFill(tester, dir), lessThan(0.25)); // the maze shows through
      }
    });

    testWidgets('holding an arm moves that way and lights that arm up', (
      tester,
    ) async {
      final held = <Direction4?>[];
      var ends = 0;
      await tester.pumpWidget(
        _host(ArrowPad(size: 150, onDirection: held.add, onEnd: () => ends++)),
      );
      final idle = _armFill(tester, Direction4.right);

      final press = await tester.startGesture(
        tester.getCenter(find.byKey(ArrowPad.armKey(Direction4.right))),
      );
      await tester.pump();
      expect(held, [Direction4.right]);
      expect(_armFill(tester, Direction4.right), greaterThan(idle));
      expect(_armFill(tester, Direction4.left), idle);

      await press.up();
      await tester.pump();
      expect(ends, 1);
      expect(_armFill(tester, Direction4.right), idle);
    });

    testWidgets('every arm steers its own way', (tester) async {
      final held = <Direction4?>[];
      await tester.pumpWidget(
        _host(ArrowPad(size: 150, onDirection: held.add, onEnd: () {})),
      );
      for (final dir in Direction4.values) {
        await tester.tap(find.byKey(ArrowPad.armKey(dir)));
        expect(held.last, dir);
      }
    });
  });

  group('Joystick', () {
    testWidgets('see-through, drawn in code; the knob follows the thumb', (
      tester,
    ) async {
      final held = <Direction4?>[];
      var ends = 0;
      await tester.pumpWidget(
        _host(Joystick(size: 140, onDirection: held.add, onEnd: () => ends++)),
      );
      expect(find.byType(Image), findsNothing);
      final centre = tester.getCenter(find.byType(Joystick));
      expect(tester.getCenter(find.byKey(Joystick.knobKey)), centre);

      final drag = await tester.startGesture(centre);
      await drag.moveBy(const Offset(40, 0));
      await tester.pump();
      expect(held.last, Direction4.right);
      expect(
        tester.getCenter(find.byKey(Joystick.knobKey)).dx,
        greaterThan(centre.dx),
      );

      await drag.up();
      await tester.pump();
      expect(ends, 1);
      expect(tester.getCenter(find.byKey(Joystick.knobKey)), centre);
    });
  });
}
