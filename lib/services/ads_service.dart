import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/app_runtime_config.dart';
import '../data/services/monetization_service.dart';
import 'ad_placement_policy.dart';
import 'ads_diagnostics.dart';
import 'consent_service.dart';

class _AdLoadState {
  _AdLoadState(this.label);

  final String label;
  int _loadToken = 0;
  bool isLoading = false;
  int failures = 0;
  DateTime? lastLoadAttemptAt;
  DateTime? lastLoadSuccessAt;
  DateTime? lastLoadFailureAt;
  Timer? retryTimer;

  int startLoad() {
    isLoading = true;
    lastLoadAttemptAt = DateTime.now();
    _loadToken += 1;
    return _loadToken;
  }

  bool isCurrent(int token) => token == _loadToken;

  void markSuccess() {
    isLoading = false;
    failures = 0;
    lastLoadSuccessAt = DateTime.now();
    retryTimer?.cancel();
    retryTimer = null;
  }

  void markFailure() {
    isLoading = false;
    failures += 1;
    lastLoadFailureAt = DateTime.now();
  }

  bool shouldThrottle(Duration minInterval) {
    if (lastLoadAttemptAt == null) {
      return false;
    }
    return DateTime.now().difference(lastLoadAttemptAt!) < minInterval;
  }

  void cancelRetry() {
    retryTimer?.cancel();
    retryTimer = null;
  }
}

class AdsService with WidgetsBindingObserver {
  static final AdsService instance = AdsService();

  AdsService({
    AdPlacementPolicy? placementPolicy,
    DateTime Function()? clock,
    MonetizationService? monetization,
  }) : _placementPolicy =
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
       _clock = clock ?? DateTime.now,
       _monetization = monetization ?? const FlutterMonetizationService();

  final AdPlacementPolicy _placementPolicy;
  final DateTime Function() _clock;
  final MonetizationService _monetization;
  final Random _random = Random();

  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;
  BannerAd? _bannerAd;
  AppOpenAd? _appOpenAd;

  final ValueNotifier<BannerAd?> bannerAdNotifier = ValueNotifier<BannerAd?>(
    null,
  );
  final ValueNotifier<AdSize?> bannerSizeNotifier = ValueNotifier<AdSize?>(
    null,
  );

  AdSize? _bannerSize;
  int? _bannerWidth;

  DateTime? _rewardedLoadedAt;
  DateTime? _interstitialLoadedAt;
  DateTime? _bannerLoadedAt;
  DateTime? _appOpenLoadedAt;

  final _rewardedState = _AdLoadState('rewarded');
  final _interstitialState = _AdLoadState('interstitial');
  final _bannerState = _AdLoadState('banner');
  final _appOpenState = _AdLoadState('app_open');
  final List<Completer<RewardedAd?>> _rewardedWaiters =
      <Completer<RewardedAd?>>[];

  bool _bannerRequested = false;
  bool _permanentlyDisabled = false;
  bool _isStarted = false;
  bool _isDisposed = false;
  bool _isAppActive = true;
  bool _appOpenShowing = false;
  bool _fullScreenAdShowing = false;
  bool _isShowingAd = false;
  String? _showingAdType;
  int _showToken = 0;
  Timer? _showTimeoutTimer;
  DateTime? _lastAppOpenShownAt;
  DateTime? _lastResumeAt;
  DateTime? _suppressAppOpenUntil;

  Timer? _rewardedPreloadTimer;
  Timer? _interstitialPreloadTimer;
  Timer? _bannerPreloadTimer;
  Timer? _appOpenPreloadTimer;
  Timer? _watchdogTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  bool get _canUseMobileAds => AppRuntimeConfig.supportsMobileAds;

  MonetizationService get monetization => _monetization;

  /// Whether ads are suppressed because the user has an active subscription.
  Future<bool> get isPremiumUnlocked => _monetization.isPremiumUnlocked();

  Future<void> start() async {
    if (_isStarted || _isDisposed) {
      return;
    }

    _isStarted = true;
    _isAppActive = _currentLifecycleActive();
    _suppressAppOpenUntil = _clock().add(
      AppRuntimeConfig.appOpenColdStartDelay,
    );
    WidgetsBinding.instance.addObserver(this);
    ConsentService.instance.canRequestAdsNotifier.addListener(
      _onConsentChanged,
    );
    ConsentService.instance.adsInitializedNotifier.addListener(
      _onAdsInitializedChanged,
    );
    _logConfigurationIssues();
    await _applyRequestConfiguration();
    _startWatchdog();
    _listenConnectivity();
    unawaited(preload());
  }

  void stop() {
    if (!_isStarted) {
      return;
    }
    _isStarted = false;
    WidgetsBinding.instance.removeObserver(this);
    ConsentService.instance.canRequestAdsNotifier.removeListener(
      _onConsentChanged,
    );
    ConsentService.instance.adsInitializedNotifier.removeListener(
      _onAdsInitializedChanged,
    );
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _stopWatchdog();
    _cancelPreloadTimers();
    _forceEndAdShow(reason: 'service_stopped');
  }

  void disableAdsPermanently() {
    _permanentlyDisabled = true;
    disposeAllAds();
  }

  void disposeAllAds({String reason = 'dispose'}) {
    _disposeRewarded(reason: reason);
    _disposeInterstitial(reason: reason);
    _disposeBanner(reason: reason);
    _disposeAppOpen(reason: reason);
  }

  Future<void> preload() async {
    if (!_isStarted || _isDisposed) {
      return;
    }

    if (!_canUseMobileAds ||
        _permanentlyDisabled ||
        !AppRuntimeConfig.admobAdsEnabled ||
        !_isAppActive) {
      return;
    }

    if (await isPremiumUnlocked) {
      return;
    }

    if (!ConsentService.instance.consentFlowCompleted) {
      AdsDiagnostics.log('Preload skipped: consent pending');
      return;
    }

    if (!ConsentService.instance.canRequestAds ||
        !ConsentService.instance.adsInitialized) {
      unawaited(ConsentService.instance.tryRefreshConsent());
      AdsDiagnostics.log('Preload deferred: consent or SDK not ready');
      return;
    }

    unawaited(_applyRequestConfiguration());
    _scheduleStaggeredPreload(reason: 'preload');
  }

