# FearFlip 2D (main branch) — Game Logic Reference for the 3D Port

Source: `main` branch, Flutter. Read from `lib/presentation/gameplay/{game_screen,stage_rules,maze_generator,maze_shift_manager,player_controller}.dart`
and `lib/game/trap/*`. (`lib/game/{devil,game,maze,player}.dart` are legacy dead code — ignored.)
Purpose: inspiration for the Godot 3D game. **Carry the *ideas*, not the numbers 1:1 — 3D should "feel significantly better", and several 2D numbers are buggy (see §12).**

---
## 1. Core loop
- 100 stages. Each stage = one fresh **perfect maze** (square), player starts at top-left `(0,0)`, exit is the **farthest cell by BFS** from start.
- Reach the exit cell → stage clear (overlay ~1.4 s + 2 s delay) → next stage, new maze, timer reset. Clearing stage 100 → crown victory dialog.
- Per-stage clock: **105 s** (constant). `<= 10 s` = "panic" mode (audio + traps get nastier). Time 0 and not on exit → lose. If on exit at 0 → still wins.
- Three ways to lose: **time out**, **Devil catches you**, **trap collapses**.
- Everything is **grid-based and discrete**: player moves cell to cell; "grid is truth, graphics are projection". Same principle as the 3D port.

## 2. Maze generation (`maze_generator.dart`)
- Recursive-backtracker DFS from `(0,0)`, random neighbor each step → **perfect maze (a tree: exactly one path between any two cells, no loops)**.
- `end` = BFS-farthest cell from start. Unseeded `Random()` (new maze each run/stage).
- Maze size per stage comes from `StageRule.mazeSize` (10 at stage 1 → 29 at stage 100) **but the game clamps to 17** (`_maxPlayableMazeSize`) — so every stage ≥ 8 is 17×17 (bug/limit, see §12).
- Consequence of perfect maze: only **dead-end branches** exist; "loop nodes" in trap code never fire. A dead-end trap trap = you must walk back through it.
- `shortestPathDistance` (BFS) is used everywhere: devil distance audio, near-goal checks, analytics.

## 3. Player movement (`player_controller.dart`)
- One step = glide from cell to adjacent cell. Step duration `120 ms / playerSpeedMultiplier`, clamped **60–260 ms** → ~8.3 steps/s at 1.0×, 12.5 steps/s at 1.5×.
- Hold a direction → keeps stepping while the wall allows. Cannot start a new step mid-step. Direction held is re-evaluated each cell.
- Player speed multiplier rises per stage: 1.00 (stage 1) → 1.30 (24) → 1.50 (cap from ~stage 44).
- **Trail** (`pathPoints`): list of visited cells; stepping back onto the previous cell *retracts* the trail. Used to spawn the Devil behind you.
- Input blocked while: round resolved, stage transition, loss overlay, trap death anim, paused, app inactive.

## 4. Reality Flip (the signature mechanic)
In 2D "flip" = **controls inversion**, not a world switch:
- `flip` toggles `controlsInverted` (up↔down, left↔right) — HUD says `NORMAL` / `FLIPPED`, world colors change (`isFlippedMode`), glitch SFX `flipTriggered`.
- Schedule: first flip at `firstFlipDelay` seconds (4.0 s stage 1 → 1.1 s late game). Then every `baseFlipInterval * (1 ± jitter)`, jitter ∈ [`flipRandomnessMin`,`flipRandomnessMax`], interval clamped **1–12 s**.
  - Stage 1: 5.0 s, no randomness · Stage 10: 3.25 s ±45 % · Stage 24: 2.15 s ±75 % · Stage 50+: ~1.5–1.95 s ±60–80 % · Stage 100: 1.6 s.
- `warningTime` (1.2 s → 0.4 s) exists per stage **but the warning branch is empty — no warning is ever shown** (bug). In 3D: implement the warning properly (fairness rule).
- Held direction is re-mapped on flip: when inverted, `_holdInputDirection` flips the direction before handing to the player.
- `RealityFlipSystem` (`lib/game/flip_system.dart`, Flame legacy) has the cleaner version: `onWarning(secondsLeft)` then `onFlip()`, interval jitter clamped 1.2–30 s, randomness clamped 0–0.8. Use *this* shape for 3D.

