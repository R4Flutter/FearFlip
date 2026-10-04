# 05 — FearFlip 3D = the 2D game rules, in first person (locked plan)

Version 2.0, 4 Oct 2026. Inputs: `claude2Dinspiratinfor3Dgame.md` (2D logic, `main` branch), the
current `godot/` code, the user's decisions (4 Oct), and the `router` + `godot-3d-essentials` skills.
**This file overrides `godot/FEARFLIP_3D_GAME_APPROACH.md` (MP) wherever they differ.** In
particular MP §4 (World Flip, NIGHTMARE, sigils, Flipping Time) and MP §8 (braided generator) are
**dropped**.

---

## 0. The game in one paragraph

You wake in the corner of a **perfect maze** (no loops) and must reach the exit, which is the cell
farthest from you, before the **clock** runs out. Every few seconds **reality flips**: your
movement controls invert (a warning first). The **Devil** appears behind you on your own trail once
you're well on your way. It's **slow when close, fast when far**. **Cracked floors** forgive the
first step and kill on the second. **Safe circles** on the main route make the Devil retreat, but
they drain. 50 floors, 5 acts, checkpoints, and at most 3 revives per act.

---

## 1. Locked decisions (user, 4 Oct)

| # | Topic | Final rule |
|---|---|---|
| L1 | Flip | **Control inversion** (the 2D Reality Flip). The World Flip (WAKE/NIGHTMARE), sigils and Flipping Time are **removed**. |
| L2 | Maze | **The 2D generator**: recursive-backtracker perfect maze from the corner, exit = BFS-farthest cell. **No braiding, no easy loops.** |
| L3 | Devil speed | Rubber band on distance: **far = faster, close = slower** (2D model, 3D caps §3.4) |
| L4 | Devil spawn | 2D gating (delay + progress + not in a safe circle + step gate), at **a larger, fair distance** (≥8 path cells, out of sight, telegraphed) |
| L5 | Timer | **Real timer. 0 = you lose** (2D). On the exit at 0 = win. Panic in the last 10 s. |
| L6 | Traps | **2D two-step death**: 1st step cracks, 2nd step kills |
| L7 | Safe circles | 2D placement (⅓ and ⅔ of the main route) + a drain timer + 2D step-gated re-acquire. The Devil **retreats**, it doesn't vanish. |
| L8 | Structure | Campaign **"Descent"**: 50 floors in 5 acts of 10. A curve with hand overrides. Checkpoints 11/21/31/41. Daily Maze = a seed. No omens or meta before the fun test. |
| L9 | Revive | GEMINI.md: **max 3 per act**. A revive returns you to the **last safe circle you used**. Premium = free. Ads **only on the death screen**. |
| L10 | Maze Shift | **Not now.** Not in this plan. |

---

## 2. Where I still push back (inside your decisions)

1. **Invert movement, never the mouse or camera.** In 2D the flip swapped the arrow keys, and
   there was no camera. In 3D, W↔S and A↔D swap (keyboard, stick and touch joystick). Mouse look
   stays normal. Inverted look = motion sickness, not fear.
2. **Inversion can't be as frequent as in 2D.** 2D flipped every 1.5–5 s while you hopped 8–12
   cells per second. In 3D you walk about 1.25 tiles per second, so a 1.5 s flip means you
   can't finish one corridor. Use the **2D curve shape stretched ×2.5, clamped to 4–14 s**, with a
   warning that's **never under 0.8 s** (2D bug #2 had no warning at all).
3. **Maze size can't follow 2D up to 29×29.** 2D's 29×29 was fine at 12 cells per second. In 3D,
   a 29×29 perfect maze is about 8+ minutes of pure walking. Use **10×10 (F1) → 20×20 (F50)**. The
   *perfect-maze* rule is what makes it hard, not raw size. The cap is one constant.
4. **Player speed scaling:** 2D went ×1.0 → ×1.5. In first person, cap it at **×1.15**. More is
   nauseating in narrow corridors.
5. **Perfect maze + two-step traps = an off-route trap at a branch entrance dooms you on your
   first step.** You crack it going in, and the only way out is back over it. 2D accepted this
   ("memory pressure"). In 3D it's only fair if the **pre-step cue is unmissable**, so: a creak at
   1 cell, plus hairline cracks visible in the flashlight at ≤1.5 cells, with cue strength floored
   at **0.35** (2D faded to 0.06). Doom traps (dead-end entrances) don't appear before **Act 2**.
   P6 has a hard gate on this.
