import 'dart:math';

/// Help for a player stuck on one stage, never announced (see
/// docs/retention_features.md). From the [failThreshold]th failure in a row
/// on a stage, each try at it gets [bonusSecondsPerLevel] more per level, up
/// to [maxLevel]; from level 2 it also gets one more safe zone. Clearing any
/// stage resets it.
class QuietMercy {
  QuietMercy({
    this.enabled = true,
    this.failThreshold = 3,
    this.maxLevel = 2,
    this.bonusSecondsPerLevel = 10,
  });

  final bool enabled;
  final int failThreshold;
  final int maxLevel;
  final int bonusSecondsPerLevel;

  int _stage = 0;
  int _fails = 0;

  /// Failures in a row on [stage] (0 for any other stage).
  int failuresOn(int stage) => stage == _stage ? _fails : 0;

  void recordFailure(int stage) {
    if (stage == _stage) {
      _fails += 1;
    } else {
      _stage = stage;
      _fails = 1;
    }
  }

  /// A stage was cleared: whoever was stuck isn't any more.
  void clear() {
    _stage = 0;
    _fails = 0;
  }

  int levelFor(int stage) {
    if (!enabled || stage != _stage || failThreshold <= 0) {
      return 0;
    }
    return (_fails - failThreshold + 1).clamp(0, max(0, maxLevel)).toInt();
  }

  int bonusSecondsFor(int stage) => levelFor(stage) * bonusSecondsPerLevel;

  int extraSafeZonesFor(int stage) => levelFor(stage) >= 2 ? 1 : 0;
}
