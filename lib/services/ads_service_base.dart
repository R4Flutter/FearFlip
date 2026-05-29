import 'package:flutter/widgets.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

import '../data/services/monetization_service.dart';

/// Abstract interface for ad services, allowing consumers to depend on
/// a common type regardless of whether the backing implementation is
/// Unity Ads, AdMob, or the unified [AdsFacade] with fallback.
///
/// This decouples FearFlipGame, LandingScreen, and other widgets from
/// concrete singleton types like [AdManager] or [AdsService].
abstract class AdsServiceBase {
  // ── Lifecycle ─────────────────────────────────────────────────────────

  Future<void> start();
  void stop();
  void disableAdsPermanently();
  void disposeAllAds({String reason = 'dispose'});
  Future<void> preload();
  void dispose();

  // ── Rewarded ──────────────────────────────────────────────────────────

  Future<bool> showRewardedForRevive();

  // ── Interstitial ──────────────────────────────────────────────────────

  Future<bool> showInterstitialAfterGameOver();
  Future<void> showInterstitialAfterStageCleared(int clearedStage);
  bool get isInterstitialReady;

  // ── Banner ────────────────────────────────────────────────────────────

  Future<void> preloadBanner({double? width});
  Future<void> ensureBannerLoaded({
    required double width,
    String reason = 'ensure',
  });
  Future<void> loadBanner();
  void disposeBanner();
  bool get bannerRequested;

  /// Unity-specific: builds a Unity banner widget.
  Widget buildBannerAd({required BannerSize size, required int reloadToken});

  // ── Notifiers ─────────────────────────────────────────────────────────

  ValueNotifier<bool> get bannerLoadedNotifier;
  ValueNotifier<BannerSize> get bannerSizeNotifier;
  ValueNotifier<int> get bannerReloadNotifier;

  // ── Monetization ──────────────────────────────────────────────────────

  MonetizationService get monetization;
  Future<bool> get isPremiumUnlocked;
}
