# FearFlip 3D: Game Approach (Master Plan)

Version 1.0, 3 October 2026. For the Godot 4.7.2 project in this folder (Compatibility renderer).
Goal: a 3D horror maze people replay and recommend, launched on the web and built to earn money.

How to read this file:
- Read §0 (one-page summary) and §1 (decisions to lock) first.
- Then build in the order of §17 (roadmap). Don't skip the playtest gates.
- A number marked **target** is a starting value you tune in playtests.
- A tag like **[S12]** points to a source in the list at the end.

> **Assumption about "the Flip".** I couldn't open the Flutter 2D code from here. Your 2D assets
> (`fahhhhh_flippingtime.mp3`, `maze_shift_audio.mp3`, `glitch_screen_sound_effect.mp3`) suggest
> the 2D flip is a timed maze change. This plan keeps that as **Flipping Time** and adds a
> player-controlled **World Flip**. If your 2D rule is different, keep the structure of §4 and
> swap in your rule.

---

## 0. The plan on one page

**What it is.** FearFlip is a first-person horror maze where you flip between two versions of the
same maze: **WAKE** (cold, quiet, mostly safe) and **NIGHTMARE** (red, hunted by the Devil).
Collect 3 sigils across both worlds, open the exit, and escape. Every floor is a new seeded maze.
Go as deep as you can, unlock new options, come back for the Daily Maze.

**Why it can win.**
- Proven demand. Maze and liminal horror is one of the strongest indie categories right now:
  Escape the Backrooms has an estimated 3.8M copies sold on Steam [S1]. The Exit 8, made by one
  developer, passed 3M copies [S6][S7]. A24's *Backrooms* film opened on 29 May 2026 and became
  A24's highest-grossing film in North America [S12].
- A real hook. "Flip to survive" gives the player a decision every few seconds. It makes a
  moment people clip and share, and it explains the name.
- Web-friendly. Short runs, instant retry, small download, and it runs on Chromebooks and phones.

**How it makes money (honest version).** Web portals pay you a share of ad revenue. That brings
reach, but for most games the income is modest [S29][S30]. The bigger money in horror is on
Steam, especially with co-op [S1][S2][S4][S13]. So the path is:
**free web game (ads) → audience and proof → paid Steam version with co-op.**
Vampire Survivors took a similar path: a free browser game on itch.io in March 2021, then Steam in
December 2021 [S31].

**Launch path.** CrazyGames first. It is non-exclusive, supports Godot 4 web builds, has a horror
category, and asks for PEGI-12 content. Then a Full Launch with ads, then a Steam page and demo. Poki
only if they invite you and you can hit their target of under 8 MB initial download [S17][S18][S20][S22][S24].

**Timeline.** About 8 weeks to a launch-ready web build. First real-player test at week 3.

---

## 1. Decisions to lock now (the "no regret" list)

| # | Decision | Recommendation | Why |
|---|---|---|---|
| 1 | Signature mechanic | Two-layer **World Flip** plus timed **Flipping Time** | Gives agency, it's unique, and it matches the name |
| 2 | Session shape | Roguelite: 2–4 minute floors in endless runs, plus a Daily Maze | Portal tests reward playtime and next-day return [S15][S19] |
| 3 | Platform order | CrazyGames → Steam. Poki is optional | Download size limits, exclusivity, audience fit |
| 4 | Art style | Lo-fi / PS1-style liminal look, fog, low internal resolution | Fits the trend, tiny downloads, runs on weak devices |
| 5 | Monster design | Every threat has a **telegraph** (warning) and a **counter** (rule) | Fair fear makes people try again [S9] |
| 6 | Pacing | AI Director with a "menace gauge" | Avoids nonstop-chase fatigue [S11] |
| 7 | Engine | Stay on Godot 4.7.2. Compatibility renderer. Single-threaded web export | CrazyGames needs single-threaded Godot 4 builds [S24][S25] |
| 8 | Budgets | Initial download ≤ 20 MB, load ≤ 10 s, 60 FPS desktop, 30+ FPS low-end | This is the profile of top CrazyGames games [S19][S20] |
| 9 | Monetization | Platform ads only, at natural breaks, plus optional rewarded ads. No paid loot boxes | Platform rules [S17][S21]; Belgium treats paid loot boxes as gambling [S33] |
| 10 | Scope | Single-player first. Co-op only for the Steam version | Co-op sells well on Steam but costs the most to build |

---

## 2. Where the project is today (audit of this Godot project)

**Keep these. They're already good.**
- Godot 4.7.2 with the **Compatibility renderer**. This is the right choice for web.
- The `PlayerFeel` resource (`resources/player_feel.tres`): walk 3.0 m/s, sprint ×1.5, head-bob,
  FOV breathing, flashlight flicker, footsteps. It's data-driven and it has a test
  (`tests/test_player_feel.gd`). Use the same pattern for every system.
- A strong horror audio kit: calm and intense loops, heartbeat, devil approach, the flip sting,
  maze shift, glitch, safe zone, low-time alarm.
- 3D models (`character1.glb`, `devil.glb`) plus 2D sprite sheets for the Devil, Phantom,
  Sentinel and Void Ripper (4 directions × 7 frames). The sheets can become 3D billboard
  monsters (§6).
- The godot-ai plugin's export hook already strips its runtime autoload from exported builds.

**Change these before you add features.**

| Issue now | Why it hurts | Fix |
|---|---|---|
| `scripts/main.gd` is one 788-line script that builds everything | Every new feature risks breaking others | Split it into scenes and systems (§11) |
| Fixed 13×13 maze | No replay value | Seeded generator plus validation (§8) |
| The Devil teleports one cell every 0.55 s on a straight BFS path to you | Looks robotic. It always knows where you are, which feels unfair | Smooth movement, senses, and a Director (§7) |
| The minimap draws the whole maze, the exit and the Devil from the start | Nothing left to explore, nothing to fear | Show explored cells only. Show the exit once you've seen it. Never show enemies |
| A hard 90 s timer ends the run with "TIME UP" | A loss the player didn't cause | Soft timer: the Nightmare "bleeds in" over time (§4) |
| Traps and safe zones are only decoration | No decisions | Turn them into rules (§6) |
| Each wall cell has 1 body + 3 meshes, plus a ceiling light on every 4th open cell | Draw calls explode on bigger mazes, worst on phones | GridMap or MultiMesh with merged collision (§10) |
| No flip in 3D yet | The name promises it | §4 |

