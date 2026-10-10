# 09 — Player's-eye audit (10 Oct 2026)

How this was done: your real playtest log (`user://events.jsonl`: 27 runs, 129 card picks, 52 map uses) and profile
(16 deaths, 109 flips); your live session watched through screenshots only, with no input sent; every gameplay
script read; the floor curve measured over 40 seeds per floor; what the player sees at the spawn and one cell from a
hidden crack captured on separate save paths. Tests: 260/260 before, 263/263 after.

## 1. Bugs fixed

| # | Bug | What the player got | Fix |
|---|---|---|---|
| 1 | `main.gd` `debug_trap_step` defaulted to 3 and no scene overrode it | Every shipped floor had a cracked floor on the route's 3rd tile. It sat inside `TrapField.SPAWN_CLEARANCE`, before the 30% route grace, and skipped the cross-once check. This explains your two trap deaths 15 s and 23 s into a floor (progress 0.01 and 0.02). | Default 0; `test_no_cracked_floor_by_the_spawn` |
| 2 | `_spot_open` sampled a 0.35 m square, not the capsule's circle | Flips were refused while rounding any corner: on seed 42 F1, all 19 corners refused although the capsule was 0.42 m from the pillar. Flipping Time still waits on this check. | Exact circle-vs-cell check; `test_flip_is_not_refused_rounding_a_corner` |
| 3 | Revive and Last Breath kept the Devil's spawn trail | It could wake ahead of you, on the cells you walked after the circle, which is the way you are about to walk again | `DevilBrain.rewind()` back to the trail length saved at the circle; `test_revive_rewinds_the_scent` |
| 4 | "find 1 more keys" | Text | Pluralised |
| 5 | Playtest log | A revived death logged `run_end` and nothing after it, so run ends were over-counted. Deaths didn't record Flipping Time. | `revive` event; `world`, `flipping` on `death`; `kit` on `run` |
| 6 | The camera started facing north | Every floor began staring at the spawn corner's border wall (10 of 10 seeds) | `_build_player` faces the first open corridor; `test_spawn_faces_a_corridor_not_a_wall` |
| 7 | `best_floor` could pass the acts opened | Your save had 50 with only Act 1 open: the dashboard said "ACT 2 SHORTCUT · 1 FLOOR TO GO · 9/10" and deaths said "best floor 50/50" | Clamped on load (`RunState.load_save`) unless the Abyss is open; `test_best_floor_never_passes_the_acts_opened` |

## 2. Decided and built (10 Oct 2026)

- **No flip button: the world flips only on its own, at random.** You chose this over world-locked keys.
  - Space/E is unbound, and the HUD hint and the manual-flip code are gone: `FlipSystem` charges and cooldown,
    `request_flip`, the deny cue, Phase Dodge.
  - The first Flipping Time now lands at 45 s ±25%, seeded per floor (`FlipSystem.arm()`). The rest was already random.
  - The plate's flip icon shows only while Flipping Time holds you: red, with the seconds left.
  - Cards that tuned the button were reworked in place, so ids, saves, Altar prices and sigil art stay valid:
    - Quick Veil: NIGHTMARE lets go 30% sooner (new `flip_duration` mod).
    - `twin_flip` became **SOUND SLEEPER**: Flipping Time a quarter less often. Your 70 shards now buy something.
    - Heavy Veil (rank 7), Deep Freeze and Quicksilver moved onto `flip_duration`.
  - The Phase Dodge challenges (Wide Awake / Sleepwalker / Between Worlds) and quests now count Flipping Times ridden
    out (new `nightmares` stat). "Flip N times" now reads "Live through N flips".
  - HOW TO SURVIVE and the NIGHTMARE / Flipping Time bestiary entries now say what the game does. The Devil's lines
    were rewritten by the Devil-chase session.
- **Braided mazes** (`FloorLayout.BRAID` 0.12): 12% of dead ends are knocked through into loops after the exit is
  chosen, giving 2–3 loops a floor. Routes got shorter on the same maze sizes:

  | Floors | Route before | Route now | Clock now |
  |---|---|---|---|
  | F1–F3 | 184 tiles (442 m) | 142 tiles (340 m) | 5:10 on F1 |
  | F4 on | 213 tiles (512 m) | 180 tiles (432 m) | 6:15 on F4, down to 4:20 on F49 |

- **Start kit kept on retry.** R or TRY AGAIN replays the same act with the curse and omens you picked last time
  (`RunState.kit`, saved). Only a run started from the menu offers the picks again.

## 3. Still open (not built)

1. **Hidden cracks can't be seen.** I stood one cell away with the flashlight on the crack, on F1 (cue 1.0) and Act 5
   (cue 0.35). The crack looked like every other tile:
   - the floor art is cracked stone everywhere, and the hairline decal blends into it;
   - the ember shows only through 1.4 cm seams;
   - the only visual tell is a thin dark outline, plus a faint red edge on Act 5.

   The creak one tile out is the real warning. Placement also scores junctions on the route highest (T-junction 86 +
   on-route 12), and a cracked junction can never be stepped on again. Traps cause 7 of your 16 deaths.
   *Fix:* tint the hairline warm and keep it bright in Act 1; stop preferring route junctions.
2. **Forced flips snatch the map.** 20 of 52 map closes were caused by a flip; 7 of those maps were reopened within 3 s.
3. **No pause menu.** Esc only shows text. Mid-floor, the only ways to Settings or the menu are R R (which wipes the run)
   or quitting the game. You also can't back out of the pick screen. *Fix:* Resume / Settings / Quit to menu.
4. **Long acts.** Even braided, an act is 10 floors of ~4–5 min, and dying on F9 restarts at F1.
   *Option:* restart from the Sanctuary (F5) once you've reached it.
5. **Ghost Sight (170 shards) does nothing**: the worlds share one maze, so it shows no walls. Rework it or pull it from
   the Altar.
6. `sfx_flip_denied.mp3` is now unused. It's left in place because deleting assets needs your OK.

Deliberate choices left alone: the strict sprint (a tap costs the 6 s rest), inverted controls in Flipping Time, no
minimap, and big mazes. The new `flipping` field on `death` will show whether inverted controls are what kills.

## 4. What already works (keep it)

- Up close the Devil is always slower than your walk (`DevilBrain.CLOSE_CAP` 0.9), so deaths come from mistakes, not
  raw speed.
- Close Call slow-mo with a shard pop, the Devil Cam, and the death screen's "N m from the exit" line.
- The map has a real cost: a 0.25x walk, and it snaps shut near the Devil. You still opened it 52 times, so it's wanted.
- Grades, chests, the Daily with quests and streak, and act stars give every run something to bank.