6. **Explored-only minimap stays.** 2D showed the whole maze top-down. Showing it in 3D would turn
   the maze into a corridor walk.

---

## 3. System specs (all numbers are **targets** and live in data, never inline)

Units: one maze *cell* = 2 tiles (a room plus a wall gap), tile = `CELL_SIZE` 2.4 m. Walk 3.0 m/s.

### 3.1 StageRule — the 2D table, ported
- `scripts/stage_rule.gd` (`class_name StageRule extends Resource`) holds:
  `floor, act, name, maze_cells, player_speed_scale, time_slack,`
  `flip_first_delay, flip_interval, flip_jitter_min/max, flip_warning,`
  `devil_spawn_delay, devil_spawn_distance, devil_base_ratio, devil_respawn_steps,`
  `safe_circle_count, safe_circle_protect_s, safe_circle_single_use,`
  `trap_count, trap_cue_strength, trap_critical_radius, dead_end_traps (bool), is_breather`.
- **Source of truth = the 2D numbers.** A one-off script reads
  `git show main:lib/presentation/gameplay/stage_rules.dart` and emits
  `resources/stage_table_2d.json` (100 rows). `scripts/stage_rules.gd` has
  `static func for_floor(f) -> StageRule`. It samples 2D stage **s = 2f − 1** (F1 = S1, F50 = S99),
  then applies the **3D transforms** from §2 (flip ×2.5 clamped, size curve, speed caps) and the
  overrides.
- **Overrides:** F11/21/31/41 are breathers and checkpoints (the 2D 25/50/75 "Checkpoint Break"
  rows). Act names come from the 2D bands (Awakening, Hunted, Mind Break, Precision Hell,
  THE BREAKER).
- **Invariants (tested for F1–50):** `flip_warning ≥ 0.8`, `4 ≤ flip_interval ≤ 14`,
  `devil_spawn_distance ≥ 8`, close Devil speed < walk, max Devil speed < sprint,
  `safe_circle_count ≥ 1`, `maze_cells` non-decreasing except on breathers, time budget ≥ 1.5×
  the optimal walk time.

### 3.2 Maze — 2D generator, one world (`scripts/floor_layout.gd`, rewritten in place)
- A recursive-backtracker DFS from cell (0,0) with a seeded `RandomNumberGenerator`, which makes a
  **perfect maze**. Exit = the BFS-farthest cell. Spawn = (0,0), the corner room.
- Keep the tile representation (`(2N+1)²` tiles) and the existing API `is_open / distances /
  next_step / validate / cell_to_world`, **minus the `world` parameter**.
- Precompute once per floor: the main route (spawn→exit), each cell's distance from spawn, the
  route index, and cell degree/type (dead end, corridor, T-junction, crossroads). The Devil, traps,
  circles and timer all read this.
- `validate()`: connected, edges = cells − 1 (a tree), exit ≠ spawn. A 1,000-seed test.
- Seed per floor = `hash(run_seed, floor)`. That gives identical retries, the Daily Maze, and
  replayable bug reports.

### 3.3 Inversion — the Reality Flip (`scripts/flip_system.gd`, rewritten in place)
- Same file and class name ("flip" is still the name), with new meaning. Port of the 2D
  `RealityFlipSystem` shape: `signal warning(seconds_left)`, `signal flipped(inverted: bool)`,
  `var inverted`, plus `advance(delta)`.
- Schedule: the first flip at `flip_first_delay`, then every `flip_interval × (1 ± jitter)`,
  clamped 4–14 s. A **warning** of `flip_warning` seconds always fires before every flip.
- Effect: `main.gd` multiplies the movement input vector by −1 while `inverted`. Held keys remap
  instantly, because input is read every frame (the 2D `_holdInputDirection` comes for free).
  Sprint and mouse are unchanged.
