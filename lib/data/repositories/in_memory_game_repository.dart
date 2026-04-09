import '../../domain/entities/game_state.dart';
import 'game_repository.dart';

class InMemoryGameRepository implements GameRepository {
  GameState? _state;

  @override
  Future<GameState?> loadState() async => _state;

  @override
  Future<void> saveState(GameState state) async {
    _state = state;
  }
}
