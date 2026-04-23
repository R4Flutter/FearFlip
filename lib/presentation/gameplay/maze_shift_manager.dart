import 'dart:math';

import 'package:flutter/foundation.dart';

import 'maze_generator.dart';

enum MazeShiftPhase { none, midRun, lateRun }

class MazeShiftOutcome {
  const MazeShiftOutcome({
    required this.phase,
    required this.applied,
    required this.attempts,
    required this.wasEligibleStage,
  });

  final MazeShiftPhase phase;
  final bool applied;
  final int attempts;
  final bool wasEligibleStage;

  static const MazeShiftOutcome none = MazeShiftOutcome(
    phase: MazeShiftPhase.none,
    applied: false,
    attempts: 0,
    wasEligibleStage: false,
  );
}

class MazeShiftManager {
  MazeShiftManager({Random? random}) : _random = random ?? Random();

  static const int _eligibleStageModulo = 6;
  static const int _candidateCount = 3;
  static const int _regionSelectionAttempts = 28;
  static const double _maxPathLengthMultiplier = 1.5;
  static const double _midMinProgress = 0.40;
  static const double _midMaxProgress = 0.60;
  static const double _lateMinProgress = 0.75;
  static const double _lateMaxProgress = 0.90;
  static const double _graceMinSeconds = 0.5;
  static const double _graceMaxSeconds = 1.0;

  final Random _random;

  int _stage = 1;
  int _stepsTaken = 0;
  int _totalSteps = 1;
  bool _hasMoved = false;
  bool _eligibleStage = false;
  double _midTriggerProgress = _midMinProgress;
  double _lateTriggerProgress = _lateMinProgress;
  double _hazardGraceRemainingSeconds = 0;

  bool hasMidShiftTriggered = false;
  bool hasLateShiftTriggered = false;

  int get stage => _stage;
  int get stepsTaken => _stepsTaken;
  int get totalSteps => _totalSteps;
  bool get isEligibleStage => _eligibleStage;
  bool get hazardGraceActive => _hazardGraceRemainingSeconds > 0;
  double get hazardGraceRemainingSeconds => _hazardGraceRemainingSeconds;

  double get progress {
    if (_totalSteps <= 0) {
      return 0;
    }
    return (_stepsTaken / _totalSteps).clamp(0.0, 1.0);
  }

  void startStage({required int stage, required int totalSteps}) {
    _stage = max(1, stage);
    _stepsTaken = 0;
    _totalSteps = max(1, totalSteps);
    _hasMoved = false;
    _eligibleStage = _stage % _eligibleStageModulo == 0;
    _midTriggerProgress = _randomInRange(_midMinProgress, _midMaxProgress);
    _lateTriggerProgress = _randomInRange(_lateMinProgress, _lateMaxProgress);
    hasMidShiftTriggered = false;
    hasLateShiftTriggered = false;
    _hazardGraceRemainingSeconds = 0;
  }

  void updateTotalSteps(int totalSteps) {
    _totalSteps = max(1, totalSteps);
  }

  void onPlayerStep() {
    _stepsTaken = (_stepsTaken + 1).clamp(0, _totalSteps * 3);
    _hasMoved = true;
  }

  void tick(double deltaSeconds) {
    if (_hazardGraceRemainingSeconds <= 0) {
      return;
    }
    _hazardGraceRemainingSeconds =
        (_hazardGraceRemainingSeconds - max(0.0, deltaSeconds)).clamp(
          0.0,
          99.0,
        );
  }

  MazeShiftPhase get pendingPhase {
    if (!_eligibleStage || !_hasMoved) {
      return MazeShiftPhase.none;
    }

    final currentProgress = progress;

    if (!hasMidShiftTriggered && currentProgress >= _midTriggerProgress) {
      return MazeShiftPhase.midRun;
    }

    if (!hasLateShiftTriggered && currentProgress >= _lateTriggerProgress) {
      return MazeShiftPhase.lateRun;
    }

    return MazeShiftPhase.none;
  }

  void markPhaseTriggered(MazeShiftPhase phase) {
    if (phase == MazeShiftPhase.midRun) {
      hasMidShiftTriggered = true;
    } else if (phase == MazeShiftPhase.lateRun) {
      hasLateShiftTriggered = true;
    }
  }

