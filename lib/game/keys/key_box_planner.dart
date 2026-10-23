import 'dart:math';

import '../../domain/entities/direction4.dart';
import '../../presentation/gameplay/maze_generator.dart';
import 'key_hunt.dart';

/// How a key hunt is laid out. See docs/retention_features.md.
class KeyHuntBalance {
  const KeyHuntBalance({
    this.boxCount = 5,
    this.keyCount = 2,
    this.keysToUnseal = 2,
    this.firstBand = 0.10,
    this.lastBand = 0.92,
    this.minWalkFromStart = 3,
    this.minSpacing = 2,
  });

  final int boxCount;
  final int keyCount;
  final int keysToUnseal;

  /// Boxes spread along the start→exit route between these fractions of it,
  /// one per equal band, so they turn up as the run goes on.
  final double firstBand;
  final double lastBand;

  /// Steps from the start a box must be, so the first box is never in view
  /// before the run begins.
  final int minWalkFromStart;

  /// Manhattan distance between any two boxes.
  final int minSpacing;

  /// How far boxes may sit off the start→exit route: next to it while players
  /// learn the hunt, deeper in side paths later.
  static int maxDepthForStage(int stage) {
    if (stage <= 10) return 1;
    if (stage <= 25) return 3;
    if (stage <= 50) return 4;
    return 6;
  }
}

/// Places a stage's boxes and decides which ones hold the keys.
///
/// Deterministic for the same maze, stage and seed, so a revive replays the
/// same layout (like traps do).
class KeyBoxPlanner {
  const KeyBoxPlanner({this.balance = const KeyHuntBalance()});

  final KeyHuntBalance balance;

