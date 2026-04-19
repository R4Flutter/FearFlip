import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'game_config.dart';

class MazeData {
  MazeData({
    required this.grid,
    required this.startCell,
    required this.goalCell,
    required this.safeZones,
  }) : rows = grid.length,
       cols = grid.isNotEmpty ? grid.first.length : 0;

  final List<List<int>> grid;
  final int rows;
  final int cols;
  final Point<int> startCell;
  final Point<int> goalCell;
  final List<Point<int>> safeZones;

  factory MazeData.fromGrid({
    required List<List<int>> grid,
    Point<int>? startCell,
    Point<int>? goalCell,
    List<Point<int>> safeZones = const <Point<int>>[],
  }) {
    if (grid.isEmpty || grid.first.isEmpty) {
      throw ArgumentError('Maze grid must not be empty.');
    }
    final cols = grid.first.length;
    for (final row in grid) {
      if (row.length != cols) {
        throw ArgumentError('All maze grid rows must have equal length.');
      }
      for (final value in row) {
        if (value != 0 && value != 1) {
          throw ArgumentError('Maze grid values must be 0 (path) or 1 (wall).');
        }
      }
    }

    Point<int>? firstPath;
    Point<int>? lastPath;
    for (var y = 0; y < grid.length; y++) {
      for (var x = 0; x < cols; x++) {
        if (grid[y][x] == 0) {
          firstPath ??= Point<int>(x, y);
          lastPath = Point<int>(x, y);
        }
      }
    }

    if (firstPath == null || lastPath == null) {
      throw ArgumentError('Maze grid must contain at least one path tile (0).');
    }

    final resolvedStart = startCell ?? firstPath;
    final resolvedGoal = goalCell ?? _farthestWalkableCell(grid, resolvedStart);

    if (grid[resolvedStart.y][resolvedStart.x] != 0) {
      throw ArgumentError('startCell must be on a path tile (0).');
    }
    if (grid[resolvedGoal.y][resolvedGoal.x] != 0) {
      throw ArgumentError('goalCell must be on a path tile (0).');
    }

    return MazeData(
      grid: grid,
      startCell: resolvedStart,
      goalCell: resolvedGoal,
      safeZones: safeZones
          .where(
            (c) =>
                c.x >= 0 &&
                c.x < cols &&
                c.y >= 0 &&
                c.y < grid.length &&
                grid[c.y][c.x] == 0,
          )
          .toList(),
    );
  }

  bool isWall(Point<int> cell) {
    if (!isInBounds(cell)) {
      return true;
    }
    return grid[cell.y][cell.x] == 1;
  }

  bool isInBounds(Point<int> cell) {
    return cell.x >= 0 && cell.x < cols && cell.y >= 0 && cell.y < rows;
  }

  bool isWalkable(Point<int> cell) {
    return !isWall(cell);
  }

  Point<int> worldToCell(Vector2 world) {
    return Point<int>(
      (world.x / GameBalanceConfig.tileSize).floor(),
      (world.y / GameBalanceConfig.tileSize).floor(),
    );
  }

  Vector2 cellCenter(Point<int> cell) {
    final tile = GameBalanceConfig.tileSize;
    return Vector2((cell.x + 0.5) * tile, (cell.y + 0.5) * tile);
  }

