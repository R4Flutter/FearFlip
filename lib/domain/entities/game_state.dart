import 'player.dart';

class GameState {
  const GameState({
    required this.player,
    required this.elapsedSeconds,
    required this.controlsInverted,
    required this.flipCooldownSeconds,
    required this.flipIntervalSeconds,
    required this.gravityPerSecond,
    required this.difficulty,
    required this.gameOver,
  });

  final Player player;
  final double elapsedSeconds;
  final bool controlsInverted;
  final double flipCooldownSeconds;
  final double flipIntervalSeconds;
  final double gravityPerSecond;
  final double difficulty;
  final bool gameOver;

  GameState copyWith({
    Player? player,
    double? elapsedSeconds,
    bool? controlsInverted,
    double? flipCooldownSeconds,
    double? flipIntervalSeconds,
    double? gravityPerSecond,
    double? difficulty,
    bool? gameOver,
  }) {
    return GameState(
      player: player ?? this.player,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      controlsInverted: controlsInverted ?? this.controlsInverted,
      flipCooldownSeconds: flipCooldownSeconds ?? this.flipCooldownSeconds,
      flipIntervalSeconds: flipIntervalSeconds ?? this.flipIntervalSeconds,
      gravityPerSecond: gravityPerSecond ?? this.gravityPerSecond,
      difficulty: difficulty ?? this.difficulty,
      gameOver: gameOver ?? this.gameOver,
    );
  }
}
