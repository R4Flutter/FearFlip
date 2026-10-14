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
