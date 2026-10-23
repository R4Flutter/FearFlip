import 'dart:math';

import 'package:fearflipgame/game/keys/key_hunt.dart';
import 'package:fearflipgame/presentation/gameplay/maze_generator.dart';
import 'package:flutter_test/flutter_test.dart';

/// A maze with every wall shut, then [open] pairs of cells joined.
MazeGrid _maze(int cols, int rows, List<(Point<int>, Point<int>)> open) {
  final cells = List.generate(
    rows,
    (_) => List.generate(cols, (_) => MazeCell()),
  );
  for (final (a, b) in open) {
    if (b.x == a.x + 1) {
      cells[a.y][a.x].right = false;
      cells[b.y][b.x].left = false;
    } else if (b.x == a.x - 1) {
      cells[a.y][a.x].left = false;
      cells[b.y][b.x].right = false;
    } else if (b.y == a.y + 1) {
      cells[a.y][a.x].bottom = false;
      cells[b.y][b.x].top = false;
    } else {
      cells[a.y][a.x].top = false;
      cells[b.y][b.x].bottom = false;
    }
  }
  return MazeGrid(
    rows: rows,
    cols: cols,
    cells: cells,
    start: const Point(0, 0),
    end: Point(cols - 1, rows - 1),
  );
}

KeyBox _box(int x, int y, {bool key = false}) =>
    KeyBox(cell: Point(x, y), hasKey: key, depth: 0, sidePath: [Point(x, y)]);

KeyHuntPlan _plan(List<KeyBox> boxes, {int keysRequired = 2}) => KeyHuntPlan(
  boxes: boxes,
  keysRequired: keysRequired,
  reservedCells: const {},
);

void main() {
  group('KeyHuntController', () {
    test('empty boxes never unseal the exit; the second key does', () {
      final hunt = KeyHuntController()
        ..reset(
          _plan([
            _box(1, 0),
            _box(2, 0, key: true),
            _box(3, 0),
            _box(4, 0),
            _box(5, 0, key: true),
          ]),
        );

      expect(hunt.exitUnsealed, isFalse);
      expect(hunt.openAt(const Point(1, 0), 1), KeyBoxOpenResult.empty);
      expect(hunt.openAt(const Point(3, 0), 2), KeyBoxOpenResult.empty);
      expect(hunt.openAt(const Point(4, 0), 3), KeyBoxOpenResult.empty);
      expect(hunt.exitUnsealed, isFalse);
      expect(hunt.boxesLeft, 2);

      expect(hunt.openAt(const Point(2, 0), 4), KeyBoxOpenResult.key);
      expect(hunt.keysFound, 1);
      expect(hunt.keysLeft, 1);
      expect(hunt.exitUnsealed, isFalse);
      expect(hunt.unsealedAt, isNull);

      expect(hunt.openAt(const Point(5, 0), 5.5), KeyBoxOpenResult.unsealed);
      expect(hunt.exitUnsealed, isTrue);
      expect(hunt.unsealedAt, 5.5);
      expect(hunt.boxesLeft, 0);
    });

    test('a box opens once; cells without a box do nothing', () {
      final hunt = KeyHuntController()
        ..reset(_plan([_box(1, 0, key: true), _box(2, 0, key: true)]));
      expect(hunt.openAt(const Point(1, 0), 1), KeyBoxOpenResult.key);
      expect(hunt.openAt(const Point(1, 0), 2), KeyBoxOpenResult.none);
      expect(hunt.openAt(const Point(7, 7), 3), KeyBoxOpenResult.none);
      expect(hunt.keysFound, 1);
      expect(hunt.boxes.first.openedAt, 1);
    });

    test('the exit needs both the exit cell and enough keys', () {
      const exit = Point(5, 5);
      final hunt = KeyHuntController()
        ..reset(_plan([_box(1, 0, key: true)], keysRequired: 1));
      expect(hunt.canEscape(exit, exit), isFalse);
      hunt.openAt(const Point(1, 0), 0);
      expect(hunt.canEscape(exit, exit), isTrue);
      expect(hunt.canEscape(const Point(4, 5), exit), isFalse);
    });

    test('a stage without a hunt is open from the start', () {
      final hunt = KeyHuntController()..clear();
      expect(hunt.isActive, isFalse);
      expect(hunt.exitUnsealed, isTrue);
      expect(hunt.canEscape(const Point(2, 2), const Point(2, 2)), isTrue);
      expect(hunt.openAt(const Point(1, 1), 0), KeyBoxOpenResult.none);
    });

    test('reset shuts every box again', () {
      final boxes = [_box(1, 0, key: true), _box(2, 0, key: true)];
      final hunt = KeyHuntController()..reset(_plan(boxes));
      hunt.openAt(const Point(1, 0), 0);
      hunt.reset(_plan([_box(1, 0, key: true), _box(2, 0, key: true)]));
      expect(hunt.keysFound, 0);
      expect(hunt.boxesLeft, 2);
      expect(hunt.unsealedAt, isNull);
    });

    test('the nearest box is the shortest walk, not the straight line', () {
      // A U: (0,0)→(1,0)→(2,0)→(2,1)→(1,1)→(0,1). (0,1) is one cell below
      // the start but five steps away; (2,0) is two.
      final maze = _maze(3, 2, const [
        (Point(0, 0), Point(1, 0)),
        (Point(1, 0), Point(2, 0)),
        (Point(2, 0), Point(2, 1)),
        (Point(2, 1), Point(1, 1)),
        (Point(1, 1), Point(0, 1)),
      ]);
      final hunt = KeyHuntController()
        ..reset(_plan([_box(0, 1), _box(2, 0, key: true)]));
      expect(
        hunt.nearestUnopened(maze, const Point(0, 0))!.cell,
        const Point(2, 0),
      );
      hunt.openAt(const Point(2, 0), 0);
      expect(
        hunt.nearestUnopened(maze, const Point(2, 0))!.cell,
        const Point(0, 1),
      );
      hunt.openAt(const Point(0, 1), 0);
      expect(hunt.nearestUnopened(maze, const Point(0, 1)), isNull);
    });

    test('objective cells cover the walks to the exit and every shut box', () {
      // A straight corridor 0..4 with a branch down from (2,0) to (2,1).
      final maze = _maze(5, 2, const [
        (Point(0, 0), Point(1, 0)),
        (Point(1, 0), Point(2, 0)),
        (Point(2, 0), Point(3, 0)),
        (Point(3, 0), Point(4, 0)),
        (Point(2, 0), Point(2, 1)),
        (Point(4, 0), Point(4, 1)),
      ]);
      final hunt = KeyHuntController()..reset(_plan([_box(2, 1, key: true)]));
      final cells = hunt.objectiveCells(maze, const Point(0, 0), maze.end);
      expect(
        cells,
        containsAll(const [Point(0, 0), Point(2, 0), Point(2, 1), Point(4, 1)]),
      );
      expect(cells.contains(const Point(0, 1)), isFalse);
    });
  });
}
