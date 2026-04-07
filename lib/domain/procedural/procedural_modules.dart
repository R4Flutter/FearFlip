import 'level_config.dart';

class DifficultyState {
  const DifficultyState({
    required this.value,
    required this.levelIndex,
    required this.timeSurvivedSeconds,
    required this.mode,
  });

  final double value;
  final int levelIndex;
  final double timeSurvivedSeconds;
  final ProgressionMode mode;
}

class ValidationRun {
  const ValidationRun({required this.success, required this.failureReason});

  final bool success;
  final String? failureReason;
}

class ValidationResult {
  const ValidationResult({
    required this.successCount,
    required this.runs,
    required this.passed,
  });

  final int successCount;
  final List<ValidationRun> runs;
  final bool passed;
}

abstract class DifficultyEngine {
  double clamp(double difficulty);

  double nextLevelBasedDifficulty({
    required int levelIndex,
    double baseDifficulty = 0.0,
  });

  double timeBasedDifficulty({
    required double timeSurvivedSeconds,
    required double maxTimeSeconds,
  });
}

abstract class ChaosSystem {
  List<ChaosEventType> selectChaos({
    required double difficulty,
    required int seed,
  });
}

abstract class BreathingSystem {
  List<BreathingEvent> buildPattern({
    required int seed,
    required double totalSeconds,
    required List<double> chaosSpikeTimes,
  });
}

abstract class ProceduralLevelGenerator {
  LevelConfig generate({
    required double difficulty,
    required int seed,
    double totalSeconds = 120,
  });
}

abstract class LevelValidator<TMaze> {
  ValidationResult validate({
    required LevelConfig config,
    required TMaze maze,
    required int seed,
  });
}