  // ---------------------------------------------------------------------------
  // Banner ad
  // ---------------------------------------------------------------------------

  /// The currently loaded banner ad, or null if not yet ready.
  BannerAd? get bannerAd => _canUseMobileAds ? _bannerAd : null;

  /// Preloads a banner ad during startup. Provide width for adaptive size.
  Future<void> preloadBanner({double? width}) async {
    _bannerRequested = true;
    _updateBannerWidth(width);
    await _loadBanner(reason: 'preload');
  }

  /// Ensures the banner is loaded for a given width (adaptive banner).
  Future<void> ensureBannerLoaded({
    required double width,
    String reason = 'ensure',
  }) async {
    _bannerRequested = true;
    _updateBannerWidth(width);
    await _loadBanner(reason: reason);
  }

  /// Loads a banner ad. Call once when the dashboard mounts.
  Future<void> loadBanner() async {
    _bannerRequested = true;
    await _loadBanner(reason: 'explicit');
  }

  /// Disposes the banner ad. Call when the dashboard unmounts.
  void disposeBanner() {
    _bannerRequested = false;
    _disposeBanner(reason: 'dashboard_closed');
  }

  Future<bool> showRewardedForRevive() async {
    if (_permanentlyDisabled) {
      AdsDiagnostics.log('Rewarded blocked: ads disabled');
      return false;
    }

    if (!_canUseMobileAds) {
      AdsDiagnostics.log('Rewarded blocked: mobile ads unavailable');
      return false;
    }

    if (await isPremiumUnlocked) {
      AdsDiagnostics.log('Rewarded skipped: premium user');
      return true;
    }

    if (!AppRuntimeConfig.rewardedAdsEnabled) {
      AdsDiagnostics.log('Rewarded blocked by config or consent');
      return false;
    }

    if (!ConsentService.instance.consentFlowCompleted) {
      AdsDiagnostics.log('Rewarded blocked: consent pending');
      return false;
    }

    if (!ConsentService.instance.canRequestAds) {
      await ConsentService.instance.tryRefreshConsent();
    }
    if (ConsentService.instance.canRequestAds &&
        !ConsentService.instance.adsInitialized) {
      await ConsentService.instance.tryRefreshConsent();
    }

    if (!ConsentService.instance.canRequestAds ||
        !ConsentService.instance.adsInitialized) {
      AdsDiagnostics.log('Rewarded blocked by consent or SDK init');
      return false;
    }

    if (!_tryBeginAdShow(
      'rewarded',
      placement: 'revive',
      timeout: AppRuntimeConfig.rewardedShowTimeout,
    )) {
      return false;
    }

    var ad = _rewardedAd;
    if (ad == null || _isExpired(_rewardedLoadedAt)) {
      _disposeRewarded(reason: 'missing_or_expired');
      unawaited(_loadRewarded(reason: 'revive_request', force: true));
      ad = await _waitForRewardedAd(
        timeout: AppRuntimeConfig.rewardedReviveAdWait,
      );
    }

    if (ad == null || _rewardedAd != ad || _isExpired(_rewardedLoadedAt)) {
      AdsDiagnostics.log('Rewarded unavailable for revive after wait');
      unawaited(_loadRewarded(reason: 'revive_unavailable'));
      _forceEndAdShow(reason: 'no_fill');
      return false;
    }

    final RewardedAd adToShow = ad;
    _rewardedAd = null;
    _rewardedLoadedAt = null;

    final c = Completer<bool>();
    var earnedReward = false;
    adToShow.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        _fullScreenAdShowing = true;
        AdsDiagnostics.log('Rewarded shown');
        AdsDiagnostics.event('ad_shown', params: {'type': 'rewarded'});
        unawaited(_loadRewarded(reason: 'showed'));
      },
      onAdImpression: (_) {
        AdsDiagnostics.event('ad_impression', params: {'type': 'rewarded'});
      },
      onAdClicked: (_) {
        _suppressAppOpenAfterAdClick('rewarded');
        AdsDiagnostics.event('ad_click', params: {'type': 'rewarded'});
      },
      onAdDismissedFullScreenContent: (ad) {
        _fullScreenAdShowing = false;
        ad.dispose();
        _forceEndAdShow(reason: 'dismissed');
        unawaited(_loadRewarded(reason: 'dismissed'));
        if (!c.isCompleted) {
          c.complete(earnedReward);
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _fullScreenAdShowing = false;
        AdsDiagnostics.error('Rewarded failed to show', error);
        ad.dispose();
        _forceEndAdShow(reason: 'show_failed');
        unawaited(_loadRewarded(reason: 'show_failed'));
        if (!c.isCompleted) {
          c.complete(false);
        }
      },
    );

    try {
      await _showAdSafely(() {
        return adToShow.show(
          onUserEarnedReward: (_, reward) {
            earnedReward = true;
            AdsDiagnostics.event(
              'ad_reward',
              params: {
                'type': 'rewarded',
                'rewardType': reward.type,
                'rewardAmount': reward.amount,
              },
            );
          },
        );
      });
    } catch (error, stackTrace) {
      _fullScreenAdShowing = false;
      _forceEndAdShow(reason: 'show_exception');
      AdsDiagnostics.error(
        'Rewarded show call failed',
        error,
        stackTrace: stackTrace,
      );
      await adToShow.dispose();
      unawaited(_loadRewarded(reason: 'show_exception'));
      if (!c.isCompleted) {
        c.complete(false);
      }
    }

