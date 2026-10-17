# FearFlip 3D: every asset still needed (checked 15 Oct 2026)

One file with a ready-to-paste prompt for every asset still missing, in making order: **images first, then sounds,
3D models last**. Put each file at the exact path (relative to `godot/assets/` unless it says otherwise), or drop it in
`godot/assets/new_assets/` and tell Claude, who cuts the ship copy. The game keeps a code stand-in until each file
exists, so any order works.

| Part | What | Files | Shows in the game when dropped in? |
|---|---|---|---|
| A | Images the game already reads | 63 | yes, no code change |
| B | Store and launch art (app icon, portal covers) | 4 | needed to publish; the icon needs one project setting |
| C | Images for planned work | 11 + the hub redesign | no: Claude wires each set first |
| D | Sounds the game already reads | 5 | yes |
| E | Sounds for the new threats (Phantom, Sentinel, Ripper) | 10 | no: they come with the threats |
| F | 3D models the game already reads | 3 | yes |
| G | 3D models for the new threats, plus an optional player redo | 4 | no |

Checked against the code: every path below is either read by a script today (A, D, F) or belongs to planned work
(C, E, G). The end of the file lists old plan items that are **not** needed any more.

## Ground rules

- **Style line** (already inside every prompt below): dark fantasy horror, semi-realistic painterly, crimson red + deep
  violet + ember orange, volumetric fog, no text, no UI, no watermark.
- **Transparent PNG** where it says so. If your tool can't do transparency, use a background remover, or paint on pure
  white and tell Claude.
- **Generate at** the size given (or bigger at the same aspect). Claude makes the smaller ship copy.
- **Words in the picture** (grades, centre titles): use a tool that can spell (Ideogram, GPT image, Flux). Everything
  else has no text at all.
- **Sounds:** ElevenLabs Sound Effects, model `eleven_text_to_sound_v2`, prompt_influence 0.6, loop off unless it says
  "loop on" (the free plan covers it). MP3.
- **3D models:** make a concept image first (plain white background, three-quarter view), then image-to-3D (Meshy /
  Tripo). Low-poly/remesh on, PBR textures at 1K, real-world size, Y-up, pivot at the base centre, export GLB. Keep to
  the triangle budget given (Claude can decimate in Blender if it comes out heavy).

## Priority (what the player notices most first)

1. **HUD icons** `icon_wake`, `icon_nightmare`, `icon_flip`, `icon_floor` (on screen every second of play) and
   `icon_open` (shown at every key box; its stand-in, the gold chest, wrongly hints at the exit).
2. **Sounds** `sfx_devil_roar`, `sfx_wall_slam`, `sfx_wall_break`, `sfx_box_open`, `sfx_box_empty`: the biggest scares
   and the most repeated action still play pitched placeholder sounds.
3. **`key_box.glb`** (3 to 5 boxes on every floor), the **wall numerals** `glyph_1..12` and the **landmark models**:
   the player navigates by them.
4. **Store art** (B): before you submit to CrazyGames.
5. `icon_devil`, `icon_chest`, `icon_shards`.
6. Card pictures, then the Altar item pictures.
7. `ending_bg`, `act_6`, then the hub backgrounds, bestiary portraits, `hub_entry`.
8. C, E and G only once Claude has wired them.

---

# IMAGES

## A1. HUD icons: 8 files, `images/hud/`

**512x512, transparent PNG.** Drawn at 30-40 px, so: one bold subject, thick outline, no fine detail, nothing behind
it. Match the menu icons and `key_icon.png`: glossy, chunky, cracked iron and stone, glowing seams. Until they arrive,
the menu's icons stand in (hourglass, RETRY arrows, maze tile, gold chest, gem, demon).

| File | Where it shows |
|---|---|
| `icon_wake.png` | left of the clock while in WAKE |
| `icon_nightmare.png` | left of the clock while in NIGHTMARE |
| `icon_flip.png` | Flipping Time; must be **round** (the game fills it clockwise like a cooldown) |
| `icon_floor.png` | before the floor count `3/10` (the depth in the Abyss) |
| `icon_chest.png` | after the keys once all are found |
| `icon_shards.png` | before the shard count |
| `icon_devil.png` | top left under the Devil Cam, before its distance; the game tints it amber then red, so keep it pale grey |
| `icon_open.png` | just under the screen centre while a closed key box is in reach; it must **not** look like the exit chest |

**icon_wake.png** and **icon_nightmare.png** are a pair: same frame, same size, same position, so a flip reads as the
eye itself changing.
> Game UI icon of a wide-open human eye set in an almond-shaped frame of cracked grey stone with frosted silver trim,
> the iris glowing cold ice-blue, calm and watchful, a faint blue mist around it, palette of ice blue, steel grey and
> white with no red at all, dark fantasy horror mobile game icon, chunky bold silhouette, thick dark outline, glossy
> painted highlights, front view, centred, isolated on a transparent background, no text, no letters, no watermark.

> The same almond-shaped stone eye frame as a matching game UI icon, now demonic: a bloodshot blood-red eye with a
> vertical slit pupil of molten orange, small curved horns growing from the frame, glowing red cracks in the stone and
> red smoke curling off it, crimson and black palette, dark fantasy horror mobile game icon, chunky bold silhouette,
> thick dark outline, glossy painted highlights, front view, centred, isolated on a transparent background, no text, no
> letters, no watermark.

