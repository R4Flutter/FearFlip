# FearFlip 3D: missing and redo assets (checked 8 Oct 2026)

Everything delivered so far is in the game (list below). Save new files in `godot/assets/new_assets/` with the exact
names below and tell Claude; Claude sizes them, moves them into place and wires them. `new_assets/` is your inbox and
archive of originals: it has a `.gdignore`, so Godot no longer imports it and it never ships.

## 0. Do first: HUD icons, so the status plate has no words (9 Oct 2026)

The top-right plate now shows **icons and numbers only**: floor `1/10` and the floor's rule cards, the world + clock,
the flip, the keys (the chest joins them once it opens) and the shards. Until these icons arrive, the menu's own icons
stand in (maze tile, hourglass, the red RETRY arrows, gold chest, gem).

Every file: **512x512 PNG with a transparent background** (if your tool can't do transparency, use a background
remover). Put it straight into `godot/assets/images/hud/` with the exact name and it shows on the next run, with no code
change. You can also put it in `new_assets/` and tell Claude. They are drawn at 30-40 px, so use one bold subject, a
thick outline, no fine detail and nothing behind it. Match the set the menu icons and `key_icon.png` come from:
glossy, chunky, cracked iron and stone, glowing seams.

| File | Where it shows | Stand-in today |
|---|---|---|
| `icon_wake.png` | left of the clock while in WAKE | hourglass |
| `icon_nightmare.png` | left of the clock while in NIGHTMARE | hourglass |
| `icon_flip.png` | the flip power; refills clockwise while it recharges, turns red while Flipping Time holds it | RETRY arrows |
| `icon_floor.png` | before the floor count `3/10` (the depth in the Abyss) | maze tile |
| `icon_chest.png` (optional) | after the keys once all are found | gold treasure chest |
| `icon_shards.png` (optional) | before the shard count | purple gem |

**icon_wake.png** and **icon_nightmare.png** are a pair. Keep the same frame at the same size and position, so a flip
reads as the eye itself changing.
> Game UI icon of a wide-open human eye set in an almond-shaped frame of cracked grey stone with frosted silver trim,
> the iris glowing cold ice-blue, calm and watchful, a faint blue mist around it, palette of ice blue, steel grey and
> white with no red at all, dark fantasy horror mobile game icon, chunky bold silhouette, thick dark outline, glossy
> painted highlights, front view, centred, isolated on a transparent background, no text, no letters, no watermark.

> The same almond-shaped stone eye frame as a matching game UI icon, now demonic: a bloodshot blood-red eye with a
> vertical slit pupil of molten orange, small curved horns growing from the frame, glowing red cracks in the stone and
> red smoke curling off it, crimson and black palette, dark fantasy horror mobile game icon, chunky bold silhouette,
> thick dark outline, glossy painted highlights, front view, centred, isolated on a transparent background, no text, no
> letters, no watermark.

**icon_flip.png** must be round: the game fills it clockwise like a cooldown clock.
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

