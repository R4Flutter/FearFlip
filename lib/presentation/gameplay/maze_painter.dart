import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../game/trap/trap_fx_renderer.dart';
import '../../game/trap/trap_tile.dart';
import '../../domain/entities/direction4.dart';
import 'maze_art.dart';
import 'maze_camera.dart';
import 'maze_generator.dart';
import 'maze_tiles.dart';

/// Stand-in colours for any art that hasn't loaded (2D-gameplay-assets.md,
/// Night 32): cold stone in WAKE, blood and bone in NIGHTMARE, no green or pink.
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

/// A one-shot effect in the maze: [kind] at cell position [at], started at
/// stage time [start].
class MazeFx {
  const MazeFx(this.kind, this.at, this.start);

  final MazeFxKind kind;
  final Offset at;
  final double start;

  double get duration => switch (kind) {
    MazeFxKind.smoke => 0.6,
    MazeFxKind.flip => 0.7,
  };
}

enum MazeFxKind {
  /// Black smoke: the Devil appears or vanishes.
  smoke,

  /// Red light cracking the floor open: the world flips.
  flip,
}

class MazePainter extends CustomPainter {
  MazePainter({
    required this.maze,
    required this.playerCellPosition,
    required this.direction,
    required this.currentFrame,
    required this.isMoving,
    required this.pulse,
    this.time = 0,
    this.art = const MazeArt.none(),
    this.devilCell,
    this.safeZones = const <Point<int>, double>{},
    this.playerSafe = false,
    this.isFlippedMode = false,
    this.trapTiles = const <TrapTile>[],
    this.trapHiddenCueLevel = 0.0,
    this.hidePlayer = false,
    this.effects = const <MazeFx>[],
  });

  final MazeGrid maze;
  final Offset playerCellPosition;
  final Direction4 direction;
  final int currentFrame;
  final bool isMoving;
  final double pulse;
  final double time;

  /// The delivered sheets; whatever is missing falls back to the stand-ins.
  final MazeArt art;
  final Point<int>? devilCell;
  final Map<Point<int>, double> safeZones;
  final bool playerSafe;
  final bool isFlippedMode;
  final List<TrapTile> trapTiles;
  final double trapHiddenCueLevel;
  final bool hidePlayer;

  /// One-shot effects still playing (GameScreen drops finished ones).
  final List<MazeFx> effects;

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
    _paintTorches(canvas, size, camera);
    _paintDrips(canvas, size, camera);
    _paintProps(canvas, size, camera);
    _paintTraps(canvas, camera);

