import '../../domain/entities/game_state.dart';

abstract class GameRepository {
  Future<void> saveState(GameState state);
  Future<GameState?> loadState();
}
