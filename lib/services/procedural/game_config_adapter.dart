import '../../domain/procedural/level_config.dart';
import '../../game/game_config.dart';

class GameConfigAdapter {
  RuntimeBalanceConfig toRuntime(LevelConfig level) {
    return RuntimeBalanceConfig.defaults().copyWith(
      playerMaxSpeed: GameBalanceConfig.playerMaxSpeed * level.playerSpeed,
      devilBaseSpeed: GameBalanceConfig.devilBaseSpeed * level.devilSpeed,
      devilMaxSpeed:
          (GameBalanceConfig.devilBaseSpeed * level.devilSpeed * 1.75).clamp(
            80,
            320,
          ),
      flipInterval: level.flipInterval,
      flipWarningDuration: level.warningTime,
      flipRandomness: level.flipRandomness,
      safeZoneProtectionSeconds: _safeZoneDuration(level.difficulty),
      glitchDuration: _glitchDuration(level.difficulty),
      preFlipShakeDuration: _shakeDuration(level.difficulty),
      shadowCloneSpeed:
          GameBalanceConfig.shadowCloneSpeed * (1.0 + level.difficulty * 0.35),
      logicalMazeRows: _mazeSizeFromComplexity(level.mazeComplexity),
      logicalMazeCols: _mazeSizeFromComplexity(level.mazeComplexity),
    );
  }

  int _mazeSizeFromComplexity(double complexity) {
    final c = complexity.clamp(0.2, 1.0);
    final value = 9 + ((c - 0.2) / 0.8 * 13).round();
    return value.clamp(9, 22).toInt();
  }

  double _safeZoneDuration(double difficulty) {
    return (3.0 - (difficulty * 2.6)).clamp(0.5, 3.0);
  }

  double _glitchDuration(double difficulty) {
    return (0.35 + difficulty * 0.5).clamp(0.35, 0.95);
  }

  double _shakeDuration(double difficulty) {
    return (0.25 + difficulty * 0.45).clamp(0.25, 0.70);
  }
}