    final start = art.start;
    if (start != null) {
      _drawFrame(canvas, start, start.loop(time, 6), camera.cellRect(maze.start));
    } else {
      final startRing = Paint()
        ..color = _amber.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.5, cellSize * 0.07);
      canvas.drawCircle(
        camera.cellCenter(_offsetOf(maze.start)),
        cellSize * (0.3 + pulse * 0.04),
        startRing,
      );
    }

    // WAKE: stairs down into warm light. NIGHTMARE: something waits below.
    final exit = isFlippedMode ? art.exitNightmare : art.exitWake;
    if (exit != null) {
      _drawFrame(canvas, exit, exit.loop(time, 6), camera.cellRect(maze.end));
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

    final safe = art.safe;
    for (final entry in safeZones.entries) {
      final strength = entry.value.clamp(0.0, 1.0);
      if (safe != null) {
        // The spirit candle flickers; a fading zone fades with it.
        _drawFrame(
          canvas,
          safe,
          safe.loop(time + entry.key.x * 0.37, 8),
          camera.cellRect(entry.key),
          opacity: 0.4 + strength * 0.6,
        );
        continue;
      }
      final zoneRect = camera.cellRect(entry.key).deflate(cellSize * 0.14);
      final glow = Paint()
        ..color = _spirit.withValues(alpha: 0.2 + strength * 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
      final core = Paint()..color = _spirit.withValues(alpha: 0.15 + strength * 0.35);
      final border = Paint()
        ..color = _spirit.withValues(alpha: 0.5 + strength * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.6, cellSize * 0.06);
      canvas.drawRect(zoneRect.inflate(cellSize * 0.06), glow);
      canvas.drawRect(zoneRect, core);
      canvas.drawRect(zoneRect, border);
    }

    _paintEffects(canvas, camera, MazeFxKind.flip);

    final playerCenter = camera.cellCenter(playerCellPosition);
    final breath = isMoving ? 0.0 : sin(time * 2.2) * 0.03;
    final playerSide = cellSize * 0.9 * (1 + breath);

    final dust = art.dust;
    if (isMoving && dust != null && !hidePlayer) {
      // Footsteps kick up a little dust from the stone.
      final side = cellSize * 0.55;
      _drawFrame(
        canvas,
        dust,
        dust.loop(time, 10),
        Rect.fromCenter(
          center: playerCenter.translate(0, cellSize * 0.28),
          width: side,
          height: side * 0.8,
        ),
        opacity: 0.45,
        tint: isFlippedMode ? _bloodDust : _stoneDust,
      );
    }

    if (!hidePlayer) {
      // Stand-in until the runner sheets land: the runner's own lantern glow.
      final playerGlow = Paint()
        ..color = _amber.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      final playerCore = Paint()..color = _candle;
      canvas.drawCircle(playerCenter, playerSide * 0.35, playerGlow);
      canvas.drawCircle(playerCenter, playerSide * 0.28, playerCore);

      if (playerSafe) {
        final ring = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = _spirit;
        canvas.drawCircle(playerCenter, playerSide * 0.42, ring);
      }
    }

    final devil = devilCell;
    final devilCenter = devil == null
        ? null
        : camera
              .cellCenter(_offsetOf(devil))
              .translate(0, sin(time * 3.4) * cellSize * 0.07);
    if (devilCenter != null) {
      // Stand-in until the devil sheets land: a shadow (its eyes burn above
      // the dark, below).
      canvas.drawCircle(
        devilCenter,
        cellSize * 0.42,
        Paint()
          ..color = _danger.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(devilCenter, cellSize * 0.32, Paint()..color = _void);
    }

    _paintEffects(canvas, camera, MazeFxKind.smoke);
    _paintDarkness(canvas, size, camera, playerCenter);

    // Above the dark: the Devil's eyes (seen before its body), the exit's
    // sparkles and the ghost wisps glow on their own.
    if (devilCenter != null) {
      final eyes = devilCenter.translate(0, -cellSize * 0.05);
      final eye = Paint()..color = _danger;
      canvas.drawCircle(eyes.translate(-cellSize * 0.1, 0), cellSize * 0.05, eye);
      canvas.drawCircle(eyes.translate(cellSize * 0.1, 0), cellSize * 0.05, eye);
    }
    _paintSparkles(canvas, camera);
    _paintWisps(canvas, size, camera);

    // The camera hides most of the maze, so point at what matters off screen:
    // the exit always (the bone arrow), the Devil once it's close enough to
    // be a threat.
    _drawPointer(
      canvas,
      size,
      camera.cellCenter(_offsetOf(maze.end)),
      _gold,
      cellSize,
      art: art.boneArrow,
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

  /// Floor and wall tiles in view. Walls are whole tiles, raised like the
  /// reference art: capstoned tops, and a rock face wherever floor lies below,
  /// which casts a short shadow onto that floor. Drawn from the world's tile
  /// atlas in one batch, or as flat stand-in colours until it loads.
  void _paintTiles(Canvas canvas, Size size, MazeCamera camera) {
    final tile = camera.tileSize;
    final atlas = isFlippedMode ? art.nightmareTiles : art.wakeTiles;
    final world = isFlippedMode ? _nightmare : _wake;
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

    final (firstCol, firstRow, lastCol, lastRow) = _visibleTiles(size, camera);
    bool wall(int col, int row) => isWallTile(maze, col, row);
    final transforms = <RSTransform>[];
    final sources = <Rect>[];
    final shaded = <Rect>[];
    // A hair of overlap, so painted neighbours never show a seam between them.
    final scale = atlas == null ? 0.0 : (tile + 0.6) / atlas.frameWidth;

    for (var row = firstRow; row <= lastRow; row++) {
      for (var col = firstCol; col <= lastCol; col++) {
        final rect = camera.tileRect(col, row);
        final isWall = wall(col, row);
        if (!isWall && wall(col, row - 1)) {
          shaded.add(rect);
        }
        if (atlas != null) {
          for (final slot in tileLayers(wall, col, row)) {
            transforms.add(RSTransform(scale, 0, rect.left - 0.3, rect.top - 0.3));
            sources.add(atlas.frame(slot));
          }
        } else if (!isWall) {
          canvas.drawRect(rect, floor);
        } else {
          canvas.drawRect(rect, top);
          if (!wall(col, row + 1)) {
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
    if (atlas != null) {
      canvas.drawAtlas(
        atlas.image,
        transforms,
        sources,
        null,
        null,
        null,
        Paint()..filterQuality = FilterQuality.medium,
      );
    }
    for (final rect in shaded) {
      final depth = tile * 0.28;
      canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.top, rect.width, depth),
        Paint()
          ..shader = ui.Gradient.linear(
            rect.topLeft,
            rect.topLeft.translate(0, depth),
            const [Color(0x88000000), Color(0x00000000)],
          ),
      );
    }
  }

  /// Block tiles in view: first and last column and row, clamped to the maze.
  (int, int, int, int) _visibleTiles(Size size, MazeCamera camera) {
    final tile = camera.tileSize;
    return (
      max(0, (-camera.origin.dx / tile).floor()),
      max(0, (-camera.origin.dy / tile).floor()),
      min(2 * maze.cols, ((size.width - camera.origin.dx) / tile).ceil()),
      min(2 * maze.rows, ((size.height - camera.origin.dy) / tile).ceil()),
    );
  }

  /// Frame [frame] of [strip] stretched over [dst] (a hair wider, so a full
  /// tile never leaves a seam).
  void _drawFrame(
    Canvas canvas,
    SpriteStrip strip,
    int frame,
    Rect dst, {
    double opacity = 1,
    ColorFilter? tint,
  }) {
    canvas.drawImageRect(
      strip.image,
      strip.frame(frame),
      dst.inflate(0.3),
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Color.fromRGBO(0, 0, 0, opacity)
        ..colorFilter = tint,
    );
  }

  /// Torches on some rock faces, each flickering on its own beat; in
  /// NIGHTMARE they burn red.
  void _paintTorches(Canvas canvas, Size size, MazeCamera camera) {
    final torch = art.torch;
    if (torch == null) {
      return;
    }
    final t = camera.tileSize;
    final (firstCol, firstRow, lastCol, lastRow) = _visibleTiles(size, camera);
    bool wall(int col, int row) => isWallTile(maze, col, row);
    final tint = isFlippedMode ? _redFlame : null;
    for (var row = firstRow; row <= lastRow; row++) {
      for (var col = firstCol; col <= lastCol; col++) {
        if (!hasTorch(wall, col, row)) {
          continue;
        }
        final rect = camera.tileRect(col, row);
        _drawFrame(
          canvas,
          torch,
          torch.loop(time + tileHash(col, row) % 97 / 13, 8),
          Rect.fromCenter(
            center: Offset(rect.center.dx, rect.bottom - t * 0.52),
            width: t * 0.5,
            height: t,
          ),
          tint: tint,
        );
      }
    }
  }

  static const _redFlame = ColorFilter.mode(Color(0xFFFF5A4A), BlendMode.modulate);

  /// Bones, dolls, crates... on dead ends (landmarks) and now and then in a
  /// corridor; never on the start, the exit, a safe zone or a trap.
  void _paintProps(Canvas canvas, Size size, MazeCamera camera) {
    final sheet = isFlippedMode ? art.propsNightmare : art.propsWake;
    if (sheet == null) {
      return;
    }
    final view = Offset.zero & size;
    final keepClear = {...safeZones.keys, for (final t in trapTiles) t.cell};
    for (var y = 0; y < maze.rows; y++) {
      for (var x = 0; x < maze.cols; x++) {
        final cell = Point<int>(x, y);
        final rect = camera.cellRect(cell);
        if (!rect.overlaps(view)) {
          continue;
        }
        final prop = propAt(maze, cell, keepClear: keepClear);
        if (prop != null) {
          _drawFrame(canvas, sheet, prop, rect.deflate(rect.width * 0.14));
        }
      }
    }
  }

  /// Revealed traps as the world's crumbling-slab frames (a red pulse under a
  /// critical one); hidden ones keep only the renderer's faint cue. Without
  /// the art the renderer draws everything.
  void _paintTraps(Canvas canvas, MazeCamera camera) {
    if (trapTiles.isEmpty) {
      return;
    }
    final strip = isFlippedMode ? art.trapNightmare : art.trapWake;
    final tile = camera.tileSize;
    const TrapFxRenderer().renderTiles(
      canvas,
      origin: camera.cellOrigin,
      cellSize: tile,
      cellStride: tile * 2,
      tiles: strip == null
          ? trapTiles
          : [for (final t in trapTiles) if (t.state == TrapState.hidden) t],
      // Both worlds have dark floors now, so the dark-floor look fits both.
      isFlippedMode: false,
      hiddenCueLevel: trapHiddenCueLevel,
    );
    if (strip == null) {
      return;
    }
    for (final trap in trapTiles) {
      final frame = trapFrame(trap.state, strip.frames, time);
      if (frame == null) {
        continue;
      }
      final rect = camera.cellRect(trap.cell);
      if (trap.state == TrapState.critical) {
        final beat = 0.35 + (sin(trap.pulsePhase * 4 * pi) + 1) * 0.2;
        canvas.drawRect(
          rect.inflate(tile * 0.08),
          Paint()
            ..color = _danger.withValues(alpha: beat * 0.6)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
      _drawFrame(canvas, strip, frame, rect);
    }
  }

  /// The runner's light: fully lit within [_lightInner] tiles, fading to
  /// [_darkness] by [_lightOuter]. The view is 11 tiles across, so only its
  /// edges and corners sink into the dark.
  static const double _lightInner = 2.5;
  static const double _lightOuter = 5;
  static const double _darkness = 0.78;

  /// The maze is dark: cold in WAKE, blood-red in NIGHTMARE. Light cuts
  /// through it around the runner, under torches, at the exit and the safe
  /// zones.
  void _paintDarkness(Canvas canvas, Size size, MazeCamera camera, Offset runner) {
    final t = camera.tileSize;
    final view = Offset.zero & size;
    canvas.saveLayer(view, Paint());
    canvas.drawRect(
      view,
      Paint()
        ..color = (isFlippedMode ? const Color(0xFF12030A) : const Color(0xFF05060C))
            .withValues(alpha: _darkness),
    );
    void light(Offset at, double inner, double outer, [double strength = 1]) {
      final core = Color.fromRGBO(0, 0, 0, strength);
      canvas.drawCircle(
        at,
        outer,
        Paint()
          ..blendMode = BlendMode.dstOut
          ..shader = ui.Gradient.radial(
            at,
            outer,
            [core, core, const Color(0x00000000)],
            [0, inner / outer, 1],
          ),
      );
    }

    light(runner, t * _lightInner, t * _lightOuter);
    if (art.torch != null) {
      final (firstCol, firstRow, lastCol, lastRow) = _visibleTiles(size, camera);
      bool wall(int col, int row) => isWallTile(maze, col, row);
      for (var row = firstRow; row <= lastRow; row++) {
        for (var col = firstCol; col <= lastCol; col++) {
          if (hasTorch(wall, col, row)) {
            final rect = camera.tileRect(col, row);
            final flicker = 1 + 0.06 * sin(time * 9 + tileHash(col, row) % 7);
            light(Offset(rect.center.dx, rect.bottom - t * 0.75), t * 0.3, t * 1.7 * flicker, 0.85);
          }
        }
      }
    }
    light(camera.cellCenter(_offsetOf(maze.end)), t * 0.45, t * 1.4); // the goal glows
    for (final cell in safeZones.keys) {
      light(camera.cellCenter(_offsetOf(cell)), t * 0.3, t * 1.2, 0.8);
    }
    canvas.restore();
  }

  static const _stoneDust = ColorFilter.mode(Color(0xFFA89C8A), BlendMode.modulate);
  static const _bloodDust = ColorFilter.mode(Color(0xFF9A6058), BlendMode.modulate);
  static const _glow = BlendMode.plus;

  /// Gold sparkles circling the exit, so the goal catches the eye.
  void _paintSparkles(Canvas canvas, MazeCamera camera) {
    final sparkle = art.sparkle;
    if (sparkle == null) {
      return;
    }
    final centre = camera.cellCenter(_offsetOf(maze.end));
    final side = camera.tileSize * 0.42;
    for (var i = 0; i < 3; i++) {
      final angle = i * 2.1 + time * 0.7;
      final at = centre + Offset(cos(angle), sin(angle)) * camera.tileSize * 0.42;
      canvas.drawImageRect(
        sparkle.image,
        sparkle.frame(sparkle.loop(time * 1.3 + i * 0.33, 5)),
        Rect.fromCenter(center: at, width: side, height: side),
        Paint()
          ..filterQuality = FilterQuality.medium
          ..blendMode = _glow,
      );
    }
  }

  /// One-shot effects of [kind]: the flip's crack burst at floor level, the
  /// Devil's smoke in the air.
  void _paintEffects(Canvas canvas, MazeCamera camera, MazeFxKind kind) {
    final strip = kind == MazeFxKind.smoke ? art.smoke : art.flip;
    if (strip == null) {
      return;
    }
    for (final fx in effects) {
      final frame = fx.kind == kind ? strip.once(time - fx.start, fx.duration) : null;
      if (frame == null) {
        continue;
      }
      final side = camera.tileSize * (kind == MazeFxKind.smoke ? 1.6 : 3);
      canvas.drawImageRect(
        strip.image,
        strip.frame(frame),
        Rect.fromCenter(center: camera.cellCenter(fx.at), width: side, height: side),
        Paint()
          ..filterQuality = FilterQuality.medium
          ..blendMode = kind == MazeFxKind.flip ? _glow : BlendMode.srcOver,
      );
    }
  }

  /// NIGHTMARE: blood runs down some rock faces (never past a torch).
  void _paintDrips(Canvas canvas, Size size, MazeCamera camera) {
    final drip = art.drip;
    if (drip == null || !isFlippedMode) {
      return;
    }
    final t = camera.tileSize;
    final (firstCol, firstRow, lastCol, lastRow) = _visibleTiles(size, camera);
    bool wall(int col, int row) => isWallTile(maze, col, row);
    for (var row = firstRow; row <= lastRow; row++) {
      for (var col = firstCol; col <= lastCol; col++) {
        final h = tileHash(col, row);
        if (h % 5 != 1 || !wall(col, row) || wall(col, row + 1)) {
          continue;
        }
        final rect = camera.tileRect(col, row);
        final x = rect.left + t * (0.2 + (h >> 4) % 60 / 100);
        _drawFrame(
          canvas,
          drip,
          drip.loop(time + h % 89 / 17, 5),
          Rect.fromLTWH(x - t * 0.09, rect.top + t * 0.5, t * 0.18, t * 0.48),
          opacity: 0.9,
        );
      }
    }
  }

  /// NIGHTMARE: pale ghost wisps drifting through the corridors.
  void _paintWisps(Canvas canvas, Size size, MazeCamera camera) {
    final wisp = art.wisp;
    if (wisp == null || !isFlippedMode) {
      return;
    }
    final view = Offset.zero & size;
    final side = camera.tileSize * 0.8;
    final count = (maze.rows * maze.cols / 10).ceil();
    for (var i = 0; i < count; i++) {
      final h = tileHash(i, 7919);
      final home = Offset((h % maze.cols).toDouble(), ((h >> 8) % maze.rows).toDouble());
      final drift = Offset(sin(time * 0.35 + i), cos(time * 0.27 + i * 1.7)) * 0.6;
      final dst = Rect.fromCenter(
        center: camera.cellCenter(home + drift),
        width: side,
        height: side,
      );
      if (!dst.overlaps(view)) {
        continue;
      }
      canvas.drawImageRect(
        wisp.image,
        wisp.frame(wisp.loop(time + i * 0.4, 4)),
        dst,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..blendMode = _glow,
      );
    }
  }

  /// A pointer at the edge of the view toward [target], when off screen: the
  /// [art] (drawn pointing right) when given, else a [color] triangle.
  void _drawPointer(
    Canvas canvas,
    Size size,
    Offset target,
    Color color,
    double tile, {
    SpriteStrip? art,
  }) {
    final at = MazeCamera.offscreenPointer(size, target, tile * 0.55);
    if (at == null) {
      return;
    }
    final direction = target - at;
    if (art != null) {
      final angle = atan2(direction.dy, direction.dx);
      final w = tile * (1.15 + 0.06 * pulse);
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(angle);
      if (cos(angle) < 0) {
        canvas.scale(1, -1); // keep the blood dripping down, not up
      }
      canvas.drawImageRect(
        art.image,
        art.frame(0),
        Rect.fromCenter(center: Offset.zero, width: w, height: w * 0.6),
        Paint()..filterQuality = FilterQuality.medium,
      );
      canvas.restore();
      return;
    }
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
        oldDelegate.art != art ||
        oldDelegate.devilCell != devilCell ||
        oldDelegate.playerSafe != playerSafe ||
        oldDelegate.isFlippedMode != isFlippedMode ||
        oldDelegate.safeZones != safeZones ||
        oldDelegate.trapTiles != trapTiles ||
        oldDelegate.trapHiddenCueLevel != trapHiddenCueLevel ||
        oldDelegate.hidePlayer != hidePlayer ||
        oldDelegate.effects != effects ||
        oldDelegate.time != time ||
        oldDelegate.pulse != pulse;
  }
}
