# FearFlip 3D: Engagement Plan (Act-Runs + "one more run")

> Approved 6 Oct 2026. It replaces the **structure** parts of `plans/05` (L8) and master plan §5;
> everything else in those docs still applies.
>
> **Status:** P1 (Act-Runs) done on `feature/godot-3d-act-runs`. Differences from the §6 table: the
> StageRule tests extend `godot/tests/test_descent_rules.gd` instead of a new `test_stage_rule.gd`; the act
> picker reuses the How-To overlay (`main_menu.gd` `_modal()`); act art is optional, with prompts in
> `godot/assets/images/menu/PROMPTS.md`.
>
> **P2 (Rewards) done** on `feature/godot-3d-rewards`. Differences from §3/§6: floors have 2 keys, so a key
> pays 4 shards (the D1 table assumed 3 × 3); grades use pace (time used ÷ time to walk the key tour, so
> S stays reachable in Act 5) with −1 grade per revive and −1 if chased over 40% of the floor; chest
> omen tokens and lore notes are profile counters until P4/P5 use them, and "rare" is a 30-shard haul;
> the first unlock costs 70 with 14 starter shards (the 20% head start); the menu's two goal cards became
> NEXT UNLOCK + the next act's shortcut ("Daily status" waits for P6); B3 (off-route chests) waits for P3's
> Vault/Greed cards. Shards bank at the chest, on death and on restart, not per pickup.
>
> **P3 (Floor variety) done** on `feature/godot-3d-floor-variety` (cut from the image-free `fearflip-3D-game`).
> Differences from §3/§6: 12 rule cards ship (`scripts/cards.gd`); Locked Flip, Lost Sigil and Hunted Wake wait
> for the systems they need, and Tight Clock (Act 4) and Relentless (Act 5) carry those acts' new thing. Until
> omens (P4) the Shrine is a quiet floor with no rule card, an omen token and x0.75 shards, and the Sanctuary is
> small, has no Devil and gives an omen token (its omen pick and lore note wait for P4/P5). Mystery is one of the
> other doors, shown at floor start, +25% shards. The game's very first floor has no card; there is no door into
> the Sanctuary or the Gate; Hunt opens from Act 2 floor 3. Card mods fold through `RunState.mod()` (counts add,
> factors multiply) and are clamped by `Cards.LIMITS` and `StageRule.MIN_TIME_SLACK`. The per-act look is a hue
> shift of WAKE and the walls (NIGHTMARE stays red). Vault/Greed chests sit down dead ends (B3) and open on reach.

## Context

**The problem.** The game runs a linear campaign. `StageRule` has 100 floors in 5 acts of 20, and
every setting slides in a straight line from floor 1 to floor 100 (`stage_rule.gd:73`). TRY AGAIN
reloads the same maze as often as you like (`main.gd:1408`). Players will get bored because:

| # | Why it bores | Where it shows in the code |
|---|---|---|
| 1 | Same goal every floor, about 1% harder each time, so nothing *feels* new | `StageRule._curve()` is a straight lerp |
| 2 | No choices between floors, so run 12 plays like run 1 | `_win_game()` goes straight to the next floor |
| 3 | Nothing pays: keys and chests give nothing that lasts | `main_menu.gd:713` "no rewards to claim yet" |
| 4 | No stakes: unlimited same-maze retries turn fear into memorising | `_restart_game()` reuses the same seed |
| 5 | The goal is too far away: "Floor 7 / 100" means 93 floors of grind | death screen detail, menu "BEST FLOOR x / 100" |
| 6 | Fear wears off: the same threat stops scaring with repetition. Horror needs new things plus mastery to keep players for weeks | one Devil and the same rules all game |

**Decided (you, 6 Oct 2026):** Act-Runs + Shortcuts · web portal (CrazyGames) first · offline-first
(no own server) · light-mystery story.

**Non-negotiables**
- Keep World Flip, NIGHTMARE, the Devil, sigils, keys, traps, safe circles and revive (your saved feedback).
- Fairness over difficulty, no sudden spikes (GEMINI rules).
- No loot boxes, no energy timers, ads only at natural breaks (master plan §13).
- `plans/05`'s "no meta before the fun test" stays, as Phase 0.

