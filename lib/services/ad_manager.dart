import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

import '../config/app_runtime_config.dart';
import '../data/services/monetization_service.dart';
import 'ads_service_base.dart';
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

  void reset() {
    isLoading = false;
    failures = 0;
    lastLoadAttemptAt = null;
    lastLoadSuccessAt = null;
    lastLoadFailureAt = null;
    cancelRetry();
  }
}

class AdManager with WidgetsBindingObserver implements AdsServiceBase {
  static final AdManager instance = AdManager._();

  AdManager._({
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

  final _rewardedState = _AdLoadState('rewarded');
  final _interstitialState = _AdLoadState('interstitial');
  final _bannerState = _AdLoadState('banner');
  final List<Completer<bool>> _rewardedWaiters = <Completer<bool>>[];

  bool _rewardedReady = false;
  bool _interstitialReady = false;
  bool _bannerRequested = false;

  DateTime? _rewardedLoadedAt;
  DateTime? _interstitialLoadedAt;

  BannerSize _bannerSize = BannerSize.standard;
  int? _bannerWidth;

  final ValueNotifier<BannerSize> bannerSizeNotifier = ValueNotifier<BannerSize>(
    BannerSize.standard,
  );
  final ValueNotifier<bool> bannerLoadedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> bannerReloadNotifier = ValueNotifier<int>(0);

  bool _permanentlyDisabled = false;
  bool _isStarted = false;
  bool _isDisposed = false;
  bool _isAppActive = true;
  bool _fullScreenAdShowing = false;
  bool _isShowingAd = false;
  String? _showingAdType;
  int _showToken = 0;
  Timer? _showTimeoutTimer;

  bool _initialized = false;
  bool _initializing = false;
  DateTime? _lastInitAttemptAt;
  Completer<bool>? _initCompleter;

  Timer? _rewardedPreloadTimer;
  Timer? _interstitialPreloadTimer;
  Timer? _bannerPreloadTimer;
  Timer? _watchdogTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  bool get _canUseUnityAds =>
      AppRuntimeConfig.supportsMobileAds && AppRuntimeConfig.unityAdsEnabled;

  MonetizationService get monetization => _monetization;

  bool get bannerRequested => _bannerRequested;

  BannerSize get bannerSize => _bannerSize;

  String? get bannerPlacementId => AppRuntimeConfig.unityBannerPlacementId;

  /// Whether an interstitial ad is loaded and ready to display.
  bool get isInterstitialReady => _interstitialReady;

  /// Whether any ad is loaded and ready (used by AdsFacade).
  bool isReady() => _rewardedReady || _interstitialReady || bannerLoadedNotifier.value;

  /// Whether ads are suppressed because the user has an active subscription.
  Future<bool> get isPremiumUnlocked => _monetization.isPremiumUnlocked();

  Future<void> start() async {
    if (_isStarted || _isDisposed) {
      return;
    }

    _isStarted = true;
    _isAppActive = _currentLifecycleActive();
    WidgetsBinding.instance.addObserver(this);
    ConsentService.instance.canRequestAdsNotifier.addListener(_onConsentChanged);
    ConsentService.instance.consentFlowCompletedNotifier.addListener(
      _onConsentChanged,
    );
    _logConfigurationIssues();
    _listenConnectivity();
    _startWatchdog();
    await _ensureInitialized(reason: 'start');
    unawaited(preload());
  }

  void stop() {
    if (!_isStarted) {
      return;
    }
    _isStarted = false;
    WidgetsBinding.instance.removeObserver(this);
    ConsentService.instance.canRequestAdsNotifier.removeListener(_onConsentChanged);
    ConsentService.instance.consentFlowCompletedNotifier.removeListener(
      _onConsentChanged,
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
  }

  Future<void> preload() async {
    if (!_isStarted || _isDisposed) {
      return;
    }

    if (!_canUseUnityAds ||
        _permanentlyDisabled ||
        !AppRuntimeConfig.adsFeatureEnabled ||
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

    if (!ConsentService.instance.canRequestAds) {
      unawaited(ConsentService.instance.tryRefreshConsent());
      AdsDiagnostics.log('Preload deferred: consent not granted');
      return;
    }

    final initialized = await _ensureInitialized(reason: 'preload');
    if (!initialized) {
      AdsDiagnostics.log('Preload deferred: Unity Ads init pending');
      return;
    }

    unawaited(_applyPrivacyConsent());
    _scheduleStaggeredPreload(reason: 'preload');
  }

  // ---------------------------------------------------------------------------
  // Banner ad
  // ---------------------------------------------------------------------------

  /// Preloads a banner ad during startup. Provide width for size selection.
  Future<void> preloadBanner({double? width}) async {
    _bannerRequested = true;
    final sizeChanged = _updateBannerWidth(width);
    if ((sizeChanged || !bannerLoadedNotifier.value) &&
        !_bannerState.isLoading) {
      _requestBannerReload(reason: 'preload');
    }
  }

  /// Ensures the banner is loaded for a given width.
  Future<void> ensureBannerLoaded({
    required double width,
    String reason = 'ensure',
  }) async {
    _bannerRequested = true;
    final sizeChanged = _updateBannerWidth(width);
    if ((sizeChanged || !bannerLoadedNotifier.value) &&
        !_bannerState.isLoading) {
      _requestBannerReload(reason: reason);
    }
  }

  /// Loads a banner ad. Call once when the dashboard mounts.
  Future<void> loadBanner() async {
    _bannerRequested = true;
    if (!bannerLoadedNotifier.value && !_bannerState.isLoading) {
      _requestBannerReload(reason: 'explicit');
    }
  }

  /// Disposes the banner ad. Call when the dashboard unmounts.
  void disposeBanner() {
    _bannerRequested = false;
    _disposeBanner(reason: 'dashboard_closed');
  }

  // ---------------------------------------------------------------------------
  // Rewarded ad
  // ---------------------------------------------------------------------------

  Future<bool> showRewardedForRevive() async {
    if (_permanentlyDisabled) {
      AdsDiagnostics.log('Rewarded blocked: ads disabled');
      return false;
    }

    if (!_canUseUnityAds) {
      AdsDiagnostics.log('Rewarded blocked: Unity Ads unavailable');
      return false;
    }

    if (await isPremiumUnlocked) {
      AdsDiagnostics.log('Rewarded skipped: premium user');
      return true;
    }

    if (!AppRuntimeConfig.unityRewardedAdsEnabled) {
      AdsDiagnostics.log('Rewarded blocked by config');
      return false;
    }

    if (!ConsentService.instance.consentFlowCompleted) {
      AdsDiagnostics.log('Rewarded blocked: consent pending');
      return false;
    }

    if (!ConsentService.instance.canRequestAds) {
      await ConsentService.instance.tryRefreshConsent();
    }

    if (!ConsentService.instance.canRequestAds) {
      AdsDiagnostics.log('Rewarded blocked by consent');
      return false;
    }

    final initialized = await _ensureInitialized(reason: 'rewarded_show');
    if (!initialized) {
      AdsDiagnostics.log('Rewarded blocked: Unity Ads not initialized');
      return false;
    }

    if (!_tryBeginAdShow(
      'rewarded',
      placement: 'revive',
      timeout: AppRuntimeConfig.rewardedShowTimeout,
    )) {
      return false;
    }

    if (!_rewardedReady || _isExpired(_rewardedLoadedAt)) {
      _disposeRewarded(reason: 'missing_or_expired');
      unawaited(_loadRewarded(reason: 'revive_request', force: true));
      final loaded = await _waitForRewardedReady(
        timeout: AppRuntimeConfig.rewardedReviveAdWait,
      );
      if (!loaded || !_rewardedReady || _isExpired(_rewardedLoadedAt)) {
        AdsDiagnostics.log('Rewarded unavailable for revive after wait');
        unawaited(_loadRewarded(reason: 'revive_unavailable'));
        _forceEndAdShow(reason: 'no_fill');
        return false;
      }
    }

    _rewardedReady = false;
    _rewardedLoadedAt = null;

    final completer = Completer<bool>();
    await _waitForSafeFrame();
    UnityAds.showVideoAd(
      placementId: AppRuntimeConfig.unityRewardedPlacementId!,
      onStart: (placementId) {
        _fullScreenAdShowing = true;
        AdsDiagnostics.log('Rewarded shown', data: {'placement': placementId});
        AdsDiagnostics.event(
          'ad_shown',
          params: {'type': 'rewarded', 'placement': placementId},
        );
        unawaited(_loadRewarded(reason: 'showed'));
      },
      onClick: (placementId) {
        AdsDiagnostics.event(
          'ad_click',
          params: {'type': 'rewarded', 'placement': placementId},
        );
      },
      onSkipped: (placementId) {
        _fullScreenAdShowing = false;
        _forceEndAdShow(reason: 'skipped');
        unawaited(_loadRewarded(reason: 'skipped'));
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
      onComplete: (placementId) {
        _fullScreenAdShowing = false;
        _forceEndAdShow(reason: 'completed');
        AdsDiagnostics.event(
          'ad_reward',
          params: {'type': 'rewarded', 'placement': placementId},
        );
        unawaited(_loadRewarded(reason: 'completed'));
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      },
      onFailed: (placementId, error, message) {
        _fullScreenAdShowing = false;
        _forceEndAdShow(reason: 'show_failed');
        AdsDiagnostics.error(
          'Rewarded failed to show',
          error,
          data: {'placement': placementId, 'message': message},
        );
        unawaited(_loadRewarded(reason: 'show_failed'));
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
    );

    return completer.future.timeout(
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

  // ---------------------------------------------------------------------------
  // Interstitial ad
  // ---------------------------------------------------------------------------

  Future<bool> showInterstitialAfterGameOver() async {
    _placementPolicy.recordGameOver();
    if (!_canUseUnityAds ||
        _permanentlyDisabled ||
        await isPremiumUnlocked ||
        !AppRuntimeConfig.unityInterstitialAdsEnabled ||
        !ConsentService.instance.consentFlowCompleted ||
        !ConsentService.instance.canRequestAds ||
        !_placementPolicy.canShowInterstitial(_clock())) {
      return false;
    }

    final initialized = await _ensureInitialized(reason: 'interstitial_show');
    if (!initialized) {
      return false;
    }

    if (!_interstitialReady || _isExpired(_interstitialLoadedAt)) {
      _disposeInterstitial(reason: 'missing_or_expired');
      await _loadInterstitial(reason: 'game_over_request');
      return false;
    }

    if (!_tryBeginAdShow('interstitial', placement: 'game_over')) {
      return false;
    }

    final completer = Completer<bool>();
    await _waitForSafeFrame();
    UnityAds.showVideoAd(
      placementId: AppRuntimeConfig.unityInterstitialPlacementId!,
      onStart: (placementId) {
        _fullScreenAdShowing = true;
        _placementPolicy.recordInterstitialShown(_clock());
        AdsDiagnostics.event(
          'ad_shown',
          params: {'type': 'interstitial', 'placement': 'game_over'},
        );
      },
      onClick: (placementId) {
        AdsDiagnostics.event(
          'ad_click',
          params: {'type': 'interstitial', 'placement': 'game_over'},
        );
      },
      onSkipped: (placementId) {
        _fullScreenAdShowing = false;
        _forceEndAdShow(reason: 'skipped');
        _interstitialReady = false;
        _interstitialLoadedAt = null;
        unawaited(_loadInterstitial(reason: 'skipped'));
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      },
      onComplete: (placementId) {
        _fullScreenAdShowing = false;
        _forceEndAdShow(reason: 'completed');
        _interstitialReady = false;
        _interstitialLoadedAt = null;
        unawaited(_loadInterstitial(reason: 'completed'));
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      },
      onFailed: (placementId, error, message) {
        _fullScreenAdShowing = false;
        _forceEndAdShow(reason: 'show_failed');
        _interstitialReady = false;
        _interstitialLoadedAt = null;
        AdsDiagnostics.error(
          'Interstitial failed to show',
          error,
          data: {'placement': placementId, 'message': message},
        );
        unawaited(_loadInterstitial(reason: 'show_failed'));
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
    );

    return completer.future.timeout(
      AppRuntimeConfig.adsShowTimeout,
      onTimeout: () {
        AdsDiagnostics.event(
          'ad_show_timeout',
          params: {'type': 'interstitial', 'timeout': 1},
        );
        _forceEndAdShow(reason: 'timeout');
        return false;
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Stage-cleared interstitial
  // ---------------------------------------------------------------------------

  Future<void> showInterstitialAfterStageCleared(int clearedStage) async {
    if (!_canUseUnityAds ||
        _permanentlyDisabled ||
        await isPremiumUnlocked ||
        !AppRuntimeConfig.unityInterstitialAdsEnabled ||
        !ConsentService.instance.consentFlowCompleted ||
        !ConsentService.instance.canRequestAds) {
      AdsDiagnostics.log(
        'Stage interstitial skipped',
        data: {'reason': 'premium_or_consent'},
      );
      return;
    }

    if (!_placementPolicy.canShowInterstitialForStage(clearedStage, _clock())) {
      AdsDiagnostics.log(
        'Stage interstitial skipped',
        data: {'reason': 'cooldown', 'stage': clearedStage},
      );
      return;
    }

    final initialized = await _ensureInitialized(reason: 'stage_interstitial');
    if (!initialized) {
      return;
    }

    if (!_interstitialReady || _isExpired(_interstitialLoadedAt)) {
      AdsDiagnostics.log(
        'Stage interstitial not ready',
        data: {'stage': clearedStage},
      );
      _disposeInterstitial(reason: 'missing_or_expired');
      unawaited(_loadInterstitial(reason: 'stage_cleared_request'));
      return;
    }

    if (!_tryBeginAdShow('interstitial', placement: 'stage_clear')) {
      return;
    }

    await _waitForSafeFrame();
    UnityAds.showVideoAd(
      placementId: AppRuntimeConfig.unityInterstitialPlacementId!,
      onStart: (placementId) {
        _fullScreenAdShowing = true;
        _placementPolicy.recordStageClearedInterstitialShown(_clock());
        AdsDiagnostics.event(
          'ad_shown',
          params: {'type': 'interstitial', 'placement': 'stage_clear'},
        );
      },
      onClick: (placementId) {
        AdsDiagnostics.event(
          'ad_click',
          params: {'type': 'interstitial', 'placement': 'stage_clear'},
        );
      },
      onSkipped: (placementId) {
        _fullScreenAdShowing = false;
        _forceEndAdShow(reason: 'skipped');
        _interstitialReady = false;
        _interstitialLoadedAt = null;
        unawaited(_loadInterstitial(reason: 'skipped'));
      },
      onComplete: (placementId) {
        _fullScreenAdShowing = false;
        _forceEndAdShow(reason: 'completed');
        _interstitialReady = false;
        _interstitialLoadedAt = null;
        unawaited(_loadInterstitial(reason: 'completed'));
      },
      onFailed: (placementId, error, message) {
        _fullScreenAdShowing = false;
        _forceEndAdShow(reason: 'show_failed');
        _interstitialReady = false;
        _interstitialLoadedAt = null;
        AdsDiagnostics.error(
          'Stage interstitial failed',
          error,
          data: {'placement': placementId, 'message': message},
        );
        unawaited(_loadInterstitial(reason: 'show_failed'));
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

    await _ensureInitialized(reason: 'resume');
    unawaited(_applyPrivacyConsent());
    unawaited(preload());
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

    unawaited(_applyPrivacyConsent());
    unawaited(preload());
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

  Future<bool> _ensureInitialized({required String reason}) async {
    if (_isDisposed || !_canUseUnityAds) {
      return false;
    }

    if (_initialized) {
      return true;
    }

    final pending = _initCompleter;
    if (_initializing && pending != null) {
      return pending.future;
    }

    final now = _clock();
    if (_lastInitAttemptAt != null &&
        now.difference(_lastInitAttemptAt!) <
            AppRuntimeConfig.adsMinLoadInterval) {
      return false;
    }

    final gameId = AppRuntimeConfig.unityAdsGameId;
    if (gameId.isEmpty) {
      AdsDiagnostics.log('Unity Ads init skipped: game id missing');
      return false;
    }

    _initializing = true;
    _lastInitAttemptAt = now;
    final completer = Completer<bool>();
    _initCompleter = completer;

    AdsDiagnostics.log('Unity Ads init start', data: {'reason': reason});

    try {
      await UnityAds.init(
        gameId: gameId,
        testMode: AppRuntimeConfig.unityAdsTestMode,
        firebaseTestLabMode: _firebaseTestLabModeFromConfig(),
        onComplete: () {
          _initialized = true;
          AdsDiagnostics.log('Unity Ads initialized');
          if (!completer.isCompleted) {
            completer.complete(true);
          }
        },
        onFailed: (error, message) {
          _initialized = false;
          AdsDiagnostics.error(
            'Unity Ads init failed',
            error,
            data: {'message': message},
          );
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        },
      );
    } catch (error, stackTrace) {
      _initialized = false;
      AdsDiagnostics.error(
        'Unity Ads init exception',
        error,
        stackTrace: stackTrace,
      );
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    }

    final result = await completer.future.timeout(
      AppRuntimeConfig.adsLoadTimeout,
      onTimeout: () {
        AdsDiagnostics.log('Unity Ads init timeout');
        return false;
      },
    );

    _initializing = false;
    _initCompleter = null;
    if (result) {
      unawaited(_applyPrivacyConsent());
    }
    return result;
  }

  Future<void> _applyPrivacyConsent() async {
    if (!_initialized) {
      return;
    }
    final consent = ConsentService.instance.canRequestAds;
    try {
      await UnityAds.setPrivacyConsent(PrivacyConsentType.gdpr, consent);
      await UnityAds.setPrivacyConsent(PrivacyConsentType.ccpa, consent);
      await UnityAds.setPrivacyConsent(PrivacyConsentType.pipl, consent);
    } catch (error, stackTrace) {
      AdsDiagnostics.error(
        'Unity Ads privacy consent update failed',
        error,
        stackTrace: stackTrace,
      );
    }
  }

  FirebaseTestLabMode _firebaseTestLabModeFromConfig() {
    final raw = AppRuntimeConfig.unityAdsFirebaseTestLabMode;
    switch (raw) {
      case 'showads':
      case 'show_ads':
      case 'show-ads':
        return FirebaseTestLabMode.showAds;
      case 'showadsintestmode':
      case 'show_ads_in_test_mode':
      case 'show-ads-in-test-mode':
        return FirebaseTestLabMode.showAdsInTestMode;
      default:
        return FirebaseTestLabMode.disableAds;
    }
  }

  void _scheduleStaggeredPreload({
    required String reason,
    bool includeRewarded = true,
    bool includeInterstitial = true,
    bool includeBanner = true,
  }) {
    if (_isDisposed || !_isAppActive) {
      return;
    }
    AdsDiagnostics.log('Preload scheduled', data: {'reason': reason});
    if (includeRewarded && AppRuntimeConfig.unityRewardedAdsEnabled) {
      _scheduleRewardedPreload(reason);
    }
    if (includeInterstitial && AppRuntimeConfig.unityInterstitialAdsEnabled) {
      _scheduleInterstitialPreload(reason);
    }
    if (includeBanner && _bannerRequested && AppRuntimeConfig.unityBannerAdsEnabled) {
      _scheduleBannerPreload(reason);
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
    _bannerPreloadTimer = Timer(
      AppRuntimeConfig.adsPreloadBannerDelay,
      () {
        _bannerPreloadTimer = null;
        if (_isDisposed) {
          return;
        }
        _requestBannerReload(reason: reason);
      },
    );
  }

  void _cancelPreloadTimers() {
    _rewardedPreloadTimer?.cancel();
    _rewardedPreloadTimer = null;
    _interstitialPreloadTimer?.cancel();
    _interstitialPreloadTimer = null;
    _bannerPreloadTimer?.cancel();
    _bannerPreloadTimer = null;
  }

  Future<void> _loadRewarded({
    required String reason,
    bool force = false,
  }) async {
    if (!AppRuntimeConfig.unityRewardedAdsEnabled) {
      return;
    }

    if (!await _canLoadAd(_rewardedState, force: force)) {
      return;
    }

    final placementId = AppRuntimeConfig.unityRewardedPlacementId;
    if (placementId == null) {
      _logMissingPlacement('rewarded');
      return;
    }

    final loadToken = _rewardedState.startLoad();
    AdsDiagnostics.log('Rewarded load start', data: {'reason': reason});

    final timeout = Timer(AppRuntimeConfig.adsLoadTimeout, () {
      _handleLoadTimeout(
        _rewardedState,
        token: loadToken,
        adType: 'rewarded',
        onRetry: () => _loadRewarded(reason: 'timeout'),
      );
    });

    UnityAds.load(
      placementId: placementId,
      onComplete: (placementId) {
        timeout.cancel();
        if (!_rewardedState.isCurrent(loadToken)) {
          return;
        }
        _rewardedReady = true;
        _rewardedLoadedAt = _clock();
        _rewardedState.markSuccess();
        _completeRewardedWaiters(true);
        AdsDiagnostics.log('Rewarded loaded', data: {'placement': placementId});
        AdsDiagnostics.event('ad_loaded', params: {'type': 'rewarded'});
      },
      onFailed: (placementId, error, message) {
        timeout.cancel();
        if (!_rewardedState.isCurrent(loadToken)) {
          return;
        }
        _rewardedReady = false;
        _rewardedState.markFailure();
        _completeRewardedWaiters(false);
        AdsDiagnostics.error(
          'Rewarded load failed',
          error,
          data: {'placement': placementId, 'message': message},
        );
        _scheduleRetry(
          _rewardedState,
          adType: 'rewarded',
          onRetry: () => _loadRewarded(reason: 'load_failed'),
        );
      },
    );
  }

  Future<void> _loadInterstitial({required String reason}) async {
    if (!AppRuntimeConfig.unityInterstitialAdsEnabled) {
      return;
    }

    if (!await _canLoadAd(_interstitialState)) {
      return;
    }

    final placementId = AppRuntimeConfig.unityInterstitialPlacementId;
    if (placementId == null) {
      _logMissingPlacement('interstitial');
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

    UnityAds.load(
      placementId: placementId,
      onComplete: (placementId) {
        timeout.cancel();
        if (!_interstitialState.isCurrent(loadToken)) {
          return;
        }
        _interstitialReady = true;
        _interstitialLoadedAt = _clock();
        _interstitialState.markSuccess();
        AdsDiagnostics.log(
          'Interstitial loaded',
          data: {'placement': placementId},
        );
        AdsDiagnostics.event('ad_loaded', params: {'type': 'interstitial'});
      },
      onFailed: (placementId, error, message) {
        timeout.cancel();
        if (!_interstitialState.isCurrent(loadToken)) {
          return;
        }
        _interstitialReady = false;
        _interstitialState.markFailure();
        AdsDiagnostics.error(
          'Interstitial load failed',
          error,
          data: {'placement': placementId, 'message': message},
        );
        _scheduleRetry(
          _interstitialState,
          adType: 'interstitial',
          onRetry: () => _loadInterstitial(reason: 'load_failed'),
        );
      },
    );
  }

  void _requestBannerReload({required String reason}) {
    if (_isDisposed || !_isAppActive) {
      return;
    }

    if (!_bannerRequested || !AppRuntimeConfig.unityBannerAdsEnabled) {
      return;
    }

    if (_bannerState.isLoading) {
      return;
    }

    _bannerState.startLoad();
    bannerLoadedNotifier.value = false;
    bannerReloadNotifier.value = bannerReloadNotifier.value + 1;
    AdsDiagnostics.log(
      'Banner reload requested',
      data: {'reason': reason, 'token': bannerReloadNotifier.value},
    );
  }

  Widget buildBannerAd({required BannerSize size, required int reloadToken}) {
    final placementId = AppRuntimeConfig.unityBannerPlacementId;
    if (placementId == null) {
      return const SizedBox.shrink();
    }

    return UnityBannerAd(
      key: ValueKey('unity_banner_$reloadToken'),
      placementId: placementId,
      size: size,
      onLoad: (placementId) {
        _bannerState.markSuccess();
        bannerLoadedNotifier.value = true;
        AdsDiagnostics.log('Banner loaded', data: {'placement': placementId});
        AdsDiagnostics.event('ad_loaded', params: {'type': 'banner'});
      },
      onShown: (placementId) {
        AdsDiagnostics.event('ad_shown', params: {'type': 'banner'});
      },
      onClick: (placementId) {
        AdsDiagnostics.event('ad_click', params: {'type': 'banner'});
      },
      onFailed: (placementId, error, message) {
        bannerLoadedNotifier.value = false;
        _bannerState.markFailure();
        AdsDiagnostics.error(
          'Banner load failed',
          error,
          data: {'placement': placementId, 'message': message},
        );
        _scheduleRetry(
          _bannerState,
          adType: 'banner',
          onRetry: () => _requestBannerReload(reason: 'load_failed'),
        );
      },
    );
  }

  void _disposeRewarded({required String reason}) {
    if (_rewardedReady) {
      AdsDiagnostics.log('Rewarded disposed', data: {'reason': reason});
    }
    _rewardedReady = false;
    _rewardedLoadedAt = null;
    _rewardedState.reset();
    _completeRewardedWaiters(false);
  }

  void _disposeInterstitial({required String reason}) {
    if (_interstitialReady) {
      AdsDiagnostics.log('Interstitial disposed', data: {'reason': reason});
    }
    _interstitialReady = false;
    _interstitialLoadedAt = null;
    _interstitialState.reset();
  }

  void _disposeBanner({required String reason}) {
    if (bannerLoadedNotifier.value) {
      AdsDiagnostics.log('Banner disposed', data: {'reason': reason});
    }
    bannerLoadedNotifier.value = false;
    _bannerState.reset();
  }

  Future<bool> _canLoadAd(_AdLoadState state, {bool force = false}) async {
    if (_isDisposed || !_isAppActive) {
      return false;
    }
    if (!_canUseUnityAds || _permanentlyDisabled) {
      return false;
    }
    if (!AppRuntimeConfig.adsFeatureEnabled) {
      return false;
    }
    if (await isPremiumUnlocked) {
      return false;
    }
    if (!ConsentService.instance.consentFlowCompleted) {
      return false;
    }
    if (!ConsentService.instance.canRequestAds) {
      return false;
    }
    if (state.isLoading ||
        (!force && state.shouldThrottle(AppRuntimeConfig.adsMinLoadInterval))) {
      return false;
    }
    final initialized = await _ensureInitialized(reason: 'load_${state.label}');
    return initialized;
  }

  bool _tryBeginAdShow(
    String adType, {
    String? placement,
    Duration? timeout,
  }) {
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

    if (_isShowingAd || _fullScreenAdShowing) {
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
        data: {
          'type': adType,
          'timeoutMs': resolvedTimeout.inMilliseconds,
        },
      );
      _forceEndAdShow(reason: 'timeout');
    });

    AdsDiagnostics.log(
      'Ad show lock acquired',
      data: {
        'type': adType,
        if (placement != null) 'placement': placement,
      },
    );
    return true;
  }

  void _forceEndAdShow({required String reason}) {
    if (!_isShowingAd && !_fullScreenAdShowing) {
      return;
    }
    final type = _showingAdType ?? 'unknown';
    _isShowingAd = false;
    _showingAdType = null;
    _showTimeoutTimer?.cancel();
    _showTimeoutTimer = null;
    _fullScreenAdShowing = false;
    AdsDiagnostics.log(
      'Ad show lock released',
      data: {'type': type, 'reason': reason},
    );
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
      _completeRewardedWaiters(false);
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

  Future<bool> _waitForRewardedReady({required Duration timeout}) {
    if (_rewardedReady && !_isExpired(_rewardedLoadedAt)) {
      return Future<bool>.value(true);
    }

    final completer = Completer<bool>();
    _rewardedWaiters.add(completer);
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _rewardedWaiters.remove(completer);
        AdsDiagnostics.log('Rewarded wait timed out');
        return false;
      },
    );
  }

  void _completeRewardedWaiters(bool ready) {
    if (_rewardedWaiters.isEmpty) {
      return;
    }

    final waiters = List<Completer<bool>>.from(_rewardedWaiters);
    _rewardedWaiters.clear();
    for (final waiter in waiters) {
      if (!waiter.isCompleted) {
        waiter.complete(ready);
      }
    }
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
    if (_isDisposed || !_isAppActive || !_canUseUnityAds) {
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
        AppRuntimeConfig.unityRewardedAdsEnabled &&
        !_rewardedState.isLoading &&
        (!_rewardedReady || _isExpired(_rewardedLoadedAt));
    final needInterstitial =
        AppRuntimeConfig.unityInterstitialAdsEnabled &&
        !_interstitialState.isLoading &&
        (!_interstitialReady || _isExpired(_interstitialLoadedAt));
    final needBanner =
        _bannerRequested &&
        AppRuntimeConfig.unityBannerAdsEnabled &&
        !_bannerState.isLoading &&
        !bannerLoadedNotifier.value;

    if (needRewarded) {
      _disposeRewarded(reason: 'watchdog_expired');
    }
    if (needInterstitial) {
      _disposeInterstitial(reason: 'watchdog_expired');
    }
    if (needBanner) {
      _disposeBanner(reason: 'watchdog_expired');
    }

    if (needRewarded || needInterstitial || needBanner) {
      _scheduleStaggeredPreload(
        reason: 'watchdog',
        includeRewarded: needRewarded,
        includeInterstitial: needInterstitial,
        includeBanner: needBanner,
      );
    }
  }

  void _logMissingPlacement(String adType) {
    AdsDiagnostics.log('Unity placement id missing', data: {'type': adType});
    AdsDiagnostics.event('ads_config_issue', params: {'type': adType});
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
      'Unity ads runtime config',
      data: {
        'unityEnabled': AppRuntimeConfig.unityAdsEnabled,
        'rewardedEnabled': AppRuntimeConfig.unityRewardedAdsEnabled,
        'interstitialEnabled': AppRuntimeConfig.unityInterstitialAdsEnabled,
        'bannerEnabled': AppRuntimeConfig.unityBannerAdsEnabled,
        'testMode': AppRuntimeConfig.unityAdsTestMode,
      },
    );
  }

  bool _updateBannerWidth(double? width) {
    if (width == null || width <= 0) {
      return false;
    }
    final rounded = width.round();
    if (_bannerWidth != null && (rounded - _bannerWidth!).abs() < 8) {
      return false;
    }
    _bannerWidth = rounded;

    final size = _resolveBannerSize(rounded);
    if (_bannerSize.width == size.width && _bannerSize.height == size.height) {
      return false;
    }
    _bannerSize = size;
    bannerSizeNotifier.value = size;
    return true;
  }

  BannerSize _resolveBannerSize(int width) {
    if (width >= BannerSize.leaderboard.width) {
      return BannerSize.leaderboard;
    }
    if (width >= BannerSize.iabStandard.width) {
      return BannerSize.iabStandard;
    }
    return BannerSize.standard;
  }
}
