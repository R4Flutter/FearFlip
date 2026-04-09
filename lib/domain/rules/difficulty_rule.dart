import '../entities/game_state.dart';
import 'game_rule.dart';

class DifficultyRule extends GameRule {
  const DifficultyRule({this.growthPerSecond = 0.015, this.maxDifficulty = 1});

  final double growthPerSecond;
  final double maxDifficulty;

  @override
  GameState apply(GameState state, double dtSeconds) {
    if (state.gameOver) {
      return state;
    }

    final nextDifficulty = (state.difficulty + (growthPerSecond * dtSeconds))
        .clamp(0, maxDifficulty);

    return state.copyWith(difficulty: nextDifficulty.toDouble());
  }
}
