import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/app_runtime_config.dart';
import 'ad_placement_policy.dart';
import 'consent_service.dart';
import 'purchase_service.dart';

class AdsService {
  AdsService({AdPlacementPolicy? placementPolicy, DateTime Function()? clock})
    : _placementPolicy =
          placementPolicy ??
          AdPlacementPolicy(
            interstitialCooldown: AppRuntimeConfig.interstitialCooldown,
            minGameOversBeforeInterstitial: AppRuntimeConfig
                .interstitialMinGameOvers
                .clamp(1, 10)
                .toInt(),
            stageClearedInterstitialInterval:
                AppRuntimeConfig.stageClearedAdInterval,
            stageClearedInterstitialCooldown:
                AppRuntimeConfig.stageClearedAdCooldown,
          ),
      _clock = clock ?? DateTime.now;

  final AdPlacementPolicy _placementPolicy;
  final DateTime Function() _clock;

  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;
  BannerAd? _bannerAd;
  bool _bannerLoading = false;

  /// Whether ads are suppressed because the user has an active subscription.
  bool get _subscriberBlocked => PurchaseService.instance.isSubscribed;

  Future<void> preload() async {
    if (_subscriberBlocked ||
        !AppRuntimeConfig.adsEnabled ||
        !ConsentService.instance.canRequestAds) {
      return;
    }
    await Future.wait([
      if (AppRuntimeConfig.rewardedAdsEnabled) _loadRewarded(),
      if (AppRuntimeConfig.interstitialAdsEnabled) _loadInterstitial(),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Banner ad
  // ---------------------------------------------------------------------------

  /// The currently loaded banner ad, or null if not yet ready.
  BannerAd? get bannerAd => _bannerAd;

  /// Loads a banner ad.  Call once when the dashboard mounts.
  Future<void> loadBanner() async {
    if (_subscriberBlocked ||
        !AppRuntimeConfig.bannerAdsEnabled ||
        !ConsentService.instance.canRequestAds ||
        _bannerLoading) {
      return;
    }

    final adUnitId = AppRuntimeConfig.bannerAdUnitId;
    if (adUnitId == null) {
      return;
    }

    _bannerLoading = true;
    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner, // 320×50 standard
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          debugPrint('[AdsService] Banner loaded');
          _bannerLoading = false;
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[AdsService] Banner failed: ${error.message}');
          ad.dispose();
          _bannerAd = null;
          _bannerLoading = false;
        },
      ),
    );
    await _bannerAd!.load();
  }

  /// Disposes the banner ad.  Call when the dashboard unmounts.
  void disposeBanner() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _bannerLoading = false;
  }

  Future<void> _loadRewarded() {
    if (!AppRuntimeConfig.rewardedAdsEnabled ||
        !ConsentService.instance.canRequestAds) {
      return Future.value();
    }
    final adUnitId = AppRuntimeConfig.rewardedAdUnitId;
    if (adUnitId == null) {
      return Future.value();
    }

    final c = Completer<void>();
    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          c.complete();
        },
        onAdFailedToLoad: (_) => c.complete(),
      ),
    );
    return c.future;
  }

  Future<void> _loadInterstitial() {
    if (!AppRuntimeConfig.interstitialAdsEnabled ||
        !ConsentService.instance.canRequestAds) {
      return Future.value();
    }
    final adUnitId = AppRuntimeConfig.interstitialAdUnitId;
    if (adUnitId == null) {
      return Future.value();
    }

    final c = Completer<void>();
    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          debugPrint('[AdsService] Ad Loaded');
          c.complete();
        },
        onAdFailedToLoad: (error) {
          debugPrint('[AdsService] Ad Failed: ${error.message}');
          c.complete();
        },
      ),
    );
    return c.future;
  }

  Future<bool> showRewardedForRevive() async {
    if (_subscriberBlocked ||
        !AppRuntimeConfig.rewardedAdsEnabled ||
        !ConsentService.instance.canRequestAds) {
      return false;
    }

    final ad = _rewardedAd;
    if (ad == null) {
      await _loadRewarded();
      return false;
    }

    final c = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        unawaited(_loadRewarded());
        if (!c.isCompleted) {
          c.complete(false);
        }
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _rewardedAd = null;
        unawaited(_loadRewarded());
        if (!c.isCompleted) {
          c.complete(false);
        }
      },
    );

    ad.show(
      onUserEarnedReward: (_, _) {
        if (!c.isCompleted) {
          c.complete(true);
        }
      },
    );

    return c.future;
  }

  Future<bool> showInterstitialAfterGameOver() async {
    _placementPolicy.recordGameOver();
    if (_subscriberBlocked ||
        !AppRuntimeConfig.interstitialAdsEnabled ||
        !ConsentService.instance.canRequestAds ||
        !_placementPolicy.canShowInterstitial(_clock())) {
      return false;
    }

    final ad = _interstitialAd;
    if (ad == null) {
      await _loadInterstitial();
      return false;
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        unawaited(_loadInterstitial());
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _interstitialAd = null;
        unawaited(_loadInterstitial());
      },
    );
    _placementPolicy.recordInterstitialShown(_clock());
    ad.show();
    return true;
  }

  // ---------------------------------------------------------------------------
  // Stage-cleared interstitial
  // ---------------------------------------------------------------------------

  /// True when an interstitial ad is loaded and ready to display.
  bool get isInterstitialReady => _interstitialAd != null;

  /// Call this immediately after a stage completion screen is shown.
  ///
  /// Shows an interstitial ad when:
  ///   • [clearedStage] is a multiple of the configured interval (default 3)
  ///   • The 30-second cooldown since the last stage ad has elapsed
  ///   • No subscriber block, no consent block, and ads are enabled
  ///   • An ad is already loaded (silent skip when not ready — no crash)
  ///
  /// After the ad is dismissed, the next ad is preloaded automatically.
  Future<void> showInterstitialAfterStageCleared(int clearedStage) async {
    if (_subscriberBlocked ||
        !AppRuntimeConfig.interstitialAdsEnabled ||
        !ConsentService.instance.canRequestAds) {
      debugPrint('[AdsService] Ad Skipped (subscriber/consent blocked)');
      return;
    }

    if (!_placementPolicy.canShowInterstitialForStage(
      clearedStage,
      _clock(),
    )) {
      debugPrint(
        '[AdsService] Ad Skipped (cooldown/not ready) '
        '— stage=$clearedStage',
      );
      return;
    }

    final ad = _interstitialAd;
    if (ad == null) {
      debugPrint(
        '[AdsService] Ad Skipped (not loaded) — preloading for next time',
      );
      unawaited(_loadInterstitial());
      return;
    }

    _placementPolicy.recordStageClearedInterstitialShown(_clock());

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        debugPrint('[AdsService] Ad Shown — stage=$clearedStage');
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        debugPrint('[AdsService] Ad Dismissed — preloading next');
        unawaited(_loadInterstitial());
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        debugPrint('[AdsService] Ad Failed to show: ${error.message}');
        unawaited(_loadInterstitial());
      },
    );

    ad.show();
  }

  void dispose() {
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
    disposeBanner();
    _rewardedAd = null;
    _interstitialAd = null;
  }
}
