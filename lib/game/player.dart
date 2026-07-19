import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'character.dart';
import 'game_config.dart';
import 'maze.dart';

/// The player avatar. Movement (lane snapping, wall collision) is unchanged from
/// the original; layered on top is a fake-3D walk cycle:
///   - X: horizontal flip on direction reversal + lean into the movement.
///   - Y: sine bob tied to the walk phase, with squash on foot-strike and a
///        slight stretch on toe-off. This vertical oscillation is what sells the
///        3D "stepping" read on an otherwise flat sprite.
///   - Z: constant breathing sway + a ground shadow that grows/shrinks opposite
///        to the bob (big & sharp on strike, small & soft at the top).
///
/// All per-frame state is advanced from elapsed time, and update()/render() do
/// no allocation: no `new`, no list literals, no `Vector2(...)` literals — the
/// two scratch vectors below are reused every tick.
class PlayerComponent extends PositionComponent {
  PlayerComponent({
    required this.maze,
    required this.config,
    this.spriteSet,
    this.avatarSprite,
  }) : super(
         anchor: Anchor.center,
         size: Vector2.all(config.playerRadius * 2),
         priority: 20,
       );

  final MazeData maze;
  final RuntimeBalanceConfig config;

  /// 7-frame walk cycle. Falls back to [avatarSprite] then a primitive if null.
  final CharacterSpriteSet? spriteSet;
  final Sprite? avatarSprite;

  final Vector2 _velocity = Vector2.zero();
  final Vector2 _rawInput = Vector2.zero();
  bool controlsInverted = false;
  static const double _laneAlignSpeed = 420;

  // ── Walk-cycle state (advanced in update, consumed in render) ──────────────
  double _phase = 0; // radians, one full 7-frame cycle per 2π
  int _lastFacing = 1; // 1 = art's native right, -1 = mirrored left
  double _footStrikeTimer = 0; // counts down 80ms of squash after a strike
  double _breathPhase = 0; // radians for the independent breathing sway

  int _frame = 0;
  double _moveFactor = 0; // eased 0..1 "am I walking", fades bob/lean/squash
  double _prevUp = 0;
  bool _prevFalling = false;

  // Derived render values, written each tick so render() stays trivial.
  double _bobOffset = 0; // px, negative = up
  double _scaleX = 1;
  double _scaleY = 1;
  double _rotation = 0;
  double _groundContact = 0; // 0 = top of step, 1 = foot on floor
  double _breathSin = 0;

  // ── Scratch (reused, never reallocated in the hot path) ────────────────────
  final Vector2 _desired = Vector2.zero();
  final Vector2 _probe = Vector2.zero();

  // ── Paints / geometry, allocated once ──────────────────────────────────────
  static const double _drawScale = 0.82;
  late final double _spriteSize = GameBalanceConfig.tileSize * _drawScale;
  late final double _bobAmplitude = _spriteSize * 0.12; // ~12% of sprite height
  late final int _frameCount =
      spriteSet?.frameCount ?? CharacterSpriteSet.framesPerSet;
  late final Rect _dstRect = Rect.fromCenter(
    center: Offset.zero,
    width: _spriteSize,
    height: _spriteSize,
  );
  late final double _shadowRadiusX = _spriteSize * 0.32;
  late final double _shadowRadiusY = _spriteSize * 0.14;
  late final double _shadowFootY = _spriteSize * 0.34;
  late final Offset _shadowCenter = Offset(0, _shadowFootY);
  final Paint _shadowPaint = Paint()..color = const Color(0x33000000);
  final Paint _bodyPaint = Paint();
  final Paint _eyePaint = Paint()..color = Colors.white;
  final Paint _invertRing = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..color = const Color(0xFFFF1744);
  static const Offset _eyeOffset = Offset(2, -2);

  // ── Tuning ─────────────────────────────────────────────────────────────────
  static const double _twoPi = 2 * pi;
  static const double _halfPi = pi / 2;
  static const double _baseFps = 10; // fps at the slowest walk
  static const double _maxFps = 14; // fps at full speed
  static const double _idleSpeed = 22; // below this, freeze on frame 0 (<100ms)
  static const double _facingDeadzone = 4; // hysteresis so we don't flip-flop
  static const double _moveEaseRate = 12; // how fast bob/lean fade in and out
  static const double _footStrikeDuration = 0.08; // 80ms squash window
  static const double _breathHz = 1.5;
  static const double _breathAmp = 1.2 * pi / 180; // ±1.2°
  static const double _leanMax = 4 * pi / 180; // ~4° lean into movement

