# FearFlip 3D: hub screen assets (Daily, Altar, Mirror, Bestiary, Archive, Settings)

The dashboard looks finished. The six screens behind it don't: each one is a flat list of text on black
(`main_menu.gd::_open_screen`, `_entry`). This file lists the art they need to look like the two reference shots
(9 Oct 2026, "THE MIRROR" Act Mastery and Challenges): a framed panel over a painted room at full strength, a carved
title, iron rows with framed icons, bars, stars and seals, and icons in place of most of the words.

**This replaces** the "Meta hub" section of `images/menu/PROMPTS.md`. `hub_entry.png` is dropped (the rows below
take its place), the six backgrounds move here, and the bestiary portraits change to 3:4. None of those files had
arrived yet, so nothing is wasted.

**Delivery.** Put each file in **`godot/assets/images/hub/`** under the exact name (or drop it in `new_assets/` and
tell Claude). Every slot keeps today's stand-in until its file exists, so deliver in any order. No 3D models needed.

## What stays as words

Numbers, proper names (challenge, item, beast, act), one-line descriptions and the lore itself (endings, notes,
bestiary pages) stay as text, set in the fonts below. Everything else becomes art: frames, section marks, stats,
states (done, locked, owned, worn, on, off), rewards, sliders and toggles.

## Rules for every file

- **Style line** (add it to every prompt): *dark fantasy horror game art, semi-realistic painterly style, crimson red
  + deep violet + ember orange, blackened iron and worn gold-bronze, volumetric haze, no text, no UI, no watermark.*
- **Transparent PNG** unless the file says *full-bleed*. If your tool can't do transparency, use a background remover.
  Files marked **(on black)** are glow: paint them on pure black, and Godot adds them so the black disappears.
- **(pale)** = paint the glow white or pale gold. Godot tints it: red for focus, gold for done, the act's colour on act
  rows.
- **Generate at** the size given, or bigger at the same aspect. Claude makes the ship copies (about 2x display size).
- **Frames, bars and plates:** put all the ornament in the ends and corners, and keep the long edges plain and
  straight. Claude keeps the ends as they are and only lengthens the plain middle, so ornate art is never stretched.
  Generate them as wide as your tool allows (3:1 is fine) and crop tight.
- **Icons** are drawn at 32-64 px: one bold subject, a thick dark outline, no fine detail, nothing behind it. Icon
  template:
  > Game UI icon of {SUBJECT}, dark fantasy horror mobile game icon, chunky bold silhouette, thick dark outline,
  > glossy painted highlights, cracked iron and stone with glowing ember seams, centred, isolated on a transparent
  > background, no text, no letters, no watermark.

## 0. Fonts (the single biggest change, and free)

The reference shots use a carved Roman serif (titles, names, numbers) and a book serif (descriptions). Download the
family from Google Fonts and put one `.ttf` in `godot/assets/fonts/` under the name below. The dashboard keeps Oswald.

| File | Font | Used for |
|---|---|---|
| `hub_display.ttf` | **Cinzel** Bold (OFL) | row names, section words, numbers, buttons |
| `hub_body.ttf` | **Cormorant Garamond** SemiBold (OFL) | descriptions and hints |
| `hub_hand.ttf` (optional) | **Special Elite** (Apache 2.0) | notes, endings and bestiary lore: typed 1987 hospital paper |

## Layout at 1280x720 (so each piece comes out the right shape)

- **Every screen:** the room (`bg_<screen>.png`) fills the screen. `panel.png` sits centred at about 1180x690, the
  title plate (520x130) over its top crest, a `divider.png` under the title holding the tab or subtitle words, the
  content area (about 1000x470) inside, and BACK on the bottom edge (`icon_back.png` + the word in Cinzel). Tabs and
  buttons are `btn_plate.png`.
- **Mirror:** two tabs, MASTERY | CHALLENGES. Mastery = the stat bar (`stat_bar.png`, six icons + numbers), then one
  row per act: `badge.png` diamond holding the act sigil (or `menu/act_locked.png`), the act's name, its banner fading
  in from the right, three stars. Challenges = rows with a framed stat icon, name + goal, a bar, the count, the reward
  (shard or item icon) and `seal_done.png` once it's done.
