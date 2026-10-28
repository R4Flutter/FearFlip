import 'dart:math';
import 'dart:ui' show Offset;

import '../../domain/entities/direction4.dart';

/// Where the Devil is drawn. The chase moves it one whole cell at a time;
/// this glides it from cell to cell over the length of a step and turns it
/// to face the way it walks, so it runs instead of jumping between tiles.
class DevilMotion {
  Offset? _from;
  Offset? _to;
  double _start = 0;
  double _duration = 1;
  double _walkUntil = double.negativeInfinity;

  /// The way it last walked.
  Direction4 facing = Direction4.down;

  /// Puts it on [cell] at once, standing (spawn, the catch lunge), or
  /// removes it when [cell] is null.
  void place(Point<int>? cell) {
    final at = cell == null ? null : Offset(cell.x * 1.0, cell.y * 1.0);
    _from = at;
    _to = at;
    _walkUntil = double.negativeInfinity;
  }

  /// One chase step onto [cell], starting at [now] and lasting [duration]
  /// seconds. A step that starts mid-glide carries on from where it is drawn.
  void step(Point<int> cell, double now, double duration) {
    final target = Offset(cell.x * 1.0, cell.y * 1.0);
    final from = positionAt(now);
    if (from == null || (target - from).distance > 1.5) {
      // Not a walk (first step, or the maze moved it): no glide.
      place(cell);
      return;
    }
    final delta = target - from;
    if (delta.dx.abs() >= delta.dy.abs() && delta.dx != 0) {
      facing = delta.dx < 0 ? Direction4.left : Direction4.right;
    } else if (delta.dy != 0) {
      facing = delta.dy < 0 ? Direction4.up : Direction4.down;
    }
    _from = from;
    _to = target;
    _start = now;
    _duration = max(duration, 0.05);
    _walkUntil = now + _duration;
  }

  /// Where it is drawn at [now], in cells; null when it isn't in the maze.
  Offset? positionAt(double now) {
    final from = _from;
    final to = _to;
    if (from == null || to == null) return null;
    final t = ((now - _start) / _duration).clamp(0.0, 1.0);
    return Offset.lerp(from, to, t);
  }

  /// Walking at [now]: mid-step, or in the short gap before the next step of
  /// a steady chase.
  bool movingAt(double now) => now < _walkUntil + _stepGap;

  static const double _stepGap = 0.15;
}
