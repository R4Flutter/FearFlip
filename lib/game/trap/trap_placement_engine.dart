import 'dart:math';

import '../../presentation/gameplay/maze_generator.dart';
import 'trap_difficulty_scaler.dart';
import 'trap_tile.dart';

/// Analyses maze topology and places fragile trap tiles using weighted
/// randomness with hard anti-frustration constraints.
class TrapPlacementEngine {
  const TrapPlacementEngine();

  /// Returns a list of [TrapTile]s placed within [maze] for the given [stage].
  ///
  /// The [seed] must match the maze-generation seed so crack patterns are
  /// deterministic across restarts of the same level.
  List<TrapTile> placeTiles({
    required MazeGrid maze,
    required int stage,
    required int seed,
    TrapBalanceConfig config = const TrapBalanceConfig(),
  }) {
    final scaler = TrapDifficultyScaler(config: config);
    final walkable = _allWalkableCells(maze);
    final stageConfig = scaler.configForStage(
      stage: stage,
      walkableCellCount: walkable.length,
    );

    if (!stageConfig.trapsEnabled || stageConfig.trapCount <= 0) {
      return const <TrapTile>[];
    }

    final random = Random(seed ^ 0x7A4D); // salt for trap-specific randomness
    final topologyMap = _classifyCells(
      maze: maze,
      walkable: walkable,
      config: config,
    );

    final shortestPath = _shortestPath(maze, maze.start, maze.end);
    final protectedCells = _buildProtectedSet(
      maze: maze,
      shortestPath: shortestPath,
      config: config,
    );

    // Weight and sort eligible cells.
    final candidates = <_WeightedCell>[];
    for (final cell in walkable) {
      if (protectedCells.contains(cell)) continue;
      final topo = topologyMap[cell] ?? TileTopology.corridor;
      if (topo == TileTopology.deadEnd) continue;
      if (topo == TileTopology.nearStart) continue;
      if (topo == TileTopology.nearGoal) continue;
      if (topo == TileTopology.chokepoint && !stageConfig.allowChokepoints) {
        continue;
      }

      candidates.add(_WeightedCell(cell: cell, topology: topo));
    }

    if (candidates.isEmpty) return const <TrapTile>[];

    // Weighted selection with constraint enforcement.
    _assignWeights(candidates, random);
    candidates.sort((a, b) => b.weight.compareTo(a.weight));

    final placed = <Point<int>>[];
    final chosen = <TrapTile>[];

    for (final c in candidates) {
      if (chosen.length >= stageConfig.trapCount) break;

      // No two traps adjacent (Manhattan >= 2).
      if (placed.any((p) => _manhattan(p, c.cell) < 2)) continue;

      placed.add(c.cell);
      chosen.add(TrapTile(
        cell: c.cell,
        crackSeed: _tileSeed(c.cell, seed),
        topology: c.topology,
      ));
    }

    // Safety: verify at least one trap-free path exists.
    if (chosen.isNotEmpty && !_trapFreePathExists(maze, chosen)) {
      // Remove the last-placed trap until a safe path exists.
      while (chosen.isNotEmpty && !_trapFreePathExists(maze, chosen)) {
        chosen.removeLast();
      }
    }

    return chosen;
  }

  // ── topology analysis ──────────────────────────────────────────────

  List<Point<int>> _allWalkableCells(MazeGrid maze) {
    final cells = <Point<int>>[];
    for (var y = 0; y < maze.rows; y++) {
      for (var x = 0; x < maze.cols; x++) {
        final cell = Point<int>(x, y);
        if (_neighborCount(maze, cell) > 0 || cell == maze.start) {
          cells.add(cell);
        }
      }
    }
    return cells;
  }

  Map<Point<int>, TileTopology> _classifyCells({
    required MazeGrid maze,
    required List<Point<int>> walkable,
    required TrapBalanceConfig config,
  }) {
    final result = <Point<int>, TileTopology>{};

    // Find dead-end cells and their entrances.
    final deadEnds = <Point<int>>{};
    final deadEndEntrances = <Point<int>>{};
    for (final cell in walkable) {
      final nc = _neighborCount(maze, cell);
      if (nc == 1) {
        deadEnds.add(cell);
        final neighbor = _neighbors(maze, cell).first;
        deadEndEntrances.add(neighbor);
      }
    }

    for (final cell in walkable) {
      final dist = _manhattan(cell, maze.start);
      if (dist <= config.nearStartProtectionRadius) {
        result[cell] = TileTopology.nearStart;
        continue;
      }
      final goalDist = _manhattan(cell, maze.end);
      if (goalDist <= config.nearGoalProtectionRadius) {
        result[cell] = TileTopology.nearGoal;
        continue;
      }
      if (deadEnds.contains(cell)) {
        result[cell] = TileTopology.deadEnd;
        continue;
      }
      if (deadEndEntrances.contains(cell)) {
        result[cell] = TileTopology.deadEndEntrance;
        continue;
      }

      final nc = _neighborCount(maze, cell);
      if (nc >= 4) {
        result[cell] = TileTopology.crossroads;
      } else if (nc == 3) {
        result[cell] = TileTopology.tJunction;
      } else {
        result[cell] = TileTopology.corridor;
      }
    }

    return result;
  }

