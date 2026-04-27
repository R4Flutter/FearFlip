import 'dart:math';

import 'trap_tile.dart';

/// Manages all trap-tile state transitions and exposes query methods
/// for the game loop.
///
/// The controller owns the list of [TrapTile]s for the current stage,
/// handles Hidden→Cracked→Critical→Collapsed transitions, and returns
/// [TrapStepResult] so the caller can react (e.g. trigger death sequence).
class TrapStateController {
  TrapStateController();

  final List<TrapTile> _tiles = <TrapTile>[];

  /// Optional callback fired when a tile transitions to [TrapState.critical].
  void Function(TrapTile tile)? onCriticalTrigger;

  // ── public API ─────────────────────────────────────────────────────

  /// Replace all traps with [tiles] (called at stage start / maze reset).
  void reset(List<TrapTile> tiles) {
    _tiles
      ..clear()
      ..addAll(tiles);
  }

  /// Read-only access to all trap tiles for rendering.
  List<TrapTile> get activeTiles => _tiles;

  /// Returns `true` if any trap tile exists at [cell].
  bool hasTrapAt(Point<int> cell) =>
      _tiles.any((t) => t.cell == cell && t.state != TrapState.collapsed);

  /// Returns the trap at [cell], or `null`.
  TrapTile? trapAt(Point<int> cell) {
    for (final t in _tiles) {
      if (t.cell == cell) return t;
    }
    return null;
  }

  /// Called when the player moves to a new [cell].
  ///
  /// Returns [TrapStepResult.trapRevealed] when a hidden trap is triggered,
  /// [TrapStepResult.trapCollapsed] when the player falls through a cracked
  /// or critical tile, and [TrapStepResult.noTrap] otherwise.
  ///
  /// [playerStepCount] is the total number of steps taken this run — stored
  /// on the tile for analytics.
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
        return TrapStepResult.trapCollapsed;

      case TrapState.collapsed:
        // Already collapsed — treat as void (no effect).
        return TrapStepResult.noTrap;
    }
  }

  /// Called every tick to advance particle/pulse animations and handle
  /// proximity-based Cracked→Critical transitions.
  ///
  /// [playerCell] is the player's current maze-grid cell.
  /// [criticalDistance] is the Manhattan distance threshold (usually 1).
  void update(double dt, Point<int> playerCell, {int criticalDistance = 1}) {
    for (final tile in _tiles) {
      // Advance visual phases for active tiles.
      if (tile.state == TrapState.cracked || tile.state == TrapState.critical) {
        tile.particlePhase += dt;
        tile.pulsePhase += dt;
      } else if (tile.state == TrapState.hidden) {
        tile.particlePhase += dt * 0.5; // Slow drift for hidden dust.
      }

      // Proximity trigger: Cracked → Critical when player is close.
      if (tile.state == TrapState.cracked) {
        final dist = _manhattan(tile.cell, playerCell);
        if (dist <= criticalDistance && dist > 0) {
          tile.state = TrapState.critical;
          tile.pulsePhase = 0; // Reset pulse on transition.
          onCriticalTrigger?.call(tile);
        }
      }
    }
  }

  /// Returns all trap cells that are in a visible (non-hidden) state,
  /// useful for avoiding cheapshots after cracking.
  Set<Point<int>> get visibleTrapCells {
    final result = <Point<int>>{};
    for (final t in _tiles) {
      if (t.state != TrapState.hidden) {
        result.add(t.cell);
      }
    }
    return result;
  }

  /// Number of traps the player has triggered (cracked or worse) this run.
  int get triggeredCount =>
      _tiles.where((t) => t.state != TrapState.hidden).length;

  // ── internal ───────────────────────────────────────────────────────

  int _manhattan(Point<int> a, Point<int> b) =>
      (a.x - b.x).abs() + (a.y - b.y).abs();
}
