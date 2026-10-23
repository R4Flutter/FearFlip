import 'dart:math';

import '../../domain/entities/direction4.dart';
import '../../presentation/gameplay/maze_generator.dart';

/// One box in the maze. Some hold a key, the rest are empty; they all look
/// the same until opened.
class KeyBox {
  KeyBox({
    required this.cell,
    required this.hasKey,
    required this.depth,
    required this.sidePath,
  });

  final Point<int> cell;
  final bool hasKey;

  /// Cells between the box and the start→exit route (0 = on the route).
  final int depth;

  /// The walk from the box back to the route: the box first, the junction on
  /// the route last. Fetching the box means walking it twice, so traps must
  /// never sit on it.
  final List<Point<int>> sidePath;

  bool opened = false;

  /// Stage time the box was opened at (for its reveal animation); -1 if shut.
  double openedAt = -1;
}

/// What stepping onto a cell did to the key hunt.
enum KeyBoxOpenResult {
  /// No shut box there.
  none,

  /// The box was empty.
  empty,

  /// A key, but the exit still needs more.
  key,

  /// The key that unseals the exit.
  unsealed,
}

/// The boxes placed for one stage and how many keys open the exit.
class KeyHuntPlan {
  const KeyHuntPlan({
    required this.boxes,
    required this.keysRequired,
    required this.reservedCells,
  });

  /// A stage without a hunt: the exit is open from the start.
  static const KeyHuntPlan none = KeyHuntPlan(
    boxes: <KeyBox>[],
    keysRequired: 0,
    reservedCells: <Point<int>>{},
  );

  final List<KeyBox> boxes;
  final int keysRequired;

  /// Cells no trap may use: the start→exit route plus every box's side path.
  final Set<Point<int>> reservedCells;

  bool get isActive => keysRequired > 0;
}

/// Runtime state of a stage's key hunt: which boxes are open and whether the
/// exit is unsealed.
class KeyHuntController {
  List<KeyBox> _boxes = const <KeyBox>[];
  int _keysRequired = 0;
  int _keysFound = 0;
  double? _unsealedAt;

  /// Starts a stage with [plan] (boxes are fresh, all shut).
  void reset(KeyHuntPlan plan) {
    _boxes = List<KeyBox>.unmodifiable(plan.boxes);
    _keysRequired = plan.keysRequired;
    _keysFound = 0;
    _unsealedAt = null;
  }

  /// A stage without a hunt.
  void clear() => reset(KeyHuntPlan.none);

  bool get isActive => _keysRequired > 0;
  List<KeyBox> get boxes => _boxes;
  int get keysRequired => _keysRequired;
  int get keysFound => _keysFound;
  int get keysLeft => max(0, _keysRequired - _keysFound);
  int get boxesLeft => _boxes.where((box) => !box.opened).length;

  /// True once enough keys are found (always true on a stage without a hunt).
  bool get exitUnsealed => _keysFound >= _keysRequired;

  /// Stage time the exit was unsealed at, or null while sealed (or no hunt).
  double? get unsealedAt => _unsealedAt;

  Iterable<KeyBox> get unopened => _boxes.where((box) => !box.opened);

  /// Opens the shut box at [cell], if any, at stage time [time].
  KeyBoxOpenResult openAt(Point<int> cell, double time) {
    for (final box in _boxes) {
      if (box.opened || box.cell != cell) {
        continue;
      }
      box
        ..opened = true
        ..openedAt = time;
      if (!box.hasKey) {
        return KeyBoxOpenResult.empty;
      }
      final wasSealed = !exitUnsealed;
      _keysFound += 1;
      if (wasSealed && exitUnsealed) {
        _unsealedAt = time;
        return KeyBoxOpenResult.unsealed;
      }
      return KeyBoxOpenResult.key;
    }
    return KeyBoxOpenResult.none;
  }

  /// Whether a runner standing on [player] escapes through [exit].
  bool canEscape(Point<int> player, Point<int> exit) =>
      player == exit && exitUnsealed;

  /// The shut box with the shortest walk from [from], or null when none is
  /// left or reachable.
  KeyBox? nearestUnopened(MazeGrid maze, Point<int> from) {
    final shut = unopened.toList(growable: false);
    if (shut.isEmpty) {
      return null;
    }
    final distances = _walkFrom(maze, from).distances;
    KeyBox? best;
    var bestDistance = 1 << 30;
    for (final box in shut) {
      final d = distances[box.cell];
      if (d != null && d < bestDistance) {
        best = box;
        bestDistance = d;
      }
    }
    return best;
  }

  /// Cells on the walks from [from] to [exit] and to every shut box: where
  /// the runner still has to go. Used to keep traps off them after the maze
  /// shifts.
  Set<Point<int>> objectiveCells(
    MazeGrid maze,
    Point<int> from,
    Point<int> exit,
  ) {
    final walk = _walkFrom(maze, from);
    final cells = <Point<int>>{};
    void addPathTo(Point<int> target) {
      if (!walk.parents.containsKey(target)) {
        return;
      }
      Point<int>? cursor = target;
      while (cursor != null && cells.add(cursor)) {
        cursor = walk.parents[cursor];
      }
    }

    addPathTo(exit);
    for (final box in unopened) {
      addPathTo(box.cell);
    }
    return cells;
  }

  static _Walk _walkFrom(MazeGrid maze, Point<int> from) {
    final distances = <Point<int>, int>{from: 0};
    final parents = <Point<int>, Point<int>?>{from: null};
    final queue = <Point<int>>[from];
    var index = 0;
    while (index < queue.length) {
      final current = queue[index++];
      for (final direction in Direction4.values) {
        if (!maze.canMove(current, direction)) {
          continue;
        }
        final next = maze.move(current, direction);
        if (distances.containsKey(next)) {
          continue;
        }
        distances[next] = distances[current]! + 1;
        parents[next] = current;
        queue.add(next);
      }
    }
    return _Walk(distances, parents);
  }
}

class _Walk {
  const _Walk(this.distances, this.parents);

  final Map<Point<int>, int> distances;
  final Map<Point<int>, Point<int>?> parents;
}