  MazeShiftOutcome triggerMazeShift({
    required MazeShiftPhase phase,
    required MazeGrid maze,
    required Point<int> playerPosition,
    required Point<int> exitPosition,
  }) {
    if (!_eligibleStage || phase == MazeShiftPhase.none) {
      return MazeShiftOutcome.none;
    }

    final original = _cloneMaze(maze);
    final candidates = _generateCandidates(
      maze: original,
      playerPosition: playerPosition,
      exitPosition: exitPosition,
      count: _candidateCount,
    );
    final oldPathLength = _shortestPathLength(
      maze: original,
      start: playerPosition,
      end: exitPosition,
    );
    if (oldPathLength == null) {
      _logPathValidation(
        oldPathLength: null,
        newPathLength: null,
        verdict: 'rejected_missing_old_path',
      );
      return MazeShiftOutcome(
        phase: phase,
        applied: false,
        attempts: 0,
        wasEligibleStage: true,
      );
    }
    final maxAllowedPathLength = oldPathLength * _maxPathLengthMultiplier;

    MazeGrid? bestCandidateGrid;
    var bestComplexity = -1;
    int? bestPathLength;
    var attempts = 0;

    for (final candidate in candidates) {
      attempts += 1;
      final working = _cloneMaze(original);
      final applied = _applyCandidate(
        maze: working,
        candidate: candidate,
        playerPosition: playerPosition,
        exitPosition: exitPosition,
      );
      if (!applied) {
        continue;
      }

      _normalizeWalls(working, candidate.region);

      if (!_hasOpenAdjacentTile(working, playerPosition)) {
        continue;
      }

      if (!_hasNearbyEscapeRoute(working, playerPosition)) {
        continue;
      }

      final newPathLength = _shortestPathLength(
        maze: working,
        start: playerPosition,
        end: exitPosition,
      );
      if (newPathLength == null) {
        _logPathValidation(
          oldPathLength: oldPathLength,
          newPathLength: null,
          verdict: 'rejected_no_path',
        );
        continue;
      }

      if (newPathLength > maxAllowedPathLength) {
        _logPathValidation(
          oldPathLength: oldPathLength,
          newPathLength: newPathLength,
          verdict: 'rejected_path_too_long',
        );
        continue;
      }

      final complexity = _countEdgeDifferences(
        before: original,
        after: working,
        region: candidate.region,
      );

      final isMoreNoticeable = complexity > bestComplexity;
      final isTieWithShorterPath =
          complexity == bestComplexity &&
          (bestPathLength == null || newPathLength < bestPathLength);
      if (isMoreNoticeable || isTieWithShorterPath) {
        bestComplexity = complexity;
        bestPathLength = newPathLength;
        bestCandidateGrid = working;
        _logPathValidation(
          oldPathLength: oldPathLength,
          newPathLength: newPathLength,
          verdict: 'accepted',
        );
      }
    }

    if (bestCandidateGrid == null) {
      return MazeShiftOutcome(
        phase: phase,
        applied: false,
        attempts: attempts,
        wasEligibleStage: true,
      );
    }

    _copyMaze(bestCandidateGrid, maze);
    _hazardGraceRemainingSeconds = _randomInRange(
      _graceMinSeconds,
      _graceMaxSeconds,
    );

    return MazeShiftOutcome(
      phase: phase,
      applied: true,
      attempts: attempts,
      wasEligibleStage: true,
    );
  }

  List<_ShiftCandidate> _generateCandidates({
    required MazeGrid maze,
    required Point<int> playerPosition,
    required Point<int> exitPosition,
    required int count,
  }) {
    final candidates = <_ShiftCandidate>[];
    for (var i = 0; i < count; i++) {
      final region = _pickRegion(
        maze: maze,
        playerPosition: playerPosition,
        exitPosition: exitPosition,
      );
      if (region == null) {
        continue;
      }

      final operation = _ShiftOperation
          .values[_random.nextInt(_ShiftOperation.values.length)];
      candidates.add(_ShiftCandidate(region: region, operation: operation));
    }
    return candidates;
  }

  _SubGridRegion? _pickRegion({
    required MazeGrid maze,
    required Point<int> playerPosition,
    required Point<int> exitPosition,
  }) {
    final maxSize = min(5, min(maze.rows, maze.cols));
    final minSize = min(3, maxSize);
    if (maxSize <= 1) {
      return null;
    }

    for (var attempt = 0; attempt < _regionSelectionAttempts; attempt++) {
      final size = minSize + _random.nextInt(max(1, maxSize - minSize + 1));
      final maxLeft = maze.cols - size;
      final maxTop = maze.rows - size;
      if (maxLeft < 0 || maxTop < 0) {
        continue;
      }

      final left = _random.nextInt(maxLeft + 1);
      final top = _random.nextInt(maxTop + 1);
      final region = _SubGridRegion(
        left: left,
        top: top,
        width: size,
        height: size,
      );

      if (region.contains(playerPosition)) {
        continue;
      }

      if (region.distanceToCell(playerPosition) <= 1) {
        continue;
      }

      if (region.contains(exitPosition)) {
        continue;
      }

      return region;
    }

    return null;
  }

