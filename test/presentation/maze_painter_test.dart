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

MazePainter _painter(
  MazeGrid maze,
  MazeArt art, {
  bool flipped = false,
  double time = 0,
  List<MazeFx> effects = const [],
}) => MazePainter(
  maze: maze,
  playerCellPosition: Offset.zero,
  direction: Direction4.right,
  currentFrame: 0,
  isMoving: false,
  pulse: 0,
  time: time,
  art: art,
  isFlippedMode: flipped,
  effects: effects,
);

/// A closed n×n maze, start top-left, exit bottom-right.
MazeGrid _bigMaze(int n) => MazeGrid(
  rows: n,
  cols: n,
  cells: List.generate(n, (_) => List.generate(n, (_) => MazeCell())),
  start: const Point<int>(0, 0),
  end: Point<int>(n - 1, n - 1),
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

  // The exit, cell (3, 3), is block tile (7, 7): pixels 160..180 square.
  const exitPixel = Offset(170, 170);

  testWidgets('the exit shows its stairway art, a different one per world', (
    tester,
  ) async {
    final art = (await tester.runAsync(MazeArt.load))!;
    addTearDown(art.dispose);
    final maze = _maze();
    final standIn = await tester.runAsync(
      () => _pixel(_painter(maze, const MazeArt.none()), exitPixel),
    );
    final wake = await tester.runAsync(
      () => _pixel(_painter(maze, art), exitPixel),
    );
    final nightmare = await tester.runAsync(
      () => _pixel(_painter(maze, art, flipped: true), exitPixel),
    );
    expect(standIn, const Color(0xFFFFC83D)); // the flat gold stand-in
    expect(wake, isNot(standIn));
    expect(nightmare, isNot(wake));
  });

  testWidgets('an off-screen exit is pointed at by the bone arrow', (
    tester,
  ) async {
    final art = (await tester.runAsync(MazeArt.load))!;
    addTearDown(art.dispose);
    // 25×25 tiles, camera on the top-left: the exit is far off the bottom
    // right, so the pointer sits on the view's corner, 0.55 tile in.
    final maze = _bigMaze(12);
    const corner = Offset(208, 208);
    final standIn = await tester.runAsync(
      () => _pixel(_painter(maze, const MazeArt.none()), corner),
    );
    final bone = await tester.runAsync(
      () => _pixel(_painter(maze, art), corner),
    );
    expect(bone, isNot(standIn));
  });

  testWidgets('the flip bursts red cracks across the floor around the runner', (
    tester,
  ) async {
    final art = (await tester.runAsync(MazeArt.load))!;
    addTearDown(art.dispose);
    final maze = _maze();
    // A tile below-right of the runner (cell 0,0 at pixels 40..60): inside
    // the 3-tile burst, clear of the runner's own glow.
    const nearRunner = Offset(66, 66);
    final calm = await tester.runAsync(
      () => _pixel(_painter(maze, art, time: 0.3), nearRunner),
    );
    final burst = await tester.runAsync(
      () => _pixel(
        _painter(
          maze,
          art,
          time: 0.3,
          effects: const [MazeFx(MazeFxKind.flip, Offset.zero, 0)],
        ),
        nearRunner,
      ),
    );
    expect(burst, isNot(calm));
    expect(burst!.r, greaterThan(calm!.r)); // red light added
  });

  testWidgets('the dark swallows the maze away from the runner light', (
    tester,
  ) async {
    // Camera on the top-left of a 25×25-tile maze, runner in cell (0, 0).
    final maze = _bigMaze(12);
    final painter = _painter(maze, const MazeArt.none());
    // Cell (1, 0), two tiles from the runner: fully lit.
    final near = await tester.runAsync(
      () => _pixel(painter, const Offset(70, 30)),
    );
    // Cell (4, 4), over eleven tiles away: deep in the dark.
    final far = await tester.runAsync(
      () => _pixel(painter, const Offset(190, 190)),
    );
    expect(near, const Color(0xFF3B4660));
    double lum(Color c) => c.r + c.g + c.b;
    expect(lum(far!), lessThan(lum(near!) * 0.5));
  });
}