**icon_chest.png** (optional; matches the 3D exit chest better than the menu's gold chest)
> Game UI icon of a heavy black iron-bound chest with a horned demon face on the lid, the lid cracked open with molten
> gold light spilling out, three-quarter front view, dark fantasy horror mobile game icon, chunky bold silhouette, thick
> dark outline, glossy painted highlights, centred, isolated on a transparent background, no text, no letters, no
> watermark.

**icon_shards.png** (optional)
> Game UI icon of a single jagged violet soul-crystal shard with a glowing lilac core, a wisp of violet smoke trailing
> from its tip, sharp facets with white highlights, dark fantasy horror mobile game icon, chunky bold silhouette, thick
> dark outline, centred, isolated on a transparent background, no text, no letters, no watermark.

The plate itself (`hud_plate.png`) stays. It is now drawn at its own 720x400 shape, so the thorned corners no longer
stretch.

---

## In the game now (8 Oct 2026)

- **Cards:** 25 card arts (`images/cards/<id>.png`; the four curses reuse their twin rule's art), `card_frame`,
  `pick_backdrop`, `omen_sigils` (re-cut on its real grid lines; omen cards, the Altar and the HUD's omen line).
- **World:** wake and NIGHTMARE wall, floor and ceiling (the square `(2)` redos), `wall_trim`, with normal maps derived
  from them (`textures/world/`), mapped one tile per cell in both worlds.
- **Decals** (`textures/decals/`): `safe_circle`, `exit_circle`, `crack_hairline` (weak tile), `crack_glow` (cracked
  tile), `decal_scratches` and `decal_blood` (NIGHTMARE dressing; the blood's grey backdrop was cleaned to white).
- **Models** (`models/`): `chest` (lid split off so it still swings open), `key`, `ceiling_lamp`, `gate_arch` (stands
  behind the exit chest on every Gate), `sanctuary_altar` (down a dead end on every Sanctuary). The delivered files were
  ~1.9M triangles each: Claude cut them to 3k-12k triangles and 1K textures in Blender (4.4 MB for all five), so **no
  re-export is needed**.
- **HUD** (`images/hud/`): `key_icon`, `hud_plate`, `minimap_frame`, `banner`, `keycap` + `keycap_wide` (split from
  the one image), `nightmare_overlay` (pulses with the heartbeat), `flip_warning_overlay`; `textures/fx/fx_sheet`
  (key sparkles, trap dust); Oswald SemiBold as `fonts/ui.ttf` (menus, death screen, HUD).

**Not used:** the two "Businessman" thumbnails and `KATSU_*.jpg` (not FearFlip art); `Demonic Gothic Gate…` and
`Gothic Altar…` (the white-background concept images behind the two models); `Gothic Horned Skull Card Frame.png`
and `Flashlight Through the Haunted Stone Maze.png` (copies of `card_frame` and `thick_fog`); `decal_handprint.jpeg`
(a photo of a real hand); the 16:9 `nightware_wall` / `nightmare_floor` / `nightmare_ceiling` (replaced by the redos).

---

## 1. Redo (optional)

`decal_handprint.png` is painted on a NIGHTMARE wall, so it can't be laid over the walls as a decal. Save it again
as **PNG, 1024x1024, top-down, on pure white**:

> A single bloody handprint smeared on a surface, the print only (no hand, no arm, no person), top-down flat view,
> dark red and almost black dried blood with drag streaks from the fingers, centred, isolated on a pure white
> background, no shadow, no text.

---

## 2. Still missing (never delivered)

### 2a. One card

**PNG, 880x520**, same style line as the other cards (`images/cards/PROMPTS.md`):

| File | Card | Subject |
|---|---|---|
| `static.png` | rule | a torn paper map dissolving into TV static and ash |

### 2d. Landmarks (plans/07): 2 models, 12 decals

Prompts: `ASSET_PROMPTS.md` §3b: `models/landmark_statue.glb`, `models/landmark_debris.glb`,
`textures/decals/glyph_1.png` … `glyph_12.png` (the painted numerals I–XII). Code stand-ins until then.

### 2e. Paper map (plans/07): 2 models, 1 image, 2 sounds

Prompts: `ASSET_PROMPTS.md` §3c: `models/map_hand.glb` (one right hand and forearm; the game mirrors it for the
left), `models/map_roll.glb`, `images/hud/map_paper.png` (2048x1536, plain centre), `audio/sfx_map_open.mp3`,
`audio/sfx_map_close.mp3`. Code stand-ins (and silence) until then.

### 2c. Meta hub art and the flashlight cards (plans/06 P5)

Prompts: `images/menu/PROMPTS.md` → "Meta hub" (`hub_entry`, `hub_altar`, `hub_mirror`, `hub_bestiary`,
`hub_archive`, `hub_daily` (P6), 8 `beast_<id>` portraits, `ending_bg`) and `images/cards/PROMPTS.md` → "Flashlights from P5"
(`old_torch`, `lantern`, `uv_light`, `camera_flash`).

### 2b. Act picker cards, padlock and act-cleared burst (7 files)

The menu's CHOOSE YOUR ACT cards are flat colour gradients today. **Generate the cards portrait 2:3 (e.g.
1024x1536)**: edge to edge, no frame, subject in the top 60% (the bottom 40% sits under the act name), no text
anywhere.

**act_1.png: AWAKENING** (cold blue)
> Dark fantasy horror mobile game card art, semi-realistic painterly anime style, portrait 2:3. A lone young survivor
> seen from behind holds a flashlight at the entrance of a vast stone maze at night; cold blue moonlight, tall wet
> walls, drifting fog, a thin line of red glow leaking from far down the corridor, two faint glowing keys floating in
> the dark. Mood: uneasy calm before the hunt. Deep navy and steel blue, one small ember-red accent, volumetric
> fog, rim light, high detail, no text, no UI, no watermark.

**act_2.png: HUNTED** (blood red)
> Dark fantasy horror mobile game card art, semi-realistic painterly anime style, portrait 2:3. A horned Devil
> silhouette with burning eyes fills the far end of a long maze corridor drowned in red light; claw marks gouged
> into the stone walls; in the foreground a young survivor sprints toward the viewer, red scarf trailing, dust and
> embers whipping past. Mood: the chase. Crimson and black with lava rim light, volumetric red fog, motion, high
> detail, no text, no UI, no watermark.

**act_3.png: MIND BREAK** (deep violet)
> Dark fantasy horror mobile game card art, semi-realistic painterly anime style, portrait 2:3. A stone maze folding
> over itself like an impossible Escher drawing: corridors running up walls and across the ceiling, staircases
> into nowhere; the image is split down the middle by a jagged glowing crack, the left half cold blue and calm, the
> right half blood red and hellish; a small survivor floats upside down, disoriented. Mood: reality breaking. Deep
> violet, cold blue and crimson, volumetric fog, high detail, no text, no UI, no watermark.

**act_4.png: PRECISION HELL** (ember orange)
> Dark fantasy horror mobile game card art, semi-realistic painterly anime style, portrait 2:3. A narrow path of
> cracked stone floor tiles hanging over a bottomless abyss of embers and lava; glowing orange cracks spiderweb
> through the tiles, several tiles already crumbling and falling away; a young survivor balances mid-step,
> flashlight beam on the next tile; a faint circular rune like a clock face glows in the smoke above. Mood: one wrong
> step and you fall. Ember orange and charcoal black, heat haze, rising sparks, high detail, no text, no UI, no
> watermark.

**act_5.png: THE BREAKER** (crimson and black)
> Dark fantasy horror mobile game card art, semi-realistic painterly anime style, portrait 2:3. The bottom of the
> maze: a colossal horned demon rises behind a shattered iron gate bound with snapped chains, molten cracks across
> its body, eyes blazing; a tiny survivor silhouette stands before it on a ledge of broken stone, flashlight raised.
> Mood: the final escape. Crimson, black and molten gold, lava glow from below, volumetric smoke, epic scale, high
> detail, no text, no UI, no watermark.

**act_locked.png** (1024x1024, transparent)
> A heavy rusted iron padlock wrapped in thick chains, front view, perfectly centered, isolated on a transparent
> background. Dark fantasy painterly style matching a horror mobile game, worn metal with scratches, faint ember-red
> rim light along the edges, soft shadowless lighting so it sits cleanly over any art. No text, no background, no
> watermark.

**act_cleared_burst.png** (3:1, e.g. 1536x512, on pure black)
> A radiant victory burst for a dark fantasy horror game: an ornate demonic seal shattering outward from the center,
> shards of glowing gold and crimson, light rays and sparks exploding horizontally, wide 3:1 composition, centered
> and symmetrical, empty middle area for overlaid words, painted on a pure black background (the black will be made
> invisible). Gold, crimson and ember orange glow, painterly, high detail, no text, no letters, no watermark.

---

## 3. Optional (later)

**Audio.** The files in `godot/assets/audio/sfx_*.mp3` are still the placeholder set (several share exactly the
same length). Use an SFX generator (ElevenLabs Sound Effects, Stable Audio) and save over the same names; no code
change is needed. Check the licence allows commercial use.

| File | Prompt |
|---|---|
| `sfx_ambient_calm.mp3` | Dark ambient drone loop for a horror maze: distant low hum, faint dripping water, air moving through stone corridors, a rare far-off metallic creak; no melody, no drums; seamless 60-second loop |
| `sfx_ambient_intense.mp3` | Oppressive horror drone loop: deep pulsing sub-bass, distorted low strings, faint whispers and breathing, irregular metallic scrapes, constant tension with no climax; seamless 60-second loop |
| `sfx_flip.mp3` | Reality-flip whoosh: a reversed cymbal swell into a deep thud with a glassy shimmer tail, 0.8 s |
| `sfx_flip_denied.mp3` | Short dull negative thunk with a muffled buzz, like hitting a locked door, 0.3 s |
| `sfx_flipping_warning.mp3` | Ominous warning: three accelerating heartbeat-like pulses under a distorted siren swell, 3 s |
| `sfx_sigil.mp3` | Old iron key picked up: a bright metallic clink plus a short magical chime with sparkle, 0.6 s |
| `sfx_devil_approach.mp3` | Close monstrous breathing loop: wet raspy inhale and exhale over a low guttural growl, seamless 4-second loop |
| `sfx_devil_wakes.mp3` | Distant demonic roar echoing down stone corridors, layered with a low rumble and rattling chains, 2.5 s |
| `sfx_heartbeat.mp3` | Deep muffled human heartbeat, 80 BPM, no music, seamless 3-second loop |
| `sfx_low_time.mp3` | Fast clock ticking over a pulsing low synth tone, rising urgency, seamless 4-second loop |
| `sfx_floor_creak.mp3` | Stone floor tile creaking and grinding under a footstep, a trickle of small debris, 0.7 s |
| `sfx_floor_crack.mp3` | Stone floor cracking and collapsing: a sharp crack, then rubble tumbling into a deep echoing shaft, 1.5 s |
| `sfx_safe_circle.mp3` | Protective ward activating: soft resonant hum, a shimmering bell tone and an airy whoosh, calming, 1.2 s |
| `sfx_win.mp3` | Short relief sting: a dark choir chord resolving upward, then a heavy lock clicking open, 2.5 s |
| `sfx_lose.mp3` | Death sting: a sudden distorted orchestral hit and a demonic shriek fading to silence, 2.5 s |
| `sfx_footstep_1/2/3.mp3` | One footstep on damp stone in a narrow corridor, rubber sole, slight echo, 0.4 s (three takes with different pressure) |

**Character animations.** The player (`character/character2withrig.glb`) and the Devil
(`character/skleton_added_devil.glb`) are rigged and light enough (~19k triangles) but carry no animations; the game
fakes the walk in code. If your tool can animate a rigged model (Meshy *Animate*, Tripo *Animation*, or Mixamo),
export each again as GLB with these clips, in place, 30 fps: **idle, walk, run**, and for the Devil also **attack**
(a forward lunge-grab, about 0.6 s). Keep the same file names. Also export the textures at 1K (they are 2K–4K now).

---

## 4. Later: the other places that still use words

These spots still draw plain text. Generate any of them whenever you like, and Claude wires each one when it arrives
(the text stays as the fallback). Unless a note says otherwise, use the §0 icon style: 512x512, transparent, no text.
Teaching lines ("The circle is empty. Move.", "Not now. It's close.") stay as words on purpose.

**Minimap readout** (`DEVIL 12 m` / `EXIT 8 m` under the map, the `EXIT` tag on it). Files go in `images/hud/`.

`icon_devil.png` (the menu's demon icon can stand in):
> Game UI icon of a horned demon head seen from the front, burning red eyes, blackened cracked skin with glowing lava
> seams, dark fantasy horror mobile game icon, chunky bold silhouette, thick dark outline, glossy painted highlights,
> centred, isolated on a transparent background, no text, no letters, no watermark.

`icon_exit.png`:
> Game UI icon of a round glowing ward circle carved into a stone floor, seen from above, runes around its rim, pale
> green-white light rising from its centre, dark fantasy horror mobile game icon, chunky bold silhouette, thick dark
> outline, centred, isolated on a transparent background, no text, no letters, no watermark.

**Score pops** (`+4 CLOSE CALL` and `+4 PHASE DODGE` under the plate). Files go in `images/hud/`.

`badge_close_call.png`:
> Game UI badge: three glowing red demon claw slashes tearing through the air, missing a small dark figure by a hair,
> sparks where they pass, round iron badge rim, dark fantasy horror mobile game icon, chunky bold silhouette, thick dark
> outline, centred, isolated on a transparent background, no text, no letters, no watermark.

`badge_phase_dodge.png`:
> Game UI badge: a ghostly ice-blue figure stepping through a cracked stone wall while a red demon claw closes on empty
> air behind it, round iron badge rim, dark fantasy horror mobile game icon, chunky bold silhouette, thick dark
> outline, centred, isolated on a transparent background, no text, no letters, no watermark.

**Curse marker** (the bottom-left omen line still says `CURSED: <name>`; the omens already have sigils).
`icon_curse.png`:
> Game UI icon of a cracked bone skull branded with a glowing red hex rune on its forehead, wrapped in a short rusted
> chain, dark fantasy horror mobile game icon, chunky bold silhouette, thick dark outline, centred, isolated on a
> transparent background, no text, no letters, no watermark.

**Control hints** (bottom left; each keycap keeps its letter, an icon replaces the word). `hint_icons.png`,
**1024x512, a 4x2 grid of 256 px cells**, transparent, in `images/hud/`:
> A 4x2 sprite sheet of eight small game UI icons, each centred in its own square cell with a margin, same style for
> all: dark fantasy horror mobile game icons, chunky bold silhouettes, cracked iron with glowing ember seams, thick dark
> outline. Top row: a pair of bare footprints (move), a winged boot (sprint), two curved arrows chasing in a circle,
> one ice-blue and one red (flip), a flashlight with a beam (flashlight). Bottom row: two vertical pause bars (pause), a
> circular arrow around a small skull (restart), a folded old paper map (map), an empty cell. Transparent background,
> no text, no letters, no watermark.

**Floor grades** (`GRADE S` on FLOOR CLEARED). `grades.png`, **1024x1024, a 2x2 grid of 512 px cells**,
transparent, in `images/hud/`. These need letters, so use a tool that can spell (Ideogram, GPT image, Flux):
> A 2x2 sheet of four round game grade medallions, each centred in its own square cell: top-left a blazing gold
> medallion with a big carved letter "S" and flames around the rim, top-right a polished silver medallion with "A",
> bottom-left a bronze medallion with "B", bottom-right a cracked dark iron medallion with "C"; thick bold letters,
> dark fantasy horror mobile game style, glossy painted highlights, thick dark outline, transparent background, no other
> text, no watermark.

**Centre titles** (the words in the middle of the screen; the banner smoke already sits behind them). Each is
**1536x384, transparent, the words only**, in `images/hud/`. Use a tool that can spell:

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

The live numbers (time to spare, shards, the countdown) stay as text under each title.

## Order to do it in

0. §0: the HUD icons (the status plate shows stand-ins until then); `icon_wake`, `icon_nightmare` and `icon_flip`
   matter most.
1. 2b: act cards, padlock, burst (the act picker is still flat gradients).
2. 2c: the hub frame and backgrounds, then the bestiary portraits and the flashlight cards.
3. 2a `static.png`, 1 (handprint), then sections 3 and 4 when you have time.