  bool _applyCandidate({
    required MazeGrid maze,
    required _ShiftCandidate candidate,
    required Point<int> playerPosition,
    required Point<int> exitPosition,
  }) {
    switch (candidate.operation) {
      case _ShiftOperation.rotate:
        return _rotateRegionClockwise(maze, candidate.region);
      case _ShiftOperation.swap:
        return _swapRegionProfiles(
          maze: maze,
          region: candidate.region,
          playerPosition: playerPosition,
          exitPosition: exitPosition,
        );
      case _ShiftOperation.toggle:
        return _toggleRegionWalls(
          maze: maze,
          region: candidate.region,
          playerPosition: playerPosition,
          exitPosition: exitPosition,
        );
    }
  }

  bool _rotateRegionClockwise(MazeGrid maze, _SubGridRegion region) {
    if (region.width != region.height) {
      return false;
    }

    final size = region.width;
    if (size < 2) {
      return false;
    }

    final source = List<List<MazeCell>>.generate(
      size,
      (row) => List<MazeCell>.generate(
        size,
        (col) => _cloneCell(maze.cells[region.top + row][region.left + col]),
      ),
    );

    for (var row = 0; row < size; row++) {
      for (var col = 0; col < size; col++) {
        final destinationRow = col;
        final destinationCol = size - 1 - row;
        final rotated = _rotateCellClockwise(source[row][col]);
        maze.cells[region.top + destinationRow][region.left + destinationCol] =
            rotated;
      }
    }

    return true;
  }

  bool _swapRegionProfiles({
    required MazeGrid maze,
    required _SubGridRegion region,
    required Point<int> playerPosition,
    required Point<int> exitPosition,
  }) {
    final candidates = <Point<int>>[];
    for (var row = region.top; row <= region.bottom; row++) {
      for (var col = region.left; col <= region.right; col++) {
        final cellPoint = Point<int>(col, row);
        if (cellPoint == playerPosition || cellPoint == exitPosition) {
          continue;
        }
        candidates.add(cellPoint);
      }
    }

    if (candidates.length < 2) {
      return false;
    }

    final first = candidates[_random.nextInt(candidates.length)];
    var second = candidates[_random.nextInt(candidates.length)];
    var guard = 0;
    while (second == first && guard < 12) {
      second = candidates[_random.nextInt(candidates.length)];
      guard += 1;
    }

    if (second == first) {
      return false;
    }

    final firstCell = maze.cells[first.y][first.x];
    final secondCell = maze.cells[second.y][second.x];

    final firstTop = firstCell.top;
    final firstRight = firstCell.right;
    final firstBottom = firstCell.bottom;
    final firstLeft = firstCell.left;

    firstCell.top = secondCell.top;
    firstCell.right = secondCell.right;
    firstCell.bottom = secondCell.bottom;
    firstCell.left = secondCell.left;

    secondCell.top = firstTop;
    secondCell.right = firstRight;
    secondCell.bottom = firstBottom;
    secondCell.left = firstLeft;

    return true;
  }

  bool _toggleRegionWalls({
    required MazeGrid maze,
    required _SubGridRegion region,
    required Point<int> playerPosition,
    required Point<int> exitPosition,
  }) {
    final targetChanges = 2 + _random.nextInt(4);
    var changed = 0;

    for (var attempt = 0; attempt < targetChanges * 8; attempt++) {
      final cell = Point<int>(
        region.left + _random.nextInt(region.width),
        region.top + _random.nextInt(region.height),
      );

      if (cell == playerPosition || cell == exitPosition) {
        continue;
      }

      final direction =
          Direction4.values[_random.nextInt(Direction4.values.length)];
      final neighbor = maze.move(cell, direction);
      if (!_isInBounds(maze, neighbor)) {
        continue;
      }
      if (neighbor == playerPosition) {
        continue;
      }

      final currentlyClosed = _isWallClosed(maze, cell, direction);
      _setWallClosed(
        maze: maze,
        from: cell,
        direction: direction,
        closed: !currentlyClosed,
      );
      changed += 1;
      if (changed >= targetChanges) {
        break;
      }
    }

    return changed > 0;
  }

