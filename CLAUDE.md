# FearFlip — Claude Instructions (Godot 3D port)

## What this repo is
- `main` branch = finished **2D Flutter/Flame** FearFlip (reference implementation, do not modify).
- `new-branch` (this branch) = base for the **3D port** in Godot. Work happens in `godot/`.
- Goal: first-person 3D horror maze. Success = "feels significantly better than the 2D version", not 1:1 parity.
- User is on Windows (`C:\flutter projects\fearflipgame`). Godot editor + `godot-ai` MCP connector are used for the engine side.

## CREDIT-SAVING RULES (read first)
1. **Do not explore the repo.** Use the maps below. Open a file only if the task needs it, and then read only the line range you need (use the section map).
2. **Never read** (huge or binary): `godot/.godot/`, `build/`, `android/ ios/ web/ windows/ linux/ macos/`, `*.glb`, `*.png`, `*.jpg`, `*.mp3`, `*.wav`, `*.import`, `*.zip`, `*.jks`, `pubspec.lock`, `lib/RULES.TXT`, `prompt_fearflip.md`, `report_of_fearflip.md`, `plans/02-audit-findings.md`, `plans/03-ui-viral-upgrade.md`, `plans/ads_managment_prompt.md`, `docs/`, `functions/`. For `plans/04-godot-3d-port.md` (55 KB) grep a heading, then read only that section.
3. **Grep before read.** `Grep` for a symbol, then `Read` with `offset`/`limit`. For Flutter reference code (e.g. `game_screen.dart` 79 KB, `stage_rules.dart` 53 KB) read ~40 lines around the function, never the whole file.
4. **Edit, don't rewrite.** Use `Edit` / godot-ai `script_patch` for surgical changes. Don't re-read a file after editing it. Don't paste file contents back to the user.
5. **Prefer godot-ai MCP tools over reading files** for scene/node/property work (`node_find`, `node_get_properties`, `node_set_property`, `script_patch`, `batch_execute` to combine many calls in one round-trip). Screenshots (`editor_screenshot`) only when visual judgment is the point.
6. **Verify by running, not by re-reading**: `project_run` then `logs_read`; fix errors from the log.
7. Don't spawn subagents for things a Grep can answer. Keep replies short; summarize outcomes in 1–3 sentences.
8. Plan first for anything touching >2 files; state the plan in a few lines, then execute. One phase/feature per session.

## Godot project facts (`godot/`)
- Name "FearFlip 3D Prototype", Godot **4.7**, renderer **`gl_compatibility`** (desktop + mobile). Plan wants Forward+ desktop / Mobile renderer Android — **ask before switching**.
- Window 1280x720, stretch `canvas_items`. Main scene `res://scenes/main.tscn` (just a root `Node3D` + `scripts/main.gd`).
- Autoload: `_mcp_game_helper` (godot-ai addon, `addons/godot_ai/`) — don't edit the addon.
- **The whole world is built in code** in `main.gd::_ready()`. The editor scene tree is nearly empty, so scene tools show little until runtime.
- Feel tunables: `scripts/player_feel.gd` (`class_name PlayerFeel`, Resource) + `resources/player_feel.tres` (assigned to `main.gd::feel`). Footsteps: `assets/audio/footstep_{1,2,3}.wav` (generated placeholders) via `AudioStreamRandomizer`. Test: `tests/test_player_feel.gd`.
- Files: `scripts/main.gd` (floor scene builder + glue), `scripts/floor_layout.gd` (`FloorLayout`: seeded carve/braid, WAKE+NIGHTMARE grids, sigils, devil spawn, `validate()`, `distances()`, `next_step()`), `scripts/flip_system.gd` (`FlipSystem`: manual flip + Flipping Time, pure logic), `scripts/character_rig.gd` (`class_name CharacterRig`), `scripts/minimap.gd`. Run structure (plans/06): `scripts/stage_rule.gd` (`StageRule`: 5 acts x 10 floors, sawtooth `difficulty`, F5 Sanctuary / F10 Gate), `scripts/run_state.gd` (`RunState`: one run = one act, `start_run`/`end_run`/`clear_act`, `user://save.cfg`), `scripts/meta_state.gd` (`MetaState`: acts unlocked, `user://profile.cfg`), `scripts/main_menu.gd` (dashboard + act picker). Assets: `assets/audio/` (13 tracks), `assets/character/{character1,devil}.glb` (~60 MB each + 2–8 MB textures), `assets/images/` (exit_portal.png, plus legacy 2D `*_frames/` sprite sets — unused in 3D).
- Constants (top of `main.gd`): `CELL_SIZE 2.4`, `WALL_HEIGHT 2.8`, `CEILING_HEIGHT 3.0`, `DEVIL_CHASE_SPEED 3.6`, fairness (`FAIR_FLIP_DISTANCE`, `FLIP_CATCH_GRACE`), per-world look arrays. Exports: `fixed_seed` (0 = random), `rooms` (7 = 15x15). Generator targets are consts in `floor_layout.gd`; flip timings are vars in `flip_system.gd`.
- Coordinates: grid `Vector2i(col,row)` -> world `Vector3(col*CELL_SIZE, 0, row*CELL_SIZE)` via `cell_to_world()` / `world_to_cell()`. **Grid is truth, 3D is projection** (physics never decides game state).

