import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Self-contained controller + painter for the 1.8-second trap-death
/// cinematic sequence.
///
/// Usage:
/// 1. Create an instance with a [TickerProvider] (the GameScreen State).
/// 2. Call [start] when a trap collapse is detected.
/// 3. Add the [painter] as an overlay that paints on top of the frozen game.
/// 4. When the animation completes, the [onComplete] callback fires.
/// 5. Call [dispose] when the GameScreen is disposed.
class TrapDeathSequence {
  TrapDeathSequence({required TickerProvider vsync, this.onComplete}) {
    _controller = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 1600),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        onComplete?.call();
      }
    });
  }

  late final AnimationController _controller;
  VoidCallback? onComplete;

  /// The pixel center of the collapsing tile (in the CustomPainter coordinate
  /// space — i.e. the maze surface widget coordinates).
  Offset _trapCenter = Offset.zero;

  /// Side length of one maze cell for sizing the void and fragments.
  double _cellSize = 0;

  /// Whether the sequence is currently animating.
  bool get isActive => _controller.isAnimating;

  /// Current normalised progress 0→1.
  double get progress => _controller.value;

  /// A [CustomPainter] that renders the death sequence overlay.
  ///
  /// Layer this on top of the frozen game canvas.
  CustomPainter get painter => _TrapDeathPainter(sequence: this);

  /// Begin the death animation centred on [trapCenter].
  void start({required Offset trapCenter, required double cellSize}) {
    _trapCenter = trapCenter;
    _cellSize = cellSize;
    _controller.forward(from: 0);
    HapticFeedback.mediumImpact();
  }

  /// Immediately stop and reset the sequence.
  void cancel() {
    _controller.stop();
    _controller.value = 0;
  }

  void dispose() {
    _controller.dispose();
  }

  // ── timeline intervals (normalised 0–1) ────────────────────────────

  /// 0.000–0.044 : Anticipation pause
  double get _anticipation => (progress / 0.044).clamp(0.0, 1.0);

  /// 0.044–0.100 : Fracture burst
  double get _fracture => ((progress - 0.044) / 0.056).clamp(0.0, 1.0);

  /// 0.100–0.278 : Tile collapse
  double get _collapse => ((progress - 0.100) / 0.178).clamp(0.0, 1.0);

  /// 0.278–0.500 : Fall illusion
  double get _fall => ((progress - 0.278) / 0.222).clamp(0.0, 1.0);

  /// 0.500–0.611 : Darkness swallow
  double get _blackout => ((progress - 0.500) / 0.111).clamp(0.0, 1.0);

  /// 0.611–0.722 : Red pulse
  double get _redPulse => ((progress - 0.611) / 0.111).clamp(0.0, 1.0);

  /// 0.722–1.000 : Loss reveal (fade out overlay)
  double get _reveal => ((progress - 0.722) / 0.278).clamp(0.0, 1.0);
}

// ── CustomPainter ──────────────────────────────────────────────────────

class _TrapDeathPainter extends CustomPainter {
  _TrapDeathPainter({required this.sequence})
      : super(repaint: sequence._controller);

  final TrapDeathSequence sequence;

  @override
  void paint(Canvas canvas, Size size) {
    if (!sequence.isActive && sequence.progress <= 0) return;

    final center = sequence._trapCenter;
    final cell = sequence._cellSize;
    final progress = sequence.progress;
    final anticipation = sequence._anticipation;
    final fall = sequence._fall;

    // ── Phase 1: Anticipation (tiny zoom-in drawn as vignette tighten) ──
    if (anticipation > 0 && anticipation < 1) {
      final alpha = 0.04 + anticipation * 0.06;
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.black.withValues(alpha: alpha),
      );
    }

    // ── Phase 2: Fracture burst ──────────────────────────────────────
    if (sequence._fracture > 0 && progress < 0.5) {
      _drawFragments(canvas, center, cell, sequence._fracture, progress);
    }

