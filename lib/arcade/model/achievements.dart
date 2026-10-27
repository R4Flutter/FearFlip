import 'package:flutter/foundation.dart';

import 'run_tally.dart';

/// What an achievement measures.
enum AchievementMetric {
  stat,
  highestCleared,
  totalStars,
  endlessBest,
  ownedItems,
  loginStreak,
}

@immutable
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.text,
    required this.metric,
    required this.target,
    required this.souls,
    this.stat,
    this.itemId,
  });

  final String id;
  final String title;
  final String text;
  final AchievementMetric metric;
  final Stat? stat;
  final int target;
  final int souls;

  /// A shop item it unlocks.
  final String? itemId;
}

abstract final class Achievements {
  static const List<Achievement> all = <Achievement>[
    Achievement(
      id: 'first_escape',
      title: 'First Light',
      text: 'Escape your first maze.',
      metric: AchievementMetric.stat,
      stat: Stat.escapes,
      target: 1,
      souls: 50,
    ),
    Achievement(
      id: 'escapes_25',
      title: 'Survivor',
      text: 'Escape 25 mazes.',
      metric: AchievementMetric.stat,
      stat: Stat.escapes,
      target: 25,
      souls: 150,
    ),
    Achievement(
      id: 'escapes_100',
      title: 'Hardened',
      text: 'Escape 100 mazes.',
      metric: AchievementMetric.stat,
      stat: Stat.escapes,
      target: 100,
      souls: 400,
    ),
    Achievement(
      id: 'world_1',
      title: 'Halls Behind You',
      text: 'Clear the Lantern Halls (stage 20).',
      metric: AchievementMetric.highestCleared,
      target: 20,
      souls: 200,
    ),
    Achievement(
      id: 'world_2',
      title: 'Crypt Walker',
      text: 'Clear the Bone Crypt (stage 40).',
      metric: AchievementMetric.highestCleared,
      target: 40,
      souls: 300,
    ),
    Achievement(
      id: 'world_3',
      title: 'Wallbreaker',
      text: 'Clear the Shifting Catacombs (stage 60).',
      metric: AchievementMetric.highestCleared,
      target: 60,
      souls: 400,
    ),
    Achievement(
      id: 'world_4',
      title: 'Into the Dark',
      text: 'Clear the Blackout Depths (stage 80).',
      metric: AchievementMetric.highestCleared,
      target: 80,
      souls: 500,
    ),
    Achievement(
      id: 'world_5',
      title: 'Devil Slayer',
      text: "Clear the Devil's Throne (stage 100).",
      metric: AchievementMetric.highestCleared,
      target: 100,
      souls: 1000,
      itemId: 'runner_bone_prince',
    ),
    Achievement(
      id: 'stars_30',
      title: 'Starlit',
      text: 'Earn 30 stars.',
      metric: AchievementMetric.totalStars,
      target: 30,
      souls: 150,
    ),
    Achievement(
      id: 'stars_150',
      title: 'Constellation',
      text: 'Earn 150 stars.',
      metric: AchievementMetric.totalStars,
      target: 150,
      souls: 500,
    ),
    Achievement(
      id: 'perfect_10',
      title: 'Flawless',
      text: 'Get 3 stars on 10 stages.',
      metric: AchievementMetric.stat,
      stat: Stat.perfects,
      target: 10,
      souls: 250,
    ),
    Achievement(
      id: 'wisps_200',
      title: 'Soul Gatherer',
      text: 'Collect 200 soul wisps.',
      metric: AchievementMetric.stat,
      stat: Stat.wisps,
      target: 200,
      souls: 150,
    ),
    Achievement(
      id: 'wisps_1500',
      title: 'Soul Hoarder',
      text: 'Collect 1,500 soul wisps.',
      metric: AchievementMetric.stat,
      stat: Stat.wisps,
      target: 1500,
      souls: 500,
    ),
    Achievement(
      id: 'keys_30',
      title: 'Locksmith',
      text: 'Find 30 keys.',
      metric: AchievementMetric.stat,
      stat: Stat.keys,
      target: 30,
      souls: 150,
    ),
    Achievement(
      id: 'flips_200',
      title: 'Upside Down',
      text: 'Survive 200 flips.',
      metric: AchievementMetric.stat,
      stat: Stat.flips,
      target: 200,
      souls: 200,
    ),
    Achievement(
      id: 'safe_40',
      title: 'Candle Hugger',
      text: 'Hide in 40 blue candles.',
      metric: AchievementMetric.stat,
      stat: Stat.safeVisits,
      target: 40,
      souls: 150,
    ),
    Achievement(
      id: 'near_miss_15',
      title: 'Too Close',
      text: 'Escape the Devil by one step 15 times.',
      metric: AchievementMetric.stat,
      stat: Stat.nearMisses,
      target: 15,
      souls: 200,
    ),
    Achievement(
      id: 'endless_8',
      title: 'Night Walker',
      text: 'Reach depth 8 in Endless Night.',
      metric: AchievementMetric.endlessBest,
      target: 8,
      souls: 250,
    ),
    Achievement(
      id: 'endless_20',
      title: 'Endless Dread',
      text: 'Reach depth 20 in Endless Night.',
      metric: AchievementMetric.endlessBest,
      target: 20,
      souls: 600,
    ),
    Achievement(
      id: 'daily_5',
      title: 'Nightly Ritual',
      text: 'Escape 5 Daily Nightmares.',
      metric: AchievementMetric.stat,
      stat: Stat.dailyEscapes,
      target: 5,
      souls: 250,
    ),
    Achievement(
      id: 'login_7',
      title: 'A Full Week',
      text: 'Claim 7 daily rewards in a row.',
      metric: AchievementMetric.loginStreak,
      target: 7,
      souls: 300,
    ),
    Achievement(
      id: 'chests_15',
      title: 'Treasure Hunter',
      text: 'Open 15 chests.',
      metric: AchievementMetric.stat,
      stat: Stat.chests,
      target: 15,
      souls: 200,
    ),
    Achievement(
      id: 'powerups_20',
      title: 'Arcane Hands',
      text: 'Use 20 power-ups.',
      metric: AchievementMetric.stat,
      stat: Stat.powerUps,
      target: 20,
      souls: 200,
    ),
    Achievement(
      id: 'collector_3',
      title: 'Collector',
      text: 'Unlock 3 shop items (runners, lanterns, trails).',
      metric: AchievementMetric.ownedItems,
      target: 3,
      souls: 250,
    ),
  ];

  static Achievement? byId(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }
}
