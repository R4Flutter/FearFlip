import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

import '../config/app_runtime_config.dart';
import '../data/services/monetization_service.dart';
import 'ad_manager.dart';
import 'ads_diagnostics.dart';
import 'ads_service.dart';
import 'ads_service_base.dart';

/// Unified ad gateway that coordinates Unity Ads ([AdManager]) and AdMob
/// ([AdsService]) with automatic network fallback.
///
/// **Priority: Unity Ads FIRST, AdMob as fallback.**
/// If Unity fails to load or show, AdMob is tried immediately.
/// This maximises fill rate while prioritising the higher-eCPM network.
///
/// Implements [AdsServiceBase] so it can be injected into FearFlipGame,
/// LandingScreen, and any other widget that previously depended on the
/// concrete [AdManager] type.
class AdsFacade with WidgetsBindingObserver implements AdsServiceBase {
  AdsFacade._();
  static final AdsFacade instance = AdsFacade._();

  final AdManager _unity = AdManager.instance;
  final AdsService _adMob = AdsService.instance;

  bool _isStarted = false;
  bool _isDisposed = false;

  // ── Banner state ─────────────────────────────────────────────────────

  final ValueNotifier<BannerAd?> _adMobBannerNotifier =
      ValueNotifier<BannerAd?>(null);

  String _bannerNetwork = 'none';

  // ── AdsServiceBase notifiers ──────────────────────────────────────────

  /// Exposes Unity banner-loaded state (for LandingScreen / _BannerAdBar).
  @override
  ValueNotifier<bool> get bannerLoadedNotifier => _unity.bannerLoadedNotifier;

  @override
  ValueNotifier<BannerSize> get bannerSizeNotifier => _unity.bannerSizeNotifier;

  @override
  ValueNotifier<int> get bannerReloadNotifier => _unity.bannerReloadNotifier;

  @override
  bool get bannerRequested => _unity.bannerRequested;

  /// AdMob banner ad for widget embedding.
  ValueNotifier<BannerAd?> get adMobBannerNotifier => _adMobBannerNotifier;

  /// Which network provided the current banner.
  String get bannerNetwork => _bannerNetwork;

  // ── Feature flags ────────────────────────────────────────────────────

  bool get _shouldUseUnity =>
      AppRuntimeConfig.unityAdsEnabled && AppRuntimeConfig.supportsMobileAds;

  bool get _shouldUseAdMob =>
      AppRuntimeConfig.admobAdsEnabled && AppRuntimeConfig.supportsMobileAds;

  @override
  MonetizationService get monetization => _unity.monetization;

  @override
  Future<bool> get isPremiumUnlocked => _unity.isPremiumUnlocked;

  @override
  bool get isInterstitialReady =>
      (_shouldUseUnity && _unity.isInterstitialReady) ||
      (_shouldUseAdMob && _adMob.isInterstitialReady);

  // ── Lifecycle ────────────────────────────────────────────────────────

  @override
  Future<void> start() async {
    if (_isStarted || _isDisposed) return;
    _isStarted = true;

    WidgetsBinding.instance.addObserver(this);

    // Initialize both networks in parallel — no need to wait for one before
    // starting the other. Each network's preload is internally gated on its
    // own init completing, so loads only fire once ready.
    await Future.wait<dynamic>([
      _shouldUseUnity
          ? _unity.start().catchError(
              (e, st) {
                AdsDiagnostics.error('Unity start failed', e, stackTrace: st);
                return null;
              },
            )
          : Future<void>.value(),
      _shouldUseAdMob
          ? _adMob.start().catchError(
              (e, st) {
                AdsDiagnostics.error('AdMob start failed', e, stackTrace: st);
                return null;
              },
            )
          : Future<void>.value(),
    ]);

    // Forward AdMob banner changes for the AdWidget path.
    _adMob.bannerAdNotifier.addListener(_onAdMobBannerChanged);

    AdsDiagnostics.log(
      'AdsFacade started (Unity=primary, AdMob=fallback)',
      data: {'unity': _shouldUseUnity, 'admob': _shouldUseAdMob},
    );
  }

  @override
  void stop() {
    if (!_isStarted) return;
    _isStarted = false;
    WidgetsBinding.instance.removeObserver(this);
    _adMob.bannerAdNotifier.removeListener(_onAdMobBannerChanged);
    _adMob.stop();
    _unity.stop();
  }

