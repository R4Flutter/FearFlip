# 07: Landmarks (make the maze memorable)

**Status (8 Oct 2026): L1-L5 built** (`scripts/landmarks.gd`, `tests/test_landmarks.gd`, `main.gd::_build_landmarks`,
minimap marks, prompts in `assets/ASSET_PROMPTS.md` §3b). Every floor is 25x25 or 27x27 now (`StageRule.ROOMS_3D`
12..13), so the count scales: one landmark per 11 open cells (~27 on 25x25, 31 on 27x27), ~87% of open cells within
4 steps at every size, ~20-25 ms per big floor. 19 names (glyphs run I-XII); on big floors a name repeats, but only
14+ tiles from its twin. Changed from the
plan: worlds share one maze now (`FloorLayout.NIGHTMARE_CHANGE` = 0), so every landmark is an anchor and there's no
world-only kind. Lamps get a halo, because walls are one mesh each and the Compatibility renderer gives a mesh at
most 8 lights, so a lamp's colour barely reaches them. L6 (the event log and the playtest) is still open.

**Why.** The paper-map twist (the minimap goes away and you read a map in your hands) only works if
the player can link the map to the corridors around them. Today every corridor looks the same: walls
are one material per world, there's a lamp every `world_light_spacing` cells, and blood or scratch
decals land at random. Players can't remember a route through that. Landmarks come first; the paper
map and chalk follow (plans/08).

**Success.** In playtests, players give directions out loud like "left at the red lamp, then past the
statue." After a flip, they can find their place again within about 3 s, using a landmark that exists
in both worlds.

---

## Design rules

1. **Grid is truth.** Landmarks are pure data: a seeded `Landmarks` object from `FloorLayout`, the
   same pattern as `SafeCircles` and `TrapField`. They never change walls, so `FloorLayout.validate()`
   and the 1,000-seed test stay untouched.
2. **Put them at decisions.** Place landmarks on junctions (3 or more open neighbours) and corner
   turns first, then straight corridors only if coverage still has gaps. A landmark in the middle of
   a straight corridor helps nobody.
3. **Coverage.** Every open WAKE cell is within `COVER_RADIUS` (4) path cells of a landmark. Keep
   landmarks at least `MIN_SPACING` (4) cells apart. On a 15x15 floor that comes to about 6–9.
4. **Anchors survive the flip.** Prefer cells that are open in **both** worlds; aim for at least 60%
   of landmarks. Those are what you reorient on after a flip. A world-only landmark appears only in
   its own world.
5. **Unique per floor.** No two landmarks share the same (kind, colour) pair, and no same kind
   within 6 cells. Every landmark should be nameable in two words: "red lamp", "the statue".
6. **Seen from a distance, read up close.** Each landmark has a far cue (light or silhouette, visible
   down a corridor in fog) and a near cue (a glyph or prop). Fog and the flashlight decide what
   carries; the far cue must work without the flashlight.
7. **Never on gameplay cells.** Keep them off spawn, exit, sigils, trap cells, circle cells, detour
   chests and the Altar. Clutter there would hide what matters.
8. **Cheap.** Landmark lights replace the normal lamp on their cell instead of adding to it.
   Budget: no more than 4 extra `OmniLight3D`s per floor, no shadows, props as MultiMesh or a single
   mesh, glyphs as `Label3D` or decals.

## Kinds (v1)

| Kind | Far cue | Near cue | Stand-in now | Art slot later |
|------|---------|----------|--------------|----------------|
| `lamp` | coloured light (red, green, amber, violet) | caged lamp in that colour | existing lamp mesh + tinted bulb/light | none |
| `flicker` | a lamp that stutters on a seeded rhythm | same | light energy wobble | none |
| `glyph` | big painted symbol on the wall, softly emissive | ☾ △ ✕ ◯ ⌘ ∆ (one per floor each) | `Label3D` (ui.ttf), `no_depth_test` off | `decal_glyph_*.png` |
| `statue` | tall silhouette in the fog | hooded figure on a plinth | `CapsuleMesh` + `BoxMesh` plinth | `landmark_statue.glb` |
| `debris` | a pile partly blocking the cell's side wall | broken chairs and crates | 3 rotated `BoxMesh` | `landmark_debris.glb` |