---

## 3. Research: what the top maze and horror games teach

| Game | Proof | What FearFlip takes from it |
|---|---|---|
| **Escape the Backrooms** (Steam) | Estimated 3.8M copies and about $32.3M gross (Raijin estimate). 90% positive across 156K reviews [S1]. Up to 4-player co-op, 30+ levels, each with its own way to escape [S45]. Got a new player surge after the A24 film [S42] | Liminal maze, a different rule per level, co-op |
| **Backrooms: Escape Together** | Estimated 1.2M copies [S2]. Sold 100K+ despite only about 500 wishlists at launch, by riding a YouTube trend with a very clear Steam page [S3] | Ride the trend, and make the hook obvious in one screenshot |
| **Labyrinthine** | Estimated 401K copies and about $3.2M gross, 84% positive of 18K reviews [S4]. Procedural maze mode, 30+ monsters with their own AI, levels that unlock 19 maze types, 200+ cosmetics, daily quests [S5] | The closest comparison. Its meta-progression recipe works |
| **The Exit 8** | 3M+ copies (Sept 2026) [S6]. One developer, deliberately short and simple. 40K+ wishlists, 30K sold on launch day [S7] | One sharp rule beats a mountain of content |
| **DOORS** (Roblox) | 3B+ visits by April 2023 [S8]. Each monster has a warning (lights flicker, a whisper) and one counter (hide, look away, turn back) [S9] | Rule-based monsters make fear learnable |
| **Granny** (mobile) | 500M Google Play downloads by 2026. Granny investigates noises you make [S10] | One hunter who hears you is enough |
| **Alien: Isolation** | A Director AI tracks a "menace gauge" and sends the alien away once tension peaks [S11] | Pacing tech for the Devil |
| **Spelunky** daily challenge | Same seed for everyone, one attempt per day, its own leaderboard [S36] | The Daily Maze |
| **Pac-Man** (maze theory) | Loops let you escape the ghosts on your tail [S34] | Braid the maze (add loops) |

**What the web portals look like.**
- Poki (100M+ monthly players [S38]) and CrazyGames both have horror categories. Poki's horror
  page is mostly 2D point-and-click games (for example the Forgotten Hill series). First-person 3D
  maze horror is rare there (Horror Dungeon 3D, Scary Maze) [S14]. That leaves room for a
  polished 3D horror maze.
- Web players want to jump in fast. 52% value being able to jump in quickly, and 29% play
  sessions of 11–20 minutes [S38].

**Horror on Steam.** Horror out-earns many genres. In 2022 the median horror game made $1,200
versus $467 for platformers, and 6.5% of horror games got 1,000+ reviews versus 2.2% of
platformers [S13]. Most games still fail, so the hook and the quality matter.

**The 7 lessons.**
1. One sharp hook you can explain in a sentence (Exit 8, and our Flip).
2. Threats you can learn, each with a warning and a counter (DOORS).
3. Short runs and instant retry (roguelites).
4. Procedural layouts mixed with handmade rooms (Labyrinthine, Spelunky).
5. A pacing Director (Alien: Isolation).
6. Ride the liminal-horror trend (the Backrooms film, Exit 8).
7. Co-op is where the Steam money is (the Backrooms games, Labyrinthine). Plan for it now, ship it later.

---

## 4. THE FLIP: the signature mechanic

**Concept.** Every floor exists twice on the same grid.

| | WAKE | NIGHTMARE |
|---|---|---|
| Look | Cold blue light, light fog, quiet hum | Red light, wrong-looking props, glitch grain, heavier fog |
| Music | `calm_loop` | `intense_loop` layers plus heartbeat |
| Walls | Layout A | Layout B: A with 20–35% of walls changed (**target**) |
| Threats | Phantom, Sentinel, traps | The Devil, Void Ripper, Sentinel |
| Sigils | 1–2 | 1–2. At least one sigil exists only here |

**Rules.**
1. **Manual flip** (Space or E on desktop, a big button on mobile). The transition takes 0.4 s.
   Cooldown is 6 s (**target**). You arrive at the same spot in the other world.
2. **Blocked flip.** If your spot is a wall in the other world, the flip refuses: a deny sound
   and a screen shudder. Where you stand matters.
3. **Flip noise.** Flipping into Nightmare makes noise (about 6 cells). The Devil may come.
4. **The Devil lives in Nightmare.** Flipping to Wake breaks a chase. But the Devil remembers
   where you vanished and may wait there. The Director decides.
5. **FLIPPING TIME** (your 2D mechanic). After 45 s on a floor (**target**), then every 40–60 s,
   a 3-second warning plays (the flip sting, strobing lights, a ring on the HUD). Then everyone is
   pulled into Nightmare for 12–20 s. This replaces the hard 90 s timer with soft pressure: the
   longer you stay, the longer and more often Nightmare takes over. Spelunky uses a similar trick
   to stop players camping.
6. **The escape.** Collecting the 3rd sigil opens the exit and enrages the Devil for 20 s. Every
   floor ends with a climax chase, then a rest screen.
7. **Ghost Sight** (an unlockable omen). Hold a key to see the other world's walls as faint
   outlines for 1 s. Useful for planning, and it looks great.

**Presentation (the "cool" moment).** The camera rolls 180° over 0.35 s, with a chromatic glitch
and a whoosh. The worlds swap at the midpoint behind a 2-frame glitch flash. Settings include
"Flip effect: Roll / Fade" and "Reduce flashing".

**Fairness guardrails.**
- A forced flip never drops you within 4 path cells of the Devil. The Director moves it first.
- Every Nightmare-only sigil has at least one escape loop nearby (§8).
- Every forced flip is announced before it happens.
- From depth 6, the Devil can follow you through a flip after 3 s. The game escalates; it doesn't cheat.

**Godot implementation.**
- Two GridMaps (`WakeWalls`, `NightmareWalls`) sharing one floor and ceiling GridMap.
- Physics layers: 1 = shared, 2 = Wake walls, 3 = Nightmare walls. A flip switches the player's
  `collision_mask` between bits 2 and 3, toggles GridMap visibility, swaps the Environment (fog
  color, ambient light) and crossfades the music layer.