    // ── Phase 2b: Player fall (explicit sink into collapsed tile) ────
    if (progress >= 0.09 && progress <= 0.62) {
      _drawPlayerFall(canvas, center, cell, progress);
    }

    // ── Phase 3: Void circle expanding ───────────────────────────────
    if (sequence._collapse > 0 && progress < 0.7) {
      final maxR = cell * 0.55;
      final t = Curves.easeOutCubic.transform(sequence._collapse.clamp(0.0, 1.0));
      final radius = maxR * t;
      final voidPaint = Paint()..color = const Color(0xFF000000);
      canvas.drawCircle(center, radius, voidPaint);

      final edgePaint = Paint()
        ..color = const Color(0xFF330000).withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(center, radius, edgePaint);
    }

    // ── Phase 3b: Screen shake simulation via offset shifts ──────────
    if (sequence._fracture > 0 && progress < 0.35) {
      final rng = Random((progress * 10000).toInt());
      final strength = (1 - sequence._collapse.clamp(0.0, 1.0)) * 3;
      final lines = <Rect>[];
      for (var i = 0; i < 4; i++) {
        final y = rng.nextDouble() * size.height;
        lines.add(Rect.fromLTWH(0, y, size.width, 1.5));
      }
      final shakePaint = Paint()
        ..color = Colors.white.withValues(alpha: strength * 0.06);
      for (final line in lines) {
        canvas.drawRect(line, shakePaint);
      }
    }