**Before starting.** The current branch `feature/godot-3d-p1-maze` has uncommitted changes
(`death_screen.gd`, `main.gd`, the new game-over images). Commit or stash them before branching for P1.

---

## 1. The formula (what the research agrees on)

There is no single magic formula. But research on roguelites, horror and player retention points the
same way: six factors that **multiply**. If any one is near zero, the whole game sinks. So always fix
the weakest one first.

> **ENGAGEMENT = FEAR × CHOICE × PROGRESS × SURPRISE × SHARE ÷ FRICTION**

| Factor | Evidence | What we use in FearFlip |
|---|---|---|
| **FEAR** (tension, then release) | Left 4 Dead's AI Director cycles build-up → peak → relax; the quiet is what makes the scream work [S4] | Director, Sanctuary floor, Gate set pieces |
| **CHOICE** (control over your run) | Self-Determination Theory: feeling in control, feeling skilled and feeling connected predict enjoyment and coming back (Ryan, Rigby & Przybylski 2006) | Doors, Omens, Curses, when to flip, risky chest detours |
| **PROGRESS** (feeling skilled) | Unlocks should add options, not raw power, and dying should still pay [S1][S2]. People push harder as a goal gets close (Kivetz et al. 2006). A progress bar that starts part-full gets finished more often (Nunes & Drèze 2006) | Fear Shards, unlock bar, shortcuts, grades, "9 m from the exit" |
| **SURPRISE** (random rewards + curiosity) | Vampire Survivors: one analysis counts a small reward about every 23 s, plus a visible unlock checklist [S3]. Hades: every death moves the story on [S5]. Open questions make people want answers (Loewenstein 1994) | Chest rolls, rare events, rule cards, lore notes, death lines |
| **SHARE** (feeling connected) | Wordle went from 90 players (Nov 2021) to 2M+ within weeks of adding its spoiler-free emoji grid [S8]. Spelunky's daily seed is another example | Daily Nightmare + share card, Devil Cam |
| **÷ FRICTION** | Web players value jumping in fast (master plan §3) | Retry in under 2 s, one-tap PLAY, resume mid-run, no timers |

**Every time scale needs its own hook:**

| How often | Hook |
|---|---|
| ~20 s | sigil, key, Close Call, Phase Dodge |
| 2–3 min | floor clear: grade, shards, pick the next door |
| ~12 min | Sanctuary: omen + lore note |
| ~25 min | Gate: set piece, act ending, shortcut unlocked |
| every 1–2 runs | something unlocks |
| daily | Daily Nightmare, 3 quests, streak |
| weekly | Cursed Week mutator |
| every 6–8 weeks | event or season |

---

## 2. The structure: Act-Runs + Shortcuts

```
HUB ── PLAY: any unlocked act · DAILY · ABYSS (after F50)
ACT n = one run, ~25 min
  F1 F2 F3 F4 ── F5 SANCTUARY ── F6 F7 F8 F9 ── F10 GATE
  after each floor: grade + shards + choose 1 of 3 doors (sets the next floor)
GATE cleared → act ending (first time) + next act unlocked forever
             → RETURN (bank, back to hub)  or  DESCEND (keep omens, ×1.5 shards, revives don't refill)
DEATH → REVIVE (≤3 per act; rewarded ad on web) · TRY AGAIN (new run, same act, new seed) · HUB
        shards are always banked (dying still pays)
F50 cleared → true ending + ENDLESS ABYSS (F51+, stacked rule cards, depth score) + NIGHTMARE RANKS 1–20
```

- **50 floors = 5 acts × 10.** That's your own number from L8. The act names stay: Awakening,
  Hunted, Mind Break, Precision Hell, THE BREAKER. "Floor 100" lives on as a bragging goal in the Abyss.
- **Sawtooth difficulty, not a ramp.**
  - Each act gets harder, F5 eases off, and F10 is a set piece at about F8 difficulty plus one twist (never a raw spike).
  - The next act's F1 is easier than this act's F9.
  - How: compute `t = ACT_BASE[act] + IN_ACT_RAMP × k/9` and feed it into the existing `_curve(ends, t)`.
    Every current endpoint keeps working, and `MAZE_SIZES` is indexed by `t`, so the table doesn't change.
