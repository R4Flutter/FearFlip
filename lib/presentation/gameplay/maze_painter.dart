import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../game/trap/trap_fx_renderer.dart';
import '../../game/trap/trap_tile.dart';
import '../../domain/entities/direction4.dart';
import 'maze_camera.dart';
import 'maze_generator.dart';

/// Stand-in colours until the tileset art lands (2D-gameplay-assets.md, Night 32):
/// cold stone in WAKE, blood and bone in NIGHTMARE, no green or pink.
class _World {
  const _World(this.floor, this.wallTop, this.wallFace);

  final Color floor;
  final Color wallTop;
  final Color wallFace;
}

const _wake = _World(Color(0xFF3B4660), Color(0xFFA3AEC4), Color(0xFF55627E));
const _nightmare = _World(
  Color(0xFF4D0E15),
  Color(0xFFD8C3A0),
  Color(0xFF8A6B50),
);
const _void = Color(0xFF0A0A0F);
const _amber = Color(0xFFF2B544);
const _candle = Color(0xFFFFE08A);
const _gold = Color(0xFFFFC83D);
const _spirit = Color(0xFF9CC8F0);
const _danger = Color(0xFFE03A32);

class MazePainter extends CustomPainter {
  MazePainter({
    required this.maze,
    required this.playerCellPosition,
    required this.direction,
    required this.currentFrame,
    required this.isMoving,
    required this.pulse,
    this.time = 0,
    this.playerFrames,
    this.exitPortalSprite,
    this.devilCell,
    this.devilFrames,
    this.safeZones = const <Point<int>, double>{},
    this.playerSafe = false,
    this.isFlippedMode = false,
    this.trapTiles = const <TrapTile>[],
    this.trapHiddenCueLevel = 0.0,
    this.breakingTrapTexture,
    this.hidePlayer = false,
  });

