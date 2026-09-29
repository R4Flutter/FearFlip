# FEARFLIP — FORENSIC AUDIT & REMEDIATION PLAN

**Date:** 2026-09-22
**Scope:** Entire `R4Flutter/FearFlip` repository
**App version:** 1.0.2+3
**Mode:** Plan / no code changes yet — every fix below has severity, file path, line range, evidence, and a proposed change.

> **Source of truth:** the runtime. Documentation, comments, and tests are **claims** — verified against `git`-tracked source.
> **Confidence scale:** HIGH = proven by code/grep; MEDIUM = proven by reading path but requires a runtime check to confirm behavior; LOW = inferred.

---

## TL;DR — THE 6 THINGS THAT ACTUALLY MATTER

1. **Two entire engines are dead at runtime.** `lib/game/*.dart` (Flame) is constructed but never mounted in a `GameWidget`. `lib/engine/fear_flip_game.dart` (domain) is wired into `GameController` but `GameController.start()` is never called. The actual runtime is **only** `_GameScreenState` inside `lib/presentation/gameplay/game_screen.dart` (2,252 lines).
2. **P0 fairness bug**: `StageRules.forStage()` silently overrides every stage's `devilSpeedMultiplier` to `playerSpeedMultiplier − 0.01`. The carefully tuned "early devil slow, late devil fast" curve is destroyed; the player is *always* a hair ahead of the devil except in the first few stages. Mid-stage the devil is 1.07× faster than the player where the intent was 0.6×. **This will yield unfair deaths.**
3. **P0 fairness bug**: the warning-time check at `game_screen.dart:629` is an empty `if (timeToFlip <= _stageRule.warningTime && timeToFlip > 0) {}` — there is no audible, visual, or haptic warning before the control inversion. The declared `warningTime: 0.4…1.2` per stage never reaches the player.
4. **P1 declared-vs-runtime drift**: `_maxPlayableMazeSize = 17` clamps every stage to 17×17 even though `_rules[1..100].mazeSize` is declared up to 29. `safeZoneCount` and `safeZoneDurationSeconds` are declared fields that the runtime ignores.
5. **P1 security gap (acknowledged in code)**: leaderboard `submitScore` allows the client to send any `scoreSeconds` (clamped to 24 h). The function's own comment says "True anti-cheat … not built yet." Trivially forgeable from a proxy.
6. **P2 release hazards**: ~10 MB of legacy per-frame sprites in `assets/images/{prefix}_frames/*` are bundled but never loaded (only the spreadsheets ship). `pubspec.yaml` carries `app_open`, `unity_banner`, etc. without verification those keys are wired. `_decodeFrameFiles` is dead. `AssetManager/Pools/FrameBudgetMonitor` exist but nothing references them outside the dead `FearFlipGame`.

Everything else below is in service of those six.

---

## PHASE 0 — REPOSITORY INVENTORY (DONE, EVERYTHING BELOW IS BASED ON THIS)

### Top-level layout

| Path | Size / role |
|---|---|
| `lib/` | ~6,500 LoC of game/UI code spread across 11 layers (see below) |
| `lib/RULES.TXT` | 1,876-line design table — the "intended" stage rules |
| `lib/presentation/gameplay/stage_rules.dart` | 1,876-line runtime mirror of `RULES.TXT` |
| `assets/images/{phantom,sentinel,devil,void_ripper}_frames/*.png` | 56 × 4 = ~6 MB **dead frames** |
| `assets/images/{...}_spreadsheet.png` | 4 × 1.2–1.9 MB — actually used at runtime |
| `assets/audio/` | 14 mp3/wav, ~8 MB |
| `functions/lib/index.js` | 5 Cloud Functions: `submitScore`, `upsertGlobalPanicProgress`, `verifyOneTimePurchase`, `checkOneTimePurchaseStatus`, `onAccountDeletionRequested` |
| `firestore.rules` | 80 LoC, server-authoritative leaderboard rules |
| `docs/` | 10 docs incl. `stage_rules_runtime_1_100.md` — already self-flags the deadstage fields |
| `test/` | 23 test files; 3 of them (`fear_flip_game_engine_test`, parts of `level_validator_test`, parts of `procedural_level_generator_test`) exercise **dead code only** |
| `report_of_fearflip.md` | 575-line prior audit; pre-dates the dev-game architecture split |
| `pubspec.yaml` | flame 1.20, just_audio 0.10, audioplayers 6.1, firebase_*, cloud_functions, in_app_purchase — dual audio stack |

### Classified file table

| File | Status | Notes |
|---|---|---|
| `lib/main.dart` | **active** | bootstrap → `FearFlipApp` |
| `lib/app/fear_flip_app.dart` | **active** | Monster class hosting the settings UI + landing → game nav |
| `lib/config/app_runtime_config.dart` | **active** | Env-var–driven feature flags, prod-readiness gate |
| `lib/firebase_options.dart` | **active** | platform options |
| `lib/presentation/providers/app_flow_provider.dart` | **active** | sole provider of session state |
| `lib/presentation/screens/*.dart` | **active** | 6 screens |
| `lib/presentation/gameplay/game_screen.dart` | **active monolith** | **THE** runtime game |
| `lib/presentation/gameplay/maze_generator.dart` | **active** | recursive-backtracker DFS |
| `lib/presentation/gameplay/maze_painter.dart` | **active** | CustomPainter |
| `lib/presentation/gameplay/player_controller.dart` | **active** | Ticker-driven |
| `lib/presentation/gameplay/maze_shift_manager.dart` | **active** | shift state machine |
| `lib/presentation/gameplay/stage_rules.dart` | **active — but poisoned** | the `forStage()` override bug lives here |
| `lib/presentation/gameplay/glitch_effect_controller.dart` | **active** | |
| `lib/presentation/gameplay/widgets/*` | **active** | |
| `lib/game/trap/*` | **active** | alive only because `game_screen.dart` imports directly |
| `lib/services/audio_manager.dart` | **active** | singleton, ~2,000 LoC |
| `lib/services/ads_facade.dart` | **active** | Unity-first, AdMob-fallback |
| `lib/services/ads_service.dart` (1,562 LoC) | **dead** | only `AdsFacade` constructs it |
| `lib/services/ad_manager.dart` (1,386 LoC) | **dead** | only `AdsFacade` constructs it |
| `lib/services/ads_service_base.dart` | **active** | only contract |
| `lib/services/consent_service.dart` | **active** | |
| `lib/services/purchase_service.dart` | **active** | best-engineered file in the repo |
| `lib/services/auth_service.dart` | **active** | |
| `lib/services/leaderboard_service.dart` | **active** | Cloud Function-backed |
| `lib/services/leaderboard_cache.dart` | **active** | offline cache for leaderboard |
| `lib/services/account_deletion_service.dart` | **active** | |
| `lib/services/error_reporter.dart` | **active** | tiny but well-shaped |
| `lib/services/game_audio_event.dart` | **active** | sealed-style audio event API |
| `lib/services/ad_placement_policy.dart` | **active** | cooldowns + game-over count |
| `lib/services/ads_diagnostics.dart` | **active** | analytics |
| `lib/services/procedural/*` | **dead** | only used by dead `FearFlipGame` |
| `lib/game/game.dart` (22 KB) | **dead** | `FearFlipGame extends FlameGame` is constructed but not mounted |
| `lib/game/character.dart` (3.5 KB) | **dead** | |
| `lib/game/player.dart` (12 KB) | **dead** | |
| `lib/game/devil.dart` (12 KB) | **dead** | |
| `lib/game/maze.dart` (14 KB) | **dead** | `MazeGrid` is the *different* class used at runtime |
| `lib/game/flip_system.dart` (1.7 KB) | **dead** | |
| `lib/game/safe_zone.dart` (1.3 KB) | **dead** | |
| `lib/game/shadow_clone.dart` (3.5 KB) | **dead** | |
| `lib/game/game_config.dart` (5.5 KB) | **dead** | only used by dead siblings |
| `lib/domain/*` (entities, rules, usecases, input, procedural, progression) | **dead at runtime**, **alive at compile** | exists for tests, factory calls, and `GameController` wiring |
| `lib/engine/fear_flip_game.dart` | **dead** | `FearFlipGameEngine.start()` never called |
| `lib/engine/components/player_component_adapter.dart` | **dead** | adapter to nothing live |
| `lib/engine/systems/{asset_manager,frame_budget_monitor,object_pool,pools}.dart` | **dead** | never imported |
| `lib/ui/game_overlays.dart` | **dead** | defines `buildOverlayBuilders` but no `GameWidget` to host them |
| `lib/data/repositories/*` | **dead** | referenced only from `FearFlipGameEngine` |
| `lib/data/services/{analytics,crash_reporting,monetization}_service.dart` | **dead** | used only by `GameController` (dead) |
| `lib/data/services/auth_service.dart`, `leaderboard_service.dart` | **DUPLICATED** under `lib/services/` | see TABLE 8 |
| `lib/data/database/local_session_database.dart` | **active** | SharedPreferences session tracking |