- **Presentation (reuses what's already built):** the current WAKE/NIGHTMARE visuals become
  NORMAL/FLIPPED. That's the fog/ambient/glow colour swap and the music crossfade, as in 2D's
  `isFlippedMode` world colours. Add a held **6° dutch tilt** while inverted (a constant "something
  is wrong" cue), the flip glitch sting, and a HUD label `NORMAL`/`FLIPPED` with the warning
  countdown pips. Setting: reduce flashing.

### 3.4 The Devil (`scripts/devil_brain.gd` pure logic + `scenes/devil.tscn`)
- **Spawn gating (2D `_canSpawnDevilNow`):** elapsed ≥ `devil_spawn_delay` · progress
  (`dist_from_spawn[player] / route_length`) ≥ 0.30 · player not in a safe circle · after a
  retreat, the player has entered ≥ `devil_respawn_steps` new cells (2D: 5 → 2).
- **Spawn point (fairer than 2D):** a cell on the player's **trail** that is
  ≥ `devil_spawn_distance` path cells behind. The 2D curve 9→1 is remapped to **14 (F1) → 8 (F50)**
  and never less than 8. The cell must not be visible from the camera (raycast), and a **1.5 s
  telegraph** plays first (a distant slam, then the heartbeat starts). Fallback: the farthest valid
  trail cell, otherwise wait a tick. **Never ahead of you, never in view.**
- **Hunting:** it follows your **scent trail** (cells you entered, newest wins), so it even walks
  your dead-end detours. That's legible and slower than a perfect BFS. While it **sees** you (75°
  cone, 12 m, raycast) or hears a **sprint** (6 path cells), it switches to BFS straight to you.
  It loses you after 8 s of neither → it goes back to the trail.
  *(2D was omniscient BFS. In a perfect maze BFS = your route minus detours, so the difference is
  small but the feel is much fairer.)*
- **Speed (L3).** Let `d` = path cells between the Devil and you:
  ```
  base  = walk * devil_base_ratio          # from 2D devil steps/s: 0.58 (F1) -> 0.90 (F50)
  band  = lerp(0.8, 1.45, inverse_lerp(3, 14, d))   # close slow, far fast (2D 0.7 / 1.5)
  speed = base * band
  caps:  d <= 3 -> speed <= 0.9 * walk*player_speed_scale     (you can always walk away)
         any    -> speed <= 0.92 * sprint                     (never instant catch)
  ```
- **Movement:** BFS `next_step`, repath on a cell change or every 0.4 s, steer smoothly between
  cell centres, **face the direction of travel** (fixes the known debt).
- **Catch (2D):** same cell **or a cross-through** (you swapped cells in one tick), **and** a
  visible **0.35 s lunge** started under 2.2 m that ends under 1.3 m. Blocked inside a safe circle
  and for 3 s after a revive.
- **Audio (2D `devilDistanceChanged`):** every 0.1 s, path distance → heartbeat inside 6 cells,
  plus an `AudioStreamPlayer3D` for steps and breathing.

### 3.5 Safe circles (`scripts/safe_circles.gd`)
- **Placement (2D):** `safe_circle_count` (default 2) at evenly spaced fractions of the
  **interior main route** (⅓, ⅔). Never a trap, the spawn or the exit.
- **Rule (L7):** inside → no catch, and the Devil goes to **RETREAT** (≥10 path cells away,
  out of sight). Protection **drains only while you stand inside** (`safe_circle_protect_s`:
  8 s → 3 s by act). Empty → the circle goes dark until you've entered 12 new cells. Single-use
  from 2D stage >75 → F38+.
- After you step out, the Devil can't re-acquire you until `devil_respawn_steps` new cells
  (the 2D anti-camping rule).
- Feedback: a blue ring whose brightness is the drain meter, `safe_zone_sound`, and a hum
  pitching down. **Entering a circle saves the revive snapshot** (§3.8).

### 3.6 Traps (`scripts/trap_field.gd`) — 2D two-step
- **States (2D):** `HIDDEN →(1st step) CRACKED →(player within critical radius, or Devil within 2
  and player within radius+2) CRITICAL →(2nd step) COLLAPSE = death`. The first step is always safe.
- **A "step" in 3D:** your cell changes *and* you are ≥0.3 m past the edge (hysteresis, so
  grazing a corner never counts). Emitted as `cell_entered(cell)` from player physics.
- **Count (2D `TrapDifficultyScaler`, sampled at s = 2f−1):** 1 → 2 → density 2–7 % of walkable
  cells, max 10.
- **Placement (2D `TrapPlacementEngine`, minus loop logic):** exclude Manhattan ≤3 from the spawn,
  ≤2 from the exit, the first 30 %→17 % of the route, dead-end cells, and safe circles. Score =
  T-junction 86 / dead-end entrance 78 (only when `dead_end_traps`, Act 2+) / chokepoint 52 /
  corridor 30, + revisit score ×42, + progress weight, + 12 on the route, + seeded noise. Take
  ≥55 % from T-junctions. Spacing: Manhattan ≥2, route gap ≥4 (≥3 late).
- **Validator (2D):** never two traps in a row on the route, never on the spawn or exit. The
  first pass along the route touches each route trap exactly once.
- **Cues:** a creak once at 1 cell (re-primes at >2). Cue strength = the 2D fade **floored at
  0.35** (§2.5). CRACKED = a clear decal visible at 2 cells. CRITICAL = dust plus a pulsing creak.
  COLLAPSE = a 0.4 s crack and camera drop, the fall cinematic, a 2D flavour quote (the near-exit
  pool when ≤3 cells away), then the death screen.

### 3.7 Timer (L5)
- `time_budget = ceil(route_m / (walk × player_speed_scale) × time_slack) + 15`, rounded to 5 s.
  `time_slack` goes 2.6 (Act 1) → 1.7 (Act 5) to cover dead-end exploration in a perfect maze.
  Tune it in playtests. The invariant test guarantees ≥1.5× the optimal walk.
- HUD clock is always visible. **≤10 s = panic** (2D): alarm audio, music shift, trap critical
  radius +1. **0 and not on the exit = lose** ("Clock hit zero"). On the exit at 0 = win.
- Paused during: the pause menu, the death cinematic, the floor-clear overlay, an unfocused window.

### 3.8 Run, death screen, retry, revive (`scripts/run_state.gd`, `scenes/ui/death_screen.tscn`)
- `RunState` is saved via `ConfigFile` to `user://save.cfg`. It stores: floor, checkpoint,
  revives used this act, best floor, and the **circle snapshot** (cell, time left, trap states,
  trail).
- Floor clear (2D): an overlay of about 1.4 s, then the next floor with a new maze and a fresh
  timer. After F50 → the victory screen.
- **Death screen (2D loss dialog, upgraded):** the cause *plus the rule* ("Cracked floors break on
  the second step" / "The Devil was slow up close — keep walking" / "Clock hit zero"), metres to
  the exit, the escape % (floor/50), the distance to the next checkpoint, and the 2D comeback line
  (≥90 % "Inches away. Lock in.", ≥70 % "Strong run. Try again.", else "Momentum is building.").
- Buttons: **RETRY** (biggest; same seed, back in <2 s) · **REVIVE** (≤3 per act; restores the
  circle snapshot; an ad hook stub, premium free) · otherwise the act checkpoint.
- Input is blocked during: the floor clear, the death cinematic, pause, and window focus loss (2D list).

---

## 4. What gets removed / changed in existing code (confirm before deleting — CLAUDE.md "ask first")

| Thing | Action |
|---|---|
| `flip_system.gd` World Flip + Flipping Time | **Rewritten** as the inversion schedule (§3.3); tests rewritten |
| `floor_layout.gd` carve/braid/NIGHTMARE/sigils/devil placement | **Rewritten** as the 2D generator (§3.2); tests rewritten |
| `main.gd` `_spot_open`, `_on_flipped` collision swap, the second wall set, sigils, `_open_exit` gating, `_keep_devil_fair` | Removed. `_apply_world` visuals are reused for NORMAL/FLIPPED. |
| Layers 2/3 (wake/nightmare walls) | Collapsed to one wall layer |
| Minimap | Kept (explored-only), single world |
| `FEARFLIP_3D_GAME_APPROACH.md` §4, §6 (monster roster), §7 (Director), §8 | Marked superseded by this file (one line at the top) |

---

## 5. Architecture

- **Pure logic in RefCounted classes, tested headless** (the existing pattern): `stage_rules`,
  `floor_layout`, `flip_system`, `devil_brain`, `safe_circles`, `trap_field`, `run_state`.
  `main.gd` feeds inputs (player cell, delta) and renders outputs.
- **Grid is truth.** Rules run on `Vector2i`, physics only moves bodies.
- **Extract only what you touch:** the Devil → `devil.tscn`, the death screen → its own scene.
  No big-bang refactor.
- Signals up: `cell_entered(cell)`, `flip_system.warning/flipped`, `devil_brain.state_changed`,
  `trap_field.trap_state_changed(cell, state)`, `safe_circles.entered/exited/depleted`,
  `run_state.floor_cleared/died(cause)`. No EventBus autoload until 3+ unrelated listeners need one.
- **No Director in this plan.** In a perfect maze the 2D gating + rubber band + circles already
  give build/peak/relax. Add one only if the fun test says chases feel monotone.

---

## 6. Phases (one branch and PR each, gated)

| # | Phase | Gate | Tests |
|---|---|---|---|
| P0 | Commit the WIP (`model_fit.gd`, the `main.gd` edits). Confirm the §4 removals. | Clean tree | 22 existing pass |
| P1 | **2D maze, one world**: rewrite `floor_layout`, strip World Flip/NIGHTMARE/sigils from `main.gd`, exit opens immediately | Walk F1 corner → exit. No errors. | 1,000 seeds: tree, connected, exit = farthest |
| P2 | **StageRule from the 2D table** + RunState + floors/checkpoints + **timer (lose at 0)** | F1 → F2 grows. Timer kills. Quit/relaunch keeps the floor. | Invariants F1–50. Budget ≥1.5× optimal. |
| P3 | **Inversion** (rewrite `flip_system`) + NORMAL/FLIPPED presentation | It never flips without a warning. It feels tense, not sick. | Schedule clamps, warning always precedes a flip, invert maps the vector |
| P4 | **Devil v2**: gating, trail spawn ≥8, trail tracking, sight/sprint BFS, rubber band, lunge, turning, minimal death screen | 30-min self-play: no death you didn't see coming. Walking away from a close Devil works. | Spawn ≥8 and not visible. Speed caps. Cross-through catch. Gating. |
| P5 | **Safe circles** | They can't be camped. The Devil retreats visibly. | Placement ⅓/⅔ on 1,000 seeds. Drain. Step gates. |
| P6 | **Traps** | **A new player survives their first trap** (the cue works) | 1,000 seeds: exclusions and validator. State machine. Step hysteresis. |
| P7 | **Full death screen + retry + revive** (ad stub) | Retry <2 s. Revive restores the circle. ≤3 per act. | Snapshot restore. Revive limit per act. |
| **GATE** | **Fun test**, 5–10 first-time players | 70 % get inversion unaided, median session ≥6 min, ≥50 % press retry | — |
| P8 | Act polish: names, breathers, audio buses, pause/settings (reduce flashing, FOV), touch controls | — | — |
| later | Daily Maze (seed of the day), then ads/premium (`plans/ads_managment_prompt.md`) | — | — |

Each phase: `godot --headless --path godot -s res://tests/run_tests.gd` plus `project_run` →
`logs_read` (zero new errors). Commit message `feat(godot-3d): ...`.

---

## 7. 2D bugs → fixed by construction

| 2D bug | 3D fix |
|---|---|
| 1 Maze clamped to 17 | `maze_cells` from StageRule, with an explicit tested cap (20) instead of a hidden clamp |
| 2 Empty flip warning | `warning` signal always fires, `flip_warning ≥ 0.8` invariant |
| 3 Safe-zone count/duration ignored | Read from StageRule, and the placement test counts them |
| 4 Devil speed overwritten/clamped | One formula, caps relative to `PlayerFeel`, tested |
| 5 Omniscient Devil | Trail tracking. BFS only on sight or sprint noise. |
| 6 Shift doesn't revalidate | Maze Shift not built (L10) |
| 7 Loop trap logic dead | Loop scoring deleted, not ported (a perfect maze has no loops) |

---

## 8. Risks

| Risk | Guard |
|---|---|
| Inversion + first person = nausea | Movement only, 4 s minimum, warning ≥0.8 s, tilt cue, reduce-flashing setting. P3 gate. |
| Perfect maze too long or boring in 3D | Size cap 20, explored minimap, landmark lights at dead ends (cheap), timer slack tuned in P2 |
| Doom traps feel unfair | Cue floor 0.35, no dead-end traps in Act 1, P6 gate |
| Devil too weak when slower | 2D logic: it kills through dead ends, inversion mistakes and the clock, not speed. Tune `devil_base_ratio`, never the caps. |
| 50 floors wrong | One constant. The 2D table sampling stretches. |
| WebGL/mobile perf at 41×41 tiles | MultiMesh walls (exists), lights every N cells, FPS check at F50 size in P2 |
