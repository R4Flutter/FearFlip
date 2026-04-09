import '../data/repositories/game_repository.dart';
import '../domain/entities/game_state.dart';
import '../domain/input/input_command.dart';
import '../domain/rules/difficulty_rule.dart';
import '../domain/rules/flip_rule.dart';
import '../domain/rules/game_rule.dart';
import '../domain/rules/gravity_rule.dart';
import '../domain/usecases/start_game.dart';
import '../domain/usecases/update_game.dart';

class FearFlipGameEngine {
  FearFlipGameEngine({
    required GameRepository repository,
    StartGame? startGame,
    List<GameRule>? rules,
  }) : _repository = repository,
       _startGame = startGame ?? const StartGame(),
       _updateGame = UpdateGame(
         rules:
             rules ??
             const <GameRule>[DifficultyRule(), FlipRule(), GravityRule()],
       );

  final GameRepository _repository;
  final StartGame _startGame;
  final UpdateGame _updateGame;
  final List<InputCommand> _pendingInput = <InputCommand>[];

  late GameState state;

  void enqueueCommand(InputCommand command) {
    _pendingInput.add(command);
  }

  Future<void> start({int seed = 42}) async {
    state = _startGame(seed: seed);
    await _repository.saveState(state);
  }

  Future<void> update(double dtSeconds) async {
    state = _applyInput(state, _pendingInput);
    _pendingInput.clear();
    state = _updateGame(state, dtSeconds);
    await _repository.saveState(state);
  }

  GameState _applyInput(GameState base, List<InputCommand> commands) {
    var next = base;
    for (final command in commands) {
      if (command.type == InputCommandType.jump) {
        next = next.copyWith(player: next.player.copyWith(vy: -7));
        continue;
      }

      if (command.type == InputCommandType.flip) {
        next = next.copyWith(controlsInverted: !next.controlsInverted);
        continue;
      }

      final directionMultiplier = next.controlsInverted ? -1.0 : 1.0;
      next = next.copyWith(
        player: next.player.copyWith(
          vx: command.dx * directionMultiplier,
          vy: next.player.vy + (command.dy * 0.15),
        ),
      );
    }
    return next;
  }
}
