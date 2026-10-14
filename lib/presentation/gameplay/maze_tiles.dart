import 'dart:math';

import '../../domain/entities/direction4.dart';
import '../../game/trap/trap_tile.dart';
import 'maze_generator.dart';

/// Slots of the `tiles/<world>_tiles.png` atlases (tool/process_2d_assets.py).
/// Every slot is a full tile; rims, corners and faces are transparent outside
/// their strip, so a wall is drawn by stacking slots on the same tile rect.
abstract final class TileSlot {
  static const floor0 = 0; // 6 floors
  static const extra0 = 6; // 6 rarer floors (cracks, puddles, gore)
  static const fill0 = 12; // 2 wall tops
  static const rimTop = 14;
  static const rimBottom = 15; // unused: floor below shows the face instead
  static const rimLeft = 16;
  static const rimRight = 17;
  static const cornerTL = 18;
  static const cornerTR = 19;
  static const cornerBL = 20;
  static const cornerBR = 21;
  static const face0 = 22; // 2 faces: capstones over the rock face
}

/// A fixed pseudo-random number per tile, so variety never flickers.
int tileHash(int col, int row) {
  var h = col * 374761393 + row * 668265263;
  h = (h ^ (h >> 13)) * 1274126177;
  return (h ^ (h >> 16)) & 0x7fffffff;
}

/// The atlas slots to stack, in order, for block tile ([col], [row]).
///
/// A wall top gets capstones along every side that borders floor, corner caps
/// where two rims meet (outer) or where a diagonal floor notches it (inner),
/// and its rock face when the tile below is floor. Floors pick a variant.
List<int> tileLayers(bool Function(int col, int row) wall, int col, int row) {
  final h = tileHash(col, row);
  if (!wall(col, row)) {
    final pick = h ~/ 9 % 6;
    return [h % 9 == 0 ? TileSlot.extra0 + pick : TileSlot.floor0 + pick];
  }
  final n = wall(col, row - 1);
  final s = wall(col, row + 1);
  final w = wall(col - 1, row);
  final e = wall(col + 1, row);
  return [
    TileSlot.fill0 + h % 2,
    if (!n) TileSlot.rimTop,
    if (!w) TileSlot.rimLeft,
    if (!e) TileSlot.rimRight,
    if (!n && !w || n && w && !wall(col - 1, row - 1)) TileSlot.cornerTL,
    if (!n && !e || n && e && !wall(col + 1, row - 1)) TileSlot.cornerTR,
    if (s && w && !wall(col - 1, row + 1)) TileSlot.cornerBL,
    if (s && e && !wall(col + 1, row + 1)) TileSlot.cornerBR,
    if (!s) TileSlot.face0 + (h >> 1) % 2,
  ];
}

/// Whether a torch hangs on block tile ([col], [row]): only on a rock face
/// (a wall with floor below), about one face in seven.
bool hasTorch(bool Function(int col, int row) wall, int col, int row) =>
    wall(col, row) && !wall(col, row + 1) && tileHash(col, row) % 7 == 3;

/// The prop (0..7 of the world's sheet) lying in [cell], or null. Dead ends
/// always get one, so they double as landmarks; corridors one in eleven. The
/// start, the exit and [keepClear] (safe zones, traps) stay bare.
int? propAt(
  MazeGrid maze,
  Point<int> cell, {
  Set<Point<int>> keepClear = const {},
}) {
  if (cell == maze.start || cell == maze.end || keepClear.contains(cell)) {
    return null;
  }
  final h = tileHash(cell.x * 2 + 1, cell.y * 2 + 1);
  final deadEnd =
      Direction4.values.where((d) => maze.canMove(cell, d)).length == 1;
  if (!deadEnd && h % 11 != 5) {
    return null;
  }
  return (h >> 3) % 8;
}

/// Which frame of a trap strip shows a trap in [state]: frame 1 cracked, the
/// last one collapsed; critical crumbles (on longer strips it shakes between
/// two frames). Hidden traps show nothing.
int? trapFrame(TrapState state, int frames, double time) => switch (state) {
  TrapState.hidden => null,
  TrapState.cracked => 1,
  TrapState.critical => frames > 4 ? 2 + (time * 8).floor() % 2 : 2,
  TrapState.collapsed => frames - 1,
};
