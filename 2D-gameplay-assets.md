# FearFlip 2D: gameplay assets (Pokémon-style horror)

For the 2D game on `main`. This file covers **everything you see during a run**: the maze, the walls, the runners,
the devils, every animation, the effects and the in-run HUD. The dashboard and menus are separate, and their style is
still open (test prompts in `2D-style-test-prompts.md`).

**The look:** like Pokémon Ash Gray, the fan game built on Pokémon FireRed. It's a top-down pixel-art world where
every character reads clearly even though it's tiny, made scary here with cold dungeon stone, bone, dried blood and
candlelight. There's no neon, no pink and no green. The walls follow your reference picture: thick raised stone
walls with a pale capstone top and a rough rock face, on a dark cobblestone floor.

**Every character is new.** Steel Sentinel, Green Phantom, Void Ripper and the old Devil are gone. Three new kids run
the maze, and four new devils hunt them, a different one every 25 stages.

**Style only, never Pokémon itself.** Don't use Pokémon's real sprites, tiles, font, names or logo; Nintendo and Game
Freak own them. "In the style of" is fine in a prompt, but the final art must be your own. Leave Pokémon out of your
store listing.

## How to use this file

1. Make each file with the tool and settings in §3. Add the **STYLE** line (§4) where a prompt says *+ STYLE*.
2. Save it as **`assets/new_assets/<exact file name>`**. That folder isn't bundled into the app.
3. Tell Claude "assets delivered". Claude checks the pixels, packs the sheets and wires them in. Until a file exists,
   its slot keeps today's look, so you can deliver in any order.
4. Work in the order of §12.

## Delivered so far (14 Oct 2026, `fearflip_assets.zip`)

The first delivery is painted (Nano Banana) art, so the game uses the §4 "smooth hand-painted" look: no pixel
snapping. `tool/process_2d_assets.py <zip>` keys out the fake backdrops (drawn checkerboards, white, sky), cuts
the sheets into strips under `assets/images/2d/`, covers the ✦ watermark and self-checks every strip. Re-run it
on a new delivery; the crop boxes in it are measured on this one.

**Wired in:** both tilesets and floor extras (walls autotiled with capstone rims, corners and rock faces), start,
exit (gold in WAKE, red eyes in NIGHTMARE: `extra_devil_eyes_exit`), spirit-candle safe zones, both trap sheets,
torches, both prop sheets, smoke (the Devil appears/vanishes), debris (trap collapse), sparkles (exit), wisps and
drips (NIGHTMARE), flip (the world flips), dust (footsteps), the bone arrow (`extra_bloody_bone`, the off-screen
exit pointer), all 16 icons, the timebar, the pause button, and `ui_textbox` (round, so it became the medallion
on every in-run dialog). The maze is dark with light around the runner, torches, the exit and safe zones (code).

**Layout (user, 14 Oct 2026):** a run is landscape only and the maze fills the whole screen like Pokémon Ash Gray
(no box); the HUD sits on top of it. The d-pad and joystick are drawn in code, see-through and fixed in place, so
`ui_dpad`, `ui_joystick` and `ui_knob` are deliberately not used.

**Still to deliver:** every runner and devil sheet and portrait (§7, §8: the runner is still a lantern glow and
the Devil a shadow with eyes), `fx_emotes`, `obj_salt_circle` (the spirit-candle tile stands in), `ui_sign`,
`ui_cursor`, and the two fonts (numbers use the
system font with a dark outline until Press Start 2P is bundled).

---

## 1. The look

### 1.1 Rules borrowed from Pokémon FireRed
- **3/4 top-down view.** You see the top of a character's head and the front of their body. Walls show their top and
  their front face, like in your picture.
- **Big round heads**, about 2.5 heads tall. Faces, hats and hoods stay readable when tiny.
- **A dark outline** around every sprite (`#16151F`, never pure black) and 3-4 shades per colour, lit from the
  top-left.
- **Crisp hard pixels:** no blur, no soft gradients, no smooth anti-aliased edges.
- **One tile is 32×32 pixels.** FireRed used 16×16 tiles, but AI pixel tools draw much cleaner at 32 px, and a phone
  has far more room than a Game Boy Advance. A character stands on one tile and their head pokes into the tile above,
  just like in FireRed.

