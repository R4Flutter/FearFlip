import 'package:flutter_test/flutter_test.dart';
import 'package:fearflipgame/services/procedural/difficulty_engine_impl.dart';

void main() {
  group('DifficultyEngineImpl', () {
    final engine = DifficultyEngineImpl();

    test('clamps values between 0 and 1', () {
      expect(engine.clamp(-1), 0.0);
      expect(engine.clamp(2), 1.0);
      expect(engine.clamp(0.42), 0.42);
    });

    test('supports level-based scaling', () {
      expect(engine.nextLevelBasedDifficulty(levelIndex: 0), 0.0);
      expect(engine.nextLevelBasedDifficulty(levelIndex: 10), closeTo(0.10, 1e-9));
      expect(engine.nextLevelBasedDifficulty(levelIndex: 200), 1.0);
    });

    test('supports time-based scaling', () {
      expect(
        engine.timeBasedDifficulty(timeSurvivedSeconds: 30, maxTimeSeconds: 120),
        closeTo(0.25, 1e-9),
      );
      expect(
        engine.timeBasedDifficulty(timeSurvivedSeconds: 999, maxTimeSeconds: 120),
        1.0,
      );
    });
  });
}