  // ── weight assignment ──────────────────────────────────────────────

  static const _topoWeights = <TileTopology, double>{
    TileTopology.tJunction: 0.40,
    TileTopology.deadEndEntrance: 0.35,
    TileTopology.loopNode: 0.30,
    TileTopology.chokepoint: 0.20,
    TileTopology.corridor: 0.10,
    TileTopology.crossroads: 0.05,
  };

  void _assignWeights(List<_WeightedCell> cells, Random random) {
    for (final c in cells) {
      final base = _topoWeights[c.topology] ?? 0.05;
      // Add small random jitter to prevent deterministic tie-breaking
      c.weight = base + random.nextDouble() * 0.08;
    }
  }

  // ── constraint helpers ─────────────────────────────────────────────

  Set<Point<int>> _buildProtectedSet({
    required MazeGrid maze,
    required List<Point<int>> shortestPath,
    required TrapBalanceConfig config,
  }) {
    final protectedSet = <Point<int>>{};

    // Protect near-start cells.
    for (var y = 0; y < maze.rows; y++) {
      for (var x = 0; x < maze.cols; x++) {
        final cell = Point<int>(x, y);
        if (_manhattan(cell, maze.start) <= config.nearStartProtectionRadius) {
          protectedSet.add(cell);
        }
        if (_manhattan(cell, maze.end) <= config.nearGoalProtectionRadius) {
          protectedSet.add(cell);
        }
      }
    }

    // Protect first 30% of shortest path.
    if (shortestPath.isNotEmpty) {
      final protectCount = (shortestPath.length * 0.30).ceil();
      for (var i = 0; i < protectCount && i < shortestPath.length; i++) {
        protectedSet.add(shortestPath[i]);
      }
    }

    return protectedSet;
  }

  /// Verifies that at least one path from start→goal avoids all given traps.
  bool _trapFreePathExists(MazeGrid maze, List<TrapTile> traps) {
    final trapCells = traps.map((t) => t.cell).toSet();
    final start = maze.start;
    final goal = maze.end;
    if (trapCells.contains(start) || trapCells.contains(goal)) return false;

    final visited = <Point<int>>{start};
    final queue = <Point<int>>[start];
    var index = 0;

    while (index < queue.length) {
      final current = queue[index++];
      if (current == goal) return true;

      for (final dir in Direction4.values) {
        if (!maze.canMove(current, dir)) continue;
        final next = maze.move(current, dir);
        if (visited.contains(next) || trapCells.contains(next)) continue;
        visited.add(next);
        queue.add(next);
      }
    }

    return false;
  }

  /// BFS shortest path from [from] to [to].
  List<Point<int>> _shortestPath(MazeGrid maze, Point<int> from, Point<int> to) {
    final parent = <Point<int>, Point<int>?>{from: null};
    final queue = <Point<int>>[from];
    var index = 0;

    while (index < queue.length) {
      final current = queue[index++];
      if (current == to) break;

      for (final dir in Direction4.values) {
        if (!maze.canMove(current, dir)) continue;
        final next = maze.move(current, dir);
        if (parent.containsKey(next)) continue;
        parent[next] = current;
        queue.add(next);
      }
    }

    if (!parent.containsKey(to)) return const <Point<int>>[];

    final path = <Point<int>>[];
    Point<int>? cursor = to;
    while (cursor != null) {
      path.add(cursor);
      cursor = parent[cursor];
    }
    return path.reversed.toList();
  }

  // ── maze helpers ───────────────────────────────────────────────────

  int _neighborCount(MazeGrid maze, Point<int> cell) {
    var count = 0;
    for (final dir in Direction4.values) {
      if (maze.canMove(cell, dir)) count++;
    }
    return count;
  }

  List<Point<int>> _neighbors(MazeGrid maze, Point<int> cell) {
    final result = <Point<int>>[];
    for (final dir in Direction4.values) {
      if (maze.canMove(cell, dir)) result.add(maze.move(cell, dir));
    }
    return result;
  }

  int _manhattan(Point<int> a, Point<int> b) {
    return (a.x - b.x).abs() + (a.y - b.y).abs();
  }

  int _tileSeed(Point<int> cell, int mazeSeed) {
    return cell.x * 7919 + cell.y * 104729 + mazeSeed;
  }
}

// ── internal helpers ───────────────────────────────────────────────────

class _WeightedCell {
  _WeightedCell({required this.cell, required this.topology});

  final Point<int> cell;
  final TileTopology topology;
  double weight = 0;
}
