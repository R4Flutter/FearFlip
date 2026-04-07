import 'dart:math';

import '../../domain/procedural/level_config.dart';
import '../../domain/procedural/procedural_modules.dart';

class ProceduralLevelGeneratorImpl implements ProceduralLevelGenerator {
  ProceduralLevelGeneratorImpl({
    required DifficultyEngine difficultyEngine,
    required ChaosSystem chaosSystem,
    required BreathingSystem breathingSystem,
  }) : _difficultyEngine = difficultyEngine,
       _chaosSystem = chaosSystem,
       _breathingSystem = breathingSystem;

  final DifficultyEngine _difficultyEngine;
  final ChaosSystem _chaosSystem;
  final BreathingSystem _breathingSystem;

  @override
  LevelConfig generate({
    required double difficulty,
    required int seed,
    double totalSeconds = 120,
  }) {
    final d = _difficultyEngine.clamp(difficulty);

    final playerSpeed = _lerp(1.0, 1.50, d);
    final devilDelta = _lerp(0.10, 0.00, d);
    final devilSpeed = min(playerSpeed, playerSpeed - devilDelta);

    final flipInterval = _lerp(5.0, 1.4, d);
    final flipRandomness = _lerp(0.0, 0.80, d);
    final warningTime = max(0.40, _lerp(1.2, 0.40, d));
    final mazeComplexity = _lerp(0.2, 1.0, d);
    final deadEnds = _lerp(0, 10, d).round().clamp(0, 10);

    final chaosEvents = _chaosSystem.selectChaos(difficulty: d, seed: seed);
    final chaosSpikes = _buildChaosSpikeTimeline(
      seed: seed,
      totalSeconds: totalSeconds,
      chaosCount: chaosEvents.length,
    );

    final breathingPattern = _breathingSystem.buildPattern(
      seed: seed,
      totalSeconds: totalSeconds,
      chaosSpikeTimes: chaosSpikes,
    );

    return LevelConfig(
      difficulty: d,
      playerSpeed: playerSpeed,
      devilSpeed: devilSpeed,
      flipInterval: flipInterval,
      flipRandomness: flipRandomness,
      warningTime: warningTime,
      mazeComplexity: mazeComplexity,
      deadEnds: deadEnds,
      chaosEvents: chaosEvents,
      breathingPattern: breathingPattern,
      seed: seed,
    );
  }

  List<double> _buildChaosSpikeTimeline({
    required int seed,
    required double totalSeconds,
    required int chaosCount,
  }) {
    if (chaosCount == 0 || totalSeconds <= 0) {
      return const <double>[];
    }
    final random = Random(seed ^ 0xA1B2C3D4);
    final spikes = <double>[];
    var t = 6.0 + random.nextDouble() * 5.0;
    final spacing = chaosCount == 1 ? 11.0 : 8.0;

    while (t < totalSeconds) {
      spikes.add(t);
      t += spacing + random.nextDouble() * 2.5;
    }
    return spikes;
  }

  double _lerp(num a, num b, double t) {
    return a + (b - a) * t;
  }
}
