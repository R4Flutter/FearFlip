import 'package:flutter_test/flutter_test.dart';
import 'package:fearflipgame/domain/procedural/level_config.dart';
import 'package:fearflipgame/game/maze.dart';
import 'package:fearflipgame/services/procedural/breathing_system_impl.dart';
import 'package:fearflipgame/services/procedural/chaos_system_impl.dart';
import 'package:fearflipgame/services/procedural/difficulty_engine_impl.dart';
import 'package:fearflipgame/services/procedural/level_validator_impl.dart';
import 'package:fearflipgame/services/procedural/procedural_generation_service.dart';
import 'package:fearflipgame/services/procedural/procedural_level_generator_impl.dart';

void main() {
  final validator = LevelValidatorImpl();

  MazeData sampleMaze() {
    return MazeData.fromGrid(
      grid: <List<int>>[
        <int>[0, 0, 0, 0],
        <int>[1, 1, 0, 1],
        <int>[0, 0, 0, 1],
        <int>[0, 1, 0, 0],
      ],
    );
  }

  LevelConfig config({double warning = 0.8, double devil = 0.95}) {
    return LevelConfig(
      difficulty: 0.4,
      playerSpeed: 1.2,
      devilSpeed: devil,
      flipInterval: 3.5,
      flipRandomness: 0.3,
      warningTime: warning,
      mazeComplexity: 0.5,
      deadEnds: 3,
      chaosEvents: const <ChaosEventType>[ChaosEventType.clone],
      breathingPattern: const <BreathingEvent>[],
      seed: 1,
    );
  }

  group('LevelValidatorImpl', () {
    test('fails when warning time is too low', () {
      final result = validator.validate(
        config: config(warning: 0.2),
        maze: sampleMaze(),
        seed: 1,
      );
      expect(result.passed, isFalse);
    });

    test('fails when devil speed exceeds player speed', () {
      final result = validator.validate(
        config: config(devil: 1.4),
        maze: sampleMaze(),
        seed: 1,
      );
      expect(result.passed, isFalse);
    });

    test('returns deterministic simulation counts for same seed', () {
      final a = validator.validate(config: config(), maze: sampleMaze(), seed: 8);
      final b = validator.validate(config: config(), maze: sampleMaze(), seed: 8);
      expect(a.successCount, b.successCount);
      expect(a.passed, b.passed);
    });
  });

  group('ProceduralGenerationService', () {
    test('always returns a config via bounded attempts and fallback', () {
      final generator = ProceduralLevelGeneratorImpl(
        difficultyEngine: DifficultyEngineImpl(),
        chaosSystem: ChaosSystemImpl(),
        breathingSystem: BreathingSystemImpl(),
      );
      final service = ProceduralGenerationService(
        generator: generator,
        validator: validator,
        maxAttempts: 1,
      );

      final result = service.generateValidated(
        difficulty: 0.9,
        maze: sampleMaze(),
        seed: 123,
      );
      expect(result.warningTime >= 0.4, isTrue);
      expect(result.devilSpeed <= result.playerSpeed, isTrue);
    });
  });
}