### `main.gd` sections (grep to find)
`_ready` (generate layout, wire FlipSystem signals) · `_process` (flip.advance, devil tick, sigils, win/lose) · `_physics_process` (movement, gravity; no jump) · `_unhandled_input` (look, Esc, R, `flip`) · World Flip: `_spot_open`, `_on_flipped`, `_apply_world` (collision mask, wall sets, fog/glow, music), `_keep_devil_fair` · `_collect_sigils`/`_open_exit`/`_step_devil` · Build: `_build_maze` (`_build_wall_set` = 1 body + 3 MultiMeshes per world), `_build_goal`, `_build_sigils`, `_build_devil`, `_build_hud` (anchored labels) · `_lose_game` (teaches the rule + distance to exit).
`character_rig.gd`: `build(model_scene)` splits the first `MeshInstance3D` of `character1.glb` into head/torso/arms/legs pivots by hard-coded vertex-centroid thresholds in `_classify()`; `animate(moving, delta, speed)` does procedural walk. Changing the model means retuning `pivots` and `_classify`.

### Already working
Seeded 15x15 floor in two worlds (WAKE/NIGHTMARE, physics layers 1 shared / 2 wake / 3 nightmare), World Flip (Space/E, 6 s cooldown, refused if you'd land in a wall, roll + flash), Flipping Time (45 s, then every 40–60 s ramping; 3 s warning; 12–20 s in NIGHTMARE), 2 keys/sigils (`FloorLayout.SIGIL_COUNT`, ≥1 NIGHTMARE-only) open the exit + enrage the Devil, Devil only in NIGHTMARE (smooth lerp, waits where you vanished), explored-only minimap (no enemies), calm/intense music crossfade, first-person look/WASD/sprint, flashlight, R twice = restart the act (new run, new maze). Tests: `godot --headless --path godot -s res://tests/run_tests.gd` (106 tests incl. 1,000-seed generator check; after adding a `class_name`, run `godot --headless --path godot --import` once or the new class is unknown). Structure plan: `plans/06-engagement-act-runs.md` (P1 Act-Runs + P2 Rewards done: Fear Shards/chest rolls/unlock bar in `MetaState`, `RunState.bank()`, grades in `StageRule.grade()`, Close Call/Phase Dodge + HUD pops in `main.gd`; P3 Floor variety done: rule cards/doors/Gate twists/Sanctuary in `scripts/cards.gd` (`Cards`, `RunState.mod()` folds a floor's cards), 3-card picker `scripts/card_choice.gd` (`CardChoice`), per-act look in `main.gd`; next P4 omens + curses). Master plan now: `godot/FEARFLIP_3D_GAME_APPROACH.md` (§17 roadmap); next = Devil senses + Director (§7), death screen/retry (§5), safe circles/threats (§6).