Colours come from a fixed palette const that stays separate from the WAKE/NIGHTMARE look colours,
so a red lamp reads as red in both worlds.

## Phases

### L1: logic (`scripts/landmarks.gd`, `class_name Landmarks`)
- `func _init(layout: FloorLayout, seed_value: int, excluded: Array[Vector2i])`, with its RNG seeded
  by `hash([seed_value, "landmarks"])`.
- Data: `cells: Array[Vector2i]`, `kinds: Array[int]`, `colors: Array[int]`,
  `worlds: Array[int]` (ANY / WAKE / NIGHTMARE), and `facing: Array[Vector2i]` (the wall a glyph
  sits on, facing the junction's main approach).
- Greedy cover: build the candidate list (junctions, then corners, then straights). Repeatedly take
  the candidate farthest from every chosen landmark (`FloorLayout._distances_from`-style multi-source
  BFS over WAKE) until max distance ≤ `COVER_RADIUS`. Stop at `MAX_LANDMARKS` (10).
- Assign kinds and colours from shuffled pools so each pair is unique.
- `func at(cell: Vector2i) -> int` (index or -1), for the minimap and future Director hints.
- Tunables as consts at the top: `COVER_RADIUS`, `MIN_SPACING`, `MAX_LANDMARKS`, `ANCHOR_SHARE`.

### L2: tests (`tests/test_landmarks.gd`, registered in `run_tests.gd`)
Over 200 seeds:
- Deterministic: the same seed gives the same landmarks.
- Coverage holds, or the floor is capped at `MAX_LANDMARKS` (if capped, report it).
- Spacing holds.
- Never placed on an excluded cell.
- Each (kind, colour) pair appears only once.
- Anchor share is at least `ANCHOR_SHARE`.
- Every landmark cell is open in its own world.

Run `godot --headless --path godot --import` once first (new `class_name`).

### L3: build (`main.gd`)
- `var landmarks: Landmarks` is created in `_ready()` after traps, circles and chests exist, so the
  excluded list is complete.
- In the `_build_maze()` light loop: on a landmark `lamp`/`flicker` cell, tint the light and bulb.
  Any other landmark light becomes one of the ≤4 extra lights.
- Add a new `_build_landmarks()` next to `_build_dressing()`, adding everything under a `Landmarks`
  `Node3D`. World-only landmarks join the existing wall-set visibility toggle in `_apply_world`, so
  they appear and disappear with their world.
- Keep the flicker in `_process`, driven by one shared timer (no node per lamp).

### L4: minimap (`minimap.gd`)
- Draw each landmark as a small glyph or coloured dot in its colour, in the same visual language as
  the world. World-only ones show only in their own world.
- The paper map in plans/08 reuses this drawing, so the link between map and world gets built now.

### L5: art prompts (`assets/images/PROMPTS.md` style, with fallbacks)
- Write prompts for the glyph decals, the statue and the debris pile. Code keeps the stand-ins until
  the files exist, through `Art.decal` and `Art.model`.

### L6: verify and playtest
- `project_run` + `logs_read` (no new errors). Take one screenshot down a corridor with the fog on
  to check that far cues read.
- Log `landmark` positions per floor in `events.jsonl` (`RunState.log_event`). Later, deaths can be
  correlated with "far from any landmark".

## Out of scope (own plans)
- **Paper map** (raise animation, slow walk, snap shut when the Devil is near): plans/08.
- **Chalk** (C marks a wall and shows on the map; fake chalk in NIGHTMARE): plans/08.
- **Alcoves and landmark rooms**: these change the generator and need the 1,000-seed check. They
  belong with the Ripper (§6).
- **Director hints that name landmarks** ("the key is past the red lamp"): one line in `director.gd`
  once L1 exists.

## Files
New: `scripts/landmarks.gd`, `tests/test_landmarks.gd`. Edited: `scripts/main.gd`,
`scripts/minimap.gd`, `tests/run_tests.gd`, and `CLAUDE.md` (map entry).
Branch: `feature/godot-3d-landmarks`, one PR.
