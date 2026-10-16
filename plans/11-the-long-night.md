# plans/11 — The Long Night (weekly race)

Status 15 Oct 2026: **v1 built** (no server). v2 below is not started.

A secondary layer beside the campaign, never a replacement (user, 15 Oct 2026: "keep the same dashboard, keep a button
for changing the mode ... don't replace my current core gameplay"). The dashboard opens on the campaign exactly as
before; the right side has a second page for the Long Night, reached by the **CAMPAIGN | LONG NIGHT · WEEKLY** tabs
above PLAY or by sliding the dashboard sideways (a drag that starts off the buttons, or a horizontal wheel/trackpad
swipe). Back from a race, the dashboard opens on the Long Night page.

## Why it works (validated in chat, 15 Oct 2026)

Same seed + time board is a proven format (Spelunky 2 / Isaac daily runs, Trackmania Weekly Shorts). "Fastest wins"
alone fails: one winner, cheaters on a web client, route spoilers. So: medals and tiers give everyone a goal, splits
and a ghost make the race felt during play, the board runs weekly (pools players, matches CrazyGames' season), and
anything worth stealing waits for v2's server checks.

## v1 (built)

| Rule | Value | Where |
|---|---|---|
| Week | CrazyGames board season: Monday 09:00 UTC to Monday. Week 1 = 12 Oct 2026 | `Race.FIRST_WEEK`, `week_of()` |
| Maze | one per week for everyone: `Race.seed_of(week)`, Act 2 F4 rules (27x27), **4 keys** (`Race.KEYS`), the week's one rule card | `Race.layout()`, `RunState.start_race()` |
| Kit | the same for everyone: no Altar torches, no hidden mercy, no ranks (`RunState.mod` folds only the week's card) | `RunState.mod()` |
| Clock | counts up to the tenth (`Race.format`), no time limit: the Devil is the threat | `main.gd::_update_hud` |
| Lives | one; RUN IT AGAIN at once (death screen [R], R R, the result page), unlimited runs, the best counts | `main.gd::_restart_game` |
| Splits | at every key: `2/4   1:12.4   -4.1` against your best run's same key | `main.gd::_race_split` |
| Ghost | your best run this week walks beside you (pale copy of your body, only you see it, fades near you and at the exit); this device only | `RaceGhost`, `Race.save_ghost/load_ghost` |
| Par | the shortest walk spawn -> every key (best order) -> exit, at walk speed | `Race.tour_tiles`, `Race.par` |
| Medals | BRONZE any escape; SILVER <= par x 1.8 (an A grade's pace); GOLD <= par x 1.35 (S); DEVIL <= par x 1.05 | `Race.medal_times` (tune `DEVIL_PACE` after playtests) |
| Pay | medals only, each once a week: 10 / 15 / 25 / 40 shards. Keys, close calls, chests and stats pay nothing in a race (a farm otherwise) | `Race.finish`, `RunState.banks()` |
| Board | a new best goes to the CrazyGames board in ms, lowest first. CrazyGames itself awards trophies to the top 3 and the top 1%, 5%, 10% | `Portal.submit_time`, Web head include `fearflipSubmitScore` |
| Share | `FearFlip · The Long Night #3 🥇 6:41.3` (the week's best) | `Race.share_text` |
| Saves | best, splits and medals in the profile (`[race]`, cloud-synced); never the campaign's run save | `Race.load_state/save_state` |

Decisions made with it:
- **The single CrazyGames board moved from Abyss depth to the Long Night** (one board per game; a time on one maze is
  a fair comparison, a depth reached in different mazes isn't). The Abyss keeps its deepest run on the dashboard.
- **Fairness fix for every shared maze**: where the Devil reappears after a forced flip (`_keep_devil_fair`) and the
  Echo Step's echo cell (`_cell_near_player`) used the launch-randomized `rng` that also drives the light flicker, so
  two players on one seed got different Devils. They now use `fair_rng`, seeded from the floor. The Daily is now truly
  the same for everyone too.

### What the user does on CrazyGames
1. Ask CrazyGames for the leaderboard (invited games only). Set it to **lowest first** (ASC); the score is milliseconds.
2. Paste its base64 encryption key into `leaderboardKey` in the Web preset's head include (`godot/export_presets.cfg`).
3. Nothing else: the season resets Monday 09:00 UTC, the same moment the next maze opens.

## v2 (next: a free server, its own session)

Client-sent scores can be faked (CrazyGames' own docs say so). Before anything valuable rides on rank:
- **Cloudflare Worker + D1 (free tier: 100k requests/day, 100k row writes/day)**: verify the CrazyGames user token
  (JWT, public key at `sdk.crazygames.com/publicKey.json`), check the run's tape (legal speed through open cells, every
  key before the exit), then submit server-side with the Leaderboard API key. One board across CrazyGames, Poki,
  GameDistribution, Android and desktop. Cache the board (D1 counts rows scanned).
- **Rival ghost**: the player just above you runs with you; pass them, take their rank. "X took your 3rd place by
  0.4 s" on your next visit.
- **Results night**: the top 10 routes stay hidden until Monday, then the champion's run plays as a Devil Cam replay.
- **Fame in the maze**: the week's #1 is carved into next week's maze on the route everyone runs ("FIRST OUT · name ·
  6:41"), as a landmark. Champion-only cosmetics (never sold). The champion picks next week's card from three.
- **Season-end tiers in the game** (top 1 / 3 / 1% / 5% / 10% / 25% / finished) on top of the CrazyGames trophies.
- Touch players get their own board once Android ships.

## Assets

Four medal icons, `images/menu/medal_{bronze,silver,gold,devil}.png` (prompts in `godot/assets/ASSETS_NEEDED.md`
A5). Until they land the page uses tinted star / demon icons. No 3D models: the ghost reuses the player's body.
