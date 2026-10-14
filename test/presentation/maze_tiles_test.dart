import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:fearflipgame/game/trap/trap_tile.dart';
import 'package:fearflipgame/presentation/gameplay/maze_generator.dart';
import 'package:fearflipgame/presentation/gameplay/maze_tiles.dart';

/// Wall test over ASCII rows: '#' is wall, anything else floor, outside wall.
bool Function(int, int) grid(List<String> rows) =>
    (c, r) =>
        r < 0 ||
        r >= rows.length ||
        c < 0 ||
        c >= rows[r].length ||
        rows[r][c] == '#';

/// A one-row corridor of [n] joined cells; its two ends are dead ends.
MazeGrid corridor(int n, {Point<int>? start, Point<int>? end}) {
  final cells = [List.generate(n, (_) => MazeCell())];
  for (var x = 0; x < n - 1; x++) {
    cells[0][x].right = false;
    cells[0][x + 1].left = false;
  }
  return MazeGrid(
    rows: 1,
    cols: n,
    cells: cells,
    start: start ?? const Point<int>(1, 0),
    end: end ?? Point<int>(n - 2, 0),
  );
}

const _fills = [TileSlot.fill0, TileSlot.fill0 + 1];
const _faces = [TileSlot.face0, TileSlot.face0 + 1];

void main() {
  group('tileLayers', () {
    test('floor tiles draw one floor or extra slot', () {
      final wall = grid(['....', '....', '....']);
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 4; c++) {
          final layers = tileLayers(wall, c, r);
          expect(layers, hasLength(1));
          expect(
            layers.single,
            inInclusiveRange(TileSlot.floor0, TileSlot.extra0 + 5),
          );
        }
      }
    });

    test('a wall between two corridors: capstones on top, face below', () {
      final layers = tileLayers(grid(['...', '###', '...']), 1, 1);
      expect(_fills, contains(layers.first));
      expect(layers.sublist(1, layers.length - 1), [TileSlot.rimTop]);
      expect(_faces, contains(layers.last));
    });

    test('a wall between two side corridors: capstones left and right', () {
      final layers = tileLayers(grid(['.#.', '.#.', '.#.']), 1, 1);
      expect(layers.sublist(1), [TileSlot.rimLeft, TileSlot.rimRight]);
    });

    test('an outer corner caps where two rims meet', () {
      final layers = tileLayers(grid(['...', '.##', '.##']), 1, 1);
      expect(layers.sublist(1), [
        TileSlot.rimTop,
        TileSlot.rimLeft,
        TileSlot.cornerTL,
      ]);
    });

    test('an inner corner fills the notch between two rims', () {
      final layers = tileLayers(grid(['.##', '###', '###']), 1, 1);
      expect(layers.sublist(1), [TileSlot.cornerTL]);
    });

    test('a bottom inner corner caps too, a wall with floor below shows no '
        'bottom corners', () {
      expect(tileLayers(grid(['###', '###', '##.']), 1, 1).sublist(1), [
        TileSlot.cornerBR,
      ]);
      final faced = tileLayers(grid(['###', '###', '...']), 1, 1);
      expect(faced, isNot(contains(TileSlot.cornerBL)));
      expect(faced, isNot(contains(TileSlot.cornerBR)));
      expect(_faces, contains(faced.last));
    });

    test('a solid block draws only its fill', () {
      final layers = tileLayers(grid(['###', '###', '###']), 1, 1);
      expect(layers, hasLength(1));
      expect(_fills, contains(layers.single));
    });

    test('variety is fixed per tile, so the floor never flickers', () {
      final wall = grid(['...', '...', '...']);
      expect(tileLayers(wall, 2, 1), tileLayers(wall, 2, 1));
    });
  });

  group('hasTorch', () {
    test('torches hang only on wall faces above floor, now and then', () {
      final wall = grid([
        for (var i = 0; i < 40; i++) i.isEven ? '#' * 40 : '.' * 40,
      ]);
      var faces = 0;
      var torches = 0;
      for (var r = 0; r < 40; r++) {
        for (var c = 0; c < 40; c++) {
          final lit = hasTorch(wall, c, r);
          if (r.isOdd) {
            expect(lit, isFalse); // floor
          } else {
            faces++;
            if (lit) torches++;
          }
        }
      }
      expect(torches / faces, inInclusiveRange(0.06, 0.22));
    });

    test('a wall with wall below shows no face, so no torch', () {
      final wall = grid(['#' * 30, '#' * 30, '#' * 30]);
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 30; c++) {
          expect(hasTorch(wall, c, r), isFalse);
        }
      }
    });
  });

  group('propAt', () {
    test('dead ends always get a prop, the start and exit never', () {
      final maze = corridor(5);
      expect(propAt(maze, const Point<int>(0, 0)), inInclusiveRange(0, 7));
      expect(propAt(maze, const Point<int>(4, 0)), inInclusiveRange(0, 7));
      expect(propAt(maze, maze.start), isNull);
      expect(propAt(maze, maze.end), isNull);
    });

    test('kept-clear cells (safe zones, traps) stay bare', () {
      final maze = corridor(5);
      expect(
        propAt(maze, const Point<int>(0, 0), keepClear: {const Point(0, 0)}),
        isNull,
      );
    });

    test('corridors get one now and then, fixed per cell', () {
      final maze = corridor(400, start: const Point(0, 0));
      var props = 0;
      for (var x = 1; x < 398; x++) {
        final cell = Point<int>(x, 0);
        if (propAt(maze, cell) != null) props++;
        expect(propAt(maze, cell), propAt(maze, cell));
      }
      expect(props / 397, inInclusiveRange(0.03, 0.2));
    });
  });

  group('trapFrame', () {
    test('WAKE (4 frames): hidden draws nothing, then crack, crumble, pit', () {
      expect(trapFrame(TrapState.hidden, 4, 0), isNull);
      expect(trapFrame(TrapState.cracked, 4, 0), 1);
      expect(trapFrame(TrapState.critical, 4, 0), 2);
      expect(trapFrame(TrapState.critical, 4, 0.13), 2);
      expect(trapFrame(TrapState.collapsed, 4, 0), 3);
    });

    test('NIGHTMARE (8 frames): the critical slab shakes, the pit glows', () {
      final shaking = {
        for (var t = 0.0; t < 1; t += 0.05) trapFrame(TrapState.critical, 8, t),
      };
      expect(shaking, {2, 3});
      expect(trapFrame(TrapState.collapsed, 8, 0), 7);
    });
  });
}
