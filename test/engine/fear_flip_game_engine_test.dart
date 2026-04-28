import 'package:flutter_test/flutter_test.dart';

import 'package:fearflipgame/data/repositories/in_memory_game_repository.dart';
import 'package:fearflipgame/domain/rules/difficulty_rule.dart';
import 'package:fearflipgame/domain/rules/flip_rule.dart';
import 'package:fearflipgame/domain/rules/game_rule.dart';
import 'package:fearflipgame/domain/rules/gravity_rule.dart';
import 'package:fearflipgame/engine/fear_flip_game.dart';

void main() {
  Future<FearFlipGameEngine> buildEngine({
    List<GameRule>? rules,
    int seed = 42,
  }) async {
    final engine = FearFlipGameEngine(
      repository: InMemoryGameRepository(),
      rules: rules,
    );
    await engine.start(seed: seed);
    return engine;
  }

  test('gravity updates vertical velocity and position', () async {
    final engine = await buildEngine(
      rules: const <GameRule>[GravityRule(deathY: 9999)],
    );

    final startY = engine.state.player.y;
    await engine.update(1.0);

    expect(engine.state.player.vy, greaterThan(0));
    expect(engine.state.player.y, greaterThan(startY));
  });

  test('flip mechanic toggles controls after interval', () async {
    final engine = await buildEngine(rules: const <GameRule>[FlipRule()]);

    expect(engine.state.controlsInverted, isFalse);
    await engine.update(5.1);
    expect(engine.state.controlsInverted, isTrue);
  });

  test('collision threshold triggers game over', () async {
    final engine = await buildEngine(
      rules: const <GameRule>[GravityRule(deathY: 1.0)],
    );

    expect(engine.state.gameOver, isFalse);
    await engine.update(1.0);
    expect(engine.state.gameOver, isTrue);
  });

  test('difficulty increases over time', () async {
    final engine = await buildEngine(
      rules: const <GameRule>[DifficultyRule(growthPerSecond: 0.1)],
    );

    final startDifficulty = engine.state.difficulty;
    await engine.update(2.0);
    expect(engine.state.difficulty, greaterThan(startDifficulty));
  });

  test('simulation remains valid for 1000 frames', () async {
    final engine = await buildEngine();

    for (var i = 0; i < 1000; i++) {
      await engine.update(0.016);
    }

    expect(engine.state.elapsedSeconds, greaterThan(15));
    expect(engine.state.difficulty, inInclusiveRange(0, 1));
    expect(engine.state.flipCooldownSeconds, greaterThan(0));
  });

  test('seeded start is deterministic', () async {
    final first = await buildEngine(seed: 42);
    final second = await buildEngine(seed: 42);

    expect(
      first.state.flipCooldownSeconds,
      closeTo(second.state.flipCooldownSeconds, 0.000001),
    );
  });
}
