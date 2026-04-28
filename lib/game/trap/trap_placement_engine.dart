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
  /// The placement goal is not "random damage". It is memory pressure:
  /// traps prefer decision forks, return paths, branch entrances, and late
  /// panic routes while preserving a clean first-pass route to the goal.
  List<TrapTile> placeTiles({
    required MazeGrid maze,
    required int stage,
    required int seed,
    TrapBalanceConfig config = const TrapBalanceConfig(),
  }) {
    final walkable = _allWalkableCells(maze);
    final scaler = TrapDifficultyScaler(config: config);
    final stageConfig = scaler.configForStage(
      stage: stage,
      walkableCellCount: walkable.length,
    );

    if (!stageConfig.trapsEnabled || stageConfig.trapCount <= 0) {
      return const <TrapTile>[];
    }

    final analysis = _analyzeMaze(
      maze: maze,
      walkable: walkable,
      config: config,
    );
    final random = Random(seed ^ 0x7A4D ^ (stage * 9973));
    final protectedCells = _buildProtectedSet(
      analysis: analysis,
      config: config,
      stageConfig: stageConfig,
    );

    final candidates = <_WeightedCell>[];
    for (final cell in analysis.walkable) {
      if (protectedCells.contains(cell)) continue;
      final candidate = _buildCandidate(
        cell: cell,
        analysis: analysis,
        stageConfig: stageConfig,
        random: random,
      );
      if (candidate != null) {
        candidates.add(candidate);
      }
    }

    if (candidates.isEmpty) return const <TrapTile>[];

    final maxTrapCount = config.maxTrapCount <= 0
        ? stageConfig.trapCount
        : config.maxTrapCount;
    final targetTrapCount = min(stageConfig.trapCount, maxTrapCount);

    final chosen = <TrapTile>[];
    final placedCells = <Point<int>>{};
    final preferredTarget = _preferredTjunctionTarget(
      targetCount: targetTrapCount,
      availablePreferred: candidates
          .where((c) => c.topology == TileTopology.tJunction)
          .length,
      ratio: config.preferredTJunctionRatio,
    );

    _selectTiles(
      candidates: candidates
          .where((c) => c.topology == TileTopology.tJunction)
          .toList(),
      targetCount: preferredTarget,
      chosen: chosen,
      placedCells: placedCells,
      stageConfig: stageConfig,
      random: random,
      seed: seed,
    );

    if (chosen.length < targetTrapCount) {
      _selectTiles(
        candidates: candidates,
        targetCount: targetTrapCount,
        chosen: chosen,
        placedCells: placedCells,
        stageConfig: stageConfig,
        random: random,
        seed: seed,
      );
    }

    if (chosen.isNotEmpty && !_safeFirstPassRouteExists(maze, chosen)) {
      chosen.sort((a, b) => a.placementScore.compareTo(b.placementScore));
      while (chosen.isNotEmpty && !_safeFirstPassRouteExists(maze, chosen)) {
        chosen.removeAt(0);
      }
    }

    chosen.sort((a, b) {
      final aIndex = a.pathIndex ?? 1 << 20;
      final bIndex = b.pathIndex ?? 1 << 20;
      return aIndex.compareTo(bIndex);
    });
    return chosen;
  }

  _MazeTrapAnalysis _analyzeMaze({
    required MazeGrid maze,
    required List<Point<int>> walkable,
    required TrapBalanceConfig config,
  }) {
    final neighbors = <Point<int>, List<Point<int>>>{};
    for (final cell in walkable) {
      neighbors[cell] = _neighbors(maze, cell);
    }

    final shortestPath = _shortestPath(maze, maze.start, maze.end);
    final shortestPathIndex = <Point<int>, int>{};
    for (var i = 0; i < shortestPath.length; i++) {
      shortestPathIndex[shortestPath[i]] = i;
    }

    final articulationPoints = _findArticulationPoints(walkable, neighbors);
    final loopNodes = _findLoopNodes(
      walkable: walkable,
      neighbors: neighbors,
      articulationPoints: articulationPoints,
    );

    final topology = _classifyCells(
      maze: maze,
      walkable: walkable,
      neighbors: neighbors,
      articulationPoints: articulationPoints,
      loopNodes: loopNodes,
      config: config,
    );

    return _MazeTrapAnalysis(
      maze: maze,
      walkable: walkable,
      neighbors: neighbors,
      shortestPath: shortestPath,
      shortestPathIndex: shortestPathIndex,
      distanceFromStart: _buildDistanceMap(maze, maze.start),
      distanceToGoal: _buildDistanceMap(maze, maze.end),
      topology: topology,
      articulationPoints: articulationPoints,
      loopNodes: loopNodes,
    );
  }

  Map<Point<int>, TileTopology> _classifyCells({
    required MazeGrid maze,
    required List<Point<int>> walkable,
    required Map<Point<int>, List<Point<int>>> neighbors,
    required Set<Point<int>> articulationPoints,
    required Set<Point<int>> loopNodes,
    required TrapBalanceConfig config,
  }) {
    final result = <Point<int>, TileTopology>{};
    final deadEnds = <Point<int>>{};
    final deadEndEntrances = <Point<int>>{};

    for (final cell in walkable) {
      final cellNeighbors = neighbors[cell] ?? const <Point<int>>[];
      if (cellNeighbors.length == 1) {
        deadEnds.add(cell);
        deadEndEntrances.add(cellNeighbors.first);
      }
    }

    for (final cell in walkable) {
      if (_manhattan(cell, maze.start) <= config.nearStartProtectionRadius) {
        result[cell] = TileTopology.nearStart;
        continue;
      }
      if (_manhattan(cell, maze.end) <= config.nearGoalProtectionRadius) {
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

      final degree = neighbors[cell]?.length ?? 0;
      if (degree >= 4) {
        result[cell] = TileTopology.crossroads;
      } else if (degree == 3) {
        result[cell] = TileTopology.tJunction;
      } else if (loopNodes.contains(cell)) {
        result[cell] = TileTopology.loopNode;
      } else if (degree == 2 && articulationPoints.contains(cell)) {
        result[cell] = TileTopology.chokepoint;
      } else {
        result[cell] = TileTopology.corridor;
      }
    }

    return result;
  }

  _WeightedCell? _buildCandidate({
    required Point<int> cell,
    required _MazeTrapAnalysis analysis,
    required TrapStageConfig stageConfig,
    required Random random,
  }) {
    final topology = analysis.topology[cell] ?? TileTopology.corridor;
    if (topology == TileTopology.nearStart ||
        topology == TileTopology.nearGoal ||
        topology == TileTopology.deadEnd) {
      return null;
    }
    if (topology == TileTopology.chokepoint && !stageConfig.allowChokepoints) {
      return null;
    }
    if (topology == TileTopology.deadEndEntrance &&
        !stageConfig.allowDeadEndEntrances) {
      return null;
    }
    if (topology == TileTopology.loopNode && !stageConfig.allowLoopNodes) {
      return null;
    }

    final pathIndex = analysis.shortestPathIndex[cell];
    final progress = _progressFor(cell, analysis);
    final revisitScore = _revisitScoreFor(
      cell: cell,
      topology: topology,
      analysis: analysis,
      stageConfig: stageConfig,
    );
    final panicScore = stageConfig.allowPanicRoutes
        ? _panicScoreFor(progress, stageConfig.memoryPressure)
        : 0.0;

    var score = _topologyWeight(topology);
    score += revisitScore * 42;
    score += _progressWeight(progress, stageConfig.band);
    score += panicScore * 24;
    if (pathIndex != null) score += 12;
    if (pathIndex == null &&
        topology != TileTopology.deadEndEntrance &&
        topology != TileTopology.loopNode) {
      score *= 0.72;
    }

    final tags = <TrapPressureTag>{};
    if (topology == TileTopology.tJunction ||
        topology == TileTopology.crossroads) {
      tags.add(TrapPressureTag.decisionFork);
    }
    if (revisitScore >= 0.62) {
      tags.add(TrapPressureTag.memoryReturn);
    }
    if (panicScore >= 0.45) {
      tags.add(TrapPressureTag.panicRoute);
    }
    if (topology == TileTopology.chokepoint) {
      tags.add(TrapPressureTag.chokepoint);
    }
    if (topology == TileTopology.loopNode) {
      tags.add(TrapPressureTag.loop);
    }
    if (topology == TileTopology.corridor &&
        stageConfig.memoryPressure >= 0.35 &&
        progress >= 0.52) {
      tags.add(TrapPressureTag.falseConfidence);
      score += 8 * stageConfig.memoryPressure;
    }

    score += random.nextDouble() * 8;
    if (score <= 0) return null;

    return _WeightedCell(
      cell: cell,
      topology: topology,
      weight: score,
      revisitScore: revisitScore,
      pathIndex: pathIndex,
      pressureTags: tags,
    );
  }

  static const _topoWeights = <TileTopology, double>{
    TileTopology.tJunction: 86,
    TileTopology.deadEndEntrance: 78,
    TileTopology.loopNode: 68,
    TileTopology.chokepoint: 52,
    TileTopology.crossroads: 42,
    TileTopology.corridor: 30,
  };

  double _topologyWeight(TileTopology topology) {
    return _topoWeights[topology] ?? 20;
  }

  double _revisitScoreFor({
    required Point<int> cell,
    required TileTopology topology,
    required _MazeTrapAnalysis analysis,
    required TrapStageConfig stageConfig,
  }) {
    final onMainPath = analysis.shortestPathIndex.containsKey(cell);
    final degree = analysis.neighbors[cell]?.length ?? 0;

    if (topology == TileTopology.deadEndEntrance) return 0.92;
    if (topology == TileTopology.loopNode) return 0.78;
    if (onMainPath && degree >= 3 && _hasOffPathNeighbor(cell, analysis)) {
      return 1.0;
    }
    if (topology == TileTopology.chokepoint && onMainPath) return 0.64;
    if (degree >= 3) return 0.56;
    if (onMainPath) {
      return 0.30 + (stageConfig.memoryPressure * 0.18);
    }
    return 0.22;
  }

  bool _hasOffPathNeighbor(Point<int> cell, _MazeTrapAnalysis analysis) {
    final path = analysis.shortestPathIndex;
    for (final neighbor in analysis.neighbors[cell] ?? const <Point<int>>[]) {
      if (!path.containsKey(neighbor)) return true;
    }
    return false;
  }

  double _progressFor(Point<int> cell, _MazeTrapAnalysis analysis) {
    final pathIndex = analysis.shortestPathIndex[cell];
    if (pathIndex != null && analysis.shortestPath.length > 1) {
      return (pathIndex / (analysis.shortestPath.length - 1))
          .clamp(0.0, 1.0)
          .toDouble();
    }

    final startDist = analysis.distanceFromStart[cell];
    final goalDist = analysis.distanceToGoal[cell];
    if (startDist == null || goalDist == null) return 0.5;
    final total = startDist + goalDist;
    if (total <= 0) return 0.0;
    return (startDist / total).clamp(0.0, 1.0).toDouble();
  }

  double _progressWeight(double progress, TrapDifficultyBand band) {
    if (progress < 0.24) return -24;
    if (progress > 0.94) return -14;

    final center = switch (band) {
      TrapDifficultyBand.tutorial => 0.48,
      TrapDifficultyBand.pressure => 0.56,
      TrapDifficultyBand.mastery => 0.64,
      TrapDifficultyBand.nightmare => 0.68,
    };
    final distance = (progress - center).abs();
    return (1 - min(1.0, distance / 0.42)) * 22;
  }

  double _panicScoreFor(double progress, double memoryPressure) {
    if (progress < 0.34 || progress > 0.92) return 0;
    final centerDistance = (progress - 0.68).abs();
    final base = (1 - min(1.0, centerDistance / 0.34)).clamp(0.0, 1.0);
    return base * (0.45 + memoryPressure * 0.55);
  }

  void _selectTiles({
    required List<_WeightedCell> candidates,
    required int targetCount,
    required List<TrapTile> chosen,
    required Set<Point<int>> placedCells,
    required TrapStageConfig stageConfig,
    required Random random,
    required int seed,
  }) {
    final pool = List<_WeightedCell>.from(candidates);
    while (chosen.length < targetCount && pool.isNotEmpty) {
      final candidate = _drawWeighted(pool, random);
      pool.remove(candidate);

      if (placedCells.contains(candidate.cell)) continue;
      if (!_passesSpacing(candidate, chosen, stageConfig)) continue;

      placedCells.add(candidate.cell);
      chosen.add(
        TrapTile(
          cell: candidate.cell,
          crackSeed: _tileSeed(candidate.cell, seed),
          topology: candidate.topology,
          placementScore: candidate.weight,
          revisitScore: candidate.revisitScore,
          pathIndex: candidate.pathIndex,
          pressureTags: candidate.pressureTags,
        ),
      );
    }
  }

  _WeightedCell _drawWeighted(List<_WeightedCell> candidates, Random random) {
    var total = 0.0;
    for (final candidate in candidates) {
      total += max(0.01, candidate.weight);
    }

    var roll = random.nextDouble() * total;
    for (final candidate in candidates) {
      roll -= max(0.01, candidate.weight);
      if (roll <= 0) return candidate;
    }
    return candidates.last;
  }

  bool _passesSpacing(
    _WeightedCell candidate,
    List<TrapTile> chosen,
    TrapStageConfig stageConfig,
  ) {
    for (final trap in chosen) {
      if (_manhattan(trap.cell, candidate.cell) < stageConfig.minTrapSpacing) {
        return false;
      }

      final candidateIndex = candidate.pathIndex;
      final trapIndex = trap.pathIndex;
      if (candidateIndex != null &&
          trapIndex != null &&
          (candidateIndex - trapIndex).abs() <
              stageConfig.mainPathClusterSpacing) {
        return false;
      }
    }
    return true;
  }

  int _preferredTjunctionTarget({
    required int targetCount,
    required int availablePreferred,
    required double ratio,
  }) {
    if (targetCount <= 0 || availablePreferred <= 0) {
      return 0;
    }
    final clampedRatio = ratio.clamp(0.0, 1.0);
    final desired = (targetCount * clampedRatio)
        .ceil()
        .clamp(1, targetCount)
        .toInt();
    return min(desired, availablePreferred);
  }

  Set<Point<int>> _buildProtectedSet({
    required _MazeTrapAnalysis analysis,
    required TrapBalanceConfig config,
    required TrapStageConfig stageConfig,
  }) {
    final maze = analysis.maze;
    final protectedSet = <Point<int>>{};

    for (final cell in analysis.walkable) {
      if (_manhattan(cell, maze.start) <= config.nearStartProtectionRadius) {
        protectedSet.add(cell);
      }
      if (_manhattan(cell, maze.end) <= config.nearGoalProtectionRadius) {
        protectedSet.add(cell);
      }
    }

    if (analysis.shortestPath.isNotEmpty) {
      final scaledRatio =
          config.earlyPathProtectionRatio *
          (1.0 - stageConfig.memoryPressure * 0.45);
      final protectCount =
          (analysis.shortestPath.length * scaledRatio.clamp(0.08, 0.35)).ceil();
      for (
        var i = 0;
        i < protectCount && i < analysis.shortestPath.length;
        i++
      ) {
        protectedSet.add(analysis.shortestPath[i]);
      }
    }

    return protectedSet;
  }

  /// Verifies that a clean first-pass route exists.
  ///
  /// Trap cells are allowed because first contact only cracks the tile. The
  /// validator rejects starts/goals on traps and routes that require immediate
  /// trap-to-trap stepping, which reads as noise on mobile.
  bool _safeFirstPassRouteExists(MazeGrid maze, List<TrapTile> traps) {
    final trapCells = traps.map((t) => t.cell).toSet();
    if (trapCells.contains(maze.start) || trapCells.contains(maze.end)) {
      return false;
    }

    final queue = <_RouteNode>[_RouteNode(maze.start, false)];
    final visited = <_RouteNode>{queue.first};
    var index = 0;

    while (index < queue.length) {
      final current = queue[index++];
      if (current.cell == maze.end) return true;

      for (final direction in Direction4.values) {
        if (!maze.canMove(current.cell, direction)) continue;
        final next = maze.move(current.cell, direction);
        final nextIsTrap = trapCells.contains(next);
        if (current.lastWasTrap && nextIsTrap) continue;
        final node = _RouteNode(next, nextIsTrap);
        if (visited.add(node)) {
          queue.add(node);
        }
      }
    }

    return false;
  }

  List<Point<int>> _allWalkableCells(MazeGrid maze) {
    final cells = <Point<int>>[];
    for (var y = 0; y < maze.rows; y++) {
      for (var x = 0; x < maze.cols; x++) {
        final cell = Point<int>(x, y);
        if (_neighbors(maze, cell).isNotEmpty || cell == maze.start) {
          cells.add(cell);
        }
      }
    }
    return cells;
  }

  Map<Point<int>, int> _buildDistanceMap(MazeGrid maze, Point<int> origin) {
    final distance = <Point<int>, int>{origin: 0};
    final queue = <Point<int>>[origin];
    var index = 0;

    while (index < queue.length) {
      final current = queue[index++];
      final currentDistance = distance[current] ?? 0;

      for (final direction in Direction4.values) {
        if (!maze.canMove(current, direction)) continue;
        final next = maze.move(current, direction);
        if (distance.containsKey(next)) continue;
        distance[next] = currentDistance + 1;
        queue.add(next);
      }
    }

    return distance;
  }

  List<Point<int>> _shortestPath(
    MazeGrid maze,
    Point<int> from,
    Point<int> to,
  ) {
    final parent = <Point<int>, Point<int>?>{from: null};
    final queue = <Point<int>>[from];
    var index = 0;

    while (index < queue.length) {
      final current = queue[index++];
      if (current == to) break;

      for (final direction in Direction4.values) {
        if (!maze.canMove(current, direction)) continue;
        final next = maze.move(current, direction);
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
    return path.reversed.toList(growable: false);
  }

  Set<Point<int>> _findArticulationPoints(
    List<Point<int>> cells,
    Map<Point<int>, List<Point<int>>> neighbors,
  ) {
    final visited = <Point<int>>{};
    final discovery = <Point<int>, int>{};
    final low = <Point<int>, int>{};
    final parent = <Point<int>, Point<int>>{};
    final result = <Point<int>>{};
    var time = 0;

    void visit(Point<int> cell) {
      visited.add(cell);
      discovery[cell] = time;
      low[cell] = time;
      time += 1;

      var childCount = 0;
      for (final next in neighbors[cell] ?? const <Point<int>>[]) {
        if (!visited.contains(next)) {
          parent[next] = cell;
          childCount += 1;
          visit(next);

          low[cell] = min(low[cell] ?? 0, low[next] ?? 0);
          final isRoot = !parent.containsKey(cell);
          if (isRoot && childCount > 1) {
            result.add(cell);
          }
          if (!isRoot && (low[next] ?? 0) >= (discovery[cell] ?? 0)) {
            result.add(cell);
          }
        } else if (parent[cell] != next) {
          low[cell] = min(low[cell] ?? 0, discovery[next] ?? 0);
        }
      }
    }

    for (final cell in cells) {
      if (!visited.contains(cell)) {
        visit(cell);
      }
    }

    return result;
  }

  Set<Point<int>> _findLoopNodes({
    required List<Point<int>> walkable,
    required Map<Point<int>, List<Point<int>>> neighbors,
    required Set<Point<int>> articulationPoints,
  }) {
    final edgeCount =
        neighbors.values.fold<int>(0, (sum, next) => sum + next.length) ~/ 2;
    if (edgeCount <= walkable.length - 1) {
      return const <Point<int>>{};
    }

    return walkable
        .where(
          (cell) =>
              (neighbors[cell]?.length ?? 0) >= 2 &&
              !articulationPoints.contains(cell),
        )
        .toSet();
  }

  List<Point<int>> _neighbors(MazeGrid maze, Point<int> cell) {
    final result = <Point<int>>[];
    for (final direction in Direction4.values) {
      if (maze.canMove(cell, direction)) {
        result.add(maze.move(cell, direction));
      }
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

class _MazeTrapAnalysis {
  const _MazeTrapAnalysis({
    required this.maze,
    required this.walkable,
    required this.neighbors,
    required this.shortestPath,
    required this.shortestPathIndex,
    required this.distanceFromStart,
    required this.distanceToGoal,
    required this.topology,
    required this.articulationPoints,
    required this.loopNodes,
  });

  final MazeGrid maze;
  final List<Point<int>> walkable;
  final Map<Point<int>, List<Point<int>>> neighbors;
  final List<Point<int>> shortestPath;
  final Map<Point<int>, int> shortestPathIndex;
  final Map<Point<int>, int> distanceFromStart;
  final Map<Point<int>, int> distanceToGoal;
  final Map<Point<int>, TileTopology> topology;
  final Set<Point<int>> articulationPoints;
  final Set<Point<int>> loopNodes;
}

class _WeightedCell {
  const _WeightedCell({
    required this.cell,
    required this.topology,
    required this.weight,
    required this.revisitScore,
    required this.pathIndex,
    required this.pressureTags,
  });

  final Point<int> cell;
  final TileTopology topology;
  final double weight;
  final double revisitScore;
  final int? pathIndex;
  final Set<TrapPressureTag> pressureTags;
}

class _RouteNode {
  const _RouteNode(this.cell, this.lastWasTrap);

  final Point<int> cell;
  final bool lastWasTrap;

  @override
  bool operator ==(Object other) {
    return other is _RouteNode &&
        other.cell == cell &&
        other.lastWasTrap == lastWasTrap;
  }

  @override
  int get hashCode => Object.hash(cell, lastWasTrap);
}
