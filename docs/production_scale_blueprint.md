# FearFlip Production Scale Blueprint

## Target Architecture

### Presentation
- `lib/presentation/screens/*`
- `lib/presentation/widgets/*`
- `lib/presentation/controllers/*` (new)
- `lib/presentation/providers/*`

Rules:
- UI emits intents only.
- No Firebase calls from UI.

### Domain
- `lib/domain/entities/*`
- `lib/domain/usecases/*`
- `lib/domain/rules/*`

Rules:
- Pure Dart only.
- All gameplay state transitions through use cases and strategy rules.

### Data
- `lib/data/services/*`
- `lib/data/repositories/*`

Rules:
- Repository interfaces define contracts.
- Infrastructure services are replaceable with mocks/fakes.

### Engine
- `lib/engine/fear_flip_game.dart`
- `lib/engine/components/*`
- `lib/engine/systems/*`

Rules:
- Flame-specific orchestration only.
- Engine consumes domain use cases.

## Implemented in this migration
- Deterministic domain state model (`GameState`, `Player`).
- Strategy rules (`GravityRule`, `FlipRule`, `DifficultyRule`).
- Engine adapter (`FearFlipGameEngine`) to run frame updates.
- In-memory repository for deterministic tests.
- Deterministic game-loop tests in `test/engine/fear_flip_game_engine_test.dart`.

## Performance checklist (60 FPS)
- Keep frame work in `update()`, not `render()`.
- Keep game surface under `RepaintBoundary`.
- Avoid `setState` for per-frame updates.
- Pool short-lived entities (particles, hazards).
- Profile on low/mid devices via Flutter DevTools:
  - Frame chart: no spikes >16ms.
  - CPU sampling around heavy maze/rule updates.
  - Memory allocation while simulating high object churn.

## Play Store readiness checklist

### App and build
1. Verify Android `applicationId` is final.
2. Set final app name, icon, splash.
3. Ensure latest `targetSdk` and Gradle plugin compatibility.

### Security and compliance
1. Add Privacy Policy URL to Play listing.
2. Confirm Firebase usage and data disclosure in Data Safety form.
3. Review runtime permissions and remove unused ones.

### Release signing
1. Generate release keystore.
2. Configure signing in `android/app/build.gradle.kts`.
3. Store secrets outside source control.

### QA and rollout
1. `flutter test` and smoke test release build.
2. Build AAB: `flutter build appbundle --release`.
3. Upload to Internal Testing.
4. Promote to Closed Testing.
5. Roll out production in staged percentages.

## Next migration wave
- Move remaining gameplay logic from `presentation/gameplay/game_screen.dart` into domain rules/use cases.
- Extract a dedicated `SettingsScreen` and thin UI controller/view model.
- Add integration tests for full play loop + revive + leaderboard submit.
- Add frame-budget CI check using scripted update loop benchmarks.
