# FearFlip 3D: every asset still needed (checked 14 Oct 2026)

One file with a ready-to-paste prompt for every slot the game **already reads** but whose file is missing.
The game keeps a code stand-in until each file exists, so deliver in any order. **No code change is needed:** put the
file at the exact path (relative to `godot/assets/`), or drop it in `godot/assets/new_assets/` and tell Claude, who cuts
the ship copy.

48 files: 7 HUD icons, 3 sounds, 12 wall numerals, 2 landmark models, 7 card pictures, 17 menu/hub images.
Part B at the end lists art for screens that are planned but **not wired into the code yet**. Don't make those until
the code is ready.

## Ground rules

- **Style line** (already inside every prompt below): dark fantasy horror, semi-realistic painterly, crimson red + deep
  violet + ember orange, volumetric fog, no text, no UI, no watermark.
- **Transparent PNG** where it says so. If your tool can't do transparency, use a background remover, or paint on pure
  white and tell Claude.
- **Generate at** the size given (or bigger at the same aspect). Claude makes the smaller ship copy.
- **3D models:** make a concept image first (plain white background, three-quarter view), then image-to-3D (Meshy /
  Tripo). Low-poly/remesh on, PBR textures at 1K, real-world size, Y-up, pivot at the base centre, export GLB. Keep to
  the triangle budget given (Claude can decimate in Blender if it comes out heavy).
- **Sounds:** ElevenLabs Sound Effects, model `eleven_text_to_sound_v2`, loop off, prompt_influence 0.6 (the free
  plan covers it). MP3.

## Priority (what the player notices most first)

1. **HUD icons** `icon_wake`, `icon_nightmare`, `icon_flip`, `icon_floor`: on screen every second of play.
2. **Sounds** `sfx_devil_roar`, `sfx_wall_slam`, `sfx_wall_break`: the biggest scares currently use pitched-down
   placeholder sounds.
3. **Wall numerals** `glyph_1..12` + **landmark models**: the player navigates by them.
4. `icon_devil`, `icon_chest`, `icon_shards`.
5. Card pictures (torches, events, Cursed Week).
6. `ending_bg`, `act_6`, then the hub backgrounds, bestiary portraits, `hub_entry`.

---

## 1. HUD icons: 7 files, `images/hud/`

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

---

## 2. Sounds: 3 files, `audio/`

Stand-ins today: the floor crack pitched down (slam, break), `sfx_devil_wakes` at pitch 0.8 (roar).

| File | Length | Where |
|---|---|---|
| `sfx_devil_roar.mp3` | 2.5 s | the wake cut: the Devil tears out of the wall and roars (the game adds the echo) |
| `sfx_wall_slam.mp3` | 1.2 s | the Devil pounding on the far side of a thin wall before Flipping Time |
| `sfx_wall_break.mp3` | 2.5 s | the Devil smashing through that wall when the flip lands, and its wake-up burst |

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

---

## 3. Wall numerals: 12 files, `textures/decals/`

`glyph_1.png` … `glyph_12.png` = I, II, III, IV, V, VI, VII, VIII, IX, X, XI, XII. Painted on maze walls at junctions
("right at III"). **512x512, transparent PNG**, about 10% margin. Use the same brush and colour on all twelve. Image
tools often misspell long numerals (VIII, XII): check each one and regenerate any that come out wrong. If one never
comes out right, skip it; the game paints its own stand-in numeral.

Prompt (swap `III` for each numeral):
> The Roman numeral III hand-painted on a wall in thick dark dried-blood red paint with a wide brush, rough uneven
> strokes, drips running down from the bottom of each stroke, a few splatters around it, front view, flat, centred,
> isolated on a transparent background, no wall texture, no shadow, no other text.

---

## 4. Landmark models: 2 files, `models/`

Today they're a grey capsule on a box and three brown boxes. Both face +Z.

**landmark_statue.glb**: about 5k triangles max, 2.0 m tall including the plinth, footprint 0.6 x 0.6 m or smaller.
It must be recognisable by its silhouette from 6 m away in fog. Godot adds a candle at its feet.
> Game asset concept, three-quarter front view: a weathered stone statue of a tall thin hooded figure standing on a
> plain square plinth, both hands covering its face as if weeping, long robe falling straight to the plinth, cracked
> grey stone with dark water stains and a little moss, bold simple silhouette, dark fantasy horror, semi-realistic.
> Isolated on a plain white background, even studio lighting, no shadow on the background.