- **One new thing per act**, introduced with a bestiary card:
  - Act 1: the core loop.
  - Act 2: dead-end traps and Hunt doors.
  - Act 3: inversion pulses and minimap blackouts.
  - Act 4: trap gauntlets.
  - Act 5: the Devil follows you through flips.
- **Shortcut start kit.** Starting at act n gives n−1 free omen picks, so skipping ahead isn't a trap.
- **DESCEND is the push-your-luck choice.** A full F1→F50 run in one go earns the "Deep Run" title and
  an alternate ending. That's the long-term mastery goal.
- **Why losing an act isn't too harsh.** Acts are short (10 floors). You get up to 3 revives per act,
  the Last Breath omen, and hidden mercy (G3). Shards are always banked. Act 1 is tuned easy
  (GEMINI: stages 1–10 easy).
- **Ship Acts 1–3 first.** Act 4 follows about 2 weeks later; Act 5 and the true ending about 4 weeks
  later. Each drop is an update the portal can feature.
- **Cheap biomes.** Give each act its own palette, fog and wall tint, set as constants next to the
  existing per-world look arrays in `main.gd`. Real biomes (hospital, subway) come later.

---

## 3. Options catalog

★ = in the roadmap below. The rest are options for later. Effort: S = 1 day or less · M = 2–4 days ·
L = 1–2 weeks. Impact runs from ● (small) to ●●● (big).

### A. Floor variety: every floor feels different
| # | Option | Effort | Impact | Plan |
|---|---|---|---|---|
| A1 | **Floor Rule card** for each floor, drawn from that act's deck. Ideas: Blackout (ceiling lights off) · Hungry Dark (Devil +15%, +50% shards) · Short Fuse (Flipping Time every 25 s) · Deaf Night (heartbeat only) · Mirror Night (controls inverted all through NIGHTMARE) · Cracked Earth (twice the traps, cracks glow) · Greed (2 chests, Devil arrives earlier) · Lost Sigil (one sigil wanders) · Locked Flip (no flipping in 20 s windows) · Thick Fog · Safe Haven (4 circles that drain fast) · Hunted Wake (Act 4+, the Devil enters WAKE slowly) | M | ●●● | ★ P3 |
| A2 | **Door choice** after each floor (3 cards): Normal · Shrine (pick an omen) · Vault (keys + chests, Devil earlier) · Hunt (2 rule cards, double shards, rare chest) · Mystery. Always at least 1 safe door; Hunt only from F3; never a Hunt-only choice | M | ●●● | ★ P3 |
| A3 | **Gate floors** (F10). Act 1 "First Blood": the Devil is awake from the start, but far away · Act 2 "Ritual": 5 sigils, Flipping Time every 25 s · Act 3 "Mind Break": inversion pulses, no minimap · Act 4 "Precision Hell": trap gauntlet, tight clock · Act 5 "THE BREAKER": the Devil follows flips, final chase | M | ●●● | ★ P3 |
| A4 | **Sanctuary** (F5): a small floor with no Devil, an omen pick and a lore note | S | ●● | ★ P3 |
| A5 | Per-act palette, fog and wall tint | S | ●● | ★ P3 |
| A6 | New monsters, each with a warning and a counter (Phantom, Sentinel, Ripper; master plan §6), one per act | L each | ●●● | later |
| A7 | Rare events (about 1 floor in 15): Wanderer trade · Golden Sigil · Red Door cursed vault · the ghost of your last death | M | ●● | later |
| A8 | **Flip Anomaly floor**: spot what's different between WAKE and NIGHTMARE. Rides the The Exit 8 / Shift at Midnight trend [S10] and fits the game perfectly | L | ●●● | later |
| A9 | Maze Shift partway through a floor (plans/05 L10) | L | ●● | later |