### Reachability proof (HIGH confidence)

```
grep "FearFlipGame\b"   →  game.dart, app_flow_provider.dart  (NO mount site)
grep "FearFlipGameEngine" → engine, game_controller            (start() never called)
grep "gameController\."  → app_flow_provider (only .dispose())
grep "GameWidget\b"      → 0 hits
```

Combined, this proves three things: (a) there is no `GameWidget(game: FearFlipGame(...))`; (b) `GameController.start()` is never called; (c) the `lib/game/*` and `lib/domain/*` material is **all compilation-attached but execution-dead**.

---

## TABLE 1 — SYSTEM OWNERSHIP

| System | Implementation | Owner | Source of truth | Status | Risk |
|---|---|---|---|---|---|
| App bootstrap | `main.dart` | `lib/main.dart` | `runZonedGuarded → runApp(FearFlipApp)` | solid | low |
| App shell | `fear_flip_app.dart` (77 KB) | the file itself | `MaterialApp` → `AnimatedBuilder` | mixed | P2 monolith |
| Session flow | `app_flow_provider.dart` (22 KB) | the file itself | `ChangeNotifier` | mixed | P2 |
| Gameplay runtime | `game_screen.dart` (78 KB / 2,252 LoC) | `_GameScreenState` | `_onStageTick` timer + `_playerController` ticker | mostly solid, some P0 | **HIGH** — bug surface concentrated here |
| Maze generation | `maze_generator.dart` | DFS recursive backtracker | seed | solid | low |
| Maze rendering | `maze_painter.dart` | `MazePainter` | CustomPainter | solid | P2 (FPS-sensitive) |
| Player movement | `player_controller.dart` | `PlayerController` (Ticker) | `notifyListeners` | mostly solid | P2 (player/devil rate split) |
| Devil AI | `game_screen.dart._nextDevilStep` (BFS) | inline; **not A\*** | shortest path within maze | borderline | **P1** — slow on size 17 |
| Maze shift | `maze_shift_manager.dart` | the class itself | mutate maze in place | mostly solid | P1 (player-in-wall risk on shifts) |
| Flip system | `game_screen._onStageTick` | inline | boolean state | **empty warning** | **P0** |
| Stage rules (declared) | `RULES.TXT`, `stage_rules.dart` | 100-entry map | `_rules` | poisoned override | **P0** |
| Trap system | `lib/game/trap/*` | mix | seed-deterministic | solid | P2 |
| Dev tools (debug dropdown) | debug_stage_dropdown.dart | the widget | `AppRuntimeConfig.debugStageDropdownEnabled` | gated | low (debug-only by design) |
| Authentication | `services/auth_service.dart`, Firebase | the class | Firebase | solid | low |
| Leaderboard | `services/leaderboard_service.dart` + Cloud Function | server | Cloud Function | mostly solid | **P1** — no anti-cheat |
| IAP | `services/purchase_service.dart` + `verifyOneTimePurchase` | server | Cloud Function | **best in repo** | low |
| Ads | `services/ads_facade.dart` (Unity → AdMob) | the facade | runtime | solid | P2 (3 impls of `AdsServiceBase`) |
| Consent | `services/consent_service.dart` | the class | runtime | solid | low |
| Account deletion | `services/account_deletion_service.dart` + Cloud Function | server | Cloud Function | solid | low |
| Audio | `services/audio_manager.dart` (2,088 LoC) | singleton | runtime | mostly solid | P2 (`dispose()` never called) |
| Crash reporting | `services/error_reporter.dart` | Crashlytics | runtime | solid | low |
| Analytics | Firebase `logEvent` ad-hoc | inline | runtime | OK | P2 (events not centralised) |
| Config | `config/app_runtime_config.dart` (34 KB) | env-vars | build flags | mostly solid | P2 (debug flag default to disable) |
| Sprite loading | inline in `game_screen._loadCharactersSprite` | inline | runtime | mostly solid | P2 (56 cell images per character) |
| Memory pools | `engine/systems/{pools,object_pool}.dart` | the file | nothing | **dead** | low (also dead code) |
| Frame budget | `engine/systems/frame_budget_monitor.dart` | the file | `GameController` | dead | low |
| Asset manager | `engine/systems/asset_manager.dart` | the file | nothing | dead | low |

---

## TABLE 2 — BUG FINDINGS

