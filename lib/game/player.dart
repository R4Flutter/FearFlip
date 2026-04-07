import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'game_config.dart';
import 'maze.dart';

class PlayerComponent extends PositionComponent {
  PlayerComponent({required this.maze, required this.config, this.avatarSprite})
    : super(
        anchor: Anchor.center,
        size: Vector2.all(config.playerRadius * 2),
        priority: 20,
      );

  final MazeData maze;
  final RuntimeBalanceConfig config;
  final Sprite? avatarSprite;

  final Vector2 _velocity = Vector2.zero();
  Vector2 _rawInput = Vector2.zero();
  bool controlsInverted = false;
  static const double _laneAlignSpeed = 420;

  void setInput(Vector2 rawInput) {
    final clamped = rawInput.clone();
    if (clamped.x.abs() > clamped.y.abs()) {
      clamped.y = 0;
      clamped.x = clamped.x.sign;
    } else if (clamped.y.abs() > 0) {
      clamped.x = 0;
      clamped.y = clamped.y.sign;
    }
    _rawInput = clamped;
  }

  @override
  void update(double dt) {
    super.update(dt);

    final desired = _rawInput.clone();
    if (controlsInverted) {
      desired.scale(-1);
    }

    if (desired.length2 > 0) {
      desired.normalize();
    }

    final targetVelocity = desired * config.playerMaxSpeed;
    final accel = config.playerAcceleration * dt;

    _alignToGridLane(desired, dt);

    _velocity.x = _approach(_velocity.x, targetVelocity.x, accel);
    _velocity.y = _approach(_velocity.y, targetVelocity.y, accel);

    final nextX = Vector2(position.x + _velocity.x * dt, position.y);
    if (maze.isCircleWalkable(nextX, config.playerRadius)) {
      position.x = nextX.x;
    } else {
      _velocity.x = 0;
    }

    final nextY = Vector2(position.x, position.y + _velocity.y * dt);
    if (maze.isCircleWalkable(nextY, config.playerRadius)) {
      position.y = nextY.y;
    } else {
      _velocity.y = 0;
    }

    _clampInsideMaze();
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
    if (avatarSprite != null) {
      final spriteSize = GameBalanceConfig.tileSize * 0.82;
      final dst = Rect.fromCenter(
        center: Offset.zero,
        width: spriteSize,
        height: spriteSize,
      );
      avatarSprite!.renderRect(canvas, dst);

      if (controlsInverted) {
        final ring = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFFF1744);
        canvas.drawCircle(Offset.zero, config.playerRadius + 3, ring);
      }
      return;
    }

    final body = Paint()
      ..color = controlsInverted
          ? const Color(0xFFFF5252)
          : const Color(0xFF2962FF);
    canvas.drawCircle(Offset.zero, config.playerRadius, body);

    final eye = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(2, -2), 1.7, eye);
  }
}
