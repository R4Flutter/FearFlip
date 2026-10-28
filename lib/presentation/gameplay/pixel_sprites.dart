import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../arcade/model/shop_catalog.dart';
import '../../domain/entities/direction4.dart';

/// The runner and the Devil, drawn as pixel art in code until their sprite
/// sheets are delivered (2D-gameplay-assets.md §7–8). FireRed rules: a big
/// round head, a dark outline, a few shades lit from the top-left.
///
/// Legend: `.` clear, `o` outline, `H`/`h` hood, `S`/`s` skin, `E` eye,
/// `T` trim (scarf), `C`/`c` cloth, `B` boots.
abstract final class RunnerPixels {
  static const int width = 16;
  static const int height = 17;

  static const List<String> _downHead = [
    '......oooo......',
    '....ooHHHHoo....',
    '...oHHHHHHHHo...',
    '..oHHHHHHHHHHo..',
    '..oHHhhhhhhHHo..',
    '.oHHhSSSSSShHHo.',
    '.oHhSSSSSSSShHo.',
    '.oHhSESSSSESHho.',
    '.oHhSSSSSSSShHo.',
    '..oHhsSSSSshHo..',
    '..ooTTTTTTTToo..',
    '.oCCCCCCCCCCCCo.',
    '.oSCCCCCCCCCCSo.',
    '..ocCCCCCCCCco..',
    '..occcccccccco..',
  ];

  static const List<String> _upHead = [
    '......oooo......',
    '....ooHHHHoo....',
    '...oHHHHHHHHo...',
    '..oHHHHHHHHHHo..',
    '..oHHHHHHHHHHo..',
    '.oHHHHHHHHHHHHo.',
    '.oHHHhHHHHhHHHo.',
    '.oHhHHHHHHHHhHo.',
    '.oHhhHHHHHHhhHo.',
    '..oHhhhhhhhhHo..',
    '..ooTTTTTTTToo..',
    '.oCCCCCCCCCCCCo.',
    '.oSCCCcCCcCCCSo.',
    '..ocCCCCCCCCco..',
    '..occcccccccco..',
  ];

  static const List<String> _leftHead = [
    '......oooo......',
    '....ooHHHHoo....',
    '...oHHHHHHHHo...',
    '..oHHHHHHHHHHo..',
    '..ohhhhHHHHHHo..',
    '.ohSSSShHHHHHHo.',
    '.oSSSSSShHHHHHo.',
    '.oSESSSShHHHHHo.',
    '.oSSSSSShHHHHHo.',
    '..osSSSshHHHHo..',
    '..ooTTTTTTTToo..',
    '...oCCCCCCCCo...',
    '...oCSCCCCCCo...',
    '...ocCCCCCCco...',
    '...occcccccco...',
  ];

  static const List<List<String>> _legs = [
    // Standing.
    ['...oBBo..oBBo...', '...oooo..oooo...'],
    // Step A: the right boot lifts.
    ['...oBBo..oBBo...', '...oooo...oo....'],
    // Step B: the left boot lifts.
    ['...oBBo..oBBo...', '....oo...oooo...'],
  ];

  static const List<List<String>> _sideLegs = [
    ['....oBBooBBo....', '....oooooooo....'],
    ['...oBBo..oBBo...', '...oooo...oo....'],
    ['....oBBoBBo.....', '.....oooooo.....'],
  ];

  /// The rows for [direction] and walk [frame] (0 stand, 1–2 steps).
  static List<String> rows(Direction4 direction, int frame) {
    final head = switch (direction) {
      Direction4.down => _downHead,
      Direction4.up => _upHead,
      Direction4.left || Direction4.right => _leftHead,
    };
    final side = direction == Direction4.left || direction == Direction4.right;
    final legs = (side ? _sideLegs : _legs)[frame.clamp(0, 2)];
    final all = [...head, ...legs];
    if (direction == Direction4.right) {
      return [for (final r in all) r.split('').reversed.join()];
    }
    return all;
  }