  @override
  void dispose() {
    _isDisposed = true;
    stop();
    _adMob.dispose();
    _unity.dispose();
  }

  @override
  void disableAdsPermanently() {
    // Disable BOTH networks — previous code only disabled Unity.
    _unity.disableAdsPermanently();
    _adMob.disableAdsPermanently();
  }

  @override
  void disposeAllAds({String reason = 'dispose'}) {
    _unity.disposeAllAds(reason: reason);
    _adMob.disposeAllAds(reason: reason);
  }

  @override
  Future<void> preload() async {
    if (_shouldUseUnity) {
      unawaited(_unity.preload());
    }
    if (_shouldUseAdMob) {
      unawaited(_adMob.preload());
    }
  }

  // ── Rewarded: Unity first, AdMob fallback ─────────────────────────────

  @override
  Future<bool> showRewardedForRevive() async {
    if (await isPremiumUnlocked) {
      AdsDiagnostics.log('Rewarded skipped: premium user');
      return true;
    }

    // Try Unity FIRST (primary network).
    if (_shouldUseUnity && AppRuntimeConfig.unityRewardedAdsEnabled) {
      AdsDiagnostics.log('Rewarded: trying Unity (primary)');
      final result = await _unity.showRewardedForRevive();
      if (result) {
        AdsDiagnostics.event(
          'ad_facade_rewarded',
          params: {'network': 'unity', 'result': 'success'},
        );
        return true;
      }
      AdsDiagnostics.log('Rewarded: Unity failed, falling back to AdMob');
    }

    // Fallback to AdMob.
    if (_shouldUseAdMob && AppRuntimeConfig.rewardedAdsEnabled) {
      AdsDiagnostics.log('Rewarded: trying AdMob (fallback)');
      final result = await _adMob.showRewardedForRevive();
      AdsDiagnostics.event(
        'ad_facade_rewarded',
        params: {'network': 'admob', 'result': result ? 'success' : 'fail'},
      );
      return result;
    }

    AdsDiagnostics.log('Rewarded: no network available');
    return false;
  }

  // ── Interstitial (game over): Unity first, AdMob fallback ────────────

  @override
  Future<bool> showInterstitialAfterGameOver() async {
    if (await isPremiumUnlocked) return false;

    // Try Unity FIRST.
    if (_shouldUseUnity && AppRuntimeConfig.unityInterstitialAdsEnabled) {
      AdsDiagnostics.log('Interstitial GO: trying Unity (primary)');
      final result = await _unity.showInterstitialAfterGameOver();
      if (result) {
        AdsDiagnostics.event(
          'ad_facade_interstitial',
          params: {'network': 'unity', 'placement': 'game_over'},
        );
        return true;
      }
      AdsDiagnostics.log(
        'Interstitial GO: Unity failed, falling back to AdMob',
      );
    }

    // Fallback to AdMob.
    if (_shouldUseAdMob && AppRuntimeConfig.interstitialAdsEnabled) {
      AdsDiagnostics.log('Interstitial GO: trying AdMob (fallback)');
      final result = await _adMob.showInterstitialAfterGameOver();
      AdsDiagnostics.event(
        'ad_facade_interstitial',
        params: {
          'network': 'admob',
          'placement': 'game_over',
          'result': result ? 'success' : 'fail',
        },
      );
      return result;
    }

    return false;
  }

  // ── Interstitial (stage cleared): Unity first, AdMob fallback ────────

  @override
  Future<bool> showInterstitialAfterStageCleared(int clearedStage) async {
    if (await isPremiumUnlocked) return false;

    // Try Unity FIRST.
    if (_shouldUseUnity && AppRuntimeConfig.unityInterstitialAdsEnabled) {
      AdsDiagnostics.log('Interstitial stage: trying Unity (primary)');
      final result = await _unity.showInterstitialAfterStageCleared(
        clearedStage,
      );
      if (result) {
        AdsDiagnostics.event(
          'ad_facade_interstitial',
          params: {'network': 'unity', 'placement': 'stage_clear'},
        );
        return true;
      }
      AdsDiagnostics.log(
        'Interstitial stage: Unity failed, falling back to AdMob',
      );
    }

    // Fallback to AdMob.
    if (_shouldUseAdMob && AppRuntimeConfig.interstitialAdsEnabled) {
      AdsDiagnostics.log('Interstitial stage: trying AdMob (fallback)');
      final result = await _adMob.showInterstitialAfterStageCleared(
        clearedStage,
      );
      AdsDiagnostics.event(
        'ad_facade_interstitial',
        params: {
          'network': 'admob',
          'placement': 'stage_clear',
          'result': result ? 'success' : 'fail',
        },
      );
      return result;
    }
    return false;
  }

