import 'dart:math';

import '../../domain/procedural/level_config.dart';
import '../../domain/procedural/procedural_modules.dart';
import '../../game/maze.dart';

class ProceduralGenerationService {
  ProceduralGenerationService({
    required ProceduralLevelGenerator generator,
    required LevelValidator<MazeData> validator,
    this.maxAttempts = 5,
  }) : _generator = generator,
       _validator = validator;

  final ProceduralLevelGenerator _generator;
  final LevelValidator<MazeData> _validator;
  final int maxAttempts;

  LevelConfig generateValidated({
    required double difficulty,
    required MazeData maze,
    required int seed,
  }) {
    final random = Random(seed);
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final candidateSeed = random.nextInt(0x7fffffff);
      final config = _generator.generate(
        difficulty: difficulty,
        seed: candidateSeed,
      );
      final result = _validator.validate(
        config: config,
        maze: maze,
        seed: candidateSeed,
      );
      if (result.passed) {
        return config;
      }
    }
    return safeLevelConfig(difficulty: difficulty, seed: seed);
  }

  LevelConfig safeLevelConfig({required double difficulty, required int seed}) {
    final d = difficulty.clamp(0.0, 1.0);
    return LevelConfig(
      difficulty: d,
      playerSpeed: 1.0 + (0.5 * d),
      devilSpeed: (1.0 + (0.5 * d)) - 0.1,
      flipInterval: 5.0 - (2.0 * d),
      flipRandomness: 0.2 + (0.3 * d),
      warningTime: 0.6,
      mazeComplexity: 0.35 + (0.4 * d),
      deadEnds: 2 + (d * 3).round(),
      chaosEvents: d < 0.6
          ? const <ChaosEventType>[ChaosEventType.clone]
          : const <ChaosEventType>[
              ChaosEventType.clone,
              ChaosEventType.fakeGoal,
            ],
      breathingPattern: const <BreathingEvent>[
        BreathingEvent(timeSeconds: 10, type: BreathingEventType.clearCorridor),
        BreathingEvent(timeSeconds: 20, type: BreathingEventType.noFlipWindow),
      ],
      seed: seed,
    );
  }
}
