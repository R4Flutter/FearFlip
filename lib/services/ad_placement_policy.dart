class AdPlacementPolicy {
  AdPlacementPolicy({
    required this.interstitialCooldown,
    this.minGameOversBeforeInterstitial = 2,
    this.stageClearedInterstitialInterval = 3,
    this.stageClearedInterstitialCooldown = const Duration(seconds: 30),
  })  : assert(minGameOversBeforeInterstitial >= 1),
        assert(stageClearedInterstitialInterval >= 1);

  // ── Game-over triggered interstitial ─────────────────────────────────────
  final Duration interstitialCooldown;
  final int minGameOversBeforeInterstitial;

  DateTime? _lastInterstitialShownAt;
  int _gameOversSinceInterstitial = 0;

  int get gameOversSinceInterstitial => _gameOversSinceInterstitial;
  DateTime? get lastInterstitialShownAt => _lastInterstitialShownAt;

  void recordGameOver() {
    _gameOversSinceInterstitial += 1;
  }

  bool canShowInterstitial(DateTime now) {
    if (_gameOversSinceInterstitial < minGameOversBeforeInterstitial) {
      return false;
    }
    final lastShown = _lastInterstitialShownAt;
    if (lastShown == null) {
      return true;
    }
    return now.difference(lastShown) >= interstitialCooldown;
  }

  void recordInterstitialShown(DateTime now) {
    _lastInterstitialShownAt = now;
    _gameOversSinceInterstitial = 0;
  }

  // ── Stage-cleared triggered interstitial ─────────────────────────────────
  //
  // Fires when clearedStage % stageClearedInterstitialInterval == 0, subject
  // to its own independent cooldown so it never collides with the game-over
  // interstitial gate.
  final int stageClearedInterstitialInterval;
  final Duration stageClearedInterstitialCooldown;

  DateTime? _lastStageClearedInterstitialAt;

  /// Returns true when [clearedStage] is on the configured interval boundary
  /// AND the per-stage cooldown has expired.
  bool canShowInterstitialForStage(int clearedStage, DateTime now) {
    if (clearedStage <= 0) {
      return false;
    }
    if (clearedStage % stageClearedInterstitialInterval != 0) {
      return false;
    }
    final lastShown = _lastStageClearedInterstitialAt;
    if (lastShown == null) {
      return true;
    }
    return now.difference(lastShown) >= stageClearedInterstitialCooldown;
  }

  void recordStageClearedInterstitialShown(DateTime now) {
    _lastStageClearedInterstitialAt = now;
  }
}