- Entities have a `layer` property. In the other world they are hidden and have no collision.
- A `FlipSystem` autoload emits `flipped(layer)`. Everything else listens to that signal.

**Flip variants for events and dailies (later).** Maze Shift (marked zones rearrange at Flipping
Time, your 2D mechanic), a Gravity Flip floor (walk the ceiling maze), a Mirror floor. Avoid
inverted controls as a core rule: in first person it feels unfair, not scary.

---

## 5. The loops: why players keep playing

| Loop | Length | What happens | The hook |
|---|---|---|---|
| Moment | 5–15 s | Listen, look, decide: sneak, run, hide or flip | Tension and agency |
| Floor | 2–4 min | Spawn in a safe room, find 3 sigils across both worlds, exit opens, escape chase | A clear goal and rising tension |
| Run | 5–20 min | Floors get deeper: bigger mazes, new threats, faster flips. Pick 1 of 3 Omens between floors | Build variety: "how deep can I go?" |
| Meta | Days | Fear Shards unlock new options: omens, flashlights, skins, biomes, bestiary pages | Something new is always 1–2 runs away |
| Daily | 1 per day | Daily Maze: same seed for everyone, one ranked try, a share card | A reason to come back tomorrow |

**Depth curve (all targets).** Player speeds come from `PlayerFeel`: walk 3.0 m/s, sprint 4.5 m/s
with about 5 s of stamina. A walking player can't outrun the Devil. You must sprint, use loops,
hide or flip.

| Depth | Maze size (tiles) | New element | Flipping Time every | Devil chase speed |
|---|---|---|---|---|
| 0 (tutorial) | 11×11 | Flip, Devil (scripted) | – | Slow |
| 1 | 15×15 | Cracked floors | 60 s | 3.6 m/s |
| 2 | 17×17 | Phantom | 55 s | 3.8 m/s |
| 3 | 19×19 | Sentinel | 50 s | 3.9 m/s |
| 4 | 21×21 | Void Ripper | 45 s | 4.0 m/s |
| 5 | 15×15 | Breather floor: an anomaly corridor in the style of Exit 8, no Devil | – | – |
| 6+ | 23×23 up to 27×27 | Combinations; new biome every 5 floors; the Devil can follow flips | 40 s | 4.1–4.3 m/s |

**Omens** (pick 1 of 3 after each floor; examples):
- Soft Soles: sprint noise radius −50%.
- Twin Flip: hold 2 flip charges.
- Lantern Heart: flashlight range +40%, but the Devil sees the beam from farther away.
- Cold Blood: the heartbeat warns you 3 cells earlier.
- Cartographer: sigil shrines appear on the minimap within 6 cells.
- Last Breath: survive one grab this run.
- Quick Veil: flip cooldown −30%.
- Ghost Sight: see the other world's walls (§4).

**Curses** (optional, for +50% shards): Blackout (no ceiling lights), Hungry Dark (Devil +10%
speed), Short Fuse (Flipping Time every 30 s), Deaf Night (no Devil footsteps, only the heartbeat).

**Meta progression.**
- Earn Fear Shards: 3 per sigil, 10 per floor plus 2 × depth, a bonus for the Daily Maze, and 5
  for each new bestiary entry (all **targets**).
- Spend them on more omens in the pool, a starting omen slot, flashlights (Old Torch, Lantern,
  UV Light that reveals Phantoms, Camera Flash that stuns once per floor), skins and flashlight
  colors. Biomes unlock at depth milestones (Office from the start, Hospital at depth 5, Subway at
  10, Hedge Maze at 15).
- The rule: unlocks add **options, not raw power**. Skill must stay the main way to get deeper,
  or the game turns into a grind [S37]. Make the first unlock cost about one floor's worth of shards.

**The death screen is the most important screen in the game.** It shows:
- What killed you and its rule, for example: "THE DEVIL hears sprinting. Walk when your heart pounds."
- How close you were: "You were 9 m from the exit."
- Your best depth, shards earned, and a progress bar to the next unlock.
- A **RETRY** button: the biggest button on screen, one tap, back in the maze in under 2 seconds.

---

## 6. Threats: port your 2D roster as rule-based monsters

| Entity | World | Telegraph (warning) | Counter (the rule) | If it gets you | From depth |
|---|---|---|---|---|---|
| **The Devil** (hunter) | Nightmare | Rising heartbeat, heavy steps and breathing in 3D audio, red glow at corners | Break line of sight, walk instead of sprint, hide in a safe circle, or flip to Wake | Grab: the run ends. One rewarded revive per run, only from depth 3 | 0 |
| **Phantom** (watcher) | Wake | Flashlight flickers, cold breath, frost at the screen edge | Don't keep it in view for more than 2 s: look away or switch off the light | It shrieks: the Devil learns your position and your light dies for 5 s | 2 |
| **Sentinel** (guard) | Both | A hum and a sweeping searchlight. The eye closes for 2 s every 5 s | Cross its corridor while the eye is closed | Alarm: the Devil gets your exact position and Flipping Time starts in 3 s | 3 |
| **Void Ripper** (rusher) | Nightmare | Lights die one by one down the corridor plus a rising roar (3 s) | Step into a side alcove or flip to Wake before it passes | The run ends (revive allowed) | 4 |
| **Cracked floor** (trap) | Both | Visible cracks, glass creaks under you | Walk across. Sprinting breaks it | You fall into a pit: about 3 s lost and a loud noise | 1 |
| **Safe circle** | Both | Blue ring plus `safe_zone_sound` | The Devil can't enter. It protects you for 8 s, then goes dark for 30 s | – | 0 |

**Teach, then test.** Each new monster first appears in a safe, scripted moment. The rule is
taught there. Only after that can it kill you.

**No cheap deaths.** Every lethal threat warns at least 1.5 s ahead. The Devil's grab has a
visible 0.4 s lunge. Nothing spawns behind you.

**Visual approach.** The Devil is a 3D model (optimized, §10). Phantom, Sentinel and Ripper are
animated billboard sprites (`AnimatedSprite3D`) built from your 4-direction sheets. The game picks
the frame set from the camera angle, like classic DOOM monsters. It's cheap, small to download,
creepy, and it matches the lo-fi style.

