# FearFlip 2D: every asset, where it goes, and the prompt to make it

> **Replaced on 11 Oct 2026.** The neon style in this file was dropped. Gameplay art (maze, walls, characters,
> devils, effects, in-run HUD) is now in **`2D-gameplay-assets.md`** (Pokémon-style horror pixel art, all-new
> characters). The dashboard and menu style is still open, with test prompts in `2D-style-test-prompts.md`. Only this
> file's screen map (§4), store specs (§5) and motion rules (§14) still apply; its colours and prompts don't.

For the 2D game on `main` (Flutter + Flame, portrait phones). **Every file in this list is new.** Nothing comes from
the old 2D sprites and nothing comes from the 3D game. The 3D dashboard is only the bar for polish and motion:
layered painted art, glow, and things that keep moving.

**Style: FearFlip 2D's own neon horror** (picked 10 Oct 2026). Painted horror-poster art lit almost only by neon:
toxic green for WAKE, hot magenta and violet for NIGHTMARE, devil red for danger, gold for rewards. The UI is smoked
black glass in black-chrome bezels with neon edge light and a little glitch.

**Today** every screen is drawn by code: flat black cards with neon-green borders, Material icons and a
black-and-white line maze. `pubspec.yaml` also still points at sprite folders that are gone from `main`. About 85
images below (the 42 icons come as 4 sheets) replace all of it.

## How to use this file

1. Copy a prompt, add the **STYLE** line (§1.6) where a prompt says *+ STYLE*, and generate at the size given. If
   your tool can't make that aspect ratio, use the nearest one and keep the subject inside the middle.
2. Save the original as **`assets/new_assets/<exact file name>`**. That folder isn't bundled into the app, so big
   files are fine.
3. Tell Claude "assets delivered". Claude trims and resizes the ship copy into `assets/images/<group>/`, builds the
   neon glow layers, slices the sheets, updates `pubspec.yaml` and wires each file in. Until a file exists, its slot
   keeps today's code-drawn look, so you can deliver in any order.
4. Follow §15. Tier 1 (53 images) changes every screen.

| Group | Images | Tier 1 |
|---|---|---|
| §5 Brand and store | 7 | 7 |
| §6 Backgrounds and key art | 12 | 4 |
| §7 UI kit | 22 | 15 |
| §8 Icons (4 sheets, 42 icons) | 4 | 4 |
| §9 Neon titles | 6 | 3 |
| §10 Maze and maze objects | 15 | 12 |
| §11 Characters | 8 | 4 |
| §12 Effects | 11 | 4 |
| §13 UI sounds (optional) | 12 sounds | 0 |

---

## 1. Art direction

### 1.1 The look
- **Painted, not pixel art and not 3D renders.** Semi-realistic horror-poster painting with clean, readable shapes.
- **Lit by neon.** Almost everything sits in deep black-violet shadow. Neon tubes, glowing eyes and lit floors are
  the only light. Wet surfaces reflect it, and smoke and haze catch it.
- **The UI is dark glass and black chrome.** Smoked black glass panels sit in thin bevelled black-chrome bezels,
  with small corner brackets, hex screws and a neon tube just inside the rim. The *code* lights that tube, so one
  frame can glow green, magenta, gold or red, pulse and flicker.
- **Glitch has a job.** RGB split, scanlines and tears show up at the reality flip and near danger. They're never
  decoration.
- **References:**
  - Pac-Man Championship Edition DX: a neon maze on black where the path always reads.
  - Hotline Miami and Katana Zero: neon in grimy places, where players read neon as "something bad is coming".
  - Your 3D dashboard: how far to push layering, glow and motion.

### 1.2 Palette, and what each colour means
| Role | Colour | Hex | Use only for |
|---|---|---|---|
| Shadow | black-violet | `#07060B` | backgrounds, glass |
| Panel fill | ink | `#14101C` at 85% | panels, plates |
| Chrome | gunmetal to highlight | `#2A2633` to `#8C8799` | bezels, frames |
| Text | bone | `#EDE6F2` | words, numbers |
| WAKE / go | toxic green | `#39FF88` | WAKE walls, PLAY and "go" buttons, stage |
| NIGHTMARE | hot magenta | `#FF2BD6` | NIGHTMARE floor, flip warning, glitch |
| NIGHTMARE 2 | electric violet | `#8A2BFF` | NIGHTMARE wall rims, Void Ripper |
| Danger | devil red | `#FF2A2A` | the Devil, traps, low time, death, delete |
| Reward | gold | `#FFC83D` | exit, trophies, revive, Remove Ads, ranks |
| Safe | ward cyan | `#8CF6FF` | safe zones only |

Red means danger and nothing else, so **no runner wears red**. Cyan means safe, gold means a reward or money, and
green and magenta are the two worlds.

### 1.3 The two worlds (the flip)
Today `isFlippedMode` swaps a black floor with white walls for a white floor with black walls. The art keeps that
inversion, so the flip lands in one frame and the maze reads in both worlds:

| | WAKE (normal) | NIGHTMARE (flipped) |
|---|---|---|
| Floor | near-black wet concrete with faint green reflections (**dark**) | glowing hot-magenta tiles with violet veins (**bright**) |
| Walls | toxic-green neon tubes (**bright**) | black void beams with violet rims (**dark**) |
| Behind the maze | a dark monitor room | the same room flooded magenta |
| Air | slow green motes | magenta glitch flecks, red edge veins |

### 1.4 Readable at maze size
Mazes grow from 10×10 (stage 1) to 29×29. On a 390-dp-wide phone the maze is about 350 dp across, so a cell is
about 35 dp at stage 1 and 12 dp at 29×29. Runners are drawn at 0.78 of a cell, which makes them **9 to 27 dp
tall**. So:
- **Silhouette first.** Every character must be recognisable as a flat black shape at 32 px: horns, hood, helmet,
  blades.
- Give each one a dark body, a thick dark outline, one bright neon accent and a rim light. The code adds a soft glow
  disc under each actor.
- Keep floors low contrast and walls high contrast.
- Check every sprite at 32 px on both floors before you accept it.
- A gameplay note, not an art one: from about 25×25, a camera that follows the runner (about 13 cells across) would
  make everything about twice as big. That's your call.

### 1.5 Fonts (free, SIL OFL, from Google Fonts)
| Font | Used for |
|---|---|
| **Bebas Neue** | titles, buttons |
| **Rajdhani** SemiBold + Bold | labels, names, HUD numbers |
| **Share Tech Mono** | the timer, stats and terminal lines (RE-LINKING..., Signal Lost). Its digits are all the same width, so the timer never jitters. |

Keep Google's file names and put the files in `assets/google_fonts/`. The `google_fonts` package uses bundled files
before fetching, so the game never waits on the network for a font. Long text such as the privacy policy stays in
the system font.

### 1.6 Prompt templates

**STYLE** (add it where a prompt says *+ STYLE*):
> neon horror mobile game art, painted like a horror movie poster, deep black-violet shadows, lit only by neon: toxic
> green #39FF88, hot magenta #FF2BD6 and electric violet #8A2BFF, devil red #FF2A2A for danger, gold #FFC83D for
> rewards, wet reflections, soft bloom, light haze, crisp readable shapes, no text, no watermark.

**Background types** (each file says which one it needs):
- **transparent**: a PNG with alpha. Use your tool's own transparency option, then check it over a checkerboard,
  because prompt words alone don't guarantee it. If the tool can't do alpha, generate on flat `#00FF00` green (flat
  `#FF00FF` magenta for anything green) and remove it.
- **on black**: glow art painted on pure black. The game *adds* it as light, so the black disappears. Never remove
  the black.
- **pale on black**: the same, painted in white only. The game tints it, so one file serves several colours.
- **full-bleed**: fills the screen edge to edge.

**T-ICON** (a single icon, 512×512, transparent; for redoing one icon from a sheet):
> Game UI icon of {SUBJECT}, neon horror mobile game icon, bold simple silhouette that reads at 24 px, glossy black
> chrome body with a glowing {COLOUR} neon edge light and soft halo, one small glitch offset on the edge, centred with
> a 10% empty margin, isolated on a transparent background, no text, no letters, no numbers, no watermark.

**T-PLATE** (frames, buttons, panels):
> {SUBJECT} for a neon horror mobile game UI: smoked black glass set in a thin bevelled black-chrome bezel, small
> corner brackets with hex screws, a thin neon tube running just inside the rim and lit pure white, faint scratches
> and one hairline crack near a corner, front view, perfectly symmetrical, all the detail in the corners and ends,
> the long edges plain and straight, isolated on a transparent background, no text, no watermark.

Claude splits the white tube into its own `*_glow.png`, so the game can light it green, magenta, gold or red, pulse
it, and flicker it. The same glow doubles as the keyboard focus ring on web.

**T-SPRITE** (characters seen from above):
> Game sprite for a top-down maze game, seen from above at a 3/4 angle (camera about 35° from straight down):
> {SUBJECT}, {POSE}, full body, a big readable silhouette that still reads when shrunk to 32 px, dark body with a
> thick dark outline, a bright {COLOUR} neon rim light and one glowing accent ({ACCENT}), clean painted shading,
> centred, feet at 80% of the image height, isolated on a transparent background, no ground, no shadow, no text, no
> watermark.