- **Daily:** left column = today's maze (the omen sigil card, the five floor cards as small cards, the big
  `menu/ui_play_button.png` for PLAY RANKED / PRACTICE, then your result squares and a copy button). Right column =
  QUESTS (three rows: stat icon, bar, reward, reroll button), STREAK (seven candles + freezes), CURSED WEEK (card row).
  The countdown uses `hud/icon_wake.png` (the hourglass).
- **Altar:** the shard total top right (`hud/icon_shards.png` + number), five tabs (Omens, Slots, Flashlights, Light,
  Flash) with emblems, then a grid of item cards in `cards/card_frame.png`, the price on a `btn_plate.png` under each
  card (or `seal_done.png` = owned or worn, `menu/act_locked.png` = needs the item before it). The selected card's
  text sits in one strip at the bottom.
- **Bestiary:** left = a 4x2 grid of portrait cards (`bestiary_frame.png` over `beast_<id>.png`, or
  `beast_unknown.png` until met). Right = `journal_page.png` with the selected beast: name, rule, lore and counts.
- **Archive:** two tabs, ENDINGS | NOTES. Endings = six cards (`menu/act_1..5.png` + `ending_true.png`), sealed with
  `wax_seal.png` until read. Notes = a grid of 30 `note_scrap.png` (or `note_missing.png`). The selected one opens on
  `journal_page.png`.
- **Settings:** two columns (SOUND + CONTROLS | DISPLAY + COMFORT). Each row = setting icon, name, then a slider
  (`slider_*.png` + percent) or a lever (`toggle_on/off.png`). The focused row's hint shows once in a footer strip
  instead of under every row.

## 1. Shared chrome: 15 files (every hub screen, How To Survive, later the pause menu)

| File | Shown at | Generate at |
|---|---|---|
| `panel.png` | 1180x690 | 2400x1400 |
| `divider.png` | ~520x26 | 1600x80 |
| `row.png` | 1000 x 72-96 | wide (3:1+), crop tight |
| `row_glow.png` (optional, pale, on black) | over `row.png` | same as `row.png` |
| `badge.png` | 72x72 | 512x512 |
| `icon_frame.png` | 64x64 | 512x512 |
| `bar_track.png` | ~300x18 | wide, crop tight |
| `bar_fill.png` (pale, on black) | inside the track | wide, crop tight |
| `scroll_track.png` | 14 x content height | tall (1:3+), crop tight |
| `scroll_grab.png` | 14x60 | 256x768 |
| `btn_plate.png` | ~220x48 | wide (4:1), crop tight |
| `icon_back.png` | 40x40 | 512x512 |
| `seal_done.png` | 44x44 | 512x512 |
| `star_full.png` / `star_empty.png` | 26x26 | 512x512 |

**panel.png**
> A large ornate gothic frame for a dark fantasy horror game menu, wide landscape: blackened wrought iron with worn
> gold-bronze edging and small thorns; a tall crest at the top centre with two horned skulls and three melted red
> candles around an empty dark medallion; smaller spiked ornaments in the four corners and a short pointed crest at
> the bottom centre; faint red occult sigils etched along the inner border. Inside the frame, a solid very dark
> black-violet panel with a barely visible pentagram pattern. Outside the frame, fully transparent. Perfectly
> symmetrical, front view, the long edges plain between the ornaments, no text, no letters, no watermark.

**divider.png**
> A thin horizontal ornamental divider for a dark gothic game UI: two hairline gold-bronze rules tapering to points
> at the outer ends, a small diamond with a red gem at each end, an empty gap in the middle a third of the width,
> isolated on a transparent background, no text, no watermark.

**row.png** (see the reference shots: dark iron rows with pointed ends)
> A long horizontal row frame for a dark gothic game menu list: blackened iron with a thin worn gold-bronze inner
> edge, pointed arrow-shaped end caps on the left and right, each with a small thorn ornament and one rivet; the top
> and bottom edges are plain straight rails between the caps; inside, a dark translucent black-red fill with a faint
> crimson haze toward the right end. Front view, symmetrical, isolated on a transparent background, no text, no
> icons, no watermark.

**row_glow.png** (optional: Claude can derive it from `row.png`, the way `ui_frame_active.png` was made)
> The same long row frame drawn only as light: a bright white-gold glow tracing the frame's edge, brightest at the
> pointed end caps with small spark flares, soft bloom inward, on pure black, no frame body, no text.

