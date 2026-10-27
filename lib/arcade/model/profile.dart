import 'boosts.dart';
import 'missions.dart';
import 'run_tally.dart';
import 'shop_catalog.dart';

/// Everything saved about a player: progress, wallet, collection, dailies and
/// settings. One JSON document under [PlayerProfile.storageKey].
class PlayerProfile {
  PlayerProfile();

  static const String storageKey = 'fearflip.profile.v1';
  static const int schema = 1;

  // Wallet.
  int souls = 0;
  int soulsEarned = 0;

  // Campaign: best stars and fastest escape per stage.
  final Map<int, int> stars = <int, int>{};
  final Map<int, int> bestSeconds = <int, int>{};

  // Collection.
  final Set<String> owned = Set<String>.of(ShopCatalog.startingItems);
  String runner = ShopCatalog.defaultRunner;
  String lantern = ShopCatalog.defaultLantern;
  String trail = ShopCatalog.defaultTrail;
  final Map<BoostType, int> boosts = <BoostType, int>{BoostType.shield: 1};

  // Lifetime stats.
  final Map<Stat, int> stats = <Stat, int>{};

  // Achievements claimed.
  final Set<String> achievements = <String>{};

  // Login calendar.
  int? loginLastDay;
  int loginStreakDay = 0;
  int loginBestRun = 0;

  // Daily missions.
  int missionsDay = -1;
  List<Mission> missions = <Mission>[];
  bool missionsBonusClaimed = false;

  // Chests.
  int? freeChestDay;
  int adChestDay = -1;
  int adChestsOpened = 0;

  // Free souls for videos (shop), a few per day.
  int freeSoulsDay = -1;
  int freeSoulsTaken = 0;

  // Endless Night.
  int endlessBestDepth = 0;
  int endlessBestScore = 0;

  // Daily Nightmare reward (first escape of the day).
  int? dailyRewardDay;

  // Ad pacing (stages since the last midgame ad).
  int stagesSinceMidgame = 0;

  // Settings.
  bool musicOn = true;
  bool sfxOn = true;
  bool tutorialDone = false;
  bool arrowPad = true;
  double padSize = 130;

  int get highestCleared {
    var best = 0;
    for (final stage in stars.keys) {
      if (stage > best) best = stage;
    }
    return best;
  }

  int get totalStars => stars.values.fold(0, (sum, s) => sum + s);

  int stat(Stat stat) => stats[stat] ?? 0;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'v': schema,
    'souls': souls,
    'soulsEarned': soulsEarned,
    'stars': {for (final e in stars.entries) '${e.key}': e.value},
    'best': {for (final e in bestSeconds.entries) '${e.key}': e.value},
    'owned': owned.toList(),
    'runner': runner,
    'lantern': lantern,
    'trail': trail,
    'boosts': {for (final e in boosts.entries) e.key.name: e.value},
    'stats': {for (final e in stats.entries) e.key.name: e.value},
    'ach': achievements.toList(),
    'loginLast': loginLastDay,
    'loginDay': loginStreakDay,
    'loginBest': loginBestRun,
    'mDay': missionsDay,
    'm': [for (final m in missions) m.toJson()],
    'mBonus': missionsBonusClaimed,
    'chestFree': freeChestDay,
    'chestAdDay': adChestDay,
    'chestAd': adChestsOpened,
    'freeDay': freeSoulsDay,
    'freeTaken': freeSoulsTaken,
    'endlessDepth': endlessBestDepth,
    'endlessScore': endlessBestScore,
    'dailyReward': dailyRewardDay,
    'sinceAd': stagesSinceMidgame,
    'music': musicOn,
    'sfx': sfxOn,
    'tutorial': tutorialDone,
    'arrowPad': arrowPad,
    'padSize': padSize,
  };

  static PlayerProfile fromJson(Map<String, dynamic> json) {
    int i(String key, [int fallback = 0]) =>
        (json[key] as num?)?.toInt() ?? fallback;
    int? n(String key) => (json[key] as num?)?.toInt();
    bool b(String key, bool fallback) => json[key] as bool? ?? fallback;
    Map<String, dynamic> m(String key) =>
        (json[key] as Map?)?.cast<String, dynamic>() ?? const {};

    final p = PlayerProfile()
      ..souls = i('souls').clamp(0, 99999999)
      ..soulsEarned = i('soulsEarned')
      ..runner = json['runner'] as String? ?? ShopCatalog.defaultRunner
      ..lantern = json['lantern'] as String? ?? ShopCatalog.defaultLantern
      ..trail = json['trail'] as String? ?? ShopCatalog.defaultTrail
      ..loginLastDay = n('loginLast')
      ..loginStreakDay = i('loginDay')
      ..loginBestRun = i('loginBest')
      ..missionsDay = i('mDay', -1)
      ..missionsBonusClaimed = b('mBonus', false)
      ..freeChestDay = n('chestFree')
      ..adChestDay = i('chestAdDay', -1)
      ..adChestsOpened = i('chestAd')
      ..freeSoulsDay = i('freeDay', -1)
      ..freeSoulsTaken = i('freeTaken')
      ..endlessBestDepth = i('endlessDepth')
      ..endlessBestScore = i('endlessScore')
      ..dailyRewardDay = n('dailyReward')
      ..stagesSinceMidgame = i('sinceAd')
      ..musicOn = b('music', true)
      ..sfxOn = b('sfx', true)
      ..tutorialDone = b('tutorial', false)
      ..arrowPad = b('arrowPad', true)
      ..padSize = ((json['padSize'] as num?)?.toDouble() ?? 130).clamp(
        90.0,
        180.0,
      );

    for (final e in m('stars').entries) {
      final stage = int.tryParse(e.key);
      final value = (e.value as num?)?.toInt();
      if (stage != null && value != null) {
        p.stars[stage] = value.clamp(1, 3);
      }
    }
    for (final e in m('best').entries) {
      final stage = int.tryParse(e.key);
      final value = (e.value as num?)?.toInt();
      if (stage != null && value != null) p.bestSeconds[stage] = value;
    }
    final owned = json['owned'];
    if (owned is List) {
      p.owned.addAll(owned.whereType<String>());
    }
    p.boosts.clear();
    for (final e in m('boosts').entries) {
      final type = Boosts.byId(e.key);
      final value = (e.value as num?)?.toInt() ?? 0;
      if (type != null && value > 0) p.boosts[type] = value;
    }
    for (final e in m('stats').entries) {
      for (final stat in Stat.values) {
        if (stat.name == e.key) {
          p.stats[stat] = (e.value as num?)?.toInt() ?? 0;
        }
      }
    }
    final ach = json['ach'];
    if (ach is List) p.achievements.addAll(ach.whereType<String>());
    final missions = json['m'];
    if (missions is List) {
      p.missions = [
        for (final raw in missions)
          if (raw is Map) Mission.fromJson(raw.cast<String, dynamic>()),
      ];
    }
    // An item that no longer exists falls back to the default.
    if (!p.owned.contains(p.runner)) p.runner = ShopCatalog.defaultRunner;
    if (!p.owned.contains(p.lantern)) p.lantern = ShopCatalog.defaultLantern;
    if (!p.owned.contains(p.trail)) p.trail = ShopCatalog.defaultTrail;
    return p;
  }
}