  bool isCircleWalkable(
    Vector2 center,
    double radius, {
    Set<Point<int>> blocked = const {},
  }) {
    final tile = GameBalanceConfig.tileSize;
    final minX = ((center.x - radius) / tile).floor();
    final maxX = ((center.x + radius) / tile).floor();
    final minY = ((center.y - radius) / tile).floor();
    final maxY = ((center.y + radius) / tile).floor();

    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        final cell = Point<int>(x, y);
        if (blocked.contains(cell)) {
          return false;
        }
        if (!isWalkable(cell)) {
          return false;
        }
      }
    }
    return true;
  }

  int? shortestPathDistance(Point<int> from, Point<int> to) {
    if (!isWalkable(from) || !isWalkable(to)) {
      return null;
    }
    if (from == to) {
      return 0;
    }

    final queue = <Point<int>>[from];
    final distance = <Point<int>, int>{from: 0};

    const neighbors = <Point<int>>[
      Point<int>(1, 0),
      Point<int>(-1, 0),
      Point<int>(0, 1),
      Point<int>(0, -1),
    ];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final currentDist = distance[current] ?? 0;

      for (final delta in neighbors) {
        final next = Point<int>(current.x + delta.x, current.y + delta.y);
        if (!isWalkable(next) || distance.containsKey(next)) {
          continue;
        }

        final nextDist = currentDist + 1;
        if (next == to) {
          return nextDist;
        }

        distance[next] = nextDist;
        queue.add(next);
      }
    }

    return null;
  }

  static MazeData generate({
    required int logicalRows,
    required int logicalCols,
    int? seed,
  }) {
    final random = Random(seed);

    final visited = List.generate(
      logicalRows,
      (_) => List<bool>.filled(logicalCols, false),
    );
    final horizontal = List.generate(
      logicalRows + 1,
      (_) => List<bool>.filled(logicalCols, true),
    );
    final vertical = List.generate(
      logicalRows,
      (_) => List<bool>.filled(logicalCols + 1, true),
    );

    final stack = <Point<int>>[];
    final startLogical = const Point<int>(0, 0);
    stack.add(startLogical);
    visited[0][0] = true;

    const dirs = <Point<int>>[
      Point<int>(0, -1),
      Point<int>(1, 0),
      Point<int>(0, 1),
      Point<int>(-1, 0),
    ];

    while (stack.isNotEmpty) {
      final current = stack.last;
      final candidates = <Point<int>>[];

      for (final d in dirs) {
        final nx = current.x + d.x;
        final ny = current.y + d.y;
        if (nx >= 0 &&
            nx < logicalCols &&
            ny >= 0 &&
            ny < logicalRows &&
            !visited[ny][nx]) {
          candidates.add(Point<int>(nx, ny));
        }
      }

      if (candidates.isEmpty) {
        stack.removeLast();
        continue;
      }

      final next = candidates[random.nextInt(candidates.length)];
      final dx = next.x - current.x;
      final dy = next.y - current.y;

      if (dx == 1) {
        vertical[current.y][current.x + 1] = false;
      } else if (dx == -1) {
        vertical[current.y][current.x] = false;
      } else if (dy == 1) {
        horizontal[current.y + 1][current.x] = false;
      } else if (dy == -1) {
        horizontal[current.y][current.x] = false;
      }

      visited[next.y][next.x] = true;
      stack.add(next);
    }

    final expandedRows = logicalRows * 2 + 1;
    final expandedCols = logicalCols * 2 + 1;
    final grid = List.generate(
      expandedRows,
      (_) => List<int>.filled(expandedCols, 1),
    );

    for (var y = 0; y < logicalRows; y++) {
      for (var x = 0; x < logicalCols; x++) {
        final ex = x * 2 + 1;
        final ey = y * 2 + 1;
        grid[ey][ex] = 0;

        if (!vertical[y][x + 1]) {
          grid[ey][ex + 1] = 0;
        }
        if (!horizontal[y + 1][x]) {
          grid[ey + 1][ex] = 0;
        }
      }
    }

    final startCell = const Point<int>(1, 1);
    final goalCell = _farthestWalkableCell(grid, startCell);

    final safeZones =
        <Point<int>>[
              const Point<int>(3, 3),
              Point<int>(
                (expandedCols / 2).floor() | 1,
                (expandedRows / 2).floor() | 1,
              ),
              Point<int>(expandedCols - 4, 3),
            ]
            .where(
              (cell) =>
                  cell.x > 0 &&
                  cell.x < expandedCols - 1 &&
                  cell.y > 0 &&
                  cell.y < expandedRows - 1 &&
                  grid[cell.y][cell.x] == 0,
            )
            .toList();

    return MazeData(
      grid: grid,
      startCell: startCell,
      goalCell: goalCell,
      safeZones: safeZones,
    );
  }

  static Point<int> _farthestWalkableCell(
    List<List<int>> grid,
    Point<int> start,
  ) {
    final rows = grid.length;
    final cols = rows == 0 ? 0 : grid.first.length;
    final queue = <Point<int>>[start];
    final distance = <Point<int>, int>{start: 0};
    var farthest = start;

    const dirs = <Point<int>>[
      Point<int>(1, 0),
      Point<int>(-1, 0),
      Point<int>(0, 1),
      Point<int>(0, -1),
    ];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final currentDist = distance[current] ?? 0;
      if (currentDist > (distance[farthest] ?? 0)) {
        farthest = current;
      }

      for (final d in dirs) {
        final nx = current.x + d.x;
        final ny = current.y + d.y;
        final next = Point<int>(nx, ny);
        if (nx < 0 || ny < 0 || nx >= cols || ny >= rows) {
          continue;
        }
        if (grid[ny][nx] == 1 || distance.containsKey(next)) {
          continue;
        }
        distance[next] = currentDist + 1;
        queue.add(next);
      }
    }

    return farthest;
  }
}