## 5. The Devil — complete behavior
**Existence / spawn gating** (`_canSpawnDevilNow`) — all must hold:
1. `devilEnabled` (true on all 100 stages).
2. Not already spawned.
3. Player is **not** on a safe zone.
4. `stageElapsed >= devilSpawnDelay` (8 s stage 1 → ~1 s late; 3 s on checkpoint stages 25/50/75 with long delay).
5. If it was removed by a safe zone: player must have taken **`devilRespawnSteps` steps** since (5 early → 2 late, linear over stages, clamped 2–5).
6. Player has progressed **≥ 30 % of start→goal path distance** (`_devilMinPathClearance = 0.30`) — measured as `distanceFromStart[player] / startToGoalDistance`. (Free early run, then it appears.)

**Spawn position** (`_spawnDevilCell`): on the **player's own trail**, `devilSpawnDistanceCells` cells *behind* the player (9 → 1 cell by stage 24; 5 on checkpoint stages). Fallback: farthest trail cell ≥2 away, else 2 cells opposite facing. → The Devil always appears **behind you, never ahead / never on top of you**.

**Pathing**: each Devil step = **BFS shortest path to the player's current cell, take the first step** (`_nextDevilStep`). Perfect knowledge, no senses (omniscient) — *3D upgrade chance: senses/Director*.

**Speed model** (in steps per second):
```
playerSpeed        = stageRule.playerSpeedMultiplier
speedRatio         = clamp(devilSpeedMultiplier / playerSpeed, 0, 1)   // forStage() forces devilMult = playerMult - 0.01  => ratio ≈ 0.99
base               = devilStepsPerSecond * speedRatio
distance factor    = rubber band on Euclidean grid distance to player:
    d <= 0.25 * mapDiagonal  -> 0.7  (SLOW when close)
    d >= 0.75 * mapDiagonal  -> 1.5  (SPRINT when far)
    in between: linear lerp
final steps/sec    = clamp(base * factor, 0.2, 4.0)
```
- `devilStepsPerSecond`: 0.35 (stage 1) → 1.5 (stage 14) → 2.08 (24) → ~3.6 (100). At the cap the Devil is ~2.5–4 steps/s vs player 8–12.5 steps/s → **Devil is only ~20–35 % of player speed**. It kills through *corridor geometry* (dead ends, flips reversing you into it, trap/time pressure), **not raw speed**. This is why it feels fair. Keep this relation in 3D (close = slower, far = faster, min lets you escape, max never instant death).
- Steps accumulate in a time accumulator (`while acc >= 1/speed`), so multiple steps per tick are possible if speed is high.

**Catch rule**: Devil cell == player cell, **or they swapped cells in one tick** (cross-through check: `prevDevil == player && lastPlayer == devil`), AND player **not** on a safe zone, AND no hazard grace active.

**Despawn**: stepping onto a **safe zone** removes the Devil entirely (`_onSafeZoneEntered`), resets respawn-step counter and starts the step-gated respawn.

**Hazard grace**: after a maze shift the Devil is frozen (accumulator = 0) and cannot catch for **0.5–1.0 s**.

**Audio coupling**: every 0.1 s (or when its cell changes) the BFS path distance Devil→player is sent as `devilDistanceChanged(distanceTiles, devilEnabled = dist <= 6, safeZoneImmune)`. Heartbeat/proximity audio only inside **6 tiles**; no devil → distance 99.

