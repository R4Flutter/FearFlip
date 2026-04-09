import '../entities/game_state.dart';

class ApplyFlip {
  const ApplyFlip();

  GameState call(GameState state) {
    if (state.gameOver) {
      return state;
    }
    return state.copyWith(controlsInverted: !state.controlsInverted);
  }
}
