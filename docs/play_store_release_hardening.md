# Play Store Release Hardening

## Product polish
- App icon: create full-res 512x512 and adaptive foreground/background layers.
- Splash: ensure startup branding and dark/light contrast are readable.
- Error UX: app now has global fallback error widget from `main.dart`.

## Offline-first safety
- Firebase init now falls back safely when unavailable.
- Auth and leaderboard bootstrapping supports offline/noop mode.
- Analytics/crash reporters can be replaced by noop services.

## Performance acceptance
- Verify 60 FPS target on low-end Android profile.
- Track frame budget overruns via `FrameBudgetMonitor` logs.
- Keep gameplay allocations low using pools and asset cache.

## Store readiness
1. Build and verify release bundle:
   - `flutter build appbundle --release`
   - Release builds now fail fast if final package id, Firebase package match, AdMob app id, or signing config is missing.
2. Verify Android signing config and keystore security.
3. Upload to Internal testing.
4. Rollout sequence: Internal -> Closed -> Production staged %.

## Local release config
- Copy `android/release.properties.example` to `android/release.properties`.
- Copy `android/key.properties.example` to `android/key.properties`.
- Pass build-time runtime IDs with `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`, `--dart-define=GOOGLE_IOS_CLIENT_ID=...`, `--dart-define=ADMOB_REWARDED_AD_UNIT_ID=...`, `--dart-define=ADMOB_INTERSTITIAL_AD_UNIT_ID=...`, and `--dart-define=ADMOB_BANNER_AD_UNIT_ID=...`.
- Prefer platform-specific ad unit IDs when Android and iOS are both shipped: `ADMOB_ANDROID_REWARDED_AD_UNIT_ID`, `ADMOB_IOS_REWARDED_AD_UNIT_ID`, `ADMOB_ANDROID_INTERSTITIAL_AD_UNIT_ID`, `ADMOB_IOS_INTERSTITIAL_AD_UNIT_ID`, `ADMOB_ANDROID_BANNER_AD_UNIT_ID`, and `ADMOB_IOS_BANNER_AD_UNIT_ID`.
- Optional launch flags: `--dart-define=PRIVACY_POLICY_URL=...`, `--dart-define=TERMS_URL=...`, `--dart-define=ACCOUNT_DELETION_URL=...`, `--dart-define=ADS_ENABLED=true`, `--dart-define=REWARDED_REVIVE_ENABLED=true`, `--dart-define=INTERSTITIALS_ENABLED=true`, `--dart-define=BANNER_ADS_ENABLED=true`, `--dart-define=REWARDED_REVIVE_AD_WAIT_SECONDS=30`, `--dart-define=INTERSTITIAL_COOLDOWN_SECONDS=120`, and `--dart-define=INTERSTITIAL_MIN_GAME_OVERS=2`.
- Keep `ADMOB_TEST_DEVICE_IDS` and `ADS_CONSENT_DEBUG_GEOGRAPHY` empty for release builds.
- For iOS, replace `ADMOB_APP_ID` in `ios/Flutter/Release.xcconfig` with the real iOS AdMob app ID before App Store release.

## Google Sign-In preflight
1. Package match:
   - Ensure `fearflip.applicationId` in `android/release.properties` matches a `client[].client_info.android_client_info.package_name` entry in `android/app/google-services.json`.
2. Certificate fingerprints:
   - Run `cd android && ./gradlew :app:signingReport`.
   - Add BOTH debug and release SHA-1/SHA-256 to the Firebase Android app for the selected package.
3. Firebase auth provider:
   - In Firebase Console -> Authentication -> Sign-in method, confirm Google provider is enabled.
4. Refresh config after Firebase changes:
   - Re-download `android/app/google-services.json` from Firebase and replace the local file.
   - Run `flutter clean && flutter pub get` and rebuild.
5. Device readiness:
   - Confirm Google Play Services is available and up to date on test devices.
6. iOS callback config:
   - Add `GoogleService-Info.plist` to `ios/Runner` for the selected iOS bundle id, or provide `--dart-define=GOOGLE_IOS_CLIENT_ID=<ios-client-id>`.
   - Ensure `ios/Runner/Info.plist` includes the reversed client-id URL scheme for the same iOS OAuth client.

## Compliance
- Privacy policy required (Firebase + Ads usage).
- Data safety form with analytics/auth/crash reporting disclosures.
- Permission review to remove unused permissions.
- In-app account deletion is available from Settings and writes `accountDeletionRequests/{uid}` when immediate Firebase Auth deletion needs support follow-up.

## Monetization readiness
- Rewarded revive implemented behind service abstraction.
- Cosmetic unlock hooks available via progression and monetization service.
- Premium-mode capability exposed via `MonetizationService.isPremiumUnlocked()`.
