import 'dart:math';
import 'dart:ui';

import 'trap_tile.dart';

/// Stateless renderer for all trap-tile visuals.
///
/// Call [renderTiles] from within a `CustomPainter.paint()` to draw
/// crack lines, critical pulses, collapsed voids and ambient particles.
///
/// The renderer adapts to the current theme (normal vs flipped) and
/// respects the [hiddenCueLevel] so that ultra-subtle dust cues
/// progressively vanish at higher stages.
class TrapFxRenderer {
  const TrapFxRenderer();

  /// Render all trap tiles into [canvas].
  ///
  /// * [origin] — top-left pixel offset of the maze grid.
  /// * [cellSize] — side length of one maze cell in pixels.
  /// * [tiles] — current trap-tile list from [TrapStateController].
  /// * [isFlippedMode] — `true` when controls are inverted (white path).
  /// * [hiddenCueLevel] — 0.0 to 1.0, fades hidden-tile dust particles.
  void renderTiles(
    Canvas canvas, {
    required Offset origin,
    required double cellSize,
    required List<TrapTile> tiles,
    required bool isFlippedMode,
    double hiddenCueLevel = 1.0,
    Image? revealedTileTexture,
  }) {
    for (final tile in tiles) {
      final rect = _cellRect(origin, cellSize, tile.cell);
      switch (tile.state) {
        case TrapState.hidden:
          if (hiddenCueLevel > 0.01) {
            _drawHiddenSuspicion(
              canvas,
              rect,
              tile.particlePhase,
              hiddenCueLevel,
              isFlippedMode,
            );
          }
          break;
        case TrapState.cracked:
          if (revealedTileTexture != null) {
            _drawRevealedTexture(
              canvas,
              rect,
              texture: revealedTileTexture,
              critical: false,
            );
          }
          _drawCrackLines(
            canvas,
            rect,
            tile,
            cellSize,
            isFlippedMode,
            widened: false,
          );
          _drawCrackDust(canvas, rect, tile.particlePhase, isFlippedMode);
          break;
        case TrapState.critical:
          _drawCriticalPulse(canvas, rect, tile.pulsePhase, isFlippedMode);
          if (revealedTileTexture != null) {
            _drawRevealedTexture(
              canvas,
              rect,
              texture: revealedTileTexture,
              critical: true,
            );
          }
          _drawCrackLines(
            canvas,
            rect,
            tile,
            cellSize,
            isFlippedMode,
            widened: true,
          );
          _drawWarningDebris(canvas, rect, tile.particlePhase, isFlippedMode);
          break;
        case TrapState.collapsed:
          _drawCollapsedVoid(
            canvas,
            rect,
            tile.collapseProgress,
            isFlippedMode,
          );
          break;
      }
    }
  }

  // ── Hidden state: ultra-subtle dust ────────────────────────────────

  void _drawHiddenSuspicion(
    Canvas canvas,
    Rect rect,
    double phase,
    double intensity,
    bool flipped,
  ) {
    final rng = Random(rect.left.toInt() * 31 + rect.top.toInt() * 17);
    final cueColor = flipped
        ? const Color(0xFF111111)
        : const Color(0xFFE8E8E8);
    final hairlinePaint = Paint()
      ..color = cueColor.withValues(alpha: 0.10 * intensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.7, rect.shortestSide * 0.018)
      ..strokeCap = StrokeCap.round;

    final start = Offset(
      rect.left + rect.width * (0.22 + rng.nextDouble() * 0.16),
      rect.top + rect.height * (0.36 + rng.nextDouble() * 0.10),
    );
    final end = Offset(
      rect.left + rect.width * (0.62 + rng.nextDouble() * 0.16),
      rect.top + rect.height * (0.50 + rng.nextDouble() * 0.12),
    );
    canvas.drawLine(start, end, hairlinePaint);

    final pulse = 0.55 + sin(phase * 1.8) * 0.25;
    final edgePaint = Paint()
      ..color = cueColor.withValues(alpha: 0.035 * intensity * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.6, rect.shortestSide * 0.014);
    canvas.drawRect(rect.deflate(rect.shortestSide * 0.10), edgePaint);

    final dotPaint = Paint()
      ..color = cueColor.withValues(alpha: 0.07 * intensity);

    for (var i = 0; i < 3; i++) {
      final dx = rect.left + rng.nextDouble() * rect.width;
      final baseY = rect.top + rng.nextDouble() * rect.height;
      final drift = sin(phase * 0.8 + i * 2.1) * rect.height * 0.08;
      canvas.drawCircle(Offset(dx, baseY + drift), 1.2, dotPaint);
    }
  }