  final MazeGrid maze;
  final Offset playerCellPosition;
  final Direction4 direction;
  final int currentFrame;
  final bool isMoving;
  final double pulse;
  final double time;
  final List<ui.Image>? playerFrames;
  final ui.Image? exitPortalSprite;
  final Point<int>? devilCell;
  final List<ui.Image>? devilFrames;
  final Map<Point<int>, double> safeZones;
  final bool playerSafe;
  final bool isFlippedMode;
  final List<TrapTile> trapTiles;
  final double trapHiddenCueLevel;
  final ui.Image? breakingTrapTexture;
  final bool hidePlayer;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _void);

    final camera = MazeCamera.follow(
      viewport: size,
      maze: maze,
      focus: playerCellPosition,
    );
    final cellSize = camera.tileSize;
    _paintTiles(canvas, size, camera);

    // ── Trap tiles (rendered between walls and entities) ──
    if (trapTiles.isNotEmpty) {
      const trapRenderer = TrapFxRenderer();
      trapRenderer.renderTiles(
        canvas,
        origin: camera.cellOrigin,
        cellSize: cellSize,
        cellStride: cellSize * 2,
        tiles: trapTiles,
        // Both worlds have dark floors now, so the dark-floor look fits both.
        isFlippedMode: false,
        hiddenCueLevel: trapHiddenCueLevel,
        revealedTileTexture: breakingTrapTexture,
      );
    }

    final startCenter = camera.cellCenter(_offsetOf(maze.start));
    final startRing = Paint()
      ..color = _amber.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.5, cellSize * 0.07);
    canvas.drawCircle(startCenter, cellSize * (0.3 + pulse * 0.04), startRing);

    final portal = exitPortalSprite;
    if (portal != null) {
      final endCenter = camera.cellCenter(_offsetOf(maze.end));
      final gateSide = cellSize * (0.92 + sin(time * 2.4) * 0.05);
      final gateGlow = Paint()
        ..color = _gold.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
      canvas.drawCircle(endCenter, gateSide * 0.55, gateGlow);
      final cropSide = min(portal.width, portal.height).toDouble();
      final src = Rect.fromCenter(
        center: Offset(portal.width / 2, portal.height / 2),
        width: cropSide,
        height: cropSide,
      );
      final dst = Rect.fromCenter(
        center: endCenter,
        width: gateSide,
        height: gateSide,
      );
      canvas.drawImageRect(
        portal,
        src,
        dst,
        Paint()..filterQuality = FilterQuality.medium,
      );
    } else {
      final endTileRect = camera.cellRect(maze.end).deflate(cellSize * 0.14);
      final endGlow = Paint()
        ..color = _gold.withValues(alpha: 0.65)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
      final endCore = Paint()..color = _gold;
      final endBorder = Paint()
        ..color = const Color(0xFF7A5A00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.6, cellSize * 0.06);
      canvas.drawRect(endTileRect.inflate(cellSize * 0.06), endGlow);
      canvas.drawRect(endTileRect, endCore);
      canvas.drawRect(endTileRect, endBorder);
    }

    if (safeZones.isNotEmpty) {
      for (final entry in safeZones.entries) {
        final zoneRect = camera.cellRect(entry.key).deflate(cellSize * 0.14);
        final strength = entry.value.clamp(0.0, 1.0);
        final glow = Paint()
          ..color = _spirit.withValues(alpha: 0.2 + strength * 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
        final core = Paint()
          ..color = _spirit.withValues(alpha: 0.15 + strength * 0.35);
        final border = Paint()
          ..color = _spirit.withValues(alpha: 0.5 + strength * 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.6, cellSize * 0.06);
        canvas.drawRect(zoneRect.inflate(cellSize * 0.06), glow);
        canvas.drawRect(zoneRect, core);
        canvas.drawRect(zoneRect, border);
      }
    }

    final playerCenter = camera.cellCenter(playerCellPosition);
    final breath = isMoving ? 0.0 : sin(time * 2.2) * 0.03;
    final playerSide = cellSize * 0.9 * (1 + breath);

    if (!hidePlayer) {
      if (playerFrames != null && playerFrames!.isNotEmpty) {
        _drawSpriteCharacter(canvas, playerCenter, playerSide);
      } else {
        final playerGlow = Paint()
          ..color = _amber.withValues(alpha: 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        final playerCore = Paint()..color = _candle;
        canvas.drawCircle(playerCenter, playerSide * 0.35, playerGlow);
        canvas.drawCircle(playerCenter, playerSide * 0.28, playerCore);
      }

      if (playerSafe) {
        final ring = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = _spirit;
        canvas.drawCircle(playerCenter, playerSide * 0.42, ring);
      }
    }

    final devil = devilCell;
    if (devil != null) {
      final devilCenter = camera
          .cellCenter(_offsetOf(devil))
          .translate(0, sin(time * 3.4) * cellSize * 0.07);
      final frames = devilFrames;
      if (frames != null && frames.isNotEmpty) {
        final devilFrame = (time * 9).floor() % frames.length;
        _drawFrame(
          canvas: canvas,
          image: frames[devilFrame],
          center: devilCenter,
          side: cellSize * 0.95,
          facing: playerCellPosition.dx < devil.x
              ? Direction4.left
              : Direction4.right,
        );
      } else {
        // Stand-in until the devil sheets land: a shadow with burning eyes.
        canvas.drawCircle(
          devilCenter,
          cellSize * 0.42,
          Paint()
            ..color = _danger.withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        canvas.drawCircle(devilCenter, cellSize * 0.32, Paint()..color = _void);
        final eye = Paint()..color = _danger;
        final eyeY = devilCenter.dy - cellSize * 0.05;
        canvas.drawCircle(
          Offset(devilCenter.dx - cellSize * 0.1, eyeY),
          cellSize * 0.05,
          eye,
        );
        canvas.drawCircle(
          Offset(devilCenter.dx + cellSize * 0.1, eyeY),
          cellSize * 0.05,
          eye,
        );
      }
    }

    // The camera hides most of the maze, so point at what matters off screen:
    // the exit always, the Devil once it's close enough to be a threat.
    _drawPointer(
      canvas,
      size,
      camera.cellCenter(_offsetOf(maze.end)),
      _gold,
      cellSize,
    );
    if (devil != null &&
        (_offsetOf(devil) - playerCellPosition).distance <= _devilWarnCells) {
      _drawPointer(
        canvas,
        size,
        camera.cellCenter(_offsetOf(devil)),
        _danger,
        cellSize,
      );
    }
  }

  /// How near (in cells) the Devil must be before its off-screen arrow shows.
  static const double _devilWarnCells = 8;

  void _drawSpriteCharacter(Canvas canvas, Offset center, double side) {
    final frames = playerFrames!;
    final frameIndex = isMoving
        ? currentFrame.clamp(0, frames.length - 1)
        : 0;
    _drawFrame(
      canvas: canvas,
      image: frames[frameIndex],
      center: center,
      side: side,
      facing: direction,
    );
  }

  void _drawFrame({
    required Canvas canvas,
    required ui.Image image,
    required Offset center,
    required double side,
    required Direction4 facing,
  }) {
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final dst = Rect.fromCenter(center: Offset.zero, width: side, height: side);
    final spritePaint = Paint()..filterQuality = FilterQuality.medium;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    switch (facing) {
      case Direction4.right:
        break;
      case Direction4.left:
        canvas.scale(-1, 1);
        break;
      case Direction4.up:
        break;
      case Direction4.down:
        break;
    }

    canvas.drawImageRect(image, src, dst, spritePaint);
    canvas.restore();
  }

  /// Floor and wall tiles in view. Walls are whole tiles, raised like the
  /// reference art: a light top, and a darker front face wherever floor lies
  /// below, which casts a short shadow onto that floor.
  void _paintTiles(Canvas canvas, Size size, MazeCamera camera) {
    final world = isFlippedMode ? _nightmare : _wake;
    final tile = camera.tileSize;
    // No anti-aliasing: neighbouring tiles share exact edges, so no seams.
    final floor = Paint()
      ..color = world.floor
      ..isAntiAlias = false;
    final top = Paint()
      ..color = world.wallTop
      ..isAntiAlias = false;
    final face = Paint()
      ..color = world.wallFace
      ..isAntiAlias = false;
    final shadow = Paint()
      ..color = const Color(0x55000000)
      ..isAntiAlias = false;

    final firstCol = max(0, (-camera.origin.dx / tile).floor());
    final firstRow = max(0, (-camera.origin.dy / tile).floor());
    final lastCol = min(
      2 * maze.cols,
      ((size.width - camera.origin.dx) / tile).ceil(),
    );
    final lastRow = min(
      2 * maze.rows,
      ((size.height - camera.origin.dy) / tile).ceil(),
    );

    for (var row = firstRow; row <= lastRow; row++) {
      for (var col = firstCol; col <= lastCol; col++) {
        final rect = camera.tileRect(col, row);
        if (!isWallTile(maze, col, row)) {
          canvas.drawRect(rect, floor);
          if (isWallTile(maze, col, row - 1)) {
            canvas.drawRect(
              Rect.fromLTWH(rect.left, rect.top, rect.width, tile * 0.18),
              shadow,
            );
          }
          continue;
        }
        canvas.drawRect(rect, top);
        if (!isWallTile(maze, col, row + 1)) {
          canvas.drawRect(
            Rect.fromLTWH(
              rect.left,
              rect.bottom - tile * 0.38,
              rect.width,
              tile * 0.38,
            ),
            face,
          );
        }
      }
    }
  }

  /// A triangle at the edge of the view pointing at [target], when off screen.
  void _drawPointer(
    Canvas canvas,
    Size size,
    Offset target,
    Color color,
    double tile,
  ) {
    final at = MazeCamera.offscreenPointer(size, target, tile * 0.55);
    if (at == null) {
      return;
    }
    final direction = target - at;
    final r = tile * 0.32;
    final arrow = Path()
      ..moveTo(r, 0)
      ..lineTo(-r * 0.7, r * 0.75)
      ..lineTo(-r * 0.7, -r * 0.75)
      ..close();
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(atan2(direction.dy, direction.dx));
    canvas.drawPath(
      arrow,
      Paint()
        ..color = _void.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawPath(
      arrow,
      Paint()..color = color.withValues(alpha: 0.65 + 0.3 * pulse),
    );
    canvas.restore();
  }

  Offset _offsetOf(Point<int> cell) =>
      Offset(cell.x.toDouble(), cell.y.toDouble());

  @override
  bool shouldRepaint(covariant MazePainter oldDelegate) {
    return oldDelegate.maze != maze ||
        oldDelegate.playerCellPosition != playerCellPosition ||
        oldDelegate.direction != direction ||
        oldDelegate.currentFrame != currentFrame ||
        oldDelegate.isMoving != isMoving ||
        oldDelegate.playerFrames != playerFrames ||
        oldDelegate.devilFrames != devilFrames ||
        oldDelegate.devilCell != devilCell ||
        oldDelegate.playerSafe != playerSafe ||
        oldDelegate.isFlippedMode != isFlippedMode ||
        oldDelegate.safeZones != safeZones ||
        oldDelegate.trapTiles != trapTiles ||
        oldDelegate.trapHiddenCueLevel != trapHiddenCueLevel ||
        oldDelegate.breakingTrapTexture != breakingTrapTexture ||
        oldDelegate.hidePlayer != hidePlayer ||
        oldDelegate.exitPortalSprite != exitPortalSprite ||
        oldDelegate.time != time ||
        oldDelegate.pulse != pulse;
  }
}
