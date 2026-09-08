# Ads & Payments Hardening — Opus-Grade Prompt

> **What this is.** A single self-contained JSON prompt you paste into Opus 4.8
> (or any top-tier coding model) to get an end-to-end, multi-provider, fail-safe
> ads + IAP implementation for **FearFlip** (Flutter, see `pubspec.yaml`).
>
> **How to use.**
> 1. Open your AI coding tool that accepts a system message.
> 2. Set the `system` block as the system message.
> 3. Set the `user` block as the user message.
> 4. Don't add commentary — feed it raw.
> 5. The `context` snapshot below is the project's *current* state. Update
>    `context.verified_at` and any drift before pasting if more than a week
>    has passed since this file was written.

---

## The Prompt

```json
{
  "prompt_version": "1.0.0",
  "intent": "ads_and_iap_hardening",

  "context": {
    "project": {
      "name": "fearflipgame",
      "framework": "Flutter",
      "sdk": ">=3.9.2",
      "platforms": ["android", "ios", "web", "windows", "macos", "linux"],
      "primary_revenue": "ads",
      "secondary_revenue": "iap_remove_ads",
      "tone": "dark arcade survival",
      "ads_are_largest_revenue_source": true
    },
    "current_state": {
      "verified_at": "2026-07-19",
      "ads_packages": {
        "google_mobile_ads": "^7.0.0",
        "unity_ads_plugin": "^0.3.30"
      },
      "iap_packages": {
        "in_app_purchase": "^3.2.3",
        "in_app_purchase_android": "^0.4.0+10"
      },
      "backend": {
        "cloud_functions": "^6.2.0",
        "firebase_auth": "^6.3.0",
        "cloud_firestore": "^6.0.3",
        "firebase_analytics": "^12.0.2",
        "firebase_crashlytics": "^5.0.3"
      },
      "existing_files": {
        "ads_facade": "lib/services/ads_facade.dart",
        "ads_service_admob": "lib/services/ads_service.dart",
        "ads_service_base": "lib/services/ads_service_base.dart",
        "unity_manager": "lib/services/ad_manager.dart",
        "ads_diagnostics": "lib/services/ads_diagnostics.dart",
        "ad_placement_policy": "lib/services/ad_placement_policy.dart",
        "purchase_service": "lib/services/purchase_service.dart",
        "monetization_service": "lib/data/services/monetization_service.dart",
        "runtime_config": "lib/config/app_runtime_config.dart",
        "remove_ads_dialog": "lib/presentation/widgets/remove_ads_dialog.dart"
      },
      "what_works": [
        "AdsFacade with Unity-first / AdMob-fallback for banner, interstitial, rewarded, app-open",
        "Runtime config with separate dev/prod ad unit IDs via String.fromEnvironment",
        "MonetizationService with isPremiumUnlocked shared flag",
        "Consent flow (onboarding_consent_screen.dart) wired to ad requests"
      ],
      "what_is_broken_or_missing": [
        "Only 2 ad networks (Unity + AdMob). One SDK init failure or zero-fill on both = no ads.",
        "Ads are loaded lazily on demand — cold-start interstitial/rewarded show visible delay",
        "in_app_purchase flow is flaky: restore rarely works, errors aren't recovered, server-side receipt validation appears incomplete, no idempotency for already-processed purchases",
        "No circuit breaker — a misbehaving provider keeps getting retried with no cooldown",
        "No per-provider health metric (eCPM, fill rate, error rate) persisted anywhere",
        "No pre-warm of SDKs at app boot — first ad request pays full SDK-init cost",
        "App-open ads not pre-fetched after dismiss (next cold-open pays full init again)",
        "PurchaseService has no explicit iOS / Android code-path parity for receipt delivery",
        "No 'Remove Ads' subscription tier — only one-time non-consumable"
      ]
    }
  },

  "system": {
    "role": "Principal Flutter engineer specialising in ad mediation, IAP, and revenue resilience. You have shipped AdMob + Unity + AppLovin MAX in production at >10M MAU. You treat the SDKs as fallible network endpoints and never trust a single provider.",
    "principles": [
      "If only one provider is integrated, the system is broken by design.",
      "Cold-start latency is a silent revenue leak. Pre-warm everything.",
      "Every provider call has a timeout, a retry budget, and a circuit breaker.",
      "The user must never see a 'no ad available' toast or spinner.",
      "Receipts are validated server-side. Never trust the client.",
      "Premium is the source of truth in shared_preferences + Firestore, with last-write-wins and clock-skew tolerance of 5 minutes.",
      "Kill switches are first-class. A failing provider must be disabled in <60s without a code release.",
      "All times are UTC. All money is in micros (int) until display.",
      "Type-safe, null-safe, lint-clean. No 'ignore_for_file' without a written reason in a comment above the directive."
    ],
    "do_not": [
      "Do not redesign FearFlip's gameplay, theme, or audio.",
      "Do not add new gameplay features.",
      "Do not introduce a state management library — the project already uses Provider (see presentation/providers/). Continue with that.",
      "Do not introduce a router library.",
      "Do not add web-only ad networks (no Adsense for this product).",
      "Do not write any code that logs the full receipt payload — it can contain PII."
    ]
  },

  "user": {
    "goal": "Make the ads + IAP system in fearflipgame fail-safe, fast, and revenue-positive across all 6 supported platforms, without changing gameplay.",
    "summary": "Currently AdMob + Unity are wired through AdsFacade but the system has zero resilience — any provider init failure or zero-fill kills the ad slot. IAP via in_app_purchase is flaky. We need a real mediation layer, parallel pre-warm, server-validated receipts, and a working restore flow.",

    "non_functional_requirements": {
      "ad_show_success_rate": ">= 95% per session (measured as: ad_won / ad_requested over rolling 24h)",
      "ad_cold_load_p95_ms": "<= 1500ms from app start to first ad-ready",
      "iap_purchase_to_unlock_p95_ms": "<= 4000ms from Google/Apple confirmation to isPremiumUnlocked=true in memory",
      "iap_restore_p95_ms": "<= 8000ms",
      "zero_crash_ads": "Any ad-related exception must be caught and routed to telemetry, never propagated to gameplay",
      "memory_budget_kb": "Ads stack at idle <= 8MB additional RSS",
      "must_compile": "flutter analyze --no-fatal-infos returns 0 errors and 0 warnings on the changed files",
      "must_test": "Unit tests cover chain selection, circuit-breaker, receipt validation happy/sad paths, restore flow, timeout handling"
    },

    "architecture": {
      "diagram": "ProviderChain(pre-warm) -> HealthRegistry -> CircuitBreaker -> [AdMob, UnityAds, AppLovinMAX, StartApp] -> WinnerEmitsAd -> AdSlot -> Telemetry + PremiumGate",

      "components": {
        "AdProviderRegistry": "Static, ordered, weighted list of all wired providers. Edit order in one place (lib/services/ads/registry.dart).",
        "ProviderHealth": "Per-provider rolling counters: requests, wins, fill_rate, init_failures, load_failures, show_failures, avg_latency_ms, last_success_at, last_failure_at, consecutive_failures.",
        "CircuitBreaker": "Per-provider state: closed / open / half-open. Open after N consecutive failures OR fill_rate < 10% over last 50 requests. Half-open after cooldown (30s initial, exponential up to 5m). Stays open if next probe fails.",
        "AdPreWarmer": "On app boot (after first frame), in parallel: init every enabled provider SDK, pre-fetch 1 rewarded + 1 interstitial + 1 app-open ad from the top-2 healthiest providers. Banner stays lazy.",
        "AdCache": "Per ad format, keep 1 'ready' ad in memory. When an ad is consumed (shown), asynchronously request a replacement within 500ms.",
        "AdSlot<TAd>": "Generic show-or-fail entry point. showRewarded() returns AdResult { status: shown|failed|cancelled|no_fill, provider, latencyMs, revenueMicros }. Never throws to caller.",
        "RevenueTelemetry": "Persists per-provider metrics to Firestore (collection: ad_metrics/{yyyyMMdd}/{provider}) for the ops dashboard. Also logs to Firebase Analytics events: ad_requested, ad_loaded, ad_shown, ad_failed, ad_circuit_open, ad_circuit_close.",
        "PremiumGate": "Single read-only ValueNotifier<bool> isPremiumUnlocked. Source of truth = shared_preferences('iap_remove_ads_unlocked') + Firestore users/{uid}.isPremium. Reconciled on auth change and on app resume."
      },

      "provider_chain_default_order": [
        {"id": "applovin_max", "rationale": "Smart mediation, supports bidding + waterfall, can wrap the other networks"},
        {"id": "unity_ads",    "rationale": "Gaming-optimized, high eCPM for arcade titles"},
        {"id": "admob",        "rationale": "Universal fallback, broadest reach"},
        {"id": "startapp",     "rationale": "Last-resort direct SDK, succeeds when mediation layers fail"}
      ],

      "ad_format_routing": {
        "banner": "Direct SDK rotation via AdCache. No mediation — banner eCPM is too low to justify.",
        "interstitial": "AppLovin MAX primary. On miss: Unity -> AdMob -> StartApp. Cache always warm.",
        "rewarded": "AppLovin MAX primary. On miss: AdMob -> Unity -> StartApp. NEVER fail silently — if all four return no_fill, surface a non-blocking telemetry event but no user-visible error.",
        "app_open": "AdMob primary (best cold-start eCPM in 2026 benchmarks). Fallback: AppLovin MAX -> StartApp."
      }
    },

    "new_dependencies": {
      "add": [
        {"pubspec_key": "applovin_max",                "version": "^4.6.0", "platforms": ["android", "ios"]},
        {"pubspec_key": "startapp",                     "version": "^2.1.7", "platforms": ["android", "ios"]},
        {"pubspec_key": "connectivity_plus",            "version": "^6.0.3", "platforms": ["android", "ios", "windows", "macos", "linux", "web"]},
        {"pubspec_key": "retry",                        "version": "^3.1.2", "platforms": ["android", "ios", "windows", "macos", "linux", "web"]},
        {"pubspec_key": "rxdart",                       "version": "^0.28.0", "platforms": ["android", "ios", "windows", "macos", "linux", "web"]},
        {"pubspec_key": "uuid",                         "version": "^4.5.1", "platforms": ["android", "ios", "windows", "macos", "linux", "web"]}
      ],
      "rationale": "AppLovin MAX is the mediation layer that turns waterfall into bidding. StartApp is the last-resort direct SDK with the most reliable init rate. retry + rxdart give us proper backoff and stream composition. uuid is for telemetry event IDs."
    },

    "tasks": [
      {
        "id": "T1",
        "title": "Add and pin new dependencies",
        "steps": [
          "Edit pubspec.yaml under dependencies: add applovin_max, startapp, retry, rxdart, uuid. Pin all versions as caret-ranges that match the latest stable on pub.dev as of 2026-07.",
          "Run `flutter pub get` and confirm no version conflicts.",
          "If any package fails to resolve, swap to the closest compatible version and document in CHANGELOG.md."
        ],
        "exit_criteria": "flutter pub deps --no-dev --style=tree shows all new packages resolved with zero conflicts."
      },
      {
        "id": "T2",
        "title": "Define the AdProvider interface",
        "steps": [
          "Create lib/services/ads/provider.dart exporting abstract class AdProvider with: String get id, Future<void> init({required AdConfig config}), Future<AdLoadResult> load(AdFormat format), Future<AdShowResult> show(AdFormat format, {Object? payload}), Future<void> dispose(), Stream<AdEvent> get events.",
          "Define enums AdFormat { banner, interstitial, rewarded, appOpen } and AdLoadStatus { ready, noFill, failed, throttled }.",
          "Define result classes as immutable Dart 3 records or sealed classes — your call, but be consistent across the codebase."
        ],
        "exit_criteria": "Interface compiles. Two stub implementations (FakeProvider) covered by unit tests pass."
      },
      {
        "id": "T3",
        "title": "Implement provider adapters",
        "steps": [
          "lib/services/ads/providers/admob_provider.dart — wraps existing google_mobile_ads calls, listens to AdEvent callbacks, normalises errors to AdLoadStatus / AdShowStatus.",
          "lib/services/ads/providers/unity_provider.dart — wraps AdManager instance, normalises UnityAdsPlacementState and UnityAdsLoadError.",
          "lib/services/ads/providers/applovin_provider.dart — wraps applovin_max. Configure ad unit IDs via AppLovinMediationAdapter for AdMob and Unity as sub-sources. This is the smart layer.",
          "lib/services/ads/providers/startapp_provider.dart — wraps startapp. Banner + interstitial + rewarded via direct API; no app-open equivalent (return AdLoadStatus.noFill for app-open).",
          "Each adapter MUST have its own try/catch around every SDK call. SDK exceptions become AdLoadStatus.failed with a typed reason string."
        ],
        "exit_criteria": "All four adapters compile, each can be init()'d in a test harness with test ad unit IDs, and each returns AdLoadResult within 5s timeout."
      },
      {
        "id": "T4",
        "title": "Build ProviderHealth and CircuitBreaker",
        "steps": [
          "lib/services/ads/health.dart — ProviderHealth class with the counters listed in architecture.components.ProviderHealth. Use a sliding window of 50 requests, atomic increments via Stream controllers.",
          "lib/services/ads/circuit_breaker.dart — generic CircuitBreaker<T> with states closed/open/half-open. Thresholds: open after 5 consecutive failures OR fill_rate < 10% over 50 requests. Cooldown: 30s, doubles up to 5m. Expose Stream<bool> isOpen for telemetry.",
          "Persist the breaker state to shared_preferences on every transition. Rehydrate on app start so a process kill doesn't reset a known-bad provider."
        ],
        "exit_criteria": "Unit tests cover: trip on consecutive failures, recovery on half-open success, state persists across simulated restart, exponential cooldown cap."
      },
      {
        "id": "T5",
        "title": "Build the AdCache and the AdSlot",
        "steps": [
          "lib/services/ads/cache.dart — AdCache per format, stores 1 ready ad per provider. When an ad is consumed, immediately request a replacement from the same provider in a microtask. If the replacement fails, fall through to the next provider in the chain.",
          "lib/services/ads/slot.dart — AdSlot.showRewarded / showInterstitial / showAppOpen. The slot walks the provider chain in priority order, skipping any provider whose CircuitBreaker is open, picks the first ready ad, shows it, and emits a result. Timeout per provider: 4s. Total slot timeout: 8s.",
          "If the entire chain returns no_fill, the slot returns AdShowResult.noFill — never throws."
        ],
        "exit_criteria": "Unit test with 3 mock providers where 2 are open and 1 is closed: the slot picks the closed one within 8s. Stress test: 100 sequential show() calls with randomised provider failures, success rate >= 90%."
      },
      {
        "id": "T6",
        "title": "Pre-warm at boot",
        "steps": [
          "lib/services/ads/pre_warmer.dart — listens to first-frame rendering, then in parallel (using Future.wait with a 10s ceiling): init all enabled providers, pre-load 1 rewarded + 1 interstitial + 1 app-open from the top-2 healthiest providers (per ProviderHealth default, all providers start at health=100 until proven otherwise).",
          "Banner stays lazy — it doesn't pay for warm-up cost.",
          "Pre-warm errors are swallowed and logged to telemetry. They must not block app start."
        ],
        "exit_criteria": "Instrumentation log: from app start to first_ad_ready timestamp. p95 <= 1500ms on a mid-range Android (Pixel 6a) over 20 cold starts."
      },
      {
        "id": "T7",
        "title": "Replace AdsFacade with the new AdSlot, keep API surface",
        "steps": [
          "Rewrite lib/services/ads_facade.dart as a thin wrapper over the new AdSlot. Keep the existing public methods and ValueNotifiers so LandingScreen, _BannerAdBar, FearFlipGame, and the diagnostics panel don't break.",
          "Mark old ads_service.dart, ad_manager.dart, ads_service_base.dart as @Deprecated for one release, then delete. Move non-trivial logic out of them into the new provider adapters first.",
          "Update ad_placement_policy.dart to take an AdSlot reference instead of hard-coded Unity/AdMob branches."
        ],
        "exit_criteria": "flutter analyze clean. Game builds. Banner + interstitial + rewarded still functional in the existing screens with no UI changes."
      },
      {
        "id": "T8",
        "title": "Fix IAP — server-validated, idempotent, restorable",
        "steps": [
          "Audit lib/services/purchase_service.dart end-to-end. Document the bugs found as a comment at the top of the new file before fixing.",
          "Rewrite purchase_service.dart to be platform-symmetric. Use the official in_app_purchase package, but route ALL receipt validation through a Cloud Function callable (`validateReceipt`) hosted in functions/. The Cloud Function must:",
          "  1. Accept { platform: 'android'|'ios', productId, purchaseToken | jwsRepresentation, isRestore }.",
          "  2. For Android: call Google Play Developer API subscriptionsv2 or purchases.products.get with the package's service account.",
          "  3. For iOS: verify the JWS against App Store Server API sandbox or production endpoint.",
          "  4. Check purchaseState / status === 0 (purchased / active).",
          "  5. Use Firestore transaction to write users/{uid}.isPremium = true and record the orderId in users/{uid}.processedOrders (a Set), so re-submission of the same receipt is a no-op.",
          "  6. Return { isPremium: bool, expiresAt: int|null }.",
          "On the client: NEVER trust the local purchase stream alone. After any purchase, await the Cloud Function, then set isPremiumUnlocked from the server response, then write shared_preferences. If the Cloud Function fails, schedule a retry (3 attempts, exponential backoff 1s/3s/9s) before declaring failure to the user.",
          "Restore flow: on auth state change to signed-in, on app resume, and on user tapping 'Restore Purchases', call _iap.restorePurchases(), await all pending purchase updates, push each receipt through the same Cloud Function, and update PremiumGate.",
          "Add a SubscriptionTier (one-time remove-ads and monthly remove-ads) behind a single config flag. For v1 ship the one-time only, but the code path must support both so we can A/B later."
        ],
        "exit_criteria": "Manual test: fresh install, sandbox account, buy -> within 4s isPremiumUnlocked is true. Force quit, reinstall -> on first signed-in event, restore runs and isPremium is true within 8s. Tampered receipt -> Cloud Function returns isPremium: false, client does not unlock. Replay same receipt -> Cloud Function is idempotent, no double-write."
      },
      {
        "id": "T9",
        "title": "Wire PremiumGate as the single source of truth",
        "steps": [
          "lib/data/services/monetization_service.dart — already has isPremiumUnlocked. Add a reconcile() method that reads shared_preferences and Firestore users/{uid}.isPremium, picks the truthier one (Firestore wins on conflict if last update within 5 min, else shared_preferences), updates the ValueNotifier, and persists the chosen value back to shared_preferences.",
          "Call reconcile() on auth state change, on app resume, and on every successful purchase/restore.",
          "AdsFacade and AdSlot check PremiumGate before ANY ad request. If isPremiumUnlocked is true, they short-circuit and return AdResult.skipped_premium. No SDK calls, no telemetry, nothing."
        ],
        "exit_criteria": "After successful purchase, the very next ad request is skipped. After refund (set users/{uid}.isPremium=false in console), next app resume re-enables ads within 8s."
      },
      {
        "id": "T10",
        "title": "Add kill switches and remote config",
        "steps": [
          "Add a Firestore document config/ads with: enabledProviders: [applovin_max, unity_ads, admob, startapp], killSwitches: { applovin_max: false, ... }, circuitBreakerThresholds: { consecutiveFailures: 5, fillRateFloor: 0.1 }, preWarmFormats: [interstitial, rewarded, appOpen].",
          "lib/services/ads/remote_config.dart listens to this doc with a 60s polling fallback (don't require real-time listeners — saves battery). On change, apply kill switches (a disabled provider is treated as if its circuit breaker is permanently open).",
          "This lets ops disable a provider from the Firebase console without a release."
        ],
        "exit_criteria": "Setting applovin_max: { killSwitch: true } in Firestore results in the next ad request skipping AppLovin within 60s. Verified in instrumentation logs."
      },
      {
        "id": "T11",
        "title": "Telemetry",
        "steps": [
          "Every ad_requested, ad_loaded, ad_shown, ad_failed, ad_circuit_open, ad_circuit_closed, purchase_started, purchase_succeeded, purchase_failed, purchase_restored event is sent to Firebase Analytics with params { provider, format, latencyMs, reason, sessionId }.",
          "Aggregate counters written hourly to Firestore ad_metrics/{yyyyMMdd}/{provider} with { requests, wins, fillRate, initFailures, loadFailures, showFailures, avgLatencyMs }. Use a Cloud Function scheduled trigger for the hourly job; don't do it on the client.",
          "Crashlytics breadcrumb: 'ad_failed' with the provider and the typed reason. Never the full error stack — that already goes to Crashlytics via the default handler."
        ],
        "exit_criteria": "Events visible in DebugView in real time. ad_metrics collection populates within 1 hour of test traffic."
      },
      {
        "id": "T12",
        "title": "Tests",
        "steps": [
          "test/services/ads/health_test.dart — sliding window correctness, atomic increments.",
          "test/services/ads/circuit_breaker_test.dart — all state transitions, persistence, cooldown cap.",
          "test/services/ads/cache_test.dart — replacement-on-consume, fall-through on failure.",
          "test/services/ads/slot_test.dart — chain selection, timeouts, never-throws contract.",
          "test/services/ads/pre_warmer_test.dart — parallel init, error isolation, ceiling.",
          "test/services/purchase_service_test.dart — happy path, restore, tampered receipt, replay idempotency, timeout, network error.",
          "integration_test/ads_e2e_test.dart — boot app, verify first ad is ready within 1.5s, show rewarded, verify it plays, verify cache refills."
        ],
        "exit_criteria": "flutter test passes. Integration test runs green on a real device (or fails gracefully with a clear 'no real device' message on CI without one)."
      },
      {
        "id": "T13",
        "title": "Documentation and changelog",
        "steps": [
          "CHANGELOG.md: every task in this prompt is one entry. Format: ## [Unreleased] / ### Added / ### Changed / ### Fixed / ### Removed.",
          "docs/ads-and-iap.md: 1-page operator runbook. How to add a new provider. How to read ad_metrics. How to flip a kill switch. How to ship a subscription tier A/B test. The on-call must be able to disable a bad provider in under 60s using only this doc.",
          "Inline Dartdoc on every public class in lib/services/ads/ — at least one paragraph and a usage example."
        ],
        "exit_criteria": "A new engineer reading docs/ads-and-iap.md alone can flip a kill switch, add a provider, and interpret a fill-rate drop."
      }
    ],

    "platform_specific_notes": {
      "android": {
        "permissions_required": ["android.permission.INTERNET", "android.permission.ACCESS_NETWORK_STATE"],
        "manifest_meta": "Add <meta-data android:name=\"com.google.android.gms.ads.APPLICATION_ID\" android:value=\"@string/admob_app_id\"/> via build.gradle. AppLovin MAX SDK key in AndroidManifest. StartApp app ID in AndroidManifest.",
        "google_play_billing_version": "v6+ via the in_app_purchase_android plugin. Server-side validation against Google Play Developer API v3.",
        "test_devices": "Configure test device hashes for AdMob so dev builds don't burn real impressions. Use AppRuntimeConfig.testDeviceIds."
      },
      "ios": {
        "info_plist_keys": [
          "GADApplicationIdentifier (AdMob)",
          "AppLovinSdkKey",
          "UnityAds placement IDs declared in UnityAds config",
          "StartApp app ID"
        ],
        "sk_ad_network_items": "Add the SKAdNetworkItem entries published by AppLovin, Unity, and StartApp — they publish an official list, copy from each provider's docs.",
        "app_tracking_transparency": "Gating on ATT consent: when the consent flow (onboarding_consent_screen.dart) returns ATT=denied, set the AdRequestConfiguration.tagForUnderAgeOfConsent=true AND pass the UMP consent string to AppLovin MAX. Never show a personalised ad to a denied user.",
        "storekit": "StoreKit 2 is the future but StoreKit 1 is still required by in_app_purchase 3.x. Use it; do not require StoreKit 2 yet."
      },
      "web": "Out of scope for ads. The product does not monetise the web build. AdsService.isEnabled must return false on web unconditionally until the product owner explicitly enables it.",
      "windows_macos_linux": "Out of scope for ads. isEnabled returns false. IAP must still function on macOS if you ever ship a Mac build — keep the iOS code path reusable for macOS via the macos folder."
    },

    "config_schema": {
      "AppRuntimeConfig additions": {
        "providers": {
          "applovin_max": { "enabled": true, "sdk_key_env": "APPLOVIN_SDK_KEY", "banner_unit_id_env": "APPLOVIN_BANNER_UNIT_ID", "interstitial_unit_id_env": "APPLOVIN_INTERSTITIAL_UNIT_ID", "rewarded_unit_id_env": "APPLOVIN_REWARDED_UNIT_ID" },
          "startapp":    { "enabled": true, "app_id_env": "STARTAPP_APP_ID" }
        },
        "chain": {
          "rewarded":     ["applovin_max", "admob", "unity_ads", "startapp"],
          "interstitial": ["applovin_max", "unity_ads", "admob", "startapp"],
          "app_open":     ["admob", "applovin_max", "startapp"],
          "banner":       ["applovin_max", "admob", "unity_ads", "startapp"]
        },
        "timeouts_ms": { "load_per_provider": 4000, "slot_total": 8000, "prewarm_ceiling": 10000 },
        "circuit_breaker": { "consecutive_failures_to_open": 5, "fill_rate_floor": 0.10, "cooldown_initial_ms": 30000, "cooldown_max_ms": 300000 }
      }
    },

    "anti_patterns_to_refuse": {
      "await_in_a_loop_for_each_provider": "Use Future.forEach with a chain, not serial awaits. Serial init doubles cold-start cost.",
      "catching_all_exceptions_silently_without_telemetry": "Every swallowed exception logs a typed reason to telemetry. Never bare 'catch (e) {}'.",
      "trusting_local_purchase_status": "Always validate server-side. A rooted device or jailbroken device can fake the local stream.",
      "using_sharedpreferences_as_only_source_of_truth_for_premium": "shared_preferences is the cache. Firestore is the truth. Re-fetch on resume.",
      "showing_an_error_dialog_when_no_ad_available": "Ads are a side effect, not a feature. Failure must be silent for the user.",
      "loading_banner_in_a_build_method": "Banner should be requested once on screen mount, never on rebuild. Cache it."
    },

    "definition_of_done": [
      "All 13 tasks in this prompt complete with their stated exit_criteria.",
      "flutter analyze --no-fatal-infos returns 0 errors and 0 warnings on changed files.",
      "flutter test passes 100%.",
      "Manual test on a real Android device: install fresh, sign in, trigger 3 rewarded shows + 3 interstitials + 1 app-open across 3 cold starts. All show successfully. No crashes in Logcat.",
      "Manual test on a real iOS device: same scenario.",
      "Manual IAP test: buy in sandbox, see ad disappear within 4s. Force-kill, reinstall, sign in, restore, see ads still gone. Refund via console, force resume, see ads return.",
      "Kill switch test: set applovin_max: { killSwitch: true } in Firestore. Within 60s, AppLovin is bypassed. Restore the flag, within 60s AppLovin is back in the chain.",
      "CHANGELOG.md and docs/ads-and-iap.md updated.",
      "No new entry in pubspec.yaml is left without a CHANGELOG line."
    ],

    "deliverables": {
      "code_files": [
        "pubspec.yaml",
        "lib/services/ads/registry.dart",
        "lib/services/ads/provider.dart",
        "lib/services/ads/health.dart",
        "lib/services/ads/circuit_breaker.dart",
        "lib/services/ads/cache.dart",
        "lib/services/ads/slot.dart",
        "lib/services/ads/pre_warmer.dart",
        "lib/services/ads/remote_config.dart",
        "lib/services/ads/providers/admob_provider.dart",
        "lib/services/ads/providers/unity_provider.dart",
        "lib/services/ads/providers/applovin_provider.dart",
        "lib/services/ads/providers/startapp_provider.dart",
        "lib/services/ads_facade.dart (refactored, same public API)",
        "lib/services/purchase_service.dart (rewritten)",
        "lib/data/services/monetization_service.dart (reconcile added)",
        "lib/config/app_runtime_config.dart (new provider config)",
        "functions/src/validateReceipt.ts (Cloud Function)",
        "android/app/src/main/AndroidManifest.xml (meta-data + permissions)",
        "ios/Runner/Info.plist (all 4 SDK keys + SKAdNetworkItems)",
        "test/services/ads/*.dart",
        "test/services/purchase_service_test.dart",
        "integration_test/ads_e2e_test.dart"
      ],
      "doc_files": ["CHANGELOG.md", "docs/ads-and-iap.md"]
    },

    "output_format": {
      "rules": [
        "Return ONE final markdown report at the end, in the style: # Summary / ## What changed / ## How to verify / ## Risks / ## Rollback.",
        "During execution, return code blocks only — no prose between code blocks. The model is doing the work, not narrating.",
        "If a task is blocked by a missing decision (e.g. a Cloud Function service account setup), STOP that task, list the blocker, and continue with the next unblocked task. Do not invent credentials.",
        "If a package version conflict occurs, document the conflict and pin to the highest compatible version. Do not loosen the SDK constraint."
      ]
    }
  }
}
```

---

## Notes for the human running this

- **Don't paste the entire JSON into a chat that already has system instructions.** Use a tool that lets you set the system + user messages explicitly (Claude API, Cursor Agent, Aider `--system-prompt-file`, Codex, etc.). Otherwise the chat's existing instructions may override the prompt.
- **Update `context.verified_at` and the `what_is_broken_or_missing` list** before running if your code has drifted.
- **For T8 (IAP fix), you need real credentials**: Google Play service account JSON for receipt validation, App Store Server API key for iOS. Get those *before* the AI gets to T8 or it will block. Same for T3 — you need real ad unit IDs (or accept that the build will use test IDs).
- **This prompt is designed to be re-runnable.** After the first run, you can re-issue it with `intent` flipped to `regression_audit` to catch drift.
