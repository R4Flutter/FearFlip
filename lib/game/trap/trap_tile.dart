import 'dart:math';
import 'dart:ui';

/// The lifecycle states of a fragile trap tile.
enum TrapState {
  /// Tile looks normal. Only ultra-subtle visual cues at high stages.
  hidden,

  /// Player stepped on this tile once — visible crack lines appear.
  cracked,

  /// Player moved adjacent to a cracked tile — pulses with danger.
  critical,

  /// Final state — tile has collapsed, player fell through.
  collapsed,
}

/// Design intent tags assigned when a trap is placed.
///
/// These tags make balancing and analytics more useful than raw coordinates.
enum TrapPressureTag {
  decisionFork,
  memoryReturn,
  panicRoute,
  falseConfidence,
  chokepoint,
  loop,
}

/// Classification of a walkable cell's topological role in the maze.
enum TileTopology {
  corridor,
  tJunction,
  crossroads,
  deadEndEntrance,
  deadEnd,
  chokepoint,
  loopNode,
  nearStart,
  nearGoal,
}

/// Pure data model for a single trap tile. No logic, no rendering.
class TrapTile {
  TrapTile({
    required this.cell,
    required this.crackSeed,
    this.topology,
    this.placementScore = 0,
    this.revisitScore = 0,
    this.pathIndex,
    Set<TrapPressureTag> pressureTags = const <TrapPressureTag>{},
  }) : pressureTags = Set<TrapPressureTag>.unmodifiable(pressureTags);

  /// Maze-grid coordinate of this trap.
  final Point<int> cell;

  /// Deterministic seed for crack-line generation (cell hash + maze seed).
  final int crackSeed;

  /// Topological classification used during placement.
  final TileTopology? topology;

  /// Weighted placement score produced by the trap-placement engine.
  final double placementScore;

  /// Estimated chance that a careless player will need to revisit this tile.
  final double revisitScore;

  /// Index on the start-to-goal route when the tile is on that route.
  final int? pathIndex;

  /// High-level design role used for analytics and future balancing.
  final Set<TrapPressureTag> pressureTags;

  /// Current lifecycle state.
  TrapState state = TrapState.hidden;

  /// Accumulated phase for ambient / dust particles (seconds).
  double particlePhase = 0;

  /// Accumulated phase for the critical-state danger pulse (seconds).
  double pulsePhase = 0;

  /// 0→1 progress used exclusively during the death-collapse animation.
  double collapseProgress = 0;

  /// Lazily-built and cached crack-line path for rendering.
  Path? cachedCrackPath;

  /// Wider variant used for the critical state.
  Path? cachedCrackPathWide;

  /// The game-step count when this tile was first revealed (Hidden→Cracked).
  int? revealedAtStep;

  /// The game-step count when this tile escalated to Critical.
  int? criticalAtStep;

  /// The game-step count when this tile collapsed.
  int? collapsedAtStep;

  /// Prevents hidden cue audio from firing every frame while nearby.
  bool suspicionCuePrimed = false;

  int? stepsSinceReveal(int currentStep) {
    final revealed = revealedAtStep;
    if (revealed == null) return null;
    return currentStep - revealed;
  }
}

/// The result of a player stepping onto a cell that may or may not be a trap.
enum TrapStepResult {
  /// Cell has no trap tile at all.
  noTrap,

  /// A hidden trap was just revealed (Hidden → Cracked).
  trapRevealed,

  /// A cracked/critical trap collapsed — player is dead.
  trapCollapsed,
}
