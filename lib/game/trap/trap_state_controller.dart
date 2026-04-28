import 'dart:math';

import 'trap_tile.dart';

/// Manages all trap-tile state transitions and exposes query methods for the
/// game loop.
class TrapStateController {
  TrapStateController();

  final List<TrapTile> _tiles = <TrapTile>[];

  /// Optional callback fired when a tile transitions to [TrapState.critical].
  void Function(TrapTile tile)? onCriticalTrigger;

  /// Optional callback fired for subtle hidden-tile suspicion cues.
  void Function(TrapTile tile)? onHiddenSuspicionCue;

  /// Replace all traps with [tiles] at stage start / maze reset.
  void reset(List<TrapTile> tiles) {
    _tiles
      ..clear()
      ..addAll(tiles);
  }

  /// Read-only access to all trap tiles for rendering.
  List<TrapTile> get activeTiles => _tiles;

  /// Returns true if any trap tile exists at [cell].
  bool hasTrapAt(Point<int> cell) =>
      _tiles.any((t) => t.cell == cell && t.state != TrapState.collapsed);

  /// Returns the trap at [cell], or null.
  TrapTile? trapAt(Point<int> cell) {
    for (final t in _tiles) {
      if (t.cell == cell) return t;
    }
    return null;
  }

  /// Called when the player moves to a new [cell].
  TrapStepResult onPlayerStep(Point<int> cell, {int playerStepCount = 0}) {
    final tile = trapAt(cell);
    if (tile == null) return TrapStepResult.noTrap;

    switch (tile.state) {
      case TrapState.hidden:
        tile.state = TrapState.cracked;
        tile.revealedAtStep = playerStepCount;
        return TrapStepResult.trapRevealed;

      case TrapState.cracked:
      case TrapState.critical:
        tile.state = TrapState.collapsed;
        tile.collapsedAtStep = playerStepCount;
        return TrapStepResult.trapCollapsed;

      case TrapState.collapsed:
        return TrapStepResult.noTrap;
    }
  }

  /// Advances tile visuals and proximity-pressure transitions.
  void update(
    double dt,
    Point<int> playerCell, {
    int criticalDistance = 1,
    int playerStepCount = 0,
    bool panicMode = false,
    Point<int>? devilCell,
    double hiddenCueLevel = 0,
  }) {
    for (final tile in _tiles) {
      if (tile.state == TrapState.cracked || tile.state == TrapState.critical) {
        tile.particlePhase += dt;
        tile.pulsePhase += dt;
      } else if (tile.state == TrapState.hidden) {
        tile.particlePhase += dt * 0.5;
      }

      _maybeFireHiddenSuspicionCue(
        tile: tile,
        playerCell: playerCell,
        hiddenCueLevel: hiddenCueLevel,
      );
      _maybeEscalateToCritical(
        tile: tile,
        playerCell: playerCell,
        criticalDistance: criticalDistance,
        playerStepCount: playerStepCount,
        panicMode: panicMode,
        devilCell: devilCell,
      );
    }
  }

  /// Returns all trap cells that are in a visible, non-hidden state.
  Set<Point<int>> get visibleTrapCells {
    final result = <Point<int>>{};
    for (final t in _tiles) {
      if (t.state != TrapState.hidden) {
        result.add(t.cell);
      }
    }
    return result;
  }

  /// Number of traps the player has triggered this run.
  int get triggeredCount =>
      _tiles.where((t) => t.state != TrapState.hidden).length;

  void _maybeFireHiddenSuspicionCue({
    required TrapTile tile,
    required Point<int> playerCell,
    required double hiddenCueLevel,
  }) {
    if (tile.state != TrapState.hidden || hiddenCueLevel <= 0.05) {
      return;
    }

    final dist = _manhattan(tile.cell, playerCell);
    if (dist == 1 && !tile.suspicionCuePrimed) {
      tile.suspicionCuePrimed = true;
      onHiddenSuspicionCue?.call(tile);
    } else if (dist > 2) {
      tile.suspicionCuePrimed = false;
    }
  }

  void _maybeEscalateToCritical({
    required TrapTile tile,
    required Point<int> playerCell,
    required int criticalDistance,
    required int playerStepCount,
    required bool panicMode,
    required Point<int>? devilCell,
  }) {
    if (tile.state != TrapState.cracked) {
      return;
    }

    final dist = _manhattan(tile.cell, playerCell);
    final devilDist = devilCell == null ? 99 : _manhattan(tile.cell, devilCell);
    final pressureDistance = panicMode
        ? criticalDistance + 1
        : criticalDistance;
    final playerPressure = dist <= pressureDistance && dist > 0;
    final devilPressure =
        devilDist <= 2 && dist <= criticalDistance + 2 && dist > 0;

    if (!playerPressure && !devilPressure) {
      return;
    }

    tile.state = TrapState.critical;
    tile.criticalAtStep = playerStepCount;
    tile.pulsePhase = 0;
    onCriticalTrigger?.call(tile);
  }

  int _manhattan(Point<int> a, Point<int> b) =>
      (a.x - b.x).abs() + (a.y - b.y).abs();
}
