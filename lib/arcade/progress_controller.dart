import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../game/daily/daily_nightmare.dart';
import 'model/achievements.dart';
import 'model/boosts.dart';
import 'model/missions.dart';
import 'model/profile.dart';
import 'model/rewards.dart';
import 'model/run_tally.dart';
import 'model/shop_catalog.dart';
import 'model/worlds.dart';
import 'platform/portal.dart';

/// What a stage clear paid.
@immutable
class StageClearResult {
  const StageClearResult({
    required this.stage,
    required this.stars,
    required this.previousStars,
    required this.souls,
    required this.firstClear,
    required this.newBestTime,
    this.gateChest,
  });

  final int stage;
  final int stars;
  final int previousStars;
  final int souls;
  final bool firstClear;
  final bool newBestTime;

  /// A gate stage's chest (first clear only).
  final Reward? gateChest;

  int get newStars => max(0, stars - previousStars);
  bool get worldCleared => firstClear && stage % Worlds.stagesPerWorld == 0;
}

/// What an Endless Night run paid.
@immutable
class EndlessResult {
  const EndlessResult({
    required this.depth,
    required this.score,
    required this.souls,
    required this.newBestDepth,
    required this.newBestScore,
  });

  final int depth;
  final int score;
  final int souls;
  final bool newBestDepth;
  final bool newBestScore;
}

enum PurchaseResult { bought, notEnoughSouls, alreadyOwned, notForSale }

/// The player's progress, wallet and dailies, saved through the [Portal]
/// (CrazyGames cloud data on the web, SharedPreferences on phones).
class ProgressController extends ChangeNotifier {
  ProgressController({
    required Portal portal,
    int Function()? today,
    Random? random,
    DateTime Function()? clock,
  }) : _portal = portal,
       _clock = clock ?? DateTime.now,
       _rng = random ?? Random() {
    _today = today ?? () => DailyChallenge.dayIndexFor(_clock());
  }

  final Portal _portal;
  final DateTime Function() _clock;
  late final int Function() _today;
  final Random _rng;

  PlayerProfile _p = PlayerProfile();
  bool _loaded = false;
  Timer? _saveTimer;
  final List<Achievement> _toasts = <Achievement>[];
  DateTime? _lastMidgameAt;
  final DateTime _sessionStart = DateTime.now();

  PlayerProfile get profile => _p;
  bool get loaded => _loaded;
  int get today => _today();

  Future<void> load() async {
    try {
      final raw = await _portal.read(PlayerProfile.storageKey);
      if (raw != null && raw.isNotEmpty) {
        final json = jsonDecode(raw);
        if (json is Map) {
          _p = PlayerProfile.fromJson(json.cast<String, dynamic>());
        }
      }
    } catch (error) {
      debugPrint('[Progress] load failed, starting fresh: $error');
      _p = PlayerProfile();
    }
    _rollDay();
    // Achievements finished on a previous visit show their badge, not a toast.
    _checkAchievements();
    _loaded = true;
    notifyListeners();
  }

  /// Starts a new day's missions and chest allowance when the date changed.
  void _rollDay() {
    final day = _today();
    if (_p.missionsDay != day || _p.missions.length != DailyMissions.perDay) {
      _p.missionsDay = day;
      _p.missions = DailyMissions.forDay(day);
      _p.missionsBonusClaimed = false;
    }
    if (_p.adChestDay != day) {
      _p.adChestDay = day;
      _p.adChestsOpened = 0;
    }
  }

  /// Call when the app comes back to the menu: a new day may have begun.
  void refreshDay() {
    final before = _p.missionsDay;
    _rollDay();
    if (before != _p.missionsDay) _changed();
  }

  void _changed({bool now = false}) {
    notifyListeners();
    _saveTimer?.cancel();
    if (now) {
      unawaited(save());
    } else {
      _saveTimer = Timer(const Duration(milliseconds: 400), save);
    }
  }

