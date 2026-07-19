import 'dart:math';

import 'package:flame/components.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import 'character.dart';
import 'game_config.dart';
import 'maze.dart';

class DevilComponent extends PositionComponent {
  DevilComponent({
    required this.maze,
    required this.config,
    required this.targetProvider,
    required this.blockedCellsProvider,
    this.spriteSet,
  }) : super(
         anchor: Anchor.center,
         size: Vector2.all(config.devilRadius * 2),
         priority: 19,
       );

  final MazeData maze;
  final RuntimeBalanceConfig config;
  final Vector2 Function() targetProvider;
  final Set<Point<int>> Function() blockedCellsProvider;

  /// 7-frame walk cycle (bigger + slower than the player). Null -> red circle.
  final CharacterSpriteSet? spriteSet;

  // ── Walk-cycle state, advanced from the position delta each frame so it is
  // immune to the pathfinding early-returns below. Devil is heavier: lower fps
  // (longer step period) and a bigger drawn body than the player.
  double _animPhase = 0;
  double _animBreath = 0;
  int _facing = 1;
  int _frame = 0;
  double _bobOffset = 0;
  double _animScaleX = 1;
  double _animScaleY = 1;
  double _moveFactor = 0;
  bool _animPrimed = false;
  double _animLastX = 0;
  double _animLastY = 0;

  static const double _twoPi = 2 * pi;
  static const double _halfPi = pi / 2;
  static const double _devilDrawScale = 0.95; // bigger than the player's 0.82
  static const double _baseFps = 7; // slower cadence than the player
  static const double _maxFps = 10;
  static const double _idleSpeed = 18;
  static const double _breathHz = 1.3;
  static const double _breathAmp = 1.2 * pi / 180;
  late final double _spriteSize = GameBalanceConfig.tileSize * _devilDrawScale;
  late final double _bobAmplitude = _spriteSize * 0.10;
  late final int _frameCount =
      spriteSet?.frameCount ?? CharacterSpriteSet.framesPerSet;
  late final Rect _dstRect = Rect.fromCenter(
    center: Offset.zero,
    width: _spriteSize,
    height: _spriteSize,
  );
  final Paint _bodyPaint = Paint()..color = const Color(0xFFFF1744);
  final Paint _eyePaint = Paint()..color = const Color(0xFFFFFFFF);

  final List<Point<int>> _path = <Point<int>>[];
  double _pathRefreshElapsed = 0;
  double chaseElapsed = 0;

  /// Cached distance-based multiplier, updated each frame in [update].
  double _distanceFactor = 1.0;

  /// Accumulator for throttling the debug log to ≤1 line/second.
  double _logThrottleElapsed = 0;

  /// Reused Random instance for rubber-band jitter – never reallocated in the update loop.
  final Random _random = Random();

  /// Base chase speed (grows over time, capped at devilMaxSpeed).
  double get _baseSpeed {
    final s =
        config.devilBaseSpeed + chaseElapsed * config.devilSpeedGrowthPerSecond;
    return s.clamp(config.devilBaseSpeed, config.devilMaxSpeed);
  }

  /// Effective speed after applying the rubber-band distance factor.
  double get speed => (_baseSpeed * _distanceFactor).clamp(0.2, 255.0);

