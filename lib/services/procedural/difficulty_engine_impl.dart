import '../../domain/procedural/procedural_modules.dart';

class DifficultyEngineImpl implements DifficultyEngine {
  @override
  double clamp(double difficulty) {
    if (difficulty.isNaN || difficulty.isInfinite) {
      return 0.0;
    }
    return difficulty.clamp(0.0, 1.0);
  }

  @override
  double nextLevelBasedDifficulty({
    required int levelIndex,
    double baseDifficulty = 0.0,
  }) {
    final normalizedBase = clamp(baseDifficulty);
    final progression = levelIndex <= 0 ? 0.0 : levelIndex * 0.01;
    return clamp(normalizedBase + progression);
  }

  @override
  double timeBasedDifficulty({
    required double timeSurvivedSeconds,
    required double maxTimeSeconds,
  }) {
    if (maxTimeSeconds <= 0) {
      return 0.0;
    }
    return clamp(timeSurvivedSeconds / maxTimeSeconds);
  }
}
