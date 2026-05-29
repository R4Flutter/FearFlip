# FearFlip — Production Ad Deployment Checklist

## Architecture Overview
- **Primary network:** Unity Ads (tried first for all ad types)
- **Fallback network:** AdMob (tried if Unity fails/no-fill)
- **Facade:** `AdsFacade` routes all ad calls, widgets never reach single-network services directly
- **"Remove Ads":** `PurchaseService` → `AdsFacade.disableAdsPermanently()` (both networks)

---

## Pre-Launch Checklist

### 1. Ad Network Configuration
- [x] Unity Ads Game ID: `800001612`
- [x] Unity Rewarded Placement: `Rewarded_Android`
- [x] Unity Interstitial Placement: `Interstitial_Android`
- [x] Unity Banner Placement: `Banner_Android`
- [x] AdMob App ID: `ca-app-pub-5463912491137261~6954996599`
- [x] AdMob Rewarded: `ca-app-pub-5463912491137261/7771282021`
- [x] AdMob Interstitial: `ca-app-pub-5463912491137261/7639420085`
- [x] AdMob Banner: `ca-app-pub-5463912491137261/3640465329`
- [ ] All ad unit IDs verified in Unity Dashboard and AdMob Console

### 2. Test Mode MUST Be Off
- [x] `unityAdsTestMode` returns `false` in release (`kReleaseMode ? override : true`)
- [ ] `UNITY_ADS_TEST_MODE` dart-define is NOT set (or set to `false`)
- [ ] `ADMOB_TEST_DEVICE_IDS` is empty in release builds
- [ ] `ADS_CONSENT_DEBUG_GEOGRAPHY` is empty in release builds

### 3. Android Build Config
- [x] `android/release.properties` has real `fearflip.admob.appId`
- [x] `android/key.properties` has signing config (storeFile, storePassword, keyAlias, keyPassword)
- [x] `google-services.json` matches package `com.rajnaik.fearflip`
- [x] `minSdkVersion` ≥ 23 (Unity Ads + AdMob requirement)
- [x] ProGuard rules include Unity Ads and AdMob keep rules
- [x] `AD_ID` permission declared in AndroidManifest.xml

### 4. Consent & Privacy (Play Store Policy)
- [x] UMP consent flow runs before any ad request (`ConsentService.gatherConsentAndInitializeAds()`)
- [x] Privacy policy URL configured and accessible
- [x] `adsTagForUnderAgeOfConsent` set appropriately (general audience = false/unspecified)
- [x] `adsMaxAdContentRating` = `T` (Teen — appropriate for horror/challenge game)
- [x] GDPR/CCPA/PIPL consent forwarded to Unity Ads via `setPrivacyConsent()`
- [x] Account deletion URL provided (Play Store requirement)

### 5. "Remove Ads" IAP
- [x] `PurchaseService` initializes BEFORE `AdsFacade.start()` in main.dart
- [x] `disableAdsPermanently()` disables BOTH networks (via `AdsFacade`)
- [x] Server-side purchase verification via Cloud Function
- [ ] `REMOVE_ADS_PRODUCT_ID` set to real Play Store product ID (not `remove_ads_prod_android`)

### 6. Stability & ANR Prevention
- [x] Ad show calls wait for safe frame (`_waitForSafeFrame()`)
- [x] Show timeout protection (180s rewarded, 90s interstitial)
- [x] Deduplication — `_isShowingAd` / `_fullScreenAdShowing` flags prevent concurrent ad shows
- [x] Exponential backoff retry with jitter (2s → 4s → 8s → 15s → 30s → 60s)
- [x] Watchdog timer auto-reloads expired ads every 45s
- [x] Ad age expiration (50 minutes max) prevents showing stale ads
- [x] Connectivity listener triggers reload when network restored
- [x] App lifecycle handling — ads paused in background, reloaded on resume

---

## Monetization Optimization Tips

### Rewarded Ad Best Placements (Horror/Challenge Game)
1. **Revive after death** — highest eCPM, player is motivated (already implemented)
2. **Double trophies reward** — after clearing a stage, offer 2x trophies for watching
3. **Unlock hint/skip** — let players watch an ad to skip a difficult trap
4. **Extra life before hard section** — offer a shield/extra-life before known hard stages

### Interstitial Frequency — Safe & Retention-Friendly
- **Game-over interstitial:** min 2 deaths + 120s cooldown (current config)
- **Stage-cleared interstitial:** every 3rd stage + 30s cooldown (current config)
- **Never show interstitial on first session** — let the player get hooked first
- **Never show two ads back-to-back** — the `_isShowingAd` lock prevents this

### Maximize eCPM
- **Show ads when engagement is highest:** revive moments have 90%+ completion rates
- **Preload ads aggressively:** rewarded is loaded at app start, interstitial after 2s delay
- **Keep fill rate high:** dual-network fallback (Unity → AdMob) ensures near-100% fill
- **Avoid accidental clicks:** don't place buttons too close to ad close buttons

### Avoid Invalid Traffic (IVT)
- [x] Never auto-click or incentivize clicks (only reward on COMPLETE, not click)
- [x] Don't refresh banners more than every 60s
- [x] Don't show ads in miniature/hidden/invisible containers
- [x] Don't place ads in ways that encourage accidental taps
- [x] Real users only — no emulators, bots, or click farms
- [x] One ad showing at a time — `_isShowingAd` flag enforces this

---

## Debugging Checklist

### Ads Not Showing
1. Check `AdsDiagnostics` logs (`[Ads]` prefix in debug console)
2. Verify `adsEnabled = true` in `AppRuntimeConfig`
3. Verify consent flow completed (`canRequestAds = true`)
4. Verify not a premium user (`isPremiumUnlocked = false`)
5. Check connectivity — ads won't load offline
6. Check Unity Ads init — `"Unity Ads initialized"` in logs
7. Check AdMob SDK init — `"MobileAds initialized"` in logs
8. Verify placement IDs are correct and active in Unity Dashboard

### Unity Ads Specific
- Unity Ads test mode is `true` in debug, `false` in release by default
- Unity Dashboard can take up to 24h to activate new placements
- Check `"Rewarded load failed"` / `"Interstitial load failed"` logs for error codes

### AdMob Fallback Not Working
1. Verify AdMob ad unit IDs are set (not empty) in `AppRuntimeConfig`
2. Verify AdMob App ID in AndroidManifest meta-data
3. Check `"AdMob start failed"` in logs
4. Verify `google-services.json` matches application ID

### Crash / ANR on Ad Show
1. Ensure `_waitForSafeFrame()` is called before show (already in code)
2. Check show timeout is firing — `"Ad show timeout"` in logs
3. Check for duplicate show calls — `"Ad show blocked: already_showing"` in logs
4. Verify no ad show during app pause — `"Ad show blocked: inactive"` in logs

---

## Crash Prevention Checklist
- [x] No ad show during app backgrounding
- [x] No concurrent ad shows (mutex lock)
- [x] All ad show calls wrapped in try/catch
- [x] Timeout on all ad show Completers
- [x] Completer completion guarded with `isCompleted` checks
- [x] Ad instances disposed after show (prevents memory leaks)
- [x] Cancel retry timers on dispose
- [x] Cancel watchdog on service stop
- [x] Connectivity subscription cancelled on stop
- [x] WidgetsBindingObserver removed on stop
- [x] Post-frame-callback for safe banner dispose
