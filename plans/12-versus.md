# FearFlip VERSUS: one player is the Devil, one is the runner (plan 12)

Status 17 Oct 2026: **V1–V4 built and V5's code built** (verified: 11 relay tests, `tests/test_versus.gd` 10/10, the full
suite 347/347, and a two-process match through `wrangler dev`: create and join by code, both rounds, roles swapped, the
result on both sides). Waiting on you (V0/V5): Godot 4.7 web export templates, a Cloudflare login, `npm run deploy` in
`server/versus` and its `wss://` URL in `Net.SERVER`; then a test on CrazyGames with two networks. V6 (playtest
balance) after that.

## Built 17 Oct 2026

| Piece | What | Where |
|---|---|---|
| Relay | One Durable Object per room: passes binary on, refuses a 3rd player, >256 B, >30 msg/s and other sites' pages; tells `joined`/`left`; a player's `{"log":…}` goes to Workers Logs | `server/versus/src/index.js`, `rules.js`, `test/room.test.js` |
| Link | `Net` (static, polled each frame by the menu and then the round): the socket, an inbox that survives scene loads, keep-alive pings, silence | `scripts/net.gd` |
| Rules + wire | `Versus`: the messages and their checks, `runner_visible` (fog of war), scoring, the Devil's legs, `Track` (100 ms interpolation), `mod()` for the floor | `scripts/versus.gd` |
| A round | `VersusMatch`: READY/GO, the referee's reports, the Devil's view (runner puppet, ripples + 3D sound, flips, lids, keys, lunge, stun, snap), the round and match page, NEXT/REMATCH, a peer gone (AI takes over / the runner fled) | `scripts/versus_match.gd` |
| Floor hooks | All behind `versus != null` in main.gd: `_tick_devil`/`_animate_devil` follow the player's Devil (speed-capped), `_play_footstep`/`_toggle_map` hear, the reports, no pause/restart/death screen, Hard hides the Devil Cam, the key bar | `scripts/main.gd` |
| Dashboard | VERSUS · 1v1 tab beside LONG NIGHT · WEEKLY: the room and its code (click to copy), EASY/HARD, join by code, CREATE/LEAVE, the two roles; an invite link opens its room | `scripts/main_menu.gd` |
| Portal + ads | CrazyGames invite button/link/param and username; a midgame ad between rounds | `scripts/portal.gd`, `scripts/ads.gd` |

Changes from the plan, found while building:
- `Net` is a static class, not an autoload: `--check-only` and `-s` scripts compile before autoloads exist, so an autoload's name broke the fast parse check on main.gd.
- The Devil's legs are multipliers on the runner's feel (`Versus.devil_feel`), so a retuned runner moves the Devil too; there is no `devil_feel.tres`.
- The Worker's main module may export only the Worker and its Durable Object: the runtime takes every export for an entrypoint (`wrangler dev` refused `MAX_BYTES`), so the checks live in `rules.js` and a test guards it.
- On the Devil's machine the body starts at `layout.devil_spawn` (it started on the runner's spawn until the two-process run showed it).

## Context

The idea (user, 17 Oct 2026): a 1v1 multiplayer mode for FearFlip 3D. One player is the Devil, the other the runner (the character). Two modes:
- **Easy**: the runner has the paper map (M, the "minimap").
- **Hard**: no map.

The Devil hears only the runner's footsteps and the map opening, nothing else. Constraints: a free server now, paid only once traffic grows, and a monetization plan that covers the bill first.

Decided with the user (17 Oct 2026):
1. **Devil senses**: it sees the runner only when they're in view; otherwise it only hears footsteps and the map opening. This holds in both modes. No map, no marker.
2. **Sound cues**: a heard sound plays as 3D audio from that spot, plus a faint ripple through the walls that fades in about a second (for people who play muted).
3. **Matchmaking v1**: friend rooms only (CrazyGames invite link or a 5-letter code). Public quick match comes later, and only if the numbers justify it.
4. **Hard mode**: removes the paper map *and* the live Devil Cam corner. Easy keeps both, as in the solo game.