**icon_flip.png**
> Round game UI emblem for a "flip between two worlds" power: two thick curved arrows chasing each other around a
> circle, the left arrow carved from cold ice-blue stone, the right arrow from molten red cracked iron, a small glowing
> hourglass in the centre where the two colours meet, symmetrical, fills a circle, dark fantasy horror mobile game
> icon, chunky bold silhouette, thick dark outline, glossy painted highlights, front view, centred, isolated on a
> transparent background, no text, no letters, no watermark.

**icon_floor.png**
> Game UI icon of an open square stone trapdoor seen from above, a spiral stone staircase winding down into a deep red
> glow, an iron rim with rivets around the hatch, dark fantasy horror mobile game icon, chunky bold silhouette, thick
> dark outline, glossy painted highlights, centred, isolated on a transparent background, no text, no letters, no
> watermark.

**icon_chest.png**
> Game UI icon of a heavy black iron-bound chest with a horned demon face on the lid, the lid cracked open with molten
> gold light spilling out, three-quarter front view, dark fantasy horror mobile game icon, chunky bold silhouette, thick
> dark outline, glossy painted highlights, centred, isolated on a transparent background, no text, no letters, no
> watermark.

**icon_shards.png**
> Game UI icon of a single jagged violet soul-crystal shard with a glowing lilac core, a wisp of violet smoke trailing
> from its tip, sharp facets with white highlights, dark fantasy horror mobile game icon, chunky bold silhouette, thick
> dark outline, centred, isolated on a transparent background, no text, no letters, no watermark.

**icon_devil.png**
> Game UI icon of a horned demon's head seen from the front, long curved horns, hollow glowing eyes, a thin grin of
> sharp teeth, pale ash-grey skin with bone-white highlights, dark fantasy horror mobile game icon, chunky bold
> silhouette, thick dark outline, glossy painted highlights, centred, isolated on a transparent background, no text, no
> letters, no watermark.

**icon_open.png**
> Game UI icon of a small plain wooden box with its flat lid lifting open and a thin line of pale light escaping from
> the gap, rough dark planks, worn bone and dark wood colours with a faint gold rim light, no metal, no lock, no
> treasure, front view, dark fantasy horror mobile game icon, chunky bold silhouette, thick dark outline, glossy painted
> highlights, centred, isolated on a transparent background, no text, no letters, no watermark.

## A2. Wall numerals: 12 files, `textures/decals/`

`glyph_1.png` … `glyph_12.png` = I, II, III, IV, V, VI, VII, VIII, IX, X, XI, XII. Painted on maze walls at junctions
("right at III"). **512x512, transparent PNG**, about 10% margin. Use the same brush and colour on all twelve. Image
tools often misspell long numerals (VIII, XII): check each one and regenerate any that come out wrong. If one never
comes out right, skip it; the game paints its own stand-in numeral.

Prompt (swap `III` for each numeral):
> The Roman numeral III hand-painted on a wall in thick dark dried-blood red paint with a wide brush, rough uneven
> strokes, drips running down from the bottom of each stroke, a few splatters around it, front view, flat, centred,
> isolated on a transparent background, no wall texture, no shadow, no other text.

## A3. Card pictures: 7 files, `images/cards/`

**880x520 PNG**, no transparency. Shown in a 130 px band at the top of a card, cover-fit: keep the subject centred,
because the top and bottom may be cropped. The same pictures also appear beside the torch in the Altar and in the
Daily screen's event entries.

**old_torch.png** (Altar, starting torch)
> Dark fantasy horror mobile game card art, semi-realistic painterly anime style, wide 880x520: a battered metal
> flashlight lying on wet stone, its cold blue beam cutting across a dark maze corridor, volumetric fog, glowing rim
> light, cold blue with a little ember orange, no text, no UI, no letters, no numbers, no watermark.

**lantern.png** (Altar torch)
> Dark fantasy horror mobile game card art, semi-realistic painterly anime style, wide 880x520: an old brass oil
> lantern held up in a stone maze corridor, a wide warm glow filling the walls but fading fast into the dark, volumetric
> fog, glowing rim light, ember orange and deep violet, no text, no UI, no letters, no numbers, no watermark.

**uv_light.png** (Altar torch)
> Dark fantasy horror mobile game card art, semi-realistic painterly anime style, wide 880x520: a violet UV torch beam
> sweeping a stone maze corridor floor, hidden cracks lighting up bright under it, volumetric fog, glowing rim light,
> deep violet and crimson, no text, no UI, no letters, no numbers, no watermark.

**camera_flash.png** (Altar torch)
> Dark fantasy horror mobile game card art, semi-realistic painterly anime style, wide 880x520: an old instant camera
> mid-flash in a stone maze corridor, a horned silhouette frozen white at the far end of the corridor, volumetric fog,
> glowing rim light, crimson and deep violet, no text, no UI, no letters, no numbers, no watermark.

**cursed_week.png** (all 8 Cursed Week curses)
> Dark fantasy horror mobile game card art, semi-realistic painterly anime style, wide 880x520: a cracked stone calendar
> slab nailed to a maze wall, seven day marks scratched into it, the last one bleeding red, a black candle guttering
> beneath, volumetric fog, glowing rim light, crimson red, deep violet and ember orange, no text, no UI, no letters, no
> numbers, no watermark.

