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
          expect(
            row.length,
            RunnerPixels.width,
            reason: '$direction $frame "$row"',
          );
        }
      }
    }
    for (final facing in Direction4.values) {
      for (var frame = 0; frame < 3; frame++) {
        final rows = DevilPixels.rows(facing, frame);
        expect(rows.length, DevilPixels.height);
        for (final row in rows) {
          expect(
            row.length,
            DevilPixels.width,
            reason: '$facing $frame "$row"',
          );
        }
      }
    }
  });

  test('the Devil walks: its frames differ, and its eyes are where '
      'the sprite draws them', () {
    for (final facing in Direction4.values) {
      final frames = [
        for (var f = 0; f < 3; f++) DevilPixels.rows(facing, f).join(),
      ];
      expect(frames.toSet().length, 3, reason: '$facing');
      final rows = DevilPixels.rows(facing, 0);
      for (final eye in DevilPixels.eyes(facing)) {
        // The glow sits on the eye pixels just up-left of its centre.
        expect(
          rows[eye.dy.toInt() - 1][eye.dx.toInt() - 1],
          'R',
          reason: '$facing $eye',
        );
      }
    }
    // Facing right is facing left in a mirror.
    expect(
      DevilPixels.rows(Direction4.right, 1),
      DevilPixels.rows(
        Direction4.left,
        1,
      ).map((r) => r.split('').reversed.join()).toList(),
    );
  });
}