### 1.2 What makes it scary
- **Kids versus devils.** The kids follow Pokémon's cute proportions. The devils break them: too tall, too thin,
  limbs bent the wrong way, faces that don't fit. That contrast is the horror, the same trick as Lavender Town,
  The Witch's House, Mad Father and OMORI.
- **Darkness.** The maze is dark. Each runner carries a light (a lantern, a candle or a paper lantern) that lights a
  circle around them, like the caves where Pokémon needs Flash. Wall torches add small pools of light. Devil eyes
  always glow, so you see the eyes before the body.
- **Floor details:** bones, melted wax, scratches, a dropped doll. They also help you remember your route.

### 1.3 Palette: "Night 32"
Every sprite uses at most 16 of these colours. If your tool accepts a palette, give it this list.

| Group | Hex |
|---|---|
| Void and shadow | `#0A0A0F` `#16151F` `#23222F` `#34344A` `#1E2A3A` |
| Cold stone (WAKE) | `#3B4660` `#55627E` `#7884A0` `#A3AEC4` `#D3D9E4` |
| Bone and skin | `#F0E6D2` `#D8C3A0` `#B39572` `#8A6B50` `#5E4636` |
| Wood and rust | `#3E2A20` `#6B3F24` `#9C5A2B` |
| Candle and amber | `#C98A2E` `#F2B544` `#FFE08A` |
| Blood (NIGHTMARE, danger) | `#2A080C` `#4D0E15` `#7A1520` `#B0202A` `#E03A32` |
| Bruise violet (shadows only) | `#2B1A33` `#45294F` |
| Spirit blue (safe) | `#9CC8F0` `#E4F2FF` |
| Highlight | `#FFFFFF` |

Each colour group has one job:
- **Amber** is the runner's own light.
- **Pale spirit blue** means safe.
- **Red** means danger only (devils, traps, low time), so it never appears on a runner.
- **Gold** means the exit and rewards.

### 1.4 The two worlds (the flip)
| | WAKE (normal) | NIGHTMARE (flipped) |
|---|---|---|
| Floor | dark slate-blue cobblestones, damp | dark maroon flagstones soaked in old blood, black cracks |
| Walls | rough grey rubble walls with pale capstones (your picture) | walls of piled bones and skulls fused with dark flesh, a pale bone rim |
| Light | cold moonlight and amber lanterns | a red glow; candles burn red |
| Air | slow dust motes | ghost wisps, blood dripping down the walls |

The walls stay lighter than the floor in both worlds, so the paths read instantly.

---

## 2. The camera: the one code change this style needs

Today the whole maze fits on the screen, which is why the sprites end up 5–15 px. Pokémon never shows the whole map:
the GBA screen shows 15×10 tiles and the camera follows the player.

- **Proposed:** the camera follows the runner and shows about **11 tiles across** (about 20 down on a phone). Each art
  pixel becomes a whole number of screen pixels (×3 on most phones), so a runner is about 32×48 dp on screen, as clear
  as in Pokémon.
- **The maze becomes a block maze.** Walls are full tiles, like your picture. A 10×10 maze becomes 21×21 tiles and a
  29×29 maze becomes 59×59 tiles. The rules don't change: cells, the devil, traps, safe zones and timers all stay the
  same.
- **What it changes in play:** you no longer see the whole maze at once, so it gets harder and scarier. Two helpers
  are worth considering: an exit arrow at the screen edge, and a map-peek button like Pokémon's Town Map. The stage
  timers may need retuning.

**Done (11 Oct 2026)**, in `lib/presentation/gameplay/maze_camera.dart` and `maze_painter.dart`:
- **Walls:** they're whole tiles with a light top, a darker front face and a shadow on the floor, like your picture.
- **Camera:** it follows the runner, 11 tiles across. To tune it, change `MazeCamera.visibleTiles`.
- **Exit arrow:** a gold arrow at the screen edge points to the exit whenever it's off screen.
- **Devil arrow:** a red arrow shows when the Devil is off screen but within 8 cells. To tune it, change
  `_devilWarnCells`.