---

## 7. AI: the Director and the Devil

**Director (decides when).** It keeps a menace gauge M from 0 to 100, like Alien: Isolation [S11].
All values are **targets**.
- M rises by 30/s while the Devil can see you, 12/s while it's within 6 path cells, and 6/s while
  you can hear it (within 10 cells). Otherwise M falls by 8/s.
- **CALM** (M < 20): the Devil patrols far away. After 35 s of calm → **BUILD**: the Devil gets a
  fuzzy hint (a random cell within 4 of you) and investigates.
- **PEAK** (M ≥ 80): chases are allowed. If the peak lasts more than 12 s, or you break line of
  sight for 6 s → **RELAX**: the Devil retreats at least 12 cells for 15–25 s and the music calms.
- **Silent help.** After two deaths in under 90 s each, the next floor gets −5% chase speed and
  −30% hint frequency. Reset after a clear. Never tell the player.
- The Director also schedules Flipping Time and spawns the Ripper and Phantoms.

**The Devil (decides how).** A small state machine:
Patrol → Investigate (a noise) → Chase (sees you) → Search (last known spot, 8–10 s) → Retreat.
- **Hearing.** Noise travels along corridors (path distance, not straight lines). Radii in cells:
  walking 2, sprinting 6, landing 3, flipping 6, a cracked floor breaking 8. A Sentinel alarm
  gives your exact position.
- **Vision.** A 75° cone, 12 m range, with a raycast line-of-sight check. A flashlight beam in
  Nightmare can be seen from 18 m.
- **Movement.** A path on the cell grid (BFS or A*). Repath when your cell changes or every 0.3 s.
  Steer smoothly along waypoints, not cell-to-cell teleports. Speeds: patrol 2.2 m/s, investigate
  3.0, search 2.6, chase from the depth table.
- **Fair-play rule.** The Devil never paths straight to you unless a sense or a Director hint
  says so. The current "always knows where you are" BFS must go.
- Put every number in a `DevilConfig.tres` resource, the same pattern as `PlayerFeel`.

---

## 8. Maze generation (seeded, validated, two worlds)

**Pipeline.** Use one `RandomNumberGenerator` with a stored seed.
1. **Carve.** A recursive backtracker on an R×R room grid gives (2R+1) tiles. It makes long,
   winding corridors with few branches, which is good for tension [S35].
2. **Braid.** Remove about 30% of dead ends (**target**) to create loops you can use to escape a
   chase [S34]. Keep a few dead ends for rewards and hiding spots.
3. **Stamp rooms.** A spawn safe room, 3 sigil shrines, the exit chamber, 1–2 landmark rooms
   (statue, fountain, broken elevator) and alcoves along long straight corridors (the counter to
   the Ripper).
4. **Make Nightmare.** Copy Wake, then change 20–35% of the eligible walls (open some, close
   others). Never touch stamped rooms.
5. **Place sigils.** At least one can only be reached by flipping. Spread them out by path distance.
6. **Validate.** Run BFS over the state (cell, world), with flips as edges. Check that:
   the exit is reachable after all sigils; the Devil spawns at least 10 path cells from you;
   every sigil has two approach routes; no pocket traps you. If a check fails, reroll (cap the attempts).
7. **Decorate by biome.** A landmark every ~5 cells, colored light per zone, props from weighted tables.
8. **Build.** `GridMap.set_cell_item` for walls, merged collision, MultiMesh for props.

**Determinism.** The same seed gives the same floor: for debugging, for the Daily Maze, and for
shareable seeds. Daily seed = hash("FearFlip-" + the UTC date).

**Tests.** Put a 1,000-seed test in `tests/`. Every seed must be solvable, have a flip-required
sigil, keep the Devil spawn distance, and generate in under 50 ms on desktop.

**Getting lost isn't fun.** Use landmarks, a minimap that shows explored cells only, an exit
beacon after the 3rd sigil, a compass omen, and **chalk marks** (press C to mark a wall). Bonus
creep factor: sometimes in Nightmare you find chalk marks you didn't draw.

---

## 9. Horror craft: audio, light, scares

- **Sound is information.** Use buses: Master ← Music, SFX, Ambience, UI. The Devil uses 3D
  positional audio, muffled when there's no line of sight. Drive the heartbeat and the music
  layers (`calm_loop` ↔ `intense_loop`) from the menace gauge, with different thresholds going up
  and going down so the music doesn't flicker. Make footsteps differ by surface. Use silence
  right before a scare.
- **Light.** Very low ambient light plus colored fog. The flashlight is your sight, but in
  Nightmare it also gives you away. Keep the existing flicker and stutter.
- **Scares.** Build up, then release. At most one big jump scare every 2–3 minutes. Most of the
  fear should come from anticipation. Flipping into the Devil's face is a natural, earned scare.
- **Feedback tiers.** Small (footsteps: nothing extra), medium (sigil: pulse plus chime), large
  (grab: shake, a short freeze, scream). Add "reduce shake" and "reduce flashing" options.
- **Content rating.** Keep it PEGI-12 safe: creepy, not gory. No realistic blood or dismemberment.
  CrazyGames requires PEGI-12 compliance [S22].

---

## 10. Art direction and tech budget

**Look: lo-fi liminal.** Render the 3D world in a `SubViewport` at about half resolution and
upscale it with nearest filtering. Add dithering or film grain, fog, a limited palette per biome,
and 256–512 px textures. It hides low-poly assets, matches the indie-horror trend, and runs on
cheap hardware.