  void _normalizeWalls(MazeGrid maze, _SubGridRegion region) {
    final startRow = max(0, region.top - 1);
    final endRow = min(maze.rows - 1, region.bottom + 1);
    final startCol = max(0, region.left - 1);
    final endCol = min(maze.cols - 1, region.right + 1);

    for (var row = startRow; row <= endRow; row++) {
      for (var col = startCol; col <= endCol; col++) {
        final current = maze.cells[row][col];

        if (col + 1 < maze.cols) {
          final right = maze.cells[row][col + 1];
          final closed = current.right && right.left;
          current.right = closed;
          right.left = closed;
        }

        if (row + 1 < maze.rows) {
          final bottom = maze.cells[row + 1][col];
          final closed = current.bottom && bottom.top;
          current.bottom = closed;
          bottom.top = closed;
        }
      }
    }

    _enforceOuterBoundaries(maze);
  }

  void _enforceOuterBoundaries(MazeGrid maze) {
    for (var col = 0; col < maze.cols; col++) {
      maze.cells[0][col].top = true;
      maze.cells[maze.rows - 1][col].bottom = true;
    }

    for (var row = 0; row < maze.rows; row++) {
      maze.cells[row][0].left = true;
      maze.cells[row][maze.cols - 1].right = true;
    }
  }

  bool _hasOpenAdjacentTile(MazeGrid maze, Point<int> playerPosition) {
    for (final direction in Direction4.values) {
      if (maze.canMove(playerPosition, direction)) {
        return true;
      }
    }
    return false;
  }

  bool _hasNearbyEscapeRoute(MazeGrid maze, Point<int> start) {
    final queue = <_BfsNode>[_BfsNode(cell: start, depth: 0)];
    final visited = <Point<int>>{start};
    var index = 0;

    while (index < queue.length) {
      final node = queue[index++];
      final distanceFromStart =
          (node.cell.x - start.x).abs() + (node.cell.y - start.y).abs();
      if (distanceFromStart >= 2) {
        return true;
      }

      if (node.depth >= 4) {
        continue;
      }

      for (final direction in Direction4.values) {
        if (!maze.canMove(node.cell, direction)) {
          continue;
        }
        final next = maze.move(node.cell, direction);
        if (visited.contains(next)) {
          continue;
        }
        visited.add(next);
        queue.add(_BfsNode(cell: next, depth: node.depth + 1));
      }
    }

    return false;
  }

  int? _shortestPathLength({
    required MazeGrid maze,
    required Point<int> start,
    required Point<int> end,
  }) {
    if (!_isInBounds(maze, start) || !_isInBounds(maze, end)) {
      return null;
    }
    if (start == end) {
      return 0;
    }

    final queue = <Point<int>>[start];
    final distances = <Point<int>, int>{start: 0};
    var index = 0;

    while (index < queue.length) {
      final current = queue[index++];
      final currentDistance = distances[current] ?? 0;

      for (final direction in Direction4.values) {
        if (!maze.canMove(current, direction)) {
          continue;
        }

        final next = maze.move(current, direction);
        if (distances.containsKey(next)) {
          continue;
        }

        final nextDistance = currentDistance + 1;
        if (next == end) {
          return nextDistance;
        }

        distances[next] = nextDistance;
        queue.add(next);
      }
    }

    return null;
  }

  int _countEdgeDifferences({
    required MazeGrid before,
    required MazeGrid after,
    required _SubGridRegion region,
  }) {
    final startRow = max(0, region.top - 1);
    final endRow = min(before.rows - 1, region.bottom + 1);
    final startCol = max(0, region.left - 1);
    final endCol = min(before.cols - 1, region.right + 1);

    var differences = 0;
    for (var row = startRow; row <= endRow; row++) {
      for (var col = startCol; col <= endCol; col++) {
        final oldCell = before.cells[row][col];
        final newCell = after.cells[row][col];

        if (oldCell.top != newCell.top) {
          differences += 1;
        }
        if (oldCell.right != newCell.right) {
          differences += 1;
        }
        if (oldCell.bottom != newCell.bottom) {
          differences += 1;
        }
        if (oldCell.left != newCell.left) {
          differences += 1;
        }
      }
    }

    return differences;
  }

