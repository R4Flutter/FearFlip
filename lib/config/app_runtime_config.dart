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
  static const int interstitialCooldownSeconds = int.fromEnvironment(
    'INTERSTITIAL_COOLDOWN_SECONDS',
    defaultValue: 120,
  );
  static const int interstitialMinGameOvers = int.fromEnvironment(
    'INTERSTITIAL_MIN_GAME_OVERS',
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
    defaultValue: '',
  );
  static const String _releaseInterstitialAdUnitId = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_AD_UNIT_ID',
    defaultValue: '',
  );

  static const String _rewardedTestId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _interstitialTestId =
      'ca-app-pub-3940256099942544/1033173712';

  static String get googleServerClientId => _googleServerClientId.trim();

  static String get googleIosClientId => _googleIosClientId.trim();

  static bool get isGoogleSignInConfigured => googleServerClientId.isNotEmpty;

  static String? get rewardedAdUnitId => _resolveAdUnitId(
    releaseValue: _releaseRewardedAdUnitId,
    testValue: _rewardedTestId,
  );

  static String? get interstitialAdUnitId => _resolveAdUnitId(
    releaseValue: _releaseInterstitialAdUnitId,
    testValue: _interstitialTestId,
  );

  static bool get rewardedAdsEnabled =>
      adsFeatureEnabled &&
      rewardedReviveFeatureEnabled &&
      rewardedAdUnitId != null;

  static bool get interstitialAdsEnabled =>
      adsFeatureEnabled &&
      interstitialFeatureEnabled &&
      interstitialAdUnitId != null;

  static bool get adsEnabled => rewardedAdsEnabled || interstitialAdsEnabled;

  /// Enables a deterministic Stage 1 trap hook for local/dev validation.
  ///
  /// Non-release builds keep this enabled by default for QA velocity.
  /// Release builds require an explicit dart-define and are guarded by
  /// [productionReadinessIssues].
  static bool get stageOneSixthTileTrapEnabled =>
      _forceStageOneTestTrap || !kReleaseMode;

  static Duration get interstitialCooldown =>
      Duration(seconds: interstitialCooldownSeconds.clamp(30, 3600).toInt());

  static List<String> productionReadinessIssues({
    bool releaseMode = kReleaseMode,
    bool adsEnabled = adsFeatureEnabled,
    bool rewardedEnabled = rewardedReviveFeatureEnabled,
    bool interstitialEnabled = interstitialFeatureEnabled,
    bool forceStageOneTestTrap = _forceStageOneTestTrap,
    String rewardedAdUnitId = _releaseRewardedAdUnitId,
    String interstitialAdUnitId = _releaseInterstitialAdUnitId,
    String googleServerClientId = _googleServerClientId,
    String privacyPolicyUrlValue = AppRuntimeConfig.privacyPolicyUrl,
    String termsUrlValue = AppRuntimeConfig.termsUrl,
    String accountDeletionUrlValue = AppRuntimeConfig.accountDeletionUrl,
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
    if (adsEnabled && rewardedEnabled && rewardedAdUnitId.trim().isEmpty) {
      issues.add(
        'ADMOB_REWARDED_AD_UNIT_ID is required when rewarded ads are enabled.',
      );
    }
    if (adsEnabled &&
        interstitialEnabled &&
        interstitialAdUnitId.trim().isEmpty) {
      issues.add(
        'ADMOB_INTERSTITIAL_AD_UNIT_ID is required when interstitial ads are enabled.',
      );
    }
    return issues;
  }

  static void assertProductionReady() {
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
    if (kReleaseMode) {
      final configured = releaseValue.trim();
      return configured.isEmpty ? null : configured;
    }
    return testValue;
  }
}