Rest of the solo game: the World Flip, keys in boxes and the exit stay ((memory: keep-existing-features)). VERSUS is a third dashboard page; the campaign is untouched.

## Verdict: worth it as a friend-invite mode, not as a public queue (yet)

- **The loop is proven**: hunt, find keys, open the exit. On Roblox, Flee the Facility has ~5.9B visits and peaks above 80k players at once; Piggy has ~14B visits.
- **Public matchmaking is the risk.** Dark Deception is a maze horror game. Its asymmetric spin-off, *Monsters & Mortals*, peaked at 176 players (now ~5–9). Reviews report 10+ minute waits and say it's "more enjoyable with friends". So the fun is real; the problem is not having enough players online at the same time.
- **FearFlip is unusually ready**:
  - Both screens can build the same maze from one seed (the Long Night already does this).
  - Hearing already uses path distance through corridors (`main.gd::_noise/_hears`: a walking step carries 2 tiles, a sprinting step 6).
  - The Devil rig animates from a speed alone (`DevilRig.prowl`), and the runner's body is already animated for the Devil Cams (`flee/kneel/hold_map`).
  - A free Cloudflare server setup already exists in `server/long-night/`.
- **The growth case**: each invite link brings a new player for free, and "play as the Devil" is the strongest hook the game has.
- **Risks**:
  - Not enough players online → friend rooms first.
  - 1v1 balance → every match is 2 rounds with the roles swapped; the numbers are knobs.
  - Muted players → the ripple.
  - Prerequisites not done yet: the web export (export templates not installed) and mobile controls (missing, so v1 is desktop browsers only).
- **Kill criteria, 4 weeks after launch**: fewer than 5% of daily players open a room, fewer than 30% of invite links lead to a played round, or fewer than 40% of matches end in REMATCH → keep it as it is and build no quick match. Above that → build quick match with an AI fallback.

## The mode (what players get)

**Room**: the VERSUS page has an EASY/HARD switch, CREATE ROOM (shows the code plus the CrazyGames invite button and a copy-link button) and JOIN (type a code). Opening an invite link drops you straight into the room (CrazyGames "instant multiplayer"). The opponent shows by CrazyGames username (guests: "Devil" / "Runner"). No text chat, because CrazyGames requires chat moderation.

**Match** = 2 rounds on 2 seeds (round 2 = seed+1, so nobody replays a maze they just watched). The room creator runs first and the roles swap after round 1.
- Winner = the better runner result: escaped beats caught; if both escaped, the faster escape wins; if both were caught, whoever survived longer wins.
- Then REMATCH (the same pair stays together, which CrazyGames requires) or LEAVE.

**Round**:
- Floor: same maze and boxes on both screens. Size starts at 25x25 ((memory: big-mazes-only)), tuned one room at a time in playtests.
- What's not on a versus floor: traps, safe circles, cards, chests and the altar.
- What stays: World Flip and landmarks.
- **Runner**: the solo controls and stamina. Kneel to open boxes, 2 keys open the exit, reach it before the floor clock runs out.
  - Easy: the paper map with the Devil marker, plus the Devil Cam corner.
  - Hard: neither.