  // ── Banner: Unity first, AdMob fallback ──────────────────────────────

  @override
  Future<void> preloadBanner({double? width}) async {
    if (_shouldUseUnity) {
      unawaited(_unity.preloadBanner(width: width));
    }
    if (_shouldUseAdMob) {
      unawaited(_adMob.preloadBanner(width: width));
    }
  }

  @override
  Future<void> ensureBannerLoaded({
    required double width,
    String reason = 'ensure',
  }) async {
    // Try Unity FIRST.
    if (_shouldUseUnity) {
      await _unity.ensureBannerLoaded(width: width, reason: reason);
      if (_unity.bannerLoadedNotifier.value) {
        _bannerNetwork = 'unity';
        return;
      }
    }
    // Fallback to AdMob.
    if (_shouldUseAdMob) {
      await _adMob.ensureBannerLoaded(width: width, reason: reason);
      if (_adMob.bannerAdNotifier.value != null) {
        _bannerNetwork = 'admob';
        _adMobBannerNotifier.value = _adMob.bannerAdNotifier.value;
      }
    }
  }

  @override
  Future<void> loadBanner() async {
    // Try Unity FIRST.
    if (_shouldUseUnity) {
      await _unity.loadBanner();
      if (_unity.bannerLoadedNotifier.value) {
        _bannerNetwork = 'unity';
        return;
      }
    }
    // Fallback to AdMob.
    if (_shouldUseAdMob) {
      await _adMob.loadBanner();
      if (_adMob.bannerAdNotifier.value != null) {
        _bannerNetwork = 'admob';
        _adMobBannerNotifier.value = _adMob.bannerAdNotifier.value;
      }
    }
  }

  @override
  void disposeBanner() {
    _unity.disposeBanner();
    _adMob.disposeBanner();
    _bannerNetwork = 'none';
  }

  /// Whether any banner is currently loaded and ready to display.
  bool get isBannerLoaded =>
      (_bannerNetwork == 'unity' && _unity.bannerLoadedNotifier.value) ||
      (_bannerNetwork == 'admob' && _adMob.bannerAdNotifier.value != null);

  @override
  Widget buildBannerAd({required BannerSize size, required int reloadToken}) {
    // If Unity banner is active, use Unity's banner widget.
    if (_bannerNetwork == 'unity' && _unity.bannerLoadedNotifier.value) {
      return _unity.buildBannerAd(size: size, reloadToken: reloadToken);
    }
    // Fallback to AdMob banner.
    final adMobBanner = _adMob.bannerAdNotifier.value;
    if (adMobBanner != null && _bannerNetwork == 'admob') {
      return AdWidget(ad: adMobBanner);
    }
    return const SizedBox.shrink();
  }

  /// Build the appropriate banner widget using the facade's state.
  /// Use this in LandingScreen instead of buildBannerAd when you need
  /// the facade's network-aware banner selection.
  Widget buildBannerWidget({
    required double width,
    required int unityReloadToken,
  }) {
    // Prefer Unity banner if loaded.
    if (_shouldUseUnity && _unity.bannerLoadedNotifier.value) {
      _bannerNetwork = 'unity';
      return _unity.buildBannerAd(
        size: _unity.bannerSizeNotifier.value,
        reloadToken: unityReloadToken,
      );
    }
    // Fallback to AdMob.
    final adMobBanner = _adMob.bannerAdNotifier.value;
    if (adMobBanner != null) {
      _bannerNetwork = 'admob';
      return AdWidget(ad: adMobBanner);
    }
    return const SizedBox.shrink();
  }

  void _onAdMobBannerChanged() {
    final ad = _adMob.bannerAdNotifier.value;
    if (ad != null && _bannerNetwork != 'unity') {
      _bannerNetwork = 'admob';
    }
    _adMobBannerNotifier.value = ad;
  }

  // ── WidgetsBindingObserver ────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Both services handle this individually via their own observer.
  }
}