**Biomes** (liminal spaces are cheap to build because they repeat): Office Yellow (backrooms-style
mood, but don't copy anything from the film), Hospital Wing, Flooded Subway, Night Hedge Maze,
Hotel Corridor, and a Nightmare-only Mirror Hall.

| Budget item | Target |
|---|---|
| Initial download | ≤ 20 MB. That's the CrazyGames mobile homepage limit, and top games are under 20 MB and load in under 10 s [S19][S20] |
| Engine (wasm) | A standard Godot web build is about 40 MB raw or 5 MB with Brotli compression [S25]. A custom build profile can cut more, but keep 3D enabled [S28] |
| Game data (.pck) | ≤ 12 MB |
| Textures | 256–512 px. On web, import as Lossless or Lossy (WebP) so one file works on desktop and mobile. If you use VRAM compression, enable both the desktop and mobile formats |
| Audio | Ogg Vorbis, mono SFX, music at 96–128 kbps, streamed |
| Models | Devil ≤ 10k triangles, props ≤ 1k. Decimate the generated GLBs and shrink their textures |
| Draw calls | ≤ 150 on mobile |
| Lights | The flashlight is the only light that casts shadows. Compatibility allows up to 8 lights per mesh by default [S26]; use emissive fakes for the rest |
| Frame rate | 60 FPS desktop, 30+ FPS on 4 GB Chromebooks (CrazyGames requires Chromebook support) [S20] |

**What the Compatibility renderer can and can't do.** It supports fog, glow and SSAO. It does not
support volumetric fog, SSR or decals [S26]. Design around that.

**Shader stutter (critical for horror).** Compatibility has no ubershaders. Show every material
and particle effect for one frame during loading so their shaders compile then [S27]. Otherwise
the game hitches the first time the Devil appears, and that kills the scare.

**Quality presets.** Low: half resolution, no shadows, short fog. Medium. High.

**Web gotchas.**
- **Esc and pointer lock.** The browser releases pointer lock on Esc. Auto-pause when that
  happens, and resume on click.
- **Audio.** Unlock audio on the first click (the PLAY button). On iOS, resume audio after an
  interruption [S20].
- **Pause and mute** when the tab is hidden or an ad is playing [S21].
- **Saves.** Wrap save and load so they never crash in incognito mode. Poki requires incognito
  support [S17].
- **iPhone Safari.** Test on it early. It's the shakiest target; CrazyGames even disables iOS by
  default until a game has enough plays [S20].

---

## 11. Code architecture (refactor plan for Godot 4.7)

```
res://
  autoload/      game.gd (state machine), event_bus.gd, save.gd, settings.gd,
                 audio.gd, platform.gd (ads, events, cloud save), flip_system.gd
  maze/          maze_data.gd, maze_generator.gd, maze_validator.gd,
                 maze_builder.gd (GridMap + collision), biomes/*.tres
  ai/            director.gd, devil.gd, senses.gd, nav_grid.gd, configs/*.tres
  entities/      devil.tscn, phantom.tscn, sentinel.tscn, ripper.tscn, sigil.tscn
  player/        player.tscn, player.gd, player_feel.gd (keep), flashlight.gd
  run/           run_manager.gd, depth_curve.tres, omens/*.tres, curses/*.tres
  ui/            hud.tscn, death_screen.tscn, omen_pick.tscn, unlocks.tscn,
                 settings.tscn, touch_controls.tscn, daily.tscn
  tests/         test_maze_generator.gd (1,000 seeds), test_flip.gd, test_director.gd
```

**Principles.**
- Make everything data-driven with Resources, as `PlayerFeel` already is.
- Systems talk through `EventBus` signals: `noise_emitted(pos, radius)`, `flipped(layer)`,
  `sigil_collected`, `player_died(cause)`, `floor_cleared(depth)`.
- `PlatformService` is one interface with these calls: init, gameplay_start/stop,
  loading_start/stop, midgame_ad, rewarded_ad, cloud_save/load, user. It has three versions:
  Local/itch (does nothing), CrazyGames (official Godot SDK [S24]), and Poki (Godot plugin [S40]).
  If you go multi-portal, Playgama Bridge covers 26+ portals behind one API (MIT license, with
  separate Godot 3 and Godot 4 versions) [S39].
- Saves: versioned JSON in `user://` (IndexedDB in the browser), written atomically, with a backup.
  CrazyGames' Full Launch requires progress linked to the player's CrazyGames account [S23].
- Keep scripts under about 300 lines. Pin Godot 4.7.2 until launch, and only upgrade after a web
  export test.
- Export preset "Web (CrazyGames)": Thread Support **off** [S24][S25], exclude `addons/godot_ai/*`
  and `tests/*`, put the SDK script in Head Include, and build from the command line so releases
  are repeatable.

---

## 12. Launching on the web, step by step

| | CrazyGames | Poki | itch.io | Steam (later) |
|---|---|---|---|---|
| Getting in | Upload, QA, then Basic Launch (7–21 days, 500 plays). Full Launch if the numbers are good [S19] | Curated: Playtests, Player Fit Test (500 players), Web Fit Test (~10,000 players), then review [S15][S16] | Instant | $100 fee and a review |
| Size | ≤ 50 MB initial, ≤ 20 MB for the mobile homepage, 250 MB total [S20] | Target under 8 MB initial [S17] | Flexible | Any |
| Godot 4 | Single-threaded build [S24] | Godot plugin available [S40] | Yes | Yes |
| Money | Ad revenue share; the % isn't public (their 2026 game jam terms gave developers 60% of ad revenue) [S29]. In-game purchases by invitation only, via Xsolla [S23] | Exclusive deal: 100% on traffic you bring, 50% on traffic Poki brings. Non-exclusive: a one-time fee [S18][S29] | Your price or donations | Paid sales |
| Exclusivity | None [S22] | Web-exclusive by default for years (the deal page has said both 5 and 7; Steam and mobile stay allowed) [S18] | None | None |
| Role for FearFlip | **Main launch** | Optional, only if invited and under 8 MB | Testers and community | **The money version** |

**Steps (each one is a gate).**
1. **Private tests.** Friends plus Poki for Developers playtests, which record real players
   and don't oblige you to publish [S15][S46]. Use a password-protected itch.io page for testers. Don't put
   the web build anywhere public yet.
2. **Optional Poki Player Fit Test.** 500 players. To pass you need an average playtime over
   3 minutes **and** at least 25% of plays over 3 minutes [S15]. It's a free benchmark.
3. **CrazyGames Basic Launch.** It runs 7–21 days. Benchmarks for strong games: average
   playtime 10+ minutes, next-day return (D1 retention) of 10–15%, and 80%+ of players playing at
   least 1 minute [S19]. You can ship updates any time; update every 2–3 days, aimed at your
   weakest number.
4. **CrazyGames Full Launch.** Add the SDK: gameplay start and stop, midgame ads, rewarded ads,
   account-linked cloud saves, username and avatar [S21][S23].
5. **itch.io public page** for the community, devlogs and a Discord link.
6. **Steam page** as soon as the vertical slice is fun (§17).

**Title and thumbnail.** Use "FearFlip: Horror Maze Escape" so portal search finds it. Poki's Web
Fit Test measures how often people click your thumbnail [S16]. Make one strong image: the
Devil's face split down the middle, blue Wake on one side and red Nightmare on the other, with
the title large.

**Halloween.** Today is 3 October and Halloween is in 4 weeks. Don't rush a weak public launch:
the Basic Launch numbers decide whether you get a Full Launch [S19][S22]. Use October for private
tests and for flip GIFs and short videos on TikTok, Shorts and Reddit.

---

## 13. Monetization (with honest numbers)

**Ad placements (web).**

| Placement | When | Rules |
|---|---|---|
| Midgame (interstitial) ad | On the move from the Omen screen to the next floor, or on Retry after death | Only at natural breaks. CrazyGames allows at most 1 every 3 minutes [S21]. On Poki, call `commercialBreak` only when the player heads back into gameplay [S17] |
| Rewarded: Revive | Once per run, only from depth 3 | Never offered on every death [S21]. You revive in the nearest safe circle and the Devil is sent away |
| Rewarded: Double shards | Once at the end of a run | Give the reward only after the ad finishes [S21] |
| Rewarded: Lantern | Before a floor: +40% flashlight range for that floor | Optional, never chained [S17][S21] |
| Banner | Only on the death or unlock screens, if at all | Never during gameplay [S21] |

The normal button must always be as big as the reward button, or bigger [S17]. Never make a
player watch two ads for one reward.

**What the numbers look like.**
- Rewarded video earns about $15–28 per 1,000 views in the US, $8–15 in the EU and $1–3 in India
  and Brazil (gross, before the platform's share) [S29].
- One developer earned about €1.23 per 1,000 plays on CrazyGames (2016–2019 data) [S30].
- Well-performing casual games on big portals make about $200–2,000 a month. Top Poki studios
  make up to €1M a year [S29].

**Illustrative scenarios.** These are my estimates, not forecasts.

| Outcome | Web plays per month | Web ads per month (at €1–5 per 1,000 plays) | Steam copies (year 1) | Steam net (about 50% of copies × $7.99) |
|---|---|---|---|---|
| Modest | 50,000 | €50–250 | 2,000 | about $8,000 |
| Good | 500,000 | €500–2,500 | 20,000 | about $80,000 |
| Hit | 5,000,000 | €5,000–25,000 | 200,000 | about $800,000 |

The "about 50%" is a rough rule of thumb for what you keep after Steam's 30% cut, discounts,
regional prices, refunds and taxes. For scale, Labyrinthine's estimated 401K copies come to
about $3.2M gross [S4].

**Steam version (the money version).** Price it at $6.99–9.99. The headline feature is 2–4
player online co-op (Steam's built-in networking through GodotSteam, so you don't run your own
servers). Add more biomes, more monsters and Steam achievements. Keep the web version free as the
funnel: "Liked it? Play with friends on Steam."

**Hard no's.**
- No paid loot boxes. Belgium ruled them gambling in April 2018 [S33]. CrazyGames is a Belgian
  company (Leuven) [S41].
- No energy or lives timers. Web players simply leave.
- No fake countdown offers.

---

## 14. Engagement hooks (the healthy kind)

1. **Near-miss feedback.** "9 m from the exit." "Best depth: 7." This is the strongest
   one-more-run trigger.
2. **An unlock bar that's always visible.** Early on, the next unlock is at most 2 runs away.
3. **Omen choices** make every run feel different.
4. **Daily Maze plus a streak**, with a free grace day so a missed day doesn't feel punishing.
5. **The Bestiary.** Collect every monster's card: lore, its rule, and how many times it killed you.
6. **Devil Cam.** On death, replay the last 4 seconds from the Devil's point of view. It's
   creepy, it teaches what went wrong, and streamers will love it. You only need to record the
   transforms of the Devil and the player.
7. **A share card**, for example "FearFlip Daily #12 · Depth 6 · 7:41 · flips 31" plus a link.
8. **A weekly modifier**, for example "Blackout Week", and seasonal biomes (a Winter "Frozen Nightmare").

**Guardrails.** Ads are optional and capped. There's no paid randomness. Floors end at natural
stopping points. These rules are also what keeps the game inside platform policy [S17][S21].

---

## 15. Onboarding: the first 5 minutes (script)

| Time | What happens | Why |
|---|---|---|
| 0:00 | Loads in under 10 s. Title screen: FEARFLIP, a big PLAY button, a small Daily button. No splash logos (Poki forbids them) [S17] | Conversion [S19] |
| 0:05 | Click PLAY: pointer lock, audio starts, `gameplay_start` fires on the first input [S17]. Tutorial floor 0 "The Waiting Room" | Playing within seconds |
| 0:20 | A wall glows. Prompt: "SPACE to FLIP". First flip: red world, the wall is gone, a sigil floats there | The hook in the first 30 s |
| 0:40 | A distant roar, the heartbeat starts. The Devil appears at the end of the corridor (scripted, slow). Prompt: "FLIP to escape". Flip back to Wake and it's gone | Teaches the core rule safely |
| 1:10 | A Phantom flickers your light. Prompt: "Don't look at it." Look away and it fades | Teaches threat rules |
| 1:30 | The exit opens. Floor cleared: +shards, pick your first Omen | The first win comes early |
| 1:40–4:00 | Floor 1 (a real seeded maze). The first death usually comes here, then the death screen with its rule and RETRY | Playtime over 3 min [S15] |

Returning players skip the tutorial. CrazyGames asks for onboarding that is skippable [S44].

**Controls.**
- Desktop: WASD and mouse, Shift sprint, F flashlight, Space or E flip, C chalk, Esc pause.
  (Space is jump today. A maze doesn't need jumping, so give Space to the flip.)
- Mobile: left thumbstick, drag the right half of the screen to look, a big FLIP button, a sprint
  toggle and a flashlight button.

**Settings.** Sensitivity, invert Y, FOV slider, brightness calibration (essential for a dark
game), head-bob on/off, reduce flashing and shake, flip effect Roll or Fade, captions and visual
sound cues, separate volume sliders. Keep text minimal so translating it later is cheap.

---

## 16. KPIs and analytics

| Metric | Target | Benchmark |
|---|---|---|
| Load to first input | Under 10 s | Top CrazyGames games [S19] |
| Initial download | ≤ 20 MB | [S19][S20] |
| Players who play at least 1 minute | ≥ 80% | CrazyGames benchmark [S19] |
| Average playtime | Over 3 min (Poki), 10+ min (CrazyGames strong) | [S15][S19] |
| Plays longer than 3 min | ≥ 25% | Poki Player Fit [S15] |
| Next-day return (D1 retention) | 10–15% or more | CrazyGames strong [S19] |
| Tutorial completion | ≥ 85% | Internal target |
| Retry after the first death | ≥ 60% | Internal target |
| First-run Floor 1 clear rate | 40–60% | Internal target |
| Deaths from any single threat | Under 50% of all deaths | Internal balance check |
| FPS on low-end (5th percentile) | ≥ 30 | Internal target |

**Events to log.** load_complete (ms), gameplay_start, tutorial_step, flip (manual or forced),
sigil (world), death (cause, depth, time, menace), floor_clear (depth, time), run_end (depth,
shards), ad_offer and ad_accept, settings_changed. During private tests, log them locally. On
portals, use their dashboards first. Poki blocks outside requests by default, and CrazyGames needs
player consent for data beyond its SDK events [S17][S20].

**Playtest protocol.** Don't explain anything. Watch silently and note every moment of confusion.
Afterwards ask three questions: What scared you? When were you confused? Would you play again?

---

## 17. Roadmap

| When | Build | Gate before moving on |
|---|---|---|
| **Week 1** (5–11 Oct) | Export a single-threaded web build today; measure size, load time and FPS on a phone and a cheap laptop. Quick wins: minimap shows explored cells only, replace the hard timer. Refactor `main.gd` into Player, MazeBuilder (GridMap), Game state, EventBus | Plays the same as now, web build ≤ 20 MB, loads in under 10 s |
| **Weeks 2–3** (12–25 Oct) | Seeded generator, braiding, validator and tests. FlipSystem v1. Devil state machine, Director v1, 3D audio. Sigils and exit. Death screen with instant retry. Tutorial floor. Adaptive music | **Fun test** with 5–10 first-time players: 70%+ understand the flip without help, median first session 6+ min, 50%+ press retry. If not, fix the core before adding content |
| **Weeks 4–5** (26 Oct–8 Nov) | Phantom, Sentinel, Ripper, cracked floors, safe circles. 2 biomes, the depth curve, omens and curses, Fear Shards and the unlock screen, bestiary, settings, touch controls, saves | Halloween week: post flip clips |
| **Week 6** (9–15 Nov) | Feedback polish, shader warm-up, quality presets, size budget, accessibility. Daily Maze and share card. Analytics events | Optional Poki Player Fit Test passes [S15] |
| **Weeks 7–8** (16–29 Nov) | CrazyGames Basic Launch. Updates every 2–3 days aimed at the weakest number | Meets the Basic Launch benchmarks [S19] |
| **Weeks 9–10** (December) | Full Launch: SDK, ads, rewarded ads, cloud saves. Winter event | Revenue flowing, D1 stable |
| **Months 3–9** (2027) | Steam page with the split blue/red capsule art, a demo, Next Fest, then co-op | Get to 2,000+ wishlists before Next Fest (below that, the festival barely helps) and aim for about 7,000 at launch to reach "Popular Upcoming" [S32] |

---

## 18. Risk register (regret-proofing)

| Risk | Prevention |
|---|---|
| Building content before the core loop is fun | The Week 3 fun test is a hard gate |
| Web build too big or slow (Godot 3D is about 40 MB raw) [S25] | Export from week 1, size budget table, lo-fi art |
| Unfair deaths | Every threat warns and has a counter. The death screen teaches the rule |
| Players get lost or bored in the maze | Braiding, landmarks, chalk, exit beacon, floors of 2–4 minutes |
| The Devil is cheesable or exhausting | Director tuning, the Devil follows flips from depth 6, Flipping Time |
| Ads hurt retention or fail platform review | Only the placements in §13; follow the platform rules to the letter |
| Content rejected | Keep it PEGI-12: scary, not gory [S22] |
| Licensing | Check every sound. Any meme or soundboard sting (for example the "fahhhhh" clip) must be replaced or properly licensed. Check the license of the tool that made the GLB models, and of your fonts. Don't copy the Backrooms film's specific designs |
| iPhone Safari problems | Test early. CrazyGames disables iOS by default anyway [S20] |
| Motion sickness | Roll/Fade option, FOV slider, head-bob toggle |
| Scope creep (co-op too early) | Co-op only for Steam, after the web launch |
| Exclusivity trap | Decide Poki versus CrazyGames before any public web release [S18] |
| Name conflicts | Check "FearFlip" on Steam, the portals and trademark databases. Register the domain and social handles now |

---

## 19. Don't build (yet)

An open world. Story cutscenes or voice acting. Inventory or crafting. Realistic graphics.
Online multiplayer on the web. A level editor. Forced login. Long intros. More than one currency.

---

## 20. Building this with Claude efficiently (godot-ai MCP)

- One system per session, for example: "Implement §8 steps 1–3 plus the 1,000-seed test."
- Point Claude at this file and at `CLAUDE.md`. For big scripts, ask for a symbol outline
  (`find_symbols`) instead of a full read.
- After each milestone, update a 5-line "Current state" section in `CLAUDE.md`.
- Ask for tests first on the generator, the Director and the flip validator, and run them in the
  editor.
- Game-dev skills: three relevant skills (procedural generation, game AI, Godot export) are
  adapted from the open-source awesome-gamedev-agent-skills collection [S43], which has 74 skills
  in total.

---

## 21. Your next 7 days

- [ ] Confirm the exact 2D flip rule. If it differs from §4, update §4 first.
- [ ] Export a web build today with Thread Support off. Note its size, load time and FPS on a
      phone and on a cheap laptop.
- [ ] Quick wins: make the minimap show explored cells only (no unseen walls, no exit until found,
      no Devil); replace the 90 s hard timer with Flipping Time.
- [ ] Refactor `main.gd` into scenes, starting with MazeBuilder on a GridMap.
- [ ] Build the seeded generator, braiding and validator, plus the 1,000-seed test.
- [ ] Graybox Flip v1 and play it yourself for 30 minutes. Is flipping fun with zero art?
- [ ] Check licenses: every sound (especially meme stings), the 3D models, the fonts.
- [ ] Check the name "FearFlip" and register the domain and handles.

---

## Sources

- [S1] Raijin: Escape the Backrooms (estimates as of 20 Jul 2026): https://raijin.gg/app/1943950/Escape_the_Backrooms
- [S2] Raijin: Backrooms: Escape Together: https://raijin.gg/app/2141730/Backrooms_Escape_Together
- [S3] How To Market A Game: Backrooms: Escape Together case study: https://howtomarketagame.com/2024/05/15/success-by-making-a-game-using-youtube-trending-content/
- [S4] Raijin: Labyrinthine (as of 3 Oct 2026): https://raijin.gg/app/1302240/Labyrinthine
- [S5] co-op.gg: Labyrinthine features: https://www.co-op.gg/pc/game/labyrinthine
- [S6] PLAYISM: The Exit 8 passes 3 million copies: https://playism.com/en/news/2026/0907/1716/
- [S7] AUTOMATON: The Exit 8 developer interview: https://automaton-media.com/en/news/20240214-27192
- [S8] Pocket Tactics: DOORS passes 3 billion visits: https://www.pockettactics.com/roblox/doors-visits
- [S9] Gamer Journalist: every DOORS entity and how to avoid it: https://gamerjournalist.com/every-enemy-and-how-to-avoid-in-roblox-doors/
- [S10] Wikipedia: Granny (video game series): https://en.wikipedia.org/wiki/Granny_(video_game_series)
- [S11] Game Developer: Revisiting the AI of Alien: Isolation: https://www.gamedeveloper.com/design/revisiting-the-ai-of-alien-isolation
- [S12] Backrooms crosses $100M, highest-grossing A24 film domestically: https://www.hot929.com/news/entertainment-news/backrooms-crosses-100-million-becomes-highest-grossing-a24-film-at-domestic-box-office/
- [S13] How To Market A Game: Every indie developer should make a horror game: https://howtomarketagame.com/2023/10/02/every-indie-game-developer-should-make-a-horror-game/
- [S14] Poki horror category: https://poki.com/kr/호러
- [S15] Poki: Player Fit Test: https://sdk.poki.com/player-fit
- [S16] Poki: Web Fit Test: https://sdk.poki.com/web-fit-test
- [S17] Poki: requirements: https://sdk.poki.com/new-requirements
- [S18] Poki: deals: https://sdk.poki.com/deals.html
- [S19] CrazyGames: Basic Launch metrics: https://docs.crazygames.com/resources/basic-launch-metrics/
- [S20] CrazyGames: technical requirements: https://docs.crazygames.com/requirements/technical/
- [S21] CrazyGames: ad requirements: https://docs.crazygames.com/requirements/ads/
- [S22] CrazyGames: FAQ: https://docs.crazygames.com/faq/
- [S23] CrazyGames: requirements overview: https://docs.crazygames.com/requirements/intro/
- [S24] CrazyGames: Godot SDK: https://docs.crazygames.com/sdk/godot/intro
- [S25] Godot: web export in 4.3 (single-threaded builds, size): https://godotengine.org/article/progress-report-web-export-in-4-3/
- [S26] Godot docs: Overview of renderers: https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html
- [S27] Godot docs: Reducing stutter from shader compilations: https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html
- [S28] How to minify Godot's build size: https://popcar.bearblog.dev/how-to-minify-godots-build-size/
- [S29] Cinevva: web game monetization data (2026): https://app.cinevva.com/guides/web-game-monetization
- [S30] DonislawDev: earnings from 8 games including WebGL: https://donislawdev.com/earnings-and-statistics-from-my-8-games-android-ios-webgl/
- [S31] Vampire Survivors wiki: https://vampire.survivors.wiki/w/Vampire_Survivors
- [S32] How To Market A Game: Steam Next Fest wishlist benchmarks: https://howtomarketagame.com/2025/03/26/archive-january-2026-benchmarks-how-many-wishlists-can-i-get-from-steam-next-fest/
- [S33] Gambling Insider: developers remove paid loot boxes in Belgium: https://www.gamblinginsider.com/news/5801/games-developers-remove-paid-loot-boxes-in-belgium
- [S34] Mazes for Programmers: braiding mazes: https://www.educative.io/courses/mazes-for-programmers/braiding-mazes
- [S35] Wikipedia: Maze generation algorithm: https://en.wikipedia.org/wiki/Maze_generation_algorithm
- [S36] Spelunky wiki: Daily Challenge mode: https://spelunky.fandom.com/wiki/Daily_Challenge_Mode_(HD)
- [S37] Bugnet: designing roguelite meta-progression: https://bugnet.io/blog/how-to-design-a-roguelite-meta-progression
- [S38] Game Dev Reports: Poki web gaming perceptions 2026: https://gamedevreports.substack.com/p/poki-web-gaming-perceptions-in-2026
- [S39] Playgama Bridge for Godot: https://github.com/playgama/bridge-godot
- [S40] Poki: Godot plugin: https://sdk.poki.com/godot
- [S41] CrazyGames developer portal press release (Leuven): https://start-it-x.prezly.com/crazygames-launches-new-developer-portal-with-revenue-share-options
- [S42] LevelUp: Escape the Backrooms surges after the A24 film: https://www.levelup.com/en/news/backrooms-game-rebounds-thanks-to-a24-film-free-on-xbox-game-pass-or-discounted-on-steam/
- [S43] awesome-gamedev-agent-skills (Apache-2.0): https://github.com/gamedev-skills/awesome-gamedev-agent-skills
- [S44] CrazyGames: quality guidelines: https://docs.crazygames.com/requirements/quality/
- [S45] Time Extension: Escape the Backrooms (PS5): https://www.timeextension.com/games/ps5/escape_the_backrooms
- [S46] StartupRise: how Poki helps developers (free playtesting, no obligation to publish): https://startuprise.co.uk/how-poki-is-helping-game-developers-across-europe-scale-globally-and-compare-with-other-platforms/
