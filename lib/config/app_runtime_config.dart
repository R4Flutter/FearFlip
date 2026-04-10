import 'package:flutter/foundation.dart';

class AppRuntimeConfig {
  static const String _googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '158165984868-bvqagc5kubdo3cmpkr3ccrhufd2ksl6i.apps.googleusercontent.com',
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

  static bool get isGoogleSignInConfigured => googleServerClientId.isNotEmpty;

  static String? get rewardedAdUnitId => _resolveAdUnitId(
    releaseValue: _releaseRewardedAdUnitId,
    testValue: _rewardedTestId,
  );

  static String? get interstitialAdUnitId => _resolveAdUnitId(
    releaseValue: _releaseInterstitialAdUnitId,
    testValue: _interstitialTestId,
  );

  static bool get adsEnabled =>
      rewardedAdUnitId != null || interstitialAdUnitId != null;

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