  MazeGrid _cloneMaze(MazeGrid source) {
    final clonedCells = List<List<MazeCell>>.generate(
      source.rows,
      (row) => List<MazeCell>.generate(
        source.cols,
        (col) => _cloneCell(source.cells[row][col]),
      ),
    );

    return MazeGrid(
      rows: source.rows,
      cols: source.cols,
      cells: clonedCells,
      start: source.start,
      end: source.end,
    );
  }

  void _copyMaze(MazeGrid from, MazeGrid to) {
    final rows = min(from.rows, to.rows);
    final cols = min(from.cols, to.cols);

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final source = from.cells[row][col];
        final target = to.cells[row][col];
        target.top = source.top;
        target.right = source.right;
        target.bottom = source.bottom;
        target.left = source.left;
      }
    }
  }

  MazeCell _cloneCell(MazeCell source) {
    final clone = MazeCell()
      ..top = source.top
      ..right = source.right
      ..bottom = source.bottom
      ..left = source.left
      ..visited = false;
    return clone;
  }

  MazeCell _rotateCellClockwise(MazeCell source) {
    final rotated = MazeCell()
      ..top = source.left
      ..right = source.top
      ..bottom = source.right
      ..left = source.bottom
      ..visited = false;
    return rotated;
  }

  bool _isInBounds(MazeGrid maze, Point<int> cell) {
    return cell.x >= 0 &&
        cell.y >= 0 &&
        cell.x < maze.cols &&
        cell.y < maze.rows;
  }

  bool _isWallClosed(MazeGrid maze, Point<int> from, Direction4 direction) {
    final cell = maze.cells[from.y][from.x];
    switch (direction) {
      case Direction4.up:
        return cell.top;
      case Direction4.right:
        return cell.right;
      case Direction4.down:
        return cell.bottom;
      case Direction4.left:
        return cell.left;
    }
  }

  void _setWallClosed({
    required MazeGrid maze,
    required Point<int> from,
    required Direction4 direction,
    required bool closed,
  }) {
    final cell = maze.cells[from.y][from.x];
    final neighbor = maze.move(from, direction);
    final hasNeighbor = _isInBounds(maze, neighbor);

    switch (direction) {
      case Direction4.up:
        cell.top = closed;
        if (hasNeighbor) {
          maze.cells[neighbor.y][neighbor.x].bottom = closed;
        }
        break;
      case Direction4.right:
        cell.right = closed;
        if (hasNeighbor) {
          maze.cells[neighbor.y][neighbor.x].left = closed;
        }
        break;
      case Direction4.down:
        cell.bottom = closed;
        if (hasNeighbor) {
          maze.cells[neighbor.y][neighbor.x].top = closed;
        }
        break;
      case Direction4.left:
        cell.left = closed;
        if (hasNeighbor) {
          maze.cells[neighbor.y][neighbor.x].right = closed;
        }
        break;
    }
  }

  double _randomInRange(double minValue, double maxValue) {
    if (maxValue <= minValue) {
      return minValue;
    }
    return minValue + _random.nextDouble() * (maxValue - minValue);
  }

  void _logPathValidation({
    required int? oldPathLength,
    required int? newPathLength,
    required String verdict,
  }) {
    if (!kDebugMode) {
      return;
    }

    final oldLabel = oldPathLength?.toString() ?? 'null';
    final newLabel = newPathLength?.toString() ?? 'null';
    debugPrint('oldPath=$oldLabel newPath=$newLabel $verdict');
  }
}

enum _ShiftOperation { rotate, swap, toggle }

class _ShiftCandidate {
  const _ShiftCandidate({required this.region, required this.operation});

  final _SubGridRegion region;
  final _ShiftOperation operation;
}

class _SubGridRegion {
  const _SubGridRegion({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final int left;
  final int top;
  final int width;
  final int height;

  int get right => left + width - 1;
  int get bottom => top + height - 1;

  bool contains(Point<int> cell) {
    return cell.x >= left &&
        cell.x <= right &&
        cell.y >= top &&
        cell.y <= bottom;
  }

  int distanceToCell(Point<int> cell) {
    final dx = cell.x < left
        ? left - cell.x
        : (cell.x > right ? cell.x - right : 0);
    final dy = cell.y < top
        ? top - cell.y
        : (cell.y > bottom ? cell.y - bottom : 0);
    return dx + dy;
  }
}

class _BfsNode {
  const _BfsNode({required this.cell, required this.depth});

  final Point<int> cell;
  final int depth;
}