  @override
  void update(double dt) {
    super.update(dt);

    _advanceWalkCycle(dt);

    chaseElapsed += dt;
    _pathRefreshElapsed += dt;

    // ── Rubber-band distance factor ──────────────────────────────────────────
    // Maps straight-line world-space distance to a speed multiplier via
    // quadratic easing (t²) + micro-random jitter:
    //   distance ≤ nearDist  →  minFactor (0.85×) – devil eases back near player
    //   distance ≥ farDist   →  maxFactor (1.25×) – devil surges when far
    //   in-between           →  t² ramp: slow build at close range,
    //                           stronger pressure as distance widens
    //   jitter ±0.03         →  breaks exploit loops, adds organic variation
    final playerPos = targetProvider();
    final dx = playerPos.x - position.x;
    final dy = playerPos.y - position.y;
    final distance = sqrt(dx * dx + dy * dy);

    // Maze diagonal in world units (expanded grid = logicalDim * 2 + 1 cells).
    final expandedRows = config.logicalMazeRows * 2 + 1;
    final expandedCols = config.logicalMazeCols * 2 + 1;
    final diagW = (expandedCols - 1) * GameBalanceConfig.tileSize;
    final diagH = (expandedRows - 1) * GameBalanceConfig.tileSize;
    final mapDiag = sqrt(diagW * diagW + diagH * diagH);

    const double nearFrac  = 0.25;
    const double farFrac   = 0.75;
    const double minFactor = 0.85;
    const double maxFactor = 1.25;

    final nearDist = nearFrac * mapDiag;
    final farDist  = farFrac  * mapDiag;

    // Quadratic easing: factor grows slowly at close range and accelerates
    // toward maxFactor as the player pulls ahead – creating "almost caught"
    // tension without a jarring linear snap.
    final t = ((distance - nearDist) / (farDist - nearDist)).clamp(0.0, 1.0);
    double factor = minFactor + (maxFactor - minFactor) * (t * t);

    // Micro-jitter (±0.03): makes the AI feel organic and prevents the player
    // from timing a perfect exploit loop around the devil's slowdown.
    // _random is a class-level field – no allocation here.
    factor += _random.nextDouble() * 0.06 - 0.03;
    factor  = factor.clamp(minFactor, maxFactor);

    _distanceFactor = factor;

    _logThrottleElapsed += dt;
    if (_logThrottleElapsed >= 1.0) {
      _logThrottleElapsed = 0;
      debugPrint(
        '[Devil] dist=${distance.toStringAsFixed(1)} '
        'factor=${_distanceFactor.toStringAsFixed(2)} '
        'speed=${speed.toStringAsFixed(1)}',
      );
    }
    // ────────────────────────────────────────────────────────────────────────

    if (_pathRefreshElapsed >= 0.28) {
      _pathRefreshElapsed = 0;
      _rebuildPath();
    }

    if (_path.isEmpty) {
      return;
    }

    final waypoint = maze.cellCenter(_path.first);
    final toWaypoint = waypoint - position;
    if (toWaypoint.length <= 1.5) {
      _path.removeAt(0);
      return;
    }

    final movement = toWaypoint.normalized() * speed * dt;
    final next = position + movement;
    if (maze.isCircleWalkable(
      next,
      config.devilRadius,
      blocked: blockedCellsProvider(),
    )) {
      position.setFrom(next);
    } else {
      _rebuildPath(force: true);
    }
  }

  void resetChase() {
    chaseElapsed = 0;
    _distanceFactor = 1.0;
    _logThrottleElapsed = 0;
    _path.clear();
    _pathRefreshElapsed = 0;
  }

  void applySlowdown({required double secondsReduction}) {
    chaseElapsed = max(0, chaseElapsed - secondsReduction);
  }

  void _rebuildPath({bool force = false}) {
    final start = maze.worldToCell(position);
    final goal = maze.worldToCell(targetProvider());

    if (!force && _path.isNotEmpty && _path.last == goal) {
      return;
    }

    final blocked = blockedCellsProvider();
    final result = _aStar(maze, start, goal, blocked);
    _path
      ..clear()
      ..addAll(result.skip(1));
  }