  Future<void> save() async {
    _saveTimer?.cancel();
    try {
      await _portal.write(PlayerProfile.storageKey, jsonEncode(_p.toJson()));
    } catch (error) {
      debugPrint('[Progress] save failed: $error');
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Wallet and rewards
  // ---------------------------------------------------------------------------

  int get souls => _p.souls;

  bool canAfford(int price) => _p.souls >= price;

  void _addSouls(int amount) {
    if (amount <= 0) return;
    _p.souls += amount;
    _p.soulsEarned += amount;
  }

  /// Pays [reward] out; any chests in it are opened on the spot and their
  /// contents added. Returns everything that was given.
  Reward _grant(Reward reward, {ChestTier chestTier = ChestTier.rich}) {
    var total = Reward(
      souls: reward.souls,
      boosts: reward.boosts,
      itemId: reward.itemId,
    );
    for (var i = 0; i < reward.chests; i++) {
      total = total + Chests.roll(_rng, tier: chestTier);
      _bump(Stat.chests);
      _progressMission(MissionKind.openChest, 1);
    }
    _addSouls(total.souls);
    for (final e in total.boosts.entries) {
      _p.boosts[e.key] = (_p.boosts[e.key] ?? 0) + e.value;
    }
    final item = total.itemId;
    if (item != null) _p.owned.add(item);
    _checkAchievements();
    return total;
  }

  void _bump(Stat stat, [int by = 1]) {
    if (by == 0) return;
    _p.stats[stat] = _p.stat(stat) + by;
  }

  // ---------------------------------------------------------------------------
  // Campaign
  // ---------------------------------------------------------------------------

  int get highestCleared => _p.highestCleared;
  int get highestUnlocked => min(Worlds.maxStage, _p.highestCleared + 1);
  int get totalStars => _p.totalStars;
  int get maxStars => Worlds.maxStage * 3;

  /// The stage the big PLAY button starts.
  int get nextStage => highestUnlocked;

  bool isUnlocked(int stage) => stage >= 1 && stage <= highestUnlocked;
  int starsFor(int stage) => _p.stars[stage] ?? 0;
  int? bestSecondsFor(int stage) => _p.bestSeconds[stage];

  int starsInWorld(WorldInfo world) {
    var sum = 0;
    for (var s = world.firstStage; s <= world.lastStage; s++) {
      sum += starsFor(s);
    }
    return sum;
  }

  bool isWorldUnlocked(WorldInfo world) => isUnlocked(world.firstStage);

  StageClearResult recordStageClear({
    required int stage,
    required int stars,
    required int seconds,
  }) {
    final previous = starsFor(stage);
    final firstClear = previous == 0;
    final best = _p.bestSeconds[stage];
    final newBest = best == null || seconds < best;
    final clamped = stars.clamp(1, 3);
    if (clamped > previous) _p.stars[stage] = clamped;
    if (newBest) _p.bestSeconds[stage] = seconds;
    final souls = StageEconomy.clearSouls(
      stage: stage,
      stars: clamped,
      firstClear: firstClear,
      newStars: max(0, clamped - previous),
    );
    _addSouls(souls);
    Reward? chest;
    if (firstClear && Worlds.isGate(stage)) {
      chest = _grant(const Reward(chests: 1));
    }
    _p.stagesSinceMidgame += 1;
    _checkAchievements();
    _changed(now: true);
    return StageClearResult(
      stage: stage,
      stars: clamped,
      previousStars: previous,
      souls: souls,
      firstClear: firstClear,
      newBestTime: newBest && best != null,
      gateChest: chest,
    );
  }

  /// Doubles a stage clear's souls (after a rewarded video).
  void grantBonusSouls(int souls) {
    _addSouls(souls);
    _changed(now: true);
  }

  // ---------------------------------------------------------------------------
  // Runs (every attempt, won or lost): stats, missions, wisps
  // ---------------------------------------------------------------------------

  void recordRun(RunTally run) {
    _rollDay();
    for (final e in run.increments.entries) {
      _bump(e.key, e.value);
    }
    // Soul wisps found in the maze are kept even when the run is lost.
    _addSouls(run.wisps);
    _p.missions = [for (final m in _p.missions) m.afterRun(run)];
    if (run.escaped) _p.tutorialDone = true;
    _checkAchievements();
    _changed(now: true);
  }

  // ---------------------------------------------------------------------------
  // Endless Night
  // ---------------------------------------------------------------------------

  int get endlessBestDepth => _p.endlessBestDepth;
  int get endlessBestScore => _p.endlessBestScore;

  EndlessResult recordEndless({required int depth, required int score}) {
    final newDepth = depth > _p.endlessBestDepth;
    final newScore = score > _p.endlessBestScore;
    if (newDepth) _p.endlessBestDepth = depth;
    if (newScore) _p.endlessBestScore = score;
    final souls = StageEconomy.endlessSouls(depth);
    _addSouls(souls);
    _checkAchievements();
    _changed(now: true);
    return EndlessResult(
      depth: depth,
      score: score,
      souls: souls,
      newBestDepth: newDepth && depth > 0,
      newBestScore: newScore && score > 0,
    );
  }

  // ---------------------------------------------------------------------------
  // Daily Nightmare reward
  // ---------------------------------------------------------------------------

  bool get dailyNightmareRewardReady => _p.dailyRewardDay != _today();

  /// The first escape of the day pays souls and a chest; later ones nothing.
  Reward? claimDailyNightmareEscape() {
    if (!dailyNightmareRewardReady) return null;
    _p.dailyRewardDay = _today();
    final granted = _grant(
      const Reward(souls: StageEconomy.dailyEscapeSouls, chests: 1),
      chestTier: ChestTier.common,
    );
    _changed(now: true);
    return granted;
  }

  // ---------------------------------------------------------------------------
  // Login calendar
  // ---------------------------------------------------------------------------

  bool get loginClaimable =>
      LoginCalendar.canClaim(today: _today(), lastDay: _p.loginLastDay);

  /// The calendar day (1–7) the next claim pays.
  int get loginNextDay => LoginCalendar.nextDay(
    today: _today(),
    lastDay: _p.loginLastDay,
    lastStreakDay: _p.loginStreakDay,
  );

  /// Calendar days already claimed in the current week (0–7).
  int get loginClaimedDays {
    if (_p.loginLastDay == null) return 0;
    if (loginClaimable) return loginNextDay - 1;
    return _p.loginStreakDay;
  }

  bool get loginStreakBroken =>
      LoginCalendar.streakBroken(today: _today(), lastDay: _p.loginLastDay);

  Reward claimLogin({bool doubled = false}) {
    if (!loginClaimable) return const Reward();
    final day = loginNextDay;
    var reward = LoginCalendar.days[day - 1];
    if (doubled) reward = reward.doubled();
    _p.loginLastDay = _today();
    _p.loginStreakDay = day;
    _p.loginBestRun = max(_p.loginBestRun, day);
    _bump(Stat.loginDays);
    final granted = _grant(reward, chestTier: ChestTier.rich);
    _changed(now: true);
    return granted;
  }

  // ---------------------------------------------------------------------------
  // Daily missions
  // ---------------------------------------------------------------------------

  List<Mission> get missions => List<Mission>.unmodifiable(_p.missions);

  int get missionsDone => _p.missions.where((m) => m.complete).length;

  bool get missionsBonusReady =>
      !_p.missionsBonusClaimed &&
      _p.missions.isNotEmpty &&
      _p.missions.every((m) => m.claimed);

  bool get missionsBonusClaimed => _p.missionsBonusClaimed;

  void _progressMission(MissionKind kind, int by) {
    _p.missions = [
      for (final m in _p.missions)
        m.kind == kind ? m.withProgress(m.progress + by) : m,
    ];
  }

  Reward claimMission(int index, {bool doubled = false}) {
    if (index < 0 || index >= _p.missions.length) return const Reward();
    final mission = _p.missions[index];
    if (!mission.claimable) return const Reward();
    _p.missions[index] = mission.claim();
    final souls = doubled ? mission.reward * 2 : mission.reward;
    final granted = _grant(Reward(souls: souls));
    _changed(now: true);
    return granted;
  }

  Reward claimMissionsBonus() {
    if (!missionsBonusReady) return const Reward();
    _p.missionsBonusClaimed = true;
    final granted = _grant(
      const Reward(souls: DailyMissions.bonusSouls, chests: 1),
    );
    _changed(now: true);
    return granted;
  }

  // ---------------------------------------------------------------------------
  // Chests
  // ---------------------------------------------------------------------------

  bool get freeChestReady => _p.freeChestDay != _today();

  int get adChestsLeft {
    _rollDay();
    return max(0, Chests.adChestsPerDay - _p.adChestsOpened);
  }

  Reward openFreeChest() {
    if (!freeChestReady) return const Reward();
    _p.freeChestDay = _today();
    final granted = _grant(const Reward(chests: 1), chestTier: ChestTier.common);
    _changed(now: true);
    return granted;
  }

  Reward openAdChest() {
    if (adChestsLeft <= 0) return const Reward();
    _p.adChestsOpened += 1;
    final granted = _grant(const Reward(chests: 1), chestTier: ChestTier.common);
    _changed(now: true);
    return granted;
  }

  // ---------------------------------------------------------------------------
  // Free souls for a video (shop)
  // ---------------------------------------------------------------------------

  static const int freeSoulVideosPerDay = 5;
  static const int freeSoulsPerVideo = 60;

  int get freeSoulVideosLeft {
    if (_p.freeSoulsDay != _today()) return freeSoulVideosPerDay;
    return max(0, freeSoulVideosPerDay - _p.freeSoulsTaken);
  }

  /// Pays a video's souls. Returns the souls given (0 when none are left).
  int claimFreeSoulVideo() {
    if (freeSoulVideosLeft <= 0) return 0;
    if (_p.freeSoulsDay != _today()) {
      _p.freeSoulsDay = _today();
      _p.freeSoulsTaken = 0;
    }
    _p.freeSoulsTaken += 1;
    _addSouls(freeSoulsPerVideo);
    _changed(now: true);
    return freeSoulsPerVideo;
  }

  // ---------------------------------------------------------------------------
  // Shop
  // ---------------------------------------------------------------------------

  bool owns(String id) => _p.owned.contains(id);

  bool isEquipped(ShopItem item) => switch (item.category) {
    ShopCategory.runner => _p.runner == item.id,
    ShopCategory.lantern => _p.lantern == item.id,
    ShopCategory.trail => _p.trail == item.id,
  };

  PurchaseResult buy(ShopItem item) {
    if (owns(item.id)) return PurchaseResult.alreadyOwned;
    if (!item.buyable) return PurchaseResult.notForSale;
    if (!canAfford(item.price)) return PurchaseResult.notEnoughSouls;
    _p.souls -= item.price;
    _p.owned.add(item.id);
    equip(item);
    _checkAchievements();
    _changed(now: true);
    return PurchaseResult.bought;
  }

  void equip(ShopItem item) {
    if (!owns(item.id)) return;
    switch (item.category) {
      case ShopCategory.runner:
        _p.runner = item.id;
      case ShopCategory.lantern:
        _p.lantern = item.id;
      case ShopCategory.trail:
        _p.trail = item.id;
    }
    _changed();
  }

  RunnerLook get look => RunnerLook.of(
    runnerId: _p.runner,
    lanternId: _p.lantern,
    trailId: _p.trail,
  );

  int get unlockedItemCount =>
      _p.owned.difference(ShopCatalog.startingItems).length;

  // ---------------------------------------------------------------------------
  // Boosts
  // ---------------------------------------------------------------------------

  int boostCount(BoostType type) => _p.boosts[type] ?? 0;

  bool buyBoost(BoostType type) {
    final price = Boosts.info[type]!.price;
    if (!canAfford(price)) return false;
    _p.souls -= price;
    _p.boosts[type] = boostCount(type) + 1;
    _changed(now: true);
    return true;
  }

  /// Takes one boost out of the inventory for a stage.
  bool consumeBoost(BoostType type) {
    final count = boostCount(type);
    if (count <= 0) return false;
    if (count == 1) {
      _p.boosts.remove(type);
    } else {
      _p.boosts[type] = count - 1;
    }
    _changed();
    return true;
  }

  // ---------------------------------------------------------------------------
  // Achievements
  // ---------------------------------------------------------------------------

  int metricValue(Achievement a) => switch (a.metric) {
    AchievementMetric.stat => _p.stat(a.stat!),
    AchievementMetric.highestCleared => _p.highestCleared,
    AchievementMetric.totalStars => _p.totalStars,
    AchievementMetric.endlessBest => _p.endlessBestDepth,
    AchievementMetric.ownedItems => unlockedItemCount,
    AchievementMetric.loginStreak => _p.loginBestRun,
  };

  bool isComplete(Achievement a) => metricValue(a) >= a.target;
  bool isClaimed(Achievement a) => _p.achievements.contains(a.id);
  bool canClaimAchievement(Achievement a) => isComplete(a) && !isClaimed(a);

  int get claimableAchievements =>
      Achievements.all.where(canClaimAchievement).length;

  int get claimedAchievements => _p.achievements.length;

  Reward claimAchievement(Achievement a) {
    if (!canClaimAchievement(a)) return const Reward();
    _p.achievements.add(a.id);
    final granted = _grant(Reward(souls: a.souls, itemId: a.itemId));
    _changed(now: true);
    return granted;
  }

  final Set<String> _announced = <String>{};

  void _checkAchievements() {
    for (final a in Achievements.all) {
      if (_announced.contains(a.id) || isClaimed(a)) continue;
      if (isComplete(a)) {
        _announced.add(a.id);
        if (_loaded) _toasts.add(a);
      }
    }
  }

  /// Achievements completed since the last call (for a toast).
  List<Achievement> takeNewAchievements() {
    final list = List<Achievement>.of(_toasts);
    _toasts.clear();
    return list;
  }

  // ---------------------------------------------------------------------------
  // Badges for the menu
  // ---------------------------------------------------------------------------

  int get claimableMissions => _p.missions.where((m) => m.claimable).length;

  bool get dailyBadge =>
      loginClaimable ||
      freeChestReady ||
      claimableMissions > 0 ||
      missionsBonusReady;

  // ---------------------------------------------------------------------------
  // Ad pacing
  // ---------------------------------------------------------------------------

  /// Stages cleared between midgame ads, and the quiet minutes around them.
  static const int stagesPerMidgame = 3;
  static const Duration midgameGap = Duration(minutes: 3);
  static const Duration firstMidgameAfter = Duration(minutes: 2);

  /// True when a midgame ad fits here (between stages, never in the first
  /// minutes of a session, at most one every few minutes).
  bool midgameDue() {
    final now = DateTime.now();
    if (now.difference(_sessionStart) < firstMidgameAfter) return false;
    final last = _lastMidgameAt;
    if (last != null && now.difference(last) < midgameGap) return false;
    return _p.stagesSinceMidgame >= stagesPerMidgame;
  }

  void markMidgameShown() {
    _lastMidgameAt = DateTime.now();
    _p.stagesSinceMidgame = 0;
    _changed();
  }

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  bool get musicOn => _p.musicOn;
  bool get sfxOn => _p.sfxOn;
  bool get arrowPad => _p.arrowPad;
  double get padSize => _p.padSize;
  bool get tutorialDone => _p.tutorialDone;

  set musicOn(bool value) {
    _p.musicOn = value;
    _changed();
  }

  set sfxOn(bool value) {
    _p.sfxOn = value;
    _changed();
  }

  set arrowPad(bool value) {
    _p.arrowPad = value;
    _changed();
  }

  set padSize(double value) {
    _p.padSize = value.clamp(90.0, 180.0);
    _changed();
  }

  /// Wipes all progress (settings → reset).
  void resetProgress() {
    final music = _p.musicOn;
    final sfx = _p.sfxOn;
    _p = PlayerProfile()
      ..musicOn = music
      ..sfxOn = sfx;
    _announced.clear();
    _toasts.clear();
    _rollDay();
    _changed(now: true);
  }

  /// Seconds since the clock's day began, for the daily countdowns.
  Duration get untilTomorrow {
    final now = _clock();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tomorrow.difference(now);
  }
}
