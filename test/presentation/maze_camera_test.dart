import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:fearflipgame/presentation/gameplay/maze_camera.dart';
import 'package:fearflipgame/presentation/gameplay/maze_generator.dart';

MazeGrid _maze(int rows, int cols) => MazeGrid(
  rows: rows,
  cols: cols,
  cells: List.generate(rows, (_) => List.generate(cols, (_) => MazeCell())),
  start: const Point<int>(0, 0),
  end: Point<int>(cols - 1, rows - 1),
);

void main() {
  group('isWallTile', () {
    test('cells are floor, the outer border and closed edges are wall', () {
      final maze = _maze(2, 2);
      expect(isWallTile(maze, 1, 1), isFalse);
      expect(isWallTile(maze, 3, 3), isFalse);
      expect(isWallTile(maze, 0, 1), isTrue);
      expect(isWallTile(maze, 4, 3), isTrue);
      expect(isWallTile(maze, 2, 1), isTrue);
      expect(isWallTile(maze, -1, 0), isTrue);
    });

    test('an open edge is floor and an untouched corner opens', () {
      final maze = _maze(2, 2);
      for (final row in maze.cells) {
        for (final cell in row) {
          cell
            ..right = false
            ..left = false
            ..top = false
            ..bottom = false;
        }
      }
      // Outer border is read from the edge cells, so close it again.
      for (var i = 0; i < 2; i++) {
        maze.cells[0][i].top = true;
        maze.cells[1][i].bottom = true;
        maze.cells[i][0].left = true;
        maze.cells[i][1].right = true;
      }
      expect(isWallTile(maze, 2, 1), isFalse); // edge between (0,0) and (1,0)
      expect(isWallTile(maze, 1, 2), isFalse); // edge between (0,0) and (0,1)
      expect(isWallTile(maze, 2, 2), isFalse); // centre corner: a room
      expect(isWallTile(maze, 0, 0), isTrue); // border corner stays wall
    });
  });

  group('MazeCamera.follow', () {
    final maze = _maze(10, 10); // 21×21 tiles
    const view = Size(110, 110); // 11 tiles of 10 px

    test('shows 11 tiles across', () {
      final camera = MazeCamera.follow(
        viewport: view,
        maze: maze,
        focus: Offset.zero,
      );
      expect(camera.tileSize, 10);
    });

    test('centres the runner in open ground', () {
      final camera = MazeCamera.follow(
        viewport: view,
        maze: maze,
        focus: const Offset(5, 5),
      );
      expect(camera.cellCenter(const Offset(5, 5)), const Offset(55, 55));
    });

    test('stops at the outer wall instead of showing past it', () {
      final topLeft = MazeCamera.follow(
        viewport: view,
        maze: maze,
        focus: Offset.zero,
      );
      expect(topLeft.origin, Offset.zero);
      expect(topLeft.cellCenter(Offset.zero), const Offset(15, 15));

      final bottomRight = MazeCamera.follow(
        viewport: view,
        maze: maze,
        focus: const Offset(9, 9),
      );
      expect(bottomRight.origin, const Offset(-100, -100));
      expect(bottomRight.cellCenter(const Offset(9, 9)), const Offset(95, 95));
    });

    test('cell rects are one tile, cells two tiles apart', () {
      final camera = MazeCamera.follow(
        viewport: view,
        maze: maze,
        focus: Offset.zero,
      );
      expect(
        camera.cellRect(const Point<int>(1, 0)),
        const Rect.fromLTWH(30, 10, 10, 10),
      );
      expect(camera.cellOrigin, const Offset(10, 10));
    });
  });

  group('MazeCamera.offscreenPointer', () {
    const view = Size(100, 100);

    test('is null while the target is in view', () {
      expect(
        MazeCamera.offscreenPointer(view, const Offset(50, 60), 5),
        isNull,
      );
    });

    test('sits on the edge toward an off-screen target', () {
      expect(
        MazeCamera.offscreenPointer(view, const Offset(300, 50), 5),
        const Offset(95, 50),
      );
      expect(
        MazeCamera.offscreenPointer(view, const Offset(50, -400), 5),
        const Offset(50, 5),
      );
    });
  });
}
