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

**Update, 11 Oct 2026 (bug sweep):** items 1, 3 and 5 are done, and the sweep fixed more (see §5). Items 2, 4 and 6, and
Settings inside the pause menu, stay open.

**Update, 15 Oct 2026 (plans/10 §4):** items 2 and 4 are done. A flip no longer takes the map, and after a death past the
Sanctuary, TRY AGAIN restarts there.

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

## 5. Bug sweep (11 Oct 2026)

How it was checked: every gameplay script read; the full suite; a bot that plays real floors headless (real physics and
input, through both keys to the chest) on 17 floors from Act 1 F1 to the Abyss with card mixes, about 55 minutes of play
with no script error and no stuck spot, plus a catch run (death, Devil Cam, revive); windowed screenshots one cell from a
hidden crack on F1 and F44.

| Bug | What the player got | Fix |
|---|---|---|
| A crack's molten glow never showed in play | `TrapPit.crack()` never switched the decals, so a cracked tile kept its hairline and no glow until a revive | `crack()` shows CrackGlow and hides the hairline |
| Hidden cracks blended in (§3.1) | No visual tell on F1 | The crack glow shows faintly on hidden tiles too, at the floor's cue: plain on F1, faint by Act 5. Route junctions no longer score higher for a trap |
| Ghost Sight did nothing (§3.5) | Both worlds share one maze, so there were no "other walls" to show | Reworked: the Devil's glow shows through walls within 10 cells |
| Mirror Night did nothing | NIGHTMARE only comes with Flipping Time, which already inverts your steps | Reworked: in NIGHTMARE your look is mirrored too |
| Your own head blocked the view | Looking down showed the top of your head (the code only hid it at the chest) | The body sits on its own render layer: your eyes skip it, the Devil Cams and the trap fall's camera see it, and it still casts its shadow |
| Breathing went silent after a revive | The death stopped both breath loops and nothing restarted them | `_revive()` restarts them, and brings back a Flipping Time warning that was running |
| One R during the chest animation | Restarted the whole act, throwing the cleared floor away | R does nothing while the keys turn |
| A wake timer outlived a revive | The Devil could wake on an old spot after you came back | The telegraph timer checks it's still due |
| No pause menu (§3.3) | Esc showed a line of text | Pause menu (RESUME, QUIT TO MENU); focus loss or a tab switch pauses; Esc on a pick screen goes to the menu (the pick is saved) |
| Reduce Flashing / Reduce Motion gaps | The death screen's hit, its revive flash and the menu's start flash were full strength; the death screen shook | All go through `Settings.flash()`; the death screen's shake respects Reduce Motion |
| Web export carried ~150 MB of unused models | `character1.glb`, `devil.glb` and their textures are referenced nowhere | `export_presets.cfg` excludes them (the files stay) |

Noted, not changed: a player who keeps walking is never caught (the Devil trails 9-13 tiles behind on every act, as the
CLOSE_CAP design intends), so deaths come from stops, backtracking and the map. `character_rig.gd` is dead code.
