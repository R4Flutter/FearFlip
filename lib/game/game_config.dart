import 'package:flame/components.dart';

class GameBalanceConfig {
  static const int logicalMazeRows = 11;
  static const int logicalMazeCols = 11;
  static const double tileSize = 32;
  static const double viewportScreenPadding = 0;
  static const double mazeFrameInset = 8;
  static const double mazeFrameRadius = 16;
  static const bool alwaysShowGoalHint = true;
  static const double portraitTopReserved = 96;
  static const double portraitBottomReserved = 176;
  static const double landscapeTopReserved = 72;
  static const double landscapeBottomReserved = 14;
  static const double landscapeRightReserved = 182;
  static const double minCameraZoom = 0.05;
  static const double maxCameraZoom = 1.2;

  static const double playerMaxSpeed = 110;
  static const double playerAcceleration = 900;
  static const double playerRadius = 9;

  static const double devilBaseSpeed = 85;
  static const double devilSpeedGrowthPerSecond = 2.8;
  static const double devilMaxSpeed = 170;
  static const double devilRadius = 9;

  static const double flipInterval = 11;
  static const double flipWarningDuration = 1;
  static const double glitchDuration = 0.65;
  static const double preFlipShakeDuration = 0.55;

  static const double memoryPreviewSeconds = 4;
  static const double safeZoneProtectionSeconds = 6;

  static const double shadowCloneSpeed = 70;

  static Vector2 get mazeWorldSize {
    final expandedRows = logicalMazeRows * 2 + 1;
    final expandedCols = logicalMazeCols * 2 + 1;
    return Vector2(expandedCols * tileSize, expandedRows * tileSize);
  }
}

class RuntimeBalanceConfig {
  const RuntimeBalanceConfig({
    required this.logicalMazeRows,
    required this.logicalMazeCols,
    required this.playerMaxSpeed,
    required this.playerAcceleration,
    required this.playerRadius,
    required this.devilBaseSpeed,
    required this.devilSpeedGrowthPerSecond,
    required this.devilMaxSpeed,
    required this.devilRadius,
    required this.flipInterval,
    required this.flipWarningDuration,
    required this.flipRandomness,
    required this.glitchDuration,
    required this.preFlipShakeDuration,
    required this.safeZoneProtectionSeconds,
    required this.shadowCloneSpeed,
  });

  final int logicalMazeRows;
  final int logicalMazeCols;
  final double playerMaxSpeed;
  final double playerAcceleration;
  final double playerRadius;
  final double devilBaseSpeed;
  final double devilSpeedGrowthPerSecond;
  final double devilMaxSpeed;
  final double devilRadius;
  final double flipInterval;
  final double flipWarningDuration;
  final double flipRandomness;
  final double glitchDuration;
  final double preFlipShakeDuration;
  final double safeZoneProtectionSeconds;
  final double shadowCloneSpeed;

  factory RuntimeBalanceConfig.defaults() {
    return const RuntimeBalanceConfig(
      logicalMazeRows: GameBalanceConfig.logicalMazeRows,
      logicalMazeCols: GameBalanceConfig.logicalMazeCols,
      playerMaxSpeed: GameBalanceConfig.playerMaxSpeed,
      playerAcceleration: GameBalanceConfig.playerAcceleration,
      playerRadius: GameBalanceConfig.playerRadius,
      devilBaseSpeed: GameBalanceConfig.devilBaseSpeed,
      devilSpeedGrowthPerSecond: GameBalanceConfig.devilSpeedGrowthPerSecond,
      devilMaxSpeed: GameBalanceConfig.devilMaxSpeed,
      devilRadius: GameBalanceConfig.devilRadius,
      flipInterval: GameBalanceConfig.flipInterval,
      flipWarningDuration: GameBalanceConfig.flipWarningDuration,
      flipRandomness: 0,
      glitchDuration: GameBalanceConfig.glitchDuration,
      preFlipShakeDuration: GameBalanceConfig.preFlipShakeDuration,
      safeZoneProtectionSeconds: GameBalanceConfig.safeZoneProtectionSeconds,
      shadowCloneSpeed: GameBalanceConfig.shadowCloneSpeed,
    );
  }

  RuntimeBalanceConfig copyWith({
    int? logicalMazeRows,
    int? logicalMazeCols,
    double? playerMaxSpeed,
    double? playerAcceleration,
    double? playerRadius,
    double? devilBaseSpeed,
    double? devilSpeedGrowthPerSecond,
    double? devilMaxSpeed,
    double? devilRadius,
    double? flipInterval,
    double? flipWarningDuration,
    double? flipRandomness,
    double? glitchDuration,
    double? preFlipShakeDuration,
    double? safeZoneProtectionSeconds,
    double? shadowCloneSpeed,
  }) {
    return RuntimeBalanceConfig(
      logicalMazeRows: logicalMazeRows ?? this.logicalMazeRows,
      logicalMazeCols: logicalMazeCols ?? this.logicalMazeCols,
      playerMaxSpeed: playerMaxSpeed ?? this.playerMaxSpeed,
      playerAcceleration: playerAcceleration ?? this.playerAcceleration,
      playerRadius: playerRadius ?? this.playerRadius,
      devilBaseSpeed: devilBaseSpeed ?? this.devilBaseSpeed,
      devilSpeedGrowthPerSecond:
          devilSpeedGrowthPerSecond ?? this.devilSpeedGrowthPerSecond,
      devilMaxSpeed: devilMaxSpeed ?? this.devilMaxSpeed,
      devilRadius: devilRadius ?? this.devilRadius,
      flipInterval: flipInterval ?? this.flipInterval,
      flipWarningDuration: flipWarningDuration ?? this.flipWarningDuration,
      flipRandomness: flipRandomness ?? this.flipRandomness,
      glitchDuration: glitchDuration ?? this.glitchDuration,
      preFlipShakeDuration: preFlipShakeDuration ?? this.preFlipShakeDuration,
      safeZoneProtectionSeconds:
          safeZoneProtectionSeconds ?? this.safeZoneProtectionSeconds,
      shadowCloneSpeed: shadowCloneSpeed ?? this.shadowCloneSpeed,
    );
  }
}