**blood_moon.png** (Halloween event, 24 Oct to 2 Nov: BLOOD MOON, HARVEST)
> Dark fantasy horror mobile game card art, semi-realistic painterly anime style, wide 880x520: a huge blood-red full
> moon over an open-roofed stone maze, jack-o'-lantern faces carved into the wall tops glowing ember orange, red fog
> pooling in the corridors, glowing rim light, no text, no UI, no letters, no numbers, no watermark.

**frozen_nightmare.png** (winter event, 15 Dec to 7 Jan: WHITEOUT, DEEP FREEZE, FROZEN WARDS)
> Dark fantasy horror mobile game card art, semi-realistic painterly anime style, wide 880x520: a maze corridor buried
> in snow and blue ice, icicles hanging from the walls, a frozen safe-circle rune glowing pale cyan under the ice, a
> horned silhouette blurred by a blizzard at the far end, volumetric fog, glowing rim light, no text, no UI, no letters,
> no numbers, no watermark.

## A4. Altar item pictures: 14 files, `images/cards/` (new)

The Altar draws a picture beside every item it sells (`main_menu.gd::_altar_item`), but only the omens (sigil sheet)
and the torches (A3) have one; the beam colours, flip flashes and omen slots show none. **880x520 PNG**, like the
cards. Shown small beside the item (cover-fit, about 5:3), so one clear subject in the centre.

**Beam colours (7 files).** Prompt (swap in the COLOUR from the table):
> Dark fantasy horror mobile game card art, semi-realistic painterly anime style, wide 880x520: a battered flashlight
> held out into a dark stone maze corridor, its beam shining COLOUR, the light pooling on wet stone and fading into
> fog, the beam's colour tints the whole picture, volumetric fog, glowing rim light, no text, no UI, no letters, no
> numbers, no watermark.

| File | COLOUR |
|---|---|
| `cold_light.png` | pale ice blue |
| `ember_light.png` | warm ember orange, like the last of a fire |
| `bone_light.png` | plain white, the colour of old paper |
| `blood_light.png` | blood red |
| `spectral_light.png` | a sickly ghostly green |
| `moonblood_light.png` | deep rose red, with a blood-red full moon above the open maze (Blood Moon event) |
| `frost_light.png` | icy cyan, with frost creeping over the walls (Frozen Nightmare event) |

**Flip flashes (5 files).** Prompt (swap in the COLOUR from the table):
> Dark fantasy horror mobile game card art, semi-realistic painterly anime style, wide 880x520: a stone maze corridor
> caught at the instant reality flips over, the whole view tilting and rolling, a blinding burst of COLOUR light
> flooding out from the centre, chips of stone hanging in the air, volumetric fog, no text, no UI, no letters, no
> numbers, no watermark.

| File | COLOUR |
|---|---|
| `world_flash.png` | ice-blue on the left half and blood-red on the right half |
| `gold_flash.png` | molten gold |
| `void_flash.png` | violet-black, like falling asleep |
| `blood_moon_flash.png` | blood-moon red |
| `frostbite_flash.png` | snow white with glittering ice crystals |

**slot_1.png** (OMEN SLOT I)
> Dark fantasy horror mobile game card art, semi-realistic painterly anime style, wide 880x520: a black stone altar
> slab seen from above at an angle, one empty round socket carved into its centre, faint violet light rising out of
> it, melted red candles at the edges, volumetric haze, no text, no UI, no letters, no numbers, no watermark.

**slot_2.png** (OMEN SLOT II)
> Dark fantasy horror mobile game card art, semi-realistic painterly anime style, wide 880x520: a black stone altar
> slab seen from above at an angle, two round sockets carved side by side, the left one holding a glowing violet sigil
> stone, the right one empty with faint violet light rising out of it, melted red candles at the edges, volumetric
> haze, no text, no UI, no letters, no numbers, no watermark.

## A5. Menu and hub images: 21 files, `images/menu/`

### act_6.png: the Abyss act card (floors 51+)
**Generate 1024x1536 (portrait 2:3)**, ship 400x600. Edge to edge, no frame. Keep the subject in the top 60%; the
bottom 40% sits under a dark gradient with the act name.
> Dark fantasy horror mobile game card art, semi-realistic painterly anime style, portrait 2:3. Looking straight down a
> bottomless square shaft of stone maze walls that repeat forever into darkness, each level a little more broken and
> overgrown with black roots; faint violet glow rising from far below, red eyes blinking open at many depths; a tiny
> survivor on the top ledge peers over the edge with a flashlight, the beam swallowed by the dark. Mood: it never ends.
> Bruised violet, deep black and a little crimson, vertigo perspective, volumetric fog, high detail, no text, no UI, no
> watermark.

### ending_bg.png: behind an act's ending text, after a Gate
**Generate 1920x1080**, ship 1280x720. Shown at 35% opacity; keep the centre very dark and empty.
> Dark fantasy horror game background, semi-realistic painterly anime style, 16:9: looking down a stone stairwell that
> spirals into darkness, lit from far below by a faint red glow; hundreds of tally marks scratched into the wall beside
> the first steps. The centre stays very dark and empty for text. Crimson and charcoal, volumetric haze, no text, no UI,
> no watermark.