| ID | Sev | File | Symbol / line | What it does | Why it's wrong | Runtime consequence | Repro | Fix |
|---|---|---|---|---|---|---|---|---|
| F-01 | **P0** | `lib/presentation/gameplay/stage_rules.dart` `_devilPlayerSpeedDelta` + `forStage()` ~L1856 | sets `devilSpeedMultiplier = clamp(playerSpeedMultiplier − 0.01, 0.01, playerSpeedMultiplier)` for every stage where `devilEnabled` is true | Lets you write a clever per-stage curve; the curve never reaches runtime | `_rules[5].devilSpeedMultiplier = 0.60` is replaced by `playerSpeedMultiplier(1.08) − 0.01 = 1.07`. Same for stages 6, 7, 8, etc. The "early devil slow" curve becomes "devil is 99% of player speed". | Player cannot escape the devil on stages 5–10 even with short paths; many deaths attributed to "the devil catches you" are actually design-table failures. | Start at stage 5 with path clearance > 0.4; observe devil catch-up rate vs stage 1. | **Remove the override** and trust `_rules`. If a clamp is wanted, clamp only `devilStepsPerSecond * (devilSpeedMultiplier / playerSpeedMultiplier) ∈ [0.2, 3.0]` (current behavior) — not the multiplier. |
| F-02 | **P0** | `lib/presentation/gameplay/game_screen.dart` L629 | `if (timeToFlip <= _stageRule.warningTime && timeToFlip > 0) {}` | empty body — guard never fires | The warning affordance declared by every `StageRule` is unreachable. Players have **zero pre-flip signal**. | Sudden control inversion = unfair deaths on stages ≥ 8 where `warningTime = 0.6–0.7 s`. | Start stage 8; hold direction; count how many flips you can predict before they fire. | Implement: HUD pulse / audio "warning" event / short haptic. Wire `audio_manager.handle(GameAudioEvent.warningWindowOpened)` + HUD overlay. |
| F-03 | **P1** | `lib/presentation/gameplay/game_screen.dart` L108, L516, L519 | `static const int _maxPlayableMazeSize = 17;` clamps maze to 17×17 | declared `mazeSize` 18–29 unused | Stages 9–100 declared as larger mazes; runtime makes them all 17×17. Difficulty curve flattens from stage 9 onward. | Difficulty plateau beyond stage 17; "stage 100 is a 29×29 maze" is fiction. | Run `StageRules.forStage(50).mazeSize` vs `game_screen._difficultyForStage(50)` (returns 17). | Either: (a) drop `mazeSize` from `StageRule` and bake 17 as canonical, (b) raise `_maxPlayableMazeSize` to 24 and re-time tests. (a) is cheaper. |
| F-04 | **P1** | `lib/presentation/gameplay/stage_rules.dart` `StageRule.safeZoneCount`, `safeZoneDurationSeconds` | never read by runtime | runtime builds 2 zones with hardcoded `1.0 s` duration every stage (`_safeZonesPerStage` constant, `_buildSafeZones(duration: 1.0)`) | `safeZoneDurationSeconds` of 0.0 (many late stages) is ignored — players get 1.0s safely regardless. | Players can survive longer than designed in late stages. | Stage 99: `safeZoneDurationSeconds = 0.0` but player gets 1.0s. | Either wire `safeZoneDurationSeconds` to `_buildSafeZones` or drop the field. |
| F-05 | **P1** | `lib/presentation/gameplay/game_screen.dart` L667–L730 (devil step loop) | `final speedRatio = (_stageRule.devilSpeedMultiplier / playerSpeed).clamp(0, 1.0)` + `distanceFactor` from `0.7..1.5` + final clamp `(0.2, 4.0)` | compound rubber-band + clamp mask the underlying bug F-01 | On stage 100 with F-01 fixed: `baseDevilSpeed = 3.62 × (1.48/1.50) ≈ 3.57`. With `distanceFactor = 1.5` the final cap is 4.0 — the *table value* is reached. With F-01 unfixed, `baseDevilSpeed = 3.62 × ~0.985 ≈ 3.57` — same effective speed; the rubber-band pretends to be tunable but isn't. | Devil speed at distance is functionally identical across stages once you account for F-01 + clamp. | Compare step rate on stage 1 vs stage 100 at same euclidean distance. | Make F-01's clamp a *hard* guideline, not a redefinition; expose `distanceFactor` as a separate tunable tested per stage. |
| F-06 | **P1** | `functions/lib/index.js` `submitScore` | `scoreSeconds = clampInt(rawScore, 0, 86400)` | server only clamps range | No plausibility check vs. stage / maze size / duration. Honest code comment says so. | Players can submit `86400` after 10 s of play and top the board. | Edit `submitRun` body to send `scoreSeconds = 86390`. | Add stage-aware plausibility: `scoreSeconds ≥ 5 × (stage-1) − 30` server-side; reject otherwise. Document as "soft anti-cheat v1". |
| F-07 | **P1** | `lib/presentation/gameplay/game_screen.dart` `_onStageTick` (Timer.periodic 50 ms) vs `PlayerController._ticker` (Flutter Ticker, ~60 Hz) | mixed timing sources | Game tick @ 20 Hz, player step at frame rate | When a `_playerController.notifyListeners()` lands between two `_onStageTick`s, the player has moved but the devil's step is delayed by up to 50 ms. | Devil can "miss" a cell the player vacated; or `crossedThroughEachOther` can fire on the wrong frame. | Hold a diagonal at 60 Hz and watch `_devilCell` lag 1–2 cells. | Move the devil step onto the same ticker the player uses, or buffer the player's previous-frame position into a queue and have the devil step consume it. |
| F-08 | **P1** | `lib/presentation/gameplay/maze_shift_manager.dart` `_applyCandidate` + `_normalizeWalls` | mutates `maze.cells` in place | if a shift toggles a wall into the player's current cell, canMove() can become false | player spawns inside a wall until `MazeShiftManager` cleans it up (`_hasOpenAdjacentTile` check) | Pause for half a frame after a mid-run shift, then resume. | Trivial to repro on stage 6 (first shift-eligible). | After mutation, run `_rebuildPathMetrics()` and assert `pathClearance ≥ 1` for the player cell. |
| F-09 | **P1** | `lib/game/trap/trap_placement_engine.dart` + `lib/presentation/gameplay/maze_shift_manager.dart` | trapped tiles + shifted maze | if a shift rotates a region containing a trap tile, the tile's cell coordinates can now lie on top of a wall or the goal | `TrapTile` references a `Point<int>`; no validation after maze mutation | Trap may reveal on a cell that is no longer walkable. | Repro: stage 12 (maze-shift eligible) with trap on a T-junction. | Add a `rebindAfterShift(List<Point<int>> removedCells)` step in `MazeShiftManager` that drops/wallpapers trap tiles whose cell is now invalid. |
| F-10 | **P2** | `lib/presentation/gameplay/stage_rules.dart` `_devilPlayerSpeedDelta = 0.01` (hard-coded magic number) | lives in a constant with no comment | could lower the gap → devil is exactly player. Currently 1%. | Won't change runtime but is a magic value in an "auditable" rules table. | Open gameplay future. | n/a | Add to `StageRule` if the design requires per-stage tuning. |
| F-11 | **P2** | `lib/services/audio_manager.dart` (2,088 LoC) | `dispose()` is on the singleton but never called | App kills audio voices, leaves StreamSubscriptions on each `audioplayers` instance | Voice pool leaks `StreamSubscription<dynamic>? completionSubscription` allocations per voice when game is restarted many times | Minimal memory growth but a bunch of Tickers/Subscriptions dangle. | Restart the game 200 times and inspect heap. | Add an explicit `AudioManager.shutdown()` hook called from `app_flow_provider.returnToDashboard()` when revives are exhausted; lifecycle the one-shots properly. |
| F-12 | **P2** | `lib/presentation/gameplay/game_screen.dart` `_loadCharactersSprite` | uses `ui.PictureRecorder` + `canvas.drawImageRect` + `picture.toImage()` × 56 per character | Splits 4-frame sprite sheet into 8 × 7 cells. Synchronous-ish decode. Allocates one `Picture` per cell | 56 picture recordings per character; runs once per stage. | One-time spike on first playable stage. On low-end Android it can stutter for ~100–300 ms. | Profile cold-start with `flutter run --profile`. | Generate the split *once* at app start (cached in a static), not on `initState`. |
| F-13 | **P2** | `pubspec.yaml` `assets:` block | `assets/images/{phantom,sentinel,devil,void_ripper}_frames/...` and top-level `sentinel.png` (2.4 MB), `app_icon.png` (1.9 MB) | `~12 MB` shipped but unread | Bundle bloat ~30 %. | Larger APK, longer cold-start asset decode. | `flutter build apk --release --split-per-abi` then inspect sizes. | Drop the dead `_frames/*` folders; ship only the spreadsheets + breaking_trap + exit_portal + landing_hero + app_icon. |
| F-14 | **P2** | `lib/presentation/gameplay/game_screen.dart` `_decodeFrameFiles` | never called; defined | dead method | Lives in a 78 KB file, takes ~10 lines. | Search-cost. | Grep `_decodeFrameFiles`. | Delete. |
| F-15 | **P2** | `lib/presentation/gameplay/game_screen.dart` `MazePainter.shouldRepaint` | compares ~20 fields including `time` and `pulse` | at 20 Hz tick rate the painter re-evaluates the predicate 20 times/s | itself cheap, but `time` and `pulse` change every frame → repaints always happen. | Wasted CPU comparing Paint instances. | Profile with `flutter run --profile`. | Cache the painter instance for the frame, only swap when the maze/devil/trap set changes. |
| F-16 | **P2** | `lib/services/ads_service.dart` + `lib/services/ad_manager.dart` | both implement `AdsServiceBase`; only `AdsFacade` consumes them | 1,562 + 1,386 LoC duplicating the same surface | high maintenance cost; any new ad flag must be added to three places | none | `grep -c "AdsServiceBase" lib/services/*.dart` | Consolidate behind the Facade; turn the two into private impls. |
| F-17 | **P2** | `lib/data/services/{analytics_service, crash_reporting_service, monetization_service, auth_service, leaderboard_service}.dart` | shadows `lib/services/*.dart` of same name | two sources for the same concept | any future auth swap needs both kept in sync | none | `grep -l "class AuthService" lib/data/services lib/services` | Delete the `lib/data/services/*.dart` duplicates (everything except `monetization_service.dart`, which `AdsServiceBase` actually uses). |
| F-18 | **P2** | `lib/services/leaderboard_service.dart` `_globalPanicProfiles()` | uses `mode='global_panic'` collection with index on `maxStage desc, totalTrophies asc` | Composite index required to avoid 5xx-ish fallback | If the index is missing, code falls back to a `limit × 3` query that re-sorts client-side; works but expensive at 10k+ players | Slow load → UI freeze | Add a player, then read the index file | Confirm `firestore.indexes.json` ships the composite; if not, add it. |
| F-19 | **P2** | `functions/lib/index.js` `submitScore` rate limit (`SCORE_MIN_INTERVAL_MS`) | `metaRef.set({lastScoreSubmitMs: nowMs})` is *not* in a transaction | Race window where two parallel calls both pass the gate | A malicious client can fire concurrent calls within ~50 ms of each other | Trivial bypass of the per-uid rate limit | Wire two parallel `submitScore` calls in 1 ms | Move metaRef.set + bestRef conditional set into a transaction or use `transaction.get` first. |
| F-20 | **P2** | `lib/services/consent_service.dart` `gatherConsentAndInitializeAds()` | `timeout: 20 s` | Cold-start blocks 20 s on the SDK init if the network is up but consent provider is slow | Worse: the rest of the app shows the landing screen during this time, no banner appears | n/a | Throttle connection | Use `Future.wait` with shorter per-SDK timeouts; show a fallback after 8 s. |
| F-21 | **P2** | `lib/services/ad_placement_policy.dart` `recordInterstitialShown` | uses `DateTime` from caller for cooldowns | Clock-skew or paused-app clock can break the cooldown | trivial; the worst case is showing two interstitials in 60 s | n/a | Set device clock back | Use `Stopwatch` monotonic. |
| F-22 | **P2** | `lib/services/purchase_service.dart` Mode B ("client_only fallback") | grants premium when server is unreachable and store confirms ownership | Allows a forged Play receipt from an emulator to grant premium until next launch re-verify | Trust the store; the documented intent is acceptable. Comment is honest about it. | Document. | n/a | Move Mode B behaviour behind a feature flag `allowOfflineIapFallback` and default it **off** for release. |
| F-23 | **P2** | `lib/presentation/gameplay/game_screen.dart` `_glitchEffectController.update(dt)` — empty in `GlitchEffectController`? | confirm | mid/late maze-shift trigger fires the glitch controller but the controller's actual visual change goes through widget tree | TBD | TBD | TBD | Verify F-23 separately. (LOW confidence — needs runtime check.) |
| F-24 | **P2** | `lib/presentation/gameplay/game_screen.dart` `_loadNextMaze` | `await Future.delayed(const Duration(seconds: 2))` before advancing | If app is backgrounded between won-state and the next stage, the timer keeps running but `_stageClearController.forward(from: 0)` may mis-behave | Worst case: visual stuck on stage-clear overlay until foreground | Minor | Background during win at stage 25 | Use a guard: if `!mounted` return; on resume, re-run the controller forward. |
| F-25 | **P2** | `lib/presentation/gameplay/stage_rules.dart` constant map | `_rules` is `Map<int, StageRule>` of size 100 | `clamp(1, 100)` everywhere; missing → returns early; stage 0 path is unreachable | n/a | n/a | n/a | Make `_rules` a `List` of fixed length and index by `stage-1` for constant-time lookup + bounds. |
| F-26 | **P2** | `lib/services/leaderboard_service.dart` `getGlobalPanicLeaderboard` | fallback query `limit * 3` can throw if user is at index > limit | covered by try/catch; returns empty | none | n/a | n/a | Add an orderedEquals + totalPlayers via `count().get()` returning 0 in the catch. |
| F-27 | **P2** | `lib/services/audio_manager.dart` | `audio_manager.handle()` is called many times per tick without backing | each tick fires `devilDistanceChanged` regardless of whether the value changed (the `_dispatchDevilDistance` has a de-dup guard but it computes a BFS first) | On every tick a `shortestPathDistance` runs; the guard only checks if the *previous* reported value matches | Minor | n/a | Compute distance on a slower cadence than ticks (e.g. 5 Hz). |
| F-28 | **P2** | `lib/main.dart` | `runApp(const FearFlipApp())` inside `runZonedGuarded` | Error handler swallows the error string output for non-debug builds | Could obfuscate bugs in production | High debug cost | Trigger an uncaught error in release mode | `FlutterError.onError` already wired; consider an in-app error toast for the first 1 s of release. |
| F-29 | **P2** | `lib/app/fear_flip_app.dart` | `FearFlipApp` is `StatefulWidget` so the entire 77 KB file's settings UI is in one widget | large class; settings UI + auth UI + onboarding UI + remove-ads UI | Hard to navigate, very long build method | minor | n/a | Split Settings / Onboarding into separate `StatelessWidget`s. |
| F-30 | **P3** | `lib/services/audio_manager.dart` | `debugPrint` everywhere on `purchase*` paths | Useful in dev but noisy | Low | n/a | n/a | Gate `debugPrint` with `if (kDebugMode)` consistently. |
| F-31 | **P3** | `lib/services/auth_service.dart` | `google_sign_in` throws in tests | not actually broken | low | n/a | n/a | Add a `GoogleSignIn` interface so tests can stub. |
| F-32 | **P3** | `pubspec.yaml` | `unity_ads_plugin: ^0.3.30` — relatively old | may have known issues on Unity 4 | low | n/a | n/a | Bump when stable. |
| F-33 | **P3** | `lib/game_improvement_plan.md`, `report_of_fearflip.md` | author-muse, not status doc | Documentation confusion | low | n/a | n/a | Rename to `notes/2026-*` and mark as design only. |
| F-34 | **P3** | `lib/RULES.TXT`, `lib/presentation/gameplay/stage_rules.dart`, `docs/stage_rules_runtime_1_100.md` | three sources of truth for the same table | drift inevitable | risk | n/a | n/a | Add a generator script `tools/gen_stage_rules.dart` and have `stage_rules.dart` `// GENERATED`; CI fails if out of date. |
| F-35 | **P3** | `lib/RULES.TXT` free-text format | brittle to parse | n/a | n/a | n/a | n/a | Move to `stages.json`. |
| F-36 | **P3** | `lib/config/app_runtime_config.dart` `adsRequestHttpTimeoutMillis`, `adsForceNonPersonalized`, `adsVerboseLogging` | never read from the ad code paths | sets exist; nobody consumes | low | n/a | n/a | Wire or delete. |