### NOT built yet (the real work)
Devil senses/state machine + Director (it is still omniscient in NIGHTMARE), traps/safe circles/Phantom/Sentinel/Ripper (§6), braid landmarks/alcoves + chalk, depth curve/omens/meta (§5), death screen UI, audio buses, pause menu, settings (reduce flashing/roll), web export + CrazyGames SDK, mobile/touch controls.

### Known issues / debt (fix when touching nearby code)
- World lights: unshadowed `OmniLight3D` every `world_light_spacing` (default 4) open cells; only the flashlight casts shadows. Tunable on the `FearFlip3D` root node (Inspector).
- HUD labels are anchored now; minimap still sits at a fixed (20,20) offset.
- `main.gd` is a monolith; plan is to extract `player.tscn`, `devil.tscn`, `goal.tscn`, `maze_builder.gd`, `maze_data.gd` (Resource). Extract incrementally, one piece per task.
- Indentation: `main.gd` uses **tabs**, `minimap.gd` uses **4 spaces**. Never mix within a file; new files use tabs.
- Devil glides between cells but never turns to face its movement; `character_rig.gd` leaks `character1.glb` instances at exit (visible in `--verbose`).

## Plan & reference (don't re-derive; look up)
- **Structure & engagement (current):** `plans/06-engagement-act-runs.md` — Act-Runs (5 acts x 10, each act one run), the options catalog, roadmap P0–P9. Overrides `plans/05` L8 and master plan §5.
- Port plan: `plans/04-godot-3d-port.md` — 10 phases with acceptance gates (Phase 1 plumbing -> 2 movement feel gate -> 3 flip/goal/timer -> 4 devil+safe zones -> 5 traps -> 6 maze shift/inversion -> 7 100 stages -> 8 polish -> 9 Android -> 10 monetization). Sections: §1 architecture, §2 scene tree, §3 file layout, §4 Flutter->Godot mapping table, §7 APIs, §8 worktree workflow. **The plan is partly stale vs. code**: it mentions sprite-sheet characters (now 3D GLB models) and Manhattan-greedy devil (now BFS); its line numbers are old. Trust the code.
- Flutter source of truth (per plan): `lib/presentation/gameplay/game_screen.dart` (devil BFS `_nextDevilStep` ~L1499-1531), `maze_generator.dart`, `stage_rules.dart` (100 stages), `maze_shift_manager.dart` (shift when `stage % 6 == 0`), `lib/game/trap/*` (trap state machine: hidden->cracked->critical->collapsed), `lib/services/audio_manager.dart`. `lib/game/{game,devil,maze,player,...}.dart` is **legacy dead code — don't port from it**.
- Plan lists 6 Flutter wiring bugs (maze size clamp, empty warning branch, safe-zone count/duration ignored, devil speed caps/renormalization) — **fix them in the port, don't copy them** (plan §0.5).
- Branches: `feature/godot-3d-plumbing` (phase-1 commit), `feature/godot-3d-maze-audio`, `feature/godot-3d-characters`; older `feature/3d-walk*`, `feat/sheet-slicer`. Worktrees in `.worktrees/`. Run `git log --oneline -5` before assuming what's merged. One phase = one worktree/branch/PR.

## Gameplay rules (from GEMINI.md — still apply in 3D)
- Tense but **fair**: never instant catches or unavoidable situations. Fairness > difficulty; no sudden spikes.
- Devil: farther from player = faster, close = slower; min speed lets you escape, max pressures without instant death.
- Stages 1-10 easy, 10-25 moderate, 25+ add complexity not unfair speed.
- Ads (later): never during gameplay; rewarded ads only for revive (max 3 per stage cycle 1-25); premium = no ads + free revive.
- Keep balance numbers in config constants/Resources, never magic numbers inline.