- **Colours:** the stand-ins use the Night 32 palette (stone and bone, no green) until the tileset art arrives.

Still to do: the darkness and light circle, the map-peek button, and retuning the stage timers after playtesting.

---

## 3. Tools (research, Oct 2026)

| Asset | Tool | Settings |
|---|---|---|
| Maze tilesets (floor + walls) | **PixelLab → Create Tileset → Top-Down** | tile size 32×32; lower terrain = the floor; upper terrain = the wall; **side wall thickness on**, so the rock face shows like in your picture; export **Wang (16 tiles)** and keep the `.json` it gives you |
| Runners and devils | **PixelLab**: create the character with **4 directions** on a **64×64** canvas, then animate it ("walk" and "idle" templates; "animate with text" for the rest) | 64×64 is the safest size for PixelLab's animation templates |
| Same jobs, second option | **Retro Diffusion** on Scenario: *RD Tile* (classic 32×32 RPG tiles), *RD Animation* (4-direction walk cycles, idles and effects as sprite sheets) | use it if PixelLab struggles with a design |
| 128×128 portraits | PixelLab or Retro Diffusion at 128 px. GPT Image or Nano Banana only for a concept, which Claude then cleans up. | |
| Touch-ups, joining frames | Aseprite (paid), or LibreSprite or Piskel (free) | |

- **Fake pixel art check:** zoom in to 800%. If the pixels are uneven or the edges are blurry, it isn't real pixel
  art. Claude shrinks it to its true size with nearest-neighbour and snaps it to the palette.
- **Anchors first:** approve Lumi's walk cycle and the WAKE tileset before anything else, then show them to the tool
  as references for the rest.

---

## 4. Prompt templates

**STYLE** (add it where a prompt says *+ STYLE*):
> Pokémon FireRed–style GBA pixel art, 3/4 top-down RPG overworld view, crisp hard pixels with no anti-aliasing or
> blur, dark outlines, 3 to 4 shades per colour, light from the top-left, horror mood, dark palette of cold slate
> blue, bone white, dried-blood red and candle amber, no green, no pink, no text, no watermark.

If you'd rather have the smooth hand-painted look of your reference picture than pixels, use this line instead.
The rest of the file stays the same, except you'd make the art with GPT Image or Nano Banana instead of PixelLab.
> Smooth hand-painted top-down game art like a modern mobile RPG, clean shapes, soft shading, 3/4 view, horror mood,
> dark palette of cold slate blue, bone white, dried-blood red and candle amber, no green, no pink, no text, no
> watermark.

**CHARACTER** (PixelLab description field; settings: 64×64 canvas, 4 directions, low top-down view, single-colour
dark outline, medium shading, medium detail):
> {DESCRIPTION}, chibi proportions with a big round head (about 2.5 heads tall), about 44 pixels tall, Pokémon
> FireRed overworld sprite style, dark outline, horror mood.

The character stands on one 32 px tile, and their head reaches into the tile above.

**OBJECT** (32×32 props and tiles):
> {SUBJECT}, a single 32×32 pixel-art game object seen from a 3/4 top-down view, transparent background. + STYLE

**FX** (effect sheets):
> Pixel-art effect animation, {N} frames in one row, {SIZE} per frame: {SUBJECT}, transparent background, crisp
> pixels. + STYLE

**PORTRAIT** (128×128):
> 128×128 pixel-art portrait in the style of a GBA monster-battle sprite, front view: {SUBJECT}, transparent
> background. + STYLE

Every animation sheet has one row per direction, in the order **down, up, left, right**, and one column per frame. If
a tool gives more or fewer frames than listed, keep them; Claude adapts the timing.

---

## 5. Maze tilesets

| File | Where | How |
|---|---|---|
| `tiles/tileset_wake.png` | every floor and wall tile, WAKE | PixelLab Create Tileset (settings below) |
| `tiles/tileset_nightmare.png` | every floor and wall tile, NIGHTMARE | the same settings, made after WAKE is approved |
| `tiles/floor_wake_extra.png` | 4 plain floor variants (a 4×1 strip of 32×32) scattered in for variety | PixelLab create tiles, or RD Tile variations, from the WAKE floor |
| `tiles/floor_nightmare_extra.png` | the same for NIGHTMARE | the same |