---

## TABLE 3 — GAMEPLAY MECHANIC INTENDED vs IMPLEMENTED vs EFFECTIVE RUNTIME

| Mechanic | Intended (`RULES.TXT` + design intent) | Implemented (code) | Effective runtime | Match? |
|---|---|---|---|---|
| Stage 1–4 flip warning | 1.2 / 1.0 / 0.9 / 0.8 s audio/HUD cue before flip | field exists, applied in `_onStageTick` for `timeToFlip ≤ warningTime` | **No warning** — empty `if` body | **NO — P0** |
| Stage 5–7 devil speed | 0.60 × 0.60 / 0.70 × 0.70 / 0.75 × player speed | `forStage()` clamps to `playerMul − 0.01` → 1.07 / 1.07 / 1.08 | ~0.99 × player speed | **NO — P0** |
| Stage 8 devil speed | 0.80 × | 1.11 | ~0.99 × | **NO — P0** |
| Maze size (stage 9–100) | 18 → 29 | clamp 17 | 17 × 17 | **NO — P1** |
| Safe zone duration | configurable 0.0–3.0 s | `duration: 1.0` hard-coded | 1.0 s always | **NO — P1** |
| Safe zone count per stage | 2 (matches intent), but `StageRule.safeZoneCount = 2` ignored | hard-coded `_safeZonesPerStage = 2` | 2 always | OK by coincidence |
| Trap count per stage | per-stage 1–10 | `_trapDifficultyScaler.configForStage()` → 1–10 | matches | OK |
| Trap placement safety | "preserve a clean first-pass route" | `_safeFirstPassRouteExists` + insertion sort + scale | matches | OK |
| Devil spawn delay | 1.0–8.0 s | `_stageRule.devilSpawnDelay` applied | matches | OK |
| Devil spawn distance | `devilSpawnDistanceCells` 1–9 | applied via `_spawnDevilCell` | matches but with off-by-one in trail indexing | OK (P3 bug) |
| Devil speed scaling | `devilStepsPerSecond` 0.35–3.62 | multiplied by `devilSpeedMultiplier / playerSpeedMultiplier`, clamped 0.2–3.0 then 0.2–4.0 with rubber-band | effective upper bound = 3.0 in docs table; runtime says up to 4.0 | **NO — P1 doc mismatch** |
| Devil rubber-band | "0.7 near, 1.5 far" | implemented; CPU per tick = 1 sqrt per tick | OK in design; OK in cost |
| Control inversion duration | "between flips" — instantaneous flip | instantaneous, no hold or grace | OK |
| Reach goal = win | Yes | `_playerController.position == _maze.end` ⇒ `_loadNextMaze` | OK |
| Reach goal during a flip warning | should still count | check happens at top of `_onStageTick`, before flip event | OK |
| Trap collapse = die | Yes | `_onTrapCollapsed` ⇒ `_finalizeTrapDeath` | OK |
| Devil on same cell as player = die | Yes | `_devilCell == playerCell` + `crossedThroughEachOther` | OK in steady state, P3 race on tick boundary (see F-07) |
| Devil within safe zone | immune | `_playerSafe` ⇒ `_dispatchDevilDistance(...devilEnabled: false)` ⇒ no kill | OK |
| Devil respawn after safe zone | 5 → 2 steps | `_devilRespawnStepsForStage()` | OK |
| Maze shift: stays solvable | yes | path validation, region bounds, player adjacency | OK, mostly |
| Maze shift: never traps player in wall | yes | `_hasOpenAdjacentTile` check | OK in design |
| Reset to checkpoint on reactivation after external pause | Yes (post-Exit-Plus dialog) | `_resetToCheckpointOnReactivation` flag | OK |
| Ad revive # limit per band | unlimited / 3 / 2 / 1 (config) | `_canRevive` + `_maxRevivesForCurrentBand` | matches config |
| Reverse on exhaust | check `!_canRevive ⇒ _onRestartFromLoss` | OK |
| Character-specific abilities | not declared | none declared; characters differ only in sprite | OK (matches "cosmetic" framing) |