**T-SCENE** (full-bleed portrait backgrounds):
> Neon horror mobile game background, painted like a horror movie poster, portrait 9:16: {SUBJECT}. {LAYOUT}. + STYLE

Generate at 9:16 (1152×2048 or larger). Tall phones crop a little off the left and right, so keep the subject in
the middle 80% of the width. If your tool only does 2:3, keep it in the middle 60%.

**T-FX** (effects on black):
> {SUBJECT}, a game visual effect element on a pure black background, only light, smoke and particles, a bright core
> fading smoothly to black, nothing touching the image border, no ground, no scene, no text, no watermark.

**T-TITLE** (words; use a tool that can spell, §2):
> The words "{WORDS}" as a broken horror neon sign: bold condensed capital letters bent from glowing {COLOUR} neon
> tubes on a thin black chrome rail, one letter flickering dimmer than the rest, a drip of black grime under two
> letters, a faint magenta and cyan glitch offset, soft bloom, centred, wide 4:1 composition, on a pure black
> background, no other text, no watermark.

**T-TILE** (seamless floors):
> Seamless tileable texture, straight top-down orthographic view, flat even lighting with no cast shadows: {SUBJECT},
> exactly 4×4 square tiles edge to edge (one tile = one maze cell), tiles perfectly on all four edges, painted, no
> text, no watermark.

**Editing a file you already approved** (every *_off*, NIGHTMARE and "same but" file): give the approved image to an
editing model and say what changes *and* what stays: "Same image, {change}; everything else identical."

---

## 2. Tools (research, Oct 2026)

| Files | Best tool | Why |
|---|---|---|
| Key art, backgrounds, portraits, the Devil | GPT Image or Nano Banana Pro (Gemini) | strongest prompt adherence. Nano Banana Pro is best at editing an image while keeping the rest identical, so use it for every *_off*, NIGHTMARE and "same but" variant. |
| The logo and titles (words) | Ideogram, or GPT Image | best text accuracy. Make 4 or more and keep the one that's spelled right. |
| Icon sheets, UI plates | Recraft (build a custom style from 2-3 approved images), or GPT Image with your first approved sheet attached | keeps a whole set in one style |
| Walk cycles | **AutoSprite** or **Ludo.ai** (one approved image → walk sheet in 4 directions) | both animate painted, non-pixel art. PixelLab leads for *pixel* art only, so it's not for this style. |
| Animated effects (optional) | any video model (Veo, Kling, Runway...) on pure black, then ffmpeg into a sheet | AI frame-by-frame sheets drift; a video keeps the motion continuous |
| Mood and early exploration | Midjourney | great looks, but weaker at transparency and at keeping a character consistent |
| Background removal | the tool's transparent mode, else remove.bg, Photoshop or rembg | never remove the black from *on black* files |

**Consistency is the #1 problem with AI art.** Approve one anchor per family first: the logo, `btn_play.png`, icon
sheet A, the Steel Sentinel base image and `floor_wake.png`. Judge each at real game size over a real game
background. Then attach the anchor as the style reference for the rest of its family and generate in small batches.

**Animated effect loop (video → sheet):**
1. Prompt the video model: *"{effect}, centred, on a pure black background, seamless loop, 2 seconds, locked
   camera"*.
2. Run `ffmpeg -i clip.mp4 -vf "fps=12,crop=ih:ih,scale=256:256,tile=6x4" -frames:v 1 fx_<name>_sheet.png` to get 24
   frames in one sheet.
3. Keep the black, because the game adds the sheet as light.

**Licences:** use a plan whose terms allow commercial use, and note which tool made each file. The stores and your
own records may ask.

---

## 3. Folders, sizes, formats

```
assets/new_assets/        your originals (not bundled, any size)
assets/images/
  brand/    logo, app icon layers
  bg/       full-bleed scenes, dashboard layers
  ui/       plates, frames, controls (+ the *_glow.png layers Claude makes)
  icons/    icon sheets
  titles/   neon word signs
  maze/     floors, walls, posts, decals
  objects/  exit, safe ward, start, traps
  chars/    runner and Devil sheets, portrait cards
  fx/       effects
assets/google_fonts/      the .ttf files
store/                    Play and App Store art (never bundled)
```

- **Ship copies** (Claude makes them) are about 3× their display size and never over 2048 px on the long side.
  Full-bleed scenes ship as JPG at quality 85 (or WebP), and everything with alpha ships as PNG. The target is under
  15 MB of images in the app.
- **Plates stretch only in their plain middle** (Flutter `centerSlice`), so keep ornament out of the long edges.
- **Sheets** keep 4 px of empty space inside every cell edge, so frames never bleed into each other when scaled.
- `pubspec.yaml` still lists the old sprite folders, which don't exist on `main`, so the build fails on them. Claude
  swaps those lines for the folders above.

---

## 4. Screen map: where each file goes and how it moves

### 4.1 Boot (native splash → first Flutter frame)
| Slot | File | Motion |
|---|---|---|
| Android 12+ / iOS splash | `brand/splash_icon.png` on `#07060B` | static (drawn by the system) |
| First frame | `brand/logo_off.png` → `logo_on.png` | the sign powers on: the tubes sputter twice (80 ms flickers), FEAR lights, then FLIP, with the `ui_neon_on` buzz. 1.2 s in total. |

### 4.2 Sign in (`lib/presentation/screens/auth_gate_screen.dart`)
```
+------------------------------+
|        bg_gate (door)        |   slow drift; red light pulses in the door gap
|          FEAR  FLIP          |   logo powers on (4.1)
|                              |
|  +------------------------+  |   ui/panel.png
|  | [official Google btn]  |  |   Google's own button, never generated
|  | [account] PLAY AS GUEST|  |   ui/btn.png + icon_account
|  | [ ] I accept the policy|  |   ui/check_box.png + the check glyph
|  +------------------------+  |
+------------------------------+
```
While it shows "Authenticating session...", `objects/exit_ring.png` spins, tinted green. Google sign-in must use
Google's official button and "G" logo (their branding rules), never an AI-made copy.

### 4.3 Dashboard (`lib/presentation/screens/landing_screen.dart`)
```
+--------------------------------+
| (AB) PLAYER NAME   [cup] 1,234 |   ui/avatar_ring.png · ui/pill.png + icon_trophy (counts up)
|                                |
|           FEAR  FLIP           |   logo_on / logo_off; FLIP turns over
|    dash_devil in the fog       |   breathes; its eyes stay lit in blackouts
|    dash_bg: the neon maze      |   drift, neon flicker, fog, motes
|        dash_runner_<id>        |   the runner you picked, breathing
| +----------------------------+ |
| |    [>]  START SURVIVAL     | |   ui/btn_play.png: glow pulse + shine sweep
| +----------------------------+ |
| +-------------+ +------------+ |
| | [runner]    | | [crown]    | |   ui/tile.png + icon + the current words
| | CHARACTER   | | LEADERBOARD| |
| +-------------+ +------------+ |
| +-------------+ +------------+ |
| | [cog]       | | [no ads]   | |
| | SETTINGS    | | REMOVE ADS | |
| +-------------+ +------------+ |
|  [bars] RANK #128              |   ui/pill.png + icon_rank (Global Panic rank)
|  [shield] privacy policy       |   icon_privacy
| ======== ad_rail ============= |   ui/ad_rail.png
|         (banner ad)            |   free players only
+--------------------------------+
```
Layers, back to front: `dash_bg` → `fx_fog` (scrolling) → `dash_devil` (added as light) → neon glow spots (code,
pinned on the art) → `fx_spark` motes → `dash_runner_<id>` → the UI.

| When | What happens |
|---|---|
| Enter | From black, `dash_bg` fades in while zooming 1.08 → 1.0 (2.4 s, sine). The runner rises 32 dp and fades in (1.2 s). The logo powers on (§4.1), then FLIP flips upside down and back (0.5 s, back-ease). The tiles cascade up 24 dp with a fade, 60 ms apart (0.4 s, ease-out quint). PLAY pops from 0.8 to 1.0 (0.5 s, back-ease). |
| Idle | The scene drifts 1.0 ↔ 1.04 (26 s each way). The Devil breathes (opacity 0.35 ↔ 0.6, 4 s). One random tube dips to 30% for 60 ms every 2-5 s. Fog scrolls, motes rise, the PLAY glow pulses (1.6 s), and a shine sweeps across PLAY every 2.5 s. |
| Blackout, every 8-14 s | All neon dies twice for 120 ms (crossfade to `dash_bg_off.jpg`); only the Devil's red eyes stay lit, with the `ui_blackout` zap. Off when Reduce Flashing is on. |
| Press anything | Scale 0.96 in 90 ms, glow to 100%, a light haptic and `ui_tap`; it springs back on release. |
| Press PLAY | The dashboard flips: green turns magenta (200 ms), an 8 dp RGB split for 120 ms, a 6 dp shake, FLIP spins, then a glitch wipe into the maze (300 ms). |

### 4.4 Choose runner (dialog in `lib/app/fear_flip_app.dart`)
- **Frame:** `ui/panel.png` + `ui/panel_header.png`, with "CHOOSE CHARACTER" set in Bebas Neue.
- **Cards:** three `ui/card_frame.png` holding `chars/card_<id>.png`. The picked card's frame lights in its runner's
  colour, with the check glyph on it.
