# Play Release Checklist

## Scope
This checklist maps production readiness requirements to concrete repository tasks for FearFlip.

## Owners
- Gameplay Engineer: balancing, fairness validators, AI readability
- Backend Engineer: Firestore rules, leaderboard integrity, remote knobs
- Mobile Engineer: ad compliance, crash resilience, performance
- QA/Release Owner: test gates, rollout controls, incident runbooks

## Gates Before Production
1. Gameplay fairness
- All stage/runtime constraints enforced in code paths.
- Route guarantee checks pass in automated simulations.
- No chaos overlap beyond max 2 active mechanics.

2. Backend security
- Firestore rules deployed from `firestore.rules`.
- Emulator tests validate reject/allow paths for leaderboard and runs.
- Auth linking path guest -> Google verified on real device.
- Google provider enabled in Firebase Authentication.
- Release keystore SHA-1 and SHA-256 are registered in Firebase for the active Android package.
- `android/app/google-services.json` package and cert entries confirmed against `android/release.properties` + signing report.

3. Ads and policy
- Production Android/iOS ad IDs loaded from environment config.
- Android release `fearflip.admob.appId` and iOS `ADMOB_APP_ID` point to the real AdMob app IDs.
- Interstitial cooldown and first-fail suppression enabled.
- Rewarded ads remain user-initiated only.
- Emergency revive uses rewarded ads only and waits up to 30 seconds for rewarded inventory.
- Consent flow (UMP) integrated where required.
- Consent debug geography and test-device IDs are removed from release builds.
- Privacy/terms/account deletion URLs are configured and reachable.
- In-app account deletion queues a backend deletion request and handles recent-login failures.

4. Reliability
- Crashlytics enabled with gameplay breadcrumbs.
- Offline fallback behavior verified for startup, auth, leaderboard submit.
- ANR and crash budgets checked in pre-launch reports.

5. Store operations
- Privacy policy URL published and linked in-app.
- Account deletion URL published and linked in Play Console.
- Data safety form completed accurately for Firebase + ads SDKs.
- Content rating completed.
- Store listing assets finalized (icon, screenshots, feature graphic).

## Release Train
1. Internal testing
- Validate sign-in, gameplay, ads, leaderboard writes.

2. Closed testing
- Minimum 50 testers.
- Monitor crash-free users, ANR, ad errors, leaderboard latency.

3. Staged rollout
- 5% -> 20% -> 50% -> 100% with stop criteria.

## Stop Rollout Criteria
- Crash-free users below target threshold.
- ANR above target threshold.
- Critical auth failures or score-write failures.
- Revenue-impacting ad failure spike.

## Hotfix Path
1. Triage incident severity.
2. Disable risky knobs through remote config where possible.
3. Ship patch build with incremented versionCode.
4. Postmortem with root cause and prevention action.