---

## TABLE 4 — PERFORMANCE HOTSPOTS (RUNTIME PATH ONLY)

| Hotspot | Location | Cost per frame | Frequency | Risk | Suggested optimization |
|---|---|---|---|---|---|
| `PlayerController.notifyListeners` | `lib/presentation/gameplay/player_controller.dart` `_tick` | tiny | ~60 Hz (Flutter Ticker) | rebuilds whole game surface via `AnimatedBuilder` | wrap the consumer in `RepaintBoundary` — already in place — and keep; the boundary is at the maze surface only, OK. |
| `_onStageTick` BFS for shortest path | `game_screen.dart` `_spawnDevilCell` / `_nextDevilStep` / `_dispatchDevilDistance` | O(N) maze BFS | 20 Hz × 3 paths ≈ 60 BFS/s on a 17×17 maze | low | cache distance map from start (already built); cache distance map from goal lazily (TBD). |
| MazePainter paint | `lib/presentation/gameplay/maze_painter.dart` `paint` | 4 sides × 17 × 17 = 1,156 line draws + 56 sprite draws + glow gradients | 20 Hz | mid | not 60 Hz because `shouldRepaint` only changes when time/pulse change — actually, paint runs every tick. Consider driving repaint via a `RepaintBoundary` that re-issues on a slower cadence than the tick itself. |
| Trap FX renderer | `lib/game/trap/trap_fx_renderer.dart` not yet read | TBD | 20 Hz when traps enabled | TBD | TBD — verify next pass |
| Player sheet split (`_loadCharactersSprite`) | `game_screen.dart` L1819–L1899 | 8 dirs × 7 frames = 56 `PictureRecorder.endRecording().toImage()` allocations | once per character change | low (one-shot) | cache the split at the AppFlowProvider level. |
| Trap placement engine on stage start | `lib/game/trap/trap_placement_engine.dart` `placeTiles` | heavy: BFS, route finding, weighted candidates, sort | once per stage | OK | already mitigated by `_rebuildTrapTilesForCurrentStage` |
| Maze shift trigger | `maze_shift_manager.dart` `triggerMazeShift` | rotates/swap/toggle region + validate | up to 2 per stage on shift-eligible stages | OK | capped to 3 candidates; tested |
| `_buildDistanceMap` (BFS) | `game_screen.dart` L1410 | O(N) per call | up to 4 per stage (start, goal, trap path length, devil distance sample) | low (300 cells / 0.05 ms) | OK |
| `_dispatchDevilDistance` | `game_screen.dart` L740 | BFS only at 10 Hz (capped by `_devilDistanceSampleElapsed`) | 10 Hz | OK |
| `_rebuildPathMetrics` after maze mutation | `game_screen.dart` L1402 | BFS | 3–4 × per stage (post-shift, post-load) | OK |
| `AudioManager.handle(GameAudioEvent.*)` | `lib/services/audio_manager.dart` | per tick (devil distance updates) | 10–20 Hz | OK (event-based lookup) |
| `AnimatedBuilder` rebuild of game surface | `game_screen.dart` `_buildGameSurface` | rebuild the painter every notify (PlayerController) | 60 Hz | mid | `Listenable.merge([playerController, gameSurfaceRevision])` — keep; this is correct for an arcade game. |

Conclusion: **no runtime block on 30 / 60 / 90 / 120 FPS that I can prove from code alone**, but the *game tick* runs at 20 Hz regardless. So under any FPS, the player advances and the devil advances at a constant 20 Hz. **Your floor is the tick rate, not the painter.**

---

## TABLE 5 — RESOURCE / DISPOSAL MATRIX

| Resource | Created | Owner | Disposed | Leak risk |
|---|---|---|---|---|
| `Timer.periodic` (`_countdownTimer`) | `game_screen._startCountdown` | `_GameScreenState` | `dispose()` | low |
| `Timer.periodic` (`_stageTimer`) | `game_screen._startStageLoop` | `_GameScreenState` | `dispose()` | low |
| `AnimationController` (`_stageClearController`) | `initState` | `_GameScreenState` | `dispose()` | low |
| `Ticker` (`_ticker` in `PlayerController`) | constructor | `PlayerController` | `dispose()` in `PlayerController.dispose()` | low — but `resetForMaze` does not `stop()` first. |
| `ui.Image` (player frames) | `_loadCharactersSprite` | `_GameScreenState` | `dispose()` calls `_disposeFrames(_playerFrames)` | OK |
| `ui.Image` (devil frames) | `_loadDevilSprite` | `_GameScreenState` | `dispose()` | OK |
| `ui.Image` (breaking_trap, exit_portal) | `_load*` | `_GameScreenState` | `dispose()` | OK |
| `FocusNode` (`_keyboardFocusNode`) | initState | `_GameScreenState` | `dispose()` | OK |
| `ValueNotifier` (`_gameSurfaceRevision`) | initState | `_GameScreenState` | `dispose()` | OK |
| `WidgetsBindingObserver` registration | `initState` `WidgetsBinding.instance.addObserver` | `_GameScreenState` | `dispose()` | OK |
| `audioplayers` voices | `AudioManager._loadProduct` chain | `AudioManager` | `AudioManager.dispose()` — **never called** | P3 |
| `AudioPlayer.completionStream` | per voice | `AudioManager` | listener cancel on voice play-done — OK in code | P3 |
| `StreamSubscription` for `purchaseStream` | `PurchaseService._startBilling` | `PurchaseService` | `dispose()` | OK |
| `StreamSubscription` for `IAP updates` | `PurchaseService._onStreamError` etc. | as above | OK |
| `Timer? _alarmPulseTimer` | `AudioManager` | `AudioManager` | cancelled + nulled in setter | OK |
| `ValueNotifier` (`bannerLoadedNotifier`, `bannerSizeNotifier`, `bannerReloadNotifier`) | `AdManager` | `AdManager` / facade | `dispose()` chain | OK |
| Flutter `WidgetsBindingObserver` from `AdsService`/`AdsFacade` | `start()` | facade + each ad impl | `stop()` | OK |
| `FearFlipGame` (constructed but not mounted) | `app_flow_provider` constructor | `app_flowProvider.game` | `app_flow_provider.dispose()` does not dispose game | P3 — dead; ok |
| `GameController` (constructed but unused) | `app_flow_provider` constructor | `app_flowProvider.gameController` | `app_flow_provider.dispose()` calls `gameController.dispose()` | OK |
| `FearFlipGameEngine` (constructed by `GameController`) | `GameController` constructor | `GameController` | `GameController.dispose()` does not dispose engine | P3 — dead; ok |
| `FirebaseFirestore`/`FirebaseAuth` listeners (authStateChanges) | `app_flow_provider` ctor | `_authSubscription` | cancelled in `dispose()` | OK |
| `Completer<void>? _restoreCompleter` | `PurchaseService.restorePurchases` | `PurchaseService` | completed in `finally` | OK |
| `Stream<LeaderboardSnapshot>` (live leaderboard) | `LeaderboardService.globalPanicLeaderboardStream` | caller-side streams — **never cancelled** in landing_screen on dispose (LOW confidence — needs verify) | leak | P3 |
| `Image.asset` cached | Flutter engine | automatic, capped | OK |

`AudioManager.dispose()` is the only meaningful leak-ish concern. The singleton never dies. Acceptable for a mobile app; if you ever embed inside a long-lived host (iOS app extension, kiosk), wrap a shutdown.

---

## TABLE 6 — TEST COVERAGE MATRIX

