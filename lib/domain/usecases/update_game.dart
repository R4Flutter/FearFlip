import '../entities/game_state.dart';
import '../rules/game_rule.dart';

class UpdateGame {
  const UpdateGame({required List<GameRule> rules}) : _rules = rules;

  final List<GameRule> _rules;

  GameState call(GameState state, double dtSeconds) {
    var next = state.copyWith(elapsedSeconds: state.elapsedSeconds + dtSeconds);
    for (final rule in _rules) {
      next = rule.apply(next, dtSeconds);
    }
    return next;
  }
}
