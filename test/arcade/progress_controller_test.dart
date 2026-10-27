import 'dart:math';

import 'package:fearflipgame/arcade/model/achievements.dart';
import 'package:fearflipgame/arcade/model/boosts.dart';
import 'package:fearflipgame/arcade/model/missions.dart';
import 'package:fearflipgame/arcade/model/rewards.dart';
import 'package:fearflipgame/arcade/model/run_tally.dart';
import 'package:fearflipgame/arcade/model/shop_catalog.dart';
import 'package:fearflipgame/arcade/model/worlds.dart';
import 'package:fearflipgame/arcade/platform/portal.dart';
import 'package:fearflipgame/arcade/progress_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MemoryPortal portal;
  late int day;
  late ProgressController progress;

  Future<ProgressController> fresh() async {
    final controller = ProgressController(
      portal: portal,
      today: () => day,
      random: Random(7),
    );
    await controller.load();
    return controller;
  }

  setUp(() async {
    portal = MemoryPortal();
    day = 100;
    progress = await fresh();
  });

  group('stars', () {
    test('3 stars need 45% of the clock left and no revive', () {
      expect(
        StageEconomy.stars(secondsLeft: 50, totalSeconds: 100, revived: false),
        3,
      );
      expect(
        StageEconomy.stars(secondsLeft: 50, totalSeconds: 100, revived: true),
        2,
      );
      expect(
        StageEconomy.stars(secondsLeft: 25, totalSeconds: 100, revived: false),
        2,
      );
      expect(
        StageEconomy.stars(secondsLeft: 5, totalSeconds: 100, revived: false),
        1,
      );
    });
  });

  group('campaign', () {
    test('a first clear unlocks the next stage and pays souls', () {
      expect(progress.nextStage, 1);
      final result = progress.recordStageClear(stage: 1, stars: 2, seconds: 40);
      expect(result.firstClear, isTrue);
      expect(result.newStars, 2);
      expect(result.souls, greaterThan(0));
      expect(progress.souls, result.souls);
      expect(progress.nextStage, 2);
      expect(progress.isUnlocked(2), isTrue);
      expect(progress.isUnlocked(3), isFalse);
    });

    test('a replay pays less but rewards new stars', () {
      final first = progress.recordStageClear(stage: 1, stars: 1, seconds: 60);
      final replay = progress.recordStageClear(stage: 1, stars: 1, seconds: 70);
      expect(replay.firstClear, isFalse);
      expect(replay.souls, lessThan(first.souls));
      final better = progress.recordStageClear(stage: 1, stars: 3, seconds: 30);
      expect(better.newStars, 2);
      expect(progress.starsFor(1), 3);
      expect(progress.bestSecondsFor(1), 30);
    });

    test('a gate stage pays a chest on its first clear', () {
      final result = progress.recordStageClear(
        stage: 10,
        stars: 1,
        seconds: 80,
      );
      expect(result.gateChest, isNotNull);
      expect(progress.profile.stat(Stat.chests), 1);
    });

    test('worlds split the 100 stages into five twists', () {
      expect(Worlds.forStage(1).twist, WorldTwist.none);
      expect(Worlds.forStage(21).twist, WorldTwist.crumbling);
      expect(Worlds.forStage(60).twist, WorldTwist.shifting);
      expect(Worlds.forStage(61).twist, WorldTwist.blackout);
      expect(Worlds.forStage(100).twist, WorldTwist.rage);
    });
  });

  group('login calendar', () {
    test('consecutive days climb the calendar and day 7 pays a runner', () {
      for (var d = 1; d <= 7; d++) {
        expect(progress.loginClaimable, isTrue);
        expect(progress.loginNextDay, d);
        progress.claimLogin();
        expect(progress.loginClaimable, isFalse);
        day += 1;
      }
      expect(progress.owns('runner_candle_keeper'), isTrue);
      expect(progress.loginNextDay, 1, reason: 'a new week starts');
    });

    test('a missed day restarts the calendar', () {
      progress.claimLogin();
      day += 1;
      progress.claimLogin();
      day += 2;
      expect(progress.loginStreakBroken, isTrue);
      expect(progress.loginNextDay, 1);
    });

    test('a doubled claim pays twice the souls', () {
      final before = progress.souls;
      final reward = progress.claimLogin(doubled: true);
      expect(reward.souls, LoginCalendar.days.first.souls * 2);
      expect(progress.souls - before, reward.souls);
    });
  });

  group('missions', () {
    test('three different missions, the same for everyone on a day', () {
      final a = DailyMissions.forDay(42);
      final b = DailyMissions.forDay(42);
      expect(a.length, 3);
      expect(a.map((m) => m.kind).toSet().length, 3);
      expect(
        a.map((m) => '${m.kind}${m.target}'),
        b.map((m) => '${m.kind}${m.target}'),
      );
    });

    test('runs move missions; claiming all three unlocks the bonus', () {
      final run = RunTally(mode: PlayMode.campaign)
        ..escaped = true
        ..stars = 3
        ..wisps = 50
        ..keys = 10
        ..flips = 30
        ..safeVisits = 8
        ..powerUps = 4;
      for (var i = 0; i < 6; i++) {
        progress.recordRun(run);
      }
      progress.openFreeChest();
      progress.openAdChest();
      for (var i = 0; i < progress.missions.length; i++) {
        final m = progress.missions[i];
        if (m.kind == MissionKind.endlessDepth ||
            m.kind == MissionKind.dailyEscape) {
          continue;
        }
        expect(m.complete, isTrue, reason: m.title);
      }
    });

    test('a new day brings new missions', () {
      final before = progress.missions.map((m) => m.kind).toList();
      day += 1;
      progress.refreshDay();
      expect(progress.profile.missionsDay, day);
      expect(progress.missions.length, 3);
      expect(progress.missions.every((m) => m.progress == 0), isTrue);
      expect(before.length, 3);
    });
  });

  group('chests', () {
    test('one free chest a day and three for videos', () {
      expect(progress.freeChestReady, isTrue);
      final reward = progress.openFreeChest();
      expect(reward.souls, greaterThan(0));
      expect(progress.freeChestReady, isFalse);
      expect(progress.openFreeChest().isEmpty, isTrue);
      for (var i = 0; i < Chests.adChestsPerDay; i++) {
        expect(progress.openAdChest().isEmpty, isFalse);
      }
      expect(progress.adChestsLeft, 0);
      day += 1;
      expect(progress.freeChestReady, isTrue);
      expect(progress.adChestsLeft, Chests.adChestsPerDay);
    });
  });

  group('shop and boosts', () {
    test('buying needs souls, then equips the item', () {
      final scout = ShopCatalog.byId('runner_moss_scout')!;
      expect(progress.buy(scout), PurchaseResult.notEnoughSouls);
      progress.grantBonusSouls(scout.price);
      expect(progress.buy(scout), PurchaseResult.bought);
      expect(progress.souls, 0);
      expect(progress.isEquipped(scout), isTrue);
      expect(progress.buy(scout), PurchaseResult.alreadyOwned);
      final keeper = ShopCatalog.byId('runner_candle_keeper')!;
      expect(progress.buy(keeper), PurchaseResult.notForSale);
    });

    test('boosts are bought and consumed one at a time', () {
      final shieldsAtStart = progress.boostCount(BoostType.shield);
      progress.grantBonusSouls(Boosts.info[BoostType.frost]!.price);
      expect(progress.buyBoost(BoostType.frost), isTrue);
      expect(progress.boostCount(BoostType.frost), 1);
      expect(progress.consumeBoost(BoostType.frost), isTrue);
      expect(progress.consumeBoost(BoostType.frost), isFalse);
      expect(progress.boostCount(BoostType.shield), shieldsAtStart);
    });
  });

  group('achievements', () {
    test('the first escape becomes claimable and is announced once', () {
      final first = Achievements.byId('first_escape')!;
      expect(progress.canClaimAchievement(first), isFalse);
      progress.recordRun(RunTally(mode: PlayMode.campaign)..escaped = true);
      expect(progress.canClaimAchievement(first), isTrue);
      expect(
        progress.takeNewAchievements().map((a) => a.id),
        contains('first_escape'),
      );
      expect(progress.takeNewAchievements(), isEmpty);
      final before = progress.souls;
      progress.claimAchievement(first);
      expect(progress.souls - before, first.souls);
      expect(progress.canClaimAchievement(first), isFalse);
    });
  });

  test('progress survives a save and a reload', () async {
    progress.recordStageClear(stage: 1, stars: 3, seconds: 20);
    progress.claimLogin();
    progress.equip(ShopCatalog.byId('trail_none')!);
    await progress.save();
    final reloaded = await fresh();
    expect(reloaded.starsFor(1), 3);
    expect(reloaded.souls, progress.souls);
    expect(reloaded.loginClaimable, isFalse);
    expect(reloaded.profile.trail, 'trail_none');
  });

  test('a corrupt save starts fresh instead of crashing', () async {
    portal.store['fearflip.profile.v1'] = '{not json';
    final reloaded = await fresh();
    expect(reloaded.loaded, isTrue);
    expect(reloaded.nextStage, 1);
  });

  test('midgame ads wait for several stages', () {
    expect(progress.midgameDue(), isFalse);
  });
}
