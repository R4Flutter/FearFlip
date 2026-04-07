import 'dart:math';

enum Direction4 { up, right, down, left }

class MazeCell {
  MazeCell();

  bool top = true;
  bool right = true;
  bool bottom = true;
  bool left = true;
  bool visited = false;
}

class MazeGrid {
  MazeGrid({
    required this.rows,
    required this.cols,
    required this.cells,
    required this.start,
    required this.end,
  });

  final int rows;
  final int cols;
  final List<List<MazeCell>> cells;
  final Point<int> start;
  final Point<int> end;

  bool canMove(Point<int> from, Direction4 direction) {
    if (!_inBounds(from.y, from.x)) {
      return false;
    }
    final cell = cells[from.y][from.x];
    switch (direction) {
      case Direction4.up:
        return !cell.top && _inBounds(from.y - 1, from.x);
      case Direction4.right:
        return !cell.right && _inBounds(from.y, from.x + 1);
      case Direction4.down:
        return !cell.bottom && _inBounds(from.y + 1, from.x);
      case Direction4.left:
        return !cell.left && _inBounds(from.y, from.x - 1);
    }
  }

  Point<int> move(Point<int> from, Direction4 direction) {
    switch (direction) {
      case Direction4.up:
        return Point<int>(from.x, from.y - 1);
      case Direction4.right:
        return Point<int>(from.x + 1, from.y);
      case Direction4.down:
        return Point<int>(from.x, from.y + 1);
      case Direction4.left:
        return Point<int>(from.x - 1, from.y);
    }
  }

  bool _inBounds(int row, int col) {
    return row >= 0 && row < rows && col >= 0 && col < cols;
  }
}

class MazeGenerator {
  MazeGrid generate({required int rows, required int cols, int? seed}) {
    final random = Random(seed);
    final cells = List.generate(
      rows,
      (_) => List.generate(cols, (_) => MazeCell()),
    );

    final stack = <Point<int>>[];
    const start = Point<int>(0, 0);
    cells[start.y][start.x].visited = true;
    stack.add(start);

    while (stack.isNotEmpty) {
      final current = stack.last;
      final neighbors = _unvisitedNeighbors(cells, current, rows, cols);

      if (neighbors.isEmpty) {
        stack.removeLast();
        continue;
      }

      final next = neighbors[random.nextInt(neighbors.length)];
      _carve(cells, current, next);
      cells[next.y][next.x].visited = true;
      stack.add(next);
    }

    final end = _farthestReachable(cells, start, rows, cols);

    for (final row in cells) {
      for (final cell in row) {
        cell.visited = false;
      }
    }

    return MazeGrid(
      rows: rows,
      cols: cols,
      cells: cells,
      start: start,
      end: end,
    );
  }

  List<Point<int>> _unvisitedNeighbors(
    List<List<MazeCell>> cells,
    Point<int> current,
    int rows,
    int cols,
  ) {
    final result = <Point<int>>[];
    const candidates = <Point<int>>[
      Point<int>(0, -1),
      Point<int>(1, 0),
      Point<int>(0, 1),
      Point<int>(-1, 0),
    ];

    for (final c in candidates) {
      final nx = current.x + c.x;
      final ny = current.y + c.y;
      if (nx < 0 || ny < 0 || nx >= cols || ny >= rows) {
        continue;
      }
      if (!cells[ny][nx].visited) {
        result.add(Point<int>(nx, ny));
      }
    }

    return result;
  }

  void _carve(List<List<MazeCell>> cells, Point<int> a, Point<int> b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;

    if (dx == 1) {
      cells[a.y][a.x].right = false;
      cells[b.y][b.x].left = false;
    } else if (dx == -1) {
      cells[a.y][a.x].left = false;
      cells[b.y][b.x].right = false;
    } else if (dy == 1) {
      cells[a.y][a.x].bottom = false;
      cells[b.y][b.x].top = false;
    } else if (dy == -1) {
      cells[a.y][a.x].top = false;
      cells[b.y][b.x].bottom = false;
    }
  }

  Point<int> _farthestReachable(
    List<List<MazeCell>> cells,
    Point<int> start,
    int rows,
    int cols,
  ) {
    final queue = <Point<int>>[start];
    final dist = <Point<int>, int>{start: 0};
    var farthest = start;

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final currentCell = cells[current.y][current.x];
      final currentDist = dist[current] ?? 0;

      if (currentDist > (dist[farthest] ?? 0)) {
        farthest = current;
      }

      final nextSteps = <MapEntry<bool, Point<int>>>[
        MapEntry(!currentCell.top, Point<int>(current.x, current.y - 1)),
        MapEntry(!currentCell.right, Point<int>(current.x + 1, current.y)),
        MapEntry(!currentCell.bottom, Point<int>(current.x, current.y + 1)),
        MapEntry(!currentCell.left, Point<int>(current.x - 1, current.y)),
      ];

      for (final step in nextSteps) {
        final p = step.value;
        if (!step.key || p.x < 0 || p.y < 0 || p.x >= cols || p.y >= rows) {
          continue;
        }
        if (dist.containsKey(p)) {
          continue;
        }
        dist[p] = currentDist + 1;
        queue.add(p);
      }
    }

    return farthest;
  }
}
