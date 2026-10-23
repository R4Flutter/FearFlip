import 'dart:math';

import 'package:fearflipgame/domain/entities/direction4.dart';
import 'package:fearflipgame/game/keys/key_box_planner.dart';
import 'package:fearflipgame/game/keys/key_hunt.dart';
import 'package:fearflipgame/game/trap/trap_placement_engine.dart';
import 'package:fearflipgame/presentation/gameplay/maze_generator.dart';
import 'package:flutter_test/flutter_test.dart';

/// The start→exit route, by BFS.
List<Point<int>> _route(MazeGrid maze) {
  final parents = <Point<int>, Point<int>?>{maze.start: null};
  final queue = <Point<int>>[maze.start];
  for (var i = 0; i < queue.length; i++) {
    for (final d in Direction4.values) {
      if (!maze.canMove(queue[i], d)) continue;
      final next = maze.move(queue[i], d);
      if (parents.containsKey(next)) continue;
      parents[next] = queue[i];
      queue.add(next);
    }
  }
  final path = <Point<int>>[];
  Point<int>? cursor = maze.end;
  while (cursor != null) {
    path.add(cursor);
    cursor = parents[cursor];
  }
  return path.reversed.toList();
}

bool _adjacentAndOpen(MazeGrid maze, Point<int> a, Point<int> b) =>
    Direction4.values.any((d) => maze.canMove(a, d) && maze.move(a, d) == b);

void main() {
  const planner = KeyBoxPlanner();

  group('KeyBoxPlanner', () {
    test('places 5 boxes, 2 of them keys, on distinct reachable cells', () {
      for (final seed in [1, 2, 3, 42, 777, 2026]) {
        final maze = MazeGenerator().generate(rows: 14, cols: 14, seed: seed);
        final plan = planner.plan(maze: maze, stage: 12, seed: seed);

        expect(plan.isActive, isTrue);
        expect(plan.boxes, hasLength(5));
        expect(plan.boxes.where((b) => b.hasKey), hasLength(2));
        expect(plan.keysRequired, 2);
        expect(plan.boxes.map((b) => b.cell).toSet(), hasLength(5));
        for (final box in plan.boxes) {
          expect(box.cell, isNot(maze.start));
          expect(box.cell, isNot(maze.end));
          final walk = maze.shortestPathDistance(maze.start, box.cell);
          expect(walk, isNotNull, reason: 'box ${box.cell} unreachable');
          expect(walk!, greaterThanOrEqualTo(3));
        }
      }
    });

    test('keeps boxes beside the route early and hides them deeper later', () {
      var deepLate = 0;
      for (final seed in List<int>.generate(12, (i) => i + 1)) {
        final maze = MazeGenerator().generate(rows: 17, cols: 17, seed: seed);
        final early = planner.plan(maze: maze, stage: 5, seed: seed);
        expect(early.boxes.every((b) => b.depth <= 1), isTrue);

        final late = planner.plan(maze: maze, stage: 60, seed: seed);
        expect(late.boxes.every((b) => b.depth <= 6), isTrue);
        deepLate += late.boxes.where((b) => b.depth > 1).length;
      }
      expect(deepLate, greaterThan(0));
    });

    test('never uses avoided cells (the safe zones)', () {
      final maze = MazeGenerator().generate(rows: 12, cols: 12, seed: 9);
      final route = _route(maze);
      final avoid = {for (var i = 2; i < route.length - 2; i++) route[i]};
      final plan = planner.plan(maze: maze, stage: 4, seed: 9, avoid: avoid);
      for (final box in plan.boxes) {
        expect(avoid.contains(box.cell), isFalse);
      }
    });

    test('is deterministic for the same maze and seed', () {
      final maze = MazeGenerator().generate(rows: 15, cols: 15, seed: 31);
      final a = planner.plan(maze: maze, stage: 30, seed: 5);
      final b = planner.plan(maze: maze, stage: 30, seed: 5);
      expect(
        a.boxes.map((x) => x.cell),
        orderedEquals(b.boxes.map((x) => x.cell)),
      );
      expect(
        a.boxes.map((x) => x.hasKey),
        orderedEquals(b.boxes.map((x) => x.hasKey)),
      );
    });

    test('spreads the boxes along the route', () {
      final maze = MazeGenerator().generate(rows: 17, cols: 17, seed: 12);
      final route = _route(maze);
      final plan = planner.plan(maze: maze, stage: 20, seed: 12);
      int attach(KeyBox box) => route.indexOf(box.sidePath.last);
      final first = attach(plan.boxes.first);
      final last = attach(plan.boxes.last);
      expect(first, lessThan(route.length ~/ 2));
      expect(last, greaterThan(route.length ~/ 2));
    });

    test('each side path walks from its box back to the route', () {
      final maze = MazeGenerator().generate(rows: 17, cols: 17, seed: 4);
      final route = _route(maze).toSet();
      final plan = planner.plan(maze: maze, stage: 70, seed: 4);
      for (final box in plan.boxes) {
        expect(box.sidePath.first, box.cell);
        expect(route.contains(box.sidePath.last), isTrue);
        expect(box.sidePath, hasLength(box.depth + 1));
        for (var i = 1; i < box.sidePath.length; i++) {
          expect(
            _adjacentAndOpen(maze, box.sidePath[i - 1], box.sidePath[i]),
            isTrue,
          );
        }
        expect(plan.reservedCells.containsAll(box.sidePath), isTrue);
      }
      expect(plan.reservedCells.containsAll(route), isTrue);
    });

    test('traps never land on the routes to the boxes or the exit', () {
      const engine = TrapPlacementEngine();
      for (final seed in [3, 8, 21, 55]) {
        final maze = MazeGenerator().generate(rows: 17, cols: 17, seed: seed);
        final plan = planner.plan(maze: maze, stage: 45, seed: seed);
        final traps = engine.placeTiles(
          maze: maze,
          stage: 45,
          seed: seed,
          reservedCells: plan.reservedCells,
        );
        for (final trap in traps) {
          expect(plan.reservedCells.contains(trap.cell), isFalse);
        }
      }
    });

    test('a balance with more keys than boxes stays sane', () {
      final maze = MazeGenerator().generate(rows: 12, cols: 12, seed: 2);
      const odd = KeyBoxPlanner(
        balance: KeyHuntBalance(boxCount: 3, keyCount: 5, keysToUnseal: 9),
      );
      final plan = odd.plan(maze: maze, stage: 10, seed: 2);
      expect(plan.boxes, hasLength(3));
      expect(plan.boxes.every((b) => b.hasKey), isTrue);
      expect(plan.keysRequired, 3);
    });
  });
}
