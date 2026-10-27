import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../domain/entities/direction4.dart';
import '../../presentation/gameplay/pixel_sprites.dart';
import '../model/shop_catalog.dart';
import 'kit.dart';

/// The equipped runner walking in place on a patch of lit cobbles, with its
/// lantern and trail: the hub's centrepiece and the shop's preview.
class RunnerPreview extends StatefulWidget {
  const RunnerPreview({
    required this.look,
    this.size = 140,
    this.walking = true,
    this.turning = true,
    this.floor = true,
    super.key,
  });

  final RunnerLook look;
  final double size;
  final bool walking;

  /// Turns to face each direction now and then.
  final bool turning;
  final bool floor;

  @override
  State<RunnerPreview> createState() => _RunnerPreviewState();
}

class _RunnerPreviewState extends State<RunnerPreview>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      setState(() => _t = elapsed.inMicroseconds / 1e6);
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _PreviewPainter(
          look: widget.look,
          t: _t,
          walking: widget.walking,
          turning: widget.turning,
          floor: widget.floor,
        ),
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter({
    required this.look,
    required this.t,
    required this.walking,
    required this.turning,
    required this.floor,
  });

  final RunnerLook look;
  final double t;
  final bool walking;
  final bool turning;
  final bool floor;

  static const _order = [
    Direction4.down,
    Direction4.right,
    Direction4.down,
    Direction4.left,
    Direction4.up,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    if (floor) {
      final r = size.width * 0.46;
      canvas.drawCircle(
        c.translate(0, size.height * 0.18),
        r,
        Paint()
          ..shader =
              RadialGradient(
                colors: [
                  look.light.withValues(alpha: 0.42),
                  look.light.withValues(alpha: 0.12),
                  look.light.withValues(alpha: 0),
                ],
                stops: const [0, 0.55, 1],
              ).createShader(
                Rect.fromCircle(
                  center: c.translate(0, size.height * 0.18),
                  radius: r,
                ),
              ),
      );
    }
    final direction = turning
        ? _order[(t / 2.4).floor() % _order.length]
        : Direction4.down;
    final frame = walking ? const [1, 0, 2, 0][(t * 7).floor() % 4] : 0;
    final height = size.height * 0.62;
    final feet = c.translate(0, size.height * 0.3);

    if (walking && look.trail != TrailStyle.none) {
      _paintTrail(canvas, feet, height);
    }
    paintRunner(
      canvas,
      feet: feet,
      height: height,
      look: look,
      direction: direction,
      walkFrame: frame,
      time: t,
      moving: walking,
    );
  }

  void _paintTrail(Canvas canvas, Offset feet, double height) {
    final px = height / RunnerPixels.height;
    final rng = Random(3);
    for (var i = 0; i < 9; i++) {
      final life = ((t * 1.3 + i / 9) % 1.0);
      final x0 = (rng.nextDouble() - 0.5) * px * 10;
      final at = feet.translate(x0, -life * px * 14 + px * 2);
      final alpha = (1 - life) * 0.8;
      final color = switch (look.trail) {
        TrailStyle.dust => FF.bone2,
        TrailStyle.embers => const Color(0xFFFF9A3C),
        TrailStyle.wisps => FF.spirit,
        TrailStyle.sparkles => FF.gold,
        TrailStyle.bones => FF.bone,
        TrailStyle.none => Colors.transparent,
      };
      final r =
          px * (look.trail == TrailStyle.dust ? 1.6 : 1.0) * (1 - life * 0.5);
      if (look.trail == TrailStyle.wisps ||
          look.trail == TrailStyle.embers ||
          look.trail == TrailStyle.sparkles) {
        canvas.drawCircle(
          at,
          r * 2.6,
          Paint()
            ..color = color.withValues(alpha: alpha * 0.35)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, px),
        );
      }
      if (look.trail == TrailStyle.bones) {
        canvas.drawRect(
          Rect.fromCenter(center: at, width: r * 2.2, height: r * 1.2),
          Paint()..color = color.withValues(alpha: alpha),
        );
      } else {
        canvas.drawCircle(
          at,
          r,
          Paint()..color = color.withValues(alpha: alpha),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter old) => true;
}
