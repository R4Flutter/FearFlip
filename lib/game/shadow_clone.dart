import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'game_config.dart';
import 'maze.dart';

class ShadowCloneComponent extends PositionComponent {
  ShadowCloneComponent({
    required this.maze,
    required this.config,
    required Vector2 spawnAt,
    required this.random,
  }) : super(
         position: spawnAt,
         anchor: Anchor.center,
         size: Vector2.all(config.playerRadius * 2),
         priority: 18,
       );

  final MazeData maze;
  final RuntimeBalanceConfig config;
  final Random random;

  Vector2 _dir = Vector2(1, 0);
  double _changeDirectionTimer = 0;

  @override
  void update(double dt) {
    super.update(dt);

    _changeDirectionTimer -= dt;
    if (_changeDirectionTimer <= 0) {
      _changeDirectionTimer = 0.35 + random.nextDouble() * 1.2;
      final dirs = <Vector2>[
        Vector2(1, 0),
        Vector2(-1, 0),
        Vector2(0, 1),
        Vector2(0, -1),
      ];
      _dir = dirs[random.nextInt(dirs.length)];
    }

    final delta = _dir * config.shadowCloneSpeed * dt;
    final next = position + delta;
    if (maze.isCircleWalkable(next, config.playerRadius * 0.8)) {
      position.setFrom(next);
    } else {
      _dir.scale(-1);
    }
  }

  @override
  void render(Canvas canvas) {
    final ghost = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.35);
    canvas.drawCircle(Offset.zero, config.playerRadius * 0.95, ghost);
  }
}