**tileset_wake.png** (Top-Down, 32×32):
- **Lower terrain:** *dark slate-blue cobblestone dungeon floor, small rounded stones, damp, dim and low contrast*
- **Upper terrain:** *the top of a thick rubble wall: jagged grey rocks rimmed with pale rounded capstones along its
  edges*
- **Transition:** *a rough rock wall face dropping down to the floor, dark mortar, a soft dark shadow at its base*
- **Settings:**
  - Side wall thickness: on, medium. The face should be clearly visible but shorter than the top.
  - Edge shape: square, slight roundness, low raggedness.
  - Transition size: small.
  - Export: Wang, 16 tiles, and keep the `.json`.

**tileset_nightmare.png** (same settings):
- **Lower terrain:** *dark maroon flagstones soaked in old blood, black cracks, small dark puddles*
- **Upper terrain:** *the top of a thick wall of piled bones and skulls fused with dark flesh, rimmed with pale bone*
- **Transition:** *a wall face of stacked bones and dried blood running down to the floor, a dark shadow at its base*

**floor_wake_extra.png:** 4 floor tiles that match the WAKE floor: *one with a thin crack, one with a loose sunken
stone, one with a small puddle, one with a dark stain*.

**floor_nightmare_extra.png:** 4 tiles that match the NIGHTMARE floor: *one with a crack, one with a small blood
puddle, one with scattered teeth, one with a dark stain*.

Because both tilesets use the same standard 16-tile layout, their walls line up tile for tile. The flip just swaps
the image.

---

## 6. Maze objects

All are 32×32 unless noted, and both worlds share them unless noted.

| File | What | Frames | Speed |
|---|---|---|---|
| `objects/obj_start.png` | where the run begins: *a chalk circle on the floor with two melted candles* | 4 (candle flicker) | 6 fps |
| `objects/obj_exit.png` | the way out: *a stone stairway going down into warm golden light, set into the floor* | 4 (the light shimmers) | 6 fps |
| `objects/obj_salt_circle.png` | a safe zone: *a ring of white salt poured on the floor with small runes* | 1 | - |
| `objects/obj_spirit_candle.png` (16×16) | 4 of these stand around each salt circle: *a short white candle burning a pale spirit-blue flame* | 4 (flicker) | 8 fps |
| `objects/trap_wake.png` | a breaking floor, WAKE: 6 tiles in a row. *(1) a normal floor tile with one faint hairline, (2) a web of cracks, (3) to (5) the tile shaking, dust puffing, chunks sinking, (6) a dark pit with broken edges and a faint red glow far below* | 6 | 10 fps for 3 to 5 |
| `objects/trap_nightmare.png` | the same 6 tiles on the NIGHTMARE floor | 6 | 10 fps |
| `objects/obj_torch.png` | *an iron torch bracket with a burning flame, mounted on a wall face* | 4 (flame) | 8 fps |
| `objects/props_wake.png` | 8 floor props in a 4×2 sheet: *skull and bones, a cluster of unlit melted candles, a broken porcelain doll, a heap of rusty chains, a corner cobweb, scattered torn papers, a cracked mirror shard, a small dead rat* | 1 each | - |
| `objects/props_nightmare.png` | 8 props in a 4×2 sheet: *a rib cage, a pile of skulls, a bloody handprint, an eyeless doll, a cracked bloody mask, a rusty axe stuck in the floor, burning black candles, deep claw marks* | 1 each | - |

How the code uses them:
- **Safe zone countdown:** the 4 spirit candles go out one by one as the safe zone's time runs out, so the countdown
  lives in the world instead of a bar.
- **Torches** only go on wall faces that point down the screen. In NIGHTMARE their flame is tinted red.
- **Props** never block a path. Dead ends get the creepiest one, which doubles as a landmark.

---

## 7. The runners (new)

