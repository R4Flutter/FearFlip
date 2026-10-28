import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../arcade/model/shop_catalog.dart';
import '../../arcade/ui/ff_icons.dart';
import '../../game/keys/key_hunt.dart';
import '../../game/trap/trap_fx_renderer.dart';
import '../../game/trap/trap_tile.dart';
import '../../domain/entities/direction4.dart';
import 'maze_art.dart';
import 'maze_camera.dart';
import 'maze_generator.dart';
import 'maze_tiles.dart';
import 'pixel_sprites.dart';

/// A runner footprint for the trail cosmetics: where (in cells) and when.
class TrailDot {
  const TrailDot(this.at, this.time);

  final Offset at;
  final double time;
}

/// A short "+1" or "CLOSE CALL!" that rises and fades over the maze.
class FloatingLabel {
  FloatingLabel(
    this.text,
    this.at,
    this.start, {
    this.color = const Color(0xFFF0E6D2),
    this.size = 1,
  });

  final String text;

  /// Cell position it rises from.
  final Offset at;
  final double start;
  final Color color;
  final double size;

  static const double life = 0.9;
}

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
const _gold = Color(0xFFFFC83D);
const _spirit = Color(0xFF9CC8F0);
const _spiritHi = Color(0xFFE4F2FF);
const _danger = Color(0xFFE03A32);
const _boneDim = Color(0xFFB39572);
const _keyGold = Color(0xFFFFD55A);
const _soot = Color(0xCC120A05);

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
    MazeFxKind.keyRise => 1.0,
    MazeFxKind.emptyPuff => 0.9,
    MazeFxKind.unseal => 1.1,
    MazeFxKind.wispPop => 0.55,
  };
}

enum MazeFxKind {
  /// Black smoke: the Devil appears or vanishes.
  smoke,

  /// Red light cracking the floor open: the world flips.
  flip,

  /// A key rises out of an opened box.
  keyRise,

  /// Dust and a cold "EMPTY" from an empty box.
  emptyPuff,

  /// The exit's seal bursts when the last key is found.
  unseal,

  /// A soul wisp or power-up is picked up: a ring of spirit light.
  wispPop,
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
    this.devilPosition,
    this.devilFacing = Direction4.down,
    this.devilMoving = false,
    this.safeZones = const <Point<int>, double>{},
    this.playerSafe = false,
    this.isFlippedMode = false,
    this.trapTiles = const <TrapTile>[],
    this.trapHiddenCueLevel = 0.0,
    this.hidePlayer = false,
    this.effects = const <MazeFx>[],
    this.keyBoxes = const <KeyBox>[],
    this.keysFound = 0,
    this.keysRequired = 0,
    this.boxPointer,
    this.keyFlashAt = -100,
    this.sealedBumpAt = -100,
    this.look,
    this.trail = const <TrailDot>[],
    this.wisps = const <Point<int>>{},
    this.pickups = const <Point<int>, String>{},
    this.devilFrozen = false,
    this.devilRaging = false,
    this.seerPath = const <Point<int>>[],
    this.shielded = false,
    this.lightScale = 1,
    this.labels = const <FloatingLabel>[],
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

  /// Where the Devil is drawn, in cells, while it glides between cells
  /// (devil_motion.dart); [devilCell] when null.
  final Offset? devilPosition;

  /// The way the Devil walks, and whether it is walking.
  final Direction4 devilFacing;
  final bool devilMoving;
  final Map<Point<int>, double> safeZones;
  final bool playerSafe;
  final bool isFlippedMode;
  final List<TrapTile> trapTiles;
  final double trapHiddenCueLevel;
  final bool hidePlayer;

  /// One-shot effects still playing (GameScreen drops finished ones).
  final List<MazeFx> effects;

  /// Key hunt: the stage's boxes (empty on stages without a hunt).
  final List<KeyBox> keyBoxes;
  final int keysFound;

  /// Keys the exit needs; 0 when the stage has no hunt.
  final int keysRequired;

  /// The shut box to point at while keys are missing.
  final Point<int>? boxPointer;

  /// Stage time of the last key found (a short gold flash) and of the last
  /// bump into the sealed exit (its chains flash red).
  final double keyFlashAt;
  final double sealedBumpAt;

  /// The runner's skin, lantern and trail (the default look when null).
  final RunnerLook? look;
  final List<TrailDot> trail;

  /// Soul wisps still in the maze, and power-ups by cell (BoostType name).
  final Set<Point<int>> wisps;
  final Map<Point<int>, String> pickups;
  final bool devilFrozen;
  final bool devilRaging;

  /// The seer's eye: the way to the next key or the exit.
  final List<Point<int>> seerPath;

  /// A holy ward is held.
  final bool shielded;

