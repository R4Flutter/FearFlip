# plans/11 — The Long Night (weekly race)

Status 16 Oct 2026: **v1 built**; **v2's server built** (verified runs, server-side board, rival ghost), waiting for
the user to deploy it (`server/long-night/README.md`). The rest of v2 (results night, fame, tiers) is not started.

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
2. Paste its base64 encryption key into `leaderboardKey` in the Web preset's head include (`godot/export_presets.cfg`),
   only until the v2 server is live; then leave it empty and give the server the Leaderboard API key instead
   (`server/long-night/README.md`).
3. Nothing else: the season resets Monday 09:00 UTC, the same moment the next maze opens.

## v2

Client-sent scores can be faked (CrazyGames' own docs say so), so the board now takes only server-verified times.

### Built 16 Oct 2026: verified runs on a free server

| Piece | What | Where |
|---|---|---|
| Server | Cloudflare Worker + D1, free tier. `POST /run`, `GET /board`, `GET /ghost`, a 10-minute cron | `server/long-night/` (README: run, deploy) |
| Who | the CrazyGames user token: RS256 against `sdk.crazygames.com/publicKey.json` (a PKCS#1 key, wrapped to SPKI for WebCrypto), cached, fetched again once when a token fails on it (at most once a minute), expiry and game id checked | `src/checks.js::verifyToken`, `Portal.user_token` |
| The run | the tape (RaceGhost samples: x, z, yaw every 0.2 s, then one at the chest) must start at the spawn, step only between open cells (corners only past an open side), visit every key box, end at the chest, keep the clock no shorter than the tape, and never outpace a body: over 1 sample, 2 s, 6 s and 10 s, at most a walk plus a sprint for as long as stamina allows (4 s sprint, 6 s rest) plus a frame's slack | `src/checks.js::checkRun` |
| Breach | the Devil's broken wall (once a floor) is sent with the run; the server accepts it only as a Flipping Time begins (the week's schedule is exported), at a wall between two rooms, beside a room you stood in within the 10 s before | `main.gd::_breach_thin_wall`, `Race.breach`, `checks.js::breachFits` |
| The maze | **exported from the game, not ported**: `export_weeks.gd` writes each week's open cells, spawn, exit, keys and Flipping Time starts, plus the pace rules, to `src/weeks.json` (98 KB for 61 weeks). The generator is GDScript on Godot's `hash()` and PCG32; a JS port would be ~400 lines that drift silently. `test_race.gd` fails when the committed export no longer matches the game; the Worker answers 503 for a week not exported | `Race.export_week/flip_times/server_rules`, `FlipSystem.for_floor` (one Flipping Time setup for the game and the export) |
| Board | each player's best and its tape in D1; a new best goes to the CrazyGames Leaderboard API from the server (`X-API-Key`, a Worker secret), retried by the cron until CrazyGames takes or refuses it for good | `index.js::postRun/send/scheduled` |
| Reads | top 10 + the 5 either side of you + your rank. A rank counts one D1 row per runner ahead, capped at 1,000 ("1000+"), and answers are cached 60 s per query in the isolate and the browser: a board read stays under ~1,030 rows of the free 5M a day. Tapes ~25 KB each; weeks older than 4 are deleted | `index.js::getBoard` |
| Client | with `Race.SERVER` set, a new best goes to the server (never also client-side: a key in the page is what lets anyone post a fake time), resent after a network failure, never after a refusal; the result page says sending / verified / refused (why) / log in | `Race.sync`, `Race.board_note` |
| Rival ghost | the run just ahead of yours runs with you, ember red under its name and time (a guest gets the run ahead of their best on this device) | `Race.fetch_rival`, `main.gd::_on_rival`, `RaceGhost.tag` |
| Passed by | the dashboard's board tile shows your rank and "VEX TOOK YOUR 3RD PLACE BY 0.4 S" (or "N RUNNERS PASSED YOU") against the place you held when you last looked | `Race.passed_line`, `main_menu.gd::_on_race_board` |
| Tests | Worker: 21 vitest tests in the Workers runtime (token, tape, breach, the real week walked along the game's own route, D1 routes, the CrazyGames call, the cron). Game: `test_race.gd` (payload, token id, passed line, answers kept, the export and its Flipping Times against frame-by-frame play, drift guard) | `server/long-night/test/`, `godot/tests/test_race.gd` |

Known ceilings (upgrade when it matters):
- A bot that plays at a legal pace, or a speed hack under ~5%, passes; only replays or human review catch those.
- A breach claim is checked against the Flipping Time and where you stood, not the Devil: a cheater could claim one
  thin wall beside them at a flip, once a run.
- Only CrazyGames logins are identities: guests, Poki, GameDistribution, Android and desktop players race but stay off
  the board until each portal's identity is verified too.
- Ranks past 1,000 read "1000+"; bucketed counts or a cron snapshot if the board outgrows that.

### Still to come

- **Results night**: the top 10 routes stay hidden until Monday, then the champion's run plays as a Devil Cam replay.
- **Fame in the maze**: the week's #1 is carved into next week's maze on the route everyone runs ("FIRST OUT · name ·
  6:41"), as a landmark. Champion-only cosmetics (never sold). The champion picks next week's card from three.
- **Season-end tiers in the game** (top 1 / 3 / 1% / 5% / 10% / 25% / finished) on top of the CrazyGames trophies.
- Touch players get their own board once Android ships.

## Assets

Four medal icons, `images/menu/medal_{bronze,silver,gold,devil}.png` (prompts in `godot/assets/ASSETS_NEEDED.md`
A5). Until they land the page uses tinted star / demon icons. No 3D models: the ghost reuses the player's body.