- **Button:** DONE on `ui/btn.png`.
- **Motion:** the cards deal in from below, 60 ms apart. The picked card lifts 8 dp and its art zooms to 1.06, and
  its walk cycle (`chars/<id>_sheet.png`, row 1) plays under it.

### 4.5 Settings (dialog in `lib/app/fear_flip_app.dart`)
| Row | Files |
|---|---|
| Control scheme | two `ui/tile.png` with `icon_joystick` / `icon_dpad`; the chosen one lit green |
| Control size | `icon_size` + `ui/bar_track.png` / `bar_fill.png` + `ui/slider_knob.png` |
| Sound | `icon_sound_on` / `icon_sound_off` + `ui/toggle.png` (its knob is `slider_knob.png`); volume uses the slider above |
| Ad consent | `icon_consent` + `ui/btn.png` |
| Account | `icon_account`. Sign out: `ui/btn.png` + `icon_sign_out`. Delete account: `ui/btn.png` lit red + `icon_delete`. |

- **Frame:** `ui/panel.png` + `ui/panel_header.png` ("SYSTEM SETTINGS"), each row on `ui/row.png`, and
  `icon_close`.
- **Motion:** rows stagger in 40 ms apart. Toggles slide in 120 ms with `ui_toggle`, and sliders tick (`ui_tick`)
  every 5%.

### 4.6 Leaderboard (`global_panic_leaderboard_screen.dart`, `leaderboard_next_level_screen.dart`)
- **Background and title:** `bg/bg_leaderboard.jpg` and `titles/title_global_panic.png`.
- **Top 3:** `ui/podium.png`, with `icon_medal_gold` / `_silver` / `_bronze` and `ui/avatar_ring.png`.
- **Everyone else:** one `ui/row.png` per player, holding the rank number, the name, `icon_stage` + stage and
  `icon_trophy` + trophies. Your own row is the same row lit magenta.
- **States:**
  - Syncing: `exit_ring` spinning.
  - Signal Lost: `icon_signal_lost` over `fx/fx_static.png`, with Reconnect on `ui/btn.png` + `icon_restart`.
  - Empty: a dim `icon_leaderboard` and "No champions yet".
- **Motion:** the podium rises (1st place last, with a gold flare), the rows slide in 30 ms apart, and the numbers
  count up over 0.5 s.

### 4.7 Remove Ads (`lib/presentation/widgets/remove_ads_dialog.dart`)
- **Frame:** `ui/panel.png` + header, and `icon_close`.
- **Content:** a big `icon_no_ads` (floats ±4 dp, with a gold shine), then four benefit lines with `icon_check`.
- **Buttons:** Buy Now is `ui/btn_play.png` lit gold, with the store price. Restore Purchases is `ui/btn.png` +
  `icon_restore`.
- **On purchase:** a gold `fx/fx_burst.png` and `ui_purchase`.

### 4.8 Small dialogs and the privacy page
- **Small dialogs** (ads consent, delete account, messages): `ui/panel.png` + header + two `ui/btn.png`, green for
  go and red for destructive.
- **Privacy policy page:** `bg/bg_gate.jpg` dimmed to 40%, `ui/panel.png` holding the scrolling text, and
  `icon_back`.
- **Motion, for every dialog:**
  1. The scrim fades to 75% black in 160 ms.
  2. The panel scales 0.94 → 1.0 and fades in over 200 ms (ease-out quint).
  3. Its neon edge draws itself around the frame in 400 ms, and the contents stagger in 40 ms apart.
  4. Closing reverses in 150 ms.

### 4.9 The run (`game_screen.dart`, `maze_painter.dart`, `widgets/game_hud.dart`, `widgets/game_controls.dart`)
```
+--------------------------------+
| (||)  [#]12  [t]0:42  [>]25    |   btn_round + icon_pause; ui/pill.png + icon + number
|           <3 <3 </3            |   icon_heart / icon_heart_empty (stages 26+)
| +----------------------------+ |
| | maze_frame (monitor bezel) | |   ui/maze_frame.png
| |  floor + walls + posts     | |   WAKE <-> NIGHTMARE
| |  start, exit, safe wards   | |   objects/*
| |  traps, runner, the Devil  | |   objects/trap_*, chars/*_sheet.png
| +----------------------------+ |
|     bg_play (monitor room)     |   bg/bg_play*.jpg
|          ( joystick )          |   joy_base + joy_knob, or 4 x dpad_btn
+--------------------------------+
```
The HUD is icons and numbers only, with no words. Optionally, the stage name (for example "FIRST CONTACT") can show
once at the start of a stage, on `ui/pill.png` for 1.5 s.