- **Devil**: first person with the Devil Cam's colour grade, its own movement numbers (`devil_feel.tres`), a short charge instead of a sprint. It can't open the map or the boxes.
  - Starting numbers (my call, to tune in V6): walk = the runner's walk x1.1; charge x1.5 for 3 s, then 8 s rest; enraged x1.15; x0.9 in WAKE (slower there, as in solo).
  - Head start (`HEAD_START` 20 s): it can look around and hear but not move. Then it bursts out of the wall (`_burst_out`'s crash and debris, without the long wake cut).
  - Hearing: footsteps and the map opening, on the solo rules (walk 2 path tiles, sprint 6, map `NOISE_MAP` 4). Each one plays as 3D sound plus a fading ripple at the runner's cell. Box lids, the flip, cracks and the solo game's "last key heard from anywhere" are **not** heard (user: "nothing else"); they stay as balance knobs, off.
  - Sight: it sees the runner only in line of sight.
  - Its HUD: the round clock, the runner's keys (count only), the flip warning strobe, the charge bar. When the exit opens it is enraged (faster), as in solo.
- **Catch**: the solo rule, judged on the runner's machine. The Devil entering the runner's cell or crossing through it starts the 0.35 s lunge; it kills only if it's still within `LUNGE_RANGE` at the end; a miss stuns the Devil (`LUNGE_MISS_STUN`). Flip grace (`FLIP_CATCH_GRACE`) still applies. The Devil's position arrives ~100 ms late, so close calls always favor the runner (fair, never an instant catch).
- **Ends**: escaped (runner wins), caught or the clock out (Devil wins).
- **Never paused**: Esc opens RESUME / LEAVE MATCH while the game keeps running.
  - If the Devil leaves, the AI Devil takes over (`DevilBrain` resumes) and the round isn't scored.
  - If the runner leaves, the Devil wins.
  - A silent peer gets 10 s of grace (a hidden browser tab stops the game loop), then forfeits.
- **Ads**: never during a round. One midgame ad on the result screen between rounds; the other player sees "waiting for X…". No REVIVE in versus.

## Architecture

**Who decides what**: the runner's game is the referee. It runs the real floor as it does today: Flipping Time, boxes, keys, exit, clock and catch. The Devil's game moves its own body, sends its position 10 times a second, and shows everything else from the referee's events. This leaves the single-player code path almost untouched: to the runner's game, the Devil is a node moved by code, just like the AI's.

**Fog of war at the source**: the runner's game sends its position only while the Devil could perceive it:
- line of sight within `DevilBrain.SIGHT_TILES` (whichever way the Devil faces, so turning never makes the runner pop in), or
- within 2 path tiles.

Otherwise it sends only heard sounds (a cell, not an exact position). A hacked Devil client has nothing to read. This is the one security measure the design depends on.

**Transport: a WebSocket relay on Cloudflare (v1)**. Two clients connect to the Worker `fearflip-versus`, which holds one Durable Object `Room` per code. The room forwards each message to the other socket. It uses the Hibernation API, so a waiting room costs nothing.
- Why a relay rather than WebRTC P2P:
  - Godot's built-in `WebSocketPeer` works on web, desktop (dev testing) and Android later. WebRTC needs the webrtc-native addon outside browsers.
  - No NAT/TURN failures (mobile carrier NAT is common in India).
  - It can be tested on one PC with `wrangler dev` and two Godot windows, before any web export exists.
- `Net` hides the transport, so P2P can replace it later without touching the game.
- TCP stalls on packet loss are hidden by a 100 ms interpolation buffer.

**Protocol**: each message is `var_to_bytes([type, …])`. Received bytes are decoded with `bytes_to_var` (never `_with_objects`) and checked for type, ranges and size; anything else is dropped.

| type | direction | fields | when |
|---|---|---|---|
| HELLO | both ways | protocol version, build, name | on join (version mismatch → "refresh the page") |
| START | creator → joiner | seed, easy/hard, round, who runs | each round |
| READY | both ways | none | floor built / result screen done |
| GO | referee → Devil | none | both ready: round clock starts |
| POS | Devil → referee | x, z, yaw, speed | 10 Hz |
| SEEN | referee → Devil | x, z, yaw, speed, flags (kneel, map, winded, flashlight) | 10 Hz, only while perceivable |
| HEARD | referee → Devil | cell, kind (step, sprint, map) | each sound the Devil hears |
| EVENT | referee → Devil | kind: warn, flip(world), box(i, key), key(n), exit_open, wake, lunge, stun(t), snap(x, z) | as they happen |
| END | referee → Devil | result (escaped/caught/time/left), time | round end |

The relay's own notices are plain JSON text: `{"peer":"joined"}`, `{"peer":"left"}`, `{"error":"full"}`.

**Trust checks on the referee**:
- POS has to be finite floats inside the maze.
- The Devil's speed is capped at `devil_feel`'s top speed x1.25 (stops speed hacks).
- If the Devil is inside a closed cell, it is moved out with the existing `_move_devil_into_world` and a `snap` is sent.

**Server checks**:
- Messages over 256 B close the socket.
- More than 30 messages/s per socket closes it.
- A third socket in a room is refused.
- Connections are only accepted from the CrazyGames domains and localhost (stops other sites spending the quota).

## Files

**New**:
- `server/versus/`: `wrangler.jsonc` (DO binding `ROOMS`, `new_sqlite_classes` migration, which the free plan requires), `package.json`, `src/index.js` (~100 lines: route `/room/<CODE>`, `Room` DO with `ctx.acceptWebSocket` / `webSocketMessage` / `webSocketClose`, the limits above), `test/room.test.js`, `README.md` (run, deploy). It copies `server/long-night`'s vitest-in-Workers setup.
- `godot/scripts/net.gd`: autoload `Net`. `join(code)`, `send(msg)`, `leave()`, signals `received` / `peer_joined` / `peer_left`, `rtt`. Wraps `WebSocketPeer`, polled in `_process`. Const `SERVER` ("" = off, like `Race.SERVER`); dev: `ws://127.0.0.1:8787`.
- `godot/scripts/versus.gd`: `class_name Versus`, static like `Race`. Holds:
  - the tunables (`HEAD_START`, `SEND_HZ`, `NOISE_MAP`, `SPEED_GUARD`, enrage, maze rooms, clock scale, plus the off-by-default knobs for box/last-key noise),
  - the protocol encode/decode/validation,
  - `runner_visible(layout, world, devil_cell, runner_cell, gap)`,
  - round roles and seeds, match scoring `winner(a, b)`,
  - a 100 ms snapshot buffer with `sample(t)` for the interpolation.
- `godot/resources/devil_feel.tres`: a second `PlayerFeel` with the Devil's numbers. No new code.
- `godot/tests/test_versus.gd`: codec round-trip and rejection, `runner_visible`, scoring, speed guard, interpolation.

**Changed**:
- `godot/project.godot`: autoload `Net`.
- `godot/scripts/run_state.gd`: `mode = "versus"`, `is_versus()`, and the versus seed, mode, role and round. Versus doesn't bank shards in v1.
- `godot/scripts/main.gd`: every change is gated by `RunState.is_versus()`; one `_tick_versus(delta)`, like `_tick_race`.
  - **Runner (referee)**:
    - `_tick_devil` skips the brain, Director, `_step_devil` and `_tick_wall`, and sets `devil_cell` from the network Devil; `_check_catch` is kept.
    - `_animate_devil` aims at `Versus.sample()` instead of `_devil_world_position()`.
    - `_play_footstep` and `_toggle_map` (`paper_map.open()`) send HEARD when `_hears()`. In versus, `_noise` feeds no brain.
    - These send EVENTs: `_on_flipped`, the flip warning, `_open_box/_take_key`, the exit opening, `_lose_game`, `_unlock_chest`.
    - SEEN goes out at 10 Hz through `runner_visible`.
    - The Devil spawns after `HEAD_START` through `_wake_devil()` directly (no wake cut).
    - Hard sets `has_map = false` and hides `_build_devil_corner`.
  - **Devil (viewer)**:
    - `_build_player` uses `devil_feel` and the Devil's eye height, and hides the runner mesh. The `devil` node follows the local body, with its mesh on `PLAYER_LAYER` (never the inside of your own head).
    - The runner puppet comes from `_make_runner_body()`, extracted from `_build_player`'s mesh and rig lines. It is driven by SEEN through `flee/kneel/hold_map`, carries a flashlight spot, and hides 0.3 s after SEEN stops.
    - `_process` branches into the Devil tick: apply events (`_apply_world` on flip, open box lids, key count, exit, enrage, lunge lurch, stun), play HEARD as sound plus a no-depth-test ripple quad, send POS, update the HUD. All referee logic is skipped.
    - Input: M and interact are blocked.
  - **Both**: `_build_pause_menu` doesn't pause the tree in versus; the round result panel replaces the death screen.
- `godot/scripts/main_menu.gd`: a third page in `_pages` with the tab "VERSUS · 1v1" (player-facing name is a placeholder; rename anytime). New `_build_versus_page` holds the room UI above; boot checks for an invite param and auto-joins.
- `godot/scripts/portal.gd`: CrazyGames invite calls through the existing JavaScriptBridge pattern (invite link, show/hide invite button, read the invite param) and the username. Exact SDK names are checked against CrazyGames' docs when built.
- `godot/scripts/ads.gd`: a midgame ad call beside the rewarded one, used only on the versus result screen.
- `godot/tests/run_tests.gd` (register the suite), `CLAUDE.md` (map entry), memory (these decisions).

## Phases (one per session and branch; check `ListAgents` before touching main.gd/tests, see (memory: parallel-sessions-one-checkout))

| # | What | Done when |
|---|---|---|
| V0 | Prereqs (user): Godot 4.7 web export templates; a free Cloudflare account + `npx wrangler login`. The CrazyGames launch and the Long Night deploy need these too | a web export runs in a browser |
| V1 | Relay server `server/versus/` + vitest | relay both ways, 3rd refused, oversize/rate closed, peer-left notice: all green |
| V2 | `Net` + `Versus` codec and rules + `test_versus.gd`; VERSUS page with create/join by code | two Godot windows on one PC (`wrangler dev`) join a room and trade HELLO/START |
| V3 | The round: referee and viewer hooks, runner puppet, Devil feel, events, results, role swap, match score, AI takeover on leave | a full 2-round match on one PC, both roles; the 287-test suite still green |
| V4 | Senses and modes: HEARD + ripple + 3D sound, SEEN fog of war, Easy/Hard (map, Devil Cam), speed guard | tests prove the runner is never sent out of sight; Hard plays with no map and no Devil Cam |
| V5 | Web + CrazyGames: export, invite link + instant join, usernames, midgame ad between rounds, hidden-tab grace, deploy the Worker (needs your OK: it publishes) | two browsers on two networks (one on mobile data) finish a match from an invite link |
| V6 | Playtest + balance: versus events into `RunState.log_event` (match_start, heard, seen, catch, escape, forfeit); tune maze size, Devil speed, head start, clock | a written tuning pass with real match numbers |
| later | only if the kill criteria pass: quick match (a `Lobby` DO queue by mode, AI Devil after ~25 s), Devil abilities (POUND the thin wall during the flip warning, roar), versus shards + cosmetics, WebRTC P2P transport, Android (the relay works there unchanged) | |

## Monetization and cost (Cloudflare figures verified 17 Oct 2026; ad numbers are estimates)

- **Free tier**: 100k requests/day and 13,000 GB-s/day. Incoming WebSocket messages bill at 20 per request; outgoing ones are free.
  - A room sends about 20 messages/s at most (≈1 request/s) and is active ≈128 MB the whole time.
  - So **≈28 hours of 1v1 play a day for free, ≈330 five-minute rounds**.
  - At the cap new rooms just fail (no surprise bill); the page then says "Versus is full tonight, play the campaign". Daily reset is 00:00 UTC.
- **Paid, $5/month**: includes 1M requests and 400k GB-s ≈ 3,300 five-minute rounds a month.
  - Beyond that: ≈ $0.0005 per round, mostly duration.
  - Example: 1,000 rounds a day ≈ $16/month.
- **Revenue per round**: about 2 midgame ads (one per player). At even $1 eCPM (India-heavy traffic) that's ≈ $0.002 per round against ≈ $0.0005 cost, roughly 4x cover. Exact revenue depends on CrazyGames' share and country mix.
- **Fair monetization (no pay-to-win in PvP)**:
  - A midgame ad between rounds.
  - Rewarded ads: double shards for a match, or try a Devil skin for one match.
  - Cosmetics through the existing Altar shards: Devil eye glow and horns, runner flashlight colours. The art prompts go in `assets/ASSETS_NEEDED.md`.
  - Premium later (plans/10): no ads, plus private-room options (maze size, rules).
  - The real v1 value is growth through invite links.
- **When to pay or change**:
  - Free tier over 70% for 3 days in a row → the $5 plan.
  - A bill over $20/month → per-region shared rooms (one DO serving many rooms through socket tags, which cuts the duration cost).
  - A bill over $50/month → WebRTC P2P (the server only does signaling; Cloudflare TURN gives 1,000 GB/month free).
  - Watch it all on Cloudflare's dashboard, plus one log line per round from the room (result, length, mode).

## Reuse (don't rebuild)

- **Seeded shared floor**: `FloorLayout`, `main.gd::fair_rng`, the Long Night's fixed-kit floor (`RunState.is_race()`; how race mode builds a fixed floor).
- **Hearing**: `main.gd::_noise/_hears` (path distance), `DevilBrain.NOISE_WALK` / `HEAR_SPRINT_TILES`.
- **Sight**: `DevilBrain.line_of_sight` / `SIGHT_TILES` (as used in `_animate_devil`).
- **Catch and flips**: `_check_catch`, `FLIP_CATCH_GRACE`, `_keep_devil_fair`, `_move_devil_into_world`, `_apply_world` (each world's collision for the local body).
- **Bodies**: `DevilRig.prowl` (Devil driven by speed), `DevilRig.flee/kneel/hold_map` (puppet), `PlayerFeel` (Devil numbers).
- **Patterns**:
  - `RunState.mode` / `is_race`, `Race.SERVER`, `server/long-night` tooling.
  - `main_menu.gd::_pages/_show_page` tabs.
  - `Portal`'s JavaScriptBridge calls, `Ads`.
  - `RunState.log_event`.

## Verification

1. **Server**: `npm test` in `server/versus` (vitest in the Workers runtime).
2. **Game logic**: `godot --headless --path godot -s res://tests/run_tests.gd` (the new `test_versus.gd` plus the existing suite). After adding `class_name Versus`, run `--import` once. Agree suite runs with any parallel session first.
3. **One PC end to end**: `npx wrangler dev` (port 8787) plus two `godot --path godot` windows. Play both roles through flip, box, key, exit, catch, escape, time-out, Devil leaving (AI takes over) and runner leaving (Devil wins). In Hard, check the Devil never sees the runner around a corner.
4. **Web**: export, two browser tabs on localhost. Then, once the deploy is OK'd, two machines on different networks (one on phone data) through a CrazyGames invite link.
5. **Balance**: read the versus events log after the first real 1v1 sessions (V6).

Sources: [Cloudflare DO pricing](https://developers.cloudflare.com/durable-objects/platform/pricing/), [Monsters & Mortals player count](https://steambase.io/apps/1266690), [its reviews summary](https://vaporlens.app/app/1266690/dark_deception_monsters_mortals), [Flee the Facility stats](https://profitable.app/roblox/games/flee-the-facility), [Flee the Facility vs Piggy](https://earnaldo.com/blog/flee-the-facility-vs-piggy); CrazyGames multiplayer rules and Cloudflare TURN from the 15 Oct 2026 research ((memory: multiplayer-zero-cost)).
