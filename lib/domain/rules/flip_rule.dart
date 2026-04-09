import '../entities/game_state.dart';
import 'game_rule.dart';

class FlipRule extends GameRule {
  const FlipRule();

  @override
  GameState apply(GameState state, double dtSeconds) {
    if (state.gameOver) {
      return state;
    }

    var nextCooldown = state.flipCooldownSeconds - dtSeconds;
    var nextInverted = state.controlsInverted;

    while (nextCooldown <= 0) {
      nextInverted = !nextInverted;
      nextCooldown += state.flipIntervalSeconds;
    }

    return state.copyWith(
      controlsInverted: nextInverted,
      flipCooldownSeconds: nextCooldown,
    );
  }
}
