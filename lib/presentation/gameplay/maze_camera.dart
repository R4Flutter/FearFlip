import 'dart:math';
import 'dart:ui';

import 'maze_generator.dart';

/// The Pokémon-style view of a maze: walls are whole tiles (a maze of N×N cells
/// is drawn as a (2N+1)×(2N+1) block grid, cell (x, y) on tile (2x+1, 2y+1)) and
/// the camera follows the runner instead of fitting the whole maze on screen.
///
/// The game logic stays cell-based; only drawing goes through this class.
class MazeCamera {
  const MazeCamera._(this.tileSize, this.origin);

  /// Tiles across the view. Fewer = bigger sprites but less of the maze in view.
  static const double visibleTiles = 11;

  /// A camera centred on [focus] (a cell position, fractional while moving),
  /// clamped so it never shows past the maze's outer wall.
  factory MazeCamera.follow({
    required Size viewport,
    required MazeGrid maze,
    required Offset focus,
  }) {
    final tileSize = min(viewport.width, viewport.height) / visibleTiles;

    double axis(double view, int cells, double focusCell) {
      final world = (2 * cells + 1) * tileSize;
      if (world <= view) return (view - world) / 2;
      final centre = tileCentre(focusCell) * tileSize;
      return -(centre - view / 2).clamp(0.0, world - view);
    }

    return MazeCamera._(
      tileSize,
      Offset(
        axis(viewport.width, maze.cols, focus.dx).roundToDouble(),
        axis(viewport.height, maze.rows, focus.dy).roundToDouble(),
      ),
    );
  }

  /// Side of one block tile on screen.
  final double tileSize;

  /// Screen position of the top-left corner of block tile (0, 0).
  final Offset origin;

  /// Block-grid coordinate of the centre of cell coordinate [cell].
  static double tileCentre(double cell) => 2 * cell + 1.5;

  /// Screen position of cell (0, 0)'s tile; cells sit every 2 tiles from here.
  Offset get cellOrigin => origin + Offset(tileSize, tileSize);

  Offset cellCenter(Offset cell) =>
      origin + Offset(tileCentre(cell.dx), tileCentre(cell.dy)) * tileSize;

  Rect cellRect(Point<int> cell) => Rect.fromCenter(
    center: cellCenter(Offset(cell.x.toDouble(), cell.y.toDouble())),
    width: tileSize,
    height: tileSize,
  );

  Rect tileRect(int col, int row) => Rect.fromLTWH(
    origin.dx + col * tileSize,
    origin.dy + row * tileSize,
    tileSize,
    tileSize,
  );

  /// Where to draw an arrow toward [target] when it's off screen: the point on
  /// the view's edge (pulled in by [inset]) in its direction. Null when visible.
  static Offset? offscreenPointer(Size view, Offset target, double inset) {
    final area = (Offset.zero & view).deflate(inset);
    if (area.contains(target)) return null;
    final centre = area.center;
    final d = target - centre;
    final sx = d.dx == 0 ? double.infinity : (area.width / 2) / d.dx.abs();
    final sy = d.dy == 0 ? double.infinity : (area.height / 2) / d.dy.abs();
    return centre + d * min(sx, sy);
  }
}

/// Whether block tile ([col], [row]) of [maze]'s (2N+1)×(2N+1) grid is a wall.
///
/// Mirrors the old line renderer: an edge is a wall when the cell below (or to
/// the right) has its top (left) wall; the outer border uses the last row's
/// bottom and the last column's right. A corner post stands only where a wall
/// touches it, so loops in the maze open into rooms. Outside the grid is wall.
bool isWallTile(MazeGrid maze, int col, int row) {
  if (col < 0 || row < 0 || col > 2 * maze.cols || row > 2 * maze.rows) {
    return true;
  }
  if (col.isOdd && row.isOdd) return false;
  if (col.isOdd) {
    final x = (col - 1) ~/ 2;
    final y = row ~/ 2;
    return y == maze.rows ? maze.cells[y - 1][x].bottom : maze.cells[y][x].top;
  }
  if (row.isOdd) {
    final x = col ~/ 2;
    final y = (row - 1) ~/ 2;
    return x == maze.cols ? maze.cells[y][x - 1].right : maze.cells[y][x].left;
  }
  return isWallTile(maze, col - 1, row) ||
      isWallTile(maze, col + 1, row) ||
      isWallTile(maze, col, row - 1) ||
      isWallTile(maze, col, row + 1);
}