  static Color? colorFor(String ch, RunnerPalette p) => switch (ch) {
    'o' => const Color(0xFF16151F),
    'H' => p.hood,
    'h' => p.hoodShade,
    'S' => p.skin,
    's' => p.skinShade,
    'E' => const Color(0xFF16151F),
    'T' => p.trim,
    'C' => p.cloth,
    'c' => p.clothShade,
    'B' => p.boots,
    _ => null,
  };
}

/// The Devil: too tall, too thin, horns and a grin. It faces the way it
/// walks, with a walk cycle like the runner's: frame 0 stands (from the side,
/// the legs passing), 1 and 2 are the two steps. Facing right is facing left
/// mirrored.
///
/// Legend: `.` clear, `o` outline, `D`/`d` body, `R` eyes, `W` teeth and
/// claws, `H`/`h` horns.
abstract final class DevilPixels {
  static const int width = 16;
  static const int height = 22;

  static const List<String> _frontHead = [
    '..o..........o..',
    '.oHo........oHo.',
    '.ohho......ohho.',
    '..ohho....ohho..',
    '...ohooooooho...',
    '...oDDDDDDDDo...',
    '..oDDDDDDDDDDo..',
    '..oDRRDDDDRRDo..',
    '..oDdRDDDDRdDo..',
    '..oDDDDDDDDDDo..',
    '..oDWoWoWoWoDo..',
    '...oDWWWWWWDo...',
    '...ooDDDDDDoo...',
  ];

  static const List<String> _backHead = [
    '..o..........o..',
    '.oHo........oHo.',
    '.ohho......ohho.',
    '..ohho....ohho..',
    '...ohooooooho...',
    '...oDDDDDDDDo...',
    '..oDDDDDDDDDDo..',
    '..oDDDDDDDDDDo..',
    '..oDDDDDDDDDDo..',
    '..odDDDDDDDDdo..',
    '..oddDDDDDDddo..',
    '...oddddddddo...',
    '...ooDDDDDDoo...',
  ];

  static const List<String> _sideHead = [
    '.o..........o...',
    'oHo........oHo..',
    'ohho......ohho..',
    '.ohho....ohho...',
    '..ohooooooho....',
    '..oDDDDDDDDo....',
    '.oDDDDDDDDDDo...',
    '.oRRDDDDDDDDo...',
    '.odRDDDDDDDDo...',
    '.oDDDDDDDDDdo...',
    'oWoWoWDDDDDdo...',
    '.oWWWWDDDDdo....',
    '..ooDDDDDDoo....',
  ];

  static const List<String> _frontStand = [
    '..oDDdDDDDdDDo..',
    '.oDDdDDDDDDdDDo.',
    '.oDo.oDDDDo.oDo.',
    '.oDo.oDDDDo.oDo.',
    '.oWo.oDddDo.oWo.',
    '..o..oDooDo..o..',
    '.....oDooDo.....',
    '....oDDooDDo....',
    '....oooooooo....',
  ];

  /// The left foot lifts; the left arm swings back, the right one forward.
  static const List<String> _frontStep = [
    '..oDDdDDDDdDDo..',
    '.oDDdDDDDDDdDDo.',
    '.oDo.oDDDDo.oDo.',
    '.oWo.oDDDDo.oDo.',
    '..o..oDddDo.oDo.',
    '.....oDooDo.oWo.',
    '....oDDooDo..o..',
    '....oooooDDo....',
    '........oooo....',
  ];

  /// Shoulders and spine from behind (the rest of the body is the front's).
  static const List<String> _backTorso = [
    '..oDDDDddDDDDo..',
    '.oDDDDDddDDDDDo.',
  ];

  /// From the side: hunched, one long arm reaching ahead, claws out.
  static const List<String> _sideTorso = [
    '...oDDDDDDo.....',
    '..ooDDDDDDdo....',
    '.oDDoDDDDDdo....',
    'oDDo.oDDDDdo....',
    'oWWo.oDDDddo....',
  ];

  /// Passing, then a stride on each leg (the far leg is the darker one).
  static const List<List<String>> _sideLegs = [
    [
      '.....oDDDDo.....',
      '.....oDDDo......',
      '....oDDDDo......',
      '....ooooo.......',
    ],
    [
      '.....oDDDDo.....',
      '....oDDoddo.....',
      '...oDDo.oddo....',
      '...oooo.oooo....',
    ],
    [
      '.....oDDDDo.....',
      '....oddoDDo.....',
      '...oddo.oDDo....',
      '...oooo.oooo....',
    ],
  ];