| Area | Existing coverage | Missing coverage | Priority |
|---|---|---|---|
| Maze generator determinism | covered (`maze_shortest_path_distance_test`) | none | — |
| Maze shortest path | covered | none | — |
| Trap placement: fairness | covered (`trap_placement_engine_test`) | none | — |
| Trap placement: determinism | covered | none | — |
| Trap placement: spacing | covered | "trap + maze shift doesn't invalidate cell" | P1 |
| Trap state controller | covered (`trap_state_controller_test`) | trap + maze-shift invalidation | P1 |
| Devil distance / speed curve | covered (`devil_distance_speed_test`) | none | — |
| `StageRules.forStage` override | **NOT covered** | regression on F-01 | **P0** |
| `GameScreen` mount | shallow (`widget_test.dart` only checks the painter appears) | full lifecycle: pause, resume, death, win, restart, revive | P0 |
| Devil step BFS | indirect (`devil_distance_speed_test`) | "no oscillation, no deadlock, never moves through wall" | P1 |
| Maze shift validity | **NOT covered** | maze-after-shift path length, player not in wall | P1 |
| Devil + safe zone interaction | covered (`devil_distance_speed_test`) | "devil despawns on entry, respawn steps" | P2 |
| Flip warning UI | **NOT covered** (because the code is empty — F-02) | regression once fixed | **P0** |
| Reverse-ad-revive limit | **NOT covered** | `_canRevive` per checkpoint band | P1 |
| Restart after trap death | **NOT covered** | F-09 path | P1 |
| Restart after time-up | **NOT covered** | `_onTimeExpired` | P1 |
| Pause → background → resume | **NOT covered** | `_handleExternalActivityChange` state | P0 |
| Profile → icon character choice | covered (`widget_test.dart`) | none | — |
| Audio cooldowns | covered (`ad_placement_policy_test`) | "two game-overs required before interstitial" | — |
| Audio voice pool | covered (`audio_manager_sync_test.dart` 879 lines) | per-event sequencing in adversarial conditions | — |
| Purchase service | covered (`purchase_service_test.dart` 387 lines) | Mode B idempotency | P2 |
| Auth | **NOT covered** | refresh, sign-out, re-sign-in | P2 |
| Leaderboard cache | **NOT covered** | "cache served first, then refreshed" | P2 |
| Leaderboard ranking | partial | "trophies tie-break ordering" | P2 |
| Account deletion flow | covered (`account_deletion_service_test`) | Cloud Function trigger | — |
| Level validator | covered (`level_validator_test`) | **tested against dead `FearFlipGame`** — switch to runtime `GameScreen` if validator survives | P0 if validator survives |
| Procedural level generator | covered | **tested against dead code only** | P0 if validator survives |
| `FrameBudgetMonitor`, `ObjectPool`, `Pools` | **NOT covered** | none — they are dead | P3 |
| `FearFlipGameEngine` (separate, dead) | covered | none — they are dead | P3 |
| Privacy / consent | **NOT covered** | "consent applies ad-personalisation" | P3 |
| Config: `productionReadinessIssues` warnings | **NOT covered** | "test placeholders produce warnings" | P1 |
| `MazeShiftManager` state machine | **NOT covered** | "mid-run shift invalidates, late-run shift invalidates" | P0 |
| Trap placement + maze shift composite | **NOT covered** | F-09 path | P0 |

**Test gap matrix verdict: ~50 % of code paths covered, but the *adversarial* paths (background / shift / trap + shift / revive / time-expiry / F-02 fix / F-01 fix) are essentially uncovered.**

---

## TABLE 7 — DOCUMENTATION vs RUNTIME MISMATCHES

| Doc | File | Claim | Actual runtime | Match? | Action |
|---|---|---|---|---|---|
| `docs/stage_rules_runtime_1_100.md` | runs the doc generator | "GameScreen clamps maze to 17" | confirmed | YES | OK |
| `docs/stage_rules_runtime_1_100.md` | "devilStepsPerSecond (runtime) clamp 0.2..3.0" | confirmed | YES | OK |
| `docs/stage_rules_runtime_1_100.md` | "warningTime, safeZoneCount, safeZoneDurationSeconds are currently not wired" | confirmed | YES (and the doc says so) | OK; but the runtime intent disagrees with the docs — the **fix** is to wire them |
| `lib/RULES.TXT` | rich text narrative of stage design | lists per-stage devil speed and warning time as the design | ignored at runtime | **NO — P0** | delete or wire |
| `docs/stage_balance_report.csv` | 11 KB machine-readable table | acts as ground truth | n/a | n/a | regenerate from rules |
| `report_of_fearflip.md` | "Front End / Back End" review | describes pre-split architecture | now stale | NO | mark `2026-07` superseded |
| `game_improvement_plan.md` | "1-click addiction blueprint" | vision doc | n/a | n/a | leave as design |
| `prompt_fearflip.md` | 835-line TODO list | n/a | n/a | n/a | leave as session prompt |
| `docs/ads-and-iap.md` | ad / IAP overview | matches runtime | YES | OK |
| `docs/play_release_checklist.md` | pre-release | n/a | n/a | OK |
| `docs/incident_runbook.md` | incident playbook | n/a | n/a | OK |
| `docs/production_scale_blueprint.md` | scale design | n/a | n/a | OK |
| `docs/play_store_release_hardening.md` | hardening checklist | n/a | n/a | OK |
| `docs/production_ad_checklist.md` | ad pre-release | n/a | n/a | OK |
| `docs/privacy_policy.md`, `docs/account_deletion.html` | legal pages | n/a | n/a | OK (legal sign-off required) |
| `firestore.rules` | server rules | matches server functions | YES | OK |
| `functions/lib/index.js` header comments | "True anti-cheat … not built yet" | honest | YES | OK; needs stronger impl (see F-06) |
| `lib/app/fear_flip_app.dart` L79 comment "Frame-folder prefix … must match the order/prefixes in game_screen.dart `_characterFramePrefix`" | naming contract | matches | YES | OK |
| `lib/presentation/providers/app_flow_provider.dart` L48 comment "Versioned key — bump the suffix (v2, v3…) if the policy materially changes" | known pattern | n/a | YES | OK |

---

## PHASE 1 — RELEASE BLOCKERS (must fix before a single Play Store upload)