  void setInput(Vector2 rawInput) {
    _rawInput.setFrom(rawInput);
    if (_rawInput.x.abs() > _rawInput.y.abs()) {
      _rawInput.y = 0;
      _rawInput.x = _rawInput.x.sign;
    } else if (_rawInput.y.abs() > 0) {
      _rawInput.x = 0;
      _rawInput.y = _rawInput.y.sign;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    _desired.setFrom(_rawInput);
    if (controlsInverted) {
      _desired.scale(-1);
    }
    if (_desired.length2 > 0) {
      _desired.normalize();
    }

    final targetVx = _desired.x * config.playerMaxSpeed;
    final targetVy = _desired.y * config.playerMaxSpeed;
    final accel = config.playerAcceleration * dt;

    _alignToGridLane(_desired, dt);

    _velocity.x = _approach(_velocity.x, targetVx, accel);
    _velocity.y = _approach(_velocity.y, targetVy, accel);

    _probe.setValues(position.x + _velocity.x * dt, position.y);
    if (maze.isCircleWalkable(_probe, config.playerRadius)) {
      position.x = _probe.x;
    } else {
      _velocity.x = 0;
    }

    _probe.setValues(position.x, position.y + _velocity.y * dt);
    if (maze.isCircleWalkable(_probe, config.playerRadius)) {
      position.y = _probe.y;
    } else {
      _velocity.y = 0;
    }

    _clampInsideMaze();
    _advanceWalkCycle(dt);
  }

  void _advanceWalkCycle(double dt) {
    final speed = _velocity.length;
    final speed01 = (speed / config.playerMaxSpeed).clamp(0.0, 1.0);
    final moving = speed > _idleSpeed;

    // Flip only when horizontal velocity clearly reverses (single bool).
    if (_velocity.x.abs() > _facingDeadzone) {
      _lastFacing = _velocity.x < 0 ? -1 : 1;
    }

    // Ease the "walking" factor so bob/lean/squash don't pop on/off.
    final moveTarget = moving ? 1.0 : 0.0;
    _moveFactor +=
        (moveTarget - _moveFactor) * (dt * _moveEaseRate).clamp(0.0, 1.0);

    // Phase advances from elapsed time × speed-scaled fps — never a frame++.
    if (moving) {
      final fps = _baseFps + (_maxFps - _baseFps) * speed01;
      _phase += _twoPi * (fps / _frameCount) * dt;
      while (_phase >= _twoPi) {
        _phase -= _twoPi;
      }
      _frame = ((_phase / _twoPi) * _frameCount).floor();
      if (_frame >= _frameCount) {
        _frame = _frameCount - 1;
      }
    } else {
      _phase = 0;
      _frame = 0; // idle stance, frozen on frame 0
    }

    // Vertical bob: two foot-steps per full frame cycle. up in 0..1, 1 = top.
    final up = 0.5 + 0.5 * sin(_phase * 2 - _halfPi);

    // Foot strike = local minimum of the bob (body lowest). Fire once per trough.
    final falling = up < _prevUp;
    if (_prevFalling && !falling && moving) {
      _footStrikeTimer = _footStrikeDuration;
    }
    _prevFalling = falling;
    _prevUp = up;
    _footStrikeTimer = max(0.0, _footStrikeTimer - dt);

    _bobOffset = -_bobAmplitude * up * _moveFactor;
    _groundContact = (1.0 - up) * _moveFactor;

    // Squash (strike, timer 1->0): y 0.92 / x 1.08. Stretch (toe-off, top):
    // y 1.06 / x 0.96. Plus 2% head-foreshorten at the peak of the bob.
    final strike = _footStrikeTimer / _footStrikeDuration;
    final stretch = (up * 2 - 1).clamp(0.0, 1.0);
    final s = _moveFactor;
    _scaleY = 1.0 + (0.06 * stretch - 0.08 * strike + 0.02 * up) * s;
    _scaleX = 1.0 + (0.08 * strike - 0.04 * stretch) * s;

    // Breathing sway (Z): ±1.2° at 1.5Hz, independent of movement.
    _breathPhase += _twoPi * _breathHz * dt;
    while (_breathPhase >= _twoPi) {
      _breathPhase -= _twoPi;
    }
    _breathSin = sin(_breathPhase);

    // Lean into movement direction, scaled by horizontal speed and walk factor.
    final horiz = (_velocity.x.abs() / config.playerMaxSpeed).clamp(0.0, 1.0);
    final lean = _leanMax * _lastFacing * horiz * s;
    _rotation = _breathAmp * _breathSin + lean;
  }

  void _alignToGridLane(Vector2 desired, double dt) {
    final movingHorizontally = desired.x.abs() > 0.01;
    final movingVertically = desired.y.abs() > 0.01;

    if (movingHorizontally && !movingVertically) {
      final targetY = _nearestCellCenter(position.y, maze.rows);
      position.y = _approach(position.y, targetY, _laneAlignSpeed * dt);
    } else if (movingVertically && !movingHorizontally) {
      final targetX = _nearestCellCenter(position.x, maze.cols);
      position.x = _approach(position.x, targetX, _laneAlignSpeed * dt);
    } else if (!movingHorizontally && !movingVertically) {
      final targetX = _nearestCellCenter(position.x, maze.cols);
      final targetY = _nearestCellCenter(position.y, maze.rows);
      position.x = _approach(position.x, targetX, _laneAlignSpeed * dt);
      position.y = _approach(position.y, targetY, _laneAlignSpeed * dt);
    }
  }

  double _nearestCellCenter(double value, int axisCellCount) {
    final tile = GameBalanceConfig.tileSize;
    final rawIndex = ((value / tile) - 0.5).round();
    final clamped = rawIndex.clamp(0, axisCellCount - 1);
    return (clamped + 0.5) * tile;
  }

  void _clampInsideMaze() {
    final r = config.playerRadius;
    position.x = min(
      max(position.x, r),
      maze.cols * GameBalanceConfig.tileSize - r,
    );
    position.y = min(
      max(position.y, r),
      maze.rows * GameBalanceConfig.tileSize - r,
    );
  }

  double _approach(double current, double target, double delta) {
    if (current < target) {
      return min(current + delta, target);
    }
    return max(current - delta, target);
  }

  @override
  void render(Canvas canvas) {
    // Shadow first, in floor space — drawn before the bob transform so it stays
    // planted while the body rises and falls above it.
    final shadowScale = 0.85 + 0.30 * _groundContact;
    final alpha =
        (0.16 + 0.20 * _groundContact + 0.04 * _breathSin).clamp(0.05, 0.5);
    _shadowPaint.color = const Color(0xFF000000).withValues(alpha: alpha);
    canvas.drawOval(
      Rect.fromCenter(
        center: _shadowCenter,
        width: _shadowRadiusX * 2 * shadowScale,
        height: _shadowRadiusY * 2 * shadowScale,
      ),
      _shadowPaint,
    );

    canvas.save();
    canvas.translate(0, _bobOffset);
    if (_rotation != 0) {
      canvas.rotate(_rotation);
    }
    // Horizontal flip folds into the x scale sign — a single bool, no Matrix4.
    canvas.scale(_scaleX * (_lastFacing < 0 ? -1.0 : 1.0), _scaleY);
    _drawBody(canvas);
    canvas.restore();

    if (controlsInverted) {
      canvas.drawCircle(Offset.zero, config.playerRadius + 3, _invertRing);
    }
  }

  void _drawBody(Canvas canvas) {
    final set = spriteSet;
    if (set != null) {
      set.frameAt(_frame).renderRect(canvas, _dstRect);
      return;
    }
    final avatar = avatarSprite;
    if (avatar != null) {
      avatar.renderRect(canvas, _dstRect);
      return;
    }
    _bodyPaint.color = controlsInverted
        ? const Color(0xFFFF5252)
        : const Color(0xFF2962FF);
    canvas.drawCircle(Offset.zero, config.playerRadius, _bodyPaint);
    canvas.drawCircle(_eyeOffset, 1.7, _eyePaint);
  }
}