  static List<String> _mirror(List<String> rows) => [
    for (final r in rows) r.split('').reversed.join(),
  ];

  /// The rows for [facing] and walk [frame] (0 stand, 1–2 steps).
  static List<String> rows(Direction4 facing, int frame) {
    final f = frame.clamp(0, 2);
    final front = switch (f) {
      0 => _frontStand,
      1 => _frontStep,
      _ => _mirror(_frontStep),
    };
    return switch (facing) {
      Direction4.down => [..._frontHead, ...front],
      Direction4.up => [..._backHead, ..._backTorso, ...front.skip(2)],
      Direction4.left => [..._sideHead, ..._sideTorso, ..._sideLegs[f]],
      Direction4.right => _mirror(rows(Direction4.left, f)),
    };
  }

  /// The middle of each eye, in sprite pixels: two from the front, one from
  /// the side, none from behind.
  static List<Offset> eyes(Direction4 facing) => switch (facing) {
    Direction4.down => const [Offset(5, 8), Offset(11, 8)],
    Direction4.up => const [],
    Direction4.left => const [Offset(3, 8)],
    Direction4.right => const [Offset(width - 3, 8)],
  };

  static Color? colorFor(String ch, {bool frozen = false}) => switch (ch) {
    'o' => const Color(0xFF0A0A0F),
    'D' => frozen ? const Color(0xFF3B5E86) : const Color(0xFF2B1A33),
    'd' => frozen ? const Color(0xFF1E2A3A) : const Color(0xFF16151F),
    'R' => frozen ? const Color(0xFFE4F2FF) : const Color(0xFFE03A32),
    'W' => const Color(0xFFF0E6D2),
    'H' => const Color(0xFFD8C3A0),
    'h' => const Color(0xFF8A6B50),
    _ => null,
  };
}

/// Renders pixel rows once into small images and draws them crisp.
class PixelSpriteCache {
  PixelSpriteCache._();

  static final PixelSpriteCache instance = PixelSpriteCache._();

  final Map<String, ui.Image> _images = <String, ui.Image>{};

  ui.Image _render(
    String key,
    List<String> rows,
    Color? Function(String) color,
  ) {
    final cached = _images[key];
    if (cached != null) return cached;
    final w = rows.fold<int>(0, (m, r) => max(m, r.length));
    final h = rows.length;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < h; y++) {
      final row = rows[y];
      for (var x = 0; x < row.length; x++) {
        final c = color(row[x]);
        if (c == null) continue;
        paint.color = c;
        canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1), paint);
      }
    }
    final image = recorder.endRecording().toImageSync(w, h);
    if (_images.length > 160) _images.clear();
    _images[key] = image;
    return image;
  }

  ui.Image runner(RunnerPalette palette, Direction4 direction, int frame) {
    final key =
        'r${palette.hood.toARGB32()}_${palette.cloth.toARGB32()}_'
        '${palette.trim.toARGB32()}_${palette.skin.toARGB32()}_'
        '${direction.name}_$frame';
    return _render(
      key,
      RunnerPixels.rows(direction, frame),
      (ch) => RunnerPixels.colorFor(ch, palette),
    );
  }

  ui.Image devil(Direction4 facing, int frame, {bool frozen = false}) =>
      _render(
        'd${facing.name}${frame}_$frozen',
        DevilPixels.rows(facing, frame),
        (ch) => DevilPixels.colorFor(ch, frozen: frozen),
      );
}

