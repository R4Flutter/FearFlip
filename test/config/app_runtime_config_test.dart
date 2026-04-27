import 'package:flutter_test/flutter_test.dart';

import 'package:fearflipgame/config/app_runtime_config.dart';

void main() {
  test('debug builds do not report production readiness issues', () {
    final issues = AppRuntimeConfig.productionReadinessIssues(
      releaseMode: false,
      googleServerClientId: '',
      privacyPolicyUrlValue: '',
      termsUrlValue: '',
      accountDeletionUrlValue: '',
      rewardedAdUnitId: '',
      interstitialAdUnitId: '',
    );

    expect(issues, isEmpty);
  });

  test('release builds require store, auth, and ad configuration', () {
    final issues = AppRuntimeConfig.productionReadinessIssues(
      releaseMode: true,
      googleServerClientId: '',
      privacyPolicyUrlValue: '',
      termsUrlValue: '',
      accountDeletionUrlValue: '',
      rewardedAdUnitId: '',
      interstitialAdUnitId: '',
    );

    expect(issues, contains(contains('GOOGLE_SERVER_CLIENT_ID')));
    expect(issues, contains(contains('PRIVACY_POLICY_URL')));
    expect(issues, contains(contains('TERMS_URL')));
    expect(issues, contains(contains('ACCOUNT_DELETION_URL')));
    expect(issues, contains(contains('ADMOB_REWARDED_AD_UNIT_ID')));
    expect(issues, contains(contains('ADMOB_INTERSTITIAL_AD_UNIT_ID')));
  });

  test('non-release builds enable stage one trap testing hook', () {
    expect(AppRuntimeConfig.stageOneSixthTileTrapEnabled, isTrue);
  });

  test('release builds reject forced stage one trap test mode', () {
    final issues = AppRuntimeConfig.productionReadinessIssues(
      releaseMode: true,
      adsEnabled: false,
      rewardedEnabled: false,
      interstitialEnabled: false,
      forceStageOneTestTrap: true,
      rewardedAdUnitId: 'ok',
      interstitialAdUnitId: 'ok',
      googleServerClientId: 'ok',
      privacyPolicyUrlValue: 'https://example.com/privacy',
      termsUrlValue: 'https://example.com/terms',
      accountDeletionUrlValue: 'https://example.com/delete',
    );

    expect(issues, contains(contains('FORCE_STAGE1_TEST_TRAP')));
  });
}