    return c.future.timeout(
      AppRuntimeConfig.rewardedShowTimeout,
      onTimeout: () {
        AdsDiagnostics.event(
          'ad_show_timeout',
          params: {'type': 'rewarded', 'timeout': 1},
        );
        _forceEndAdShow(reason: 'timeout');
        return false;
      },
    );
  }

  Future<bool> showInterstitialAfterGameOver() async {
    _placementPolicy.recordGameOver();
    if (!_canUseMobileAds ||
        _permanentlyDisabled ||
        await isPremiumUnlocked ||
        !AppRuntimeConfig.interstitialAdsEnabled ||
        !ConsentService.instance.consentFlowCompleted ||
        !ConsentService.instance.canRequestAds ||
        !_placementPolicy.canShowInterstitial(_clock())) {
      return false;
    }

    final ad = _interstitialAd;
    if (ad == null || _isExpired(_interstitialLoadedAt)) {
      _disposeInterstitial(reason: 'missing_or_expired');
      await _loadInterstitial(reason: 'game_over_request');
      return false;
    }

    if (!_tryBeginAdShow('interstitial', placement: 'game_over')) {
      return false;
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        _fullScreenAdShowing = true;
        AdsDiagnostics.event('ad_shown', params: {'type': 'interstitial'});
      },
      onAdImpression: (_) {
        AdsDiagnostics.event('ad_impression', params: {'type': 'interstitial'});
      },
      onAdClicked: (_) {
        _suppressAppOpenAfterAdClick('interstitial');
        AdsDiagnostics.event('ad_click', params: {'type': 'interstitial'});
      },
      onAdDismissedFullScreenContent: (ad) {
        _fullScreenAdShowing = false;
        ad.dispose();
        _interstitialAd = null;
        _forceEndAdShow(reason: 'dismissed');
        unawaited(_loadInterstitial(reason: 'dismissed'));
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _fullScreenAdShowing = false;
        AdsDiagnostics.error('Interstitial failed to show', error);
        ad.dispose();
        _interstitialAd = null;
        _forceEndAdShow(reason: 'show_failed');
        unawaited(_loadInterstitial(reason: 'show_failed'));
      },
    );

    _attachPaidEvent(ad, 'interstitial', placement: 'game_over');

    _placementPolicy.recordInterstitialShown(_clock());
    try {
      await _showAdSafely(() => ad.show());
    } catch (error, stackTrace) {
      _fullScreenAdShowing = false;
      _forceEndAdShow(reason: 'show_exception');
      AdsDiagnostics.error(
        'Interstitial show call failed',
        error,
        stackTrace: stackTrace,
      );
      ad.dispose();
      _interstitialAd = null;
      unawaited(_loadInterstitial(reason: 'show_exception'));
      return false;
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Stage-cleared interstitial
  // ---------------------------------------------------------------------------

  /// True when an interstitial ad is loaded and ready to display.
  bool get isInterstitialReady => _canUseMobileAds && _interstitialAd != null;

  /// Call this immediately after a stage completion screen is shown.
  Future<bool> showInterstitialAfterStageCleared(int clearedStage) async {
    if (!_canUseMobileAds ||
        _permanentlyDisabled ||
        await isPremiumUnlocked ||
        !AppRuntimeConfig.interstitialAdsEnabled ||
        !ConsentService.instance.consentFlowCompleted ||
        !ConsentService.instance.canRequestAds) {
      AdsDiagnostics.log(
        'Stage interstitial skipped',
        data: {'reason': 'premium_or_consent'},
      );
      return false;
    }

    if (!_placementPolicy.canShowInterstitialForStage(clearedStage, _clock())) {
      AdsDiagnostics.log(
        'Stage interstitial skipped',
        data: {'reason': 'cooldown', 'stage': clearedStage},
      );
      return false;
    }

    final ad = _interstitialAd;
    if (ad == null || _isExpired(_interstitialLoadedAt)) {
      AdsDiagnostics.log(
        'Stage interstitial not ready',
        data: {'stage': clearedStage},
      );
      _disposeInterstitial(reason: 'missing_or_expired');
      unawaited(_loadInterstitial(reason: 'stage_cleared_request'));
      return false;
    }

    if (!_tryBeginAdShow('interstitial', placement: 'stage_clear')) {
      return false;
    }

    _placementPolicy.recordStageClearedInterstitialShown(_clock());

    final completer = Completer<bool>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        _fullScreenAdShowing = true;
        AdsDiagnostics.log(
          'Stage interstitial shown',
          data: {'stage': clearedStage},
        );
        AdsDiagnostics.event(
          'ad_shown',
          params: {'type': 'interstitial', 'placement': 'stage_clear'},
        );
      },
      onAdImpression: (_) {
        AdsDiagnostics.event(
          'ad_impression',
          params: {'type': 'interstitial', 'placement': 'stage_clear'},
        );
      },
      onAdClicked: (_) {
        _suppressAppOpenAfterAdClick('stage_interstitial');
        AdsDiagnostics.event(
          'ad_click',
          params: {'type': 'interstitial', 'placement': 'stage_clear'},
        );
      },
      onAdDismissedFullScreenContent: (ad) {
        _fullScreenAdShowing = false;
        ad.dispose();
        _interstitialAd = null;
        _forceEndAdShow(reason: 'dismissed');
        AdsDiagnostics.log('Stage interstitial dismissed');
        unawaited(_loadInterstitial(reason: 'dismissed'));
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _fullScreenAdShowing = false;
        AdsDiagnostics.error('Stage interstitial failed', error);
        ad.dispose();
        _interstitialAd = null;
        _forceEndAdShow(reason: 'show_failed');
        unawaited(_loadInterstitial(reason: 'show_failed'));
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
    );

    _attachPaidEvent(ad, 'interstitial', placement: 'stage_clear');

    try {
      await _showAdSafely(() => ad.show());
    } catch (error, stackTrace) {
      _fullScreenAdShowing = false;
      _forceEndAdShow(reason: 'show_exception');
      AdsDiagnostics.error(
        'Stage interstitial show call failed',
        error,
        stackTrace: stackTrace,
      );
      ad.dispose();
      _interstitialAd = null;
      unawaited(_loadInterstitial(reason: 'show_exception'));
      if (!completer.isCompleted) {
        completer.complete(false);
      }
      return false;
    }
    return completer.future.timeout(
      AppRuntimeConfig.adsShowTimeout,
      onTimeout: () {
        AdsDiagnostics.event(
          'ad_show_timeout',
          params: {'type': 'interstitial', 'placement': 'stage_clear'},
        );
        _forceEndAdShow(reason: 'timeout');
        return false;
      },
    );
  }

  void dispose() {
    _isDisposed = true;
    stop();
    _cancelPreloadTimers();
    _forceEndAdShow(reason: 'dispose');
    disposeAllAds();
  }

  // ---------------------------------------------------------------------------
  // WidgetsBindingObserver
  // ---------------------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) {
      return;
    }

    AdsDiagnostics.log('Lifecycle change', data: {'state': state.name});

    switch (state) {
      case AppLifecycleState.resumed:
        _isAppActive = true;
        _lastResumeAt = _clock();
        unawaited(_handleAppResumed());
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _isAppActive = false;
        _handleAppPaused();
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  bool _currentLifecycleActive() {
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == null) {
      return true;
    }
    return state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
  }

  Future<void> _handleAppResumed() async {
    if (_isDisposed) {
      return;
    }

    AdsDiagnostics.log('App resumed');

    final delay = AppRuntimeConfig.adsResumeDelay;
    if (delay.inMilliseconds > 0) {
      await Future<void>.delayed(delay);
    }

    if (!_isAppActive) {
      return;
    }

    if (!ConsentService.instance.consentFlowCompleted) {
      AdsDiagnostics.log('Resume skipped: consent flow active');
      return;
    }

    await ConsentService.instance.tryRefreshConsent();
    if (!_isAppActive) {
      return;
    }
    unawaited(_applyRequestConfiguration());
    unawaited(preload());
    await _showAppOpenIfAvailable(reason: 'resume');
  }

  void _handleAppPaused() {
    AdsDiagnostics.log('App paused; ads idle');
  }

  void _onConsentChanged() {
    if (_isDisposed) {
      return;
    }
    if (!ConsentService.instance.canRequestAds) {
      _forceEndAdShow(reason: 'consent_revoked');
      disposeAllAds(reason: 'consent_revoked');
      return;
    }
    unawaited(preload());
  }

  void _onAdsInitializedChanged() {
    if (_isDisposed) {
      return;
    }
    if (ConsentService.instance.adsInitialized &&
        ConsentService.instance.canRequestAds) {
      unawaited(preload());
    }
  }

  void _listenConnectivity() {
    if (_connectivitySub != null) {
      return;
    }

    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      (results) {
        final hasConnection =
            results.isNotEmpty && !results.contains(ConnectivityResult.none);

        if (!hasConnection) {
          AdsDiagnostics.log('Connectivity lost');
          return;
        }

        AdsDiagnostics.log(
          'Connectivity restored',
          data: {'types': results.map((e) => e.name).join(',')},
        );

        unawaited(_handleConnectivityRestored());
      },
      onError: (error) {
        AdsDiagnostics.error('Connectivity listener error', error);
      },
    );
  }

  Future<void> _handleConnectivityRestored() async {
    if (!_isAppActive) {
      return;
    }
    if (!ConsentService.instance.consentFlowCompleted) {
      return;
    }
    await ConsentService.instance.tryRefreshConsent();
    unawaited(preload());
  }

  void _scheduleStaggeredPreload({
    required String reason,
    bool includeRewarded = true,
    bool includeInterstitial = true,
    bool includeBanner = true,
    bool includeAppOpen = true,
  }) {
    if (_isDisposed || !_isAppActive) {
      return;
    }
    AdsDiagnostics.log('Preload scheduled', data: {'reason': reason});
    if (includeRewarded && AppRuntimeConfig.rewardedAdsEnabled) {
      _scheduleRewardedPreload(reason);
    }
    if (includeInterstitial && AppRuntimeConfig.interstitialAdsEnabled) {
      _scheduleInterstitialPreload(reason);
    }
    if (includeBanner &&
        _bannerRequested &&
        AppRuntimeConfig.bannerAdsEnabled) {
      _scheduleBannerPreload(reason);
    }
    if (includeAppOpen && AppRuntimeConfig.appOpenAdsEnabled) {
      _scheduleAppOpenPreload(reason);
    }
  }

  void _scheduleRewardedPreload(String reason) {
    if (_rewardedPreloadTimer != null) {
      return;
    }
    _rewardedPreloadTimer = Timer(Duration.zero, () {
      _rewardedPreloadTimer = null;
      if (_isDisposed) {
        return;
      }
      unawaited(_loadRewarded(reason: reason));
    });
  }

  void _scheduleInterstitialPreload(String reason) {
    if (_interstitialPreloadTimer != null) {
      return;
    }
    _interstitialPreloadTimer = Timer(
      AppRuntimeConfig.adsPreloadInterstitialDelay,
      () {
        _interstitialPreloadTimer = null;
        if (_isDisposed) {
          return;
        }
        unawaited(_loadInterstitial(reason: reason));
      },
    );
  }

  void _scheduleBannerPreload(String reason) {
    if (_bannerPreloadTimer != null) {
      return;
    }
    _bannerPreloadTimer = Timer(AppRuntimeConfig.adsPreloadBannerDelay, () {
      _bannerPreloadTimer = null;
      if (_isDisposed) {
        return;
      }
      unawaited(_loadBanner(reason: reason));
    });
  }

  void _scheduleAppOpenPreload(String reason) {
    if (_appOpenPreloadTimer != null) {
      return;
    }
    _appOpenPreloadTimer = Timer(AppRuntimeConfig.adsPreloadAppOpenDelay, () {
      _appOpenPreloadTimer = null;
      if (_isDisposed) {
        return;
      }
      unawaited(_loadAppOpen(reason: reason));
    });
  }

  void _cancelPreloadTimers() {
    _rewardedPreloadTimer?.cancel();
    _rewardedPreloadTimer = null;
    _interstitialPreloadTimer?.cancel();
    _interstitialPreloadTimer = null;
    _bannerPreloadTimer?.cancel();
    _bannerPreloadTimer = null;
    _appOpenPreloadTimer?.cancel();
    _appOpenPreloadTimer = null;
  }

  Future<void> _loadRewarded({
    required String reason,
    bool force = false,
  }) async {
    if (!await _canLoadAd(_rewardedState, force: force)) {
      return;
    }

    final adUnitId = AppRuntimeConfig.rewardedAdUnitId;
    if (adUnitId == null) {
      _logMissingAdUnit('rewarded');
      return;
    }

    final loadToken = _rewardedState.startLoad();
    AdsDiagnostics.log('Rewarded load start', data: {'reason': reason});

    final timeout = Timer(
      force
          ? AppRuntimeConfig.rewardedReviveAdWait
          : AppRuntimeConfig.adsLoadTimeout,
      () {
        _handleLoadTimeout(
          _rewardedState,
          token: loadToken,
          adType: 'rewarded',
          onRetry: () => _loadRewarded(reason: 'timeout'),
        );
      },
    );

    RewardedAd.load(
      adUnitId: adUnitId,
      request: _buildAdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          timeout.cancel();
          if (!_rewardedState.isCurrent(loadToken)) {
            ad.dispose();
            return;
          }
          _rewardedAd?.dispose();
          _rewardedAd = ad;
          _rewardedLoadedAt = _clock();
          _rewardedState.markSuccess();
          _attachPaidEvent(ad, 'rewarded');
          _completeRewardedWaiters(ad);
          AdsDiagnostics.log('Rewarded loaded');
          AdsDiagnostics.event('ad_loaded', params: {'type': 'rewarded'});
        },
        onAdFailedToLoad: (error) {
          timeout.cancel();
          if (!_rewardedState.isCurrent(loadToken)) {
            return;
          }
          _rewardedAd = null;
          _rewardedState.markFailure();
          _completeRewardedWaiters(null);
          AdsDiagnostics.error('Rewarded load failed', error);
          _scheduleRetry(
            _rewardedState,
            adType: 'rewarded',
            onRetry: () => _loadRewarded(reason: 'load_failed'),
          );
        },
      ),
    );
  }

  Future<void> _loadInterstitial({required String reason}) async {
    if (!await _canLoadAd(_interstitialState)) {
      return;
    }

    final adUnitId = AppRuntimeConfig.interstitialAdUnitId;
    if (adUnitId == null) {
      _logMissingAdUnit('interstitial');
      return;
    }

    final loadToken = _interstitialState.startLoad();
    AdsDiagnostics.log('Interstitial load start', data: {'reason': reason});

    final timeout = Timer(AppRuntimeConfig.adsLoadTimeout, () {
      _handleLoadTimeout(
        _interstitialState,
        token: loadToken,
        adType: 'interstitial',
        onRetry: () => _loadInterstitial(reason: 'timeout'),
      );
    });

    InterstitialAd.load(
      adUnitId: adUnitId,
      request: _buildAdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          timeout.cancel();
          if (!_interstitialState.isCurrent(loadToken)) {
            ad.dispose();
            return;
          }
          _interstitialAd?.dispose();
          _interstitialAd = ad;
          _interstitialLoadedAt = _clock();
          _interstitialState.markSuccess();
          _attachPaidEvent(ad, 'interstitial');
          AdsDiagnostics.log('Interstitial loaded');
          AdsDiagnostics.event('ad_loaded', params: {'type': 'interstitial'});
        },
        onAdFailedToLoad: (error) {
          timeout.cancel();
          if (!_interstitialState.isCurrent(loadToken)) {
            return;
          }
          _interstitialAd = null;
          _interstitialState.markFailure();
          AdsDiagnostics.error('Interstitial load failed', error);
          _scheduleRetry(
            _interstitialState,
            adType: 'interstitial',
            onRetry: () => _loadInterstitial(reason: 'load_failed'),
          );
        },
      ),
    );
  }

  Future<void> _loadBanner({required String reason}) async {
    if (!await _canLoadAd(_bannerState)) {
      return;
    }

    if (!_bannerRequested || !AppRuntimeConfig.bannerAdsEnabled) {
      return;
    }

    final adUnitId = AppRuntimeConfig.bannerAdUnitId;
    if (adUnitId == null) {
      _logMissingAdUnit('banner');
      return;
    }

    final size = await _resolveBannerSize();
    if (_bannerAd != null &&
        !_isExpired(_bannerLoadedAt) &&
        _sameAdSize(_bannerSize, size)) {
      return;
    }

    final loadToken = _bannerState.startLoad();
    AdsDiagnostics.log('Banner load start', data: {'reason': reason});

    final timeout = Timer(AppRuntimeConfig.adsLoadTimeout, () {
      _handleLoadTimeout(
        _bannerState,
        token: loadToken,
        adType: 'banner',
        onRetry: () => _loadBanner(reason: 'timeout'),
      );
    });

    final oldAd = _bannerAd;
    _setBannerAd(null);
    _setBannerSize(null);
    _disposeBannerInstance(oldAd);

    final bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: size,
      request: _buildAdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          timeout.cancel();
          if (!_bannerState.isCurrent(loadToken)) {
            ad.dispose();
            return;
          }
          _setBannerAd(ad as BannerAd);
          _setBannerSize(size);
          _bannerLoadedAt = _clock();
          _bannerState.markSuccess();
          AdsDiagnostics.log('Banner loaded');
          AdsDiagnostics.event('ad_loaded', params: {'type': 'banner'});
        },
        onAdFailedToLoad: (ad, error) {
          timeout.cancel();
          if (!_bannerState.isCurrent(loadToken)) {
            ad.dispose();
            return;
          }
          _bannerAd = null;
          ad.dispose();
          _bannerState.markFailure();
          AdsDiagnostics.error('Banner load failed', error);
          _scheduleRetry(
            _bannerState,
            adType: 'banner',
            onRetry: () => _loadBanner(reason: 'load_failed'),
          );
        },
        onAdImpression: (_) {
          AdsDiagnostics.event('ad_impression', params: {'type': 'banner'});
        },
        onAdClicked: (_) {
          _suppressAppOpenAfterAdClick('banner');
          AdsDiagnostics.event('ad_click', params: {'type': 'banner'});
        },
        onAdOpened: (_) {
          _fullScreenAdShowing = true;
          AdsDiagnostics.event('ad_opened', params: {'type': 'banner'});
        },
        onAdClosed: (_) {
          _fullScreenAdShowing = false;
          AdsDiagnostics.event('ad_closed', params: {'type': 'banner'});
        },
        onPaidEvent: _paidEventCallback('banner'),
      ),
    );

    await bannerAd.load();
  }

  Future<void> _loadAppOpen({required String reason}) async {
    if (!AppRuntimeConfig.appOpenAdsEnabled) {
      return;
    }

    if (!await _canLoadAd(_appOpenState)) {
      return;
    }

    final adUnitId = AppRuntimeConfig.appOpenAdUnitId;
    if (adUnitId == null) {
      _logMissingAdUnit('app_open');
      return;
    }

    final loadToken = _appOpenState.startLoad();
    AdsDiagnostics.log('AppOpen load start', data: {'reason': reason});

    final timeout = Timer(AppRuntimeConfig.adsLoadTimeout, () {
      _handleLoadTimeout(
        _appOpenState,
        token: loadToken,
        adType: 'app_open',
        onRetry: () => _loadAppOpen(reason: 'timeout'),
      );
    });

    AppOpenAd.load(
      adUnitId: adUnitId,
      request: _buildAdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          timeout.cancel();
          if (!_appOpenState.isCurrent(loadToken)) {
            ad.dispose();
            return;
          }
          _appOpenAd?.dispose();
          _appOpenAd = ad;
          _appOpenLoadedAt = _clock();
          _appOpenState.markSuccess();
          _attachPaidEvent(ad, 'app_open');
          AdsDiagnostics.log('AppOpen loaded');
          AdsDiagnostics.event('ad_loaded', params: {'type': 'app_open'});
        },
        onAdFailedToLoad: (error) {
          timeout.cancel();
          if (!_appOpenState.isCurrent(loadToken)) {
            return;
          }
          _appOpenAd = null;
          _appOpenState.markFailure();
          AdsDiagnostics.error('AppOpen load failed', error);
          _scheduleRetry(
            _appOpenState,
            adType: 'app_open',
            onRetry: () => _loadAppOpen(reason: 'load_failed'),
          );
        },
      ),
    );
  }

  Future<void> _showAppOpenIfAvailable({required String reason}) async {
    if (!AppRuntimeConfig.appOpenAdsEnabled ||
        _appOpenShowing ||
        _fullScreenAdShowing ||
        _isShowingAd ||
        !_isAppActive) {
      return;
    }

    if (await isPremiumUnlocked) {
      return;
    }

    if (!ConsentService.instance.consentFlowCompleted) {
      return;
    }

    if (!ConsentService.instance.canRequestAds) {
      return;
    }

    if (!ConsentService.instance.adsInitialized) {
      return;
    }

    final lastShown = _lastAppOpenShownAt;
    if (lastShown != null &&
        _clock().difference(lastShown) < AppRuntimeConfig.appOpenCooldown) {
      return;
    }

    final lastResume = _lastResumeAt;
    if (lastResume != null &&
        _clock().difference(lastResume) < AppRuntimeConfig.adsResumeDelay) {
      return;
    }

    final suppressUntil = _suppressAppOpenUntil;
    if (suppressUntil != null && _clock().isBefore(suppressUntil)) {
      return;
    }

    final ad = _appOpenAd;
    if (ad == null || _isExpired(_appOpenLoadedAt)) {
      _disposeAppOpen(reason: 'missing_or_expired');
      unawaited(_loadAppOpen(reason: 'resume_request'));
      return;
    }

    if (!_tryBeginAdShow('app_open', placement: reason)) {
      return;
    }

    _appOpenShowing = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        _fullScreenAdShowing = true;
        AdsDiagnostics.log('AppOpen shown', data: {'reason': reason});
        AdsDiagnostics.event('ad_shown', params: {'type': 'app_open'});
      },
      onAdImpression: (_) {
        AdsDiagnostics.event('ad_impression', params: {'type': 'app_open'});
      },
      onAdClicked: (_) {
        _suppressAppOpenAfterAdClick('app_open');
        AdsDiagnostics.event('ad_click', params: {'type': 'app_open'});
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _appOpenAd = null;
        _appOpenShowing = false;
        _fullScreenAdShowing = false;
        _lastAppOpenShownAt = _clock();
        _forceEndAdShow(reason: 'dismissed');
        unawaited(_loadAppOpen(reason: 'dismissed'));
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        AdsDiagnostics.error('AppOpen failed to show', error);
        ad.dispose();
        _appOpenAd = null;
        _appOpenShowing = false;
        _fullScreenAdShowing = false;
        _lastAppOpenShownAt = _clock();
        _forceEndAdShow(reason: 'show_failed');
        unawaited(_loadAppOpen(reason: 'show_failed'));
      },
    );

    _attachPaidEvent(ad, 'app_open', placement: reason);

    try {
      await _showAdSafely(() => ad.show());
    } catch (error, stackTrace) {
      AdsDiagnostics.error(
        'AppOpen show call failed',
        error,
        stackTrace: stackTrace,
      );
      _forceEndAdShow(reason: 'show_exception');
      await ad.dispose();
      _appOpenAd = null;
      _appOpenShowing = false;
      _fullScreenAdShowing = false;
      _lastAppOpenShownAt = _clock();
      unawaited(_loadAppOpen(reason: 'show_exception'));
    }
  }

  void _disposeRewarded({required String reason}) {
    if (_rewardedAd != null) {
      AdsDiagnostics.log('Rewarded disposed', data: {'reason': reason});
    }
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _rewardedLoadedAt = null;
    _rewardedState.cancelRetry();
    _completeRewardedWaiters(null);
  }

  void _disposeInterstitial({required String reason}) {
    if (_interstitialAd != null) {
      AdsDiagnostics.log('Interstitial disposed', data: {'reason': reason});
    }
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _interstitialLoadedAt = null;
    _interstitialState.cancelRetry();
  }

  void _disposeBanner({required String reason}) {
    if (_bannerAd != null) {
      AdsDiagnostics.log('Banner disposed', data: {'reason': reason});
    }
    final oldAd = _bannerAd;
    _setBannerAd(null);
    _setBannerSize(null);
    _disposeBannerInstance(oldAd);
    _bannerLoadedAt = null;
    _bannerState.cancelRetry();
  }

  void _disposeAppOpen({required String reason}) {
    if (_appOpenAd != null) {
      AdsDiagnostics.log('AppOpen disposed', data: {'reason': reason});
    }
    _appOpenAd?.dispose();
    _appOpenAd = null;
    _appOpenLoadedAt = null;
    _appOpenState.cancelRetry();
  }

  Future<bool> _canLoadAd(_AdLoadState state, {bool force = false}) async {
    if (_isDisposed || !_isAppActive) {
      return false;
    }
    if (!_canUseMobileAds || _permanentlyDisabled) {
      return false;
    }
    if (!AppRuntimeConfig.admobAdsEnabled) {
      return false;
    }
    if (await isPremiumUnlocked) {
      return false;
    }
    if (!ConsentService.instance.consentFlowCompleted) {
      return false;
    }
    if (!ConsentService.instance.canRequestAds ||
        !ConsentService.instance.adsInitialized) {
      return false;
    }
    if (state.isLoading ||
        (!force && state.shouldThrottle(AppRuntimeConfig.adsMinLoadInterval))) {
      return false;
    }
    return true;
  }

  bool _tryBeginAdShow(String adType, {String? placement, Duration? timeout}) {
    if (_isDisposed || !_isAppActive) {
      AdsDiagnostics.log(
        'Ad show blocked',
        data: {'type': adType, 'reason': 'inactive'},
      );
      return false;
    }

    if (!ConsentService.instance.consentFlowCompleted) {
      AdsDiagnostics.log(
        'Ad show blocked',
        data: {'type': adType, 'reason': 'consent_pending'},
      );
      return false;
    }

    if (_isShowingAd || _fullScreenAdShowing || _appOpenShowing) {
      AdsDiagnostics.log(
        'Ad show blocked',
        data: {
          'type': adType,
          'reason': 'already_showing',
          'active': _showingAdType ?? 'unknown',
        },
      );
      return false;
    }

    _isShowingAd = true;
    _showingAdType = adType;
    _showToken += 1;
    final token = _showToken;
    final resolvedTimeout = timeout ?? AppRuntimeConfig.adsShowTimeout;
    _showTimeoutTimer?.cancel();
    _showTimeoutTimer = Timer(resolvedTimeout, () {
      if (!_isShowingAd || _showToken != token) {
        return;
      }
      AdsDiagnostics.log(
        'Ad show timeout',
        data: {'type': adType, 'timeoutMs': resolvedTimeout.inMilliseconds},
      );
      _forceEndAdShow(reason: 'timeout');
    });

    final logData = <String, Object>{'type': adType};
    if (placement != null) {
      logData['placement'] = placement;
    }
    AdsDiagnostics.log('Ad show lock acquired', data: logData);
    return true;
  }

  void _forceEndAdShow({required String reason}) {
    if (!_isShowingAd && !_fullScreenAdShowing && !_appOpenShowing) {
      return;
    }
    final type = _showingAdType ?? 'unknown';
    _isShowingAd = false;
    _showingAdType = null;
    _showTimeoutTimer?.cancel();
    _showTimeoutTimer = null;
    _fullScreenAdShowing = false;
    _appOpenShowing = false;
    AdsDiagnostics.log(
      'Ad show lock released',
      data: {'type': type, 'reason': reason},
    );
  }

  Future<void> _showAdSafely(Future<void> Function() showCall) async {
    await _waitForSafeFrame();
    await showCall();
  }

  Future<void> _waitForSafeFrame() async {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      return;
    }
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    await completer.future;
  }

  void _handleLoadTimeout(
    _AdLoadState state, {
    required int token,
    required String adType,
    required VoidCallback onRetry,
  }) {
    if (!state.isCurrent(token)) {
      return;
    }
    state.markFailure();
    if (identical(state, _rewardedState)) {
      _completeRewardedWaiters(null);
    }
    AdsDiagnostics.log('Ad load timeout', data: {'type': adType});
    _scheduleRetry(state, adType: adType, onRetry: onRetry);
  }

  void _scheduleRetry(
    _AdLoadState state, {
    required String adType,
    required VoidCallback onRetry,
  }) {
    if (_isDisposed || !_isAppActive) {
      return;
    }
    if (state.retryTimer != null) {
      return;
    }
    final delay = _nextRetryDelay(state.failures);
    AdsDiagnostics.log(
      'Ad retry scheduled',
      data: {'type': adType, 'delayMs': delay.inMilliseconds},
    );
    state.retryTimer = Timer(delay, () {
      state.retryTimer = null;
      onRetry();
    });
  }

  Duration _nextRetryDelay(int failures) {
    const schedule = <Duration>[
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
      Duration(seconds: 15),
      Duration(seconds: 30),
      Duration(seconds: 60),
    ];
    final index = failures <= 0
        ? 0
        : (failures - 1).clamp(0, schedule.length - 1);
    final base = schedule[index];
    final jitterMs = _random.nextInt(400) - 200;
    final duration = base + Duration(milliseconds: jitterMs);
    return duration.isNegative ? base : duration;
  }

  bool _isExpired(DateTime? loadedAt) {
    if (loadedAt == null) {
      return true;
    }
    return _clock().difference(loadedAt) > AppRuntimeConfig.adsMaxAdAge;
  }

  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(
      AppRuntimeConfig.adsWatchdogInterval,
      (_) => unawaited(_watchdogTick()),
    );
  }

  void _stopWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
  }

  Future<void> _watchdogTick() async {
    if (_isDisposed || !_isAppActive || !_canUseMobileAds) {
      return;
    }

    if (_permanentlyDisabled || await isPremiumUnlocked) {
      return;
    }

    if (!ConsentService.instance.canRequestAds) {
      await ConsentService.instance.tryRefreshConsent();
    }

    if (!ConsentService.instance.canRequestAds) {
      return;
    }

    final needRewarded =
        AppRuntimeConfig.rewardedAdsEnabled &&
        !_rewardedState.isLoading &&
        (_rewardedAd == null || _isExpired(_rewardedLoadedAt));
    final needInterstitial =
        AppRuntimeConfig.interstitialAdsEnabled &&
        !_interstitialState.isLoading &&
        (_interstitialAd == null || _isExpired(_interstitialLoadedAt));
    final needBanner =
        _bannerRequested &&
        AppRuntimeConfig.bannerAdsEnabled &&
        !_bannerState.isLoading &&
        (_bannerAd == null || _isExpired(_bannerLoadedAt));
    final needAppOpen =
        AppRuntimeConfig.appOpenAdsEnabled &&
        !_appOpenState.isLoading &&
        (_appOpenAd == null || _isExpired(_appOpenLoadedAt));

    if (needRewarded) {
      _disposeRewarded(reason: 'watchdog_expired');
    }
    if (needInterstitial) {
      _disposeInterstitial(reason: 'watchdog_expired');
    }
    if (needBanner) {
      _disposeBanner(reason: 'watchdog_expired');
    }
    if (needAppOpen) {
      _disposeAppOpen(reason: 'watchdog_expired');
    }

    if (needRewarded || needInterstitial || needBanner || needAppOpen) {
      _scheduleStaggeredPreload(
        reason: 'watchdog',
        includeRewarded: needRewarded,
        includeInterstitial: needInterstitial,
        includeBanner: needBanner,
        includeAppOpen: needAppOpen,
      );
    }
  }

  Future<void> _applyRequestConfiguration() async {
    if (!_canUseMobileAds) {
      return;
    }
    final testDeviceIds = AppRuntimeConfig.adTestDeviceIds;
    try {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          maxAdContentRating: AppRuntimeConfig.adsMaxAdContentRating,
          tagForChildDirectedTreatment:
              AppRuntimeConfig.adsTagForChildDirectedTreatment,
          tagForUnderAgeOfConsent: AppRuntimeConfig.adsTagForUnderAgeOfConsent,
          testDeviceIds: testDeviceIds.isEmpty ? null : testDeviceIds,
        ),
      );
      AdsDiagnostics.log(
        'Request configuration updated',
        data: {
          'testDevices': testDeviceIds.length,
          'maxContentRating':
              AppRuntimeConfig.adsMaxAdContentRating ?? 'unspecified',
          'childDirected': AppRuntimeConfig.adsTagForChildDirectedTreatment,
          'underAge': AppRuntimeConfig.adsTagForUnderAgeOfConsent,
        },
      );
    } catch (error, stackTrace) {
      AdsDiagnostics.error(
        'Request configuration failed',
        error,
        stackTrace: stackTrace,
      );
    }
  }

  void _logConfigurationIssues() {
    final issues = AppRuntimeConfig.adsConfigurationIssues();
    if (issues.isNotEmpty) {
      AdsDiagnostics.log(
        'Ads configuration issues',
        data: {'issues': issues.join(' | ')},
      );
      AdsDiagnostics.event(
        'ads_config_issue',
        params: {'count': issues.length},
      );
    }

    AdsDiagnostics.log(
      'Ads runtime config',
      data: {
        'releaseLike': AppRuntimeConfig.useReleaseAdIds,
        'adsEnabled': AppRuntimeConfig.adsEnabled,
        'admobEnabled': AppRuntimeConfig.admobAdsEnabled,
        'bannerEnabled': AppRuntimeConfig.bannerAdsEnabled,
        'interstitialEnabled': AppRuntimeConfig.interstitialAdsEnabled,
        'rewardedEnabled': AppRuntimeConfig.rewardedAdsEnabled,
        'appOpenEnabled': AppRuntimeConfig.appOpenAdsEnabled,
      },
    );
  }

  void _logMissingAdUnit(String adType) {
    AdsDiagnostics.log('Ad unit id missing', data: {'type': adType});
    AdsDiagnostics.event('ads_config_issue', params: {'type': adType});
  }

  AdRequest _buildAdRequest() {
    return AdRequest(
      httpTimeoutMillis: AppRuntimeConfig.adRequestHttpTimeoutMillis,
      nonPersonalizedAds: AppRuntimeConfig.adsForceNonPersonalized
          ? true
          : null,
    );
  }

  void _attachPaidEvent(AdWithoutView ad, String adType, {String? placement}) {
    ad.onPaidEvent = _paidEventCallback(adType, placement: placement);
  }

  OnPaidEventCallback _paidEventCallback(String adType, {String? placement}) {
    return (ad, valueMicros, precision, currencyCode) {
      final params = <String, Object>{
        'type': adType,
        'valueMicros': valueMicros,
        'precision': precision.toString(),
        'currency': currencyCode,
      };
      if (placement != null) {
        params['placement'] = placement;
      }
      AdsDiagnostics.event('ad_paid', params: params);
    };
  }

  Future<RewardedAd?> _waitForRewardedAd({required Duration timeout}) {
    final ad = _rewardedAd;
    if (ad != null && !_isExpired(_rewardedLoadedAt)) {
      return Future<RewardedAd?>.value(ad);
    }

    final completer = Completer<RewardedAd?>();
    _rewardedWaiters.add(completer);
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _rewardedWaiters.remove(completer);
        AdsDiagnostics.log('Rewarded wait timed out');
        return null;
      },
    );
  }

  void _completeRewardedWaiters(RewardedAd? ad) {
    if (_rewardedWaiters.isEmpty) {
      return;
    }

    final waiters = List<Completer<RewardedAd?>>.from(_rewardedWaiters);
    _rewardedWaiters.clear();
    for (final waiter in waiters) {
      if (!waiter.isCompleted) {
        waiter.complete(ad);
      }
    }
  }

  void _suppressAppOpenAfterAdClick(String adType) {
    _suppressAppOpenUntil = _clock().add(
      AppRuntimeConfig.appOpenSuppressAfterAdClick,
    );
    AdsDiagnostics.log(
      'AppOpen suppressed after ad click',
      data: {'type': adType, 'until': _suppressAppOpenUntil?.toIso8601String()},
    );
  }

  void _setBannerAd(BannerAd? ad) {
    _bannerAd = ad;
    bannerAdNotifier.value = ad;
  }

  void _setBannerSize(AdSize? size) {
    _bannerSize = size;
    bannerSizeNotifier.value = size;
  }

  void _disposeBannerInstance(BannerAd? ad) {
    if (ad == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ad.dispose();
    });
  }

  void _updateBannerWidth(double? width) {
    if (width == null || width <= 0) {
      return;
    }
    final rounded = width.round();
    if (_bannerWidth != null && (rounded - _bannerWidth!).abs() < 8) {
      return;
    }
    _bannerWidth = rounded;
  }

  Future<AdSize> _resolveBannerSize() async {
    final width = _bannerWidth;
    if (width == null || width <= 0) {
      return AdSize.banner;
    }
    try {
      final adaptive =
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
      return adaptive ?? AdSize.banner;
    } catch (error, stackTrace) {
      AdsDiagnostics.error(
        'Adaptive banner size failed',
        error,
        stackTrace: stackTrace,
      );
      return AdSize.banner;
    }
  }

  bool _sameAdSize(AdSize? a, AdSize? b) {
    if (a == null || b == null) {
      return false;
    }
    return a.width == b.width && a.height == b.height;
  }
}
