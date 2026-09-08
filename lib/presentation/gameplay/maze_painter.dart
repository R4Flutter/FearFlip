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
    this.directionalPlayerFrames = false,
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

  /// True when [playerFrames] are already rendered facing [direction]
  /// (sliced from the 8-direction sheet) - no horizontal mirroring needed.
  final bool directionalPlayerFrames;
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
        _drawWalkingPlayer(canvas, playerCenter, playerSide);
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
      final devilBaseCenter = _cellCenter(origin, cellSize, devil);
      final frames = devilFrames;
      
      if (frames != null && frames.isNotEmpty) {
        const frameCount = 7;
        const walkBobFreq = 2 * pi * 2.2; // Slightly faster/scarier than player
        const halfPi = pi / 2;
        const leanMax = 5 * pi / 180;
        
        final animFrame = (time * 10).floor() % frameCount;
        
        // Calculate direction relative to player
        final dx = playerCellPosition.dx - devil.x;
        final dy = playerCellPosition.dy - devil.y;
        
        int rowIndex = 0;
        double lean = 0;
        if (dx.abs() >= dy.abs()) {
          rowIndex = dx > 0 ? 6 : 2; // Right or Left
          lean = dx > 0 ? leanMax : -leanMax;
        } else {
          rowIndex = dy > 0 ? 0 : 4; // Down or Up
        }
        
        final spriteIndex = rowIndex * frameCount + animFrame;
        final image = frames[spriteIndex.clamp(0, frames.length - 1)];

        // Professional effects: Bob, Squash/Stretch
        final up = 0.5 + 0.5 * sin(time * walkBobFreq - halfPi);
        final bob = -cellSize * 0.15 * up;
        final squash = 1.0 - up;
        final scaleY = 1.0 + (0.08 * (up * 2 - 1).clamp(0.0, 1.0) - 0.10 * squash);
        final scaleX = 1.0 + (0.10 * squash - 0.05 * (up * 2 - 1).clamp(0.0, 1.0));

        // Ground shadow
        final shadowScale = 0.70 + 0.30 * (1.0 - up);
        final shadowPaint = Paint()..color = Colors.black.withAlpha(80);
        canvas.drawOval(
          Rect.fromCenter(
            center: devilBaseCenter.translate(0, cellSize * 0.35),
            width: cellSize * 0.5 * shadowScale,
            height: cellSize * 0.2 * shadowScale,
          ),
          shadowPaint,
        );

        // Draw Devil with effects
        final devilCenter = devilBaseCenter.translate(0, bob);
        final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
        final dst = Rect.fromCenter(center: Offset.zero, width: cellSize * 0.85, height: cellSize * 0.85);
        
        canvas.save();
        canvas.translate(devilCenter.dx, devilCenter.dy);
        canvas.rotate(lean);
        canvas.scale(scaleX, scaleY);
        canvas.drawImageRect(image, src, dst, Paint()..filterQuality = FilterQuality.medium);
        canvas.restore();
      } else {
        final silhouette = Paint()..color = const Color(0xFF1B1B1B);
        canvas.drawCircle(devilBaseCenter, cellSize * 0.24, silhouette);
      }
    }
  }

  // Fake-3D walk: a sine bob tied to the step, squash on foot-strike / stretch
  // on toe-off, a ground shadow that grows opposite the bob, plus a constant
  // breathing sway and a lean into the movement direction. The bob is what
  // makes the flat sprite read as an actual stepping person.
  void _drawWalkingPlayer(Canvas canvas, Offset center, double side) {
    const halfPi = pi / 2;
    const walkBobFreq = 2 * pi * 2.0; // ~2 foot-falls per second when walking
    const idleBobFreq = 2 * pi * 0.9; // slow breathing bob when standing still
    const breathFreq = 1.5 * 2 * pi; // 1.5 Hz sway
    const breathAmp = 1.6 * pi / 180; // ±1.6° sway
    const leanMax = 6 * pi / 180; // ~6° lean into movement

    final frames = playerFrames!;
    final frameCount = 7;
    final animFrame = isMoving ? currentFrame % frameCount : 0;
    
    // Row indices from the 8-direction sheet:
    // 0: Down, 1: Down-Left, 2: Left, 3: Up-Left, 4: Up, 5: Up-Right, 6: Right, 7: Down-Right
    int rowIndex = 0;
    switch (direction) {
      case Direction4.down: rowIndex = 0; break;
      case Direction4.left: rowIndex = 2; break;
      case Direction4.up: rowIndex = 4; break;
      case Direction4.right: rowIndex = 6; break;
    }
    
    final spriteIndex = rowIndex * frameCount + animFrame;
    final image = frames[spriteIndex.clamp(0, frames.length - 1)];

    // The body ALWAYS oscillates so it never reads as a frozen sticker: a bold
    // step-bounce while walking, a gentle breath while idle.
    final bobFreq = isMoving ? walkBobFreq : idleBobFreq;
    final up = 0.5 + 0.5 * sin(time * bobFreq - halfPi); // 0 planted .. 1 top
    final amp = isMoving ? 0.18 : 0.05; // bold vs gentle
    final bob = -side * amp * up; // body rises off the floor
    final contact = 1.0 - up; // 1 = foot planted
    final stretch = (up * 2 - 1).clamp(0.0, 1.0);
    final squash = 1.0 - up;
    final squashAmt = isMoving ? 1.0 : 0.35;
    final scaleY =
        1.0 + (0.09 * stretch - 0.12 * squash + 0.03 * up) * squashAmt;
    final scaleX = 1.0 + (0.12 * squash - 0.06 * stretch) * squashAmt;

    final sway = sin(time * breathFreq) * breathAmp;
    var lean = 0.0;
    if (isMoving) {
      if (direction == Direction4.right) {
        lean = leanMax;
      } else if (direction == Direction4.left) {
        lean = -leanMax;
      }
    }

    // Ground shadow, opposite the bob: big & dark when planted, small & faint
    // when the body is at the top of the step.
    final shadowScale = 0.80 + 0.40 * contact;
    final shadowPaint = Paint()
      ..color = const Color(
        0xFF000000,
      ).withValues(alpha: (0.20 + 0.22 * contact).clamp(0.06, 0.55))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + side * 0.36),
        width: side * 0.50 * shadowScale,
        height: side * 0.22 * shadowScale,
      ),
      shadowPaint,
    );

    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final dst = Rect.fromCenter(center: Offset.zero, width: side, height: side);
    final spritePaint = Paint()..filterQuality = FilterQuality.medium;

    canvas.save();
    canvas.translate(center.dx, center.dy + bob);
    if (sway != 0 || lean != 0) {
      canvas.rotate(sway + lean);
    }
    // Directional frames are pre-rendered facing the right way; legacy
    // side-view frames get mirrored for leftward movement.
    final facingSign = !directionalPlayerFrames && direction == Direction4.left
        ? -1.0
        : 1.0;
    canvas.scale(scaleX * (directionalPlayerFrames ? 1.0 : facingSign), scaleY);
    canvas.drawImageRect(image, src, dst, spritePaint);
    canvas.restore();
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
        oldDelegate.directionalPlayerFrames != directionalPlayerFrames ||
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
