import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'maze_generator.dart';

class PlayerController extends ChangeNotifier {
  PlayerController({
    required this.maze,
    required TickerProvider vsync,
    this.onWin,
    this.animationFrameCount = 8,
    this.animationFrameStepMs = 100,
    this.baseMoveDurationMs = 120,
  }) {
    _ticker = vsync.createTicker(_handleTick);
    resetForMaze(maze);
  }

  MazeGrid maze;
  final VoidCallback? onWin;
  final int animationFrameCount;
  final int animationFrameStepMs;
  final int baseMoveDurationMs;

  late Point<int> _position;
  final List<Offset> _pathPoints = <Offset>[];
  late final List<Offset> _pathPointsView = UnmodifiableListView(_pathPoints);
  Direction4? _heldDirection;
  late final Ticker _ticker;
  Duration? _lastTickElapsed;
  Point<int>? _segmentFrom;
  Point<int>? _segmentTo;
  double _segmentProgress = 0;
  double _frameElapsedMs = 0;

  int _moveDurationMs = 120;
  bool _controlsInverted = false;

  Direction4 _direction = Direction4.right;
  int _currentFrame = 0;

  Point<int> get position => _position;
  Direction4 get direction => _direction;
  int get currentFrame => _currentFrame;
  bool get isMoving => _segmentTo != null;

  List<Offset> get pathPoints => _pathPointsView;

  Offset get renderPosition {
    final from = _segmentFrom;
    final to = _segmentTo;
    if (from == null || to == null) {
      return Offset(_position.x.toDouble(), _position.y.toDouble());
    }

    final x = from.x + (to.x - from.x) * _segmentProgress;
    final y = from.y + (to.y - from.y) * _segmentProgress;
    return Offset(x.toDouble(), y.toDouble());
  }

  void resetForMaze(MazeGrid newMaze) {
    stop();
    maze = newMaze;
    _position = maze.start;
    _segmentFrom = null;
    _segmentTo = null;
    _segmentProgress = 0;
    _pathPoints
      ..clear()
      ..add(Offset(_position.x.toDouble(), _position.y.toDouble()));
    _direction = Direction4.right;
    _currentFrame = 0;
    _frameElapsedMs = 0;
    notifyListeners();
  }

  bool get hasWon => _position == maze.end;

  bool get controlsInverted => _controlsInverted;

  void setControlsInverted(bool value) {
    _controlsInverted = value;
  }

  void setSpeedMultiplier(double multiplier) {
    final safe = multiplier <= 0 ? 1.0 : multiplier;
    _moveDurationMs = (baseMoveDurationMs / safe).round().clamp(60, 260);
  }

  void holdDirection(Direction4? direction) {
    _heldDirection = direction;
    _ensureTicking();
  }

  void stop() {
    _heldDirection = null;
    if (_ticker.isActive) {
      _ticker.stop();
    }
    _lastTickElapsed = null;
    _currentFrame = 0;
    _frameElapsedMs = 0;
    notifyListeners();
  }

  void _ensureTicking() {
    if (_ticker.isActive) {
      return;
    }

    _lastTickElapsed = null;
    _ticker.start();
  }

  void _handleTick(Duration elapsed) {
    final lastElapsed = _lastTickElapsed;
    _lastTickElapsed = elapsed;

    if (lastElapsed == null) {
      _tick(0);
      return;
    }

    final dt = (elapsed - lastElapsed).inMicroseconds / 1000000.0;
    _tick(dt.clamp(0.0, 0.05).toDouble());
  }

  void _tick(double dt) {
    var changed = false;

    if (_segmentTo != null) {
      _segmentProgress += dt / (_moveDurationMs / 1000.0);
      if (_segmentProgress >= 1) {
        final arrived = _segmentTo!;
        _position = arrived;
        _segmentFrom = null;
        _segmentTo = null;
        _segmentProgress = 0;
        _commitPath(arrived);

        if (hasWon) {
          onWin?.call();
        }
      }
      changed = true;
    }

    if (_segmentTo == null && _heldDirection != null) {
      changed = _tryStartStep(_heldDirection!) || changed;
    }

    if (_segmentTo != null) {
      _frameElapsedMs += dt * 1000;
      final frameStep = max(animationFrameStepMs, 16);
      final frameCount = max(animationFrameCount, 1);
      while (_frameElapsedMs >= frameStep) {
        _frameElapsedMs -= frameStep;
        _currentFrame = (_currentFrame + 1) % frameCount;
      }
    } else if (_currentFrame != 0 || _frameElapsedMs != 0) {
      _currentFrame = 0;
      _frameElapsedMs = 0;
      changed = true;
    }

    if (changed) {
      notifyListeners();
    }

    if (_heldDirection == null && _segmentTo == null) {
      stop();
    }
  }

  bool _tryStartStep(Direction4 direction) {
    if (!maze.canMove(_position, direction)) {
      return false;
    }

    final next = maze.move(_position, direction);
    _direction = direction;
    _segmentFrom = _position;
    _segmentTo = next;
    _segmentProgress = 0;
    return true;
  }

  void _commitPath(Point<int> next) {
    final nextPoint = Offset(next.x.toDouble(), next.y.toDouble());

    // Keep only the currently walkable trail: stepping back retracts the path.
    if (_pathPoints.length > 1 &&
        _pathPoints[_pathPoints.length - 2] == nextPoint) {
      _pathPoints.removeLast();
    } else if (_pathPoints.isEmpty || _pathPoints.last != nextPoint) {
      _pathPoints.add(nextPoint);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