## Godot 3D conventions (GDScript, 4.x)
- **Static typing** everywhere (`var x: float`, `-> void`). `@export` for tunables, `class_name` for reusable scripts, `Resource` subclasses for data (`MazeData`, `StageRule`).
- Movement in `_physics_process`; input via **InputMap actions** (`Input.get_vector("move_left","move_right","move_forward","move_back")`), not raw keys. Mouse look in `_unhandled_input`; `Input.mouse_mode = MOUSE_MODE_CAPTURED`.
- `CharacterBody3D`: set `velocity`, call `move_and_slide()`; rotate body on Y (yaw) and a head pivot on X (pitch, clamp ~±1.35). Detect grid cell each physics frame and emit `cell_entered(cell)` for traps/safe zones.
- Communicate with **signals** ("call down, signal up"); avoid `get_node("../..")` chains; use groups or exported `NodePath`/typed refs. Use `await get_tree().create_timer(t).timeout` for one-shots.
- Reusable things (player, devil, goal, trap, overlays) become `.tscn` scenes; code-built nodes only for procedural geometry.
- Rendering: keep `StandardMaterial3D` instances shared (build once, not per wall). Many identical walls -> consider `MultiMeshInstance3D` or merged meshes; GridMap only if per-cell animation isn't needed (plan §10.4 decides).
- Lighting/perf: shadows only on the flashlight and a few key lights; `WorldEnvironment` fog (`fog_enabled`) for the distance cutoff. **Volumetric fog, SDFGI, SSAO/SSIL are Forward+ only** — horror look must work without them.
- Audio: `AudioStreamPlayer3D` for the devil (attenuation), buses Master/BGM/SFX/Devil/UI (`default_bus_layout.tres`).
- Pathfinding: `AStarGrid2D` — set `region` + `cell_size`, call `update()`, **then** `set_point_solid()` (update resets solids). Re-bake after maze shifts; repath ~every 0.4 s, not per frame.
- UI: `CanvasLayer` (HUD layer ≥1, overlays ≥10), `Control` anchors/containers, not absolute pixels. Minimap: redraw only on state change.
- Mobile later: touch joystick + right-half drag look; keep draw calls/lights low; compress textures (current GLB textures are 2–8 MB each — resize/compress before Android).
- Look up exact class/method signatures with the godot-ai API/docs tool or Godot docs instead of guessing — 4.7 may differ from older training data.

## godot-ai MCP tools (editor must be open with plugin enabled)
`scene_*`/`node_*` (structure, properties), `script_create/patch/attach`, `resource_manage`, `material_manage`, `camera_manage`, `particle_manage`, `animation_*`, `audio_manage`, `input_map_manage` (set up actions here), `autoload_manage`, `filesystem_manage`, `project_manage`, `project_run` + `logs_read` (verify), `test_manage`/`test_run` (GDScript tests), `batch_execute` (combine calls), `editor_screenshot`/`editor_state`, `session_manage/activate`. If a call fails because the editor isn't connected, say so — don't retry in a loop.

## Workflow
1. State goal + files you'll touch (≤5 lines). 2. Targeted grep/read. 3. Small edits. 4. `project_run` + `logs_read`; zero errors/warnings you introduced. 5. For gameplay logic add a test (GDScript test via `test_run` or a headless check). 6. Commit small, message `feat(godot-3d): ...`; never touch `main`'s Flutter code from this branch.
- Don't commit large binaries, `.godot/`, keystores (`*.jks`), or `keystore/`. Never expose secrets in `firebase.json`/`firestore.rules`/keystore files.
- Respect "ask first": renderer switch, project-wide restructure, adding plugins/addons, deleting files.
