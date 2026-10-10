# FearFlip 3D: Maze Events, Skins and Seasons (BGMI's hooks in maze form)

Research from 9 Oct 2026. The question: why can't BGMI players put it down, and what is the **maze**
version of that? This plan builds on plans/06 (P0–P9 are all built) and keeps its guardrails (§5): no paid
randomness, no energy timers, no fake scarcity, ads only at breaks. The fairness rules (GEMINI, master plan
§6) apply to every event here: it must be telegraphed, optional, and never unavoidable.

Effort: S = 1 day or less · M = 2–4 days · L = 1–2 weeks. Impact runs from ● (small) to ●●● (big).

## 1. BGMI → maze

| BGMI | Why it hooks | Maze form (this plan) |
|---|---|---|
| Airdrop | The best loot. Everyone sees it fall, and grabbing it is a risk | M1 Relic Drop |
| Flare gun | Call your own airdrop | M1 Signal Flare |
| Blue zone | The map pushes you on | M5 The Rot |
| Clutch 1v4 | Outplay moments, clips | M6 Drop Gates |
| Loot tiers | Visible value means detour decisions | M1/M2 (glow you can see down a corridor) |
| 99 alive, Chicken Dinner | You against everyone | S2 99 Dreamers |
| Royale Pass | You're always one tier away | P1 Labyrinth Pass |
| Upgradable gun skins | The skin grows with use and adds kill effects | K1 Light Sets |
| Bronze → Conqueror | Status, season resets | P2 Season Tiers |
| Arcade/EvoGround | Something new each week | P3 Weekly modes |
| Crates, spins | The jackpot feeling | **Free in-maze randomness only** (M1, M2, chests). Paid crates stay banned (master plan §13: Belgium, and CrazyGames is Belgian) |

## 2. What the maze games teach
- **Pac-Man CE DX**: ghosts sleep until you pass, then follow you as a "ghost train". Eat the train with a
  power pellet for a big bonus. Slow motion when a ghost gets close. IGN's Most Addictive Game of 2010 [S1].
- **Pac-Man 256**: a glitch eats the endless maze from behind, so you can never stop [S3].
- **Pac-Man 99**: 99 players, each in their own maze. The last one standing wins [S2].
- **DOORS** (Roblox): numbered rooms, one life, entities with one rule each (look away from Eyes, hide from
  Rush), drawers pay currency for items. 86M visits in its first two weeks [S4], 3B later [S5].
- **Piggy**: chapters with escape objectives, item doors, traps, and hunter skins (cosmetic only, earned or
  bought). Limited-time events add NPCs, skins and maps [S7].
- **Granny**: 5 days, several escape routes (door, car, sewer), noise draws her in, closing doors slows her [S8].
- **Lethal Company**: pulling the Apparatus pays the most, and it kills the facility's power.
- **The Exit 8**: spot the anomaly in a looping corridor. 3M copies, and a film in 2025 [S6].

## 3. Maze events (inside a floor)

