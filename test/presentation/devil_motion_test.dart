import 'dart:math';

import 'package:fearflipgame/domain/entities/direction4.dart';
import 'package:fearflipgame/presentation/gameplay/devil_motion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('it glides from cell to cell over the length of a step', () {
    final m = DevilMotion()..place(const Point(2, 2));
    m.step(const Point(3, 2), 10, 0.5);

    expect(m.positionAt(10), const Offset(2, 2));
    expect(m.positionAt(10.25), const Offset(2.5, 2));
    expect(m.positionAt(10.5), const Offset(3, 2));
    expect(m.positionAt(11), const Offset(3, 2));
  });

  test('it faces the way it walks', () {
    final m = DevilMotion()..place(const Point(2, 2));
    m.step(const Point(1, 2), 0, 0.4);
    expect(m.facing, Direction4.left);
    m.step(const Point(1, 1), 0.4, 0.4);
    expect(m.facing, Direction4.up);
    m.step(const Point(2, 1), 0.8, 0.4);
    expect(m.facing, Direction4.right);
    m.step(const Point(2, 2), 1.2, 0.4);
    expect(m.facing, Direction4.down);
  });

  test('it walks through a steady chase and stands once it stops', () {
    final m = DevilMotion()..place(const Point(0, 0));
    expect(m.movingAt(0), isFalse);

    m.step(const Point(1, 0), 0, 0.4);
    expect(m.movingAt(0.2), isTrue);
    expect(m.movingAt(0.45), isTrue); // the gap before the next step
    expect(m.movingAt(1), isFalse); // frozen: no more steps
  });

  test('a step taken mid-glide carries on from where it is drawn', () {
    final m = DevilMotion()..place(const Point(0, 0));
    m.step(const Point(1, 0), 0, 1);
    m.step(const Point(1, 1), 0.5, 1); // half-way along the first step

    expect(m.positionAt(0.5), const Offset(0.5, 0));
    expect(m.positionAt(1.5), const Offset(1, 1));
  });

  test('a jump (or the catch lunge) puts it straight on the cell', () {
    final m = DevilMotion()..place(const Point(0, 0));
    m.step(const Point(5, 5), 0, 0.4);
    expect(m.positionAt(0), const Offset(5, 5));

    m.step(const Point(6, 5), 1, 0.4);
    m.place(const Point(6, 5));
    expect(m.positionAt(1), const Offset(6, 5));
    expect(m.movingAt(1), isFalse);

    m.place(null);
    expect(m.positionAt(2), isNull);
  });
}