**badge.png**
> A diamond-shaped socket (a square turned 45 degrees) for a game UI: blackened iron with a bevelled gold-bronze rim,
> a small spike at each of the four points, a dark recessed centre where an icon will sit, front view, symmetrical,
> isolated on a transparent background, no text, no watermark.

**icon_frame.png**
> A small square gothic picture frame for a game icon: blackened iron with worn gold-bronze edges, tiny thorns at the
> four corners, a thin dark inner bevel, the centre completely empty and transparent, front view, isolated on a
> transparent background, no text, no watermark.

**bar_track.png**
> A thin horizontal progress bar trough for a dark gothic game UI: a narrow recessed groove in black iron with a fine
> gold-bronze edge and small pointed caps at both ends, the groove plain and straight between them, front view,
> isolated on a transparent background, no text.

**bar_fill.png**
> A thin horizontal bar of glowing molten light, white-gold with a hot core and soft bloom, slightly uneven like
> liquid metal, even along its whole length with rounded ends, on pure black, no text.

**scroll_track.png** and **scroll_grab.png**
> A thin vertical scroll bar rail for a gothic game UI: a narrow black iron rod with gold-bronze edges and a small
> diamond ornament at the top and bottom ends, plain between them, isolated on a transparent background, no text.

> A slim vertical scroll handle: a glowing crimson crystal capsule held in a small black iron clasp, isolated on a
> transparent background, no text.

**btn_plate.png** (PLAY RANKED, PRACTICE, BUY, WEAR, REROLL, COPY, the tabs; the word is drawn by Godot)
> A horizontal button plate for a dark gothic game menu, about four times wider than tall: a dark iron plaque with a
> worn gold-bronze border, pointed hexagonal ends with a small red gem in each, a plain dark centre, a faint red glow
> under the edges, front view, symmetrical, isolated on a transparent background, no text, no letters.

**icon_back.png**: icon template, SUBJECT = *a diamond-shaped iron frame with a bold left-pointing arrowhead inside,
gold-bronze rim*.

**seal_done.png**: icon template, SUBJECT = *a round gold wax-seal medallion with a bold carved check mark, a ring
of small thorns around the rim, warm glow*.

**star_full.png**: icon template, SUBJECT = *a five-pointed star of polished gold metal with a bright glowing core
and a few sparks*.
**star_empty.png**: SUBJECT = *the same five-pointed star as a dark empty socket carved into black stone, only a faint
grey rim, no glow*.

## 2. Titles: 7 files

1536x384, transparent, the words only. These need letters, so use a tool that can spell (Ideogram, GPT image,
Flux). Shown about 520x130.

| File | Words |
|---|---|
| `title_daily.png` | THE DAILY |
| `title_altar.png` | THE ALTAR |
| `title_mirror.png` | THE MIRROR |
| `title_bestiary.png` | THE BESTIARY |
| `title_archive.png` | THE ARCHIVE |
| `title_settings.png` | SETTINGS |
| `title_how_to.png` | HOW TO SURVIVE |

> The words "THE MIRROR" as a dark fantasy horror game title: tall classical Roman capital letters like Trajan or
> Cinzel, cast in aged gold-bronze metal with chipped edges and fine cracks, a thin crimson glow seeping from the
> cracks, a small spiked red occult sigil crest rising behind the middle letters, ornate thin gold flourishes reaching
> out to both sides, a few embers, wide centred composition, transparent background, nothing else in the image, no
> other text, no watermark.

## 3. Backgrounds: 6 files (full-bleed)

`bg_daily.png`, `bg_altar.png`, `bg_mirror.png`, `bg_bestiary.png`, `bg_archive.png`, `bg_settings.png`:
**1920x1080**, shown full screen at full strength (not dimmed to 30% any more). Use the six prompts in
`images/menu/PROMPTS.md` → "Meta hub" (`hub_daily` ... `hub_settings`), with one change: replace "The centre stays
dark and empty..." with *"Full scene, edge to edge. The middle is covered by a menu panel, so put the striking
parts (light sources, the mirror, the altar, the candles) in the left and right thirds."*

