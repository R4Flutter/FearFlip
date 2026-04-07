import 'dart:math';

import '../../domain/procedural/level_config.dart';
import '../../domain/procedural/procedural_modules.dart';
import '../../game/maze.dart';

class LevelValidatorImpl implements LevelValidator<MazeData> {
  static const int _simRuns = 5;
  static const double _dt = 0.05;

  @override
  ValidationResult validate({
    required LevelConfig config,
    required MazeData maze,
    required int seed,
  }) {
    final structuralError = _checkStructuralRules(config: config, maze: maze);
    if (structuralError != null) {
      return ValidationResult(
        successCount: 0,
        runs: <ValidationRun>[
          ValidationRun(success: false, failureReason: structuralError),
        ],
        passed: false,
      );
    }

    final random = Random(seed ^ 0x7F4A7C15);
    final runs = <ValidationRun>[];
    var successCount = 0;
    for (var i = 0; i < _simRuns; i++) {
      final reactionTime = 0.16 + random.nextDouble() * 0.06;
      final mistakeChance = 0.03 + random.nextDouble() * 0.05;
      final ok = _simulateSingleRun(
        config: config,
        maze: maze,
        reactionTime: reactionTime,
        mistakeChance: mistakeChance,
      );
      runs.add(
        ValidationRun(
          success: ok,
          failureReason: ok ? null : 'simulation_failed',
        ),
      );
      if (ok) {
        successCount++;
      }
    }

    return ValidationResult(
      successCount: successCount,
      runs: runs,
      passed: successCount >= 3,
    );
  }

  String? _checkStructuralRules({
    required LevelConfig config,
    required MazeData maze,
  }) {
    if (config.warningTime < 0.40) {
      return 'warning_too_low';
    }
    if (config.devilSpeed > config.playerSpeed) {
      return 'devil_faster_than_player';
    }
    if (config.chaosEvents.length > 2) {
      return 'too_many_chaos_events';
    }

    final pathLen = _shortestPathLength(
      maze: maze,
      start: maze.startCell,
      goal: maze.goalCell,
    );
    if (pathLen == null) {
      return 'no_path_to_goal';
    }

    if (_spawnBlocksAllExits(maze, maze.startCell)) {
      return 'spawn_blocks_exits';
    }
    return null;
  }

  bool _simulateSingleRun({
    required LevelConfig config,
    required MazeData maze,
    required double reactionTime,
    required double mistakeChance,
  }) {
    if (config.warningTime + 0.01 < reactionTime) {
      return false;
    }

    final pathLength = _shortestPathLength(
      maze: maze,
      start: maze.startCell,
      goal: maze.goalCell,
    );
    if (pathLength == null) {
      return false;
    }

    final effectivePlayerSpeed =
        (config.playerSpeed * (1.0 - mistakeChance * 0.6)).clamp(0.05, 4.0);
    final effectiveDevilSpeed = config.devilSpeed.clamp(0.05, 4.0);

    final stepsToGoal = pathLength.toDouble();
    final playerTravelTime = stepsToGoal / effectivePlayerSpeed;

    final spawnDistance = max(6.0, stepsToGoal * 0.65);
    final devilCatchTime = spawnDistance / max(0.01, effectiveDevilSpeed);

    final chaosPenalty = 1 + (config.chaosEvents.length * 0.08);
    final flipPenalty = 1 + (config.flipRandomness * 0.15);
    final adjustedPlayerTime = playerTravelTime * chaosPenalty * flipPenalty;

    final maxTime = min(90.0, adjustedPlayerTime + 10.0);
    var elapsed = 0.0;
    while (elapsed < maxTime) {
      elapsed += _dt;
      if (elapsed >= adjustedPlayerTime) {
        return true;
      }
      if (elapsed >= devilCatchTime) {
        return false;
      }
    }

    return false;
  }

  int? _shortestPathLength({
    required MazeData maze,
    required Point<int> start,
    required Point<int> goal,
  }) {
    final queue = <Point<int>>[start];
    final visited = <Point<int>, int>{start: 0};
    const dirs = <Point<int>>[
      Point<int>(1, 0),
      Point<int>(-1, 0),
      Point<int>(0, 1),
      Point<int>(0, -1),
    ];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      if (current == goal) {
        return visited[current];
      }
      for (final d in dirs) {
        final next = Point<int>(current.x + d.x, current.y + d.y);
        if (!maze.isWalkable(next) || visited.containsKey(next)) {
          continue;
        }
        visited[next] = (visited[current] ?? 0) + 1;
        queue.add(next);
      }
    }
    return null;
  }

  bool _spawnBlocksAllExits(MazeData maze, Point<int> origin) {
    const dirs = <Point<int>>[
      Point<int>(1, 0),
      Point<int>(-1, 0),
      Point<int>(0, 1),
      Point<int>(0, -1),
    ];
    var openNeighbors = 0;
    for (final d in dirs) {
      final cell = Point<int>(origin.x + d.x, origin.y + d.y);
      if (maze.isWalkable(cell)) {
        openNeighbors++;
      }
    }
    return openNeighbors == 0;
  }
}
