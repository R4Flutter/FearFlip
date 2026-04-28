/// Maps stage number and difficulty to trap-placement parameters.
///
/// All values are tunable at runtime through [TrapBalanceConfig].
class TrapBalanceConfig {
  const TrapBalanceConfig({
    this.trapDensityMultiplier = 1.0,
    this.maxTrapCount = 10,
    this.preferredTJunctionRatio = 0.55,
    this.chokePointMinDifficulty = 0.58,
    this.hiddenCueIntensity = 1.0,
    this.nearStartProtectionRadius = 3,
    this.nearGoalProtectionRadius = 2,
    this.criticalTriggerDistance = 1,
    this.minTrapSpacing = 2,
    this.mainPathClusterSpacing = 4,
    this.earlyPathProtectionRatio = 0.30,
    this.enabled = true,
  });

  /// Scales the formula-based trap count. 1.0 = default density.
  final double trapDensityMultiplier;

  /// Hard cap on the number of trap tiles per stage.
  final int maxTrapCount;

  /// Preferred share of traps that should appear on T-junction tiles.
  final double preferredTJunctionRatio;

  /// Minimum normalised difficulty (0-1) before chokepoint traps appear.
  final double chokePointMinDifficulty;

  /// Visual cue strength for Hidden tiles (0 = invisible, 1 = obvious).
  final double hiddenCueIntensity;

  /// Cells within this Manhattan radius of start are trap-protected.
  final int nearStartProtectionRadius;

  /// Cells within this Manhattan radius of goal are trap-protected.
  final int nearGoalProtectionRadius;

  /// Manhattan distance at which a Cracked tile escalates to Critical.
  final int criticalTriggerDistance;

  /// Minimum Manhattan distance between placed traps.
  final int minTrapSpacing;

  /// Minimum path-index gap between traps on the main route.
  final int mainPathClusterSpacing;

  /// Protected opening share of the start-to-goal route.
  final double earlyPathProtectionRatio;

  /// Global kill-switch. When false, no traps are placed.
  final bool enabled;
}

enum TrapDifficultyBand { tutorial, pressure, mastery, nightmare }

/// Stage-aware configuration produced by [TrapDifficultyScaler].
class TrapStageConfig {
  const TrapStageConfig({
    required this.trapsEnabled,
    required this.trapCount,
    required this.allowChokepoints,
    required this.hiddenCueLevel,
    required this.criticalTriggerDistance,
    this.allowDeadEndEntrances = false,
    this.allowPanicRoutes = false,
    this.allowLoopNodes = false,
    this.minTrapSpacing = 2,
    this.mainPathClusterSpacing = 4,
    this.memoryPressure = 0,
    this.band = TrapDifficultyBand.tutorial,
  });

  /// Whether traps should appear at all on this stage.
  final bool trapsEnabled;

  /// Target number of trap tiles to place (before hard placement validation).
  final int trapCount;

  /// Whether chokepoint cells are eligible for trap placement.
  final bool allowChokepoints;

  /// Visual cue intensity for Hidden tiles (0.0-1.0).
  final double hiddenCueLevel;

  /// Manhattan distance for Cracked -> Critical proximity trigger.
  final int criticalTriggerDistance;

  /// Whether dead-end entrances can become memory punishment traps.
  final bool allowDeadEndEntrances;

  /// Whether panic-route scoring is allowed to influence placement.
  final bool allowPanicRoutes;

  /// Whether loop/cycle nodes are eligible when a maze contains loops.
  final bool allowLoopNodes;

  /// Minimum Manhattan distance between placed traps for this stage.
  final int minTrapSpacing;

  /// Minimum path-index gap between traps on the main route.
  final int mainPathClusterSpacing;

  /// 0-1 pressure used by placement scoring and future live tuning.
  final double memoryPressure;

  /// Coarse stage band for analytics and tuning.
  final TrapDifficultyBand band;
}

/// Derives per-stage trap configuration from the stage number and an
/// optional [TrapBalanceConfig] for live-tuning.
class TrapDifficultyScaler {
  const TrapDifficultyScaler({this.config = const TrapBalanceConfig()});

