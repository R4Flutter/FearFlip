import 'dart:math';

import 'package:fearflipgame/game/trap/trap_state_controller.dart';
import 'package:fearflipgame/game/trap/trap_tile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TrapStateController', () {
    test('first step reveals and cracks a hidden trap tile', () {
      final controller = TrapStateController();
      final tile = TrapTile(cell: const Point<int>(2, 3), crackSeed: 77);
      controller.reset(<TrapTile>[tile]);

      final result = controller.onPlayerStep(
        const Point<int>(2, 3),
        playerStepCount: 9,
      );

      expect(result, TrapStepResult.trapRevealed);
      expect(tile.state, TrapState.cracked);
      expect(tile.revealedAtStep, 9);
    });

    test(
      'second step on the same trap collapses it and future steps are inert',
      () {
        final controller = TrapStateController();
        final tile = TrapTile(cell: const Point<int>(4, 1), crackSeed: 11);
        controller.reset(<TrapTile>[tile]);

        final firstStep = controller.onPlayerStep(
          const Point<int>(4, 1),
          playerStepCount: 2,
        );
        final secondStep = controller.onPlayerStep(
          const Point<int>(4, 1),
          playerStepCount: 3,
        );
        final thirdStep = controller.onPlayerStep(
          const Point<int>(4, 1),
          playerStepCount: 4,
        );

        expect(firstStep, TrapStepResult.trapRevealed);
        expect(secondStep, TrapStepResult.trapCollapsed);
        expect(tile.state, TrapState.collapsed);
        expect(thirdStep, TrapStepResult.noTrap);
      },
    );

    test('cracked trap escalates to critical when player is adjacent', () {
      final controller = TrapStateController();
      final tile = TrapTile(cell: const Point<int>(5, 5), crackSeed: 123)
        ..state = TrapState.cracked;
      controller.reset(<TrapTile>[tile]);

      TrapTile? criticalTile;
      controller.onCriticalTrigger = (triggeredTile) {
        criticalTile = triggeredTile;
      };

      controller.update(0.16, const Point<int>(5, 4), criticalDistance: 1);

      expect(tile.state, TrapState.critical);
      expect(criticalTile, same(tile));
      expect(tile.pulsePhase, 0);
      expect(tile.particlePhase, greaterThan(0));
    });

    test('hidden trap fires one suspicion cue while player is nearby', () {
      final controller = TrapStateController();
      final tile = TrapTile(cell: const Point<int>(2, 2), crackSeed: 91);
      controller.reset(<TrapTile>[tile]);

      var cueCount = 0;
      controller.onHiddenSuspicionCue = (_) {
        cueCount += 1;
      };

      controller.update(0.16, const Point<int>(2, 1), hiddenCueLevel: 1);
      controller.update(0.16, const Point<int>(1, 2), hiddenCueLevel: 1);

      expect(cueCount, 1);

      controller.update(0.16, const Point<int>(6, 6), hiddenCueLevel: 1);
      controller.update(0.16, const Point<int>(2, 1), hiddenCueLevel: 1);

      expect(cueCount, 2);
    });
  });
}
