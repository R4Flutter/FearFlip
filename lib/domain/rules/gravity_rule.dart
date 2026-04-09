import '../entities/game_state.dart';
import 'game_rule.dart';

class GravityRule extends GameRule {
  const GravityRule({this.deathY = 100});

  final double deathY;

  @override
  GameState apply(GameState state, double dtSeconds) {
    if (state.gameOver) {
      return state;
    }

    final nextVy = state.player.vy + (state.gravityPerSecond * dtSeconds);
    final nextY = state.player.y + (nextVy * dtSeconds);
    final collided = nextY >= deathY;

    return state.copyWith(
      player: state.player.copyWith(vy: nextVy, y: nextY),
      gameOver: state.gameOver || collided,
    );
  }
}