    // ── Phase 4: Darkness swallow (full-screen black fade) ───────────
    if (sequence._blackout > 0) {
      final alpha = sequence._blackout.clamp(0.0, 1.0);
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.black.withValues(alpha: alpha),
      );
    }

    // ── Phase 5: Red pulse ───────────────────────────────────────────
    if (sequence._redPulse > 0 && sequence._redPulse < 1) {
      final redAlpha = sin(sequence._redPulse * pi) * 0.35;
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFF220000).withValues(alpha: redAlpha),
      );

      // Glitch scan lines
      final rng = Random(42);
      final linePaint = Paint()
        ..color = Colors.white.withValues(alpha: redAlpha * 0.4);
      for (var i = 0; i < 6; i++) {
        final y = rng.nextDouble() * size.height;
        canvas.drawRect(Rect.fromLTWH(0, y, size.width, 2), linePaint);
      }
    }

    // ── Phase 6: Reveal (fade to transparent so loss overlay shows) ──
    if (sequence._reveal > 0) {
      final holdAlpha = (1.0 - sequence._reveal).clamp(0.0, 1.0);
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.black.withValues(alpha: holdAlpha),
      );
    }

    if (fall > 0 && progress < 0.62) {
      final alpha = (fall * 0.18).clamp(0.0, 0.18);
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFF070707).withValues(alpha: alpha),
      );
    }

    // ── Vignette (present through most of the sequence) ──────────────
    if (progress > 0.1 && progress < 0.72) {
      final vignetteStrength = (progress < 0.5)
          ? ((progress - 0.1) / 0.4).clamp(0.0, 0.5)
          : (1.0 - (progress - 0.5) / 0.22).clamp(0.0, 0.5);
      _drawVignette(canvas, size, vignetteStrength);
    }
  }

  void _drawFragments(
    Canvas canvas,
    Offset center,
    double cellSize,
    double fracProgress,
    double totalProgress,
  ) {
    final rng = Random(center.dx.toInt() * 31 + center.dy.toInt() * 17);
    final fragmentCount = 12;
    final elapsed = totalProgress * 1.8; // seconds

    for (var i = 0; i < fragmentCount; i++) {
      final angle = rng.nextDouble() * 2 * pi;
      final speed = 50 + rng.nextDouble() * 150;
      final fragSize = 2 + rng.nextDouble() * 4;

      final distance = speed * elapsed * 0.5;
      final gravity = 60 * elapsed * elapsed * 0.5;
      final x = center.dx + cos(angle) * distance;
      final y = center.dy + sin(angle) * distance + gravity * 0.3;

      final opacity = (1.0 - totalProgress * 2.5).clamp(0.0, 0.8);
      if (opacity <= 0) continue;

      final paint = Paint()
        ..color = (rng.nextBool()
                ? const Color(0xFFCCCCCC)
                : const Color(0xFF888888))
            .withValues(alpha: opacity);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle + totalProgress * 8);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: fragSize, height: fragSize * 0.6),
        paint,
      );
      canvas.restore();
    }
  }

  void _drawPlayerFall(
    Canvas canvas,
    Offset center,
    double cellSize,
    double progress,
  ) {
    const start = 0.10;
    const end = 0.56;
    final tRaw = ((progress - start) / (end - start)).clamp(0.0, 1.0);
    if (tRaw <= 0) {
      return;
    }

    final t = Curves.easeInCubic.transform(tRaw);
    final drop = t * cellSize * 0.95;
    final wobble = sin(progress * pi * 18) * (1 - t) * 0.22;
    final scale = (1.0 - t * 0.78).clamp(0.22, 1.0);
    final fade = (1.0 - ((tRaw - 0.58).clamp(0.0, 0.42) / 0.42)).clamp(0.0, 1.0);

    final actorCenter = Offset(center.dx, center.dy + drop);
    final trailPaint = Paint()
      ..color = const Color(0xFF9DE7FF).withValues(alpha: 0.10 * (1 - t));
    canvas.drawLine(
      Offset(center.dx, center.dy - cellSize * 0.22),
      actorCenter,
      trailPaint..strokeWidth = cellSize * 0.12,
    );

    canvas.save();
    canvas.translate(actorCenter.dx, actorCenter.dy);
    canvas.rotate(wobble);
    canvas.scale(scale, scale);

    final glow = Paint()
      ..color = const Color(0xAA8EF3FF).withValues(alpha: 0.30 * fade)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(Offset.zero, cellSize * 0.19, glow);

    final silhouette = Paint()
      ..color = const Color(0xFFF2FAFF).withValues(alpha: 0.95 * fade);
    final limb = Paint()
      ..color = const Color(0xFFDDF4FF).withValues(alpha: 0.90 * fade)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.2, cellSize * 0.055)
      ..strokeCap = StrokeCap.round;

    final headRadius = cellSize * 0.07;
    canvas.drawCircle(Offset(0, -cellSize * 0.11), headRadius, silhouette);

    final torsoRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, cellSize * 0.02),
        width: cellSize * 0.16,
        height: cellSize * 0.25,
      ),
      Radius.circular(cellSize * 0.08),
    );
    canvas.drawRRect(torsoRect, silhouette);

    canvas.drawLine(
      Offset(-cellSize * 0.07, cellSize * 0.02),
      Offset(-cellSize * 0.15, cellSize * 0.13),
      limb,
    );
    canvas.drawLine(
      Offset(cellSize * 0.07, cellSize * 0.02),
      Offset(cellSize * 0.16, cellSize * 0.12),
      limb,
    );
    canvas.drawLine(
      Offset(-cellSize * 0.04, cellSize * 0.15),
      Offset(-cellSize * 0.11, cellSize * 0.30),
      limb,
    );
    canvas.drawLine(
      Offset(cellSize * 0.04, cellSize * 0.15),
      Offset(cellSize * 0.12, cellSize * 0.30),
      limb,
    );

    canvas.restore();
  }

  void _drawVignette(Canvas canvas, Size size, double strength) {
    final rect = Offset.zero & size;
    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 0.9,
      colors: [
        Colors.transparent,
        Colors.black.withValues(alpha: strength),
      ],
      stops: const [0.5, 1.0],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
  }

  @override
  bool shouldRepaint(covariant _TrapDeathPainter oldDelegate) => true;
}
