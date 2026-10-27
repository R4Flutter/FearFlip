import 'package:fearflipgame/arcade/arcade_app.dart';
import 'package:fearflipgame/arcade/platform/portal.dart';
import 'package:fearflipgame/domain/entities/direction4.dart';
import 'package:fearflipgame/presentation/gameplay/pixel_sprites.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('boots straight to the dashboard: no sign-in, no consent wall', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final portal = MemoryPortal();
    await tester.pumpWidget(ArcadeApp(portal: portal));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('PLAY'), findsOneWidget);
    expect(find.text('World Map'), findsOneWidget);
    expect(find.text('Endless Night'), findsOneWidget);
    expect(find.text('Daily Nightmare'), findsOneWidget);
    expect(find.textContaining('Sign'), findsNothing);
    expect(portal.events, contains('finishLoading'));

    // The shop opens and lists the runners.
    await tester.tap(find.text('Shop'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Moss Scout'), findsOneWidget);
    expect(find.text('RUNNERS'), findsOneWidget);
  });

  test('every runner and devil sprite row is 16 pixels wide', () {
    for (final direction in Direction4.values) {
      for (var frame = 0; frame < 3; frame++) {
        final rows = RunnerPixels.rows(direction, frame);
        expect(rows.length, RunnerPixels.height);
        for (final row in rows) {
          expect(row.length, RunnerPixels.width, reason: '$direction $frame "$row"');
        }
      }
    }
    for (final frame in DevilPixels.frames) {
      expect(frame.length, DevilPixels.height);
      for (final row in frame) {
        expect(row.length, DevilPixels.width, reason: row);
      }
    }
  });
}
