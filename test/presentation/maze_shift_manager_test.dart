import 'dart:math';

import 'package:fearflipgame/presentation/gameplay/maze_generator.dart';
import 'package:fearflipgame/presentation/gameplay/maze_shift_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MazeShiftManager with key boxes', () {
    test('a shift never cuts off a box the player still needs', () {
      var applied = 0;
      for (var seed = 0; seed < 60; seed++) {
        final maze = MazeGenerator().generate(rows: 12, cols: 12, seed: seed);
        final random = Random(seed);
        final targets = <Point<int>>[
          for (var i = 0; i < 4; i++)
            Point<int>(random.nextInt(12), random.nextInt(12)),
        ]..removeWhere((c) => c == maze.start);
        final manager = MazeShiftManager(random: Random(seed * 7 + 1))
          ..startStage(stage: 6, totalSteps: 60);

        final outcome = manager.triggerMazeShift(
          phase: MazeShiftPhase.midRun,
          maze: maze,
          playerPosition: maze.start,
          exitPosition: maze.end,
          mustReach: targets,
        );
        if (!outcome.applied) continue;
        applied += 1;
        for (final target in targets) {
          expect(
            maze.shortestPathDistance(maze.start, target),
            isNotNull,
            reason: 'seed $seed cut off $target',
          );
        }
      }
      expect(applied, greaterThan(10));
    });

    test('a region never covers protected cells', () {
      // Protect every cell but a 5×5 corner far from the player: the only
      // regions allowed sit inside that corner, so walls elsewhere hold.
      for (var seed = 0; seed < 25; seed++) {
        final maze = MazeGenerator().generate(rows: 12, cols: 12, seed: seed);
        final protectedCells = <Point<int>>{
          for (var y = 0; y < 12; y++)
            for (var x = 0; x < 12; x++)
              if (x < 6 || y < 6) Point<int>(x, y),
        };
        final before = [
          for (var y = 0; y < 5; y++)
            for (var x = 0; x < 5; x++) _walls(maze, x, y),
        ];
        MazeShiftManager(random: Random(seed))
          ..startStage(stage: 6, totalSteps: 60)
          ..triggerMazeShift(
            phase: MazeShiftPhase.midRun,
            maze: maze,
            playerPosition: maze.start,
            exitPosition: maze.end,
            protectedCells: protectedCells,
          );
        final after = [
          for (var y = 0; y < 5; y++)
            for (var x = 0; x < 5; x++) _walls(maze, x, y),
        ];
        expect(after, before, reason: 'seed $seed touched a protected cell');
      }
    });
  });
}

List<bool> _walls(MazeGrid maze, int x, int y) {
  final c = maze.cells[y][x];
  return [c.top, c.right, c.bottom, c.left];
}