| # | Event | How it plays | Reuses / fair because | Effort | Impact |
|---|---|---|---|---|---|
| M1 | **Relic Drop** | Once per floor, in the Director's RELAX phase, a crate smashes through the ceiling at a reachable cell 8–14 steps away: a boom, dust, a shaft of light, and a mark on the paper map. It holds the floor's best loot (cosmetic fragment, omen token, 3× chest). The Devil hears it and **investigates the crate, not you**. From F20, a chest can hold a **Signal Flare**: it calls a drop where you stand, loudly | `FloorLayout.distances()`, `main.gd::_noise`, `DevilBrain.investigate()`, chest rolls, `Director`. Fair: an optional detour, and the Devil heads for the crate | M | ●●● |
| M2 | **The Wisp** | A glowing wisp appears at a junction for 40 s and flees through the maze. Each step it moves to the neighbour farthest from you by BFS. Corner it in a **dead end** to catch it: shards + a cosmetic fragment. The chase pulls you through corridors you don't know | `distances()`, `next_step()`. Fair: optional, it never enters safe circles, and a flip ends it | S–M | ●●● |
| M3 | **The Procession** (ghost train) | NIGHTMARE statues (the landmark statue) wake when you pass within 1 cell, then shuffle after you in single file at walking pace. Contact = a 1.5 s grab and a loud noise, **not death**. Reach a safe circle or flip, and they all shatter, paying 1+2+3+… shards | `Landmarks` statue, `_noise`, safe circles. Fair: slow, visible, never lethal | M | ●●● |
| M4 | **The Heart** (Apparatus) | Some floors put a beating heart in the dead end farthest from the exit. Take it for ×3 floor shards, but every lamp dies and the Devil wakes enraged. You're asked first | Blackout card, the enrage from `_open_exit`, `distances()`. Fair: an explicit choice | S | ●● |
| M5 | **The Rot** (rule card, blue zone) | Lamps die ring by ring outward from the start cell, and in dark cells the Devil is faster. It pushes you on without a visible clock | `distances()` from the start, lamps in `_apply_world`. Fair: rings spread slower than you walk, and they pause in RELAX | M | ●● |
| M6 | **Drop Gates** | Some junctions have a lever. Pull it and a gate slams the corridor **behind** you for 8 s, so the Devil must path around it. One use each | Block the cell in the Devil's BFS only (grid truth). Fair: it only drops behind you and never seals you in | M | ●●● |
| M7 | **Second Exit** (Granny's routes) | Some floors hide a crawlspace exit that needs a found item (a crowbar from a chest). It pays bonus shards, and 1 in 10 leads to a secret floor | `FloorLayout`, chest rolls. Fair: the normal exit always works | M | ●● |
| M8 | **Wrong Floor** (plans/06 A8) | The Exit 8 trend: one landmark is wrong (a lamp colour or a glyph). Landmarks exist now, so this got cheaper | `Landmarks` | M | ●●● |

## 4. Skins: sell what the player sees
In first person you never see your own body. You see your light, the flip, the map and the hands holding
it, the Devil, and the exit. Your character only shows in the Devil Cam replay. Today the Altar has two
cosmetic kinds, `light` (beam colour) and `flash` (flip flash), and they're sold only during events.

| # | Skin | How | Reuses | Effort | Impact |
|---|---|---|---|---|---|
| K1 | **Light Sets that level up by use** (upgradable gun skins) | Level 1 beam colour · L2 flip flash · L3 sigil-collect effect · L4 escape effect · L5 Devil Cam frame + its name on the share card. XP = cells walked with the set on. Levels are earned, never bought | `Unlocks.ALTAR` `light`/`flash` kinds | M | ●●● |
| K2 | **Devil skins** | It's what you look at most (Piggy sells hunter skins). A material swap on the Devil model. The silhouette, the red glow and the sounds stay the same, so every tell stays fair | `devil_rig.gd` | M + art | ●●● |
| K3 | **Map + hands** | Paper, ink, wax seal and marker. Gloves, rings, bangles or mehendi on the hands that hold the map | `paper_map.gd` (`SKIN`, `map_paper*.png`) | S–M | ●● |
| K4 | **Chalk colours and symbols** (sprays) | After chalk (plans/06 G5) | – | S | ●● |
| K5 | **Escape finisher** | The exit portal effect + the "YOU GOT OUT" banner | – | S | ● |

Rules: no stat bonuses (fairness). Paid items are sold directly at a shown price. Every season puts at least one
skin on the free track. Art prompts go to `assets/ASSET_PROMPTS.md` with stand-ins until the files exist (`Art`).

## 5. Seasons and ranks

| # | Option | How | Reuses | Effort | Impact |
|---|---|---|---|---|---|
| P1 | **Labyrinth Pass** | 30 tiers, with XP only from maze play: floors, wisps, relics, procession chains, second exits. Free track: shards, fragments, 2 skins. Premium track: a Light Set, a Devil skin, a map set. **Never expires** (Halo Infinite and Helldivers 2 do this), and old passes stay on sale, which keeps the no-fake-scarcity rule | `MetaState`, `Unlocks`, `LiveOps` | M | ●●● |
| P2 | **Season Tiers** | Lost → Wanderer → Tracker → Pathfinder → Cartographer → Minotaur → Labyrinth Lord (top 100). Points come from the Daily ranked try + Abyss depth. A badge on the leaderboard and the death screen. You drop one tier each season | `Portal`, `Daily`, `MetaState.abyss_best` | M | ●● |
| P3 | **Weekly modes** | Wisp Hunt (5 wisps) · Relic Rain (3 drops, the Devil faster) · Two Devils · Hide & Seek (90 s, no exit, survive) · Speed Maze (60 s) | `Cards.WEEKLY` / `LiveOps` | S each, after M1–M3 | ●● |

## 6. Social: others were here

| # | Option | How | Reuses | Effort | Impact |
|---|---|---|---|---|---|
| S1 | **Bloodstains** (extends plans/06 A7/C7) | On a shared seed (the Daily), red stains mark where players died. Touch one to watch its last 4 s. Build offline first: your own deaths on that seed | the Devil Cam tape (`_record_tape`) | M local / L online | ●●● |
| S2 | **99 Dreamers** (async battle royale) | A Daily seed with up to 99 recorded runs as faint silhouettes. "ALIVE 63/99" drops as their recorded runs die, and you finish ranked against them. No real-time netcode: a run is about 7 KB of positions at 5 Hz | the tape recorder, `Portal`. Needs a small backend, since CrazyGames saves are per player (Firebase, as in the Flutter build) | L | ●●● |

## 7. Build order
1. M2 Wisp → 2. M1 Relic Drop → 3. K1 Light Sets + P1 Pass → 4. M6 Drop Gates → 5. M3 Procession → then
K2/K3 art, M8, S1, S2. One branch/PR each (CLAUDE.md). The threats (master plan §6) are the **danger** track
and these are the **greed** track, so alternate them.

## 8. Measure (P0 event log, `RunState.log_event`)
`relic_drop` (seen/taken/died within 10 s), `wisp` (spawned/caught/escaped), `procession_len`, `heart_taken`,
`gate_used`, `pass_tier`. Red flags: more than 30% of deaths within 10 s of a relic means the Devil arrives too
fast. Under 20% of players detouring for a relic means the loot is too weak.

## Sources
- [S1] [Pac-Man Championship Edition DX (Wikipedia)](https://en.wikipedia.org/wiki/Pac-Man_Championship_Edition_DX)
- [S2] [Pac-Man 99 (Wikipedia)](https://en.wikipedia.org/wiki/Pac-Man_99)
- [S3] [Pac-Man 256 (Wikipedia)](https://en.wikipedia.org/wiki/Pac-Man_256)
- [S4] [PCGamesN: Roblox's Doors horror game](https://www.pcgamesn.com/roblox/doors-horror-game)
- [S5] [Pocket Tactics: Doors finds a way to three billion visits](https://www.pockettactics.com/roblox/doors-visits)
- [S6] [Inven Global: The Exit 8 passes 3 million copies](https://www.invenglobal.com/articles/25663/so-many-lost-travelers-the-exit-8-surpasses-3-million-worldwide-copies-sold)
- [S7] [Sportskeeda: 10 things to know before playing Piggy](https://sportskeeda.com/roblox-news/10-things-know-playing-piggy-roblox)
- [S8] [BlueStacks: Granny rooms, routes and secrets](https://www.bluestacks.com/blog/game-guides/granny/guide-rooms-routes-secrets-en.html)
