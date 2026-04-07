import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class SafeZoneComponent extends PositionComponent {
  SafeZoneComponent({required this.initialProtection, required this.tileSize})
    : remainingProtection = initialProtection,
      super(
        anchor: Anchor.center,
        size: Vector2.all(tileSize * 0.9),
        priority: 10,
      );

  final double initialProtection;
  final double tileSize;
  double remainingProtection;

  bool get isActive => remainingProtection > 0;

  @override
  bool containsPoint(Vector2 point) {
    return point.distanceTo(position) <= size.x * 0.5;
  }

  void consume(double dt, bool playerInside) {
    if (!playerInside || remainingProtection <= 0) {
      return;
    }
    remainingProtection = max(0, remainingProtection - dt);
  }

  @override
  void render(Canvas canvas) {
    final intensity = (remainingProtection / initialProtection).clamp(
      0.15,
      1.0,
    );
    final glow = Paint()
      ..color = const Color(0xFF00FF9D).withValues(alpha: intensity * 0.45);
    final core = Paint()
      ..color = const Color(0xFF00FF9D).withValues(alpha: intensity);

    canvas.drawCircle(Offset.zero, size.x * 0.55, glow);
    canvas.drawCircle(Offset.zero, size.x * 0.25, core);
  }
}
