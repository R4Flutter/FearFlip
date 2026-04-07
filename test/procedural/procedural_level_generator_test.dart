import 'package:flutter_test/flutter_test.dart';
import 'package:fearflipgame/services/procedural/breathing_system_impl.dart';
import 'package:fearflipgame/services/procedural/chaos_system_impl.dart';
import 'package:fearflipgame/services/procedural/difficulty_engine_impl.dart';
import 'package:fearflipgame/services/procedural/procedural_level_generator_impl.dart';

void main() {
  final generator = ProceduralLevelGeneratorImpl(
    difficultyEngine: DifficultyEngineImpl(),
    chaosSystem: ChaosSystemImpl(),
    breathingSystem: BreathingSystemImpl(),
  );

  group('ProceduralLevelGeneratorImpl', () {
    test('respects low-end formula values', () {
      final config = generator.generate(difficulty: 0.0, seed: 1);
      expect(config.playerSpeed, closeTo(1.0, 1e-9));
      expect(config.flipInterval, closeTo(5.0, 1e-9));
      expect(config.flipRandomness, closeTo(0.0, 1e-9));
      expect(config.warningTime, closeTo(1.2, 1e-9));
      expect(config.chaosEvents.length, 0);
    });

    test('respects high-end bounds', () {
      final config = generator.generate(difficulty: 1.0, seed: 7);
      expect(config.playerSpeed, closeTo(1.5, 1e-9));
      expect(config.devilSpeed <= config.playerSpeed, isTrue);
      expect(config.flipInterval, closeTo(1.4, 1e-9));
      expect(config.flipRandomness, closeTo(0.8, 1e-9));
      expect(config.warningTime >= 0.4, isTrue);
      expect(config.chaosEvents.length <= 2, isTrue);
    });
  });
}
