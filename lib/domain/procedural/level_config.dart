enum ChaosEventType { clone, fakeGoal, mazeShift }

enum BreathingEventType { clearCorridor, noFlipWindow, slightSlowdown }

enum ProgressionMode { levelBased, timeBased }

class BreathingEvent {
  const BreathingEvent({required this.timeSeconds, required this.type});

  final double timeSeconds;
  final BreathingEventType type;
}

class LevelConfig {
  const LevelConfig({
    required this.difficulty,
    required this.playerSpeed,
    required this.devilSpeed,
    required this.flipInterval,
    required this.flipRandomness,
    required this.warningTime,
    required this.mazeComplexity,
    required this.deadEnds,
    required this.chaosEvents,
    required this.breathingPattern,
    required this.seed,
  });

  final double difficulty;
  final double playerSpeed;
  final double devilSpeed;
  final double flipInterval;
  final double flipRandomness;
  final double warningTime;
  final double mazeComplexity;
  final int deadEnds;
  final List<ChaosEventType> chaosEvents;
  final List<BreathingEvent> breathingPattern;
  final int seed;

  LevelConfig copyWith({
    double? difficulty,
    double? playerSpeed,
    double? devilSpeed,
    double? flipInterval,
    double? flipRandomness,
    double? warningTime,
    double? mazeComplexity,
    int? deadEnds,
    List<ChaosEventType>? chaosEvents,
    List<BreathingEvent>? breathingPattern,
    int? seed,
  }) {
    return LevelConfig(
      difficulty: difficulty ?? this.difficulty,
      playerSpeed: playerSpeed ?? this.playerSpeed,
      devilSpeed: devilSpeed ?? this.devilSpeed,
      flipInterval: flipInterval ?? this.flipInterval,
      flipRandomness: flipRandomness ?? this.flipRandomness,
      warningTime: warningTime ?? this.warningTime,
      mazeComplexity: mazeComplexity ?? this.mazeComplexity,
      deadEnds: deadEnds ?? this.deadEnds,
      chaosEvents: chaosEvents ?? this.chaosEvents,
      breathingPattern: breathingPattern ?? this.breathingPattern,
      seed: seed ?? this.seed,
    );
  }
}
