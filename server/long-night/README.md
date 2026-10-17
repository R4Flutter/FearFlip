# The Long Night server (plans/11 v2)

A Cloudflare Worker + D1 on the free tier that takes the weekly race's runs, checks them, and puts verified times on
the CrazyGames board from the server. The game talks to it once `Race.SERVER` (godot/scripts/race.gd) holds its URL.

| Route | Does |
|---|---|
| `POST /run` | `{token, week, time_ms, splits, tape, breach}`: verifies the CrazyGames token (RS256), checks the tape against the week's maze, keeps the player's best and its tape, sends a new best to the CrazyGames Leaderboard API |
| `GET /board?week=&player=` | top 10, the 5 either side of you, your rank (`ms=` instead of `player=` for a guest's time) |
| `GET /ghost?week=&player=` | your rival: the run just ahead of yours, with its tape |
| cron, every 10 min | resends bests CrazyGames missed; deletes weeks older than 4 |

## Run it locally

```bash
npm install
npx wrangler d1 migrations apply fearflip-long-night --local
npx wrangler dev
npm test
```

## The week's maze comes from the game

`src/weeks.json` is written by `export_weeks.gd` from the game's own generator: each week's open cells, spawn, exit,
key boxes and Flipping Time starts, plus the pace and stamina rules. Re-run it (then redeploy) whenever the maze code or
the player's speed changes; `godot/tests/test_race.gd` fails until you do, and the Worker answers 503 for a week that
isn't exported (the default export runs 60 weeks ahead).

```bash
godot --headless --path godot -s "<repo>/server/long-night/export_weeks.gd" -- [first week] [last week]
```

## Go live (your Cloudflare account; nothing here is created for you)

1. `npx wrangler login`
2. `npx wrangler d1 create fearflip-long-night`, then paste the printed `database_id` into `wrangler.jsonc`.
3. `npx wrangler d1 migrations apply fearflip-long-night --remote`
4. `npx wrangler secret put CG_API_KEY` and paste the Leaderboard API key from the CrazyGames developer portal
   (Leaderboard tab). It lives only in Cloudflare; never commit it or put it in `.dev.vars` in git.
5. Set `CG_GAME_ID` in `wrangler.jsonc` to FearFlip's CrazyGames game id.
6. `npx wrangler deploy`, then put the printed `https://fearflip-long-night.<you>.workers.dev` into `Race.SERVER`.
7. Leave `leaderboardKey` empty in the Web export's head include (`godot/export_presets.cfg`): with the server live,
   only the server submits, and a key in the page is what lets anyone post a fake time.

The CrazyGames API base URL is a var (`CG_LEADERBOARD_URL`): their docs show both `leaderboard.crazygames.com` and
`userportal.crazygames.com`; switch it if the first answers 404.