class MazeComponent extends PositionComponent {
  MazeComponent({required this.maze})
    : super(
        position: Vector2.zero(),
        size: Vector2(
          maze.cols * GameBalanceConfig.tileSize,
          maze.rows * GameBalanceConfig.tileSize,
        ),
      );

  final MazeData maze;
  late final List<Rect> _wallRects = _buildWallRects();
  bool isInverted = false;
  bool isMemoryHidden = false;
  bool showGoalHint = false;
  bool devilPresent = false;
  double _goalHintPulse = 0;

  List<Rect> _buildWallRects() {
    final tile = GameBalanceConfig.tileSize;
    final rects = <Rect>[];

    for (var y = 0; y < maze.rows; y++) {
      var runStart = -1;
      for (var x = 0; x <= maze.cols; x++) {
        final isWall = x < maze.cols && maze.grid[y][x] == 1;
        if (isWall && runStart == -1) {
          runStart = x;
        }
        if (!isWall && runStart != -1) {
          rects.add(
            Rect.fromLTWH(
              runStart * tile,
              y * tile,
              (x - runStart) * tile,
              tile,
            ),
          );
          runStart = -1;
        }
      }
    }

    return rects;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _goalHintPulse += dt;
  }

  @override
  void render(Canvas canvas) {
    final tile = GameBalanceConfig.tileSize;
    const mazeBorderWidth = 3.0;
    final frameInset = GameBalanceConfig.mazeFrameInset;
    final frameRadius = Radius.circular(GameBalanceConfig.mazeFrameRadius);

    final pathPaint = Paint()..color = const Color(0xFFF8F8F8);
    final wallEdge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = const Color(0xFF000000);
    final wallGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0x66000000);
    final hiddenWall = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75
      ..color = const Color(0x33FFFFFF);

    final frameGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 5)
      ..color = isInverted ? const Color(0x33405060) : const Color(0xAA34D8FF);
    final frameRect = Rect.fromLTWH(
      frameInset,
      frameInset,
      size.x - (frameInset * 2),
      size.y - (frameInset * 2),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, frameRadius),
      frameGlow,
    );

    canvas.drawRect(size.toRect(), pathPaint);

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = isInverted ? const Color(0x16000000) : const Color(0x2200F0FF);
    for (var y = 0; y <= maze.rows; y++) {
      final yPos = y * tile;
      canvas.drawLine(Offset(0, yPos), Offset(size.x, yPos), gridPaint);
    }
    for (var x = 0; x <= maze.cols; x++) {
      final xPos = x * tile;
      canvas.drawLine(Offset(xPos, 0), Offset(xPos, size.y), gridPaint);
    }

    for (final rect in _wallRects) {
      if (isMemoryHidden) {
        canvas.drawRect(rect, hiddenWall);
      } else {
        canvas.drawRect(rect, wallGlow);
        canvas.drawRect(rect, wallEdge);
      }
    }

    final goalPaint = Paint()
      ..color = isInverted ? const Color(0xFF1A6E79) : const Color(0xFFFFC107);
    final goalRect = Rect.fromCenter(
      center: maze.cellCenter(maze.goalCell).toOffset(),
      width: tile * 0.6,
      height: tile * 0.6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(goalRect, const Radius.circular(6)),
      goalPaint,
    );

    if (showGoalHint) {
      final pulse = 0.5 + (sin(_goalHintPulse * 6) + 1) * 0.25;
      final hintCenter = maze.cellCenter(maze.goalCell).toOffset();
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFFFF176).withValues(alpha: pulse);
      canvas.drawCircle(hintCenter, tile * 0.6 + tile * pulse * 0.25, ring);

      final core = Paint()
        ..color = const Color(0xFFFFF176).withValues(alpha: 0.9);
      canvas.drawCircle(hintCenter, tile * 0.12, core);

      final tp = TextPainter(
        text: const TextSpan(
          text: 'GOAL',
          style: TextStyle(
            color: Color(0xFFFFF59D),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(hintCenter.dx - tp.width / 2, hintCenter.dy - tile * 1.2),
      );
    }

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = mazeBorderWidth
      ..color = isInverted ? const Color(0xFF2B3138) : const Color(0xFF42F5FF);
    final borderRect = Rect.fromLTWH(
      frameInset,
      frameInset,
      size.x - (frameInset * 2),
      size.y - (frameInset * 2),
    );
    canvas.drawRRect(RRect.fromRectAndRadius(borderRect, frameRadius), border);
  }
}