## 4. Stat icons: 17 new + 6 reused + 5 act sigils

One icon per counted thing. The same icon serves the Mirror stat bar, every challenge tier on that stat (Claude
gives tiers a bronze, silver or gold frame), the Daily quests and the bestiary counts. All 512x512, icon template.

| File | SUBJECT |
|---|---|
| `stat_best_floor.png` | a steep stone staircase going down into a red glow |
| `stat_floors.png` | a gothic stone archway with a dark doorway |
| `stat_deaths.png` | a cracked skull with red glowing eyes |
| `stat_close_calls.png` | a jagged red heartbeat line across a dark iron disc |
| `stat_phase_dodges.png` | a ghostly ice-blue figure stepping half through a cracked wall |
| `stat_grade_s.png` | a blazing gold medal crowned with flames, no letter on it |
| `stat_acts_clean.png` | one white candle burning untouched inside a ring of salt |
| `stat_act1_no_sprint.png` | two bare footprints in dust with a small feather beside them |
| `stat_gate_s.png` | a demonic stone gate arch with a molten gold sigil |
| `stat_deep_runs.png` | a deep round stone well seen from above, ring after ring down to a tiny red light |
| `stat_cracks.png` | a stone floor tile split by glowing orange cracks |
| `stat_notes.png` | a torn yellowed paper note held to stone by a rusty nail |
| `stat_circles.png` | a glowing blue-white ward circle carved into a stone floor |
| `stat_forced_flips.png` | a cracked clock face twisted like wrung cloth, red light at the edges |
| `stat_devil_escapes.png` | a fleeing figure's silhouette with three red claw slashes missing it |
| `stat_daily_runs.png` | a cracked stone calendar tablet with one day glowing ember red, no numbers |
| `stat_daily_clears.png` | the same calendar tablet with a gold check mark carved over the glowing day |

Reused from `images/hud/` (prompts in `MISSING_ASSETS.md` §0 and §4): flips = `icon_flip.png`, chests =
`icon_chest.png`, keys = `key_icon.png`, curses = `icon_curse.png`, descents = `icon_floor.png`, the Devil =
`icon_devil.png`.