  /// The lantern's reach (world 4 burns it low).
  final double lightScale;
  final List<FloatingLabel> labels;

  RunnerLook get _look => look ?? RunnerLook.standard;

  bool get exitSealed => keysFound < keysRequired;

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
    _paintKeyBoxes(canvas, size, camera);
    _paintSeerPath(canvas, camera);
    _paintPickups(canvas, size, camera);

    final start = art.start;
    if (start != null) {
      _drawFrame(
        canvas,
        start,
        start.loop(time, 6),
        camera.cellRect(maze.start),
      );
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
    if (exitSealed) {
      _paintExitSeal(canvas, camera.cellRect(maze.end));
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
      _paintTrail(canvas, camera, cellSize);
      // The runner: pixel art in code until the sheets land (pixel_sprites.dart).
      paintRunner(
        canvas,
        feet: playerCenter.translate(0, cellSize * 0.42),
        height: cellSize * runnerHeightCells,
        look: _look,
        direction: direction,
        walkFrame: isMoving ? const [1, 0, 2, 0][(time * 9).floor() % 4] : 0,
        time: time,
        moving: isMoving,
      );
      if (playerSafe || shielded) {
        final ring = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(2.0, cellSize * 0.06)
          ..color = _spirit.withValues(alpha: 0.6 + 0.3 * sin(time * 6));
        canvas.drawCircle(playerCenter, playerSide * 0.55, ring);
      }
    }

    final devil = devilCell;
    final devilAt = devil == null ? null : devilPosition ?? _offsetOf(devil);
    var devilEyes = const <Offset>[];
    if (devilAt != null) {
      devilEyes = paintDevil(
        canvas,
        feet: camera.cellCenter(devilAt).translate(0, cellSize * 0.45),
        height: cellSize * devilHeightCells,
        time: time,
        facing: devilFacing,
        moving: devilMoving,
        frozen: devilFrozen,
        raging: devilRaging,
      );
    }

    _paintEffects(canvas, camera, MazeFxKind.smoke);
    _paintDarkness(canvas, size, camera, playerCenter);

    // Above the dark: the Devil's eyes (seen before its body), the exit's
    // sparkles and the ghost wisps glow on their own.
    if (devilEyes.isNotEmpty) {
      final px = cellSize * devilHeightCells / DevilPixels.height;
      final eyeColor = devilFrozen ? _spirit : _danger;
      final glow = Paint()
        ..color = eyeColor.withValues(alpha: 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, px * 1.6);
      final eye = Paint()..color = eyeColor;
      for (final at in devilEyes) {
        canvas.drawCircle(at, px * 1.8, glow);
        canvas.drawRect(
          Rect.fromCenter(center: at, width: px * 2, height: px * 1.6),
          eye,
        );
      }
    }
    if (!exitSealed) {
      _paintSparkles(canvas, camera);
    }
    _paintWisps(canvas, size, camera);
    _paintSoulWisps(canvas, size, camera);
    _paintKeyHuntEffects(canvas, camera);
    _paintArcadeEffects(canvas, camera);
    final sinceKey = time - keyFlashAt;
    if (sinceKey >= 0 && sinceKey < _keyFlashSeconds) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = _gold.withValues(
            alpha: 0.16 * (1 - sinceKey / _keyFlashSeconds),
          ),
      );
    }

    // The camera hides most of the maze, so point at what matters off screen:
    // the exit always (the bone arrow), the Devil once it's close enough to
    // be a threat.
    // While the exit is sealed its arrow dims and an amber one points at the
    // nearest shut box instead.
    _drawPointer(
      canvas,
      size,
      camera.cellCenter(_offsetOf(maze.end)),
      _gold,
      cellSize,
      art: art.boneArrow,
      opacity: exitSealed ? 0.45 : 1,
    );
    final boxTarget = boxPointer;
    if (exitSealed && boxTarget != null) {
      _drawPointer(
        canvas,
        size,
        camera.cellCenter(_offsetOf(boxTarget)),
        _amber,
        cellSize,
      );
    }
    if (devilAt != null &&
        (devilAt - playerCellPosition).distance <= _devilWarnCells) {
      _drawPointer(canvas, size, camera.cellCenter(devilAt), _danger, cellSize);
    }
  }

  /// How near (in cells) the Devil must be before its off-screen arrow shows.
  static const double _devilWarnCells = 8;

  /// How tall the runner and the Devil stand, in cells: the runner fits
  /// inside a corridor, the Devil towers over it.
  static const double runnerHeightCells = 0.84;
  static const double devilHeightCells = 1.2;

  /// The gold flash when a key is found.
  static const double _keyFlashSeconds = 0.3;

  /// How near (in cells) the runner must be for a shut box to rattle.
  static const double _rattleCells = 2.2;

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
            transforms.add(
              RSTransform(scale, 0, rect.left - 0.3, rect.top - 0.3),
            );
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

  static const _redFlame = ColorFilter.mode(
    Color(0xFFFF5A4A),
    BlendMode.modulate,
  );

  /// Bones, dolls, crates... on dead ends (landmarks) and now and then in a
  /// corridor; never on the start, the exit, a safe zone or a trap.
  void _paintProps(Canvas canvas, Size size, MazeCamera camera) {
    final sheet = isFlippedMode ? art.propsNightmare : art.propsWake;
    if (sheet == null) {
      return;
    }
    final view = Offset.zero & size;
    final keepClear = {
      ...safeZones.keys,
      for (final t in trapTiles) t.cell,
      for (final b in keyBoxes) b.cell,
    };
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
          : [
              for (final t in trapTiles)
                if (t.state == TrapState.hidden) t,
            ],
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
  void _paintDarkness(
    Canvas canvas,
    Size size,
    MazeCamera camera,
    Offset runner,
  ) {
    final t = camera.tileSize;
    final view = Offset.zero & size;
    canvas.saveLayer(view, Paint());
    canvas.drawRect(
      view,
      Paint()
        ..color =
            (isFlippedMode ? const Color(0xFF12030A) : const Color(0xFF05060C))
                .withValues(alpha: lightScale < 1 ? 0.93 : _darkness),
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

    light(runner, t * _lightInner * lightScale, t * _lightOuter * lightScale);
    if (art.torch != null) {
      final (firstCol, firstRow, lastCol, lastRow) = _visibleTiles(
        size,
        camera,
      );
      bool wall(int col, int row) => isWallTile(maze, col, row);
      for (var row = firstRow; row <= lastRow; row++) {
        for (var col = firstCol; col <= lastCol; col++) {
          if (hasTorch(wall, col, row)) {
            final rect = camera.tileRect(col, row);
            final flicker = 1 + 0.06 * sin(time * 9 + tileHash(col, row) % 7);
            light(
              Offset(rect.center.dx, rect.bottom - t * 0.75),
              t * 0.3,
              t * 1.7 * flicker,
              0.85,
            );
          }
        }
      }
    }
    light(
      camera.cellCenter(_offsetOf(maze.end)),
      t * 0.45,
      t * 1.4,
      exitSealed ? 0.6 : 1,
    ); // the goal glows (dimly while sealed)
    for (final box in keyBoxes) {
      if (!box.opened) {
        // Shut boxes glint in the dark so they can be found.
        light(camera.cellCenter(_offsetOf(box.cell)), t * 0.22, t * 0.95, 0.6);
      }
    }
    for (final cell in safeZones.keys) {
      light(camera.cellCenter(_offsetOf(cell)), t * 0.3, t * 1.2, 0.8);
    }
    for (final cell in pickups.keys) {
      light(camera.cellCenter(_offsetOf(cell)), t * 0.2, t * 0.8, 0.55);
    }
    canvas.restore();
    // The lantern's own colour, laid softly over its pool of light (only
    // when a lantern is chosen in the shop).
    if (look != null) {
      canvas.drawCircle(
        runner,
        t * _lightOuter * lightScale * 0.8,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.radial(
            runner,
            t * _lightOuter * lightScale * 0.8,
            [
              _look.light.withValues(alpha: 0.10),
              _look.light.withValues(alpha: 0),
            ],
          ),
      );
    }
  }

  static const _stoneDust = ColorFilter.mode(
    Color(0xFFA89C8A),
    BlendMode.modulate,
  );
  static const _bloodDust = ColorFilter.mode(
    Color(0xFF9A6058),
    BlendMode.modulate,
  );
  static const _glow = BlendMode.plus;

  /// Key boxes. Shut ones rattle when the runner is near; opened ones stay
  /// open as landmarks (a fading glow where a key was, cobwebs if empty).
  /// Drawn from `objects/chest.png` once delivered (frames: shut, rattle,
  /// open-empty, open-key), in code until then.
  void _paintKeyBoxes(Canvas canvas, Size size, MazeCamera camera) {
    if (keyBoxes.isEmpty) {
      return;
    }
    final view = Offset.zero & size;
    final strip = art.chest;
    for (var i = 0; i < keyBoxes.length; i++) {
      final box = keyBoxes[i];
      final rect = camera.cellRect(box.cell);
      if (!rect.overlaps(view)) {
        continue;
      }
      final near =
          !box.opened &&
          (_offsetOf(box.cell) - playerCellPosition).distance <= _rattleCells;
      final rattle = near ? sin(time * 38 + i * 1.7) : 0.0;
      final dst = rect
          .deflate(rect.width * 0.08)
          .translate(rattle * rect.width * 0.025, 0);
      if (strip != null) {
        final frame = box.opened
            ? (box.hasKey ? 3 : 2)
            : (near && (time * 6).floor().isEven ? 1 : 0);
        _drawFrame(
          canvas,
          strip,
          frame,
          dst,
          tint: isFlippedMode ? _redFlame : null,
        );
        continue;
      }
      _drawChest(canvas, dst, box, rattle: rattle);
    }
  }

  /// A wooden chest with iron bands and a glinting lock, shut or thrown open.
  void _drawChest(Canvas canvas, Rect r, KeyBox box, {double rattle = 0}) {
    final w = r.width;
    final h = r.height;
    final line = max(1.0, w * 0.03);
    final dark = isFlippedMode
        ? const Color(0xFF2A0A0E)
        : const Color(0xFF2E1B0F);
    final wood = isFlippedMode
        ? const Color(0xFF6A1C1C)
        : const Color(0xFF7A4B28);
    final woodLight = isFlippedMode
        ? const Color(0xFF8E2A26)
        : const Color(0xFF9A6236);
    const iron = Color(0xFF4A4E58);
    const ironLight = Color(0xFF9096A3);
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = line
      ..color = _soot;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(r.center.dx, r.bottom - h * 0.05),
        width: w * 0.95,
        height: h * 0.22,
      ),
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    final body = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        r.left + w * 0.06,
        r.top + h * 0.44,
        r.right - w * 0.06,
        r.bottom - h * 0.06,
      ),
      Radius.circular(w * 0.06),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          body.outerRect.topCenter,
          body.outerRect.bottomCenter,
          [wood, dark],
        ),
    );
    canvas.drawLine(
      Offset(body.left + w * 0.04, body.center.dy + h * 0.05),
      Offset(body.right - w * 0.04, body.center.dy + h * 0.05),
      Paint()
        ..color = dark.withValues(alpha: 0.8)
        ..strokeWidth = max(1.0, w * 0.025),
    );

    if (!box.opened) {
      // The domed lid, lifted a hair by the rattle.
      final lift = rattle.abs() * h * 0.05;
      final lidRect = Rect.fromLTRB(
        r.left + w * 0.04,
        r.top + h * 0.14 - lift,
        r.right - w * 0.04,
        r.top + h * 0.47 - lift,
      );
      final lid = RRect.fromRectAndCorners(
        lidRect,
        topLeft: Radius.elliptical(w * 0.3, h * 0.2),
        topRight: Radius.elliptical(w * 0.3, h * 0.2),
        bottomLeft: Radius.circular(w * 0.03),
        bottomRight: Radius.circular(w * 0.03),
      );
      canvas.drawRRect(
        lid,
        Paint()
          ..shader = ui.Gradient.linear(
            lidRect.topCenter,
            lidRect.bottomCenter,
            [woodLight, wood],
          ),
      );
      for (final fx in const [0.26, 0.74]) {
        final x = r.left + w * fx;
        final band = Rect.fromLTRB(
          x - w * 0.045,
          lidRect.top + h * 0.03,
          x + w * 0.045,
          body.bottom,
        );
        canvas.drawRect(band, Paint()..color = iron);
        canvas.drawLine(
          band.topLeft,
          band.bottomLeft,
          Paint()
            ..color = ironLight.withValues(alpha: 0.6)
            ..strokeWidth = max(0.8, w * 0.012),
        );
      }
      canvas.drawRect(
        Rect.fromLTRB(
          lidRect.left,
          lidRect.bottom - h * 0.035,
          lidRect.right,
          lidRect.bottom + h * 0.02,
        ),
        Paint()..color = iron,
      );
      // The lock plate, its keyhole glinting amber.
      final lock = Offset(r.center.dx, lidRect.bottom + h * 0.05);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: lock, width: w * 0.22, height: h * 0.22),
          Radius.circular(w * 0.03),
        ),
        Paint()..color = const Color(0xFFD8C3A0),
      );
      final glint = 0.55 + 0.45 * sin(time * 3 + box.cell.x * 1.3 + box.cell.y);
      canvas.drawCircle(
        lock,
        w * 0.08,
        Paint()
          ..color = _amber.withValues(alpha: 0.55 * glint)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      final hole = Paint()..color = const Color(0xFF1A1008);
      canvas.drawCircle(lock.translate(0, -h * 0.025), w * 0.03, hole);
      canvas.drawRect(
        Rect.fromCenter(
          center: lock.translate(0, h * 0.025),
          width: w * 0.026,
          height: h * 0.07,
        ),
        hole,
      );
      canvas.drawRRect(lid, outline);
      canvas.drawRRect(body, outline);
      return;
    }

    // Opened: the lid thrown back, the inside dark.
    final mouth = Rect.fromLTRB(
      body.left + w * 0.04,
      body.top - h * 0.04,
      body.right - w * 0.04,
      body.top + h * 0.12,
    );
    final lidBack = Path()
      ..moveTo(body.left, body.top)
      ..lineTo(body.right, body.top)
      ..lineTo(body.right - w * 0.06, r.top + h * 0.06)
      ..lineTo(body.left + w * 0.06, r.top + h * 0.06)
      ..close();
    canvas.drawPath(
      lidBack,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, r.top), Offset(0, body.top), [
          dark,
          wood,
        ]),
    );
    canvas.drawPath(lidBack, outline);
    canvas.drawRect(mouth, Paint()..color = const Color(0xFF0B0705));
    for (final fx in const [0.26, 0.74]) {
      final x = r.left + w * fx;
      canvas.drawRect(
        Rect.fromLTRB(x - w * 0.045, body.top, x + w * 0.045, body.bottom),
        Paint()..color = iron,
      );
    }
    canvas.drawRRect(body, outline);
    if (box.hasKey) {
      final fade = (1 - (time - box.openedAt) / 3).clamp(0.0, 1.0);
      if (fade > 0) {
        canvas.drawOval(
          mouth.inflate(w * 0.05),
          Paint()
            ..color = _gold.withValues(alpha: 0.55 * fade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
    } else {
      final web = Paint()
        ..color = const Color(0x88B8B0A0)
        ..strokeWidth = max(0.7, w * 0.012);
      canvas.drawLine(mouth.topLeft, mouth.bottomRight, web);
      canvas.drawLine(
        mouth.bottomLeft.translate(w * 0.1, 0),
        mouth.topCenter,
        web,
      );
    }
  }

  /// The sealed exit: the stairs dimmed, a chain across them for every key
  /// still missing, and a padlock. A bump into it flashes them red.
  void _paintExitSeal(Canvas canvas, Rect r) {
    final w = r.width;
    canvas.drawRect(r, Paint()..color = const Color(0x66000000));
    final missing = (keysRequired - keysFound).clamp(0, 2);
    final sinceBump = time - sealedBumpAt;
    final flash = sinceBump >= 0 && sinceBump < 0.5 ? 1 - sinceBump / 0.5 : 0.0;
    final metal = Color.lerp(const Color(0xFF9A9CA4), _danger, flash)!;
    final link = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.2, w * 0.05)
      ..color = metal;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(2.0, w * 0.09)
      ..color = const Color(0xCC0A0A0F);

    void chain(Offset a, Offset b) {
      const links = 7;
      final d = b - a;
      final angle = atan2(d.dy, d.dx);
      final step = d.distance / links;
      for (var i = 0; i < links; i++) {
        final c = a + d * ((i + 0.5) / links);
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(angle);
        // Links alternate face-on and edge-on, like a real chain.
        final oval = Rect.fromCenter(
          center: Offset.zero,
          width: step * 1.15,
          height: i.isEven ? w * 0.14 : w * 0.05,
        );
        canvas.drawOval(oval, edge);
        canvas.drawOval(oval, link);
        canvas.restore();
      }
    }

    final inset = r.deflate(w * 0.04);
    if (missing >= 1) {
      chain(inset.topLeft, inset.bottomRight);
    }
    if (missing >= 2) {
      chain(inset.topRight, inset.bottomLeft);
    }

    final c = r.center;
    final shackle = Rect.fromCenter(
      center: c.translate(0, -w * 0.05),
      width: w * 0.2,
      height: w * 0.24,
    );
    canvas.drawArc(shackle, pi, pi, false, edge);
    canvas.drawArc(shackle, pi, pi, false, link);
    final lockBody = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: c.translate(0, w * 0.07),
        width: w * 0.32,
        height: w * 0.26,
      ),
      Radius.circular(w * 0.04),
    );
    canvas.drawRRect(lockBody, Paint()..color = const Color(0xFF0A0A0F));
    canvas.drawRRect(
      lockBody.deflate(max(1.0, w * 0.02)),
      Paint()..color = Color.lerp(const Color(0xFFB8A27A), _danger, flash)!,
    );
    canvas.drawCircle(
      c.translate(0, w * 0.06),
      w * 0.035,
      Paint()..color = const Color(0xFF1A1008),
    );
  }

  /// Key-hunt effects, above the dark: a key rising out of its box, an empty
  /// box's dust, the exit's seal bursting.
  void _paintKeyHuntEffects(Canvas canvas, MazeCamera camera) {
    final t = camera.tileSize;
    for (final fx in effects) {
      final age = time - fx.start;
      if (age < 0 || age >= fx.duration) {
        continue;
      }
      final p = age / fx.duration;
      final at = camera.cellCenter(fx.at);
      switch (fx.kind) {
        case MazeFxKind.keyRise:
          final rise = Curves.easeOutCubic.transform(min(1.0, p * 1.6));
          final alpha = p < 0.7 ? 1.0 : 1 - (p - 0.7) / 0.3;
          final keyAt = at.translate(0, -t * 0.65 * rise);
          canvas.drawCircle(
            keyAt,
            t * (0.35 + 0.25 * rise),
            Paint()
              ..color = _gold.withValues(alpha: 0.35 * alpha)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
          );
          _drawKey(canvas, keyAt, t * (0.55 + 0.15 * rise), alpha);
          _drawFloatingText(
            canvas,
            'KEY!',
            at.translate(0, -t * (1.1 + 0.25 * rise)),
            t * 0.34,
            _gold,
            alpha,
          );
          final sparkle = art.sparkle;
          if (sparkle != null) {
            final side = t * 0.4;
            for (var i = 0; i < 4; i++) {
              final angle = i * pi / 2 + p * 2.4;
              final spot =
                  keyAt +
                  Offset(cos(angle), sin(angle)) * t * (0.25 + 0.4 * rise);
              canvas.drawImageRect(
                sparkle.image,
                sparkle.frame(sparkle.loop(age * 1.3 + i * 0.3, 6)),
                Rect.fromCenter(center: spot, width: side, height: side),
                Paint()
                  ..filterQuality = FilterQuality.medium
                  ..blendMode = _glow
                  ..color = Color.fromRGBO(0, 0, 0, alpha),
              );
            }
          }
        case MazeFxKind.emptyPuff:
          final alpha = 1 - p;
          final dust = art.dust ?? art.smoke;
          final frame = dust?.once(age, fx.duration);
          if (dust != null && frame != null) {
            _drawFrame(
              canvas,
              dust,
              frame,
              Rect.fromCenter(
                center: at.translate(0, -t * 0.1),
                width: t * 1.1,
                height: t * 0.9,
              ),
              opacity: 0.75 * alpha,
              tint: _stoneDust,
            );
          } else {
            canvas.drawCircle(
              at,
              t * (0.3 + 0.4 * p),
              Paint()
                ..color = const Color(0xFFB8B0A0).withValues(alpha: 0.3 * alpha)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
            );
          }
          _drawFloatingText(
            canvas,
            'EMPTY',
            at.translate(0, -t * (0.75 + 0.2 * p)),
            t * 0.3,
            _boneDim,
            alpha,
          );
        case MazeFxKind.unseal:
          final alpha = 1 - p;
          canvas.drawCircle(
            at,
            t * (0.6 + 0.6 * p),
            Paint()
              ..color = _gold.withValues(alpha: 0.35 * alpha)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
          );
          canvas.drawCircle(
            at,
            t * (0.4 + 1.4 * p),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = t * 0.12 * (1 - p) + 1
              ..color = _gold.withValues(alpha: 0.8 * alpha),
          );
          final debris = art.debris;
          final frame = debris?.once(age, fx.duration);
          if (debris != null && frame != null) {
            _drawFrame(
              canvas,
              debris,
              frame,
              Rect.fromCenter(center: at, width: t * 1.6, height: t * 1.6),
              opacity: alpha,
            );
          }
        case MazeFxKind.smoke:
        case MazeFxKind.flip:
        case MazeFxKind.wispPop:
          break;
      }
    }
  }

  /// A gold key (ring, shaft, two teeth) centred on [c], [s] wide.
  void _drawKey(Canvas canvas, Offset c, double s, double alpha) {
    final ring = Offset(c.dx - s * 0.28, c.dy);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final (color, width) in [
      (const Color(0xFF3A2400), s * 0.2),
      (_keyGold, s * 0.12),
    ]) {
      paint
        ..color = color.withValues(alpha: alpha)
        ..strokeWidth = width;
      canvas.drawCircle(ring, s * 0.17, paint);
      canvas.drawLine(
        ring.translate(s * 0.17, 0),
        Offset(c.dx + s * 0.42, c.dy),
        paint,
      );
      canvas.drawLine(
        Offset(c.dx + s * 0.22, c.dy),
        Offset(c.dx + s * 0.22, c.dy + s * 0.16),
        paint,
      );
      canvas.drawLine(
        Offset(c.dx + s * 0.36, c.dy),
        Offset(c.dx + s * 0.36, c.dy + s * 0.12),
        paint,
      );
    }
  }

  /// Heavy outlined text centred on [c] (the floating KEY! / EMPTY).
  void _drawFloatingText(
    Canvas canvas,
    String text,
    Offset c,
    double size,
    Color color,
    double alpha,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'FFBody',
          color: color.withValues(alpha: alpha),
          fontSize: size * 1.22,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          shadows: [
            Shadow(
              color: _void.withValues(alpha: alpha),
              offset: const Offset(1.5, 1.5),
            ),
            Shadow(
              color: _void.withValues(alpha: alpha),
              offset: const Offset(-1.5, 1.5),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, c - Offset(painter.width / 2, painter.height / 2));
    painter.dispose();
  }

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
      final at =
          centre + Offset(cos(angle), sin(angle)) * camera.tileSize * 0.42;
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
      final frame = fx.kind == kind
          ? strip.once(time - fx.start, fx.duration)
          : null;
      if (frame == null) {
        continue;
      }
      final side = camera.tileSize * (kind == MazeFxKind.smoke ? 1.6 : 3);
      canvas.drawImageRect(
        strip.image,
        strip.frame(frame),
        Rect.fromCenter(
          center: camera.cellCenter(fx.at),
          width: side,
          height: side,
        ),
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
      final home = Offset(
        (h % maze.cols).toDouble(),
        ((h >> 8) % maze.rows).toDouble(),
      );
      final drift =
          Offset(sin(time * 0.35 + i), cos(time * 0.27 + i * 1.7)) * 0.6;
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
    double opacity = 1,
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
        Paint()
          ..filterQuality = FilterQuality.medium
          ..color = Color.fromRGBO(0, 0, 0, opacity),
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
        ..color = _void.withValues(alpha: 0.75 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawPath(
      arrow,
      Paint()..color = color.withValues(alpha: (0.65 + 0.3 * pulse) * opacity),
    );
    canvas.restore();
  }

  Offset _offsetOf(Point<int> cell) =>
      Offset(cell.x.toDouble(), cell.y.toDouble());

  /// Footprints of the trail cosmetic, fading behind the runner.
  void _paintTrail(Canvas canvas, MazeCamera camera, double t) {
    final style = _look.trail;
    if (style == TrailStyle.none || style == TrailStyle.dust || trail.isEmpty) {
      return;
    }
    final color = switch (style) {
      TrailStyle.embers => const Color(0xFFFF9A3C),
      TrailStyle.wisps => _spirit,
      TrailStyle.sparkles => _gold,
      TrailStyle.bones => const Color(0xFFF0E6D2),
      _ => _amber,
    };
    for (var i = 0; i < trail.length; i++) {
      final dot = trail[i];
      final age = (time - dot.time).clamp(0.0, 0.8);
      final life = 1 - age / 0.8;
      final wobble = Offset(
        sin(dot.time * 37) * t * 0.12,
        cos(dot.time * 29) * t * 0.08,
      );
      final at =
          camera
              .cellCenter(dot.at)
              .translate(0, t * 0.3 - (1 - life) * t * 0.35) +
          wobble;
      final r = t * 0.06 * (0.6 + life);
      if (style != TrailStyle.bones) {
        canvas.drawCircle(
          at,
          r * 2.8,
          Paint()
            ..color = color.withValues(alpha: 0.25 * life)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 1.5),
        );
        canvas.drawCircle(
          at,
          r,
          Paint()..color = color.withValues(alpha: 0.9 * life),
        );
      } else {
        canvas.drawRect(
          Rect.fromCenter(center: at, width: r * 2.4, height: r * 1.3),
          Paint()..color = color.withValues(alpha: 0.85 * life),
        );
      }
    }
  }

  /// The seer's eye: a dotted golden way through the dark.
  void _paintSeerPath(Canvas canvas, MazeCamera camera) {
    if (seerPath.length < 2) return;
    final t = camera.tileSize;
    final dot = Paint()..color = _gold.withValues(alpha: 0.85);
    final glow = Paint()
      ..color = _gold.withValues(alpha: 0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, t * 0.12);
    for (var i = 0; i < seerPath.length - 1; i++) {
      final a = camera.cellCenter(_offsetOf(seerPath[i]));
      final b = camera.cellCenter(_offsetOf(seerPath[i + 1]));
      for (var k = 0; k < 4; k++) {
        final phase = ((k / 4) + time * 1.5) % 1.0;
        final p = Offset.lerp(a, b, phase)!;
        canvas.drawCircle(p, t * 0.14, glow);
        canvas.drawCircle(p, t * 0.06, dot);
      }
    }
  }

  /// Power-ups waiting at dead ends: a gold glow and the item's icon.
  void _paintPickups(Canvas canvas, Size size, MazeCamera camera) {
    if (pickups.isEmpty) return;
    final t = camera.tileSize;
    final view = (Offset.zero & size).inflate(t);
    for (final entry in pickups.entries) {
      final c = camera.cellCenter(_offsetOf(entry.key));
      if (!view.contains(c)) continue;
      final bob = sin(time * 3 + entry.key.x) * t * 0.06;
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(0, t * 0.3),
          width: t * 0.6,
          height: t * 0.18,
        ),
        Paint()..color = const Color(0x66000000),
      );
      canvas.drawCircle(
        c.translate(0, bob),
        t * 0.42,
        Paint()
          ..color = _gold.withValues(alpha: 0.32 + 0.12 * sin(time * 4))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, t * 0.18),
      );
      paintFFGlyph(
        canvas,
        boostGlyphFor(entry.value),
        c.translate(0, bob - t * 0.05),
        t * 0.62,
      );
    }
  }

  /// Soul wisps float above the dark (they glow on their own).
  void _paintSoulWisps(Canvas canvas, Size size, MazeCamera camera) {
    if (wisps.isEmpty) return;
    final t = camera.tileSize;
    final view = (Offset.zero & size).inflate(t);
    for (final cell in wisps) {
      final c = camera.cellCenter(_offsetOf(cell));
      if (!view.contains(c)) continue;
      final phase = (cell.x * 1.7 + cell.y * 2.3);
      final bob = sin(time * 2.6 + phase) * t * 0.08;
      final at = c.translate(0, bob - t * 0.05);
      canvas.drawCircle(
        at,
        t * 0.3,
        Paint()
          ..color = _spirit.withValues(
            alpha: 0.28 + 0.1 * sin(time * 5 + phase),
          )
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, t * 0.14),
      );
      paintFFGlyph(canvas, FFGlyph.soul, at, t * 0.42);
    }
  }

  /// Pickup bursts and floating words (+1, CLOSE CALL!).
  void _paintArcadeEffects(Canvas canvas, MazeCamera camera) {
    final t = camera.tileSize;
    for (final fx in effects) {
      if (fx.kind != MazeFxKind.wispPop) continue;
      final age = time - fx.start;
      if (age < 0 || age >= fx.duration) continue;
      final p = age / fx.duration;
      final at = camera.cellCenter(fx.at);
      canvas.drawCircle(
        at,
        t * (0.2 + 0.6 * p),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = t * 0.08 * (1 - p) + 0.5
          ..color = _spirit.withValues(alpha: 1 - p),
      );
      for (var i = 0; i < 6; i++) {
        final a = i * pi / 3 + p;
        final spot = at + Offset(cos(a), sin(a)) * t * (0.15 + 0.5 * p);
        canvas.drawCircle(
          spot,
          t * 0.05 * (1 - p),
          Paint()..color = _spiritHi.withValues(alpha: 1 - p),
        );
      }
    }
    for (final label in labels) {
      final age = time - label.start;
      if (age < 0 || age >= FloatingLabel.life) continue;
      final p = age / FloatingLabel.life;
      final rise = Curves.easeOutCubic.transform(p);
      final alpha = p < 0.6 ? 1.0 : 1 - (p - 0.6) / 0.4;
      _drawFloatingText(
        canvas,
        label.text,
        camera.cellCenter(label.at).translate(0, -t * (0.7 + 0.6 * rise)),
        t * 0.34 * label.size,
        label.color,
        alpha,
      );
    }
  }

  @override
  bool shouldRepaint(covariant MazePainter oldDelegate) {
    return oldDelegate.maze != maze ||
        oldDelegate.playerCellPosition != playerCellPosition ||
        oldDelegate.direction != direction ||
        oldDelegate.currentFrame != currentFrame ||
        oldDelegate.isMoving != isMoving ||
        oldDelegate.art != art ||
        oldDelegate.devilCell != devilCell ||
        oldDelegate.devilPosition != devilPosition ||
        oldDelegate.devilFacing != devilFacing ||
        oldDelegate.devilMoving != devilMoving ||
        oldDelegate.playerSafe != playerSafe ||
        oldDelegate.isFlippedMode != isFlippedMode ||
        oldDelegate.safeZones != safeZones ||
        oldDelegate.trapTiles != trapTiles ||
        oldDelegate.trapHiddenCueLevel != trapHiddenCueLevel ||
        oldDelegate.hidePlayer != hidePlayer ||
        oldDelegate.effects != effects ||
        oldDelegate.keyBoxes != keyBoxes ||
        oldDelegate.keysFound != keysFound ||
        oldDelegate.keysRequired != keysRequired ||
        oldDelegate.boxPointer != boxPointer ||
        oldDelegate.time != time ||
        oldDelegate.pulse != pulse;
  }
}
