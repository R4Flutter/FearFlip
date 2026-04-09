import '../entities/game_state.dart';

abstract class GameRule {
  const GameRule();

  GameState apply(GameState state, double dtSeconds);
}