**Act sigils** (inside `badge.png` on the Mirror's act rows, and the icons of the act-clear challenges):

| File | SUBJECT |
|---|---|
| `act_sigil_1.png` | an upright ghostly blue-white dagger, point down |
| `act_sigil_2.png` | a hanging iron cage lantern with a red flame inside |
| `act_sigil_3.png` | a swirling violet spiral vortex |
| `act_sigil_4.png` | a red-hot iron hourglass full of glowing lava |
| `act_sigil_5.png` | a cracked black horned crown with red fire inside |

## 5. Section emblems: 18 files (optional, last)

The mark beside a section word (the red eye on a spiked star in the first reference shot). Without them, the word
sits on the divider alone. All 512x512, shown at 56 px:
> Game UI emblem: {SUBJECT} set on a spiked eight-pointed crimson occult star with a thin gold rim, dark fantasy
> horror mobile game icon, chunky bold silhouette, thick dark outline, glossy painted highlights, centred, isolated
> on a transparent background, no text, no letters, no watermark.

| Screen | File: SUBJECT |
|---|---|
| Daily | `emblem_maze`: a round maze pattern with a red eye at its centre · `emblem_quests`: a rolled scroll with a red wax seal · `emblem_streak`: a single tall candle flame · `emblem_week`: a playing card pierced by an iron nail · `emblem_event`: a blood-red full moon |
| Altar | `emblem_omens`: a glowing violet occult eye sigil · `emblem_slots`: an empty stone socket ring with violet light · `emblem_torch`: a flashlight throwing a beam · `emblem_light`: a glass lens splitting light into colours · `emblem_flash`: two curved arrows chasing around a white flash |
| Mirror | `emblem_mastery`: an open red eye · `emblem_challenges`: two crossed blades over a skull |
| Archive | `emblem_endings`: a spiral stair descending into dark · `emblem_notes`: a torn page on a nail |
| Settings | `emblem_sound`: a cracked church bell · `emblem_controls`: an iron gauntlet hand · `emblem_display`: an eye-shaped lantern with a candle inside · `emblem_comfort`: a softly glowing heart in a ring of thorns |

## 6. Per screen

### Daily: 9 files

| File | Generate at | Prompt |
|---|---|---|
| `daily_sq_clean.png` | 256x256 | icon template: *a square stone tile lit cold blue from within, a calm closed-eye rune carved in it* |
| `daily_sq_chased.png` | 256x256 | *a square stone tile lit red, three claw marks gouged across it* |
| `daily_sq_s.png` | 256x256 | *a square gold tile with a crown of flames carved in it* |
| `daily_sq_died.png` | 256x256 | *a square black cracked tile with a small skull carved in it* |
| `streak_lit.png` | 256x384 | icon template: *a tall red wax candle burning brightly, wax dripping* |
| `streak_out.png` | 256x384 | *the same candle snuffed out, a thin curl of smoke, cold grey wax* |
| `streak_frozen.png` | 256x384 | *the same candle encased in pale blue ice, the flame frozen inside* (a streak freeze) |
| `icon_reroll.png` | 512x512 | icon template: *a bone die inside a circular arrow* |
| `icon_copy.png` | 512x512 | icon template: *a quill pen over a small parchment* |

The four squares replace today's coloured blocks (your result). Reused: `menu/ui_play_button.png`, card art from
`images/cards/`, `hud/icon_wake.png`.

### Altar: 3 files

| File | Generate at | Prompt |
|---|---|---|
| `altar_light_orb.png` (pale) | 512x512 | icon template: *a glass lantern lens with a brilliant white light core and short beams fanning out*. Claude tints it per light colour, so one file covers all of them. |
| `altar_flash_orb.png` (pale, on black) | 512x512 | *a radial white flash burst with a thin ring shockwave, on pure black*. Tinted per flip flash. |
| `altar_slot.png` | 512x512 | icon template: *an empty round stone socket in an iron setting, a faint violet glow rising from it* (OMEN SLOT I and II) |

Reused: `cards/card_frame.png`, `cards/omen_sigils.png`, the flashlight cards (`old_torch`, `lantern`, `uv_light`,
`camera_flash` in `images/cards/PROMPTS.md`), `menu/act_locked.png`, `hud/icon_shards.png`.

### Mirror: 5 files (optional)

`act_banner_1.png` ... `act_banner_5.png`: **1536x512, full-bleed**. They go on the right of each act row. Put the
subject in the right half and let the left half fade to pure black (the act's name sits there). Without them, Claude
crops the act cards.
> Dark fantasy horror game banner, wide 3:1, semi-realistic painterly style: {SUBJECT}, the subject in the right half,
> the left half fading smoothly to pure black, volumetric haze, no text, no UI, no watermark.

| File | SUBJECT |
|---|---|
| `act_banner_1.png` | a cold blue-lit gothic corridor ending in a tall arched doorway |
| `act_banner_2.png` | a hanging iron cage lantern glowing red over burned black ruins |
| `act_banner_3.png` | a violet spiral vortex tearing open a ruined night sky |
| `act_banner_4.png` | a long stone aqueduct bridge burning over a river of lava |
| `act_banner_5.png` | a huge horned demon silhouette before a red, ash-filled sky |

### Bestiary: 11 files

- `beast_devil.png` ... `beast_ripper.png` (8): **now 3:4, 900x1200, full-bleed**, the subject in the upper middle
  (the bottom fifth sits under the nameplate). Subjects as in `images/menu/PROMPTS.md` → "Bestiary portraits"; swap
  "5:3" for "3:4 portrait".
- `beast_unknown.png` (900x1200, full-bleed):
  > A dark shape barely visible behind a torn, bloodstained cloth curtain, only a faint outline of horns or limbs, a
  > cracked red wax seal pinned to the cloth, near-black, volumetric haze, no text, no watermark.
- `bestiary_frame.png` (900x1200):
  > A portrait-shaped gothic picture frame, 3:4: blackened iron with worn gold-bronze edges and small thorns at the
  > corners, a plain empty nameplate bar across the bottom, the picture area completely transparent, front view,
  > symmetrical, isolated on a transparent background, no text, no watermark.
- `journal_page.png` (1200x1600; also used by the Archive and the act ending page):
  > A single aged paper page from an old hospital journal, 3:4: yellowed paper with coffee rings and a faint dried
  > blood smudge in one corner, torn and curled edges, faint ruled lines, the centre plain and evenly lit for text,
  > front view, isolated on a transparent background, no writing, no text, no watermark.

### Archive: 4 files

| File | Generate at | Prompt |
|---|---|---|
| `ending_true.png` | 1024x1536, full-bleed | *a stone stairwell opening onto a pale dawn sky, the maze tiny and far below, the first light touching the top step*, card style like `menu/act_<n>.png` |
| `wax_seal.png` | 512x512 | icon template: *a cracked red wax seal stamped with a horned skull, a torn black ribbon under it* |
| `note_scrap.png` | 600x800 | *a torn scrap of yellowed paper held up by a rusty nail at the top, plain centre, transparent outside the paper, no writing* |
| `note_missing.png` | 600x800 | *a rusty nail in dark stone with only a tiny torn corner of paper still caught on it, transparent background* |

### Settings: 14 files

Setting icons (512x512, icon template):

| File | SUBJECT |
|---|---|
| `set_master.png` | a cracked church bell |
| `set_music.png` | an antique music box with its lid open and a red glow inside |
| `set_effects.png` | an ear carved in pale stone with three red sound ripples |
| `set_sensitivity.png` | an eye inside two crosshair rings |
| `set_invert.png` | two thick arrows, one up and one down, swapping places |
| `set_brightness.png` | a candle with a tall bright flame and rays |
| `set_fullscreen.png` | four iron corner brackets around a glowing empty frame |
| `set_flashing.png` | a lightning bolt struck through by an iron bar |
| `set_motion.png` | a spiral struck through by an iron bar |

Controls:

| File | Generate at | Prompt |
|---|---|---|
| `slider_track.png` | wide, crop tight | same as `bar_track.png` but thinner and darker (or skip it and Claude uses `bar_track.png`) |
| `slider_fill.png` (pale, on black) | wide, crop tight | same as `bar_fill.png` (or skip it and Claude uses `bar_fill.png`) |
| `slider_knob.png` | 256x256 | icon template: *a diamond-shaped crimson gem knob set in a black iron claw setting* |
| `toggle_on.png` | 512x256 | icon template: *an iron lever switch plate, the lever thrown up, a round red rune lamp glowing above it* |
| `toggle_off.png` | 512x256 | *the same switch plate, the lever thrown down, the rune lamp dark and cold grey* |

The levers replace the ON / OFF words.

## 7. Other pages that still look unfinished

1. **How To Survive** (dashboard): plain text on black. Covered by the shared chrome + `title_how_to.png`; the key
   names use the existing `hud/keycap.png` / `keycap_wide.png`, and the rules get stat icons (flips, keys, the
   Devil, descents) and `hud/hint_icons.png` (`MISSING_ASSETS.md` §4).
2. **Act ending page** (in the maze after a Gate, `main.gd::_show_ending`): gold text over a 35% backdrop. Covered by
   `panel.png` + `journal_page.png` + `hub_hand.ttf`; `menu/ending_bg.png` (prompt in `images/menu/PROMPTS.md`)
   stays behind it.
3. **Floor / act cleared titles, grades, the HUD's remaining words**: already prompted in `MISSING_ASSETS.md` §4
   (`title_*.png`, `grades.png`, badges, `hint_icons.png`). None have arrived, and they're the biggest in-game win.
4. Fine as they are: the act picker, the card picker and pick screens, and the death screen (all have their art).
   The pause menu isn't built yet. When it is, it reuses this chrome.

## Order

1. **Makes every screen match the references (27 files):** the 2 fonts, `panel`, the 7 titles, `row`, `divider`,
   `btn_plate`, `icon_back`, `icon_frame`, `badge`, `bar_track` + `bar_fill`, the 2 stars, `seal_done`, the 6
   backgrounds.
2. The stat icons and act sigils (the Mirror then matches both shots), the Settings icons + knob + levers, the Daily
   squares and candles.
3. The Bestiary and Archive pieces, the act banners, the scroll bar, the emblems.

Once files arrive, Claude rebuilds one screen per session (`main_menu.gd::_open_screen` and that screen's `_fill_*`),
in this order: Mirror, Settings, Daily, Altar, Bestiary, Archive. Each slot keeps today's look until its file lands.
