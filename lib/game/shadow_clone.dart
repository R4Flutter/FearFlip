import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'game_config.dart';
import 'maze.dart';

/// A drifting phantom of the player. A single frame is fine, but it shares the
/// player's vertical rhythm — a sine bob plus foot-strike squash — so it reads
/// as part of the same world rather than a flat sticker sliding around.
class ShadowCloneComponent extends PositionComponent {
  ShadowCloneComponent({
    required this.maze,
    required this.config,
    required Vector2 spawnAt,
    required this.random,
    this.sprite,
  }) : super(
         position: spawnAt,
         anchor: Anchor.center,
         size: Vector2.all(config.playerRadius * 2),
         priority: 18,
       );

  final MazeData maze;
  final RuntimeBalanceConfig config;
  final Random random;

  /// Optional phantom frame. Null -> translucent ghost circle (still bobs).
  final Sprite? sprite;

  final Vector2 _dir = Vector2(1, 0);
  final Vector2 _next = Vector2.zero();
  double _changeDirectionTimer = 0;

  // ── Bob state, matched to the player's cadence ─────────────────────────────
  double _phase = 0;
  double _bobOffset = 0;
  double _scaleX = 1;
  double _scaleY = 1;
  int _facing = 1;

  static const double _twoPi = 2 * pi;
  static const double _halfPi = pi / 2;
  static const double _stepCyclesPerSec = 1.8; // ~ the player's walking rhythm
  static const double _drawScale = 0.8;
  late final double _spriteSize = GameBalanceConfig.tileSize * _drawScale;
  late final double _bobAmplitude = _spriteSize * 0.12;
  late final Rect _dstRect = Rect.fromCenter(
    center: Offset.zero,
    width: _spriteSize,
    height: _spriteSize,
  );
  final Paint _ghostPaint = Paint()
    ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.35);

  @override
  void update(double dt) {
    super.update(dt);

    _changeDirectionTimer -= dt;
    if (_changeDirectionTimer <= 0) {
      _changeDirectionTimer = 0.35 + random.nextDouble() * 1.2;
      // Pick a cardinal direction in place — no list/Vector2 allocation.
      switch (random.nextInt(4)) {
        case 0:
          _dir.setValues(1, 0);
        case 1:
          _dir.setValues(-1, 0);
        case 2:
          _dir.setValues(0, 1);
        default:
          _dir.setValues(0, -1);
      }
    }

    _next
      ..setFrom(_dir)
      ..scale(config.shadowCloneSpeed * dt)
      ..add(position);
    if (maze.isCircleWalkable(_next, config.playerRadius * 0.8)) {
      position.setFrom(_next);
    } else {
      _dir.scale(-1);
    }

    if (_dir.x.abs() > 0.01) {
      _facing = _dir.x < 0 ? -1 : 1;
    }

    _phase += _twoPi * _stepCyclesPerSec * dt;
    while (_phase >= _twoPi) {
      _phase -= _twoPi;
    }
    final up = 0.5 + 0.5 * sin(_phase * 2 - _halfPi);
    _bobOffset = -_bobAmplitude * up;
    final stretch = (up * 2 - 1).clamp(0.0, 1.0);
    final squash = (1.0 - up).clamp(0.0, 1.0);
    _scaleY = 1.0 + 0.06 * stretch - 0.08 * squash;
    _scaleX = 1.0 - 0.04 * stretch + 0.08 * squash;
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(0, _bobOffset);
    canvas.scale(_scaleX * (_facing < 0 ? -1.0 : 1.0), _scaleY);
    final s = sprite;
    if (s != null) {
      s.renderRect(canvas, _dstRect);
    } else {
      canvas.drawCircle(Offset.zero, config.playerRadius * 0.95, _ghostPaint);
    }
    canvas.restore();
  }
}
