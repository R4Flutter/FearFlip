import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/app_runtime_config.dart';

class AdsService {
  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;

  Future<void> preload() async {
    if (!AppRuntimeConfig.adsEnabled) {
      return;
    }
    await Future.wait([_loadRewarded(), _loadInterstitial()]);
  }

  Future<void> _loadRewarded() {
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
      onUserEarnedReward: (_, __) {
        if (!c.isCompleted) {
          c.complete(true);
        }
      },
    );

    return c.future;
  }

  Future<void> showInterstitialAfterGameOver() async {
    final ad = _interstitialAd;
    if (ad == null) {
      await _loadInterstitial();
      return;
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
    ad.show();
  }

  void dispose() {
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd = null;
    _interstitialAd = null;
  }
}
