import 'dart:async';

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
          ),
      _clock = clock ?? DateTime.now;

  final AdPlacementPolicy _placementPolicy;
  final DateTime Function() _clock;

  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;

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
          c.complete();
        },
        onAdFailedToLoad: (_) => c.complete(),
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

  void dispose() {
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd = null;
    _interstitialAd = null;
  }
}