/// Draws the runner with its lantern. [feet] is where the sprite stands;
/// [height] its on-screen height.
void paintRunner(
  Canvas canvas, {
  required Offset feet,
  required double height,
  required RunnerLook look,
  required Direction4 direction,
  required int walkFrame,
  required double time,
  bool moving = false,
  double opacity = 1,
}) {
  final image = PixelSpriteCache.instance.runner(
    look.palette,
    direction,
    walkFrame,
  );
  final scale = height / RunnerPixels.height;
  final width = RunnerPixels.width * scale;
  final bob = moving && walkFrame != 0 ? -scale : 0.0;
  final dst = Rect.fromLTWH(
    feet.dx - width / 2,
    feet.dy - height + bob,
    width,
    height,
  );

  // A soft shadow under the feet.
  canvas.drawOval(
    Rect.fromCenter(
      center: feet.translate(0, -scale * 0.5),
      width: width * 0.62,
      height: scale * 2.4,
    ),
    Paint()..color = const Color(0x66000000),
  );

  // The lantern: held out to the side (behind the body when walking away).
  final hand = switch (direction) {
    Direction4.down => Offset(width * 0.4, -height * 0.32),
    Direction4.up => Offset(-width * 0.4, -height * 0.34),
    Direction4.left => Offset(-width * 0.3, -height * 0.3),
    Direction4.right => Offset(width * 0.3, -height * 0.3),
  };
  final swing = sin(time * (moving ? 9 : 2.2)) * scale * (moving ? 0.9 : 0.35);
  final lanternAt = feet + hand + Offset(swing, 0);
  final behind = direction == Direction4.up;
  if (behind) _paintLantern(canvas, lanternAt, scale, look.light, time);

  final paint = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;
  if (opacity < 1) paint.color = Color.fromRGBO(0, 0, 0, opacity);
  canvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    dst,
    paint,
  );
  if (!behind) _paintLantern(canvas, lanternAt, scale, look.light, time);
}

void _paintLantern(
  Canvas canvas,
  Offset at,
  double px,
  Color light,
  double time,
) {
  final flicker = 0.85 + 0.15 * sin(time * 13) * sin(time * 5.3);
  canvas.drawCircle(
    at,
    px * 6 * flicker,
    Paint()
      ..color = light.withValues(alpha: 0.35)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, px * 3),
  );
  final body = Rect.fromCenter(center: at, width: px * 3.2, height: px * 4);
  canvas.drawRect(
    body.inflate(px * 0.7),
    Paint()..color = const Color(0xFF16151F),
  );
  canvas.drawRect(
    body,
    Paint()..color = Color.lerp(light, Colors.white, 0.35)!,
  );
  canvas.drawRect(
    Rect.fromCenter(
      center: at.translate(0, -px * 2.6),
      width: px * 2,
      height: px * 0.9,
    ),
    Paint()..color = const Color(0xFF3E2A20),
  );
}

/// Draws the Devil standing on [feet], [height] tall, facing [facing]; it
/// walks while [moving]. Returns where its eyes are on the canvas, so their
/// glow can be drawn again above the dark.
List<Offset> paintDevil(
  Canvas canvas, {
  required Offset feet,
  required double height,
  required double time,
  Direction4 facing = Direction4.down,
  bool moving = false,
  bool frozen = false,
  bool raging = false,
}) {
  final walking = moving && !frozen;
  // Raging, it sprints: a faster cadence and a shake.
  final cadence = raging ? 12.0 : 7.0;
  final frame = walking ? const [1, 0, 2, 0][(time * cadence).floor() % 4] : 0;
  final image = PixelSpriteCache.instance.devil(facing, frame, frozen: frozen);
  final scale = height / DevilPixels.height;
  final width = DevilPixels.width * scale;
  // Walking, the body rises as the legs pass; standing, it breathes.
  final bob = walking
      ? (frame == 0 ? -scale : 0.0)
      : frozen
      ? 0.0
      : sin(time * 2.4) * scale * 0.5;
  final jitter = raging ? sin(time * 70) * scale * 0.6 : 0.0;
  final left = feet.dx - width / 2 + jitter;
  final top = feet.dy - height + bob;
  canvas.drawOval(
    Rect.fromCenter(center: feet, width: width * 0.7, height: scale * 3),
    Paint()
      ..color = (frozen ? const Color(0xFF9CC8F0) : const Color(0xFFE03A32))
          .withValues(alpha: 0.35)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, scale * 2),
  );
  canvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    Rect.fromLTWH(left, top, width, height),
    Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false,
  );
  return [
    for (final eye in DevilPixels.eyes(facing))
      Offset(left + eye.dx * scale, top + eye.dy * scale),
  ];
}