  KeyHuntPlan plan({
    required MazeGrid maze,
    required int stage,
    required int seed,
    Set<Point<int>> avoid = const <Point<int>>{},
  }) {
    final boxCount = balance.boxCount;
    final keyCount = min(balance.keyCount, boxCount);
    if (boxCount <= 0 || keyCount <= 0) {
      return KeyHuntPlan.none;
    }

    final route = _route(maze);
    if (route.length < 3) {
      return KeyHuntPlan.none;
    }

    // Every cell's distance from the route, the route step it hangs off, and
    // the next cell back toward the route.
    final depth = <Point<int>, int>{};
    final attach = <Point<int>, int>{};
    final towardRoute = <Point<int>, Point<int>>{};
    final queue = <Point<int>>[];
    for (var i = 0; i < route.length; i++) {
      depth[route[i]] = 0;
      attach[route[i]] = i;
      queue.add(route[i]);
    }
    var head = 0;
    while (head < queue.length) {
      final current = queue[head++];
      for (final direction in Direction4.values) {
        if (!maze.canMove(current, direction)) {
          continue;
        }
        final next = maze.move(current, direction);
        if (depth.containsKey(next)) {
          continue;
        }
        depth[next] = depth[current]! + 1;
        attach[next] = attach[current]!;
        towardRoute[next] = current;
        queue.add(next);
      }
    }

    final fromStart = _distances(maze, maze.start);
    final maxDepth = KeyHuntBalance.maxDepthForStage(stage);
    final random = Random(seed ^ 0x4B3F ^ (stage * 7919));

    bool isDeadEnd(Point<int> cell) =>
        Direction4.values.where((d) => maze.canMove(cell, d)).length == 1;

    // Deeper first (a side path's end is the natural hiding place), dead
    // ends before corridors, then a seeded shuffle.
    final scores = <Point<int>, double>{};
    final candidates = <Point<int>>[];
    for (final cell in depth.keys) {
      if (cell == maze.start ||
          cell == maze.end ||
          avoid.contains(cell) ||
          depth[cell]! > maxDepth ||
          (fromStart[cell] ?? 0) < balance.minWalkFromStart) {
        continue;
      }
      candidates.add(cell);
    }
    // Sort first so the seeded scores don't depend on map iteration order.
    candidates.sort((a, b) => a.y != b.y ? a.y - b.y : a.x - b.x);
    for (final cell in candidates) {
      scores[cell] =
          depth[cell]! * 10 + (isDeadEnd(cell) ? 5 : 0) + random.nextDouble();
    }

    final picked = <Point<int>>[];
    bool spaced(Point<int> cell) => picked.every(
      (p) => (p.x - cell.x).abs() + (p.y - cell.y).abs() >= balance.minSpacing,
    );
    Point<int>? best(Iterable<Point<int>> pool) {
      Point<int>? top;
      for (final cell in pool) {
        if (!spaced(cell)) {
          continue;
        }
        if (top == null || scores[cell]! > scores[top]!) {
          top = cell;
        }
      }
      return top;
    }

    final length = route.length - 1;
    final span = balance.lastBand - balance.firstBand;
    for (var band = 0; band < boxCount; band++) {
      final lo = (length * (balance.firstBand + span * band / boxCount))
          .floor();
      final hi = (length * (balance.firstBand + span * (band + 1) / boxCount))
          .floor();
      final choice = best(
        candidates.where((c) => attach[c]! >= lo && attach[c]! <= hi),
      );
      if (choice != null) {
        picked.add(choice);
      }
    }
    // A band with no room: take the best spot left anywhere.
    while (picked.length < boxCount) {
      final choice = best(candidates.where((c) => !picked.contains(c)));
      if (choice == null) {
        break;
      }
      picked.add(choice);
    }
    if (picked.length < keyCount) {
      return KeyHuntPlan.none;
    }

    picked.sort((a, b) => attach[a]!.compareTo(attach[b]!));
    final order = List<int>.generate(picked.length, (i) => i)..shuffle(random);
    final keyed = order.take(keyCount).toSet();

    final reserved = <Point<int>>{...route};
    final boxes = <KeyBox>[];
    for (var i = 0; i < picked.length; i++) {
      final cell = picked[i];
      final sidePath = <Point<int>>[cell];
      var cursor = cell;
      while (depth[cursor]! > 0) {
        cursor = towardRoute[cursor]!;
        sidePath.add(cursor);
      }
      reserved.addAll(sidePath);
      boxes.add(
        KeyBox(
          cell: cell,
          hasKey: keyed.contains(i),
          depth: depth[cell]!,
          sidePath: List<Point<int>>.unmodifiable(sidePath),
        ),
      );
    }

    return KeyHuntPlan(
      boxes: List<KeyBox>.unmodifiable(boxes),
      keysRequired: balance.keysToUnseal.clamp(1, keyCount),
      reservedCells: Set<Point<int>>.unmodifiable(reserved),
    );
  }

  static List<Point<int>> _route(MazeGrid maze) {
    final parents = <Point<int>, Point<int>?>{maze.start: null};
    final queue = <Point<int>>[maze.start];
    var head = 0;
    while (head < queue.length) {
      final current = queue[head++];
      if (current == maze.end) {
        break;
      }
      for (final direction in Direction4.values) {
        if (!maze.canMove(current, direction)) {
          continue;
        }
        final next = maze.move(current, direction);
        if (parents.containsKey(next)) {
          continue;
        }
        parents[next] = current;
        queue.add(next);
      }
    }
    if (!parents.containsKey(maze.end)) {
      return const <Point<int>>[];
    }
    final path = <Point<int>>[];
    Point<int>? cursor = maze.end;
    while (cursor != null) {
      path.add(cursor);
      cursor = parents[cursor];
    }
    return path.reversed.toList(growable: false);
  }

  static Map<Point<int>, int> _distances(MazeGrid maze, Point<int> from) {
    final distances = <Point<int>, int>{from: 0};
    final queue = <Point<int>>[from];
    var head = 0;
    while (head < queue.length) {
      final current = queue[head++];
      for (final direction in Direction4.values) {
        if (!maze.canMove(current, direction)) {
          continue;
        }
        final next = maze.move(current, direction);
        if (distances.containsKey(next)) {
          continue;
        }
        distances[next] = distances[current]! + 1;
        queue.add(next);
      }
    }
    return distances;
  }
}