### Hub backgrounds: 6 files
`hub_daily.png`, `hub_altar.png`, `hub_mirror.png`, `hub_bestiary.png`, `hub_archive.png`, `hub_settings.png`.
**Generate 1920x1080**, ship 1280x720. Today each is drawn behind a hub screen's list at 30% opacity; the planned hub
redesign (`HUB_ASSET_PROMPTS.md` §3) shows the same picture at full strength. One picture serves both, so the prompts
put the striking parts in the left and right thirds and keep the middle third dark and calm (the text or a menu panel
covers it).

**hub_daily.png**
> Dark fantasy horror game background, semi-realistic painterly anime style, 16:9, full scene edge to edge: a cracked
> stone calendar wall at the heart of a maze, one day carved deeper than the rest and glowing ember red, tally marks and
> old scratched dates fading into the dark around it, a single candle burning on a ledge below. The middle third stays
> dark and calm; the glowing day and the candle sit in the left and right thirds. Ember and violet light, no readable
> text or numbers, no UI, no watermark.

**hub_altar.png**
> Dark fantasy horror game background, semi-realistic painterly anime style, 16:9, full scene edge to edge: a ruined
> chapel at the bottom of a maze, on the left a black stone altar with a cracked offering bowl heaped with glowing
> violet crystal shards, on the right melted red candles under iron chains hanging out of the dark, faint occult sigils
> carved into the floor between them. The middle third stays dark and calm. Crimson, deep violet and ember orange,
> volumetric haze, no text, no UI, no watermark.

**hub_mirror.png**
> Dark fantasy horror game background, semi-realistic painterly anime style, 16:9, full scene edge to edge: an
> abandoned hospital ward corridor with a tall cracked antique mirror standing on the right, its reflection showing the
> same corridor bathed in red, wet walls and a faint horned silhouette far back in it, five small star-shaped candle
> holders on the ornate frame, two of them lit. The middle third stays dark and calm. Cold blue on the near side, blood
> red inside the glass, no text, no UI, no watermark.

**hub_bestiary.png**
> Dark fantasy horror game background, semi-realistic painterly anime style, 16:9, full scene edge to edge: a forgotten
> doctor's study, a rotting corkboard wall covered in pinned sketches and torn pages of monsters with red string between
> them, a tall horned figure drawn in red chalk on the left, specimen jars on a shelf and one flickering desk lamp on
> the right. The middle third stays dark and calm. Ember and violet light, no readable text, no UI, no watermark.

**hub_archive.png**
> Dark fantasy horror game background, semi-realistic painterly anime style, 16:9, full scene edge to edge: a dusty
> hospital records room, tall steel filing cabinets on the left with one drawer pulled open and spilling yellowed
> patient files and handwritten notes, a desk lamp with a weak warm bulb and an old wall calendar half in shadow on the
> right. The middle third stays dark and calm. Warm lamp light and deep violet shadow, no readable text, no UI, no
> watermark.

**hub_settings.png**
> Dark fantasy horror game background, semi-realistic painterly anime style, 16:9, full scene edge to edge: the night
> nurse's station of an abandoned 1980s hospital ward, a wall of old brass dials and toggle switches on the left, one
> switch flipped and its pilot lamp glowing ember red, a dusty valve radio and a desk lamp with a weak warm bulb on the
> right. The middle third stays dark and calm. Warm lamp light and deep violet shadow, no readable text, no UI, no
> watermark.

### Bestiary portraits: 8 files
`beast_<id>.png`. **Generate 900x1200 (3:4 portrait)**, the subject in the upper middle. Today each appears beside its
Bestiary entry once you've met that threat, as a small 5:3 crop (Claude cuts the 240x144 ship copy around the
subject); the hub redesign shows the whole portrait, so one picture serves both. Start every prompt with:
*"Dark fantasy horror game illustration, semi-realistic painterly anime style, 3:4 portrait, the subject in the upper
middle and readable when cropped small, volumetric fog, no text, no UI, no watermark:"* then add the subject.

| File | Subject |
|---|---|
| `beast_devil.png` | a tall patient horned figure standing in a dim red maze corridor, long arms, face in shadow except two burning eyes |
| `beast_nightmare.png` | one corridor split down the middle: a cold blue clean half and a red, wet, veined half |
| `beast_flipping_time.png` | a corridor twisting like a wrung cloth around a cracked clock face, red light pulling at the edges |
| `beast_cracked_floor.png` | stone floor tiles split by glowing orange cracks, one tile gone and embers glowing far below |
| `beast_the_clock.png` | an old hospital wall clock with its hands melting, pale morning light leaking under a closed door |
| `beast_phantom.png` | a pale translucent figure in an old nurse's uniform at the end of a blue corridor, a flashlight beam flickering on it |
| `beast_sentinel.png` | a mechanical searchlight eye in the ceiling sweeping a corridor, a heavy iron eyelid half closed |
| `beast_ripper.png` | ceiling lights dying one by one toward the viewer, a long clawed shape rushing out of the dark |

### hub_entry.png: the frame around each line in the hub screens
**600x120, transparent PNG**, used as-is. It is stretched as a 9-slice with 24 px corners and tinted per line, so all
the detail must sit in the corners and the straight edges must stay plain.
> A horizontal UI panel frame for a dark fantasy horror game, 600x120 PNG with transparency: a thin aged-iron border
> with small rivets and faint engraved runes in the four corners, a very dark translucent black-violet interior (about
> 60% opaque), a faint ember-red glow along the inner edge. Symmetrical; all the detail sits in the 24 px corners and the
> straight edges between them are plain so it stretches cleanly as a 9-slice. No text, no icons, no watermark.

