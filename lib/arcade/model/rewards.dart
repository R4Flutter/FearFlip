import 'dart:math';

import 'package:flutter/foundation.dart';

import 'boosts.dart';
import 'worlds.dart';

/// Souls and items paid out together.
@immutable
class Reward {
  const Reward({
    this.souls = 0,
    this.boosts = const <BoostType, int>{},
    this.itemId,
    this.chests = 0,
  });

  final int souls;
  final Map<BoostType, int> boosts;

  /// A shop item unlocked (the day-7 runner).
  final String? itemId;

  /// Chests to open on the spot.
  final int chests;

  bool get isEmpty =>
      souls == 0 && boosts.isEmpty && itemId == null && chests == 0;

  Reward doubled() => Reward(
    souls: souls * 2,
    boosts: {for (final e in boosts.entries) e.key: e.value * 2},
    itemId: itemId,
    chests: chests,
  );

  Reward operator +(Reward other) {
    final merged = Map<BoostType, int>.of(boosts);
    for (final e in other.boosts.entries) {
      merged[e.key] = (merged[e.key] ?? 0) + e.value;
    }
    return Reward(
      souls: souls + other.souls,
      boosts: merged,
      itemId: itemId ?? other.itemId,
      chests: chests + other.chests,
    );
  }
}

/// The 7-day login calendar. Missing a day starts it again from day 1.
abstract final class LoginCalendar {
  static const List<Reward> days = <Reward>[
    Reward(souls: 60),
    Reward(souls: 90),
    Reward(souls: 60, boosts: {BoostType.shield: 1}),
    Reward(souls: 140),
    Reward(souls: 100, chests: 1),
    Reward(souls: 200, boosts: {BoostType.hourglass: 1, BoostType.frost: 1}),
    Reward(souls: 350, itemId: 'runner_candle_keeper', chests: 1),
  ];

  /// The calendar day (1–7) the next claim pays, given the last claim.
  /// [lastDay] is the day index of the last claim; [lastStreakDay] the
  /// calendar day it paid.
  static int nextDay({
    required int today,
    required int? lastDay,
    required int lastStreakDay,
  }) {
    if (lastDay == null) return 1;
    if (today == lastDay) return lastStreakDay;
    if (today == lastDay + 1) return lastStreakDay % days.length + 1;
    return 1;
  }

  static bool canClaim({required int today, required int? lastDay}) =>
      lastDay == null || today > lastDay;

  /// True when yesterday's claim was missed and the streak restarts.
  static bool streakBroken({required int today, required int? lastDay}) =>
      lastDay != null && today > lastDay + 1;
}

enum ChestTier { common, rich }

/// Chest odds: mostly souls, often a power-up.
abstract final class Chests {
  /// Extra chests a day for watching a video.
  static const int adChestsPerDay = 3;

  static Reward roll(Random rng, {ChestTier tier = ChestTier.common}) {
    final rich = tier == ChestTier.rich;
    final soulRoll = rng.nextDouble();
    final int souls;
    if (soulRoll < 0.55) {
      souls = rich ? 120 + rng.nextInt(60) : 40 + rng.nextInt(30);
    } else if (soulRoll < 0.88) {
      souls = rich ? 180 + rng.nextInt(80) : 70 + rng.nextInt(40);
    } else {
      souls = rich ? 300 + rng.nextInt(150) : 140 + rng.nextInt(80);
    }
    final boosts = <BoostType, int>{};
    final boostChance = rich ? 0.8 : 0.45;
    if (rng.nextDouble() < boostChance) {
      final type = BoostType.values[rng.nextInt(BoostType.values.length)];
      boosts[type] = rich ? 2 : 1;
    }
    return Reward(souls: souls, boosts: boosts);
  }
}

/// Stars and souls for clearing a stage.
abstract final class StageEconomy {
  /// Share of the clock that must be left for 2 and for 3 stars.
  static const double twoStarShare = 0.2;
  static const double threeStarShare = 0.45;

  static int stars({
    required int secondsLeft,
    required int totalSeconds,
    required bool revived,
  }) {
    if (totalSeconds <= 0) return 1;
    final share = secondsLeft / totalSeconds;
    if (share >= threeStarShare && !revived) return 3;
    if (share >= twoStarShare) return 2;
    return 1;
  }

  /// Souls for a clear. A first clear pays in full, a replay pays half, and
  /// every star earned for the first time adds a bonus.
  static int clearSouls({
    required int stage,
    required int stars,
    required bool firstClear,
    required int newStars,
  }) {
    final base = 10 + (stage * 0.6).round();
    final mult = switch (stars) {
      >= 3 => 1.6,
      2 => 1.3,
      _ => 1.0,
    };
    var souls = (base * mult).round();
    if (!firstClear) souls = (souls / 2).round();
    souls += newStars * 15;
    if (firstClear && Worlds.isGate(stage)) souls += 50;
    return souls;
  }

  /// Endless Night: souls for the depth reached (wisps are paid as found).
  static int endlessSouls(int depth) => depth * 8 + (depth >= 5 ? 25 : 0);

  /// Endless Night score.
  static int endlessScore({
    required int depth,
    required int wisps,
    required int secondsLeftTotal,
  }) => depth * 100 + wisps * 5 + secondsLeftTotal;

  /// Souls for the first Daily Nightmare escape of the day.
  static const int dailyEscapeSouls = 120;
}