  void _drawRevealedTexture(
    Canvas canvas,
    Rect rect, {
    required Image texture,
    required bool critical,
  }) {
    final src = _centerSquareSrc(texture);
    final inset = (rect.shortestSide * 0.04).clamp(0.4, 1.8);
    final dst = rect.deflate(inset);

    final imagePaint = Paint()
      ..isAntiAlias = false
      ..filterQuality = FilterQuality.low;
    canvas.drawImageRect(texture, src, dst, imagePaint);

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = critical ? 1.4 : 1.0
      ..color = critical ? const Color(0xCCFF1744) : const Color(0x55000000);
    canvas.drawRect(dst, border);

    if (critical) {
      final alertTint = Paint()..color = const Color(0x22FF1744);
      canvas.drawRect(dst, alertTint);
    }

    final shade = Paint()
      ..shader = Gradient.linear(dst.topCenter, dst.bottomCenter, const [
        Color(0x00000000),
        Color(0x44000000),
      ]);
    canvas.drawRect(dst, shade);
  }

  Rect _centerSquareSrc(Image texture) {
    final side = min(texture.width, texture.height).toDouble();
    final left = (texture.width - side) * 0.5;
    final top = (texture.height - side) * 0.5;
    return Rect.fromLTWH(left, top, side, side);
  }

  // ── Cracked state: crack lines + dust ──────────────────────────────

  void _drawCrackLines(
    Canvas canvas,
    Rect rect,
    TrapTile tile,
    double cellSize,
    bool flipped, {
    required bool widened,
  }) {
    tile.cachedCrackPath ??= _buildCrackPath(tile.crackSeed, rect);
    if (widened) {
      tile.cachedCrackPathWide ??= _buildCrackPath(
        tile.crackSeed,
        rect,
        widthScale: 1.3,
      );
    }

    final path = widened
        ? (tile.cachedCrackPathWide ?? tile.cachedCrackPath!)
        : tile.cachedCrackPath!;

    final color = flipped ? const Color(0xFF333333) : const Color(0xFFDDDDDD);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = widened ? 2.0 : 1.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, paint);