  final TrapBalanceConfig config;

  /// Returns the trap configuration for the given [stage] and maze size.
  ///
  /// [walkableCellCount] is the total number of path cells in the generated
  /// maze, used to compute density-based trap counts.
  TrapStageConfig configForStage({
    required int stage,
    required int walkableCellCount,
  }) {
    if (!config.enabled || walkableCellCount <= 0) {
      return const TrapStageConfig(
        trapsEnabled: false,
        trapCount: 0,
        allowChokepoints: false,
        hiddenCueLevel: 0,
        criticalTriggerDistance: 1,
      );
    }

    final normalized = _normalised(stage);
    final maxTraps = config.maxTrapCount <= 0 ? 1 : config.maxTrapCount;
    final count = _trapCountForStage(
      stage: stage,
      walkableCellCount: walkableCellCount,
      maxTraps: maxTraps,
    );

    return TrapStageConfig(
      trapsEnabled: count > 0,
      trapCount: count,
      allowChokepoints: normalized >= config.chokePointMinDifficulty,
      allowDeadEndEntrances: stage >= 4,
      allowPanicRoutes: stage >= 8,
      allowLoopNodes: stage >= 18,
      hiddenCueLevel: (_hiddenCueForStage(stage) * config.hiddenCueIntensity)
          .clamp(0.0, 1.0),
      criticalTriggerDistance: stage >= 55
          ? (config.criticalTriggerDistance + 1).clamp(1, 2).toInt()
          : config.criticalTriggerDistance.clamp(1, 2).toInt(),
      minTrapSpacing: stage >= 70
          ? (config.minTrapSpacing - 1).clamp(1, 3).toInt()
          : config.minTrapSpacing.clamp(1, 4).toInt(),
      mainPathClusterSpacing: stage >= 70
          ? (config.mainPathClusterSpacing - 1).clamp(2, 6).toInt()
          : config.mainPathClusterSpacing.clamp(2, 8).toInt(),
      memoryPressure: normalized,
      band: _bandForStage(stage),
    );
  }

  int _trapCountForStage({
    required int stage,
    required int walkableCellCount,
    required int maxTraps,
  }) {
    if (stage <= 3) return 1.clamp(0, maxTraps).toInt();
    if (stage <= 7) return 2.clamp(0, maxTraps).toInt();

    final density = _densityForStage(stage);
    final rawCount =
        (walkableCellCount * density * config.trapDensityMultiplier)
            .round()
            .clamp(1, maxTraps)
            .toInt();

    if (stage <= 15) return rawCount.clamp(2, maxTraps).toInt();
    if (stage <= 30) return rawCount.clamp(3, maxTraps).toInt();
    if (stage <= 55) return rawCount.clamp(4, maxTraps).toInt();
    if (stage <= 80) return rawCount.clamp(5, maxTraps).toInt();
    return rawCount.clamp(6, maxTraps).toInt();
  }

  double _densityForStage(int stage) {
    if (stage <= 10) return 0.020;
    if (stage <= 20) return 0.030;
    if (stage <= 35) return 0.040;
    if (stage <= 55) return 0.050;
    if (stage <= 75) return 0.060;
    return 0.070;
  }

  double _hiddenCueForStage(int stage) {
    if (stage <= 5) return 1.0;
    if (stage <= 15) return 0.82;
    if (stage <= 30) return 0.58;
    if (stage <= 50) return 0.34;
    if (stage <= 70) return 0.16;
    return 0.06;
  }

  TrapDifficultyBand _bandForStage(int stage) {
    if (stage <= 10) return TrapDifficultyBand.tutorial;
    if (stage <= 35) return TrapDifficultyBand.pressure;
    if (stage <= 70) return TrapDifficultyBand.mastery;
    return TrapDifficultyBand.nightmare;
  }

  /// Normalised difficulty 0-1 across stages 1-100.
  double _normalised(int stage) => ((stage - 1) / 99).clamp(0.0, 1.0);
}
