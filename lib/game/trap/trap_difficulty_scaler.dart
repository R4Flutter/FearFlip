/// Maps stage number and difficulty to trap-placement parameters.
///
/// All values are tunable at runtime through [TrapBalanceConfig].
class TrapBalanceConfig {
  const TrapBalanceConfig({
    this.trapDensityMultiplier = 1.0,
    this.chokePointMinDifficulty = 0.6,
    this.hiddenCueIntensity = 1.0,
    this.nearStartProtectionRadius = 3,
    this.nearGoalProtectionRadius = 2,
    this.criticalTriggerDistance = 1,
    this.enabled = true,
  });

  /// Scales the formula-based trap count. 1.0 = default density.
  final double trapDensityMultiplier;

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

  /// Global kill-switch. When false, no traps are placed.
  final bool enabled;
}

/// Stage-aware configuration produced by [TrapDifficultyScaler].
class TrapStageConfig {
  const TrapStageConfig({
    required this.trapsEnabled,
    required this.trapCount,
    required this.allowChokepoints,
    required this.hiddenCueLevel,
    required this.criticalTriggerDistance,
  });

  /// Whether traps should appear at all on this stage.
  final bool trapsEnabled;

  /// Target number of trap tiles to place (before density multiplier).
  final int trapCount;

  /// Whether chokepoint cells are eligible for trap placement.
  final bool allowChokepoints;

  /// Visual cue intensity for Hidden tiles (0.0–1.0).
  final double hiddenCueLevel;

  /// Manhattan distance for Cracked → Critical proximity trigger.
  final int criticalTriggerDistance;
}

/// Derives per-stage trap configuration from the stage number and an
/// optional [TrapBalanceConfig] for live-tuning.
class TrapDifficultyScaler {
  const TrapDifficultyScaler({
    this.config = const TrapBalanceConfig(),
  });

  final TrapBalanceConfig config;

  /// Returns the trap configuration for the given [stage] and maze size.
  ///
  /// [walkableCellCount] is the total number of path cells in the generated
  /// maze — used to compute density-based trap counts.
  TrapStageConfig configForStage({
    required int stage,
    required int walkableCellCount,
  }) {
    if (!config.enabled || stage < 8) {
      return const TrapStageConfig(
        trapsEnabled: false,
        trapCount: 0,
        allowChokepoints: false,
        hiddenCueLevel: 0,
        criticalTriggerDistance: 1,
      );
    }

    final density = _densityForStage(stage);
    final rawCount = (walkableCellCount * density * config.trapDensityMultiplier)
        .floor()
        .clamp(1, 16);

    return TrapStageConfig(
      trapsEnabled: true,
      trapCount: rawCount,
      allowChokepoints: _normalised(stage) >= config.chokePointMinDifficulty,
      hiddenCueLevel:
          (_hiddenCueForStage(stage) * config.hiddenCueIntensity)
              .clamp(0.0, 1.0),
      criticalTriggerDistance: stage >= 41 ? 2 : config.criticalTriggerDistance,
    );
  }

  // ── internal helpers ───────────────────────────────────────────────

  double _densityForStage(int stage) {
    if (stage <= 10) return 0.03;
    if (stage <= 15) return 0.05;
    if (stage <= 25) return 0.07;
    if (stage <= 50) return 0.09;
    if (stage <= 75) return 0.11;
    return 0.13;
  }

  double _hiddenCueForStage(int stage) {
    if (stage <= 15) return 1.0;  // Strong cues
    if (stage <= 25) return 0.7;  // Moderate
    if (stage <= 40) return 0.4;  // Light
    if (stage <= 60) return 0.15; // Minimal
    return 0.0;                   // Zero — memory mastery
  }

  /// Normalised difficulty 0→1 across stages 1→100.
  double _normalised(int stage) => ((stage - 1) / 99).clamp(0.0, 1.0);
}