### Long Night medals: 4 files (plans/11, new)
`medal_bronze.png`, `medal_silver.png`, `medal_gold.png`, `medal_devil.png` in `images/menu/`. **Generate 512x512,
transparent PNG**, ship 128x128. Shown on the dashboard's Long Night page at about 58 px, lit once earned that week
(dimmed before), so each must read at a glance. The stand-in is a tinted star (a red demon for DEVIL). Start every
prompt with: *"A single round medal icon for a dark fantasy horror game, 512x512 PNG with transparency, centred and
filling about 80% of the frame, readable at 64 px, a short torn ribbon at the top, rim light, no text, no watermark:"*
then add the medal.

| File | Medal |
|---|---|
| `medal_bronze.png` | worn dark bronze stamped with a simple maze pattern, a dull crimson ribbon, faint ember glow on the rim |
| `medal_silver.png` | tarnished silver stamped with the maze and a small key, a deep violet ribbon, cold blue sheen |
| `medal_gold.png` | polished old gold stamped with the maze and a key, thin cracks leaking warm ember light, a crimson ribbon |
| `medal_devil.png` | blackened iron stamped with a horned skull, molten red light glowing from its cracks, tiny flames licking the rim, a burnt black ribbon |

## B. Store and launch art: 4 files (new)

The game has **no app icon** yet (`project.godot` sets none, so the web build's favicon and every portal tile fall back
to Godot's), and CrazyGames won't take a submission without three covers.

**icon.png** → `godot/icon.png`. **1024x1024, opaque** (no transparency: portals and Android want a filled square).
Claude sets it as the project icon (also the web favicon) and cuts the Android launcher icons from it later.
> Game app icon, square, must read at 48 px: a horned demon's face filling the frame, split straight down the middle,
> the left half cold ice-blue stone with a calm glowing blue eye, the right half blood-red cracked skin with a burning
> slit-pupil eye, a thin line of white light along the split, near-black background, dark fantasy horror, semi-realistic
> painterly, chunky bold shapes, very high contrast, no text, no letters, no border, no watermark.

**CrazyGames covers (3 files).** Their rules: three covers that look like one set, landscape 1920x1080, portrait
800x1200 and square 800x800; the only text allowed is the game's title; no borders, no "New" or "Play now", no icons
or store logos, and not a plain screenshot. So generate them **without text**, and Claude puts the existing
`images/menu/logo.png` on each. Save them outside `godot/` (for example a `store/` folder at the repo root) so the
game never imports them.

**cover_landscape.png** (generate 1920x1080)
> Dark fantasy horror game cover art, semi-realistic painterly anime style, 16:9 landscape: a stone maze corridor split
> straight down the middle into two worlds, the left half cold blue (clean grey stone, pale blue light), the right half
> red nightmare (wet veined walls, red fog, glowing cracks); a huge horned demon's face looms out of the dark exactly on
> the split, its left eye calm ice-blue, its right eye a burning red slit; in the foreground a young survivor with messy
> dark hair, a long red scarf and a flashlight runs toward the viewer, glancing back; dramatic rim light, high
> contrast, reads clearly as a small thumbnail, the top quarter dark and calm for the title, no text, no letters, no
> logo, no border, no watermark.

**cover_portrait.png** (generate 1024x1536, ship 800x1200)
> Dark fantasy horror game cover art, semi-realistic painterly anime style, 2:3 portrait: a huge horned demon's face
> fills the upper half, split straight down the middle, the left half cold ice-blue stone with a calm blue eye, the
> right half blood-red cracked skin with a burning slit-pupil eye; below it a stone maze corridor split the same way,
> blue on the left and red on the right, and a young survivor with messy dark hair, a long red scarf and a flashlight
> running toward the viewer; dramatic rim light, high contrast, a calm dark band at the very top for the title, no
> text, no letters, no logo, no border, no watermark.

**cover_square.png** (generate 1024x1024, ship 800x800)
> Dark fantasy horror game cover art, semi-realistic painterly anime style, 1:1 square: close on a huge horned demon's
> face split straight down the middle, the left half cold ice-blue stone with a calm blue eye, the right half
> blood-red cracked skin with a burning slit-pupil eye and red smoke; a small survivor with a flashlight and a long red
> scarf silhouetted at the bottom centre; dramatic rim light, high contrast, a calm dark band at the top for the title,
> no text, no letters, no logo, no border, no watermark.

Two more launch pieces need **no new art**: the loading splash (Claude can point Godot's boot splash at `logo.png` on
black, one project setting) and CrazyGames' preview videos (record them from the game).

## C. Images for planned work (not wired yet)

Dropping these in today shows **nothing**. Ask Claude to wire a set before you make it.

### C1. Word labels that become pictures: 10 files, `images/hud/`
These spots still draw plain text; the text stays as the fallback. Unless a note says otherwise: 512x512, transparent,
the A1 icon style, no text.

**badge_close_call.png** (the `+4 CLOSE CALL` pop)
> Game UI badge: three glowing red demon claw slashes tearing through the air, missing a small dark figure by a hair,
> sparks where they pass, round iron badge rim, dark fantasy horror mobile game icon, chunky bold silhouette, thick dark
> outline, centred, isolated on a transparent background, no text, no letters, no watermark.

**badge_phase_dodge.png** (the `+4 PHASE DODGE` pop)
> Game UI badge: a ghostly ice-blue figure stepping through a cracked stone wall while a red demon claw closes on empty
> air behind it, round iron badge rim, dark fantasy horror mobile game icon, chunky bold silhouette, thick dark
> outline, centred, isolated on a transparent background, no text, no letters, no watermark.

**icon_curse.png** (the bottom-left `CURSED: <name>` line)
> Game UI icon of a cracked bone skull branded with a glowing red hex rune on its forehead, wrapped in a short rusted
> chain, dark fantasy horror mobile game icon, chunky bold silhouette, thick dark outline, centred, isolated on a
> transparent background, no text, no letters, no watermark.

**hint_icons.png** (the control hints, bottom left; each keycap keeps its letter, an icon replaces the word).
**768x512, a 3x2 grid of 256 px cells**, transparent, in the order of today's hints:
> A 3x2 sprite sheet of six small game UI icons, each centred in its own square cell with a margin, same style for
> all: dark fantasy horror mobile game icons, chunky bold silhouettes, cracked iron with glowing ember seams, thick dark
> outline. Top row: a pair of bare footprints (move), a winged boot (sprint), a flashlight with a short beam
> (flashlight). Bottom row: a folded old paper map (map), two vertical pause bars (pause), a circular arrow around a
> small skull (restart). Transparent background, no text, no letters, no watermark.

**grades.png** (`GRADE S` on FLOOR CLEARED). **1024x1024, a 2x2 grid of 512 px cells**, transparent. Needs letters:
> A 2x2 sheet of four round game grade medallions, each centred in its own square cell: top-left a blazing gold
> medallion with a big carved letter "S" and flames around the rim, top-right a polished silver medallion with "A",
> bottom-left a bronze medallion with "B", bottom-right a cracked dark iron medallion with "C"; thick bold letters,
> dark fantasy horror mobile game style, glossy painted highlights, thick dark outline, transparent background, no other
> text, no watermark.

**Centre titles: 5 files**, each **1536x384, transparent, the words only**. Needs letters.

| File | Words |
|---|---|
| `title_floor_cleared.png` | FLOOR CLEARED |
| `title_act_cleared.png` | ACT CLEARED |
| `title_paused.png` | PAUSED |
| `title_flipping_time.png` | FLIPPING TIME |
| `title_keys_found.png` | ALL KEYS FOUND |

> The words "FLOOR CLEARED" as a dark fantasy horror game title: tall condensed gothic capital letters carved from
> bone-white stone with worn gold edges, hairline cracks and a soft ember-orange glow behind them, a few sparks, wide
> centred composition, transparent background, nothing else in the image, no other text, no watermark.
> (Swap in the words for each file. For `title_flipping_time.png`, make the letters blood red with a jagged glitch
> split and red static, like a warning.)

### C2. Phantom frost overlay: 1 file, `images/hud/` (comes with the Phantom)
**frost_overlay.png**, **1920x1080, transparent**. Laid over the screen edges while a Phantom is near (master plan §6:
"frost at the screen edge"), like `nightmare_overlay.png`.
> Frost creeping in from the edges of the frame like ice forming on a cold window: white and pale blue ice crystals and
> feathery frost patterns, thick in the four corners and along the edges, thinning to nothing toward the centre, the
> middle 60% of the image completely empty, transparent background, no text, no watermark.

### C3. Hub screen redesign: about 100 files
Panel, rows, bars, stars, seals, sliders, toggles, carved titles, stat and settings icons, Daily squares, Altar orbs,
act banners and sigils, journal pages, fonts. All prompts, sizes and the layout are in
[HUB_ASSET_PROMPTS.md](HUB_ASSET_PROMPTS.md) §0-§6. Its six backgrounds and eight bestiary portraits are the same
pictures as A5 (generate them once), and it would replace `hub_entry.png`.

---

# SOUNDS

## D. Sounds the game already reads: 5 files, `audio/`

| File | Length | Where | Stand-in today |
|---|---|---|---|
| `sfx_devil_roar.mp3` | 2.5 s | the wake cut: the Devil tears out of the wall and roars (the game adds the echo) | `sfx_devil_wakes` at pitch 0.8 |
| `sfx_wall_slam.mp3` | 1.2 s | the Devil pounding on the far side of a thin wall before Flipping Time | the floor crack, pitched down |
| `sfx_wall_break.mp3` | 2.5 s | the Devil smashing through that wall when the flip lands, and its wake-up burst | the floor crack, pitched down |
| `sfx_box_open.mp3` | 0.9 s | you force a key box's lid open (the Devil can hear it) | the floor creak |
| `sfx_box_empty.mp3` | 0.6 s | the box you opened is empty | the floor crack, pitched down |

**sfx_devil_roar.mp3**
> A huge demonic creature's roar in a stone corridor, starting as a wet guttural snarl and swelling into a long furious
> bellow with a rasping animal edge, deep and inhuman, close and loud, dry room with no reverb (the game adds the
> echo), no music, no voice, no words

**sfx_wall_slam.mp3**
> One heavy blow on the far side of a thick stone wall, a deep muffled thud with a short crunch of grit and a low
> rumble that dies fast, heard from inside a dark corridor, something huge pounding to get through, dry room, no music,
> no voice

**sfx_wall_break.mp3**
> A thick stone wall bursting apart from a massive impact, a sharp crack then heavy chunks of masonry crashing onto a
> stone floor, grit and dust raining down after, close and loud, a monster smashing through, dry room, no music, no
> voice

**sfx_box_open.mp3**
> Old wooden box lid forced open: a stuck lid jerks, a short pause, then a long dry hinge creak as it swings up, close,
> dry room, no music, no voice

**sfx_box_empty.mp3**
> Empty wooden box: a hollow knock on bare planks and a soft puff of dust settling, disappointed silence after, close,
> dry room, no music, no voice

## E. Sounds for the new threats: 10 files, `audio/` (come with the threats)

Master plan §6: every threat warns before it can hurt you, so most of these are its warning. Loops say "loop on".

| File | Length | What it is |
|---|---|---|
| `sfx_phantom_near.mp3` | 4 s, loop on | the Phantom is close (with the flicker and the frost) |
| `sfx_light_flicker.mp3` | 1 s | your flashlight stutters near a Phantom |
| `sfx_phantom_shriek.mp3` | 2 s | you looked at it too long: it shrieks and the Devil hears where you are |
| `sfx_sentinel_hum.mp3` | 4 s, loop on | the Sentinel's searchlight sweeping its corridor |
| `sfx_sentinel_close.mp3` | 0.8 s | its eyelid shuts: cross now |
| `sfx_sentinel_open.mp3` | 0.8 s | its eyelid opens again |
| `sfx_sentinel_alarm.mp3` | 2.5 s | it saw you: alarm |
| `sfx_light_die.mp3` | 0.6 s | one ceiling light dying (the Ripper kills them one by one toward you) |
| `sfx_ripper_charge.mp3` | 3 s | the Ripper's rising roar as it comes (the 3 s warning) |
| `sfx_ripper_pass.mp3` | 1.5 s | it rushes past you in an alcove, or through the world you just flipped out of |

**sfx_phantom_near.mp3**
> A cold ghostly presence close by in a silent stone corridor: a faint slow breathy exhale like frost forming on
> glass, a thin high wavering tone, tiny ice crackles, very quiet and intimate, dry room, no music, no voice, no words,
> seamless loop

**sfx_light_flicker.mp3**
> An old flashlight flickering in someone's hand: a dying bulb's electrical buzz stuttering on and off with sharp
> little clicks, close, dry room, no music, no voice

**sfx_phantom_shriek.mp3**
> A sudden piercing ghostly shriek, a woman's spirit screaming, high, distorted and inhuman, rising fast and then cut
> off, close and loud, dry room with no reverb (the game adds the echo), no music, no words

**sfx_sentinel_hum.mp3**
> An old ceiling-mounted searchlight machine: a low electric hum, a slow motor whirring as it sweeps from side to side,
> soft servo ticks at each turn, dry room, no music, no voice, seamless loop

**sfx_sentinel_close.mp3**
> A heavy riveted iron shutter sliding down over a glass lens and locking with a deep metallic clunk and a short hiss,
> dry room, no music, no voice

**sfx_sentinel_open.mp3**
> A heavy iron shutter grinding up off a glass lens, a rising metallic scrape ending in a sharp click and an electric
> buzz as a light snaps on, dry room, no music, no voice

**sfx_sentinel_alarm.mp3**
> An old industrial alarm klaxon going off in a stone corridor, two harsh rising wails with a distorted metallic edge,
> urgent, close and loud, dry room, no music, no voice

**sfx_light_die.mp3**
> A ceiling light bulb burning out: a sharp electrical pop, a fizzing crackle and a tiny tinkle of glass, dry room, no
> music, no voice

**sfx_ripper_charge.mp3**
> Something monstrous charging down a long stone corridor toward you: starting far away and low, growing for three
> seconds into a screaming howl with thundering clawed footfalls getting closer and louder, no music, no voice, no
> words

**sfx_ripper_pass.mp3**
> A huge creature rushing past inches away at full speed: a violent whoosh of air, claws scraping stone, a roar flying
> past and fading fast down the corridor, close, no music, no voice, no words

---

# 3D MODELS

## F. 3D models the game already reads: 3 files, `models/`

**key_box.glb** (the boxes the keys hide in; replaces the code-built crate in `key_box.gd`). About 3k triangles max,
0.7 m wide, 0.48 m deep, 0.47 m tall. Front faces +Z. The lid must be a separate object named `Lid`, hinged on its back
edge, and the box needs a modelled hollow inside (players kneel and look into it). It must never read as the exit
chest: no iron bands, no locks, no gold.
> Game asset concept, three-quarter front view: a small plain wooden storage box with a flat hinged lid, rough dark
> planks held by two darker wooden slats, a little rope handle on each side, dusty, cobwebbed, scratched, damp stains;
> no metal, no lock, no treasure; dark horror style, semi-realistic. Isolated on a plain white background, even studio
> lighting, no shadow on the background.

**landmark_statue.glb**: about 5k triangles max, 2.0 m tall including the plinth, footprint 0.6 x 0.6 m or smaller.
Faces +Z. It must be recognisable by its silhouette from 6 m away in fog. Godot adds a candle at its feet. Today it's
a grey capsule on a box.
> Game asset concept, three-quarter front view: a weathered stone statue of a tall thin hooded figure standing on a
> plain square plinth, both hands covering its face as if weeping, long robe falling straight to the plinth, cracked
> grey stone with dark water stains and a little moss, bold simple silhouette, dark fantasy horror, semi-realistic.
> Isolated on a plain white background, even studio lighting, no shadow on the background.

**landmark_debris.glb**: about 4k triangles max, 0.8 m tall, footprint 0.7 x 0.7 m or smaller. Faces +Z. Today it's
three brown boxes.
> Game asset concept, three-quarter view: a small heap of broken old furniture piled in a corner: a smashed wooden
> chair on its side, two splintered crates stacked crookedly, a torn grey cloth draped over them and a rusty chain
> hanging off the top, dark grimy wood, dark horror style, semi-realistic. Isolated on a plain white background, even
> studio lighting.

## G. 3D models for planned work: 4 files, `models/` (not wired yet)

### The new threats (master plan §6, next on the roadmap)
3D models like the Devil (the master plan's billboard-sprite idea predates the 3D Devil). Claude animates them in code
the way it does the Devil, so **no animation clips are needed**: for the two figures, only auto-rig them on Mixamo
(free, humanoid) and export GLB. Godot adds the glow, the see-through look and the lights.

**phantom.glb** (the watcher, WAKE; look at it too long and it shrieks). About 10k triangles max, 1.75 m tall, A-pose.
Model it solid; Godot makes it pale and translucent.
> Character concept, full body front view, A-pose with arms 45 degrees down and legs slightly apart: the ghost of a
> 1980s hospital night nurse, very tall and thin, an old-fashioned white nurse's uniform and cap stained and torn at
> the hem, long black hair hanging over a pale face with no visible eyes, bare feet, long thin fingers, bluish-white
> skin, dark fantasy horror, semi-realistic. Isolated on a plain white background, even lighting, symmetrical.

**sentinel.glb** (the guard, both worlds; a ceiling searchlight eye that shuts for 2 s every 5 s). About 4k triangles
max, 0.5 m wide, 0.6 m tall including its arm. It hangs from the ceiling: **pivot at the top centre** (the ceiling
mount), the lens facing +Z. The eyelid must be a separate object named `Lid` and the glass a separate object named
`Lens` (Godot makes it glow).
> Game asset concept, three-quarter view from slightly below: a ceiling-mounted mechanical searchlight shaped like a
> giant eye, a round brass and black iron housing hanging from a short jointed arm, a big glass lens with a red-orange
> iris painted behind it, a heavy riveted iron eyelid that slides down over the lens, cables and rust, 1980s hospital
> machinery turned sinister, dark fantasy horror, semi-realistic. Isolated on a plain white background, even studio
> lighting.

**ripper.glb** (the Void Ripper, NIGHTMARE; rushes down a corridor after killing its lights). About 10k triangles
max, about 2.2 m tall standing (it runs hunched), A-pose.
> Character concept, full body front view, A-pose with arms 45 degrees down and legs slightly apart: a gaunt eyeless
> creature with black smoke-like skin stretched over long bones, extremely long arms ending in four long blade-like
> claws, a narrow skull with a wide lipless mouth of needle teeth, ribs showing, thin legs with long clawed feet,
> tatters of black void-smoke trailing off its back and shoulders, deep black with violet highlights, dark fantasy
> horror, semi-realistic. Isolated on a plain white background, even lighting, symmetrical.

### Optional: a clean player model
**player.glb** → replaces `character/character2withrig.glb`, the body you see in the Devil Cams. The current mesh has
a scrap fused to the left hand that floats off it when the forearm bends; a clean model fixes that, but swapping it
means re-tuning the player rig in code (a session of work). About 20k triangles max, 1.75 m, A-pose, Mixamo auto-rig
only (no clips). Use `images/menu/menu_hero.png` as the image-to-3D reference so the 3D hero matches the menu.
Since 17 Oct 2026 this body also stands, large, in the middle of the dashboard (the 3D lobby), so a clean model now
shows on every launch. `lobby_stage.gd`'s `MODEL` names the same file as `main.gd`'s `PLAYER_MODEL`: swap both.
> Character concept, full body front view, A-pose: a young survivor with messy dark hair and a long red scarf, dark
> grey jacket over a black shirt, utility belt, dark cargo pants and red-and-black combat boots, a flashlight clipped
> to the shoulder strap, semi-realistic anime-inspired style. Isolated on a plain white background, even lighting,
> symmetrical.

---

## Not needed any more (don't make)

- `devil_v2.glb` and animation clips for the player and the Devil: the Devil's rig was repaired and both are animated
  in code now.
- `icon_exit.png` (minimap readout): the corner minimap is gone.
- `models/map_arms.glb`: the map fists and `BoxHands` cover it.
- The 8 Oct audio redo list and `sfx_flip_denied.mp3`: all game clips were regenerated with ElevenLabs, and the flip
  button is gone. If one still sounds synthetic, its prompt is in `ASSET_PROMPTS.md` §6.
- The `decal_handprint.png` redo: delivered 9 Oct.
- Skins (plans/08 §4: Devil skins, map paper, hands): no prompts yet on purpose. A Devil skin has to be painted on the
  current model's own texture layout, so it gets written with the skin feature.
