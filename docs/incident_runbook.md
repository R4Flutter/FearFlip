# Incident Runbook

## Purpose
Provide a fast, repeatable path for diagnosing and recovering live production issues.

## Severity Levels
- Sev 1: App unusable, major crash loop, auth outage, or monetization outage.
- Sev 2: Significant degradation with workaround.
- Sev 3: Minor issue without major user impact.

## Detection Sources
- Firebase Crashlytics alerts
- Play Console vitals (ANR/crash)
- Firestore error-rate dashboards
- Ad load/show failure trends

## Immediate Response
1. Assign incident commander.
2. Freeze non-essential releases.
3. Snapshot latest metrics and affected versions.
4. Evaluate remote kill-switch options (ads frequency, chaos intensity, feature flags).

## Technical Triage Checklist
1. Confirm scope
- Which versions?
- Which devices/OS?
- Which regions?

2. Confirm trigger
- Gameplay event (flip/chaos/spawn)?
- Auth transition?
- Leaderboard write path?
- Ad lifecycle callback?

3. Reproduce
- Use seed/build metadata where available.
- Use emulator + one physical affected class device.

## Containment Actions
- Reduce rollout percentage.
- Pause rollout if Sev 1.
- Disable risky runtime knobs through remote config.
- Temporarily route to stub behavior if backend dependency fails.

## Recovery
1. Patch and validate with focused regression tests.
2. Promote build through internal then closed testing.
3. Resume staged rollout conservatively.

## Postmortem
- Timeline
- Root cause
- User impact
- Detection gaps
- Preventive actions with owners and due dates
