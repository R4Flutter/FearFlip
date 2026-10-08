# FearFlip 3D: missing and redo assets (checked 8 Oct 2026)

Everything delivered so far is in the game (list below). Save new files in `godot/assets/new_assets/` with the exact
names below and tell Claude; Claude sizes them, moves them into place and wires them. `new_assets/` is your inbox and
archive of originals: it has a `.gdignore`, so Godot no longer imports it and it never ships.

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

## Order to do it in

1. 2b: act cards, padlock, burst (the act picker is still flat gradients).
2. 2c: the hub frame and backgrounds, then the bestiary portraits and the flashlight cards.
3. 2a `static.png`, 1 (handprint), then section 3 when you have time.
