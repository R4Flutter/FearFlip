import 'dart:math';

import 'package:fearflipgame/arcade/model/rewards.dart';
import 'package:fearflipgame/game/keys/key_box_planner.dart';
import 'package:fearflipgame/presentation/gameplay/maze_generator.dart';
import 'package:fearflipgame/presentation/gameplay/stage_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Checks the star thresholds against the real mazes: walking the shortest
/// route (plus the key-box detours) must leave enough of the clock for
/// 3 stars with room to spare for a human who has to explore in the dark.
void main() {
  test('3 stars are reachable on every stage, 2 stars comfortably', () {
    final generator = MazeGenerator();
    const planner = KeyBoxPlanner();
    final rows = <String>[];
    for (var stage = 1; stage <= 100; stage++) {
      final rule = StageRules.forStage(stage);
      final size = rule.mazeSize.clamp(10, 17);
      var worstRatio = 0.0;
      for (var seed = 0; seed < 6; seed++) {
        final maze = generator.generate(
          rows: size,
          cols: size,
          seed: stage * 97 + seed,
        );
        final route = maze.shortestPathDistance(maze.start, maze.end) ?? 0;
        var detour = 0;
        if (stage >= 3) {
          final plan = planner.plan(
            maze: maze,
            stage: stage,
            seed: seed,
            avoid: const {},
          );
          // Average case: about two thirds of the boxes are opened before
          // both keys turn up; each box costs walking its side path twice.
          final depths = plan.boxes.map((b) => b.depth).toList();
          final opened = (depths.length * 2 / 3).ceil();
          detour = depths.take(opened).fold(0, (a, d) => a + 2 * d);
        }
        final cellSeconds =
            (120 / rule.playerSpeedMultiplier).round().clamp(60, 260) / 1000;
        final clock = 105 + (stage >= 3 ? 10 : 0);
        final seconds = (route + detour) * cellSeconds;
        worstRatio = max(worstRatio, seconds / clock);
      }
      rows.add(
        'stage $stage maze $size: best-case walk uses ${(worstRatio * 100).round()}% of the clock',
      );
      // A perfect walk must leave the 3-star share with a wide margin, so a
      // player exploring at ~2x the shortest route can still make it.
      expect(
        worstRatio * 2,
        lessThan(1 - StageEconomy.threeStarShare),
        reason: rows.last,
      );
    }
    // ignore: avoid_print
    print(
      rows
          .where(
            (r) =>
                r.contains('stage 1 ') ||
                r.contains('stage 25 ') ||
                r.contains('stage 50 ') ||
                r.contains('stage 100 '),
          )
          .join('\n'),
    );
  });
}