| Name | Look | Silhouette (must read in one glance) | Light |
|---|---|---|---|
| **Lumi** (default) | a small girl in a too-big amber-yellow raincoat with the hood up, black rubber boots, holding an old oil lantern | rounded hood, lantern | warm amber |
| **Owen** | a pale boy in a white hospital gown, bandages wrapped around his head over one eye, barefoot, holding a candle in a tin holder | bandaged head, gown | white candlelight |
| **Sora** | a quiet girl with long straight black hair, a cream knit cardigan over a dark skirt, a white fox mask pushed up on the side of her head, holding a paper lantern on a stick | long hair, fox mask, lantern on a stick | soft paper-lantern glow |

Files for each runner (`chars/<name>_<animation>.png`, 64×64 frames):

| File | Directions × frames | Speed | Plays when |
|---|---|---|---|
| `<name>_idle.png` | 4 × 4 | 4 fps | standing still: breathing, the light flickering |
| `<name>_walk.png` | 4 × 6 | 10 fps | moving |
| `<name>_scared.png` | down only × 2 | 8 fps | a devil is within 3 tiles (a "!" pops over their head) |
| `<name>_caught.png` | 1 × 6 | 10 fps | the devil gets them |
| `<name>_fall.png` | 1 × 6 | 12 fps | the floor collapses under them |
| `<name>_escape.png` | 1 × 4 | 8 fps | reaching the exit |
| `<name>_portrait.png` | 128×128, one image | - | the runner picker, and the escape and caught screens |

**Descriptions for PixelLab** (the CHARACTER template, §4):
- **Lumi:** *a small girl in a too-big amber-yellow raincoat with the hood up, black rubber boots, holding an old oil
  lantern with a warm glow in her right hand, nervous wide eyes*
- **Owen:** *a pale thin boy in a white hospital gown, white bandages wrapped around his head covering one eye,
  barefoot, holding a lit candle in a small tin holder*
- **Sora:** *a quiet girl with long straight black hair, a cream knit cardigan over a dark skirt, a white fox mask
  pushed up on the side of her head, holding a glowing paper lantern on a short stick*