## 6. Safe zones
- **Count: always 2** (the `safeZoneCount` / `safeZoneDurationSeconds` fields in `StageRule` are **ignored** — constant `_safeZonesPerStage = 2`, `duration 1.0`; bug, see §12).
- Placement: BFS shortest path start→goal, drop start+exit, then pick cells at ratios **1/3 and 2/3** of that interior path → evenly spaced **on the main route**. (Never in dead ends.)
- Stages **1–75: persistent** (re-usable infinitely). Stages **>75: one-use** (cell removed when you step on it).
- While standing on one: `playerSafe = true` → Devil catch ignored, Devil is deleted (see §5), safe-zone SFX enter/exit, HUD glow. Traps are **never placed on safe zone cells** (`filteredTiles` removes them).
- Intent per stage rule (not implemented): `safeZoneDurationSeconds` 3.0 s (stage 1) shrinking to 0 s (stage 13+), i.e. early game = timed protection, late game = momentary. Legacy `SafeZoneComponent` (Flame) had a per-zone protection timer that drained only while the player stood inside. **This timed-protection idea is a good 3D mechanic** (circle drains → you can't camp).
- Respawn throttle after leaving a safe zone (steps 5→2, §5) is the *anti-camping* rule.

## 7. Traps (fragile floor tiles) — `lib/game/trap/*`
**State machine per tile** (`TrapTile`/`TrapStateController`):
```
hidden --(player steps ON it)--> cracked --(player steps ON it again)--> collapsed = DEATH
                                   |  (player/devil proximity, no step needed)
                                   v
                                critical (visual/audio pulse; still only dies on 2nd step)
```
- **First step is always safe** (reveals cracks + `crack_reveal` SFX). Death only on a **second step onto a cracked/critical tile**. Fair rule = "you got a warning; don't come back".
- Because the maze is a tree, **stepping on a trap while exploring a dead-end branch means you can't walk out that way** → memory-punishment design ("memory pressure").
- Hidden → cracked cue: when a hidden tile is exactly 1 cell (Manhattan) away and `hiddenCueLevel > 0.05`, a **hidden creak** SFX plays once (re-primes when player >2 cells away). Visual cue strength fades with stage: **1.0 (≤5) → 0.82 (≤15) → 0.58 (≤30) → 0.34 (≤50) → 0.16 (≤70) → 0.06**.
- Cracked → critical: when the player is within `criticalTriggerDistance` (1; 2 from stage 55; +1 while in panic ≤10 s) of a cracked tile (not on it), **or** the Devil is within 2 of the tile and the player within `critical+2` ("devil pressure"). Fires `critical_trigger` (+ `near_miss` analytics).
- Death: trap collapse → `trap_death` SFX, cinematic collapse animation (`TrapDeathSequence`), random flavor quote (`TrapDeathQuotes`, different pool when ≤3 cells from the goal), then loss overlay. Input/timer paused during the animation.

**Count per stage** (`TrapDifficultyScaler`, max 10): stages 1–3 → **1**; 4–7 → **2**; ≥8 → `round(walkableCells * density)` with density 0.020 (≤10), 0.030 (≤20), 0.040 (≤35), 0.050 (≤55), 0.060 (≤75), 0.070 (>75), clamped to a floor of 2 (≤15), 3 (≤30), 4 (≤55), 5 (≤80), 6 (81–100).
**Bands**: tutorial ≤10 · pressure ≤35 · mastery ≤70 · nightmare >70.
**Unlock gates**: chokepoint cells at normalised difficulty ≥ 0.58 (~stage 58), dead-end entrances ≥ stage 4, panic-route scoring ≥ stage 8, loop nodes ≥ stage 18 (moot in a perfect maze).
**Spacing**: min Manhattan 2 (1 at stage ≥70), min path-index gap 4 on the main route (3 at ≥70).

**Placement engine** (`TrapPlacementEngine`) — weighted random, seeded per stage (`stage*73856093 ^ rows*19349663 ^ cols*83492791 ^ endHash`):
1. Classify every walkable cell: `nearStart` (Manhattan ≤3), `nearGoal` (≤2), `deadEnd`, `deadEndEntrance`, `crossroads` (deg 4), `tJunction` (deg 3), `loopNode`, `chokepoint` (articulation point, deg 2), `corridor`.
2. **Hard exclusions (anti-frustration)**: near start, near goal, **first ~30 % (shrinking to ~17 %) of the shortest route**, dead-end cells themselves, safe zones.
3. Score = topology weight (T-junction 86, dead-end-entrance 78, loop 68, chokepoint 52, crossroads 42, corridor 30) + `revisitScore*42` (chance you'll need to come back: 1.0 for on-route fork with off-route branch, 0.92 dead-end entrance, 0.78 loop, 0.64 chokepoint…) + progress weight (centered ~0.48 → 0.68 along the route depending on band; −24 if <24 % or −14 if >94 %) + panic score (progress 0.34–0.92, peak 0.68, from stage 8) + 12 if on main route + noise up to 8. Off-route non-entrance cells ×0.72. Mid-route corridors get a "false confidence" tag late.
4. Pick ≥55 % of the traps from T-junctions first, rest from all candidates, honoring spacing.
5. **Validator**: must still exist a clean first-pass start→goal route (never start/goal on a trap; never two traps in a row on the route). Drops lowest-score traps until valid.
- Tags for design/analytics: `decisionFork, memoryReturn, panicRoute, falseConfidence, chokepoint, loop`. Analytics events: `hidden_suspicion_cue, crack_reveal, critical_trigger, near_miss, trap_death, restart_after_trap_death, checkpoint_reset_after_trap_death`.
- Stage 1 optionally forces a test trap on the 6th path cell (feature flag).

## 8. Maze Shift (`maze_shift_manager.dart`)
- Only on stages where **`stage % 6 == 0`** (6, 12, …, 96; stage 100 not a multiple → none).
- Two shifts per eligible stage, triggered by **step progress** (`stepsTaken / startToGoalDistance`, counts every step incl. backtracking, only after first move): **mid 40–60 %** and **late 75–90 %** (random per stage).
- Operation (random of 3) applied to a **3–5 cell square region**:
  - `rotate` — rotate the region's cells 90° clockwise (walls rotate too).
  - `swap` — swap wall profiles of two random cells (not player/exit).
  - `toggle` — flip 2–5 random walls open↔closed.
- Region rules: must **not contain the player, not be within 1 cell of the player, not contain the exit**. Walls on region borders are normalised so both sides agree.
- Try **3 candidates**, accept only if: player has an open adjacent tile, **an escape route within 4 steps** exists, a path to exit exists, and **new path ≤ 1.5× old path length**. Of the valid ones pick the **most noticeable** (most wall differences; tie → shorter path). If none valid → no shift.
- On shift: glitch overlay + `mazeShiftStarted/Ended` audio, path metrics rebuilt, Devil accumulator reset, **0.5–1.0 s hazard grace** (Devil frozen, can't catch).
- **Gap:** shifts do not re-validate trap placement or safe zones.

## 9. Stage progression (`stage_rules.dart`, 100 hand-tuned rules)
Each `StageRule` has: name, player speed mult, flip interval/randomness/first-delay/warning, maze size, devil (enabled, speed mult, spawn delay, steps/sec, spawn distance), safe zone count/duration.
Difficulty arc (every 25 stages is a **checkpoint** with an easier "breather" stage 25/50/75, then ramps):
| Stage | Name | PlayerX | Flip s | Flip rand | Devil steps/s | Spawn delay | Spawn dist |
|---|---|---|---|---|---|---|---|
| 1 | Awakening | 1.00 | 5.0 | 0 | 0.35 | 8 s | 9 |
| 2 | Inversion | 1.00 | 5.0 | 0 | 0.45 | 7 s | 8 |
| 3 | Control | 1.05 | 5.0 | 10–20 % | 0.55 | 6 s | 8 |
| 5 | First Contact | 1.08 | 4.0 | 20–30 % | 0.75 | 5 s | 7 |
| 8 | Acceleration | 1.12 | 3.5 | 35 % | 1.05 | 2.5 s | 4 |
| 10 | Trial | 1.15 | 3.25 | 45 % | 1.30 | 2 s | 3 |
| 15 | Instability Peak | 1.20 | 2.8 | 55 % | 1.68 | 1.5 s | 2 |
| 16 | Stabilization (breather) | 1.18 | 3.25 | 40 % | 1.50 | 3 s | 5 |
| 24 | Final Stretch | 1.30 | 2.15 | 75 % | 2.08 | 1.5 s | 1 |
| 25 | Checkpoint Break | 1.28 | 2.75 | 50 % | 1.60 | 3 s | 5 |
| 35 | Breaking Point | 1.41 | 1.95 | 60 % | 2.68 | 1.6 s | 1 |
| 49 | Last Attempt | 1.50 | 1.7 | 60 % | 3.16 | 1.4 s | 1 |
| 50 | Checkpoint Break | 1.45 | 2.5 | 50 % | 2.40 | 2.6 s | 4 |
| 75 | Checkpoint Break | 1.50 | 2.35 | 55 % | 2.55 | 2.4 s | 4 |
| 89 | Needle Run | 1.50 | 1.45 | 80 % | 3.51 | 1.1 s | 1 |
| 100 | THE BREAKER | 1.50 | 1.6 | 70–80 % | 3.62 | 1.0 s | 1 |
- Stage names are themed per band (Awakening, Inversion, Pursuit, Chaos Entry, Mental Break, False Security, Hunted, Dual Threat, Master Entry, Trap Routes, Mind Loop, Checkpoint Grind I–IV, Precision Hell, Mind Break, Final Trial I–IV, THE BREAKER).
- Design rules from `GEMINI.md`: stages 1–10 easy, 10–25 moderate, 25+ add *complexity* (shifts, traps, flip jitter) not raw speed.
- New mechanics by stage: traps from stage 1 (1 trap), dead-end traps 4+, panic routes 8+, shifts every 6th, safe-zone single-use >75, flip window shrinks as stage rises.

## 10. Checkpoints, lives and revives
- Checkpoints: **25, 50, 75** (`_checkpoint` = highest reached). Full death → restart from checkpoint (stage 1 if below 25).
- Loss dialog shows reason (`Floor collapsed beneath you.` / `Clock hit zero.` / `Devil intercepted you.`), escape % (stage/100), distance-to-next-checkpoint text, and a comeback hook by progress (≥90 % "Inches away. Lock in.", ≥70 % "Strong run. Try again.", else "Momentum is building.").
- **Revive (rewarded ad)**: restarts the *same* maze/stage from the start. Limit per checkpoint band: **unlimited stages 1–25**, then configurable limits for 25–50, 50–75, 75–100 (`AppRuntimeConfig.reviveLimitBand*`); revive counter resets when you cross a checkpoint boundary. Out of revives → falls back to checkpoint restart. Restart also goes through an ad callback (premium = skip).
- Ads: never during gameplay.

## 11. Audio / feedback events (from `game_audio_event.dart` + calls)
`matchStart, matchRestart, matchPause/Resume/Exit, timeChanged(secondsLeft), flipTriggered, devilDistanceChanged(tiles, enabled, safeZoneImmune), safeZoneEntered/Exited, mazeShiftStarted/Ended, playerWon, playerLost` + trap SFX (`hidden_creak, crack_reveal, critical_escalation, trap_death`) + alarm (stopped immediately on win). Panic (≤10 s) changes music/alarm. Glitch visual effect on shifts.
HUD: stage, timer, pause, checkpoint, hearts (lives) when band is limited; pause dialog shows stage, checkpoint, mode label (NORMAL/FLIPPED), time.
Input: touch ArrowPad/Joystick on mobile, arrow keys on web. Pause/background auto-pause.

## 12. Known 2D bugs / unfinished wiring — DO NOT COPY into 3D
1. Maze size clamped to 17 → stages ≥8 all 17×17.
2. Flip `warningTime` branch is empty → no flip warning.
3. `safeZoneCount` / `safeZoneDurationSeconds` in rules ignored (constant 2 zones, 1.0 s unused).
4. `devilSpeedMultiplier` per stage is overwritten by `playerSpeed − 0.01` in `StageRules.forStage`, and `devilStepsPerSecond` is hard-clamped to 0.2–4.0 → table values above ~stage 90 are capped.
5. Devil is omniscient (always BFS to the exact player cell).
6. Maze shift doesn't re-check traps/safe zones; progress counts backtracking steps.
7. Perfect maze means loop-based trap/panic logic never triggers.

## 13. What to carry into the 3D game (recommendations)
- **Keep:** two-step trap rule (first step cracks, second kills) — it is the fairest horror trap; trap placement philosophy (forks, dead-end entrances, never near start/goal, always a clean first-pass route); Devil spawns behind you on your trail, only after ≥30 % progress and with a spawn delay; Devil slower than player with rubber-band speed (slow when close, fast when far); safe zones = devil leaves + respawn throttled by steps; hazard grace after any scripted shift; devil proximity audio inside ~6 tiles; checkpoints every 25 and revives only at deaths; breather stages after hard blocks.
- **Adapt for 3D:** 2D flip = control inversion → 3D flip = **World Flip WAKE↔NIGHTMARE** (already built) so the *position* is the same but the walls/hazards differ; Devil lives only in NIGHTMARE; flip warning must be visible/audible (rule from 2D bug #2); trap tiles become cracked floor decals + creak SFX at 1 cell (use the same hidden-cue fade by stage); Maze Shift = rotate/swap/toggle on a ≤5-cell region (never near the player, ≤1.5× path length, ≥1 escape within 4 cells) with a glitch/shake + 0.5–1 s freeze on the devil.
- **Upgrade:** Devil senses/Director (Devil currently omniscient in both 2D and the 3D prototype); safe circles with a drain timer to stop camping; trap warning escalation (`critical` state) driven by player/devil proximity; per-stage data in `Resource`s (`StageRule`) instead of magic numbers; deterministic seeds so deaths can be replayed.
