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
2. Verify Android signing config and keystore security.
3. Upload to Internal testing.
4. Rollout sequence: Internal -> Closed -> Production staged %.

## Local release config
- Copy `android/release.properties.example` to `android/release.properties`.
- Copy `android/key.properties.example` to `android/key.properties`.
- Pass build-time runtime IDs with `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`, `--dart-define=ADMOB_REWARDED_AD_UNIT_ID=...`, and `--dart-define=ADMOB_INTERSTITIAL_AD_UNIT_ID=...`.

## Compliance
- Privacy policy required (Firebase + Ads usage).
- Data safety form with analytics/auth/crash reporting disclosures.
- Permission review to remove unused permissions.

## Monetization readiness
- Rewarded revive implemented behind service abstraction.
- Cosmetic unlock hooks available via progression and monetization service.
- Premium-mode capability exposed via `MonetizationService.isPremiumUnlocked()`.
