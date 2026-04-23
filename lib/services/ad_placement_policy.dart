class AdPlacementPolicy {
  AdPlacementPolicy({
    required this.interstitialCooldown,
    this.minGameOversBeforeInterstitial = 2,
  }) : assert(minGameOversBeforeInterstitial >= 1);

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
}
