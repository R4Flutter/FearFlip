import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../game/trap/trap_fx_renderer.dart';
import '../../game/trap/trap_tile.dart';
import '../../domain/entities/direction4.dart';
import 'maze_generator.dart';

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
    final pathColor = isFlippedMode
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF0D0D0D);
    final wallColor = isFlippedMode
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);

    canvas.drawRect(Offset.zero & size, Paint()..color = pathColor);

    final cellSize = min(size.width / maze.cols, size.height / maze.rows);
    final mazeWidth = cellSize * maze.cols;
    final mazeHeight = cellSize * maze.rows;
    final origin = Offset(
      (size.width - mazeWidth) * 0.5,
      (size.height - mazeHeight) * 0.5,
    );

    final wallPaint = Paint()
      ..color = wallColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.square
      ..isAntiAlias = false;

    for (var row = 0; row < maze.rows; row++) {
      for (var col = 0; col < maze.cols; col++) {
        final cell = maze.cells[row][col];
        final x = origin.dx + col * cellSize;
        final y = origin.dy + row * cellSize;
        final leftTop = Offset(x, y);
        final rightTop = Offset(x + cellSize, y);
        final leftBottom = Offset(x, y + cellSize);
        final rightBottom = Offset(x + cellSize, y + cellSize);

        if (cell.top) {
          canvas.drawLine(leftTop, rightTop, wallPaint);
        }
        if (cell.left) {
          canvas.drawLine(leftTop, leftBottom, wallPaint);
        }
        if (row == maze.rows - 1 && cell.bottom) {
          canvas.drawLine(leftBottom, rightBottom, wallPaint);
        }
        if (col == maze.cols - 1 && cell.right) {
          canvas.drawLine(rightTop, rightBottom, wallPaint);
        }
      }
    }

    // ── Trap tiles (rendered between walls and entities) ──
    if (trapTiles.isNotEmpty) {
      const trapRenderer = TrapFxRenderer();
      trapRenderer.renderTiles(
        canvas,
        origin: origin,
        cellSize: cellSize,
        tiles: trapTiles,
        isFlippedMode: isFlippedMode,
        hiddenCueLevel: trapHiddenCueLevel,
        revealedTileTexture: breakingTrapTexture,
      );
    }

    final startCenter = _cellCenter(origin, cellSize, maze.start);
    final startGlow = Paint()
      ..color = const Color(0xAA00FFAA)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    final startCore = Paint()..color = const Color(0xFF00FFAA);
    final startRadius = cellSize * (0.14 + pulse * 0.04);
    canvas.drawCircle(startCenter, cellSize * 0.22 + pulse * 2.5, startGlow);
    canvas.drawCircle(startCenter, startRadius, startCore);

    final portal = exitPortalSprite;
    if (portal != null) {
      final endCenter = _cellCenter(origin, cellSize, maze.end);
      final gateSide = cellSize * (0.92 + sin(time * 2.4) * 0.05);
      final gateGlow = Paint()
        ..color = const Color(0x88FFD700)
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
      final endTileRect = _cellRect(
        origin,
        cellSize,
        maze.end,
      ).deflate(cellSize * 0.14);
      final endGlow = Paint()
        ..color = const Color(0xAAFFD700)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
      final endCore = Paint()..color = const Color(0xFFFFD700);
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
        final zoneRect = _cellRect(
          origin,
          cellSize,
          entry.key,
        ).deflate(cellSize * 0.14);
        final strength = entry.value.clamp(0.0, 1.0);
        final glow = Paint()
          ..color = const Color(
            0x9900FF9D,
          ).withValues(alpha: 0.2 + strength * 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
        final core = Paint()
          ..color = const Color(
            0xFF00FF9D,
          ).withValues(alpha: 0.30 + strength * 0.70);
        final border = Paint()
          ..color = const Color(0xFF00A86B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.6, cellSize * 0.06);
        canvas.drawRect(zoneRect.inflate(cellSize * 0.06), glow);
        canvas.drawRect(zoneRect, core);
        canvas.drawRect(zoneRect, border);
      }
    }

    final playerCenter = _cellCenterFromPosition(
      origin,
      cellSize,
      playerCellPosition,
    );
    final breath = isMoving ? 0.0 : sin(time * 2.2) * 0.03;
    final playerSide = cellSize * 0.78 * (1 + breath);

    if (!hidePlayer) {
      if (playerFrames != null && playerFrames!.isNotEmpty) {
        _drawSpriteCharacter(canvas, playerCenter, playerSide);
      } else {
        final playerGlow = Paint()
          ..color = const Color(0x8800FFAA)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        final playerCore = Paint()..color = const Color(0xFF00FFAA);
        canvas.drawCircle(playerCenter, playerSide * 0.35, playerGlow);
        canvas.drawCircle(playerCenter, playerSide * 0.28, playerCore);
      }

      if (playerSafe) {
        final ring = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = const Color(0xFF00FF9D);
        canvas.drawCircle(playerCenter, playerSide * 0.42, ring);
      }
    }

    final devil = devilCell;
    if (devil != null) {
      final devilCenter = _cellCenter(
        origin,
        cellSize,
        devil,
      ).translate(0, sin(time * 3.4) * cellSize * 0.07);
      final frames = devilFrames;
      if (frames != null && frames.isNotEmpty) {
        final devilFrame = (time * 9).floor() % frames.length;
        _drawFrame(
          canvas: canvas,
          image: frames[devilFrame],
          center: devilCenter,
          side: cellSize * 0.82,
          facing: playerCellPosition.dx < devil.x
              ? Direction4.left
              : Direction4.right,
        );
      } else {
        final silhouette = Paint()..color = const Color(0xFF1B1B1B);
        canvas.drawCircle(devilCenter, cellSize * 0.24, silhouette);
      }
    }
  }

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

  Offset _cellCenter(Offset origin, double cellSize, Point<int> cell) {
    return Offset(
      origin.dx + (cell.x + 0.5) * cellSize,
      origin.dy + (cell.y + 0.5) * cellSize,
    );
  }

  Rect _cellRect(Offset origin, double cellSize, Point<int> cell) {
    return Rect.fromLTWH(
      origin.dx + cell.x * cellSize,
      origin.dy + cell.y * cellSize,
      cellSize,
      cellSize,
    );
  }

  Offset _cellCenterFromPosition(Offset origin, double cellSize, Offset pos) {
    return Offset(
      origin.dx + (pos.dx + 0.5) * cellSize,
      origin.dy + (pos.dy + 0.5) * cellSize,
    );
  }

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
