import 'package:flutter/foundation.dart';

import 'portal_stub.dart'
    if (dart.library.js_interop) 'portal_web.dart'
    as impl;

/// How a requested ad ended.
enum AdOutcome {
  /// The ad played to the end: give the reward.
  finished,

  /// The portal tried and failed (no fill, closed early, error): no reward.
  failed,

  /// No ad system here at all (local testing, an ad-blocker, a portal
  /// without ads). Rewards are granted so the game never blocks on ads.
  unavailable,
}

/// Everything the game needs from the site or store it runs on: the
/// CrazyGames SDK on the web, the phone ad networks on mobile.
///
/// Every call is safe when the portal is missing: gameplay events become
/// no-ops, saves fall back to local storage and ads report [AdOutcome.unavailable].
abstract class Portal {
  /// The portal for this build (CrazyGames bridge on the web).
  static Portal instance = impl.createPortal();

  Future<void> init();

  /// 'crazygames', 'local', 'disabled', 'none' (web without the SDK) or
  /// 'mobile'.
  String get environment;

  bool get isWeb;

  /// The page's own loading screen hides once the first menu is drawn.
  void finishLoading();

  /// Gameplay is running (the maze is live, not paused or in a menu).
  void gameplayStart();

  /// Gameplay stopped: a menu, pause, result screen or ad.
  void gameplayStop();

  /// A moment of joy (a 3-star clear, a new best) the portal may celebrate.
  void happyTime();

  /// A rewarded video; [onStarted] runs right before it shows.
  Future<AdOutcome> rewardedAd({VoidCallback? onStarted});

  /// A short ad at a natural break; [onStarted] runs right before it shows.
  Future<AdOutcome> midgameAd({VoidCallback? onStarted});

  /// The portal asked the game to be silent (CrazyGames' mute setting).
  ValueListenable<bool> get portalMuted;

  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

/// An in-memory portal for tests and previews.
class MemoryPortal implements Portal {
  MemoryPortal({
    this.rewardedResult = AdOutcome.finished,
    this.midgameResult = AdOutcome.finished,
  });

  AdOutcome rewardedResult;
  AdOutcome midgameResult;
  final Map<String, String> store = <String, String>{};
  final List<String> events = <String>[];
  final ValueNotifier<bool> _muted = ValueNotifier<bool>(false);
  int rewardedRequests = 0;
  int midgameRequests = 0;

  @override
  Future<void> init() async {}

  @override
  String get environment => 'memory';

  @override
  bool get isWeb => false;

  @override
  void finishLoading() => events.add('finishLoading');

  @override
  void gameplayStart() => events.add('gameplayStart');

  @override
  void gameplayStop() => events.add('gameplayStop');

  @override
  void happyTime() => events.add('happyTime');

  @override
  Future<AdOutcome> rewardedAd({VoidCallback? onStarted}) async {
    rewardedRequests += 1;
    onStarted?.call();
    return rewardedResult;
  }

  @override
  Future<AdOutcome> midgameAd({VoidCallback? onStarted}) async {
    midgameRequests += 1;
    onStarted?.call();
    return midgameResult;
  }

  @override
  ValueListenable<bool> get portalMuted => _muted;

  @override
  Future<String?> read(String key) async => store[key];

  @override
  Future<void> write(String key, String value) async => store[key] = value;
}
