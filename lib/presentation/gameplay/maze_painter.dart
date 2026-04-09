import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'maze_generator.dart';

class MazePainter extends CustomPainter {
  MazePainter({
    required this.maze,
    required this.pathPoints,
    required this.playerCellPosition,
    required this.direction,
    required this.currentFrame,
    required this.isMoving,
    required this.pulse,
    this.playerSprite,
    this.spriteFrameCount = 8,
    this.spriteRows = 1,
    this.spriteRowIndex = 0,
    this.devilCell,
    this.devilSprite,
    this.devilSpriteRowIndex = 0,
    this.safeZones = const <Point<int>, double>{},
    this.playerSafe = false,
    this.isFlippedMode = false,
  });

  final MazeGrid maze;
  final List<Offset> pathPoints;
  final Offset playerCellPosition;
  final Direction4 direction;
  final int currentFrame;
  final bool isMoving;
  final double pulse;
  final ui.Image? playerSprite;
  final int spriteFrameCount;
  final int spriteRows;
  final int spriteRowIndex;
  final Point<int>? devilCell;
  final ui.Image? devilSprite;
  final int devilSpriteRowIndex;
  final Map<Point<int>, double> safeZones;
  final bool playerSafe;
  final bool isFlippedMode;

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

    final startCenter = _cellCenter(origin, cellSize, maze.start);
    final startGlow = Paint()
      ..color = const Color(0xAA00FFAA)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    final startCore = Paint()..color = const Color(0xFF00FFAA);
    final startRadius = cellSize * (0.14 + pulse * 0.04);
    canvas.drawCircle(startCenter, cellSize * 0.22 + pulse * 2.5, startGlow);
    canvas.drawCircle(startCenter, startRadius, startCore);

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
    final playerSide = cellSize * 0.78;

    if (playerSprite != null) {
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

    final devil = devilCell;
    if (devil != null) {
      final devilCenter = _cellCenter(origin, cellSize, devil);
      final image = devilSprite;
      if (image != null) {
        _drawCharacterSprite(
          canvas: canvas,
          image: image,
          center: devilCenter,
          side: cellSize * 0.82,
          rowIndex: devilSpriteRowIndex,
          facing: direction,
          frame: (currentFrame + 2) % spriteFrameCount,
        );
      } else {
        final silhouette = Paint()..color = const Color(0xFF1B1B1B);
        canvas.drawCircle(devilCenter, cellSize * 0.24, silhouette);
      }
    }
  }

  void _drawSpriteCharacter(Canvas canvas, Offset center, double side) {
    final image = playerSprite!;
    _drawCharacterSprite(
      canvas: canvas,
      image: image,
      center: center,
      side: side,
      rowIndex: spriteRowIndex,
      facing: direction,
      frame: isMoving ? currentFrame.clamp(0, spriteFrameCount - 1) : 0,
    );
  }

  void _drawCharacterSprite({
    required Canvas canvas,
    required ui.Image image,
    required Offset center,
    required double side,
    required int rowIndex,
    required Direction4 facing,
    required int frame,
  }) {
    final frameW = image.width / spriteFrameCount;
    final frameH = image.height / spriteRows;
    final row = rowIndex.clamp(0, spriteRows - 1);

    final src = Rect.fromLTWH(frame * frameW, row * frameH, frameW, frameH);
    final dst = Rect.fromCenter(center: Offset.zero, width: side, height: side);
    final spritePaint = Paint()..filterQuality = FilterQuality.none;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    switch (facing) {
      case Direction4.right:
        break;
      case Direction4.left:
        canvas.scale(-1, 1);
        break;
      case Direction4.up:
        canvas.rotate(-pi / 2);
        break;
      case Direction4.down:
        canvas.rotate(pi / 2);
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
        oldDelegate.pathPoints != pathPoints ||
        oldDelegate.playerCellPosition != playerCellPosition ||
        oldDelegate.direction != direction ||
        oldDelegate.currentFrame != currentFrame ||
        oldDelegate.isMoving != isMoving ||
        oldDelegate.playerSprite != playerSprite ||
        oldDelegate.devilSprite != devilSprite ||
        oldDelegate.devilSpriteRowIndex != devilSpriteRowIndex ||
        oldDelegate.spriteFrameCount != spriteFrameCount ||
        oldDelegate.spriteRows != spriteRows ||
        oldDelegate.spriteRowIndex != spriteRowIndex ||
        oldDelegate.devilCell != devilCell ||
        oldDelegate.playerSafe != playerSafe ||
        oldDelegate.isFlippedMode != isFlippedMode ||
        oldDelegate.safeZones != safeZones ||
        oldDelegate.pulse != pulse;
  }
}
