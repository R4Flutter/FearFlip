import 'dart:math';

import 'trap_tile.dart';

/// Lightweight in-memory analytics recorder for trap events.
///
/// Events are buffered and can be flushed/read at session boundaries
/// for future analysis or remote reporting.
class TrapAnalytics {
  final List<TrapAnalyticsEvent> _buffer = <TrapAnalyticsEvent>[];

  /// Record a trap event.
  void record({
    required int stage,
    required String eventType,
    required Point<int> cell,
    TileTopology? topology,
    int playerStepCount = 0,
    double secondsElapsed = 0,
    bool devilActive = false,
    bool controlsInverted = false,
    int trapsTriggeredThisRun = 0,
    int? distanceToGoal,
  }) {
    _buffer.add(TrapAnalyticsEvent(
      stage: stage,
      eventType: eventType,
      cellX: cell.x,
      cellY: cell.y,
      topology: topology?.name ?? 'unknown',
      playerStepCount: playerStepCount,
      secondsElapsed: secondsElapsed,
      devilActive: devilActive,
      controlsInverted: controlsInverted,
      trapsTriggeredThisRun: trapsTriggeredThisRun,
      distanceToGoal: distanceToGoal,
      timestamp: DateTime.now(),
    ));
  }

  /// All recorded events since last flush.
  List<TrapAnalyticsEvent> get events =>
      List<TrapAnalyticsEvent>.unmodifiable(_buffer);

  /// Clear the buffer (e.g. after sending to backend).
  void flush() => _buffer.clear();

  /// Summary stats for the current session.
  TrapSessionSummary get summary {
    var totalDeaths = 0;
    var totalReveals = 0;
    var totalNearMisses = 0;
    for (final e in _buffer) {
      if (e.eventType == 'trap_death') totalDeaths++;
      if (e.eventType == 'crack_reveal') totalReveals++;
      if (e.eventType == 'near_miss') totalNearMisses++;
    }
    return TrapSessionSummary(
      totalDeaths: totalDeaths,
      totalReveals: totalReveals,
      totalNearMisses: totalNearMisses,
      totalEvents: _buffer.length,
    );
  }
}

/// A single recorded trap event.
class TrapAnalyticsEvent {
  const TrapAnalyticsEvent({
    required this.stage,
    required this.eventType,
    required this.cellX,
    required this.cellY,
    required this.topology,
    required this.playerStepCount,
    required this.secondsElapsed,
    required this.devilActive,
    required this.controlsInverted,
    required this.trapsTriggeredThisRun,
    required this.timestamp,
    this.distanceToGoal,
  });

  final int stage;
  final String eventType;
  final int cellX;
  final int cellY;
  final String topology;
  final int playerStepCount;
  final double secondsElapsed;
  final bool devilActive;
  final bool controlsInverted;
  final int trapsTriggeredThisRun;
  final int? distanceToGoal;
  final DateTime timestamp;
}

/// Aggregated session-level trap metrics.
class TrapSessionSummary {
  const TrapSessionSummary({
    required this.totalDeaths,
    required this.totalReveals,
    required this.totalNearMisses,
    required this.totalEvents,
  });

  final int totalDeaths;
  final int totalReveals;
  final int totalNearMisses;
  final int totalEvents;
}

/// Curated pool of death quotes shown after trap collapse.
class TrapDeathQuotes {
  static const List<String> _taunt = <String>[
    'The floor remembers.',
    'You walked there before...',
    'Your own footsteps betrayed you.',
    'The maze gives one warning.\nYou ignored it.',
    'Every step leaves a mark.\nYours left a grave.',
  ];

  static const List<String> _nearMiss = <String>[
    'So close. The exit was RIGHT THERE.',
    '3 tiles. That\'s all you needed.',
    'Almost. Almost. Almost.',
    'The goal could see you coming.',
    'One wrong step undid everything.',
  ];

  static const List<String> _revenge = <String>[
    'Try again.\nThe cracks haven\'t moved.',
    'Remember the pattern.\nAttack the maze.',
    'Your memory is your weapon.',
    'The maze is the same.\nYou are not.',
    'This time,\nwatch where you\'ve been.',
  ];

  /// Pick a random death quote weighted by how close the player was to the
  /// goal.
  static String pick({required Random random, bool wasNearGoal = false}) {
    if (wasNearGoal && random.nextDouble() < 0.5) {
      return _nearMiss[random.nextInt(_nearMiss.length)];
    }
    if (random.nextDouble() < 0.45) {
      return _taunt[random.nextInt(_taunt.length)];
    }
    return _revenge[random.nextInt(_revenge.length)];
  }
}
