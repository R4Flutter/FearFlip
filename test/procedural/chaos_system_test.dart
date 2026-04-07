import 'package:flutter_test/flutter_test.dart';
import 'package:fearflipgame/services/procedural/chaos_system_impl.dart';

void main() {
  group('ChaosSystemImpl', () {
    final system = ChaosSystemImpl();

    test('returns 0 chaos for difficulty < 0.3', () {
      expect(system.selectChaos(difficulty: 0.29, seed: 10), isEmpty);
    });

    test('returns 1 chaos for difficulty < 0.6', () {
      expect(system.selectChaos(difficulty: 0.59, seed: 10).length, 1);
    });

    test('returns max 2 chaos for high difficulty', () {
      final events = system.selectChaos(difficulty: 0.9, seed: 42);
      expect(events.length, 2);
      expect(events.toSet().length, 2);
    });

    test('is deterministic for same seed', () {
      final a = system.selectChaos(difficulty: 0.9, seed: 5);
      final b = system.selectChaos(difficulty: 0.9, seed: 5);
      expect(a, b);
    });
  });
}