**landmark_debris.glb**: about 4k triangles max, 0.8 m tall, footprint 0.7 x 0.7 m or smaller.
> Game asset concept, three-quarter view: a small heap of broken old furniture piled in a corner: a smashed wooden
> chair on its side, two splintered crates stacked crookedly, a torn grey cloth draped over them and a rusty chain
> hanging off the top, dark grimy wood, dark horror style, semi-realistic. Isolated on a plain white background, even
> studio lighting.

---

## 5. Card pictures: 7 files, `images/cards/`

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

---

## 6. Menu and hub images: 17 files, `images/menu/`

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
**Generate 1920x1080**, ship 1280x720. Drawn behind each hub screen's list at 30% opacity, cover-fit. Keep the centre
70% dark and empty (the text sits there), with light only at the edges.

**hub_daily.png**
> Dark fantasy horror game background, semi-realistic painterly anime style, 16:9: a cracked stone calendar wall at the
> heart of a maze, one day carved deeper than the rest and glowing ember red, tally marks and old scratched dates fading
> into the dark around it, a single candle burning on a ledge below. The centre stays dark and empty; ember and violet
> light at the edges only, no readable text or numbers, no UI, no watermark.

**hub_altar.png**
> Dark fantasy horror game background, semi-realistic painterly anime style, 16:9: a black stone altar in a ruined
> chapel at the bottom of a maze, a cracked offering bowl heaped with glowing violet crystal shards, melted red candles,
> iron chains hanging out of the dark above, faint occult sigils carved into the floor. The centre stays dark and empty;
> light comes only from the shards and candles at the edges. Crimson, deep violet and ember orange, volumetric haze, no
> text, no UI, no watermark.

**hub_mirror.png**
> Dark fantasy horror game background, semi-realistic painterly anime style, 16:9: a tall cracked antique mirror at the
> end of an abandoned hospital ward corridor. The reflection shows the same corridor bathed in red, wet walls and a
> faint horned silhouette standing far back in it. Five small star-shaped candle holders on the ornate frame, two of
> them lit. The centre stays dark; cold blue on the near side, blood red inside the glass, no text, no UI, no watermark.

**hub_bestiary.png**
> Dark fantasy horror game background, semi-realistic painterly anime style, 16:9: a rotting corkboard wall in a
> forgotten doctor's study, covered in pinned sketches and torn pages of monsters, a tall horned figure drawn in red
> chalk at its heart, red string between the pages, specimen jars on a shelf, one flickering desk lamp. The centre stays
> dark; ember and violet light at the edges, no readable text, no UI, no watermark.

**hub_archive.png**
> Dark fantasy horror game background, semi-realistic painterly anime style, 16:9: a dusty hospital records room, tall
> steel filing cabinets, one drawer pulled open and spilling yellowed patient files and handwritten notes, a desk lamp
> with a weak warm bulb, a 1987 wall calendar half in shadow. The centre stays dark; warm lamp light and deep violet
> shadow, no readable text, no UI, no watermark.

**hub_settings.png**
> Dark fantasy horror game background, semi-realistic painterly anime style, 16:9: the night nurse's station of an
> abandoned 1987 hospital ward, a wall of old brass dials, toggle switches and a dusty valve radio, one switch flipped
> and its pilot lamp glowing ember red, a desk lamp with a weak warm bulb. The centre stays dark; warm lamp light and
> deep violet shadow, no readable text, no UI, no watermark.

### Bestiary portraits: 8 files
`beast_<id>.png`, **generate 1000x600 (5:3)**, ship 240x144. Each portrait appears beside its Bestiary entry once
you've met that threat, cover-fit to 120x72, so keep the subject centred and readable when small. Start every prompt
with:
*"Dark fantasy horror game illustration, semi-realistic painterly anime style, 5:3, the subject centred so a small crop
still reads, volumetric fog, no text, no UI, no watermark:"* then add the subject.

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

---

## Part B: planned art, NOT wired into the code yet

Dropping these in today shows **nothing**: each needs code first. The prompts already exist. Ask Claude to wire a set
before you make it.

| Set | Files | Prompts in |
|---|---|---|
| Hub screen redesign: panel, rows, bars, stars, seals, sliders, toggles, carved titles, stat/settings icons, Daily squares, Altar orbs, act banners/sigils, journal pages, fonts | ~100 | `HUB_ASSET_PROMPTS.md` §0-§6 (it would replace `hub_entry.png` and move the hub backgrounds to `images/hub/bg_*.png`) |
| Word labels still on screen: badges (Close Call, Phase Dodge), carved titles (FLOOR CLEARED, PAUSED, …), grade letters, hint icons | ~15 | `MISSING_ASSETS.md` §4 |
| Phantom, Sentinel, Ripper (the other threats, master plan §6) | models + sounds | not written yet; they'll come with the feature |