**Animate with text** (one line each, the same for all three; put the runner's name first):
- **scared:** *trembling, hugging the light close, glancing left and right*
- **caught:** *a black clawed hand grabs from behind, the kid gasps and is dragged backwards into the dark, the light
  drops and goes out*
- **fall:** *the floor cracks under the kid, they wobble, drop through the hole and shrink away into the dark*
- **escape:** *the kid steps forward into warm light and fades into it*

**Portrait** (the PORTRAIT template): *{the runner's description}, from the chest up, looking scared but brave, lit by
their own light from below*.

---

## 8. The devils (new: one per 25 stages)

| Stages | Devil | Look | How it moves | Canvas |
|---|---|---|---|---|
| 5–25 | **The Hollow Man** | an impossibly tall, thin figure in a ragged black suit, arms hanging past its knees, a cracked white porcelain face with a stitched-shut grin and two empty black eye holes with tiny white pupils | jerky stop-start steps, its head tilting | 64×64, nearly 2 tiles tall |
| 26–50 | **The Crawler** | a pale starved figure crawling on all fours with its body bent backwards like a spider, long black hair hanging over its upside-down face, too many joints | fast scuttling, low to the ground | 64×64, wide and low |
| 51–75 | **The Butcher** | a hulking brute in a filthy blood-stained apron, a goat skull for a head with two glowing red pinprick eyes, dragging a rusty meat hook on a chain that sparks on the stone | slow, heavy, unstoppable | 64×64, bulky |
| 76–100 | **The Horned King** (the Devil itself) | huge, charred black skin cracked with glowing ember veins, great curved horns forming a crown, torn wings wrapped around it like a cloak, burning white-hot eyes | glides more than walks, trailing smoke | 128×128, towers over the walls |

Files for each devil (`chars/<devil>_<animation>.png`; file names `hollow`, `crawler`, `butcher`, `king`):

| File | Directions × frames | Speed | Plays when |
|---|---|---|---|
| `<devil>_idle.png` | 4 × 4 | 4 fps | waiting: twitching, breathing |
| `<devil>_walk.png` | 4 × 6 | 8 fps (the Crawler 12) | hunting |
| `<devil>_spawn.png` | 1 × 8 | 10 fps | appearing: rising out of a black pool in the floor |
| `<devil>_notice.png` | down only × 3 | 8 fps | it spots you: its head snaps toward you and it screeches |
| `<devil>_catch.png` | 1 × 5 | 12 fps | it lunges and grabs |
| `<devil>_portrait.png` | 128×128, one image | - | the reveal of a new devil, and the caught screen |

**Descriptions for PixelLab** (CHARACTER settings, but drop "chibi" and "big round head"; these should look wrong):
- **hollow:** *an impossibly tall thin figure in a ragged black suit, long pale arms hanging past its knees, a cracked
  white porcelain face with a stitched-shut grin and two empty black eye holes with tiny white pupils, about 60
  pixels tall, horror*
- **crawler:** *a pale starved figure crawling on all fours with its body bent backwards like a spider, long black
  hair hanging over its upside-down face, bony limbs with too many joints, low and wide, horror*
- **butcher:** *a hulking brute in a filthy blood-stained apron, a goat skull for a head with two glowing red pinprick
  eyes, a rusty meat hook on a chain dragging behind it, heavy and wide, horror*
- **king** (128×128 canvas): *a towering demon with charred black skin cracked by glowing ember veins, great curved
  horns forming a crown, torn bat wings wrapped around its body like a cloak, burning white-hot eyes, smoke rising off
  it, about 110 pixels tall, horror*

**Animate with text:**
- **spawn:** *a black pool spreads on the floor and the devil slowly rises out of it, eyes lighting up last*. For the
  Crawler: *crawls up out of a crack in the floor*.
- **notice:** *its head snaps toward the viewer and it lets out a screech, body shaking*
- **catch:** *it lunges forward with its arms outstretched and grabs*

**Portrait** (PORTRAIT template): *{the devil's description}, a close-up of the face and shoulders, staring straight at
the viewer, deeply unsettling*.

---

## 9. Effects and emotes

| File | Frames × size | What |
|---|---|---|
| `fx/fx_emotes.png` | 6 × 16×16 | speech-bubble emotes: *"!" (spotted), "?" (lost), "…" (waiting), a sweat drop (scared), a skull (danger), a small heart (revived)*. The code makes them pop. |
| `fx/fx_dust.png` | 4 × 16×16 | *a small grey dust puff*: footsteps on stone, trap dust |
| `fx/fx_smoke.png` | 6 × 64×64 | *a burst of black smoke with red embers*: a devil appearing or vanishing |
| `fx/fx_debris.png` | 6 × 32×32 | *stone chunks breaking apart and falling into darkness*: a trap collapsing |
| `fx/fx_sparkle.png` | 4 × 16×16 | *a small gold four-point sparkle*: the exit, stage cleared, a trophy |
| `fx/fx_wisp.png` | 4 × 16×16 | *a pale blue ghost wisp drifting*: NIGHTMARE air |
| `fx/fx_drip.png` | 4 × 16×32 | *a blood drop running down a wall and falling*: NIGHTMARE walls |
| `fx/fx_flip.png` | 6 × 64×64, seamless | *the floor cracking open with red light in the cracks*: the world flipping. Tier 3; a code wipe stands in until then. |

**Made in code (no file):** the darkness and light circles, the flip wipe (in the style of Pokémon's battle
transition), screen shake, the red flash, the heartbeat vignette, and the devils' eyes drawn over the dark.

---

## 10. The in-run HUD and overlays

| File | Size | What |
|---|---|---|
| `ui/ui_textbox.png` | 48×48 (stretches in 9 parts; corners 16 px) | a Pokémon-style text box: *a dark slate fill, a bone-white double border, tiny rivets in the corners*. Used for the stage name, the pause menu and every in-run message. |
| `ui/ui_sign.png` | 96×32 (stretches in the middle) | *a rotten wooden plank sign with rusty nails*: the stage name pop-up, like Pokémon's location sign |
| `ui/ui_cursor.png` | 2 × 16×16 | *a small bone-white arrow* that bobs next to the chosen menu item |
| `ui/ui_icons.png` | 16 × 16×16 (an 8×2 sheet) | *pause, play, a little maze (stage), an hourglass (timer), a flag (checkpoint), a heart, an empty heart, a skull (danger), a trophy, a house, a retry arrow, a film reel (watch an ad), a check mark, an X, a speaker on, a speaker off* |
| `ui/ui_timebar.png` | 64×12 | *a thin stone bar frame with an hourglass at the left end*, shaped like Pokémon's HP bar. The code draws the fill: bone, then amber, then red. |
| `ui/ui_dpad.png` | 96×96 | *a Game Boy-style directional pad carved from dark stone, bone-white arrows* |
| `ui/ui_dpad_press.png` | 96×96 | the same pad with the up arm pressed in and glowing amber (the code rotates it for each direction) |
| `ui/ui_joystick.png` + `ui/ui_knob.png` | 96×96 + 48×48 | *a round dark stone joystick base with four carved arrows*, and *a bone-white stone knob* |
| `ui/ui_button.png` | 2 × 32×32 | *a round dark stone button*, normal and pressed (for pause) |

**Fonts** (free, OFL, Google Fonts): **Press Start 2P** for titles and numbers, **Pixelify Sans** for text.

**Overlays** (built in code from the files above, no extra art needed):
- **Stage start:** `ui_sign` slides down at the top left for 2 s, showing the stage number and name, for example
  "STAGE 12 · DECISIONS".
- **A new devil** (stages 5, 26, 51 and 76): the screen wipes to black like a Pokémon battle start, and the devil's
  portrait slides in from the right with a text box: "THE HOLLOW MAN is hunting you."
- **Pause:** a text box on the right like Pokémon's start menu, with RESUME and ABANDON and the bobbing cursor.
- **Caught:** a red flash, the devil's portrait lunges in, then "THE BUTCHER caught you!" with REVIVE and RESTART in a
  yes/no box.
- **Fell:** the runner's fall animation, then "The floor gave way."
- **Stage cleared:** the escape animation, sparkles, "STAGE CLEARED" in Press Start 2P, and +1 trophy.
- **Stage 100:** a Hall of Fame screen with the runner's portrait and all four devil portraits greyed out, with gold
  sparkles.

---

## 11. Sounds (optional, ElevenLabs sound effects)

Your current gameplay sounds stay. These four suit the new style; save them in `assets/audio/`.

| File | Prompt |
|---|---|
| `sfx_spotted.mp3` | a short sharp retro game alert sting with a distorted low growl under it, 0.6 seconds |
| `sfx_devil_reveal.mp3` | a creepy 8-bit chiptune encounter jingle that slows down and detunes into a deep horror drone, 3 seconds |
| `sfx_step_stone.mp3` | a soft single footstep on damp stone, dry, 0.2 seconds |
| `sfx_floor_crack.mp3` | old stone cracking and crumbling with a hollow echo below, 1 second |

---

## 12. Order of work

**Tier 1: stages 1–25 look finished.**
- Fonts: Press Start 2P, Pixelify Sans.
- Tiles: `tileset_wake`, `tileset_nightmare`, both floor extras.
- Objects: `obj_start`, `obj_exit`, `obj_salt_circle`, `obj_spirit_candle`, `trap_wake`, `trap_nightmare`.
- Lumi: idle, walk, scared, caught, fall, escape.
- The Hollow Man: idle, walk, spawn, notice, catch.
- Effects: `fx_emotes`, `fx_dust`, `fx_smoke`, `fx_debris`, `fx_sparkle`.
- HUD: `ui_textbox`, `ui_icons`, `ui_dpad` + `ui_dpad_press`, `ui_joystick` + `ui_knob`, `ui_button`.

**Tier 2: the full cast.**
- Owen and Sora, every animation.
- The Crawler, the Butcher and the Horned King, every animation.
- All 7 portraits.
- `obj_torch`, both prop sheets.
- `ui_sign`, `ui_cursor`, `ui_timebar`.

**Tier 3: extra atmosphere.** `fx_wisp`, `fx_drip`, `fx_flip`, and the sounds.

Approve the anchors first (the WAKE tileset and Lumi's walk), then use them as references for everything else.

---

## 13. Check each file before you send it

- [ ] Real pixels: at 800% zoom every pixel is a clean square, with no blur and no soft edges.
- [ ] Only Night 32 colours: no green, no pink, no neon.
- [ ] Exact size: 32×32 tiles, 64×64 character frames (128×128 for the Horned King and the portraits).
- [ ] The feet sit in the same spot in every frame, so the character doesn't jitter.
- [ ] One-second test at real size (64 px): can you tell Lumi, Owen and Sora apart, and every devil apart?
- [ ] Tilesets: build a small test maze in PixelLab's preview or Sprite Fusion. The walls must join everywhere with no
      gaps, and the rock face must show on walls that face down.
- [ ] The devils look *wrong* next to the kids: bent proportions, glowing eyes.

---

## 14. Notes for the wiring session (Claude)

- **Fallbacks:** every file loads with one, so a missing file keeps today's drawing (as in `_loadExitPortalSprite` in
  `game_screen.dart`).
- **Block maze:** a maze of N×N cells becomes a (2N+1)×(2N+1) tile grid. Cell (r, c) maps to tile (2r+1, 2c+1);
  open edges become floor tiles and closed edges, plus every corner, become wall tiles. The game logic stays
  cell-based, and only the drawing changes. One logical step moves 2 tiles, playing one walk cycle per tile.
- **Autotiling:** use a dual grid (offset by half a tile). Each drawn tile reads its 4 corner cells (wall or floor)
  and picks one of the 16 Wang tiles by the order in PixelLab's `.json`. The flip just swaps the WAKE and NIGHTMARE
  images, because the tile indices match.
- **Camera:** follow the runner with light smoothing, clamped to the maze. Scale by a whole number
  (`floor(screenWidthPx / (32 × 11))`), draw with `FilterQuality.none`, and snap the camera to whole art pixels, so
  nothing shimmers.
- **Draw order:**
  1. Bake the floor and walls into one image per maze and per world.
  2. Draw the actors sorted by their y position, then the wall rows in front of them.
  3. Draw the darkness layer, with light circles about 3.5 tiles across for the runner and 2 tiles for torches.
  4. Draw the devils' eyes and the emotes on top of the darkness.
- **Never rotate or non-integer-scale a pixel sprite.** Motion comes from the frames, plus at most a 1-pixel bob.
- **Devil by band:** stages 5–25 the Hollow Man, 26–50 the Crawler, 51–75 the Butcher, 76–100 the Horned King. Play
  the reveal overlay on the first stage of each band.
- **Runners:** rename the three `_CharacterOption` entries in `fear_flip_app.dart` to Lumi, Owen and Sora, with prefixes
  `lumi`, `owen` and `sora`.
- **`pubspec.yaml`:** drop the old `*_frames/` lines, which point at folders that are gone, and add the new folders.
- **Camera:** done on 11 Oct (§2). When the art arrives, it replaces the stand-in drawing in `maze_painter.dart`.
  `MazeCamera` already places every cell, so traps, safe zones, the exit and the trap death all line up with it.

---

## 15. Sources

- PixelLab, [Create tileset](https://www.pixellab.ai/docs/tools/create-tileset): top-down tilesets at 16, 24 or 32 px
  from a lower terrain, an upper terrain and a transition, with a side wall thickness option, exported as Wang,
  dual-grid or 3×3.
- PixelLab, [Rotate](https://www.pixellab.ai/docs/tools/rotate) and [API](https://api.pixellab.ai/v2/docs): characters in
  8 directions at 16-128 px, and walk animation templates priced from 64×64.
- PixelLab, [tileset options](https://www.pixellab.ai/docs/options/tileset): 16-tile Wang sets for square top-down.
- Scenario, [Retro Diffusion models](https://help.scenario.com/en/articles/retro-diffusion-models-the-essentials/):
  RD Tile, and RD Animation for 4-direction walk cycles and idles.
- [Sprixen comparison](https://sprixen.com/blog/best-ai-sprite-generators-2026): PixelLab is weaker at 16×16, which
  is why this file uses 32 px.
- [PokéCommunity spriting tutorial](https://www.pokecommunity.com/threads/spriting-tutorials-pokemon-and-trainer.176686/page-9):
  FireRed trainer sprites have subdued colours, large round heads and are seen from above.
- [The Cutting Room Floor: Pokémon FireRed and LeafGreen](https://tcrf.net/Pokémon_FireRed_and_LeafGreen).