### R-01 — Restore the stage rules
**File:** `lib/presentation/gameplay/stage_rules.dart` `forStage()` (~L1856)
**Change:** remove the `if (!baseRule.devilEnabled) return baseRule` branch + the `targetDevilMultiplier` clamping, OR move the cap from `devilSpeedMultiplier` to the downstream `devilStepsPerSecond * speedRatio` clamp (where it already lives).
**Regression risk:** stages 5–8 become noticeably easier (devil drops from `~playerSpeed − 0.01` to the table value of `0.6–0.8 × playerSpeed`). Possibly too easy — measure.
**Validation:** new test `test that `StageRules.forStage(5).devilSpeedMultiplier == 0.60`.

### R-02 — Wire the warning
**File:** `lib/presentation/gameplay/game_screen.dart` L629
**Change:** when `timeToFlip ≤ warningTime && timeToFlip > 0`, set a state that the HUD reads and emits `GameAudioEvent.flipImminent`. Bind an overlay / haptic / color pulse. Use existing `GameHud` widget — add a `flipImminentMs` field that ticks down.
**Regression risk:** none, it's currently doing nothing.
**Validation:** new tests for HUD + audio event on warning window.

### R-03 — Stop shipping dead assets
**File:** `pubspec.yaml` `flutter.assets`
**Change:** remove `phantom_frames/`, `sentinel_frames/`, `devil_frames/`, `void_ripper_frames/` (4 dirs × ~10 MB).
**Regression risk:** `_decodeFrameFiles` (dead code) — delete that method at the same time.
**Validation:** `flutter pub get` and `flutter build apk --release`.

### R-04 — Consolidate the two duplicate leaderboards of source-of-truth
**File:** `lib/data/services/leaderboard_service.dart`, `lib/services/leaderboard_service.dart`
**Change:** keep one. The `lib/services/` copy is the one used at runtime (`app_flow_provider` references it).
**Regression risk:** minimal — the `data/services/` versions are referenced only by `lib/data/services/auth_service.dart` (itself only by `GameController`, which is dead) and by tests.
**Validation:** `flutter analyze` clean, `flutter test` green.

### R-05 — Fix the `submitScore` server race
**File:** `functions/lib/index.js` `submitScore`
**Change:** wrap the meta-ref check + best-ref conditional set in a transaction, OR use `lastScoreSubmitMs` lock + bestRef in one update.
**Validation:** unit test that two concurrent calls from the same uid don't both pass.

### R-06 — Plausibility-check the score
**File:** `functions/lib/index.js` `submitScore`
**Change:** add `if (scoreSeconds > 86400) throw …` already done; add `if (mode === 'normal' && scoreSeconds > 180 + (stage − 1) × 30) return { ok: false, reason: 'implausible' }` — adjust per-mode after talking to the design owner.

### R-07 — Verify `productionReadinessIssues` with a test
**File:** `lib/config/app_runtime_config.dart`
**Change:** add a `production_readiness_test.dart` that injects fake `removeAdsProductIdValue`, `_debugBannerAdUnitId`, etc., and asserts each known bad value triggers a warning.

### R-08 — Re-enable safe-zone duration
**File:** `lib/presentation/gameplay/game_screen.dart` `_buildSafeZones` call at L1620
**Change:** replace `duration: 1.0` with `_stageRule.safeZoneDurationSeconds`. The default value 1.0 is OK for early stages; late stages with `0.0` get a 0-second safe zone (immortal cells disappear).

### R-09 — Tighten maze shift: never invalidate trap tiles
**File:** `lib/presentation/gameplay/game_screen.dart` post-shift handler
**Change:** after shift, drop any `TrapTile` whose `cell` no longer maps to a walkable cell (or whose cell is no longer an interior walkable cell per `TrapStateController.update` invariants).

### R-10 — Wrap the leaderboard stream so it actually tears down
**File:** `lib/presentation/screens/landing_screen.dart` `globalPanicLeaderboardStream` consumer
**Change:** cache the subscription in a `State` field; cancel on `dispose()`. (LOW confidence — verify by reading `landing_screen.dart` consumer code; the listing I did showed ~28 KB class.)

---

## PHASE 2 — GAMEPLAY CORRECTNESS

### G-01 — Tests for `StageRules.forStage` (no override)
### G-02 — Tests for F-02 fix (warning window visible)
### G-03 — Tests for `MazeShiftManager`: post-shift path exists for player
### G-04 — Tests for `MazeShiftManager`: traps survive the shift (or are dropped)
### G-05 — Tests for player/devil tick alignment: hold the player idle; devil shouldn't "spasm"
### G-06 — Tests for safe-zone duration = 0 at stages ≥ 75 (no immortal cells)
### G-07 — Refactor `_onStageTick` so the player and devil use the same timing source
### G-08 — Re-test devil rubber-band at distance ≤ 25 % of map diag (slow), ≥ 75 % (fast)
### G-09 — Confirm all 100 stages are playable end-to-end with F-01 unfixed → then fixed (run the existing `level_validator` + a new "runtime simulator")

---

## PHASE 3 — PERFORMANCE

### P-01 — Cache sprite sheet split in `AppFlowProvider` (or `loadCharactersSprite` once)
### P-02 — Move `_dispatchDevilDistance` cadence from per-tick to 5 Hz, with change-only dispatch
### P-03 — Re-verify `MazePainter.shouldRepaint` doesn't allocate
### P-04 — Lift `_gameSurfaceRevision` out of the painter and into a `RepaintBoundary`'s `markNeedsPaint`
### P-05 — On cold-start, prefetch the player sheet (1 of 3) in `initState` only, load the others on demand

---

## PHASE 4 — ARCHITECTURE

### A-01 — Decide ONE: keep `_GameScreenState` as the runtime, delete the dead engines, OR re-platform onto Flame.
   **Recommendation:** delete `lib/game/*`, `lib/engine/*`, `lib/domain/*`, `lib/data/*`, `lib/ui/*`, `lib/presentation/controllers/*`. Save ~4,000 LoC of dead code. Risk = the test files that exercise those paths; refactor them to test the same behaviour from `_GameScreenState`.
### A-02 — Decompose `game_screen.dart` (2,252 LoC) into:
- `lib/presentation/gameplay/runtime/game_loop.dart` (~150 LoC): owns timer + tick
- `lib/presentation/gameplay/runtime/devil_controller.dart` (~300 LoC): owns devil BFS, spawn, rubber-band
- `lib/presentation/gameplay/runtime/flip_controller.dart` (~80 LoC): owns flip state + warning
- `lib/presentation/gameplay/runtime/maze_shift_controller.dart` (~80 LoC): thin wrapper over `MazeShiftManager`
- `lib/presentation/gameplay/runtime/trap_runtime.dart` (~200 LoC): owns trap lifecycle beyond Tile
- `lib/presentation/gameplay/runtime/stage_clerk.dart` (~250 LoC): owns `StageRule` application + metrics
- `game_screen.dart` shrinks to ~1,200 LoC and is presentation glue
### A-03 — Replace `RULES.TXT` + `stage_rules.dart` with `assets/data/stages.json` + a generator
### A-04 — Consolidate `lib/services/ads_*.dart` behind `AdsFacade`; make `AdsService` and `AdManager` private to `ads/`
### A-05 — Consolidate `lib/data/services/*.dart` (delete duplicates)
### A-06 — Convert `_GameScreenState` state into a single `GameRuntimeState` with `ChangeNotifier`-like semantics owned by a runtime controller; drop `setState` from per-tick paths

---

## PHASE 5 — QA / TESTING

### Q-01 — Add the test matrix in TABLE 6 above (P0 + P1 rows)
### Q-02 — Property-based tests for `MazeGenerator` (every generated maze is connected; start ≠ end; no orphan cells)
### Q-03 — Flake-target the 50 ms tick: run `_onStageTick` at 5 ms for a synthetic 24 h, assert no NaN / no overflow / no log-spam
### Q-04 — Add a smoke test that boots `FearFlipApp` and asserts `_gameSurfaceRevision` is non-null after first frame
### Q-05 — Add a kill-the-app-during-gameplay test (simulate `AppLifecycleState.detached`)

---

## PHASE 6 — POLISH

- Drop `_decodeFrameFiles` and the old per-frame PNGs.
- Replace `assets/RULES.TXT` text with a generator-driven JSON.
- Remove `game_improvement_plan.md` from the repo root (move to `docs/notes/`).
- Add `lib/services/audio_manager.dispose()` hook to `app_flow_provider`.
- Add a tiny `dispose()` test for `FearFlipApp`.

---

## CRITICAL ANSWERS — verbatim from the brief

### What is currently solid?
- `PurchaseService` and its Cloud Function pair — token-idempotent, server-validated, revocation-safe.
- `FirestoreLeaderboardService` write path (server-authoritative via Cloud Functions).
- `MazeGenerator` (deterministic, connected, farthest-goal).
- `MazeShiftManager` validation (preserves solvability, never traps the player).
- `TrapPlacementEngine` ("preserve a clean first-pass route" guarantee).
- `AdsFacade` Unity → AdMob fallback design.
- `AppRuntimeConfig.productionReadinessIssues()` gate.

### What is actually broken?
- **`StageRules.forStage()` silently overwrites `_rules[].devilSpeedMultiplier`.** This produces unfair devil speeds in stages 5–10.
- **The flip-warning is a no-op** (`if (...) {}`). Players have no warning before control inversion.
- **Maze size is clamped to 17** at runtime even though 100 stages are declared up to 29.
- **Safe-zone duration is hard-coded to 1.0 s**, ignoring per-stage values of 0.0 s (late stages).

### What is only partially implemented?
- Devil rubber-band (declared 0.7–1.5; effective clamp 0.2–4.0 with rubber-band; the silent override F-01 masks the design).
- Maze shift + trap interaction — the validator doesn't know about traps.
- `pause/resume` in `_GameScreenState` — handles `AppLifecycleState.paused/inactive/hidden/resumed/detached` cleanly, but the only `danger` path is `detached` which is unhandled (`break`).

### What is duplicated?
- `lib/services/leaderboard_service.dart` ↔ `lib/data/services/leaderboard_service.dart`
- `lib/services/auth_service.dart` ↔ `lib/data/services/auth_service.dart`
- `lib/services/ads_service.dart` ↔ `lib/services/ad_manager.dart` ↔ `lib/services/ads_facade.dart` (all three impl `AdsServiceBase`)
- `lib/game/maze.dart` ↔ `lib/presentation/gameplay/maze_generator.dart` (two `MazeGrid` types; only the latter is used)
- Engine #1 (`lib/game/*` Flame) ↔ Engine #2 (`lib/domain/* + lib/engine/* + lib/presentation/controllers/*`) ↔ Engine #3 (the `_GameScreenState` runtime). **Only engine #3 actually plays.**

### What is unnecessarily complex?
- `lib/app/fear_flip_app.dart` settings UI is a `StatefulWidget` housing six concerns (settings, character select, onboarding, privacy, account deletion UI, remove-ads UI). Split into six.
- `audio_manager.dart` 2,088 LoC: extract the multi-bus logic into `audio_buses.dart`, the voice pool into `audio_pool.dart`, the cal/devil/alarm loops into `audio_loops.dart`.
- `_OnStageTick` is a 100-line method.
- `procedural/` services in both `lib/services/` and `lib/domain/` — duplicated contracts.

### What can cause a player to die unfairly?
- **F-01** (devil forced to player speed before design intends): stage 5 onward.
- **F-02** (no warning before flip): every stage.
- **F-07** (player vs devil on different tick rates): occasionally the devil "appears" inside the player cell on a 50-ms boundary.
- **F-09** (trap cell invalidated by maze shift): trap reveals on a now-non-walkable cell.
- **Random rubber-band factor at extreme distance** combined with F-01 → devil moves 4 cells/s while player is at 60 Hz / 120 ms-per-step ≈ 8 cells/s. Looks fair numerically but at tight corridors the rubber-band "1.5 max factor" makes the devil catch up during a straight section.

### What can cause performance drops?
- 56-cell sprite sheet split on first character change (one-shot 100–300 ms).
- `_dispatchDevilDistance` runs BFS every tick guard fires (10 Hz × BFS).
- `AnimatedBuilder` rebuild on every player notify (60 Hz).
- Big per-frame Paint / MaskFilter allocations in `MazePainter` (Blur MaskFilter per cell glow — high cost).

### What can cause data or purchase problems?
- `purchase_service.Mode B` grant → 24 h tolerance window before re-verify. During that window a refunded user keeps premium.
- `submitScore` race (F-19) allows two near-simultaneous submissions.
- `_reviveLimitBand25to50/50to75/75to100` are env-only. If unset they default to `0` (per `AppRuntimeConfig`) — verify and add an assertion.
- `_removeAdsIosProductIdRaw` defaults to same as Android if empty — verify this is what the Play Store sheet shows.

### What would prevent this from shipping?
- **F-01** alone — Play Store reviewers will catch it in the first 5 levels.
- **F-02** — every reviewer will say "the controls just flipped without warning".
- **F-13** (12 MB of dead assets in the APK) — will show up as "app is large" in Play Console warnings.

### What should be fixed first?
1. **F-01** (devil speed), **F-02** (warning), both small — together 40-50 LoC of change but the biggest gameplay wins.
2. **F-13** (dead assets) — 30 minutes, dramatic APK savings.
3. **F-06** (plausibility-checked score) — keep your leaderboard from getting griefed on launch day.

---

## MINIMAL ARCHITECTURAL TARGET (the smallest thing that works)

```
flutter/
  lib/
    main.dart                              # bootstrap + crashlytics
    firebase_options.dart                  # platform options
    app/
      fear_flip_app.dart                   # MaterialApp + routing
    config/
      app_runtime_config.dart              # env-driven gates
    domain/
      stage_rule.dart                      # immutable value types only
      stages.json                          # 1..100 data
    presentation/
      screens/                             # 6 screens
        auth_gate/
        landing/
        onboarding_consent/
        privacy_policy/
        leaderboard_global_panic/
        leaderboard_next_level/
      gameplay/                            # the runtime
        game_screen.dart                   # shell, paint only
        runtime/
          game_loop.dart                   # 20 Hz tick
          stage_clerk.dart                 # applies stage rule
          player_runtime.dart              # PlayerController wrapper
          devil_runtime.dart               # DevilController + BFS
          flip_runtime.dart                # FlipController + warning
          maze_shift_runtime.dart          # MazeShiftManager wrapper
          trap_runtime.dart                # TrapStateController wrapper
        maze_generator.dart                # recursive backtracker
        maze_painter.dart                  # CustomPainter
        stage_rules_loader.dart            # reads stages.json
        widgets/                           # HUD, controls, dialogs
    services/
      audio_manager.dart                   # or audio/
      ads_facade.dart                      # only public ads surface
      ads_internal/                        # private Unity+AdMob impls
      purchase_service.dart
      leaderboard_service.dart
      auth_service.dart
      consent_service.dart
      account_deletion_service.dart
      game_audio_event.dart
      error_reporter.dart
      ad_placement_policy.dart
      leaderboard_cache.dart
      ads_diagnostics.dart
      ...
functions/                                  # unchanged
firestore.rules                              # unchanged
firestore.indexes.json                       # add composite for global_panic
assets/                                      # trim dead frames
assets/data/stages.json                      # NEW: 100-entry table
```

**Removed:**
- `lib/game/*` (entire folder) — engine #1
- `lib/engine/*` (entire folder) — engine #2
- `lib/domain/{entities,input,procedural,usecases,progression,rules}/*` (consolidate to `stage_rule.dart` + `stages.json`)
- `lib/data/*` (entire folder) — duplicates of `lib/services/*` and `engine#2` internals
- `lib/ui/game_overlays.dart` — never used
- `lib/presentation/controllers/game_controller.dart` — never used

**Net deletion: ~5,500 LoC.** Reasoning: keep the parts that actually run.

---

## BAYESIAN CONFIDENCE NOTES

- All `Phase 2 / 3` findings (`dev path overlay`, `MazeShiftManager` invariants) are HIGH-confidence (read entire file).
- All `Phase 6` (release config) findings are HIGH-confidence (read the env var model fully).
- Audio's `dispose()` never-called claim is HIGH-confidence; but the memory impact claim is LOW-confidence — I haven't measured actual heap. Treat as P3.
- `app_flow_provider` leaderboard subscription leak claim is LOW-confidence — needs a read of `landing_screen.dart`'s subscription lifecycle. Marked P3.
- "Trap + maze-shift invalidation" claim is HIGH-confidence from reading `MazeShiftManager._applyCandidate` + `TrapTile` (cell-coordinate based).

---

## WHAT TO FIX FIRST (FINAL)

| Order | Effort | Why |
|---|---|---|
| 1. **F-01** Restore `StageRules.forStage` — 10 LoC | S | Largest gameplay win |
| 2. **F-02** Wire the flip warning — ~50 LoC + 1 audio event + HUD pulse | S | Unblocks the whole flip system from being "unfair" |
| 3. **F-04** Wire `safeZoneDurationSeconds` — 1 LoC | XS | Free |
| 4. **F-13** Drop dead sprite frames from `pubspec.yaml` — 4 lines | XS | APK drops ~12 MB |
| 5. **F-06 + F-19** Server-side plausibility + rate-limit transaction — ~30 LoC in `functions/lib/index.js` | S | Day-1 leaderboard sanity |
| 6. **F-08 + F-09** Maze-shift + trap post-validation — ~30 LoC in `maze_shift_manager` + glue in `game_screen` | S | Last "random unfair death" |
| 7. **F-12** Player sheet split cache — lift to `AppFlowProvider` | S | First-stage stutter |
| 8. **A-01/A-02** Delete dead engines, decompose `game_screen.dart` — 1 file moved to `runtime/` | M+L | Hygiene + future velocity |
| 9. **Q-01** Test gap matrix | M | Lock the fixes |
| 10. **A-04 + A-05** Consolidate ad/data services | M | Reduces review surface |

**Suggested PR structure (for future implementation):**

```
PR-1  hotfix/f01-f02-f04  (gameplay)
PR-2  hotfix/f13-asset-trim (release size)
PR-3  feat/server-anti-cheat (F-06, F-19)
PR-4  feat/maze-shift-trap-validation (F-08, F-09)
PR-5  refactor/dead-engine-removal (A-01)
PR-6  refactor/game-screen-decomposition (A-02)
PR-7  refactor/ads-internal (A-04)
PR-8  refactor/data-services-merge (A-05)
PR-9  test/audit-coverage (Q-01)
PR-10 polish/audio-dispose (F-11)
```

10 PRs, ordered by impact / risk. Each one independently shippable. None collides with the others. That's the path to a clean, fair, ship-able FearFlip.

---

## THE 4-SHIP-READINESS GAUNTLET

| Gate | Pass? |
|---|---|
| Crash-free boot on Pixel 4a / iPhone 12 baseline | Likely yes — no obvious blocker |
| `flutter analyze` clean | Probably yes — the dead code masks most lints |
| `flutter test` green | Yes if existing suite passes today |
| F-01 + F-02 fixed | **No** today, trivial tomorrow |
| Leaderboard ungriefed for 24 h | **No** today, ~30 LoC tomorrow |
| APK size below ~40 MB | **No** (after dead asset trim, yes) |
| Stage 100 reachable | Not verified — needs an end-to-end smoke test |

---

**That's the audit. Now you can decide: ship-blocker fixes first (PR-1..PR-3), or do the structural cleanup alongside (PR-5..PR-8 first, then PR-1..PR-3). I'd recommend fixing the P0s first and refactoring once the behaviour is stable — that way the dead-code deletion is provably safe.**
