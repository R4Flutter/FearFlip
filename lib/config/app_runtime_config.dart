import 'package:flutter/foundation.dart';

class AppRuntimeConfig {
  static const String privacyPolicyUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: 'https://fearflipgame.com/privacy',
  );
  static const String termsUrl = String.fromEnvironment(
    'TERMS_URL',
    defaultValue: 'https://fearflipgame.com/terms',
  );
  static const String accountDeletionUrl = String.fromEnvironment(
    'ACCOUNT_DELETION_URL',
    defaultValue: 'https://fearflipgame.com/account-deletion',
  );
  static const bool adsFeatureEnabled = bool.fromEnvironment(
    'ADS_ENABLED',
    defaultValue: true,
  );
  static const bool rewardedReviveFeatureEnabled = bool.fromEnvironment(
    'REWARDED_REVIVE_ENABLED',
    defaultValue: true,
  );
  static const bool interstitialFeatureEnabled = bool.fromEnvironment(
    'INTERSTITIALS_ENABLED',
    defaultValue: true,
  );
  static const bool bannerFeatureEnabled = bool.fromEnvironment(
    'BANNER_ADS_ENABLED',
    defaultValue: true,
  );
  static const bool removeAdsUiEnabled = bool.fromEnvironment(
    'REMOVE_ADS_UI_ENABLED',
    defaultValue: true, // Play Store requires a remove-ads path to be visible.
  );
  static const bool appOpenFeatureEnabled = bool.fromEnvironment(
    'APP_OPEN_ADS_ENABLED',
    defaultValue: true,
  );
  static const int rewardedReviveAdWaitSeconds = int.fromEnvironment(
    'REWARDED_REVIVE_AD_WAIT_SECONDS',
    defaultValue: 10,
  );
  static const int adsRequestHttpTimeoutMillis = int.fromEnvironment(
    'ADS_REQUEST_HTTP_TIMEOUT_MILLIS',
    defaultValue: 10000,
  );
  static const bool adsForceNonPersonalized = bool.fromEnvironment(
    'ADS_FORCE_NON_PERSONALIZED',
    defaultValue: false,
  );
  static const bool adsVerboseLogging = bool.fromEnvironment(
    'ADS_VERBOSE_LOGGING',
    defaultValue: false,
  );
  static const bool adsAnalyticsLogging = bool.fromEnvironment(
    'ADS_ANALYTICS_LOGGING',
    defaultValue: true,
  );
  static const bool adsUseReleaseIdsInProfile = bool.fromEnvironment(
    'ADS_USE_RELEASE_IDS_IN_PROFILE',
    defaultValue: false,
  );
  static const int adsLoadTimeoutSeconds = int.fromEnvironment(
    'ADS_LOAD_TIMEOUT_SECONDS',
    defaultValue: 8,
  );
  static const int adsShowTimeoutSeconds = int.fromEnvironment(
    'ADS_SHOW_TIMEOUT_SECONDS',
    defaultValue: 90,
  );
  static const int rewardedShowTimeoutSeconds = int.fromEnvironment(
    'REWARDED_SHOW_TIMEOUT_SECONDS',
    defaultValue: 180,
  );
  static const int adsWatchdogIntervalSeconds = int.fromEnvironment(
    'ADS_WATCHDOG_INTERVAL_SECONDS',
    defaultValue: 30,
  );
  static const int adsMaxAdAgeMinutes = int.fromEnvironment(
    'ADS_MAX_AD_AGE_MINUTES',
    defaultValue: 50,
  );
  static const int adsMinLoadIntervalSeconds = int.fromEnvironment(
    'ADS_MIN_LOAD_INTERVAL_SECONDS',
    defaultValue: 2,
  );
  static const int adsRetryBaseSeconds = int.fromEnvironment(
    'ADS_RETRY_BASE_SECONDS',
    defaultValue: 2,
  );
  static const int adsRetryMaxSeconds = int.fromEnvironment(
    'ADS_RETRY_MAX_SECONDS',
    defaultValue: 60,
  );
  static const int adsPreloadInterstitialDelayMs = int.fromEnvironment(
    'ADS_PRELOAD_INTERSTITIAL_DELAY_MS',
    defaultValue: 0,
  );
  static const int adsPreloadBannerDelayMs = int.fromEnvironment(
    'ADS_PRELOAD_BANNER_DELAY_MS',
    defaultValue: 0,
  );
  static const int adsPreloadAppOpenDelayMs = int.fromEnvironment(
    'ADS_PRELOAD_APP_OPEN_DELAY_MS',
    defaultValue: 0,
  );
  static const int adsResumeDelayMs = int.fromEnvironment(
    'ADS_RESUME_DELAY_MS',
    defaultValue: 200,
  );
  static const int appOpenCooldownSeconds = int.fromEnvironment(
    'APP_OPEN_COOLDOWN_SECONDS',
    defaultValue: 90,
  );
  static const int appOpenColdStartDelaySeconds = int.fromEnvironment(
    'APP_OPEN_COLD_START_DELAY_SECONDS',
    defaultValue: 10,
  );
  static const int appOpenSuppressAfterAdClickSeconds = int.fromEnvironment(
    'APP_OPEN_SUPPRESS_AFTER_AD_CLICK_SECONDS',
    defaultValue: 180,
  );
  static const int interstitialCooldownSeconds = int.fromEnvironment(
    'INTERSTITIAL_COOLDOWN_SECONDS',
    defaultValue: 120,
  );
  static const int interstitialMinGameOvers = int.fromEnvironment(
    'INTERSTITIAL_MIN_GAME_OVERS',
    defaultValue: 2,
  );
  static const int stageClearedInterstitialInterval = int.fromEnvironment(
    'STAGE_INTERSTITIAL_INTERVAL',
    defaultValue: 3,
  );
  static const int stageClearedInterstitialCooldownSeconds =
      int.fromEnvironment(
        'STAGE_INTERSTITIAL_COOLDOWN_SECONDS',
        defaultValue: 30,
      );

  // ---------------------------------------------------------------------------
  // Revive-life limits per checkpoint band
  // ---------------------------------------------------------------------------

  /// Max ad-revives for stages 26–50 (checkpoint at stage 25). Default: 5.
  static const int reviveLimitBand25to50 = int.fromEnvironment(
    'REVIVE_LIMIT_BAND_25_50',
    defaultValue: 5,
  );

  /// Max ad-revives for stages 51–75 (checkpoint at stage 50). Default: 3.
  static const int reviveLimitBand50to75 = int.fromEnvironment(
    'REVIVE_LIMIT_BAND_50_75',
    defaultValue: 3,
  );

  /// Max ad-revives for stages 76–100 (checkpoint at stage 75). Default: 2.
  static const int reviveLimitBand75to100 = int.fromEnvironment(
    'REVIVE_LIMIT_BAND_75_100',
    defaultValue: 2,
  );
  static const bool glitchEffectsEnabled = bool.fromEnvironment(
    'GLITCH_EFFECTS_ENABLED',
    defaultValue: true,
  );
  static const bool _forceStageOneTestTrap = bool.fromEnvironment(
    'FORCE_STAGE1_TEST_TRAP',
    defaultValue: false,
  );
  static const bool _debugStageDropdown = bool.fromEnvironment(
    'DEBUG_STAGE_DROPDOWN',
    defaultValue:
        false, // disabled by default; enable via dart-define for QA only
  );

  /// When true, [LeaderboardNextLevelScreen] uses a real-time Firestore
  /// [Stream] instead of a one-shot [Future]. Disable if Firestore stream
  /// costs are a concern; the [Future] path still refreshes on pull-to-refresh.
  static const bool leaderboardRealtimeEnabled = bool.fromEnvironment(
    'LEADERBOARD_REALTIME_ENABLED',
    defaultValue: true,
  );

  // ---------------------------------------------------------------------------
  // Unity Ads configuration
  // ---------------------------------------------------------------------------

  static const bool unityAdsFeatureEnabled = bool.fromEnvironment(
    'UNITY_ADS_ENABLED',
    defaultValue: true,
  );
  static const bool unityRewardedFeatureEnabled = bool.fromEnvironment(
    'UNITY_REWARDED_ENABLED',
    defaultValue: true,
  );
  static const bool unityInterstitialFeatureEnabled = bool.fromEnvironment(
    'UNITY_INTERSTITIAL_ENABLED',
    defaultValue: true,
  );
  static const bool unityBannerFeatureEnabled = bool.fromEnvironment(
    'UNITY_BANNER_ENABLED',
    defaultValue: true,
  );
  static const bool unityAdsTestModeOverride = bool.fromEnvironment(
    'UNITY_ADS_TEST_MODE',
    defaultValue: false,
  );
  static const String _unityAdsFirebaseTestLabModeRaw = String.fromEnvironment(
    'UNITY_ADS_FIREBASE_TEST_LAB_MODE',
    defaultValue: '',
  );
  static const String _unityAdsGameIdAndroid = String.fromEnvironment(
    'UNITY_ADS_GAME_ID_ANDROID',
    defaultValue: '800001612',
  );
  static const String _unityAdsGameIdIos = String.fromEnvironment(
    'UNITY_ADS_GAME_ID_IOS',
    defaultValue: '',
  );
  static const String _unityRewardedPlacementIdAndroid = String.fromEnvironment(
    'UNITY_ADS_REWARDED_PLACEMENT_ID_ANDROID',
    defaultValue: 'Rewarded_Android',
  );
  static const String _unityRewardedPlacementIdIos = String.fromEnvironment(
    'UNITY_ADS_REWARDED_PLACEMENT_ID_IOS',
    defaultValue: '',
  );
  static const String _unityInterstitialPlacementIdAndroid =
      String.fromEnvironment(
        'UNITY_ADS_INTERSTITIAL_PLACEMENT_ID_ANDROID',
        defaultValue: 'Interstitial_Android',
      );
  static const String _unityInterstitialPlacementIdIos = String.fromEnvironment(
    'UNITY_ADS_INTERSTITIAL_PLACEMENT_ID_IOS',
    defaultValue: '',
  );
  static const String _unityBannerPlacementIdAndroid = String.fromEnvironment(
    'UNITY_ADS_BANNER_PLACEMENT_ID_ANDROID',
    defaultValue: 'Banner_Android',
  );
  static const String _unityBannerPlacementIdIos = String.fromEnvironment(
    'UNITY_ADS_BANNER_PLACEMENT_ID_IOS',
    defaultValue: '',
  );

  static const String _googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '158165984868-bvqagc5kubdo3cmpkr3ccrhufd2ksl6i.apps.googleusercontent.com',
  );
  static const String _googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '',
  );
  static const String _releaseRewardedAdUnitId = String.fromEnvironment(
    'ADMOB_REWARDED_AD_UNIT_ID',
    defaultValue: 'ca-app-pub-5463912491137261/7771282021',
  );
  static const String _releaseAndroidRewardedAdUnitId = String.fromEnvironment(
    'ADMOB_ANDROID_REWARDED_AD_UNIT_ID',
    defaultValue: '',
  );
  static const String _releaseIosRewardedAdUnitId = String.fromEnvironment(
    'ADMOB_IOS_REWARDED_AD_UNIT_ID',
    defaultValue: '',
  );
  static const String _releaseInterstitialAdUnitId = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_AD_UNIT_ID',
    defaultValue: 'ca-app-pub-5463912491137261/7639420085',
  );
  static const String _releaseAndroidInterstitialAdUnitId =
      String.fromEnvironment(
        'ADMOB_ANDROID_INTERSTITIAL_AD_UNIT_ID',
        defaultValue: '',
      );
  static const String _releaseIosInterstitialAdUnitId = String.fromEnvironment(
    'ADMOB_IOS_INTERSTITIAL_AD_UNIT_ID',
    defaultValue: '',
  );
  static const String _releaseBannerAdUnitId = String.fromEnvironment(
    'ADMOB_BANNER_AD_UNIT_ID',
    defaultValue: 'ca-app-pub-5463912491137261/3640465329',
  );
  static const String _releaseAndroidBannerAdUnitId = String.fromEnvironment(
    'ADMOB_ANDROID_BANNER_AD_UNIT_ID',
    defaultValue: '',
  );
  static const String _releaseIosBannerAdUnitId = String.fromEnvironment(
    'ADMOB_IOS_BANNER_AD_UNIT_ID',
    defaultValue: '',
  );
  static const String _releaseAppOpenAdUnitId = String.fromEnvironment(
    'ADMOB_APP_OPEN_AD_UNIT_ID',
    defaultValue: 'ca-app-pub-5463912491137261/4708523466',
  );
  static const String _releaseAndroidAppOpenAdUnitId = String.fromEnvironment(
    'ADMOB_ANDROID_APP_OPEN_AD_UNIT_ID',
    defaultValue: '',
  );
  static const String _releaseIosAppOpenAdUnitId = String.fromEnvironment(
    'ADMOB_IOS_APP_OPEN_AD_UNIT_ID',
    defaultValue: '',
  );
  static const String _adTestDeviceIdsRaw = String.fromEnvironment(
    'ADMOB_TEST_DEVICE_IDS',
    defaultValue: '',
  );
  static const String _adsMaxContentRatingRaw = String.fromEnvironment(
    'ADS_MAX_CONTENT_RATING',
    defaultValue: 'T',
  );
  static const String _adsTagChildDirectedRaw = String.fromEnvironment(
    'ADS_TAG_CHILD_DIRECTED',
    defaultValue: 'false',
  );
  static const String _adsTagUnderAgeOfConsentRaw = String.fromEnvironment(
    'ADS_TAG_UNDER_AGE_OF_CONSENT',
    defaultValue: '',
  );
  static const String _adsConsentDebugGeographyRaw = String.fromEnvironment(
    'ADS_CONSENT_DEBUG_GEOGRAPHY',
    defaultValue: '',
  );

  /// Google Play product ID for the "Remove Ads" one-time non-consumable IAP.
  ///
  /// Set at build time:
  /// ```
  /// flutter run --dart-define=REMOVE_ADS_PRODUCT_ID=com.example.fearflip.remove_ads
  /// ```
  static const String removeAdsProductId = String.fromEnvironment(
    'REMOVE_ADS_PRODUCT_ID',
    defaultValue: 'remove_ads_prod_android',
  );

  /// App Store product ID for the "Remove Ads" non-consumable (iOS/macOS).
  ///
  /// Defaults to the same value as [removeAdsProductId] when not supplied
  /// (many developers use the same SKU on both stores).
  static const String _removeAdsIosProductIdRaw = String.fromEnvironment(
    'REMOVE_ADS_IOS_ID',
    defaultValue: '',
  );

  /// Resolves the iOS product ID: uses [_removeAdsIosProductIdRaw] if set,
  /// otherwise falls back to [removeAdsProductId].
  static String get removeAdsIosProductId =>
      _removeAdsIosProductIdRaw.trim().isNotEmpty
      ? _removeAdsIosProductIdRaw.trim()
      : removeAdsProductId;

  static const String _androidRewardedTestId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _iosRewardedTestId =
      'ca-app-pub-3940256099942544/1712485313';
  static const String _androidInterstitialTestId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _iosInterstitialTestId =
      'ca-app-pub-3940256099942544/4411468910';
  static const String _androidBannerTestId =
      'ca-app-pub-3940256099942544/9214589741';
  static const String _iosBannerTestId =
      'ca-app-pub-3940256099942544/2934735716';
  static const String _androidAppOpenTestId =
      'ca-app-pub-3940256099942544/3419835294';
  static const String _iosAppOpenTestId =
      'ca-app-pub-3940256099942544/5575463023';

  static bool get supportsMobileAds =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool get useReleaseAdIds =>
      kReleaseMode || (kProfileMode && adsUseReleaseIdsInProfile);

  static String get googleServerClientId => _googleServerClientId.trim();

  static String get googleIosClientId => _googleIosClientId.trim();

  static bool get isGoogleSignInConfigured => googleServerClientId.isNotEmpty;

  static bool get unityAdsEnabled =>
      supportsMobileAds && unityAdsFeatureEnabled;

  static bool get unityAdsTestMode =>
      kReleaseMode ? unityAdsTestModeOverride : true;

  static String get unityAdsFirebaseTestLabMode =>
      _unityAdsFirebaseTestLabModeRaw.trim().toLowerCase();

  static String get unityAdsGameId => _unityValueForPlatform(
    androidValue: _unityAdsGameIdAndroid,
    iosValue: _unityAdsGameIdIos,
  ).trim();

  static String? get unityRewardedPlacementId => _unityPlacementForPlatform(
    androidValue: _unityRewardedPlacementIdAndroid,
    iosValue: _unityRewardedPlacementIdIos,
  );

  static String? get unityInterstitialPlacementId => _unityPlacementForPlatform(
    androidValue: _unityInterstitialPlacementIdAndroid,
    iosValue: _unityInterstitialPlacementIdIos,
  );

  static String? get unityBannerPlacementId => _unityPlacementForPlatform(
    androidValue: _unityBannerPlacementIdAndroid,
    iosValue: _unityBannerPlacementIdIos,
  );

  static bool get unityRewardedAdsEnabled =>
      unityAdsEnabled &&
      unityRewardedFeatureEnabled &&
      unityRewardedPlacementId != null;

  static bool get unityInterstitialAdsEnabled =>
      unityAdsEnabled &&
      unityInterstitialFeatureEnabled &&
      unityInterstitialPlacementId != null;

  static bool get unityBannerAdsEnabled =>
      unityAdsEnabled &&
      unityBannerFeatureEnabled &&
      unityBannerPlacementId != null;

  static String? get rewardedAdUnitId => _resolveAdUnitId(
    releaseValue: _releaseRewardedAdUnitIdForPlatform,
    testValue: _testAdUnitIdForPlatform(
      androidValue: _androidRewardedTestId,
      iosValue: _iosRewardedTestId,
    ),
  );

  static String? get interstitialAdUnitId => _resolveAdUnitId(
    releaseValue: _releaseInterstitialAdUnitIdForPlatform,
    testValue: _testAdUnitIdForPlatform(
      androidValue: _androidInterstitialTestId,
      iosValue: _iosInterstitialTestId,
    ),
  );

  static String? get bannerAdUnitId => _resolveAdUnitId(
    releaseValue: _releaseBannerAdUnitIdForPlatform,
    testValue: _testAdUnitIdForPlatform(
      androidValue: _androidBannerTestId,
      iosValue: _iosBannerTestId,
    ),
  );

  static String? get appOpenAdUnitId => _resolveAdUnitId(
    releaseValue: _releaseAppOpenAdUnitIdForPlatform,
    testValue: _testAdUnitIdForPlatform(
      androidValue: _androidAppOpenTestId,
      iosValue: _iosAppOpenTestId,
    ),
  );

  static bool get rewardedAdsEnabled =>
      supportsMobileAds &&
      adsFeatureEnabled &&
      rewardedReviveFeatureEnabled &&
      rewardedAdUnitId != null;

  static bool get interstitialAdsEnabled =>
      supportsMobileAds &&
      adsFeatureEnabled &&
      interstitialFeatureEnabled &&
      interstitialAdUnitId != null;

  static bool get bannerAdsEnabled =>
      supportsMobileAds &&
      adsFeatureEnabled &&
      bannerFeatureEnabled &&
      bannerAdUnitId != null;

  static bool get appOpenAdsEnabled =>
      supportsMobileAds &&
      adsFeatureEnabled &&
      appOpenFeatureEnabled &&
      appOpenAdUnitId != null;

  static bool get admobAdsEnabled =>
      rewardedAdsEnabled ||
      interstitialAdsEnabled ||
      bannerAdsEnabled ||
      appOpenAdsEnabled;

  static bool get adsEnabled =>
      admobAdsEnabled ||
      unityRewardedAdsEnabled ||
      unityInterstitialAdsEnabled ||
      unityBannerAdsEnabled;

  static Duration get adsLoadTimeout =>
      Duration(seconds: adsLoadTimeoutSeconds.clamp(5, 60).toInt());

  static Duration get adsShowTimeout =>
      Duration(seconds: adsShowTimeoutSeconds.clamp(10, 600).toInt());

  static Duration get rewardedReviveAdWait =>
      Duration(seconds: rewardedReviveAdWaitSeconds.clamp(5, 60).toInt());

  static Duration get rewardedShowTimeout =>
      Duration(seconds: rewardedShowTimeoutSeconds.clamp(10, 600).toInt());

  static int? get adRequestHttpTimeoutMillis {
    final timeout = adsRequestHttpTimeoutMillis.clamp(0, 60000).toInt();
    return timeout <= 0 ? null : timeout;
  }

  static Duration get adsWatchdogInterval =>
      Duration(seconds: adsWatchdogIntervalSeconds.clamp(10, 300).toInt());

  static Duration get adsMaxAdAge =>
      Duration(minutes: adsMaxAdAgeMinutes.clamp(10, 120).toInt());

  static Duration get adsMinLoadInterval =>
      Duration(seconds: adsMinLoadIntervalSeconds.clamp(5, 120).toInt());

  static Duration get adsRetryBase =>
      Duration(seconds: adsRetryBaseSeconds.clamp(3, 60).toInt());

  static Duration get adsRetryMax =>
      Duration(seconds: adsRetryMaxSeconds.clamp(30, 600).toInt());

  static Duration get adsResumeDelay =>
      Duration(milliseconds: adsResumeDelayMs.clamp(0, 5000).toInt());

  static Duration get adsPreloadInterstitialDelay => Duration(
    milliseconds: adsPreloadInterstitialDelayMs.clamp(0, 30000).toInt(),
  );

  static Duration get adsPreloadBannerDelay =>
      Duration(milliseconds: adsPreloadBannerDelayMs.clamp(0, 30000).toInt());

  static Duration get adsPreloadAppOpenDelay =>
      Duration(milliseconds: adsPreloadAppOpenDelayMs.clamp(0, 60000).toInt());

  static Duration get appOpenColdStartDelay =>
      Duration(seconds: appOpenColdStartDelaySeconds.clamp(0, 120).toInt());

  static Duration get appOpenCooldown =>
      Duration(seconds: appOpenCooldownSeconds.clamp(30, 600).toInt());

  static Duration get appOpenSuppressAfterAdClick => Duration(
    seconds: appOpenSuppressAfterAdClickSeconds.clamp(30, 1800).toInt(),
  );

  static String? get adsMaxAdContentRating {
    final rating = _adsMaxContentRatingRaw.trim().toUpperCase();
    if (rating.isEmpty) {
      return null;
    }
    if (rating == 'G' || rating == 'PG' || rating == 'T' || rating == 'MA') {
      return rating;
    }
    return 'T';
  }

  static int? get adsTagForChildDirectedTreatment =>
      _toMobileAdsRequestTag(_parseNullableBool(_adsTagChildDirectedRaw));

  static int? get adsTagForUnderAgeOfConsent =>
      _toMobileAdsRequestTag(adsConsentTagForUnderAgeOfConsent);

  static bool? get adsConsentTagForUnderAgeOfConsent =>
      _parseNullableBool(_adsTagUnderAgeOfConsentRaw);

  static String get adsConsentDebugGeography =>
      _adsConsentDebugGeographyRaw.trim().toLowerCase();

  static List<String> get adTestDeviceIds {
    if (_adTestDeviceIdsRaw.trim().isEmpty) {
      return const <String>[];
    }
    return _adTestDeviceIdsRaw
        .split(',')
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
  }

  static List<String> adsConfigurationIssues({bool? releaseLike}) {
    final isReleaseLike = releaseLike ?? useReleaseAdIds;
    if (!isReleaseLike) {
      return const <String>[];
    }

    final issues = <String>[];
    final validateAdMobAds = adsFeatureEnabled && supportsMobileAds;
    final validateUnityAds = unityAdsEnabled;
    if (validateAdMobAds &&
        rewardedReviveFeatureEnabled &&
        _isMissingOrTestAdUnitId(_releaseRewardedAdUnitIdForPlatform)) {
      issues.add(
        'ADMOB_REWARDED_AD_UNIT_ID must be a real production ad unit.',
      );
    }
    if (validateAdMobAds &&
        interstitialFeatureEnabled &&
        _isMissingOrTestAdUnitId(_releaseInterstitialAdUnitIdForPlatform)) {
      issues.add(
        'ADMOB_INTERSTITIAL_AD_UNIT_ID must be a real production ad unit.',
      );
    }
    if (validateAdMobAds &&
        bannerFeatureEnabled &&
        _isMissingOrTestAdUnitId(_releaseBannerAdUnitIdForPlatform)) {
      issues.add('ADMOB_BANNER_AD_UNIT_ID must be a real production ad unit.');
    }
    if (validateAdMobAds &&
        appOpenFeatureEnabled &&
        _isMissingOrTestAdUnitId(_releaseAppOpenAdUnitIdForPlatform)) {
      issues.add(
        'ADMOB_APP_OPEN_AD_UNIT_ID must be a real production ad unit.',
      );
    }
    if (validateAdMobAds && _adTestDeviceIdsRaw.trim().isNotEmpty) {
      issues.add('ADMOB_TEST_DEVICE_IDS must be empty for release builds.');
    }
    if (validateAdMobAds && adsConsentDebugGeography.isNotEmpty) {
      issues.add('ADS_CONSENT_DEBUG_GEOGRAPHY must be empty for release.');
    }
    if (validateUnityAds && unityAdsGameId.trim().isEmpty) {
      issues.add('UNITY_ADS_GAME_ID_ANDROID is required.');
    }
    if (validateUnityAds &&
        unityRewardedFeatureEnabled &&
        unityRewardedPlacementId == null) {
      issues.add('UNITY_ADS_REWARDED_PLACEMENT_ID_ANDROID is required.');
    }
    if (validateUnityAds &&
        unityInterstitialFeatureEnabled &&
        unityInterstitialPlacementId == null) {
      issues.add('UNITY_ADS_INTERSTITIAL_PLACEMENT_ID_ANDROID is required.');
    }
    if (validateUnityAds &&
        unityBannerFeatureEnabled &&
        unityBannerPlacementId == null) {
      issues.add('UNITY_ADS_BANNER_PLACEMENT_ID_ANDROID is required.');
    }
    if (validateUnityAds && unityAdsTestModeOverride) {
      issues.add('UNITY_ADS_TEST_MODE must be false for release builds.');
    }
    final rating = _adsMaxContentRatingRaw.trim().toUpperCase();
    if (rating.isNotEmpty &&
        rating != 'G' &&
        rating != 'PG' &&
        rating != 'T' &&
        rating != 'MA') {
      issues.add('ADS_MAX_CONTENT_RATING must be one of G, PG, T, or MA.');
    }
    return issues;
  }

  /// Enables a deterministic Stage 1 trap hook for local/dev validation.
  ///
  /// Non-release builds keep this enabled by default for QA velocity.
  /// Release builds require an explicit dart-define and are guarded by
  /// [productionReadinessIssues].
  static bool get stageOneSixthTileTrapEnabled =>
      _forceStageOneTestTrap || !kReleaseMode;

  /// Shows the stage jumper in debug builds unless explicitly disabled.
  static bool get debugStageDropdownEnabled =>
      kDebugMode && _debugStageDropdown;

  static Duration get interstitialCooldown =>
      Duration(seconds: interstitialCooldownSeconds.clamp(30, 3600).toInt());

  static int get stageClearedAdInterval =>
      stageClearedInterstitialInterval.clamp(1, 50);

  static Duration get stageClearedAdCooldown => Duration(
    seconds: stageClearedInterstitialCooldownSeconds.clamp(30, 3600).toInt(),
  );

  static List<String> productionReadinessIssues({
    bool releaseMode = kReleaseMode,
    bool adsEnabled = adsFeatureEnabled,
    bool rewardedEnabled = rewardedReviveFeatureEnabled,
    bool interstitialEnabled = interstitialFeatureEnabled,
    bool bannerEnabled = bannerFeatureEnabled,
    bool unityAdsEnabled = unityAdsFeatureEnabled,
    bool unityRewardedEnabled = unityRewardedFeatureEnabled,
    bool unityInterstitialEnabled = unityInterstitialFeatureEnabled,
    bool unityBannerEnabled = unityBannerFeatureEnabled,
    bool? mobileAdsSupported,
    bool forceStageOneTestTrap = _forceStageOneTestTrap,
    String? rewardedAdUnitId,
    String? interstitialAdUnitId,
    String? bannerAdUnitId,
    String? appOpenAdUnitId,
    String? unityAdsGameIdValue,
    String? unityRewardedPlacementIdValue,
    String? unityInterstitialPlacementIdValue,
    String? unityBannerPlacementIdValue,
    bool unityAdsTestModeOverrideValue = unityAdsTestModeOverride,
    String googleServerClientId = _googleServerClientId,
    String privacyPolicyUrlValue = AppRuntimeConfig.privacyPolicyUrl,
    String termsUrlValue = AppRuntimeConfig.termsUrl,
    String accountDeletionUrlValue = AppRuntimeConfig.accountDeletionUrl,
    String removeAdsProductIdValue = AppRuntimeConfig.removeAdsProductId,
  }) {
    if (!releaseMode) {
      return const <String>[];
    }

    final issues = <String>[];
    if (googleServerClientId.trim().isEmpty) {
      issues.add('GOOGLE_SERVER_CLIENT_ID is required for release builds.');
    }
    if (privacyPolicyUrlValue.trim().isEmpty) {
      issues.add('PRIVACY_POLICY_URL is required for Play Store release.');
    }
    if (termsUrlValue.trim().isEmpty) {
      issues.add('TERMS_URL is required for Play Store release.');
    }
    if (accountDeletionUrlValue.trim().isEmpty) {
      issues.add('ACCOUNT_DELETION_URL is required for Play account deletion.');
    }
    if (forceStageOneTestTrap) {
      issues.add('FORCE_STAGE1_TEST_TRAP must be false for release builds.');
    }
    final mobileAdsAvailable = mobileAdsSupported ?? supportsMobileAds;
    final validateAnyMobileAds = adsEnabled && mobileAdsAvailable;
    final validateAdMobAds = validateAnyMobileAds;
    final validateUnityAds = unityAdsEnabled && mobileAdsAvailable;
    final effectiveRewardedAdUnitId =
        rewardedAdUnitId ?? _releaseRewardedAdUnitIdForPlatform;
    final effectiveInterstitialAdUnitId =
        interstitialAdUnitId ?? _releaseInterstitialAdUnitIdForPlatform;
    final effectiveBannerAdUnitId =
        bannerAdUnitId ?? _releaseBannerAdUnitIdForPlatform;
    final effectiveAppOpenAdUnitId =
        appOpenAdUnitId ?? _releaseAppOpenAdUnitIdForPlatform;
    final resolvedUnityAdsGameId =
        unityAdsGameIdValue ?? AppRuntimeConfig.unityAdsGameId;
    final resolvedUnityRewardedPlacementId =
        unityRewardedPlacementIdValue ??
        AppRuntimeConfig.unityRewardedPlacementId;
    final resolvedUnityInterstitialPlacementId =
        unityInterstitialPlacementIdValue ??
        AppRuntimeConfig.unityInterstitialPlacementId;
    final resolvedUnityBannerPlacementId =
        unityBannerPlacementIdValue ?? AppRuntimeConfig.unityBannerPlacementId;
    if (validateAdMobAds &&
        rewardedEnabled &&
        _isMissingOrTestAdUnitId(effectiveRewardedAdUnitId)) {
      issues.add(
        'ADMOB_REWARDED_AD_UNIT_ID must be a real production ad unit when rewarded fallback ads are enabled.',
      );
    }
    if (validateAdMobAds &&
        interstitialEnabled &&
        _isMissingOrTestAdUnitId(effectiveInterstitialAdUnitId)) {
      issues.add(
        'ADMOB_INTERSTITIAL_AD_UNIT_ID must be a real production ad unit when interstitial fallback ads are enabled.',
      );
    }
    if (validateAdMobAds &&
        bannerEnabled &&
        _isMissingOrTestAdUnitId(effectiveBannerAdUnitId)) {
      issues.add(
        'ADMOB_BANNER_AD_UNIT_ID must be a real production ad unit when banner fallback ads are enabled.',
      );
    }
    if (validateAdMobAds &&
        appOpenFeatureEnabled &&
        _isMissingOrTestAdUnitId(effectiveAppOpenAdUnitId)) {
      issues.add(
        'ADMOB_APP_OPEN_AD_UNIT_ID must be a real production ad unit when app-open ads are enabled.',
      );
    }
    if (validateUnityAds && resolvedUnityAdsGameId.trim().isEmpty) {
      issues.add(
        'UNITY_ADS_GAME_ID_ANDROID is required when Unity Ads are enabled.',
      );
    }
    if (validateUnityAds &&
        unityRewardedEnabled &&
        (resolvedUnityRewardedPlacementId?.trim().isNotEmpty != true)) {
      issues.add(
        'UNITY_ADS_REWARDED_PLACEMENT_ID_ANDROID is required when Unity rewarded ads are enabled.',
      );
    }
    if (validateUnityAds &&
        unityInterstitialEnabled &&
        (resolvedUnityInterstitialPlacementId?.trim().isNotEmpty != true)) {
      issues.add(
        'UNITY_ADS_INTERSTITIAL_PLACEMENT_ID_ANDROID is required when Unity interstitials are enabled.',
      );
    }
    if (validateUnityAds &&
        unityBannerEnabled &&
        (resolvedUnityBannerPlacementId?.trim().isNotEmpty != true)) {
      issues.add(
        'UNITY_ADS_BANNER_PLACEMENT_ID_ANDROID is required when Unity banners are enabled.',
      );
    }
    if (validateUnityAds && unityAdsTestModeOverrideValue) {
      issues.add('UNITY_ADS_TEST_MODE must be false for release builds.');
    }
    final validateRemoveAdsProductId =
      validateAnyMobileAds && removeAdsUiEnabled;
    if (validateRemoveAdsProductId &&
      (removeAdsProductIdValue.trim().isEmpty ||
        removeAdsProductIdValue.trim() == 'remove_ads_prod_android')) {
      issues.add(
        'REMOVE_ADS_PRODUCT_ID must be set to the real Play Store / App Store '
        'product ID for release builds (current: "$removeAdsProductIdValue").',
      );
    }
    return issues;
  }

  static void assertProductionReady() {
    // Web/itch.io builds don't require Play Store metadata and shouldn't crash.
    if (kIsWeb) return;

    assert(removeAdsProductId.isNotEmpty);
    final issues = productionReadinessIssues();
    if (issues.isEmpty) {
      return;
    }
    throw StateError(
      'Release configuration is incomplete: ${issues.join(' ')}',
    );
  }

  static String? _resolveAdUnitId({
    required String releaseValue,
    required String testValue,
  }) {
    if (useReleaseAdIds) {
      final configured = releaseValue.trim();
      return configured.isEmpty ? null : configured;
    }
    return testValue;
  }

  static String get _releaseRewardedAdUnitIdForPlatform =>
      _releaseAdUnitIdForPlatform(
        androidValue: _releaseAndroidRewardedAdUnitId,
        iosValue: _releaseIosRewardedAdUnitId,
        fallbackValue: _releaseRewardedAdUnitId,
      );

  static String get _releaseInterstitialAdUnitIdForPlatform =>
      _releaseAdUnitIdForPlatform(
        androidValue: _releaseAndroidInterstitialAdUnitId,
        iosValue: _releaseIosInterstitialAdUnitId,
        fallbackValue: _releaseInterstitialAdUnitId,
      );

  static String get _releaseBannerAdUnitIdForPlatform =>
      _releaseAdUnitIdForPlatform(
        androidValue: _releaseAndroidBannerAdUnitId,
        iosValue: _releaseIosBannerAdUnitId,
        fallbackValue: _releaseBannerAdUnitId,
      );

  static String get _releaseAppOpenAdUnitIdForPlatform =>
      _releaseAdUnitIdForPlatform(
        androidValue: _releaseAndroidAppOpenAdUnitId,
        iosValue: _releaseIosAppOpenAdUnitId,
        fallbackValue: _releaseAppOpenAdUnitId,
      );

  static String _releaseAdUnitIdForPlatform({
    required String androidValue,
    required String iosValue,
    required String fallbackValue,
  }) {
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        iosValue.trim().isNotEmpty) {
      return iosValue;
    }
    if (defaultTargetPlatform == TargetPlatform.android &&
        androidValue.trim().isNotEmpty) {
      return androidValue;
    }
    return fallbackValue;
  }

  static String _testAdUnitIdForPlatform({
    required String androidValue,
    required String iosValue,
  }) {
    return defaultTargetPlatform == TargetPlatform.iOS
        ? iosValue
        : androidValue;
  }

  static String _unityValueForPlatform({
    required String androidValue,
    required String iosValue,
  }) {
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        iosValue.trim().isNotEmpty) {
      return iosValue;
    }
    return androidValue;
  }

  static String? _unityPlacementForPlatform({
    required String androidValue,
    required String iosValue,
  }) {
    final resolved = _unityValueForPlatform(
      androidValue: androidValue,
      iosValue: iosValue,
    ).trim();
    return resolved.isEmpty ? null : resolved;
  }

  static bool? _parseNullableBool(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'unspecified') {
      return null;
    }
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
    return null;
  }

  static int? _toMobileAdsRequestTag(bool? value) {
    if (value == null) {
      return null;
    }
    return value ? 1 : 0;
  }

  static bool _isMissingOrTestAdUnitId(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return true;
    }
    return normalized == _androidRewardedTestId ||
        normalized == _iosRewardedTestId ||
        normalized == _androidInterstitialTestId ||
        normalized == _iosInterstitialTestId ||
        normalized == _androidBannerTestId ||
        normalized == _iosBannerTestId ||
        normalized == _androidAppOpenTestId ||
        normalized == _iosAppOpenTestId;
  }
}
