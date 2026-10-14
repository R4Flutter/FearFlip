import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fearflipgame/domain/entities/direction4.dart';
import 'package:fearflipgame/presentation/gameplay/maze_art.dart';
import 'package:fearflipgame/presentation/gameplay/maze_generator.dart';
import 'package:fearflipgame/presentation/gameplay/maze_painter.dart';

/// A 4×4 maze with every wall closed: start top-left, exit bottom-right.
MazeGrid _maze() => MazeGrid(
  rows: 4,
  cols: 4,
  cells: List.generate(4, (_) => List.generate(4, (_) => MazeCell())),
  start: const Point<int>(0, 0),
  end: const Point<int>(3, 3),
);

const _view = Size(220, 220); // 11 tiles of 20 px

MazePainter _painter(MazeGrid maze, MazeArt art, {bool flipped = false}) =>
    MazePainter(
      maze: maze,
      playerCellPosition: Offset.zero,
      direction: Direction4.right,
      currentFrame: 0,
      isMoving: false,
      pulse: 0,
      art: art,
      isFlippedMode: flipped,
    );

/// Paints [painter] and reads back the colour at [at].
Future<Color> _pixel(MazePainter painter, Offset at) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), _view);
  final image = await recorder.endRecording().toImage(
    _view.width.toInt(),
    _view.height.toInt(),
  );
  final bytes = (await image.toByteData())!;
  image.dispose();
  final i = (at.dy.toInt() * _view.width.toInt() + at.dx.toInt()) * 4;
  return Color.fromARGB(
    bytes.getUint8(i + 3),
    bytes.getUint8(i),
    bytes.getUint8(i + 1),
    bytes.getUint8(i + 2),
  );
}

void main() {
  // The 9×9-tile maze is centred in the 11-tile view (a one-tile margin), so
  // cell (1, 0) sits on block tile (3, 1) at pixels 80..100 × 40..60, clear
  // of the start, the runner and the edge arrows.
  const floorPixel = Offset(90, 50);

  testWidgets('without art the floor keeps its stand-in colour', (
    tester,
  ) async {
    final colour = await tester.runAsync(
      () => _pixel(_painter(_maze(), const MazeArt.none()), floorPixel),
    );
    expect(colour, const Color(0xFF3B4660));
  });

  testWidgets('with art the floor is painted from the tile atlas', (
    tester,
  ) async {
    final art = (await tester.runAsync(MazeArt.load))!;
    addTearDown(art.dispose);
    final colour = await tester.runAsync(
      () => _pixel(_painter(_maze(), art), floorPixel),
    );
    expect(colour, isNot(const Color(0xFF3B4660)));
  });

  testWidgets('the flip swaps the WAKE atlas for the NIGHTMARE one', (
    tester,
  ) async {
    final art = (await tester.runAsync(MazeArt.load))!;
    addTearDown(art.dispose);
    final maze = _maze();
    final wake = await tester.runAsync(
      () => _pixel(_painter(maze, art), floorPixel),
    );
    final nightmare = await tester.runAsync(
      () => _pixel(_painter(maze, art, flipped: true), floorPixel),
    );
    expect(nightmare, isNot(wake));
    // NIGHTMARE floors are blood-red: red leads the other channels.
    expect(nightmare!.r, greaterThan(nightmare.b));
  });
}
