import 'dart:math';

import '../entities/game_state.dart';
import '../entities/player.dart';

class StartGame {
  const StartGame();

  GameState call({int seed = 42}) {
    final random = Random(seed);
    final initialFlipCooldown = 3 + (random.nextDouble() * 2);

    return GameState(
      player: const Player(x: 0, y: 0, vx: 0, vy: 0),
      elapsedSeconds: 0,
      controlsInverted: false,
      flipCooldownSeconds: initialFlipCooldown,
      flipIntervalSeconds: 5,
      gravityPerSecond: 9.8,
      difficulty: 0,
      gameOver: false,
    );
  }
}
