# FearFlip on CrazyGames

## 1. Build the upload

```bash
bash tool/build_crazygames.sh
```

Upload `build/fearflip_crazygames.zip` (about 15 MB, about 100 files) on the
CrazyGames developer portal as an **HTML5** game. Everything ships inside the
zip: no CDN, no service worker, no Firebase. The only outside request is the
CrazyGames SDK script itself.

## 2. What is integrated (HTML5 SDK v3)

The bridge lives in `web/index.html` (`window.ffcg`); the Dart side is
`lib/arcade/platform/portal_web.dart`. Every call is safe when the SDK can't
load (ad-blockers, local testing): the game keeps working, saves go to
`localStorage`, and rewarded ads are granted.

| SDK call | When |
|---|---|
| `SDK.init()` | Page load, before the engine starts (waits at most 4 s) |
| `game.loadingStart()` / `loadingStop()` | Page load → first frame of the dashboard |
| `game.gameplayStart()` | The maze is live (not paused, no result screen, tab visible) |
| `game.gameplayStop()` | Pause, result screens, menus, ads, hidden tab |
| `game.happytime()` | 3-star clear, world cleared, Endless best, Daily Nightmare escape |
| `ad.requestAd('rewarded')` | Revive, double souls, double login reward, double mission reward, bonus chests, free souls (all optional, player-chosen) |
| `ad.requestAd('midgame')` | Only on **NEXT** between campaign stages: at most every 3 stages, never in the first 2 minutes, at least 3 minutes apart |
| `data.getItem/setItem` | The whole save (`fearflip.profile.v1`, `fearflip.daily.v1`); cloud-synced for logged-in players |
| `game.settings.muteAudio` | Silences music and sounds; audio is also muted while any ad plays |

Arrow keys, space and page keys never scroll the page around the game.

## 3. Listing text (suggestion)

- **Title:** FearFlip
- **Short description:** Escape a haunted pixel maze while the world flips your
  controls and the Devil hunts you.
- **Description:** Every few seconds the world flips: stone halls turn to bone
  and blood, and your controls reverse. Find the keys, grab soul wisps, hide in
  blue spirit candles and reach the stairs before the Devil reaches you.
  100 stages across 5 worlds (each with its own twist), 3 stars per stage,
  Endless Night, and a new Daily Nightmare every day: the same maze for every
  player. Collect souls to unlock runners, lanterns and trails, and come back
  each night for login rewards, missions and chests.
- **Controls:** Arrows or WASD to move · P or Esc to pause · Touch: the pad in
  the corner.
- **Tags:** horror, maze, pixel, dungeon, survival, escape, daily challenge.
- **Orientation:** both (landscape is best); mobile supported (touch pad).

## 4. Covers

`store/` holds `cover_1920x1080.png`, `cover_800x1200.png`, `cover_800x800.png`
and `icon_512.png`, built from the game's own sprites, fonts and a maze
screenshot. To rebuild them from a new 1920×1080 screenshot:

```bash
python3 tool/make_covers.py path/to/maze_screenshot.png store
```

Check the portal's current list of required sizes before uploading; it can
change. CrazyGames also asks for a short gameplay video, which needs recording
on a real machine.

## 5. Before you submit

Already checked here (headless Chrome, 1280×720, 1920×1080 and a 412×915
phone with touch):

- Opens straight on the dashboard; no sign-in or consent screen.
- Every menu and result screen; win, loss, revive, retry, pause, Endless
  Night, Daily Nightmare, World 2/4/5 twists, power-ups and the shield.
- The SDK event order above, inside an iframe, with a stand-in SDK that
  records every call (the real SDK can't be downloaded in the build sandbox).

Please also check on the CrazyGames **preview / QA tool** with the real SDK:

1. Rewarded ads play, mute the game, and give the reward.
2. A midgame ad appears on NEXT after the third cleared stage (and only after
   the first 2 minutes).
3. Progress survives a reload (and, logged in, another device).
4. The mute button in the CrazyGames frame silences the game.
5. Phone: the touch pad shows, menus fit in portrait and landscape.

## 6. Why the 100 stages no longer get boring

Before, every maze from stage 8 to 100 was the same size with the same 105 s
clock; only the speed numbers changed, nothing could be collected, and losing
at stage 24 sent you back to stage 1. Now:

- **5 worlds of 20 stages, each with a twist:** Lantern Halls (the basics),
  Bone Crypt (cracked floors everywhere), Shifting Catacombs (walls move every
  stage), Blackout Depths (your light burns low), Devil's Throne (the Devil
  sprints when it falls behind).
- **Gate stages** every 10 stages pay a chest on the first clear.
- **3 stars per stage** (escape · 20 % of the clock left · 45 % left without a
  revive): a reason to replay. A perfect walk uses 8–18 % of the clock
  (`test/arcade/star_balance_test.dart`), so 3 stars needs good play but is
  always possible.
- **Losing retries the same stage** (or revives on the spot with a video); no
  more falling back 20 stages.
- **Soul wisps and power-ups** in every maze; souls buy runners, lanterns,
  trails and power-ups.
- **Endless Night** and the **Daily Nightmare** for when the campaign is done.
