# Retention features

Four features aimed at the first session and at coming back: a faster start, the
Key Hunt, a loss screen that shows how close the run came (with quiet help), and the
Daily Nightmare. Each one has a switch in `AppRuntimeConfig` (`--dart-define`).

## 1. Guest-first start

**Before:** consent screen → sign-in screen (Google or guest, second policy checkbox)
→ menu → maze. **Now:** consent screen → maze.

- The consent screen stays (it is the legal step). The sign-in screen no longer blocks:
  a guest session starts by itself (`AppFlowProvider._ensureGuestSession`, Firebase
  anonymous auth, or an offline guest when that fails).
- A new player goes straight from consent into stage 1. On EEA devices it first waits
  (at most 12 s) for Google's ad-consent form so the maze never runs underneath it.
- After a guest's **first stage clear**, a one-time "SAVE YOUR RUN" offer appears over
  the stage-clear screen (`SaveProgressDialog`). Google sign-in links the guest account,
  so trophies and rank carry over. Only shown where this build can sign in
  (web, or `GOOGLE_SERVER_CLIENT_ID` set).
- Guests also get a **SAVE YOUR PROGRESS** button on the menu.
- Off switch: `GUEST_FIRST_START=false` brings the sign-in screen back.

## 2. Key Hunt (stage 3 onward)

Five boxes in the maze; two hold keys, three are empty. The exit stays chained shut
until **both** keys are found. Stepping on a box opens it.

- Feedback: a key rises with a chime, a gold flash and a HUD slot pulse; an empty box
  puffs dust with a creak and "EMPTY… 1 KEY IN 2 BOXES". Reaching the sealed exit
  clunks and says how many keys are left. The last key breaks the chains.
- The HUD shows one slot per key and the shut boxes left (honest odds). An amber arrow
  points to the nearest shut box; the exit arrow dims while sealed.
- Shut boxes rattle when the runner is near and glint in the dark; opened boxes stay
  open as landmarks.

**Fairness rules** (the reason both keys can be required):

| Rule | Where |
|---|---|
| Boxes spread along the start→exit route in 5 bands (10–92 %), at most 1 cell off it on stages 3–10, 3 on 11–25, 4 on 26–50, 6 after | `KeyHuntBalance` |
| Never on the start, exit, safe zones, or within 3 steps of the start | `KeyBoxPlanner` |
| Hunt stages get +10 s (a full 5-box tour costs +5–30 % over the plain route; ≈32 s of movement worst case on a 17×17 maze) | `KEY_HUNT_EXTRA_SECONDS` |
| No trap on the route or on any box's side path: fetching a box means walking it twice, and a second step on a cracked trap kills | `TrapPlacementEngine.reservedCells` |
| Maze shifts never touch a shut box's side path and never cut a box off; after a shift, traps on the new routes are removed | `MazeShiftManager`, `TrapStateController.removeTilesOn` |
| Same layout on a revive (seeded, like traps) | `GameScreen._resetKeyHunt` |

Knobs: `KEY_HUNT_ENABLED`, `KEY_HUNT_START_STAGE` (3), `KEY_HUNT_BOX_COUNT` (5),
`KEY_HUNT_KEY_COUNT` (2), `KEY_HUNT_KEYS_TO_UNSEAL` (2), `KEY_HUNT_EXTRA_SECONDS` (10).

Art: the chest and key are drawn in code until these are delivered (each optional):
`objects/chest.png` (4 frames: shut, rattle, open-empty, open-key), `ui/icon_key.png`,
`ui/icon_key_empty.png`, `ui/icon_chest.png`. Sounds: `key_found.mp3`, `box_empty.mp3`,
`exit_unsealed.mp3`, `exit_sealed.mp3`, built from the raw takes by
`python tool/audio/build_sfx.py key_found.mp3 box_empty.mp3 exit_unsealed.mp3 exit_sealed.mp3`.

## 3. Near-miss loss screen and quiet mercy

- The loss screen leads with how close the run came: **"4 TILES FROM THE EXIT · 1 KEY
  SHORT"** and **"2 STAGES TO CHECKPOINT 25"** (`near_miss_text.dart`).
- **Quiet mercy** (`QuietMercy`): from the 3rd failure in a row on the same stage, the
  next tries get +10 s; from the 4th, +20 s and one extra safe zone. Never announced,
  reset by clearing any stage, never in the Daily Nightmare.
- Knobs: `MERCY_ENABLED`, `MERCY_FAIL_THRESHOLD` (3), `MERCY_BONUS_SECONDS` (10),
  `MERCY_MAX_LEVEL` (2).

## 4. Daily Nightmare

One maze per calendar day, the same for everyone on that date (`DailyChallenge`):
the maze, traps and boxes all come from the day's seed. #1 was 2026-10-01.

- Difficulty follows the week: Monday plays like stage 5, Sunday like stage 23 (none a
  multiple of 6, so walls never shift and the maze stays identical for everyone).
- Free retries, no revives, ads or trophies. The escape screen shows the time, today's
  best, the streak and the share text exactly as it will be sent:
  `FearFlip Daily #12 — escaped 0:48 🗝🗝 💀1` / `🔥 5-day streak` (+ `DAILY_SHARE_URL`
  if set). It says nothing about the maze. Phones open the share sheet; the web copies.
- **Forgiving streak** (`DailyStreak`): one escape a day keeps it. Players start with
  one freeze and earn one per 7 days in a row (max 2); a freeze covers a missed day.
- Stored on the device (`DailyNightmareStore`, `daily.v1.*` keys).
- Knobs: `DAILY_NIGHTMARE_ENABLED`, `DAILY_SHARE_URL`.

## What to measure

Day-1 / day-7 / day-30 retention per install cohort (typical mobile game ≈22 % / 4 % /
<1 %; top casual titles ≈30 % / 15 % / 7–8 %), plus the stage where players quit and what
killed them. Compare cohorts before and after this change; the mercy and key-hunt
numbers are first guesses to tune from that data.

## Research behind it

- Uncertain rewards hold attention; a fixed mix in random order (a "shuffle bag") keeps
  randomness feeling fair; visible stepped progress pulls players to the goal; horror
  needs tension and release; keys at dead ends turn wrong turns into progress.
- The first minutes lose the most players; forced sign-up and legal screens before play
  are a top cause (Aalborg onboarding study; industry guides).
- Easing difficulty for players about to quit kept them playing (field experiment with
  300,000+ players, Ascarza, Netzer & Runge, Columbia Business School).
- One shared puzzle a day with a spoiler-free share grid drove Wordle's spread; streaks
  work but must forgive (freezes, low daily bar) or they become pressure.
