/// Which game a run belongs to.
enum PlayMode { campaign, endless, daily }

/// Counters kept for life (achievements) and per day (missions).
enum Stat {
  escapes,
  wisps,
  keys,
  flips,
  safeVisits,
  powerUps,
  deaths,
  perfects,
  endlessRuns,
  dailyEscapes,
  chests,
  loginDays,
  nearMisses,
  frozenDevils,
}

/// What happened in one attempt at a maze, from the game to the progress
/// controller (stats, missions, achievements).
class RunTally {
  RunTally({required this.mode, this.stage = 1});

  final PlayMode mode;
  int stage;

  int wisps = 0;
  int keys = 0;
  int flips = 0;
  int safeVisits = 0;
  int powerUps = 0;
  int nearMisses = 0;
  int frozenDevils = 0;

  bool escaped = false;
  bool died = false;
  int stars = 0;

  /// Endless: mazes escaped in this run.
  int depth = 0;

  /// Seconds the escape took.
  int seconds = 0;

  bool get perfect => escaped && stars >= 3;

  /// The per-stat increments this run adds.
  Map<Stat, int> get increments => <Stat, int>{
    Stat.escapes: mode == PlayMode.endless ? depth : (escaped ? 1 : 0),
    Stat.wisps: wisps,
    Stat.keys: keys,
    Stat.flips: flips,
    Stat.safeVisits: safeVisits,
    Stat.powerUps: powerUps,
    Stat.deaths: died ? 1 : 0,
    Stat.perfects: perfect ? 1 : 0,
    Stat.endlessRuns: mode == PlayMode.endless && died ? 1 : 0,
    Stat.dailyEscapes: mode == PlayMode.daily && escaped ? 1 : 0,
    Stat.nearMisses: nearMisses,
    Stat.frozenDevils: frozenDevils,
  };
}
