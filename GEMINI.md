# FearFlip Project Instructions

## 🚀 Project Overview
FearFlip is a Flutter + Flame based horror maze game featuring:
- Procedural maze generation
- Reality flipping mechanic
- AI-driven "Devil" enemy that dynamically adjusts speed

**Core Goal:** Create a tense but fair gameplay loop with strong monetization balance.

---

## 🧠 AI Behavior Rules (VERY IMPORTANT)
When modifying this project:
1. **DO NOT break gameplay balance.**
2. **Prioritize:** Fairness > Difficulty | Smooth gameplay > Complex logic.
3. **Avoid sudden difficulty spikes.**
4. **Optimize for Mobile:** Mobile-first performance is mandatory.

---

## 🎮 Core Gameplay Systems

### Player
- Grid/tile-based movement.
- Must feel responsive and predictable.

### Devil AI
- Must feel threatening BUT fair.
- Uses distance-based speed logic:
  - **If CLOSE to player:** Slow down.
  - **If FAR from player:** Speed up.
- **NEVER ALLOW:** Instant catches or unavoidable situations.

---

## ⚙️ Difficulty Balancing Rules
- **Early Stages (1–10):** Easy onboarding.
- **Mid Stages (10–25):** Moderate tension.
- **Beyond Stage 25:** Increase complexity, NOT unfair speed.
- **Devil Tuning Guidelines:** Min speed should allow escape; Max speed should pressure but not cause instant death.

---

## 💰 Monetization Logic

### Ads
- **Banner Ads:** Allowed in non-gameplay screens only.
- **Rewarded Ads:** Used ONLY for revive. Max 3 revives per stage cycle (1–25).
- **NEVER:** Force ads aggressively or break gameplay flow with ads.

### Premium Users
- **No Ads:** All ad placements must be suppressed.
- **Free Revive:** Revive benefit granted without showing an ad.

---

## 🏗 Architecture & Tech Stack
- **Framework:** Flutter (Dart) & Flame Engine.
- **Backend:** Firebase (Auth, Firestore, Cloud Functions, Analytics, Crashlytics).
- **State Management:** Provider-like pattern using `ChangeNotifier` and `AnimatedBuilder`.

---

## 📂 Important Directories
- `lib/engine/`: Core gameplay logic (Flame components and systems).
- `lib/domain/`: Maze generation, procedural rules, and entities.
- `lib/services/`: Ads, IAP, Auth, and other backend integrations.
- `lib/presentation/`: UI screens, widgets, and controllers.
- `functions/`: Firebase Cloud Functions (TypeScript) for purchase verification.

---

## 🔧 Coding Guidelines
- **Small Targeted Changes:** Use `replace` tool for surgical edits; avoid full-file rewrites.
- **Separation of Concerns:** Keep UI, Logic, and Services distinct.
- **Dependency Injection:** Inject services into controllers/engines to facilitate testing.
- **Configuration:** Keep game balance and config values inside `AppRuntimeConfig`.

---

## 🧪 Testing Rules
- **Gameplay Logic:** Every change to gameplay systems must be accompanied by a test case.
- **No Hardcoding:** Use configuration constants.
- **Validation:** Run `flutter test` after every significant logic update.

---

## ⚡ Performance Rules
- **Flutter:** Avoid heavy/unnecessary widget rebuilds.
- **Flame:** Optimize `update()` loops; keep FPS stable for mobile devices.

---

## 🛠 Common Commands

**Development & Testing:**
```bash
flutter run
flutter test
```

**Backend Deployment:**
```bash
cd functions && npm run build && firebase deploy --only functions
```