  /// Advances the walk cycle from the position moved since the previous frame.
  /// Runs at the top of [update] so pathfinding early-returns never freeze it.
  void _advanceWalkCycle(double dt) {
    if (!_animPrimed) {
      _animLastX = position.x;
      _animLastY = position.y;
      _animPrimed = true;
      return;
    }

    final dx = position.x - _animLastX;
    final dy = position.y - _animLastY;
    _animLastX = position.x;
    _animLastY = position.y;

    final moveSpeed = dt > 0 ? sqrt(dx * dx + dy * dy) / dt : 0.0;
    final speed01 = (moveSpeed / config.devilMaxSpeed).clamp(0.0, 1.0);
    final moving = moveSpeed > _idleSpeed;

    if (dx.abs() > 0.05) {
      _facing = dx < 0 ? -1 : 1;
    }

    final moveTarget = moving ? 1.0 : 0.0;
    _moveFactor += (moveTarget - _moveFactor) * (dt * 10).clamp(0.0, 1.0);

    if (moving) {
      final fps = _baseFps + (_maxFps - _baseFps) * speed01;
      _animPhase += _twoPi * (fps / _frameCount) * dt;
      while (_animPhase >= _twoPi) {
        _animPhase -= _twoPi;
      }
      _frame = ((_animPhase / _twoPi) * _frameCount).floor();
      if (_frame >= _frameCount) {
        _frame = _frameCount - 1;
      }
    } else {
      _animPhase = 0;
      _frame = 0;
    }

    final up = 0.5 + 0.5 * sin(_animPhase * 2 - _halfPi);
    _bobOffset = -_bobAmplitude * up * _moveFactor;
    final stretch = (up * 2 - 1).clamp(0.0, 1.0);
    final squash = (1.0 - up).clamp(0.0, 1.0);
    _animScaleY = 1.0 + (0.05 * stretch - 0.06 * squash) * _moveFactor;
    _animScaleX = 1.0 + (0.06 * squash - 0.03 * stretch) * _moveFactor;

    _animBreath += _twoPi * _breathHz * dt;
    while (_animBreath >= _twoPi) {
      _animBreath -= _twoPi;
    }
  }

  @override
  void render(Canvas canvas) {
    final set = spriteSet;
    if (set == null) {
      // Fallback primitive if the art failed to load.
      canvas.drawCircle(Offset.zero, config.devilRadius, _bodyPaint);
      canvas.drawCircle(const Offset(2, -2), 1.6, _eyePaint);
      return;
    }

    canvas.save();
    canvas.translate(0, _bobOffset);
    final rot = _breathAmp * sin(_animBreath);
    if (rot != 0) {
      canvas.rotate(rot);
    }
    canvas.scale(_animScaleX * (_facing < 0 ? -1.0 : 1.0), _animScaleY);
    set.frameAt(_frame).renderRect(canvas, _dstRect);
    canvas.restore();
  }
}

List<Point<int>> _aStar(
  MazeData maze,
  Point<int> start,
  Point<int> goal,
  Set<Point<int>> blocked,
) {
  if (!maze.isWalkable(start) ||
      !maze.isWalkable(goal) ||
      blocked.contains(goal)) {
    return <Point<int>>[];
  }

  final openSet = PriorityQueue<_Node>((a, b) => a.fScore.compareTo(b.fScore));
  final cameFrom = <Point<int>, Point<int>>{};
  final gScore = <Point<int>, double>{start: 0};

  openSet.add(_Node(start, _heuristic(start, goal)));

  const neighbors = <Point<int>>[
    Point<int>(1, 0),
    Point<int>(-1, 0),
    Point<int>(0, 1),
    Point<int>(0, -1),
  ];

  final closed = <Point<int>>{};

  while (openSet.isNotEmpty) {
    final current = openSet.removeFirst().cell;
    if (current == goal) {
      return _reconstructPath(cameFrom, current);
    }

    if (!closed.add(current)) {
      continue;
    }

    for (final d in neighbors) {
      final next = Point<int>(current.x + d.x, current.y + d.y);
      if (!maze.isWalkable(next) || blocked.contains(next)) {
        continue;
      }

      final tentative = (gScore[current] ?? double.infinity) + 1;
      if (tentative < (gScore[next] ?? double.infinity)) {
        cameFrom[next] = current;
        gScore[next] = tentative;
        final f = tentative + _heuristic(next, goal);
        openSet.add(_Node(next, f));
      }
    }
  }

  return <Point<int>>[];
}

List<Point<int>> _reconstructPath(
  Map<Point<int>, Point<int>> cameFrom,
  Point<int> current,
) {
  final total = <Point<int>>[current];
  while (cameFrom.containsKey(current)) {
    current = cameFrom[current]!;
    total.add(current);
  }
  return total.reversed.toList(growable: false);
}

double _heuristic(Point<int> a, Point<int> b) {
  return (a.x - b.x).abs() + (a.y - b.y).abs().toDouble();
}

class _Node {
  _Node(this.cell, this.fScore);

  final Point<int> cell;
  final double fScore;
}