| Moment | Files | Motion |
|---|---|---|
| Stage start | `objects/start_mark.png` | the floor fades in from the start mark outward (300 ms); the runner drops in with a one-frame squash |
| Walking | `<runner>_sheet` rows down / up / side | a 10-12 fps walk; the code adds bob, foot-strike squash and a small lean |
| Flip warning (0.8-1.2 s before) | `fx_edge_veins` tinted magenta | the veins pulse at 2 Hz, the walls flicker, the timer glitches, a heartbeat plays |
| The flip | floor, walls and posts WAKE ↔ NIGHTMARE; `bg_play` ↔ `bg_play_nightmare`; `fx_ring`; `fx_static` | one white frame (skipped with Reduce Flashing), RGB split and tear slices for 150 ms, a 180 ms crossfade, a ring bursting from the runner (400 ms), a 4 dp shake |
| NIGHTMARE | `fx_spark` tinted magenta | the floor's brightness breathes ±8% at 1 Hz; a small glitch slice every 2-4 s |
| The Devil appears | `fx_rift`, `fx_smoke`, `devil_sheet` | a red rift opens in the floor (300 ms), smoke bursts, the Devil rises and its eyes ignite |
| The Devil is near | `fx_edge_veins` tinted red | the edge veins grow as it closes in, and the heartbeat speeds up |
| Safe zone | `safe_ring` tinted cyan | it spins at 30°/s while a code arc counts down its time. Entering flashes a cyan ring with a chime; when it runs out it shatters into motes. |
| Trap | `trap_hairline` → `trap_cracked` → `trap_critical` → `trap_hole` | the hairline is barely visible (it fades with the stage's hidden-cue level); cracks spread in 150 ms; the critical tile pulses red at 1.5 Hz; the collapse uses the existing 1.8 s sequence with `trap_hole`, shards and dust |
| Exit | `exit_ring` tinted gold + `exit_core` | the ring spins and the core pulses at 1.2 Hz; on arrival, a gold flash and `title_stage_cleared` |
| Low time (10 s or less) | `icon_timer` tinted red, `fx_edge_veins` red | the number shakes each second, with a heartbeat |
| Life lost | `icon_heart` | the heart cracks and splits into two falling halves (code), with a red flash on its pill |

**Controls:** `ui/joy_base.png` + `ui/joy_knob.png` (the knob's glow brightens the further it's pushed), or four
`ui/dpad_btn.png`. That's one file, rotated, and the pressed key lights green.

### 4.10 Pause (`widgets/run_paused_dialog.dart`)
- **Frame and title:** `ui/panel.png` + `titles/title_fear_cycle.png`, which flickers on.
- **Stats:** pills with `icon_stage` + stage, `icon_timer` + time left, and `icon_flip` + WAKE / NIGHTMARE.
- **Checkpoint line:** `icon_checkpoint` + "3 stages to 25".
- **Buttons:** RESUME SURVIVAL is `ui/btn_play.png` + `icon_play`. ABANDON RUN is `ui/btn.png` lit red +
  `icon_home`, followed by the "BREAK THE LOOP?" confirm.
- **Motion:** the maze behind desaturates and blurs (code), and the title sign flickers on.

### 4.11 Stage cleared (`widgets/stage_clear_overlay.dart`)
- **Title:** `titles/title_stage_cleared.png` with a gold `fx/fx_burst.png` behind it. At stages 25, 50 and 75,
  `titles/title_checkpoint.png` shows instead, with a bigger burst.
- **Trophy:** `icon_trophy` flies along an arc toward the trophy counter with an `fx_spark` trail, showing +1.
- **Loading:** NEXT STAGE LOADING on `ui/bar_track.png` / `bar_fill.png`.
- **Motion:** the title slams from 1.4 to 1.0 in 180 ms with a 5 dp shake. The burst expands and fades over 0.8 s,
  with the `ui_trophy` chime.

### 4.12 Run failed (`widgets/run_failed_dialog.dart`)
| Cause | Extra art |
|---|---|
| The Devil intercepted you | `chars/devil_scare.png` lunges in for 0.6 s (first death of a session only; skipped with Reduce Flashing), and `icon_devil` |
| The clock hit zero | `icon_timer` in red |
| The floor collapsed | `icon_trap` |

- **Overlay:** `fx/fx_screen_crack.png` over the frozen maze.
- **Title:** `titles/title_cycle_terminated.png`.
- **Stats:** `icon_stage` for LAST SECTOR, `icon_best` for PERSONAL BEST, and the survival % on `bar_*`, plus the
  hearts.
- **Buttons:** EMERGENCY REVIVE is `ui/btn_play.png` lit gold + `icon_revive` + `icon_ad`. CHECKPOINT RESTART is
  `ui/btn.png` + `icon_restart`.
- **Motion:** a 100 ms freeze, then cracks spread from the runner (250 ms), a static burst, the title sputters on,
  and the buttons rise 60 ms apart.

### 4.13 Fear conquered, stage 100 (`widgets/stage_100_win_dialog.dart`)
- **Background:** `bg/bg_victory.jpg` with `fx/fx_godrays.png`.
- **Title and badges:** `titles/title_fear_conquered.png`, with `icon_legend` (LEGEND) and `icon_master` (MASTER).
- **Buttons:** PLAY AGAIN on `ui/btn_play.png`. EXIT TO MENU on `ui/btn.png` + `icon_home`.
- **Motion:** everything turns gold from the centre out (1 s), the rays rotate slowly and gold sparks fall, and the
  title powers on letter by letter.

---

## 5. Brand and store

| File | Where | Type | Generate at |
|---|---|---|---|
| `brand/logo_on.png` | boot, sign-in, dashboard | on black | 3:1, at least 1536×512 (3072×1024 is best) |
| `brand/logo_off.png` | the same logo unlit, for the power-on and flicker | on black, an edit of `logo_on` | same |
| `brand/app_icon.png` | iOS and legacy Android icon, and the Play icon (Claude makes the 512 copy) | full-bleed square, no rounded corners | 1024×1024 |
| `brand/app_icon_fg.png` | Android adaptive icon, foreground | transparent, the subject inside the centre 61% | 1024×1024 |
| `brand/app_icon_bg.png` | Android adaptive icon, background | full-bleed | 1024×1024 |
| `brand/app_icon_mono.png` | Android 13+ themed icon | white on transparent, inside the centre 61% | 1024×1024 |
| `brand/splash_icon.png` | Android 12+ and iOS launch screen | Claude makes it from `app_icon_fg` (1152×1152, inside the centre 768 px circle) | - |
| `store/feature_graphic.jpg` | the Google Play banner | full-bleed, no alpha | 2048×1000, shipped at 1024×500 |

**logo_on.png** (Ideogram or GPT Image)
> The game logo "FEAR FLIP" as a broken horror neon sign: two words side by side with a clear gap between them, bold
> condensed jagged capital letters bent from neon tubes; "FEAR" in toxic green #39FF88, "FLIP" in hot magenta
> #FF2BD6; the tubes held on a thin black chrome rail with small brackets; slightly cracked glass, a drip of black
> grime under two letters, the F of FLIP flickering dimmer; soft neon bloom; centred, wide 3:1; on a pure black
> background, no other text, no watermark.

**logo_off.png**, an edit of `logo_on.png`:
> Same image, every neon tube switched off: dark grey unlit glass tubes, no glow, no bloom; everything else identical.

Claude cuts both at the gap, so FLIP can turn over on its own.

**app_icon.png**
> Mobile game app icon, square 1:1, full-bleed: the face of a horned shadow demon filling the frame, split down the
> middle by a jagged glowing crack, the left half lit toxic-green neon, the right half hot-magenta neon, both eyes
> burning devil red, smoke curling off the horns; bold simple shapes that read at 48 px, high contrast, the face
> inside the central 70%, no text, no letters, no border, no rounded corners, no watermark.

The stores round the corners and add shadows themselves, so leave those out.

**app_icon_fg.png**: the same demon face cut out on a transparent background, with the head and horns inside the
central 61%. Android masks everything outside its 66 dp safe zone.

**app_icon_bg.png**
> Square black-violet background, soft green neon haze on the left and magenta on the right, a faint glowing maze
> pattern, no subject, no text, no watermark.

**app_icon_mono.png**
> Flat white silhouette of a horned demon head with a crack as a gap down the middle, on a transparent background,
> no shading, no text, no watermark.

**store/feature_graphic.jpg**
> Mobile game store banner, wide 2048×1000: a neon maze seen from above, split down the centre by a jagged glitch
> crack; the left half calm, toxic-green neon walls on wet black concrete with a small hooded runner holding a green
> lantern; the right half the same maze flipped to a glowing magenta floor with black walls, a huge horned shadow
> demon with red eyes reaching across the crack; the top-centre third darker and simpler for the logo; nothing
> important within 60 px of the edges. + STYLE

Claude places `logo_on.png` on it. Google Play needs 1024×500, JPG or 24-bit PNG, with no alpha.

**Screenshots** are taken from the game once the art is in, then given a one-line caption on top:
1. The dashboard.
2. The WAKE maze with the Devil closing in.
3. The flip to NIGHTMARE, mid-glitch.
4. A floor collapsing.
5. STAGE CLEARED.
6. The leaderboard.

Google Play takes up to 8 at 1080×1920. The long side can be at most twice the short side, so 1080×2400 is rejected.
Don't put device frames on them. The App Store's 6.9" size is 1320×2868.

---

## 6. Backgrounds and key art

| File | Where | Type | Generate at | Tier |
|---|---|---|---|---|
| `bg/dash_bg.jpg` | dashboard | full-bleed | 1152×2048 | 1 |
| `bg/dash_bg_off.jpg` | dashboard blackout and flicker | an edit of `dash_bg` | same | 2 |
| `bg/dash_devil.png` | dashboard apparition | on black | 1536×1536 | 1 |
| `bg/dash_runner_sentinel.png`, `_phantom.png`, `_void_ripper.png` | the picked runner on the dashboard | transparent | 1024×1536 | 2 |
| `bg/bg_gate.jpg` | sign-in, privacy page, loading | full-bleed | 1152×2048 | 1 |
| `bg/bg_play.jpg` | behind the maze, WAKE | full-bleed | 1152×2048 | 1 |
| `bg/bg_play_nightmare.jpg` | behind the maze, NIGHTMARE | an edit of `bg_play` | same | 2 |
| `bg/bg_leaderboard.jpg` | leaderboard | full-bleed | 1152×2048 | 2 |
| `bg/bg_victory.jpg` | stage 100 | full-bleed | 1152×2048 | 2 |
| `chars/devil_scare.png` | run failed, caught | on black | 1536×2048 | 2 |

**dash_bg.jpg** (T-SCENE)
> SUBJECT: a vast labyrinth of black stone corridors seen from high above at a steep angle, the top of every wall
> lined with glowing toxic-green neon tubes (a few broken and dark), the corridors receding into black fog toward a
> far doorway of devil-red light; wet floors mirroring the neon; two or three hot-magenta glitch scars across the
> maze; drifting smoke. LAYOUT: the top 20% dark sky and fog (the logo sits there); the red doorway at about 30% of
> the height; the middle third the most detailed; the bottom 45% darker and calmer (the buttons sit there). No
> characters, no creature. + STYLE

**dash_bg_off.jpg**, an edit:
> Same image, every neon light switched off: tubes dark grey glass, no neon reflections, only the red doorway faintly
> lit; everything else identical.

**dash_devil.png** (on black)
> The head, horns and shoulders of a colossal shadow demon rising out of darkness, made of black smoke, two huge
> curved horns, burning devil-red eyes and thin red glowing cracks across its face, lit from behind by hot-magenta
> haze so its outline, horns and smoke glow while the inside of the silhouette stays dark, front view from slightly
> below, painted, on a pure black background, no text, no watermark.

Claude cuts the eyes out into `dash_devil_eyes.png` for the blackout beat.

**dash_runner_<id>.png** (transparent, one per runner; the runners are described in §11)
> The {RUNNER} seen from behind at a slight angle, standing at the edge of a stone ledge looking down over a neon
> maze, full body, {THEIR LIGHT} in hand, rim-lit by green neon from below and magenta from the side, painted like a
> horror poster, isolated on a transparent background, no ground, no text, no watermark.

**bg_gate.jpg** (T-SCENE)
> SUBJECT: the end of a long dark concrete corridor, a heavy steel door slightly open with devil-red light spilling
> through the gap, a blank glowing green neon sign box above the door (no letters), puddles reflecting the light,
> claw scratches on the walls, low smoke on the floor. LAYOUT: the door in the upper middle; the bottom half darker
> (the sign-in panel sits there). No characters. + STYLE

**bg_play.jpg** (T-SCENE)
> SUBJECT: a dark surveillance room seen from the operator's chair: a wall of dead monitors and hanging cables, tiny
> green standby lights, the edge of a dusty console at the bottom. LAYOUT: everything very dark and soft so a bright
> square maze screen placed over the middle (90% of the width, centred at 45% of the height) stands out; the bottom
> 20% is the console where the joystick sits. Nothing readable on any screen. + STYLE

**bg_play_nightmare.jpg**, an edit:
> Same room flooded with hot-magenta light, the cables swollen like veins, the dead monitors cracked; everything else
> identical.

**bg_leaderboard.jpg** (T-SCENE)
> SUBJECT: a dark control-room wall covered top to bottom in old CRT monitors, most showing static, a few showing a
> red horned silhouette, one in the upper centre glowing gold; cables hanging; green and magenta haze. LAYOUT: the
> middle 70% of the height darker (the ranking list sits there). + STYLE

**bg_victory.jpg** (T-SCENE)
> SUBJECT: the neon labyrinth from high above at dawn, every neon tube turning warm gold, a pillar of white-gold light
> rising from the exit at the centre, the demon's smoke breaking apart into sparks at the edges, the sky opening from
> black-violet to pale gold at the top. LAYOUT: the middle third calmer (the title and buttons sit there). No
> characters. + STYLE

**devil_scare.png** (on black)
> The face of a horned shadow demon lunging straight at the viewer, mouth open in a silent scream, burning devil-red
> eyes, clawed hands reaching toward the camera from the bottom corners, black smoke whipping back, lit by red neon
> from below and magenta from behind, close-up, portrait 3:4, painted, on a pure black background, no gore, no blood,
> no text, no watermark.

---

## 7. UI kit

All of these use T-PLATE with a transparent background unless the row says otherwise. Claude makes each
`*_glow.png`.

| File | Where | Shown at (dp) | Generate at | Tier |
|---|---|---|---|---|
| `ui/panel.png` | every dialog (stretches in 9 parts; detail in the corners only) | 340 × 260-620 | 1024×1024 | 1 |
| `ui/panel_header.png` | the title strip on top of a panel | 300×56 | 1536×288 | 1 |
| `ui/divider.png` | under titles, between sections | 280×10 | 1600×64 (T-FX, pale on black) | 1 |
| `ui/btn_play.png` | START SURVIVAL, RESUME, REVIVE, BUY, PLAY AGAIN | 300×84 | 1536×432 | 1 |
| `ui/btn.png` | every other button | 300×56 | 1536×288 | 1 |
| `ui/tile.png` | dashboard 2×2, control scheme picker | 170×110 | 1024×672 | 1 |
| `ui/btn_round.png` | pause, close, back | 48×48 | 512×512 | 1 |
| `ui/pill.png` | HUD numbers, trophies, rank, toasts, stage name | 110×38 | 1024×352 | 1 |
| `ui/row.png` | leaderboard and settings rows | 350×64 | 1536×288 | 1 |
| `ui/bar_track.png` | timers, sliders, loading, survival % | 280×10 | 1600×96 | 1 |
| `ui/bar_fill.png` | inside the track | 280×10 | 1600×96 (T-FX, pale on black) | 1 |
| `ui/maze_frame.png` | around the maze (square, never stretched) | 360×360 | 2048×2048 | 1 |
| `ui/joy_base.png` | joystick ring | 140×140 | 1024×1024 | 1 |
| `ui/joy_knob.png` | joystick knob | 60×60 | 512×512 | 1 |
| `ui/dpad_btn.png` | arrow pad key (one file, rotated 4 ways) | 56×56 | 512×512 | 1 |
| `ui/slider_knob.png` | slider knob, and the knob of `toggle.png` | 28×28 | 256×256 | 2 |
| `ui/toggle.png` | settings switch housing | 56×32 | 512×288 | 2 |
| `ui/check_box.png` | policy checkbox on sign-in (the check is glyph 5 of sheet A) | 28×28 | 256×256 | 2 |
| `ui/avatar_ring.png` | player initials, podium | 44×44 | 512×512 | 2 |
| `ui/card_frame.png` | runner cards | 110×150 | 900×1200 | 2 |
| `ui/podium.png` | leaderboard top 3 | 340×150 | 1536×672 | 2 |
| `ui/ad_rail.png` | above the banner ad | 390×6 | 1600×64 | 3 |

The {SUBJECT} for each, to paste into T-PLATE:
- **panel**: *a large near-square dialog frame with angular cut corners, the glass about 85% opaque and very dark,
  the detail only in the four corners*
- **panel_header**: *a wide header strip with angled ends and two small vents, the neon tube along its bottom edge,
  a plain dark centre for a title*
- **divider** (T-FX, pale): *a thin horizontal neon line, brightest in the middle and fading to both ends, one
  small glitch break off-centre, a tiny diamond at each end, white*
- **btn_play**: *a wide angular plate with sharp chamfered ends shaped like arrowheads, a short horn-like spike on
  each outer end, claw scratches across the chrome, a thick neon tube*
- **btn**: *a slim horizontal button plate with chamfered ends and a plain dark centre*
- **tile**: *a 3:2 rectangular plate with cut corners and a hex screw in each corner*
- **btn_round**: *a round button plate, the neon tube a full circle, a plain dark centre*
- **pill**: *a slim capsule plate with rounded ends and a tiny hex screw in each end*
- **row**: *a long row plate with a small angled tab on the left end, the neon tube along the bottom edge only*
- **bar_track**: *a thin long groove of black chrome with a dark glass bottom and small angled end caps, no neon
  tube*
- **bar_fill** (T-FX, pale): *a thin long bar of white neon light, even along its whole length, rounded ends, soft
  bloom*
- **maze_frame**: *a square surveillance-monitor bezel seen straight on: a thick black chrome frame with rounded
  inner corners, four corner brackets with hex screws, a tiny round red recording light in the top-left corner (the
  only thing that isn't symmetrical), faint hazard stripes on the bottom edge, grime and scratches, the screen area
  completely transparent*
- **joy_base**: *a round dial ring with eight short tick marks around the rim, the neon tube as a ring, a dark
  smoked-glass centre*
- **joy_knob**: *a glossy black glass orb knob in a thin chrome rim, a small bright white core*
- **dpad_btn**: *a square key cap with cut corners, an upward arrow drawn as a white neon tube in its face*
- **slider_knob**: *a small round black glass knob with a chrome rim, the neon tube as a ring*
- **toggle**: *a small horizontal slide-switch housing with an empty track, the neon tube along the track*
- **check_box**: *a small square checkbox with a dark glass well*
- **avatar_ring**: *a round ring frame for a profile picture, the neon tube with one small gap at the top right, the
  centre completely transparent*
- **card_frame**: *a portrait 3:4 frame for a character card with angular cut corners and a plain name-plate slot
  across the bottom, the picture area completely transparent*
- **podium**: *three stepped plinths seen from the front, the middle one tallest, each with a smoked-glass face and
  a neon tube along its top edge*
- **ad_rail**: *a thin long rail with a hex screw at each end, the neon tube along its top edge*

Claude tints each glow by what the button does: green = go, gold = reward or money, red = destructive, magenta =
flip or nightmare, white = neutral.

---

## 8. Icons: four sheets

Each sheet is one image with the icons in a grid, and Claude slices it. Making a whole set in one generation keeps
it consistent. Generate a 4×3 sheet at 4:3 (for example 2048×1536) and a 3×2 sheet at 3:2. If your tool only offers
other sizes, that's fine, because Claude cuts each icon to its own bounds. If one icon fails, redo just that one with
T-ICON and attach the sheet as a reference.

Shared start of every sheet prompt:
> A sheet of {N} game UI icons in a {COLS}×{ROWS} grid, each icon centred in its own square cell with clear empty
> space between cells, all in exactly the same style, light and outline weight: neon horror mobile game icons, bold
> simple silhouettes that read at 24 px, glossy black chrome bodies with a glowing neon edge light in the colour
> given for each and a soft halo, one small glitch offset on each, isolated on a transparent background, no text, no
> letters, no numbers, no watermark. Left to right, top to bottom:

**Sheet A: `icons/icons_glyphs.png`** (12 icons, 4×3; all white edge light so Claude can tint them by state)
> 1 a play triangle, 2 a pause sign of two thick bars, 3 an X, 4 a left arrow, 5 a check mark, 6 a circular arrow,
> 7 a small house with a door, 8 a speaker with three sound waves, 9 a speaker with an X beside it, 10 four corner
> brackets pointing outward around a small square, 11 an arcade joystick with a ball top, 12 a cross-shaped
> directional pad. All white edge light.

Names: `icon_play`, `icon_pause`, `icon_close`, `icon_back`, `icon_check`, `icon_restart`, `icon_home`,
`icon_sound_on`, `icon_sound_off`, `icon_size`, `icon_joystick`, `icon_dpad`.

**Sheet B: `icons/icons_menu.png`** (12 icons, 4×3)
> 1 a hooded runner's head and shoulders in profile (green), 2 a jagged crown with three spikes (gold), 3 a cog wheel
> with a small eye in its centre (white), 4 a round seal with a bold diagonal slash across a small play-screen
> (gold), 5 a goblet trophy with horned handles (gold), 6 three rising bars with a small skull on the tallest
> (magenta), 7 a shield with a closed eye on it (white), 8 a document with a check mark and a small shield (white),
> 9 a head-and-shoulders silhouette inside a circle (white), 10 a door with an arrow leaving it (white), 11 a trash
> bin with its lid tilted open (red), 12 a circular arrow around a small coin (gold).

Names: `icon_runner`, `icon_leaderboard`, `icon_settings`, `icon_no_ads`, `icon_trophy`, `icon_rank`,
`icon_privacy`, `icon_consent`, `icon_account`, `icon_sign_out`, `icon_delete`, `icon_restore`.

**Sheet C: `icons/icons_game.png`** (12 icons, 4×3)
> 1 a small square maze with one glowing path (green), 2 an hourglass with falling sand (white), 3 a tattered flag
> with a skull finial (gold), 4 a heart made of a red neon tube (red), 5 the same heart as a dead tube of grey glass,
> no glow (grey), 6 a circle split down the middle, left half green and right half magenta, with two arrows chasing
> around it (magenta), 7 a horned demon head with burning eyes (red), 8 a square floor tile split by glowing cracks
> (red), 9 a heart with a circular arrow around it (gold), 10 a film clapperboard with a play triangle (gold), 11 a
> star wearing a small crown (gold), 12 a ring three-quarters full (green).

Names: `icon_stage`, `icon_timer`, `icon_checkpoint`, `icon_heart`, `icon_heart_empty`, `icon_flip`, `icon_devil`,
`icon_trap`, `icon_revive`, `icon_ad`, `icon_best`, `icon_survival`.

**Sheet D: `icons/icons_rank.png`** (6 icons, 3×2)
> 1 a round gold medal with a crown engraved on it, on a short ribbon (gold), 2 the same medal in silver (white), 3
> the same medal in bronze (orange), 4 a horned crown on fire (gold), 5 a skull wearing a laurel wreath (magenta),
> 6 a broken antenna mast with a glitch spark (magenta).

Names: `icon_medal_gold`, `icon_medal_silver`, `icon_medal_bronze`, `icon_legend`, `icon_master`,
`icon_signal_lost`.

**Not generated:** the Google sign-in button and its "G" (use Google's official asset), and any store badges.

---

## 9. Neon titles

All titles use T-TITLE and come on black: the game adds them as light, then flickers them on.

| File | Words | Colour | Where | Tier |
|---|---|---|---|---|
| `titles/title_stage_cleared.png` | STAGE CLEARED | toxic green | stage cleared | 1 |
| `titles/title_cycle_terminated.png` | CYCLE TERMINATED | devil red | run failed | 1 |
| `titles/title_fear_cycle.png` | FEAR CYCLE | hot magenta | pause | 1 |
| `titles/title_checkpoint.png` | CHECKPOINT | gold | stages 25, 50, 75 | 2 |
| `titles/title_fear_conquered.png` | FEAR CONQUERED | gold | stage 100 | 2 |
| `titles/title_global_panic.png` | GLOBAL PANIC | hot magenta | leaderboard | 2 |

These are the words the game already uses. Generate at 2048×512, make 4 or more, and keep the one that's spelled
right. The other screen titles (SYSTEM SETTINGS, CHOOSE CHARACTER, REMOVE ADS) are set in Bebas Neue with a code
glow, so they stay editable and translatable.

---

## 10. Maze and maze objects

The maze data puts thin walls on cell edges. So the art is one floor tile per cell, a wall strip along each wall edge
(about 18% of a cell thick), and a post on every grid corner to hide the joints. Claude bakes the floor, walls and
posts into one image per maze and per world, so even 29×29 runs at 60 fps.

| File | Where | Type | Generate at | Tier |
|---|---|---|---|---|
| `maze/floor_wake.png` | every cell, WAKE | T-TILE, opaque | 2048×2048 | 1 |
| `maze/floor_nightmare.png` | every cell, NIGHTMARE | T-TILE, opaque | 2048×2048 | 1 |
| `maze/wall_wake.png` | wall strips, WAKE (rotated for vertical walls) | transparent | 2048×512 | 1 |
| `maze/wall_nightmare.png` | wall strips, NIGHTMARE | transparent | 2048×512 | 1 |
| `maze/post_wake.png` | wall corners, WAKE | transparent | 512×512 | 1 |
| `maze/post_nightmare.png` | wall corners, NIGHTMARE | transparent | 512×512 | 1 |
| `objects/exit_ring.png` | the exit (tinted gold, spinning) | pale on black | 1024×1024 | 1 |
| `objects/exit_core.png` | the exit's centre (pulsing) | on black | 1024×1024 | 1 |
| `objects/safe_ring.png` | safe zones (tinted cyan, spinning) | pale on black | 1024×1024 | 1 |
| `objects/trap_cracked.png` | trap, cracked | transparent | 512×512 | 1 |
| `objects/trap_critical.png` | trap, about to go (pulsing) | on black | 512×512 | 1 |
| `objects/trap_hole.png` | trap, collapsed | transparent | 512×512 | 1 |
| `objects/trap_hairline.png` | trap, hidden (very faint) | transparent | 512×512 | 2 |
| `objects/start_mark.png` | the start cell (tinted dim green) | pale on black | 512×512 | 2 |
| `maze/decals.png` | a 4×2 sheet of floor details for dead ends and corners | transparent | 2048×1024 | 3 |

Prompts:
- **floor_wake** (T-TILE): *dark wet concrete slabs with thin dark seams, near-black charcoal with a faint
  blue-green tint, small puddles and grime catching soft toxic-green reflections, low contrast and calm so thin
  glowing walls drawn over it stand out*
- **floor_nightmare** (T-TILE): *nightmare floor tiles, each lit from inside with hot magenta-pink light like a
  cursed dance floor, dark violet veins and thin black cracks crawling across them, the brightness a little uneven
  from tile to tile, bright overall so black walls drawn over it stand out hard*
- **wall_wake**:
  > The top of a maze wall seen straight from above, a long horizontal strip 4:1: a straight glowing toxic-green neon
  > tube in a narrow black chrome rail with a small bracket every quarter, slightly dirty glass, even brightness along
  > the whole length, tiles seamlessly left to right, isolated on a transparent background, no text, no watermark.
- **wall_nightmare**:
  > The top of a maze wall seen straight from above, a long horizontal strip 4:1: a beam of matte black void that
  > swallows light, a thin hot-violet rim light along both long edges, tiny glitch pixels flaking off, even along the
  > whole length, tiles seamlessly left to right, isolated on a transparent background, no text, no watermark.
- **post_wake**:
  > A small square junction box seen straight from above where neon wall tubes meet: black chrome, four short tube
  > stubs, one green neon dot in the centre, isolated on a transparent background, no text, no watermark.
- **post_nightmare**:
  > The same junction seen from above, made of black void with a violet rim and a tiny red ember in the centre,
  > isolated on a transparent background, no text, no watermark.
- **exit_ring** (T-FX, pale): *a circular portal ring seen from above: three concentric broken neon arcs with small
  glitch notches and tiny tick marks, white*
- **exit_core** (T-FX): *a swirling vortex of gold and white light seen from above, spiralling down into a bright
  shaft, sparks flying outward*
- **safe_ring** (T-FX, pale): *a protective ward circle seen from above: a double ring of thin white neon lines, a
  simple open eye in the centre, four small triangles pointing inward, soft halo*
- **trap_cracked**:
  > A square floor slab seen from above, broken by a web of dark cracks, a few chips missing, a faint red glow deep
  > inside the cracks, isolated on a transparent background, no text, no watermark.
- **trap_critical** (T-FX): *glowing devil-red cracks splitting a square floor slab into five pieces, seen from
  above, white-hot inside the cracks, small sparks*
- **trap_hole**:
  > A square hole where a floor slab fell away, seen from above: broken jagged concrete edges, a bottomless black shaft
  > with a faint red glow and falling dust far below, isolated on a transparent background, no text, no watermark.
- **trap_hairline**:
  > A few very faint hairline cracks across a square patch of dark concrete seen from above, almost invisible,
  > isolated on a transparent background, no text, no watermark.
- **start_mark** (T-FX, pale): *a simple ring painted on a floor seen from above, four short tick marks pointing
  inward and a small chevron pointing up, thin white neon lines*
- **decals** (+ STYLE):
  > A sheet of 8 top-down floor details in a 4×2 grid on a transparent background, dark and low contrast: a smeared
  > handprint, claw scratches, a broken neon tube lying on the floor, scattered torn paper, a cracked skull, wet
  > footprints, a dark stain, a spray-painted arrow with no letters. No text, no watermark.

---

## 11. Characters

### 11.1 The four
The names stay as the code has them.

| ID (code prefix) | Who | Silhouette (must read at 32 px) | Neon colour | Glowing accent |
|---|---|---|---|---|
| `sentinel` (Steel Sentinel, the default) | a compact survivor in scratched black riot armour with steel-blue plates | round helmet, broad shoulder plates | ice blue `#9FE6FF` | the visor slit and a shoulder lamp |
| `phantom` (Green Phantom) | a slender hooded wanderer in a long tattered black cloak, no face, only two glowing eyes | tall pointed hood, flared cloak | toxic green `#39FF88` | a cage lantern of green ghost fire |
| `void_ripper` (Void Ripper) | a lean runner in a black high-collar jacket with violet seams, short white hair, a half-mask and a long violet scarf | twin short curved blades, trailing scarf | electric violet `#8A2BFF` | the blades |
| `devil` (the Devil) | a tall hunched shadow demon of black smoke and cracked obsidian skin | two huge curved horns, long arms with hooked claws, a body that trails into smoke | devil red `#FF2A2A` | burning eyes and red cracks |

### 11.2 Sheets
| File | Layout | Made with | Tier |
|---|---|---|---|
| `chars/sentinel_sheet.png`, `phantom_sheet.png`, `void_ripper_sheet.png`, `devil_sheet.png` | 7 columns × 3 rows, 256×256 per cell (1792×768). The rows are walking **down** (toward the camera), **up** and **right**; left is right mirrored. Column 1 is an idle stand and columns 2-7 are a 6-frame walk. Same scale and the same feet line (80% of the cell) in every cell. | a base image + an animation tool | 1 |
| `chars/devil_rise_sheet.png` | 8 × 1, 256 per cell: rising out of a red rift in the floor, its eyes igniting in the last two frames | a video, or the animation tool | 3 |

How to make a sheet:
1. Make the **base image** with T-SPRITE, using the SUBJECT, colour and accent from §11.1 and the POSE *standing,
   facing the camera*. Approve this one image after checking it at 32 px on both floors.
2. **Animate it** in AutoSprite or Ludo.ai: a 6-frame walk cycle in 4 directions (export down, up and right; left
   is mirrored). Export the frames.
3. Drop the frames in `assets/new_assets/<id>_frames/`. Claude aligns the pivots and packs the sheet.

If the tool can't animate it well, 3 frames per direction is enough (idle, left step, right step). The code adds a
bob, a foot-strike squash and a small lean.

The full base prompt for the default runner:
> Game sprite for a top-down maze game, seen from above at a 3/4 angle (camera about 35° from straight down): a
> compact survivor in scratched black riot armour with steel-blue plates, a rounded helmet with a narrow glowing
> visor slit and a small shoulder lamp, standing, facing the camera, full body, a big readable silhouette that still
> reads when shrunk to 32 px, dark body with a thick dark outline, a bright ice-blue neon rim light and one glowing
> accent (the visor slit), clean painted shading, centred, feet at 80% of the image height, isolated on a
> transparent background, no ground, no shadow, no text, no watermark.

The Devil's base pose: *hunched forward mid-stride, claws reaching*.

### 11.3 Portrait cards (Choose Runner)
`chars/card_sentinel.png`, `card_phantom.png` and `card_void_ripper.png` (Tier 2), 900×1200, full-bleed:
> Neon horror game character portrait card, painted like a horror movie poster, 3:4 portrait: {SUBJECT}, from the
> waist up, three-quarter view, looking toward the viewer, a {COLOUR} neon rim light from behind and a hot accent
> light on {ACCENT}, dark smoky background with {COLOUR} haze, the face and the glowing accent in the upper half, the
> bottom fifth dark (a name plate sits there), no text, no frame, no watermark.

Until the cards exist, each card shows the runner's idle frame, enlarged.

---

## 12. Effects

These use T-FX.

| File | Where | Type | Generate at | Tier |
|---|---|---|---|---|
| `fx/fx_spark.png` | motes, trophy trail, sparks | pale on black | 256×256 | 1 |
| `fx/fx_smoke.png` | the Devil's trail, dust, blackout | pale on black | 512×512 | 1 |
| `fx/fx_burst.png` | behind STAGE CLEARED, purchase, revive | pale on black | 2048×683 | 1 |
| `fx/fx_edge_veins.png` | flip warning (magenta); Devil near and low time (red) | pale on black | 1152×2048 | 1 |
| `fx/fx_ring.png` | flip shockwave, safe-zone flash | pale on black | 1024×1024 | 2 |
| `fx/fx_static.png` | flip glitch, Signal Lost, blackout | grey, seamless (not on black) | 512×512 | 2 |
| `fx/fx_screen_crack.png` | run failed | pale on black | 1152×2048 | 2 |
| `fx/fx_fog.png` | dashboard, victory (scrolling) | pale on black | 2048×512 | 2 |
| `fx/fx_rift.png` | where the Devil comes up | on black | 1024×1024 | 2 |
| `fx/fx_godrays.png` | stage 100, the exit | pale on black | 1152×2048 | 3 |
| `fx/fx_exit_sheet.png` | animated exit vortex | video → sheet (24 frames, 6×4, 256 each) | - | 3 |

The SUBJECTs:
- **fx_spark**: *one tiny glowing mote with a soft halo and a short motion streak, white*
- **fx_smoke**: *a soft wispy puff of smoke, translucent, white-grey*
- **fx_burst**: *a wide horizontal blast of light, a bright white core, rays and sparks shooting left and right, an
  empty darker band across the middle for words, 3:1*
- **fx_edge_veins**: *glowing veins creeping in from all four edges of a tall 9:16 frame, thick at the edges and
  thinning toward the middle, the whole centre empty black, white*
- **fx_ring**: *a thin bright shockwave ring with a slightly ragged edge and a few sparks, white*
- **fx_static** (not on black): *television static, black and white grain, a seamless tileable square, no text*
- **fx_screen_crack**: *shattered glass cracks spreading from a point just above the centre of a tall 9:16 frame,
  like a broken phone screen, thin white crack lines*
- **fx_fog**: *a long band of soft drifting fog, seamless left to right, white-grey, its top and bottom edges fading
  to black*
- **fx_rift**: *a jagged round rift torn in a floor seen from above, glowing devil red, glitch pixels and smoke
  around its edge*
- **fx_godrays**: *soft rays of light fanning down from the top centre, white*
- **fx_exit_sheet** (video prompt): *a swirling vortex of gold and white light seen from above, spiralling down,
  centred, on a pure black background, seamless loop, 2 seconds, locked camera*

**Made in code, no file needed:** neon glow and flicker, the PLAY shine sweep, RGB split, scanlines, tear slices,
shake, count-ups, the glow disc under actors, the safe-zone countdown arc, the falling heart halves, and the
desaturate and blur behind dialogs.

---

## 13. UI sounds (optional, ElevenLabs sound effects)

Your gameplay sounds are already in `assets/audio/`; these are only for the animated UI. Save each as
`assets/audio/ui_<name>.mp3`.

| File | Prompt |
|---|---|
| `ui_tap` | a short glassy click with a tiny electric buzz, like tapping a neon sign, dry, 0.15 seconds |
| `ui_open` | a quick rising electric hum with a soft glitch stutter, a panel powering on, 0.5 seconds |
| `ui_close` | a quick falling electric hum powering down, 0.4 seconds |
| `ui_toggle` | a solid mechanical switch clunk with a short neon buzz, 0.3 seconds |
| `ui_tick` | a tiny digital tick, 0.05 seconds |
| `ui_neon_on` | a neon sign flickering on: two buzzing sputters, then a steady hum, 1.5 seconds |
| `ui_blackout` | an electric power failure: a sharp zap, the hum cuts out, a low sub drop, 1 second |
| `ui_trophy` | a bright arcade coin chime over a dark synth swell, 1 second |
| `ui_purchase` | a shimmering gold synth arpeggio rising, 1.2 seconds |
| `ui_error` | a low glitchy buzz, a denial tone, 0.4 seconds |
| `ui_heart_break` | a glass neon tube cracking and shattering, 0.6 seconds |
| `ui_scare` | a distorted demonic screech with a static burst, 0.8 seconds (played quieter than the rest) |

---

## 14. Motion rules (every screen)

These numbers come from the 3D dashboard's tuning, so both games feel equally finished.

| Rule | Value |
|---|---|
| Anything that answers a touch | 180 ms or less, ease-out quint (`Curves.easeOutQuint`) |
| Press | scale 0.96 in 90 ms, glow to 100%, a light haptic, `ui_tap` |
| Stagger | 60 ms on the dashboard, 40 ms in dialogs |
| Enter slide | 24 dp, with a fade |
| Dialog open / close | 200 ms in (0.94 → 1.0), 150 ms out |
| Ambient motion (drift, fog, breathing) | slow sine, 4-26 s cycles |
| Titles | a slam from 1.4 to 1.0 in 180 ms with a 5 dp shake, or a neon power-on |
| Numbers | count up over 500 ms with `ui_tick` |
| PLAY shine | one sweep every 2.5 s |
| Neon flicker | random dips, never more than 2 per second |
| **Reduce Motion** (add to Settings) | no drift, parallax, shake or slides; fades only |
| **Reduce Flashing** (add to Settings) | no white flip frame, blackouts, static bursts or jump scare |

---

## 15. Order of work

**Tier 1, the launch look: 53 images, plus 3 free fonts.**
- Fonts: Bebas Neue, Rajdhani, Share Tech Mono.
- Brand and store (7): `logo_on`, `logo_off`, the 4 app icon files, the feature graphic.
- Backgrounds (4): `dash_bg`, `dash_devil`, `bg_gate`, `bg_play`.
- UI kit (15): `panel`, `panel_header`, `divider`, `btn_play`, `btn`, `tile`, `btn_round`, `pill`, `row`,
  `bar_track`, `bar_fill`, `maze_frame`, `joy_base`, `joy_knob`, `dpad_btn`.
- Icons: the 4 sheets.
- Titles (3): `title_stage_cleared`, `title_cycle_terminated`, `title_fear_cycle`.
- Maze and objects (12): both floors, both walls, both posts, `exit_ring`, `exit_core`, `safe_ring`,
  `trap_cracked`, `trap_critical`, `trap_hole`.
- Characters: the 4 character sheets.
- Effects (4): `fx_spark`, `fx_smoke`, `fx_burst`, `fx_edge_veins`.

Approve the anchors first (the logo, `btn_play`, icon sheet A, the Sentinel base image, `floor_wake`), then use them
as references for everything else.

**Tier 2: 27 images.**
- Backgrounds (8): `dash_bg_off`, the 3 dashboard runners, `devil_scare`, `bg_play_nightmare`, `bg_leaderboard`,
  `bg_victory`.
- UI kit (6): `slider_knob`, `toggle`, `check_box`, `avatar_ring`, `card_frame`, `podium`.
- Titles (3): `title_checkpoint`, `title_fear_conquered`, `title_global_panic`.
- Objects (2): `trap_hairline`, `start_mark`.
- Characters: the 3 runner cards.
- Effects (5): `fx_ring`, `fx_static`, `fx_screen_crack`, `fx_fog`, `fx_rift`.

**Tier 3:** `decals`, `fx_godrays`, `fx_exit_sheet`, `devil_rise_sheet`, `ad_rail`, and the UI sounds.

Once files land, Claude wires one screen per session, in this order:
1. The maze and the characters.
2. The HUD and the controls.
3. The dashboard.
4. Run failed, stage cleared and pause.
5. Settings, the runner picker and Remove Ads.
6. The leaderboard.
7. Sign-in.

---

## 16. Check each file before you send it

- [ ] It's the right type (transparent, on black, pale on black or full-bleed), as its row says. Transparent files
      show a checkerboard behind them in an image viewer.
- [ ] There's no text, letters or numbers (except titles and the logo), and no watermark.
- [ ] Characters and icons: shrink them to 32 px (icons to 24 px) and look again. Are they still clear?
- [ ] No red on a runner. Danger is red, safe is cyan, reward is gold.
- [ ] Plates: all the detail is in the corners and ends, and the long edges are plain.
- [ ] Floors and walls: lay 3×3 copies side by side and check that no seams show.
- [ ] Sprites: the same size and the same feet line in every frame, lit from the same side.
- [ ] You've noted which tool made it, and its terms allow commercial use.

---

## 17. Notes for the wiring session (Claude)

- **Fallbacks:** load every file with one. `Image.asset(..., errorBuilder: ...)` returns today's widget. Painter
  images use the `rootBundle.load` + `try/catch` pattern already in `game_screen.dart` (`_loadExitPortalSprite`), so
  a missing file never breaks a screen.
- **On black and pale art:** *on black* art draws with `BlendMode.plus`. *Pale* art draws the same way after
  `ColorFilter.mode(colour, BlendMode.modulate)`.
- **`*_glow.png`:**
  1. Mask the white tube pixels in the plate (high value, low saturation) and blur them, giving white on black.
  2. Repaint those pixels in the plate as unlit grey glass.
  3. Draw the glow tinted and added over the plate. It pulses and flickers through its opacity.
- **Plates:** `centerSlice` over the plain middle only.
- **Maze:** when a maze is built or reshaped, bake the floor, walls and posts into one `ui.Image` per world with
  `PictureRecorder`. Each frame then draws that image plus the actors.
- **Sheets:** `drawImageRect` with the frame's source rect, the row chosen from `Direction4`, and left drawn as right
  mirrored (as now). Particles use one `Canvas.drawAtlas` call.
- **Runner colours:** set `_CharacterOption.color` in `fear_flip_app.dart` to the §11.1 neon colours. Void Ripper is
  pink `#E85BDA` there today and becomes violet `#8A2BFF`.
- **Fonts:** the files go in `assets/google_fonts/`, registered as assets, with their OFL licences added to
  `LicenseRegistry`.
- **`pubspec.yaml`:**
  - Replace the old `assets/images/*_frames/`, `landing_hero.png`, `exit_portal.png` and `breaking_trap.png` lines
    with the new folders, and leave `assets/new_assets/` out.
  - Set `flutter_launcher_icons` to `image_path`, `adaptive_icon_background`, `adaptive_icon_foreground` and
    `adaptive_icon_monochrome` with `adaptive_icon_foreground_inset: 0`, since the art already sits in the safe zone.
    Then run `dart run flutter_launcher_icons`.
- **QA:** check each delivery with the create-game-assets scripts (size, alpha, a contact sheet at game scale) before
  wiring it, and look at it in the running game at phone size.
- **Performance:** test on a low-end Android. If a shader (fog, glitch) costs frames, use the image versions.

---

## 18. Research behind this file (Oct 2026)

- **Sprite tools.**
  - PixelLab leads for pixel-art 4- and 8-direction rotation and skeleton animation.
  - AutoSprite turns one image into sheets through a video pipeline and isn't pixel-specific.
  - Ludo makes animated sheets from a prompt, keyframes or a reference video, with 8-direction presets.
  - Scenario's strength is a custom-trained house style.
  - Most of these comparisons are written by the vendors.
  - Sources: [Ludo: best AI sprite generators](https://ludo.ai/compare/best-ai-sprite-generators),
    [Ludo vs PixelLab](https://ludo.ai/compare/ludo-vs-pixellab),
    [Ludo vs AutoSprite](https://ludo.ai/compare/ludo-vs-autosprite),
    [Cinevva guide](https://app.cinevva.com/guides/ai-pixel-art-generators),
    [Sprixen](https://sprixen.com/blog/best-ai-sprite-generators-2026)
- **Image tools.**
  - Recraft builds a custom style from reference images, which suits one consistent icon set.
  - Ideogram has the best text accuracy.
  - GPT Image leads on prompt adherence but needs a background-removal step.
  - Nano Banana Pro wins on edit consistency.
  - Midjourney looks great but is weaker at transparency and at consistent characters.
  - Sources: [Ludo: image generators for game art](https://ludo.ai/compare/best-ai-image-generators-for-game-art),
    [BuildMVPFast, Sept 2026](https://www.buildmvpfast.com/articles/best-llms-2026-guide/image-generation-ai),
    [The Insight](https://www.theinsight.tech/articles/best-ai-image-generators-in-2026-i-tested-nano-banana-pro-vs-midjourney-vs-flux-heres-what-actually-wins)
- **Animated UI in Flutter.**
  - Rive suits interactive, state-driven widgets and has smaller files; Lottie suits timeline playback.
  - Fragment shaders suit ambient effects, but profile them on old devices.
  - Sprite sheets are the most predictable for frame animation inside a game loop.
  - Sources: [Callstack: Lottie vs Rive](https://callstack.com/blog/lottie-vs-rive-optimizing-mobile-app-animation),
    [DEV: Rive vs Lottie 2026](https://dev.to/mascotengine/rive-vs-lottie-which-animation-tool-should-flutter-developers-choose-in-2026-lp5),
    [Impeller shader optimisation](https://flutter.googlesource.com/mirrors/engine/+show/refs/heads/main/impeller/docs/shader_optimization.md)
- **Readable small sprites.**
  - Silhouette first, check at real size, high contrast, few colours, coloured outlines.
  - Sources: [Wayline pixel-art lesson](https://www.wayline.io/learn/pixel-art/4),
    [Space Station 14 art guide](https://docs.spacestation14.com/en/space-station-14/art.html),
    [Valve: art that serves gameplay](https://www.gamedeveloper.com/art/in-depth-how-valve-makes-art-to-enhance-gameplay)
- **Neon mazes and neon horror.**
  - Pac-Man CE DX's neon came from fluorescent LCD handhelds, and its mazes always show a clear path.
  - In Hotline Miami, players read neon as a warning; Katana Zero puts neon in grimy, threatening places.
  - Matching the logo's glow to the menu's neon makes a title screen read as one piece.
  - Sources: [Wikipedia: Pac-Man CE DX](https://en.wikipedia.org/wiki/Pac-Man_Championship_Edition_DX),
    [Michigan Daily review](https://www.michigandaily.com/uncategorized/pac-man-championship-edition-review/),
    [GearVN: neon games](https://gearvn.com/blogs/cong-nghe/top-10-the-gioi-game-sieu-dep-ruc-chay-anh-den-neon-day-me-hoac/),
    [Forbes México: Katana Zero](https://forbes.com.mx/?p=575410),
    [Ulster title-screen devlog](https://blogs.ulster.ac.uk/kcampbell/2023/05/06/vertical-slice-5/)
- **Horror HUD.**
  - Keep it sparse and glanceable: corners for information that's always there, the centre for alerts.
  - Sources: [Wayline: UI and immersion](https://www.wayline.io/blog/your-ui-is-killing-immersion-fix-it),
    [Virtuall: game UI guide](https://virtuall.pro/blog/game-ui-design)
- **Effects pipeline.**
  - Video → ffmpeg frames → a tiled sheet keeps motion continuous, and additive blending lets glow keep its black.
  - Sources: [Sorceress: sprite generator](https://sorceress.games/blog/ai-sprite-generator-pixel-walk-cycles-idles-and-vfx),
    [mp4tosprite](https://yewlark.itch.io/mp4tosprite)
- **Store and icons.**
  - Play icon: 512×512, 32-bit PNG, under 1 MB. Feature graphic: 1024×500, JPG or 24-bit PNG, no alpha.
  - Play screenshots: up to 8, 320-3840 px, long side at most twice the short side. App Store 6.9": 1320×2868.
  - Android adaptive icon: 108 dp with a 66 dp safe zone. Android 12 splash icon: 288 dp inside a 192 dp circle.
  - `adaptive_icon_monochrome` is in flutter_launcher_icons, and google_fonts uses bundled files before fetching.
  - Sources: [Play Console help](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en),
    [App Radar](https://appradar.com/blog/android-app-screenshot-sizes-and-guidelines-for-google-play),
    [TrySonar: feature graphic](https://trysonar.app/blog/google-play-feature-graphic),
    [The App Launchpad: icon guide](https://theapplaunchpad.com/blog/google-play-app-icon-guidelines/),
    [Screenhance: App Store sizes](https://screenhance.com/blog/app-store-screenshot-dimensions-2026),
    [Android adaptive icons](https://developer.android.com/develop/ui/views/launch/icon_design_adaptive),
    [AndroidX SplashScreen](https://developer.android.com/reference/androidx/core/splashscreen/SplashScreen),
    [flutter_launcher_icons](https://pub.dev/documentation/flutter_launcher_icons/latest/),
    [google_fonts](https://pub.dev/documentation/google_fonts/latest/)