### B. Builds and risk/reward: no two runs alike
| # | Option | Effort | Impact | Plan |
|---|---|---|---|---|
| B1 | **Omens**: pick 1 of 3 at Shrines, Sanctuaries and Gates. Pool of 16, with 6 unlocked at the start. Quick Veil (flip cooldown −30%) · Twin Flip (2 flip charges) · Cold Blood (heartbeat warns 3 cells earlier) · Cartographer (sigils show on the minimap within 6 cells) · Last Breath (survive 1 catch, back to the last circle) · Ghost Sight (see the other world's walls) · Feather Step (the first crack per floor holds) · Circle Keeper (circles drain 50% slower) · Borrowed Time (+20 s on the clock, the Devil comes 5 s earlier) · Locksmith (keys glow, chests give +1) · Blood Pact (+50% shards, Devil +10%) · Keen Eye (see cracks 1 cell farther away) · Night Owl (NIGHTMARE fog −30%) · Lantern Heart\* · Echo Step\* · Soft Soles\* (\*these 3 need the Devil to hear and see, which arrives in P7) | M | ●●● | ★ P4 |
| B2 | **Curses**: optional at run start, after your first act clear. Blackout · Hungry Dark · Short Fuse · Deaf Night, each +25–50% shards | S | ●● | ★ P4 |
| B3 | Risky detours: keys and chests sit off the main route, and chests now pay (C5) | S | ●● | ★ P2 |
| B4 | Revives (already built): up to 3 per act, a rewarded ad on web, free with premium | — | ●● | keep |
| B5 | Characters with one flip trait each. Insomniac: Ghost Sight built in, shorter sprint · Medium: hears the Devil from farther, dimmer light · Runner: faster sprint, louder steps. Same model, different tint | M | ●● | later |
| B6 | Omen pairs (for example, Twin Flip + Echo Step = "Phantom Waltz") | M | ●● | later |
| B7 | Practice: replay any floor you've reached, with no rewards | S | ● | later |

### C. Moment-to-moment hooks: something every 20 s
| # | Option | Effort | Impact | Plan |
|---|---|---|---|---|
| C1 | **Director**: a "menace" meter that runs build-up → peak → relax (master plan §7) | L | ●●● | ★ P7 (earlier if P0 finds the fear flat) |
| C2 | **Close Call**: the Devil's lunge misses, or you escape from catch range. +3 shards, 0.3 s of slow motion, a heartbeat spike. **Phase Dodge**: you flip inside `FLIP_CATCH_GRACE` | S | ●●● | ★ P2 |
| C3 | **Floor grade** S/A/B/C, based on `StageRule.time_budget()`, catches and revives, and time spent being chased | S | ●● | ★ P2 |
| C4 | Style meter (chain sigils without being seen) | M | ● | later |
| C5 | **Chest rolls**: shards 60% · omen token 20% · lore note 15% · rare 5%, seeded by the floor seed. Never paid randomness | S | ●●● | ★ P2 |
| C6 | **Devil Cam**: on death, replay the last 4 s from the Devil's point of view | M | ●●● | ★ P7 |
| C7 | Footprints of your previous attempt | M | ● | later |

### D. Long-term progress: something new is always 1–2 runs away
| # | Option | Effort | Impact | Plan |
|---|---|---|---|---|
| D1 | **Fear Shards**, the only currency (replaces the COIN and GEM pills). Earn: sigil 3 · chest 4–12 · floor clear 10 + 2 × floor number in the act · grade S +10, A +5 · Close Call 3 · act clear 50 × act number · first bestiary entry 5 · Daily 25 · quest 15–30. You keep 100% when you die | S | ●●● | ★ P2 |
| D2 | **Altar** (unlock tree): add omens to the pool, a starting-omen slot, flashlights (Old Torch → Lantern → UV light that reveals Phantoms → Camera Flash that stuns once per floor), characters, cosmetics (light colour, flip effect, skins). The first unlock costs about one run; the bar starts 20% full | M | ●●● | ★ P5 |
| D3 | **The hub is the existing dashboard** (`main_menu.gd`). Its rows become ALTAR · MIRROR · BESTIARY · ARCHIVE · DAILY. Hide or finish the "soon" placeholders (MULTIPLAYER stays hidden until Steam co-op). No walk-around 3D hub | M | ●● | ★ P5 |
| D4 | **Bestiary**: each threat's rule, lore, and how often it killed you or you escaped it | S | ●● | ★ P5 |
| D5 | **Challenges** with visible conditions (about 40). For example: "Clear Act 1 without sprinting → Soft Soles" · "10 Phase Dodges → Echo Step" · "25 chests → Locksmith" | M | ●●● | ★ P5 |
| D6 | **Act mastery stars**: clear with no revives ★ · S-grade average ★★ · clear with a curse ★★★ | S | ●● | ★ P5 |
| D7 | **Nightmare Ranks 1–20**: stackable difficulty modifiers for extra rewards, like Hades' Heat. Unlocked after your first F50 clear | M | ●● | ★ P8 |
| D8 | Titles and card frames earned from mastery | S | ● | later |

### E. Reasons to come back tomorrow
| # | Option | Effort | Impact | Plan |
|---|---|---|---|---|
| E1 | **Daily Nightmare**: the seed is today's UTC date. A 5-floor mini-act with fixed cards and a fixed omen. One ranked try (stored locally), unlimited practice | M | ●●● | ★ P6 |
| E2 | **Share card**, copied to the clipboard: `FearFlip Daily #37 🟦🟦🟥⭐💀 4/5 · 6:41` (🟦 clean · 🟥 chased · ⭐ S grade · 💀 died) | S | ●●● | ★ P6 |
| E3 | **3 daily quests** from a pool of about 25, picked by the date, with 1 free reroll. The menu's quest cards already exist (`main_menu.gd:673`) | M | ●● | ★ P6 |
| E4 | **Streak**, plus 1 free "freeze" earned every 7 days (max 2). Cosmetics at 3, 7, 14 and 30 days. Missing a day is never guilt-tripped [S7] | S | ●● | ★ P6 |
| E5 | **"Unfinished business"** panel on the menu and death screen: next unlock %, Daily status, "2 floors to the Act 2 shortcut" | S | ●●● | ★ P2 |
| E6 | Cursed Week mutator (picked by the week number) | S | ●● | P9 |
| E7 | Events: Blood Moon (Halloween), Frozen Nightmare (winter). A card set and cosmetics that switch on by date | M | ●● | P9 |
| E8 | Notifications | — | — | Android only, later |

### F. Social and viral (offline-first)
| # | Option | Effort | Impact | Plan |
|---|---|---|---|---|
| F1 | Share card (E2), also offered at run end and on death | S | ●●● | ★ P6 |
| F2 | Devil Cam (C6): clip bait for streamers | M | ●●● | ★ P7 |
| F3 | "Beat my seed" link using CrazyGames' invite link (confirm in the SDK docs) | S | ●● | later |
| F4 | CrazyGames leaderboard: one per game, only for invited games [S6]. Use it for Abyss depth | S | ●● | P8 |
| F5 | Twitch chat votes on the next door or curse (Steam) | M | ●● | later |
| F6 | Co-op with one player in each world (Steam) | L | ●●● | later |

### G. Less friction, more fairness
| # | Option | Effort | Impact | Plan |
|---|---|---|---|---|
| G1 | One-tap PLAY: continue your run, or start at your highest act (rewire the existing rows) | S | ●● | ★ P1 |
| G2 | Resume mid-run after relaunching (RunState already saves floor + seed) | S | ●● | ★ P1 |
| G3 | **Mercy** (hidden): after 3 deaths at the same point in an act, next time you get +1 safe circle or a 5% slower Devil. Resets when you clear it | S | ●● | ★ P7 |
| G4 | Every act clear is a natural "good place to stop" | — | ● | ★ P1 |
| G5 | Chalk marks (the master plan's "C" key) | S | ● | later |

### H. Making money without hurting engagement (web, later)
- **Rewarded ads:** revive (up to 3 per act) · double shards when you bank · 1 omen reroll per run.
- **Midgame ads:** only between the door choice and the next floor, at least 3 minutes apart, and
  never during a player's first 3 floors.
- **Shop:** cosmetics are bought directly, never randomly.
- **Premium:** no ads + free revive, as the GEMINI rules say.

---

## 4. Light mystery (about 2,500 words, text only, no cutscenes)
- **Premise.** Every night you wake in the same building, and every blink flips it into *his*
  version. Others left notes. None of them got out. Each act is one layer deeper, and F50 is the bottom.
- **30 notes** (70 words or fewer). About two-thirds teach a rule in a dead dreamer's voice ("He's slow
  when he's close. Don't run. *Walk.*"). The rest feed the mystery. Found in chests and Sanctuaries.
- **5 act endings** (150 words or fewer each) plus the true ending. The Abyss is "the part that never ends".
- **The Voice** (about 100 lines on the death screen). It reacts to how you died, how many times
  you've died, and milestones, a lighter version of Hades. It extends `DEATH_TEXT` (`main.gd:1345`).
- **Bestiary**: about 8 entries of 60 words.
- **Questions to plant:** Who is the Devil? Why can you flip? Who writes the notes? What's below F50?

---

## 5. Guardrails: hook players with mastery and curiosity, not traps
- No loot boxes or paid randomness.
- No energy or lives timers.
- Streaks never punish you.
- No fake scarcity.
- Ads only at breaks, and capped.
- Every act end is a natural stopping point.
- PEGI-12 content.

These rules also keep the game inside CrazyGames and Poki policy.

---

## 6. Roadmap (one phase = one branch/PR, per CLAUDE.md)

**Code patterns for every phase**
- **Data** lives in `const` tables, one script per system, the way `StageRule.MAZE_SIZES` does it.
  **Logic** is pure static functions with headless tests. `run_tests.gd` finds any `tests/test_*.gd`
  automatically. Tabs, static typing.
- **Every modifier has the same shape**: `{id, name, text, mods}`. That covers floor cards, doors,
  omens, curses and ranks. They all live in **one** data file, `cards.gd`, and use **one** 3-card
  picker UI, `card_choice.gd`.
- **One modifier lookup**: `RunState.mod(key, default)`.
  - It combines the active omens, curses, floor card and rank.
  - It then clamps to the fairness floors: `MIN_DEVIL_SPAWN_DISTANCE`, `MIN_TRAP_CUE`,
    `MIN_FLIP_WARNING`, `FAIR_FLIP_DISTANCE`.
  - Each system reads it once when a floor is built.
- **Your permanent profile** (shards, unlocks, stats, streak) goes in a new `MetaState` saved to
  `user://profile.cfg`. It needs its own file because `RunState.save()` rewrites all of `save.cfg`.
- **Daily and Abyss runs** are just modes of `RunState` (a `mode` field) kept in memory. Only campaign
  runs save mid-run, so playing the Daily never overwrites your campaign.

| Phase | Build | Main files (reuse) | Tests | Gate |
|---|---|---|---|---|
| **P0 Fun gate** (1 day) | A local event log: deaths (cause, floor, time), floor clears and run ends → `user://events.jsonl`. Playtest the current build with 5–10 people (master plan §16 protocol) | `run_state.gd` (about 20 lines); hooks in `_win_game` / `_lose_game` | — | 70% understand the flip without help and 50% press retry. If not, fix the core game before any meta |
| **P1 Act-Runs** (3–4 days) | 50 floors with 10 per act and sawtooth difficulty; `is_sanctuary` (floor 5) and `is_gate` (floor 10) flags; `start_run(act)`, `end_run()`, `clear_act()`. TRY AGAIN on death = a new run from the act start (label "NEW RUN · ACT n · [R]"). Clearing a gate shows a message, unlocks the next act and returns to the menu. Menu: PLAY with an act picker, "BEST FLOOR x / 50". Death text: "Floor k / 10 · Act n" | `stage_rule.gd` (`for_floor`, `is_checkpoint`), `run_state.gd`, new `meta_state.gd`, `main.gd` (`_win_game` :1330, `_lose_game` :1352, `_restart_game` :1408), `death_screen.gd`, `main_menu.gd` (rows :570–581, goal card :713) | `test_stage_rule.gd`: 50 floors, the flags, the sawtooth shape, fairness minimums on every floor. `test_run_state.gd`: unlock and start rules, revives reset per act, a temporary save path | You can play Act 1 F1→F10. Dying restarts Act 1 on a new seed. Clearing the gate unlocks Act 2 in the menu. The existing 22 tests still pass |
| **P2 Rewards** (2–3 days) | Fear Shards, chest rolls, Close Call and Phase Dodge, floor grades, a "+3" pop on the HUD, one currency pill, the unlock bar and the "unfinished business" panel on the death screen and menu | `meta_state.gd` (EARN table, unlock-bar math), `stage_rule.gd` (`grade()` next to `time_budget()`), `main.gd` (`_collect_sigils` :530, `_on_chest_opened` :587, `_check_catch` :647), `treasure_chest.gd`, `death_screen.show_death()`, `main_menu.gd` (pills :667) | `test_meta_state.gd`: earning rules, a typical floor pays 25–40 shards, chest rolls repeat for the same seed, profile save/load works. Grade boundaries in `test_stage_rule.gd` | Even a losing first run earns about 1 unlock |
| **P3 Floor variety** (4–6 days) | Rule cards (a deck per act, shown for 2 s at floor start), the door-choice screen, per-act gate settings, the Sanctuary floor, per-act palettes. `RunState.mod()` is introduced here | new `cards.gd` (FLOOR_RULES, DOORS, GATES, `draw()`, `apply()` with clamps), new `card_choice.gd`, `run_state.gd` (`mod()`, next door), `stage_rule.gd`, `main.gd` (`_ready` :209, look arrays :72–76), `floor_layout.gd` (sigil count becomes a parameter) | `test_cards.gd`: decks filter by act; every card on every floor stays inside the fairness limits; door rules hold over 1,000 seeds | Two floors in a row never play the same. Testers name a favourite door |
| **P4 Omens + curses** (3–4 days) | 16 omens (13 work now), pick 1 of 3, curses at run start, the DESCEND option at gates, the shortcut start kit | `cards.gd` (OMENS, CURSES), `run_state.gd` (omen list). Systems that read omens: `flip_system.gd` (cooldown, charges), `main.gd` (flashlight, heartbeat, clock, fog), `safe_circles.gd` (drain), `trap_field.gd` (first crack, crack visibility) | `test_cards.gd`: draws never repeat; modifiers combine and stay inside the limits | **Minimum Addictive Product.** Playtest: 2.5+ runs per session; when offered, each omen is picked 5–40% of the time |
| **P5 Meta hub** (4–5 days) | Altar unlock tree, challenges (stat counters trigger unlock pop-ups), bestiary, archive (notes + act endings), act stars, menu rows rewired | new `unlocks.gd` (UNLOCKS, CHALLENGES), new `lore.gd` (NOTES, ACT_ENDINGS, VOICE, BESTIARY), `meta_state.gd` (stats, unlocked items), `main_menu.gd` (`_row`; replace the `_soon` dead ends) | `test_unlocks.gd`: costs and requirements checked, challenge checks, profile round trip | For the first 15 runs, something is always unlockable within 2 runs |
| **P6 Daily + quests + streak + share** (3–4 days) | Daily seed = `hash(["daily", Time.get_date_string_from_system(true)])`, a 5-floor mini-act, ranked and practice modes, share text via `DisplayServer.clipboard_set()`, 3 quests a day, streak + freezes | new `daily.gd`, `meta_state.gd`, `main_menu.gd` (quest cards `_quest` :673) | `test_daily.gd`: same seed all day and a new seed the next day; quest picks repeat for the same date; streak math across missed days with freezes; share text format | The Daily works offline, and the share card pastes correctly into Discord and X |
| **P7 Director + Devil Cam + mercy** (5–7 days) | The menace meter (build-up → peak → relax), Devil hearing and sight (enables the 3 starred omens), a 4 s recording of player and Devil positions → Devil Cam on death, hidden mercy | `devil_brain.gd`, new `director.gd`, `main.gd`, `death_screen.gd` | `test_director.gd`: state changes; mercy kicks in and resets | Testers describe floors as "quiet, then terror". No single cause makes up more than 50% of deaths |
| **P8 Abyss + Ranks** (3 days) | F51+ with an extra rule card every 5 floors, a depth score, Nightmare Ranks 1–20, and the CrazyGames leaderboard once the SDK is in | `stage_rule.gd`, `cards.gd` (RANKS), `meta_state.gd` | Stacked cards and ranks never break the fairness limits | — |
| **P9 Live ops** (ongoing) | Cursed Week; events (winter first; Halloween only if a public build is live by 31 Oct); the Act 4 and Act 5 drops; cloud saves through the CrazyGames data module (up to 1 MB of JSON, syncs logged-in players, falls back to browser storage [S6]) | `cards.gd` (card sets that switch on by date), CrazyGames SDK bridge | — | An update every 2–3 days, each aimed at the weakest KPI |

**Why this order.** Structure (P1) → make it pay (P2) → make every floor different (P3) → add
builds (P4). After those four you have a playtestable "one more run" game in about 3 weeks. Long-term
progress, the Daily and polish come after. If P0 shows the fear itself is flat, move P7 ahead of P3:
FEAR multiplies everything else.

**Docs to update in P1.** Mark `plans/05` L8 as replaced, and point CLAUDE.md's "Plan & reference" at `plans/06`.

---

## 7. Metrics (logged locally from P0; portal dashboards after launch)
| KPI | Target | Why it matters |
|---|---|---|
| Runs per session | 2.5 or more | The "one more run" test |
| Players who retry after dying | 60% or more | Master plan §16 |
| First unlock reached in session 1 | 70% or more | The PROGRESS factor |
| Median session length | 12 min or more | CrazyGames counts 10+ min as strong |
| Act 1 cleared within the first 3 runs | 30–50% of players | Neither trivial nor a wall |
| How picks spread across doors and omens | No door above 60%; each omen 5–40% | The choices are real |
| Next-day return (D1), web | 15% or more | CrazyGames counts 10–15% as strong |
| D1 / D7 / D30 return, Android (later) | 27% / 10% / 4% | 2026 mobile benchmarks [S9] |
| Daily share rate | 5% or more of Daily finishes | The SHARE factor |

---

## 8. Verification (every phase)
1. `godot --headless --path godot -s res://tests/run_tests.gd`: all old and new test suites pass.
2. godot-ai `project_run` + `logs_read`: no new errors or warnings.
3. A debug-only "clear floor" key (behind `OS.is_debug_build()`) to walk F1→F10 → gate → menu in
   minutes. Check save/resume by quitting mid-act and relaunching.
4. Fairness: run the 1,000-seed generator test with every floor card applied.
5. Playtest after P4 with 5–10 new players, watching silently. Check the §7 KPIs from
   `events.jsonl`, then ask three questions: What scared you? When were you confused? Would you play again?

---

## Sources
- [S1] Roguelite meta progression: [bugnet.io](https://bugnet.io/blog/how-to-design-a-roguelite-meta-progression), [wayline.io retention postmortem](https://www.wayline.io/blog/roguelike-early-access-retention-postmortem)
- [S2] [feedme.design: Why we can't stop playing these roguelites](https://www.feedme.design/why-we-cant-stop-playing-these-roguelites)
- [S3] Vampire Survivors: [The Secret Sauce of Vampire Survivors](https://jboger.substack.com/p/the-secret-sauce-of-vampire-survivors), [Loop & Ledger](https://loopandledger.beehiiv.com/p/the-overlooked-but-humble-magic-sauce-of-vampire-survivors)
- [S4] Left 4 Dead's Director: [Game Developer: Structure or AI Director?](https://www.gamedeveloper.com/design/structure-or-ai-director-), [Shacknews: how Evolve learned from L4D](https://shacknews.com/article/82787/how-evolve-assures-action-peaks-and-valleys)
- [S5] Hades: [First Person Scholar: There is No Escape](https://www.firstpersonscholar.com/there-is-no-escape/), [AV Club: How Hades makes the case for failure](https://www.avclub.com/hades-and-failure)
- [S6] CrazyGames SDK: [Data module](https://docs.crazygames.com/sdk/html5-v3/data), [Account integration](https://docs.crazygames.com/requirements/account-integration/)
- [S7] [Lenny's Newsletter: Behind the product, Duolingo streaks](https://lennysnewsletter.com/p/behind-the-product-duolingo-streaks)
- [S8] [Wikipedia: Wordle](https://en.wikipedia.org/wiki/Wordle)
- [S9] [Segwise: mobile retention benchmarks 2026](https://segwise.ai/blog/mobile-gaming-app-user-retention-strategies.md)
- [S10] The horror market in 2026: [Shift at Midnight hits 37K concurrent players](https://ingamenews.com/topic/horror-gaming/), [Horror game statistics 2026](https://voxbooster.com/blog/horror-games-statistics-2026/), [Only 7.2% of 2024 indie horror games succeeded](https://wnhub.io/news/analytics/item-47472)
- Papers: Ryan, Rigby & Przybylski (2006) *The Motivational Pull of Video Games*, Motivation and Emotion ·
  Kivetz, Urminsky & Zheng (2006) *The Goal-Gradient Hypothesis Resurrected*, JMR · Nunes & Drèze (2006)
  *The Endowed Progress Effect*, JCR · Loewenstein (1994) *The Psychology of Curiosity*, Psychological
  Bulletin · Hunicke (2005) *The Case for Dynamic Difficulty Adjustment in Games*, ACE.
