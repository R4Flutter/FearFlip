import 'package:flutter_test/flutter_test.dart';

import 'package:fearflipgame/presentation/gameplay/maze_tiles.dart';

/// Wall test over ASCII rows: '#' is wall, anything else floor, outside wall.
bool Function(int, int) grid(List<String> rows) =>
    (c, r) =>
        r < 0 ||
        r >= rows.length ||
        c < 0 ||
        c >= rows[r].length ||
        rows[r][c] == '#';

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
}
