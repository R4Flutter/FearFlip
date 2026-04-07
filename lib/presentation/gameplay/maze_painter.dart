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

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0D0D0D),
    );

    final cellSize = min(size.width / maze.cols, size.height / maze.rows);
    final mazeWidth = cellSize * maze.cols;
    final mazeHeight = cellSize * maze.rows;
    final origin = Offset(
      (size.width - mazeWidth) * 0.5,
      (size.height - mazeHeight) * 0.5,
    );

    final wallPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
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

    if (pathPoints.length > 1) {
      final path = Path();
      final first = _cellCenterFromPosition(origin, cellSize, pathPoints.first);
      path.moveTo(first.dx, first.dy);

      for (var i = 1; i < pathPoints.length; i++) {
        final prev = _cellCenterFromPosition(
          origin,
          cellSize,
          pathPoints[i - 1],
        );
        final curr = _cellCenterFromPosition(origin, cellSize, pathPoints[i]);
        final mid = Offset(
          (prev.dx + curr.dx) * 0.5,
          (prev.dy + curr.dy) * 0.5,
        );
        path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
      }

      final trailPaint = Paint()
        ..color = const Color(0xFFFF3B3B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true;
      canvas.drawPath(path, trailPaint);
    }

    final startCenter = _cellCenter(origin, cellSize, maze.start);
    final startGlow = Paint()
      ..color = const Color(0xAA00FFAA)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    final startCore = Paint()..color = const Color(0xFF00FFAA);
    final startRadius = cellSize * (0.14 + pulse * 0.04);
    canvas.drawCircle(startCenter, cellSize * 0.22 + pulse * 2.5, startGlow);
    canvas.drawCircle(startCenter, startRadius, startCore);

    final endCenter = _cellCenter(origin, cellSize, maze.end);
    final endSide = cellSize * 0.28;
    final endRect = Rect.fromCenter(
      center: endCenter,
      width: endSide,
      height: endSide,
    );
    final endGlow = Paint()
      ..color = const Color(0xAAFFD700)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
    final endCore = Paint()..color = const Color(0xFFFFD700);
    canvas.drawRect(endRect.inflate(2), endGlow);
    canvas.drawRect(endRect, endCore);

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
  }

  void _drawSpriteCharacter(Canvas canvas, Offset center, double side) {
    final image = playerSprite!;
    final frameW = image.width / spriteFrameCount;
    final frameH = image.height / spriteRows;
    final row = spriteRowIndex.clamp(0, spriteRows - 1);
    final frame = isMoving ? currentFrame.clamp(0, spriteFrameCount - 1) : 0;

    final src = Rect.fromLTWH(frame * frameW, row * frameH, frameW, frameH);
    final dst = Rect.fromCenter(center: Offset.zero, width: side, height: side);
    final spritePaint = Paint()..filterQuality = FilterQuality.none;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    switch (direction) {
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
        oldDelegate.spriteFrameCount != spriteFrameCount ||
        oldDelegate.spriteRows != spriteRows ||
        oldDelegate.spriteRowIndex != spriteRowIndex ||
        oldDelegate.pulse != pulse;
  }
}
