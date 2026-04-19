import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:fearflipgame/presentation/gameplay/maze_generator.dart';

void main() {
  group('MazeGrid.shortestPathDistance', () {
    test('returns zero when source and target are identical', () {
      final grid = _buildBlockedGrid(rows: 2, cols: 2);

      final distance = grid.shortestPathDistance(
        const Point<int>(0, 0),
        const Point<int>(0, 0),
      );

      expect(distance, 0);
    });

    test('returns null when either point is out of bounds', () {
      final grid = _buildBlockedGrid(rows: 3, cols: 3);

      expect(
        grid.shortestPathDistance(
          const Point<int>(-1, 0),
          const Point<int>(0, 0),
        ),
        isNull,
      );
      expect(
        grid.shortestPathDistance(
          const Point<int>(0, 0),
          const Point<int>(3, 0),
        ),
        isNull,
      );
    });

    test('returns null when no route exists', () {
      final grid = _buildBlockedGrid(rows: 2, cols: 2);
      _openPassage(grid, const Point<int>(0, 0), const Point<int>(1, 0));

      final distance = grid.shortestPathDistance(
        const Point<int>(0, 0),
        const Point<int>(1, 1),
      );

      expect(distance, isNull);
    });

    test('returns BFS shortest route length', () {
      final grid = _buildBlockedGrid(rows: 3, cols: 3);

      // Short path: (0,0)->(1,0)->(2,0)->(2,1)->(2,2) = 4 steps.
      _openPassage(grid, const Point<int>(0, 0), const Point<int>(1, 0));
      _openPassage(grid, const Point<int>(1, 0), const Point<int>(2, 0));
      _openPassage(grid, const Point<int>(2, 0), const Point<int>(2, 1));
      _openPassage(grid, const Point<int>(2, 1), const Point<int>(2, 2));

      // Longer alternate path to ensure shortest route is selected.
      _openPassage(grid, const Point<int>(0, 0), const Point<int>(0, 1));
      _openPassage(grid, const Point<int>(0, 1), const Point<int>(0, 2));
      _openPassage(grid, const Point<int>(0, 2), const Point<int>(1, 2));
      _openPassage(grid, const Point<int>(1, 2), const Point<int>(2, 2));

      final distance = grid.shortestPathDistance(
        const Point<int>(0, 0),
        const Point<int>(2, 2),
      );

      expect(distance, 4);
    });

    test('tracks dynamic devil-player movement sequence', () {
      final grid = _buildBlockedGrid(rows: 1, cols: 5);

      _openPassage(grid, const Point<int>(0, 0), const Point<int>(1, 0));
      _openPassage(grid, const Point<int>(1, 0), const Point<int>(2, 0));
      _openPassage(grid, const Point<int>(2, 0), const Point<int>(3, 0));
      _openPassage(grid, const Point<int>(3, 0), const Point<int>(4, 0));

      final sequence = <({Point<int> player, Point<int> devil, int expected})>[
        (
          player: const Point<int>(0, 0),
          devil: const Point<int>(4, 0),
          expected: 4,
        ),
        (
          player: const Point<int>(1, 0),
          devil: const Point<int>(4, 0),
          expected: 3,
        ),
        (
          player: const Point<int>(2, 0),
          devil: const Point<int>(4, 0),
          expected: 2,
        ),
        (
          player: const Point<int>(3, 0),
          devil: const Point<int>(4, 0),
          expected: 1,
        ),
        (
          player: const Point<int>(4, 0),
          devil: const Point<int>(4, 0),
          expected: 0,
        ),
        (
          player: const Point<int>(4, 0),
          devil: const Point<int>(3, 0),
          expected: 1,
        ),
      ];

      for (final step in sequence) {
        final distance = grid.shortestPathDistance(step.player, step.devil);
        expect(distance, step.expected);
      }
    });
  });
}

MazeGrid _buildBlockedGrid({required int rows, required int cols}) {
  return MazeGrid(
    rows: rows,
    cols: cols,
    cells: List<List<MazeCell>>.generate(
      rows,
      (_) => List<MazeCell>.generate(cols, (_) => MazeCell()),
    ),
    start: const Point<int>(0, 0),
    end: Point<int>(cols - 1, rows - 1),
  );
}

void _openPassage(MazeGrid grid, Point<int> a, Point<int> b) {
  final dx = b.x - a.x;
  final dy = b.y - a.y;

  if (dx == 1 && dy == 0) {
    grid.cells[a.y][a.x].right = false;
    grid.cells[b.y][b.x].left = false;
    return;
  }
  if (dx == -1 && dy == 0) {
    grid.cells[a.y][a.x].left = false;
    grid.cells[b.y][b.x].right = false;
    return;
  }
  if (dx == 0 && dy == 1) {
    grid.cells[a.y][a.x].bottom = false;
    grid.cells[b.y][b.x].top = false;
    return;
  }
  if (dx == 0 && dy == -1) {
    grid.cells[a.y][a.x].top = false;
    grid.cells[b.y][b.x].bottom = false;
    return;
  }

  throw ArgumentError('Cells must be orthogonally adjacent. a=$a b=$b');
}
