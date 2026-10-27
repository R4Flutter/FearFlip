import 'dart:math';

import 'package:flutter/foundation.dart';

import 'run_tally.dart';

/// The kinds of daily mission.
enum MissionKind {
  escapeMazes,
  collectWisps,
  findKeys,
  surviveFlips,
  earnStars,
  perfectStage,
  endlessDepth,
  safeCandles,
  dailyEscape,
  usePowerUps,
  openChest,
}

@immutable
class _Template {
  const _Template(this.kind, this.min, this.max, this.step, this.rewardBase);

  final MissionKind kind;
  final int min;
  final int max;
  final int step;
  final int rewardBase;
}

/// One of today's three missions.
@immutable
class Mission {
  const Mission({
    required this.kind,
    required this.target,
    required this.reward,
    this.progress = 0,
    this.claimed = false,
  });

  factory Mission.fromJson(Map<String, dynamic> json) {
    final kindName = json['k'] as String? ?? '';
    final kind = MissionKind.values.firstWhere(
      (k) => k.name == kindName,
      orElse: () => MissionKind.escapeMazes,
    );
    return Mission(
      kind: kind,
      target: (json['t'] as num?)?.toInt() ?? 1,
      reward: (json['r'] as num?)?.toInt() ?? 50,
      progress: (json['p'] as num?)?.toInt() ?? 0,
      claimed: json['c'] as bool? ?? false,
    );
  }

  final MissionKind kind;
  final int target;
  final int reward;
  final int progress;
  final bool claimed;

  bool get complete => progress >= target;
  bool get claimable => complete && !claimed;
  double get fraction => target <= 0 ? 1 : (progress / target).clamp(0.0, 1.0);

  String get title => switch (kind) {
    MissionKind.escapeMazes => 'Escape $target mazes',
    MissionKind.collectWisps => 'Collect $target soul wisps',
    MissionKind.findKeys => 'Find $target keys',
    MissionKind.surviveFlips => 'Survive $target flips',
    MissionKind.earnStars => 'Earn $target stars',
    MissionKind.perfectStage =>
      target == 1 ? 'Get 3 stars on a stage' : 'Get 3 stars on $target stages',
    MissionKind.endlessDepth => 'Reach depth $target in Endless Night',
    MissionKind.safeCandles => 'Hide in $target blue candles',
    MissionKind.dailyEscape => "Escape today's Daily Nightmare",
    MissionKind.usePowerUps => 'Use $target power-ups',
    MissionKind.openChest =>
      target == 1 ? 'Open a chest' : 'Open $target chests',
  };

  Mission withProgress(int value) => Mission(
    kind: kind,
    target: target,
    reward: reward,
    progress: min(target, value),
    claimed: claimed,
  );

  Mission claim() => Mission(
    kind: kind,
    target: target,
    reward: reward,
    progress: progress,
    claimed: true,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'k': kind.name,
    't': target,
    'r': reward,
    'p': progress,
    'c': claimed,
  };

  /// How much a finished run moves this mission. [endlessDepth] is a "best"
  /// mission: the run's depth replaces the progress when higher.
  Mission afterRun(RunTally run) {
    switch (kind) {
      case MissionKind.endlessDepth:
        if (run.mode != PlayMode.endless) return this;
        return withProgress(max(progress, run.depth));
      case MissionKind.escapeMazes:
        final escapes = run.mode == PlayMode.endless
            ? run.depth
            : (run.escaped ? 1 : 0);
        return withProgress(progress + escapes);
      case MissionKind.collectWisps:
        return withProgress(progress + run.wisps);
      case MissionKind.findKeys:
        return withProgress(progress + run.keys);
      case MissionKind.surviveFlips:
        return withProgress(progress + run.flips);
      case MissionKind.earnStars:
        return withProgress(progress + (run.escaped ? run.stars : 0));
      case MissionKind.perfectStage:
        return withProgress(progress + (run.perfect ? 1 : 0));
      case MissionKind.safeCandles:
        return withProgress(progress + run.safeVisits);
      case MissionKind.dailyEscape:
        final escaped = run.mode == PlayMode.daily && run.escaped;
        return withProgress(progress + (escaped ? 1 : 0));
      case MissionKind.usePowerUps:
        return withProgress(progress + run.powerUps);
      case MissionKind.openChest:
        return this;
    }
  }
}

abstract final class DailyMissions {
  static const int perDay = 3;

  /// Souls for finishing all three.
  static const int bonusSouls = 150;

  static const List<_Template> _templates = <_Template>[
    _Template(MissionKind.escapeMazes, 3, 6, 1, 18),
    _Template(MissionKind.collectWisps, 20, 45, 5, 2),
    _Template(MissionKind.findKeys, 4, 10, 2, 9),
    _Template(MissionKind.surviveFlips, 12, 30, 3, 3),
    _Template(MissionKind.earnStars, 4, 9, 1, 12),
    _Template(MissionKind.perfectStage, 1, 3, 1, 45),
    _Template(MissionKind.endlessDepth, 3, 7, 1, 16),
    _Template(MissionKind.safeCandles, 3, 8, 1, 10),
    _Template(MissionKind.dailyEscape, 1, 1, 1, 90),
    _Template(MissionKind.usePowerUps, 2, 4, 1, 25),
    _Template(MissionKind.openChest, 1, 2, 1, 40),
  ];

  /// Today's missions: the same three for a given [day], three different kinds.
  static List<Mission> forDay(int day) {
    final rng = Random(day * 7919 + 17);
    final pool = List<_Template>.of(_templates)..shuffle(rng);
    // Keep the first slot easy so every day starts with a quick win.
    pool.sort((a, b) {
      final aEasy = a.kind == MissionKind.escapeMazes ? 0 : 1;
      final bEasy = b.kind == MissionKind.escapeMazes ? 0 : 1;
      return aEasy - bEasy;
    });
    final picked = pool.take(perDay);
    return [
      for (final t in picked)
        () {
          final steps = ((t.max - t.min) ~/ t.step) + 1;
          final target = t.min + rng.nextInt(steps) * t.step;
          final reward = ((t.rewardBase * target + 30) / 5).round() * 5;
          return Mission(kind: t.kind, target: target, reward: reward);
        }(),
    ];
  }
}