    // Subtle glow behind cracks
    final glow = Paint()
      ..color = (widened
          ? const Color(0x44FF1744)
          : color.withValues(alpha: 0.15))
      ..style = PaintingStyle.stroke
      ..strokeWidth = widened ? 4.0 : 2.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawPath(path, glow);
  }

  void _drawCrackDust(Canvas canvas, Rect rect, double phase, bool flipped) {
    final rng = Random(rect.left.toInt() * 53 + rect.top.toInt() * 7);
    final dustColor = flipped
        ? const Color(0xFF666666)
        : const Color(0xFFAAAAAA);

    for (var i = 0; i < 4; i++) {
      final dx = rect.left + rng.nextDouble() * rect.width;
      final baseY =
          rect.top + rect.height * 0.3 + rng.nextDouble() * rect.height * 0.5;
      final drift = -((phase * 12 + i * 30) % rect.height) * 0.04;
      final opacity = (0.3 - (drift.abs() / rect.height)).clamp(0.0, 0.3);
      final paint = Paint()..color = dustColor.withValues(alpha: opacity);
      canvas.drawCircle(Offset(dx, baseY + drift), 0.9, paint);
    }
  }

  // ── Critical state: pulsing danger glow ────────────────────────────

  void _drawCriticalPulse(
    Canvas canvas,
    Rect rect,
    double phase,
    bool flipped,
  ) {
    final pulse = 0.3 + (sin(phase * 4 * pi) + 1) * 0.2; // 0.3–0.7
    final color = flipped ? const Color(0xFFB71C1C) : const Color(0xFFFF1744);

    // Full-tile glow
    final glowPaint = Paint()
      ..color = color.withValues(alpha: pulse * 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRect(rect.inflate(2), glowPaint);

    // Edge darkening
    final edgePaint = Paint()
      ..color = (flipped ? const Color(0xFF1A0000) : const Color(0xFF0A0000))
          .withValues(alpha: pulse * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(rect, edgePaint);
  }

  void _drawWarningDebris(
    Canvas canvas,
    Rect rect,
    double phase,
    bool flipped,
  ) {
    final rng = Random(rect.left.toInt() * 97 + rect.top.toInt() * 13);
    final debrisColor = flipped
        ? const Color(0xFFFF5252)
        : const Color(0xFFFF8A80);

    for (var i = 0; i < 5; i++) {
      final angle = (phase * 1.2 + i * 1.256) % (2 * pi);
      final radius = rect.width * 0.28 + sin(phase * 3 + i) * 3;
      final cx = rect.center.dx + cos(angle) * radius;
      final cy = rect.center.dy + sin(angle) * radius;
      final opacity = (0.5 + sin(phase * 5 + i * 1.7) * 0.3).clamp(0.1, 0.7);

      final paint = Paint()..color = debrisColor.withValues(alpha: opacity);
      canvas.drawCircle(Offset(cx, cy), 1.0 + rng.nextDouble() * 0.5, paint);
    }
  }

  // ── Collapsed state: void hole ─────────────────────────────────────

  void _drawCollapsedVoid(
    Canvas canvas,
    Rect rect,
    double progress,
    bool flipped,
  ) {
    final center = rect.center;
    final maxRadius = rect.shortestSide * 0.55;
    final radius = maxRadius * progress.clamp(0.0, 1.0);

    // Dark void
    final voidPaint = Paint()
      ..color = flipped ? const Color(0xFF0D0D0D) : const Color(0xFF000000);
    canvas.drawCircle(center, radius, voidPaint);

    // Red-tinted edge
    if (radius > 2) {
      final edgePaint = Paint()
        ..color = const Color(0xFF220000).withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(center, radius, edgePaint);
    }
  }

  // ── crack path builder ─────────────────────────────────────────────

  Path _buildCrackPath(int seed, Rect rect, {double widthScale = 1.0}) {
    final rng = Random(seed);
    final center = rect.center;
    final path = Path();
    final lineCount = 3 + rng.nextInt(3); // 3–5 fracture lines

    for (var i = 0; i < lineCount; i++) {
      final angle = (i / lineCount) * 2 * pi + rng.nextDouble() * 0.5;
      final length = rect.width * (0.22 + rng.nextDouble() * 0.22) * widthScale;
      path.moveTo(center.dx, center.dy);

      // 2–3 jitter segments for organic look
      final segments = 2 + rng.nextInt(2);
      var cx = center.dx;
      var cy = center.dy;
      for (var s = 1; s <= segments; s++) {
        final t = s / segments;
        final jitterAngle = angle + (rng.nextDouble() - 0.5) * 0.6;
        cx = center.dx + cos(jitterAngle) * length * t;
        cy = center.dy + sin(jitterAngle) * length * t;
        path.lineTo(cx, cy);
      }
    }

    return path;
  }

  // ── geometry helpers ───────────────────────────────────────────────

  Rect _cellRect(Offset origin, double cellSize, Point<int> cell) {
    return Rect.fromLTWH(
      origin.dx + cell.x * cellSize,
      origin.dy + cell.y * cellSize,
      cellSize,
      cellSize,
    );
  }
}
