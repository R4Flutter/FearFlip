import 'dart:math';

import 'package:fearflipgame/game/trap/trap_difficulty_scaler.dart';
import 'package:fearflipgame/game/trap/trap_placement_engine.dart';
import 'package:fearflipgame/game/trap/trap_tile.dart';
import 'package:fearflipgame/presentation/gameplay/maze_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TrapPlacementEngine', () {
    test(
      'places fair traps in a perfect maze instead of deleting them all',
      () {
        final maze = MazeGenerator().generate(rows: 10, cols: 10, seed: 1234);
        const engine = TrapPlacementEngine();

        final traps = engine.placeTiles(
          maze: maze,
          stage: 20,
          seed: 9876,
          config: const TrapBalanceConfig(maxTrapCount: 6),
        );

        expect(traps, isNotEmpty);
        expect(traps.length, lessThanOrEqualTo(6));
        expect(traps.any((trap) => trap.cell == maze.start), isFalse);
        expect(traps.any((trap) => trap.cell == maze.end), isFalse);
        expect(
          traps.every((trap) => trap.topology != TileTopology.deadEnd),
          isTrue,
        );
      },
    );

    test('is deterministic for the same maze and trap seed', () {
      final maze = MazeGenerator().generate(rows: 12, cols: 12, seed: 77);
      const engine = TrapPlacementEngine();

      final a = engine.placeTiles(maze: maze, stage: 35, seed: 44);
      final b = engine.placeTiles(maze: maze, stage: 35, seed: 44);

      expect(
        a.map((trap) => trap.cell),
        orderedEquals(b.map((trap) => trap.cell)),
      );
      expect(a.map(_tagSignature), orderedEquals(b.map(_tagSignature)));
    });

    test('respects mobile readability spacing constraints', () {
      final maze = MazeGenerator().generate(rows: 14, cols: 14, seed: 222);
      const engine = TrapPlacementEngine();

      final traps = engine.placeTiles(
        maze: maze,
        stage: 65,
        seed: 333,
        config: const TrapBalanceConfig(maxTrapCount: 10, minTrapSpacing: 2),
      );

      for (var i = 0; i < traps.length; i++) {
        for (var j = i + 1; j < traps.length; j++) {
          expect(
            _manhattan(traps[i].cell, traps[j].cell),
            greaterThanOrEqualTo(2),
          );
        }
      }
    });
  });
}

String _tagSignature(TrapTile trap) {
  final names = trap.pressureTags.map((tag) => tag.name).toList()..sort();
  return names.join('|');
}

int _manhattan(Point<int> a, Point<int> b) {
  return (a.x - b.x).abs() + (a.y - b.y).abs();
}
