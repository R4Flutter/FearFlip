# FearFlip 3D: asset prompts for the whole game

Every visual the game currently draws with a stand-in (code-built boxes, flat colours, rough AI meshes) is listed
below, judged from in-game screenshots on 7 Oct 2026. Menu and death-screen art already looks good and is covered by
`images/menu/PROMPTS.md`.

**How delivery works.** Generate each file, save it in the folder shown with the exact name, and tell Claude.
Claude wires each slot with a fallback, so a missing file never breaks the game. Audio is drop-in: the files already
exist under those names, so replacing one needs no code change at all.

## Ground rules for every prompt

- **2D art style line** (cards, icons, overlays): *dark fantasy horror game art, semi-realistic painterly style,
  crimson red + deep violet + ember orange, volumetric fog, rim light, no text, no UI, no watermark.*
- **Tileable materials:** seamless, flat even lighting, orthographic (straight-on), no shadows, no perspective, no
  vignette. If the tool has a "tiling" switch (Midjourney `--tile`, Leonardo "Tiling", SD tiling), turn it on.
- **Glow art without transparency:** if the tool can't make a transparent PNG, paint glowing things on **pure black**
  (Godot adds them, so black disappears). Paint dark marks like cracks and stains on **pure white** (Godot multiplies
  them, so white disappears).
- **Tintable glow:** circles and sparks are painted **white/pale**, so Godot can colour them per world and state
  (blue WAKE, red NIGHTMARE, green "exit open").
- **3D models:** generate a concept image first with the given prompt (plain white background, three-quarter view),
  then use image-to-3D (Meshy / Tripo, the tools behind the current models). Settings: low-poly/remesh on, PBR
  textures at 1K (2K only for the Devil), real-world size, Y-up, pivot at the base centre. Export GLB.
- **Web budget:** the whole web build should stay under ~20 MB. Ship albedo maps as 1024px JPG and normal maps as
  1024px PNG; keep models at or under the triangle counts given.
- **Normal/roughness maps:** take them from the generator if it offers PBR. Otherwise send only the albedo and Claude
  will derive the rest. Plan B for any tileable material: free CC0 libraries (ambientCG, Poly Haven) often beat AI here.

## Status (8 Oct 2026)

**Latest check: see `MISSING_ASSETS.md`** (what is in the game, what is still missing, all prompts in one file).

- **In the game:** everything delivered so far: world materials, decals, the five models (cut to budget in Blender),
  HUD and overlay art, the FX sheet, card art, card frame, pick backdrop, omen sigils and Oswald. Every slot loads
  only when its file exists (art is git-ignored), so a fresh checkout shows the code-built stand-ins.
- **Still to generate:** `static.png`; the act cards, padlock and act-cleared burst; the P5 hub art and the flashlight
  cards; optionally a handprint decal on white, new audio and animated characters.

## Priority (what removes the most ugliness first)

0. Card picker: `card_frame.png` + `pick_backdrop.png` (`images/cards/PROMPTS.md`), seen after every floor.
1. World materials (§1): on screen every single frame.
2. Chest + exit circle, safe circle, cracked-floor decals (§2, §3).
3. Key model + key icon (§3, §4).
4. FX sprite sheet, NIGHTMARE overlay, ceiling lamp (§3–§5).
5. Optional / later: Devil v2, player model, Gate and Sanctuary models (Phase 3), audio (§6).

---

## 1. World materials (replace the flat "Tron box" walls, floor and ceiling)

Folder `godot/assets/textures/world/`. 1024x1024 each. Names: `<name>_albedo.jpg` (+ `_normal.png`, `_rough.jpg` if
you have them). One tile covers one 2.4 m maze cell (walls are 2.8 m tall).

**wake_wall**
> Seamless tileable texture of an old underground maze wall built from large cold grey stone blocks with thin mortar
> lines, damp patches, faint water streaks, moss in a few cracks, chipped edges. Cold neutral grey with a faint blue
> tint. Semi-realistic with a slightly painterly finish. Flat even lighting, straight-on orthographic view, no
> shadows, no perspective, no vignette, no text, square.

**wake_floor**
> Seamless tileable texture of worn square stone floor tiles in a dark underground corridor, uneven grout, grime,
> scuffs, a few hairline cracks, a faint damp sheen in places. Dark slate grey with a cold blue undertone.
> Semi-realistic, slightly painterly. Flat even lighting, top-down orthographic, no shadows, no perspective, no text.

**wake_ceiling**
> Seamless tileable texture of a low concrete ceiling with water stains, rust drip marks and small patches of
> peeling paint. Cold grey. Semi-realistic, slightly painterly. Flat even lighting, orthographic, no shadows, no
> perspective, no text.

**nightmare_wall**
> Seamless tileable texture of the same stone block wall corrupted by hell: dark red organic veins and flesh-like
> growths spreading over blackened, scorched stone, dried blood streaks, thin glowing ember-orange cracks along the
> mortar lines. Deep crimson, black and dull orange. Semi-realistic, slightly painterly. Flat even lighting,
> orthographic, no shadows, no perspective, no text.

**nightmare_floor**
> Seamless tileable texture of charred black stone floor tiles with dried blood pooled in the grout, thin glowing
> ember-orange cracks, scattered ash. Black, crimson and ember orange. Semi-realistic, slightly painterly. Flat even
> lighting, top-down orthographic, no shadows, no perspective, no text.

**nightmare_ceiling**
> Seamless tileable texture of a cracked blackened ceiling with dark red veins and drips spreading across it and a
> faint ember glow inside the cracks. Semi-realistic, slightly painterly. Flat even lighting, orthographic, no
> shadows, no perspective, no text.

**wall_trim** (optional: the strips at the top and foot of each wall, now neon lines)
> Seamless horizontally tileable strip of worn dark iron skirting with rivets, rust and grime, 4:1 wide strip.
> Flat even lighting, orthographic, no shadows, no text.

---

## 2. Floor decals (safe circles, the exit, cracked floors, set dressing)

Folder `godot/assets/textures/decals/`. 1024x1024, centred, top-down.

**safe_circle.png** (replaces the neon torus ring). White glow on pure black, tinted in Godot.
> Top-down view of a protective ward circle drawn on a stone floor: two concentric rings of pale white light filled
> with ancient runes, a simple eye-shaped ward symbol in the centre, soft glow and faint light mist. Perfectly
> circular and symmetrical, centred, pure black background, no perspective, no letters.

**exit_circle.png** (replaces the flat red disc under the chest). White glow on pure black, tinted red (locked) / green (open).
> Top-down view of an ornate summoning circle on a stone floor: a thorny ring of runes with three keyhole symbols
> evenly spaced around it and an empty centre for a chest to stand on. Pale white glowing lines, soft glow, perfectly
> circular and symmetrical, centred, pure black background, no perspective, no letters.

**crack_hairline.png** (the early warning that a floor tile is weak). Black on pure white, multiplied in Godot.
> Top-down view of fine hairline cracks spreading from the centre of a square stone floor tile to its edges, thin
> black jagged lines, subtle, square composition, pure white background, no shading, no perspective.

**crack_glow.png** (the cracked state: molten light through the seams). Glow on pure black, added in Godot.
> Top-down view of the glowing seams of a square stone floor tile broken into five jagged plates: wide ember-orange
> molten light shining up through the gaps, bright at the centre and fading toward the edges, plates themselves
> pure black, square composition, pure black background, no perspective.

**decal_scratches.png** (optional NIGHTMARE wall dressing). Black on pure white.
> Four long deep claw scratch marks gouged diagonally into stone, black jagged grooves with chipped edges, isolated,
> pure white background, no shading.

**decal_blood.png** (optional). Dark red on pure white.
> Top-down view of a dried dark red blood smear trailing across a floor with a few drips, isolated, pure white
> background, no shading, no perspective.

**decal_handprint.png** (optional). Dark red on pure white.
> A single dried dark red bloody handprint with dragged fingertips, front view, isolated, pure white background, no
> shading.

---

## 3. 3D models

Folder `godot/assets/models/`. GLB, PBR 1K, metres, Y-up, pivot at the base centre.

**chest.glb** (the exit; replaces the box-built chest). About 9k triangles max. 0.9 m wide, 0.6 m deep, 0.6 m tall.
Front faces +Z. Ideal: the lid as a separate object named `Lid`, hinged on its back edge. If the generator fuses
everything, Claude can split the lid or keep animating the current code lid.
> Game asset concept, three-quarter front view: a heavy iron-banded dark oak treasure chest with three ornate iron
> lock plates side by side across the front, each with a large keyhole; rounded lid with iron straps and studs;
> worn, scratched, dark fantasy horror style, semi-realistic. Isolated on a plain white background, even studio
> lighting, no shadow on the background.

**key.glb** (replaces the current key, which reads as a noisy blob). About 3k triangles max, 0.3 m long. It needs a
clean, readable silhouette from 5 m away; Godot adds the glow in the key's world colour.
> Game asset concept, side view: an ornate antique skeleton key with a long shaft, a bow shaped like a small horned
> demon skull with one empty gem socket in its eye, and a bit with three square teeth; aged dark iron with worn gold
> edges, bold simple shapes, dark fantasy style. Isolated on a plain white background, even studio lighting.

**ceiling_lamp.glb** (replaces the glowing rectangles on the ceiling). About 1.5k triangles max, 0.35 m tall. The
bulb is made emissive in Godot.
> Game asset concept, three-quarter view: an old industrial caged ceiling lamp, a wire-mesh cage around a single
> bulb, a rusted round metal mounting plate and a short chain, grimy and dented, dark horror style. Isolated on a
> plain white background, even studio lighting.

**devil_v2.glb** (optional). The current Devil reads well but has no animations and a broken rig. About 25k triangles
max, textures 2K, about 2.3 m tall, A-pose. Then auto-rig it on Mixamo (free) and download Idle, Walk, Run, Attack and
Roar. That replaces the procedural run cycle and the re-weighting workarounds in `devil_rig.gd`. Feed the current
Devil and `images/menu/menu_demon.png` in as references so the silhouette survives.
> Character concept, full body front view, A-pose with arms 45 degrees down and legs slightly apart: a tall gaunt
> horned demon with human proportions, long arms ending in clawed hands, cracked charcoal skin with glowing crimson
> veins, visible ribcage, burning red eyes, thin tendrils rising from the shoulders and back, dark fantasy horror,
> semi-realistic. Isolated on a plain white background, even lighting, symmetrical.

**player.glb** (optional; seen in the trap-fall camera and a future death cam). About 20k triangles max, 1.75 m, A-pose,
Mixamo-rigged (Idle, Walk, Run, Fall). Use `images/menu/menu_hero.png` as the image-to-3D reference so the 3D hero
matches the menu.
> Character concept, full body front view, A-pose: a young survivor with messy dark hair and a long red scarf, dark
> grey jacket over a black shirt, utility belt, dark cargo pants and red-and-black combat boots, a flashlight clipped
> to the shoulder strap, semi-realistic anime-inspired style. Isolated on a plain white background, even lighting,
> symmetrical.

**gate_arch.glb** (Phase 3: the Act Gate on floor 10). About 12k triangles max. It must fit a 2.4 m wide, 2.8 m tall
corridor.
> Game asset concept, front view: a massive gothic gate arch of black stone carved with screaming faces and curling
> horns, cracked and ancient, two rusted iron doors chained shut with a glowing red seal at the centre, dark fantasy
> horror, semi-realistic. Isolated on a plain white background, even lighting.

**sanctuary_altar.glb** (Phase 3: the floor-5 Sanctuary). About 6k triangles max, about 1 m tall.
> Game asset concept, three-quarter view: a small stone shrine altar with melted candles, a cracked bowl holding cold
> blue fire, carved protective runes and a few yellowed paper notes pinned under small stones, calm but eerie, dark
> fantasy, semi-realistic. Isolated on a plain white background, even lighting.

### 3b. Landmarks (plans/07)

Things to remember at the maze's junctions ("left at the statue, right at III"). Today they're code stand-ins: a
grey capsule on a box, three brown boxes, a red sans-serif numeral. The coloured and flickering lamps reuse
`ceiling_lamp.glb` and need nothing new. Each slot below loads as soon as the file exists.

**landmark_statue.glb** (`models/`). About 5k triangles max, 2.0 m tall including its plinth, footprint 0.6 x 0.6 m or
smaller (it stands in a corridor corner). Front faces +Z. It needs a silhouette you recognise from 6 m away in fog; a
candle at its feet is added in Godot.
> Game asset concept, three-quarter front view: a weathered stone statue of a tall thin hooded figure standing on a
> plain square plinth, both hands covering its face as if weeping, long robe falling straight to the plinth, cracked
> grey stone with dark water stains and a little moss, bold simple silhouette, dark fantasy horror, semi-realistic.
> Isolated on a plain white background, even studio lighting, no shadow on the background.

**landmark_debris.glb** (`models/`). About 4k triangles max, 0.8 m tall, footprint 0.7 x 0.7 m or smaller. Front +Z.
> Game asset concept, three-quarter view: a small heap of broken old furniture piled in a corner: a smashed wooden
> chair on its side, two splintered crates stacked crookedly, a torn grey cloth draped over them and a rusty chain
> hanging off the top, dark grimy wood, dark horror style, semi-realistic. Isolated on a plain white background, even
> studio lighting.

**glyph_1.png … glyph_12.png** (`textures/decals/`). 512x512, **transparent PNG** (if the tool can't do
transparency, use pure white and say so, and Claude will cut it out). Painted on the wall at 0.9 m, so keep a margin of
about 10%. One numeral per file: `glyph_1` = I, `glyph_2` = II … `glyph_12` = XII (big floors use all twelve). Same
brush and colour on all twelve so they read as one set. Image tools often misspell long numerals (VIII, XII): check
each one, regenerate the wrong ones, and skip any that won't come out right, since the game paints a missing numeral
itself. The prompt for III (swap in the other numerals):
> The Roman numeral III hand-painted on a wall in thick dark dried-blood red paint with a wide brush, rough uneven
> strokes, drips running down from the bottom of each stroke, a few splatters around it, front view, flat, centred,
> isolated on a transparent background, no wall texture, no shadow, no other text.

### 3c. Paper map (plans/07)

> **Superseded (9 Oct 2026) by `MAP_ASSETS/REQUIREMENTS.md`** (code-built paper curl, grip-pose hand, snap sound).

M takes the map out. The right hand pulls the rolled map from the back pocket of the cargo pants, the left hand takes
its free edge, both hands pull it open left to right, and it comes up to the eyes to read. Today the hands are skin
boxes with dark sleeves, the roll is a plain tube and the sheet is flat beige. The game draws the maze on the sheet
itself, so the paper art must leave its centre plain. Each slot loads as soon as the file exists.

**map_hand.glb** (`models/`). About 6k triangles max, 1K textures. **One right hand** and forearm, cut off just below
the elbow; the game mirrors it for the left hand. 42 cm from fingertips to the cut end. Pose: a relaxed pinch grip, as
if holding the edge of a sheet of paper, thumb in front and the four fingers together behind it. Orientation if the
tool lets you choose: fingers up (+Y), elbow end down, palm facing left (-X), thumb toward the front (+Z). The sleeve
matches the hero's dark grey jacket (`player.glb`, `menu_hero.png`). If the tool gives a whole arm or two hands,
deliver it anyway and say so: Claude cuts it.
> Game asset concept, side view: a single right human hand and forearm, cut off cleanly just below the elbow, in a
> relaxed pinch grip as if holding the edge of a sheet of paper (thumb in front, four fingers together behind it),
> fingers pointing straight up, the sleeve of a worn dark grey jacket covering the forearm to the wrist, pale skin
> with grime on the knuckles and a few small scratches, short nails, semi-realistic, dark horror game style. Isolated
> on a plain white background, even studio lighting, no body, no shadow, no text.

**map_roll.glb** (`models/`). About 2k triangles max, 1K texture. The map rolled up: 33 cm long, about 5 cm thick,
standing upright (long axis +Y), pivot at the base centre. No string or ribbon, because it unrolls on screen.
> Game asset concept, three-quarter view: one sheet of old yellowed parchment rolled into a loose tube about 33 cm
> long and 5 cm thick, standing upright, the outer edge of the sheet lifting slightly off the roll, ragged torn edges,
> coffee and water stains, faint ink lines showing through, creased and grubby from being carried in a back pocket,
> semi-realistic, dark horror game style. Isolated on a plain white background, even studio lighting, no hands, no
> string, no text.

**map_paper.png** (`images/hud/`). **2048x1536** (4:3), **transparent PNG** (if the tool can't do transparency, use
pure white around the sheet and say so; Claude cuts it out). The blank sheet the maze is drawn on, seen straight on
and filling the frame. **Keep the centre plain**: the maze covers a square over the middle two-thirds of the width
(17% to 83%) and nearly the full height (6% to 94%), so decorate the two side margins only.
> One sheet of aged yellowed parchment seen straight on, flat, filling the frame, an old explorer's map before
> anything is drawn on it: ragged torn edges with a few small burn marks, faint fold creases, water and coffee stains
> and grime gathered near the edges, in the right margin a small faded compass rose with N pointing up, in the left
> margin a few faded illegible pencil scribbles and one dark brown dried-blood thumbprint, the large centre area left
> plain, clean and evenly lit, flat even lighting, no perspective, no shadow, isolated on a transparent background,
> no readable words.

**sfx_map_open.mp3** + **sfx_map_close.mp3** (`audio/`). MP3, peaks around -3 dB, no silence at the start. Use an AI
sound-effect tool (e.g. ElevenLabs Sound Effects) or cut them from CC0 recordings (freesound.org: "paper unroll",
"map paper", "pocket rustle").
- `sfx_map_open.mp3`, **1.7 s** (the whole move, pocket to eyes):
  > A rolled-up paper map pulled out of the back pocket of cargo pants, then unrolled with both hands: a short
  > fabric rustle, then crisp old paper crackling as it unrolls, ending in a soft taut snap as it is held open.
  > Close-up, dry, no music, no voice.
- `sfx_map_close.mp3`, **0.8 s**:
  > An old paper map quickly rolled up and pushed back into the back pocket of cargo pants: a fast paper crinkle,
  > then a short fabric rustle. Close-up, dry, no music, no voice.

---

## 4. HUD and screen overlays

Folder `godot/assets/images/hud/`.

**key_icon.png** (replaces `images/key.png` in the HUD key slots, the minimap and the key halo). 512x512, transparent
or pure black. It must read at 32 px.
> Game UI icon of an ornate skeleton key whose bow is a small horned demon skull with a glowing gem eye, front view,
> bright worn gold with a thick dark outline and a soft inner glow, bold simple shapes, centred, isolated on a pure
> black background, dark fantasy game icon style, no text.

**nightmare_overlay.png** (new; sits faintly over the screen in NIGHTMARE and pulses as the Devil closes in).
1920x1080, pure black. The centre must stay empty.
> Full-screen 16:9 overlay: dark red veins, hairline cracks and thin red smoke creeping in from all four screen edges
> and corners, densest in the corners, the central 60 percent completely empty pure black, painted on a pure black
> background, dark horror, no text.

**flip_warning_overlay.png** (optional; frames the screen during the Flipping Time warning). 1920x1080, pure black.
> Full-screen 16:9 overlay: a jagged red glitch frame around the screen edges, torn scanlines, static noise and
> chromatic split, centre completely empty pure black, painted on a pure black background, no text.

**Font** (no AI needed): download **Oswald SemiBold** from Google Fonts (free, OFL) and save it as
`godot/assets/fonts/ui.ttf`. The menu and death screen already look for that file, and the HUD will be switched to it.

### Added 7 Oct 2026 (from the P4 screenshots: the HUD is bare text floating over the 3D view)

**hud_plate.png** (behind the top-right status plate of icons: floor, cards, world + clock, flip, keys, shards).
720x400 PNG, drawn at its own shape (never stretched), so a new plate must keep that 9:5 shape and its border.
Transparent is best; an opaque plate works too (Godot draws it at about 85% opacity).
> Game HUD backing plate for a dark fantasy horror game, flat front view, a wide rectangle of dark smoky charcoal
> glass with a thin worn blackened-iron border, tiny rivets and small thorn ornaments only in the four corners,
> plain straight edges between the corners, faint inner smoke texture, evenly lit, fills the canvas edge to edge,
> no text, no icons, no watermark.

**minimap_frame.png** (around the minimap and its DEVIL / EXIT readout). 520x612 PNG with a **fully transparent
centre window** (the map shows through it), so use a background remover if your tool can't make transparency. The
window is the middle 480x572 px; the frame is the 20 px band around it.
> Ornate square-ish frame for a game minimap, flat front view, portrait 520x612, blackened iron with thin bone-gold
> filigree, small horned skull ornament at the top centre and a compass "N" notch shape (no letter) at the top, a
> thin divider bar across the frame about 84% of the way down, the whole inside window fully transparent, frame
> band thin and even, no text, no watermark.

**banner.png** (behind the centre messages: floor title, FLOOR CLEARED, ACT CLEARED, PAUSED, "Something woke up").
1536x384 PNG. Paint it as dark marks on **pure white**: Godot multiplies it, so the white vanishes and only the smoke
darkens the scene behind the words.
> A long horizontal band of soft charcoal-black smoke with torn, feathered ends fading to nothing at the left and
> right, densest in the middle, painted on a pure white background, grayscale only, no hard edges, no text.

**keycap.png** + **keycap_wide.png** (optional; the bottom control hints are plain text). 128x128 and 256x128 PNG,
transparent or pure black, blank caps (Godot writes the letter on them).
> A single blank keyboard keycap icon for a dark fantasy game UI, front view, worn dark iron cap with a bone-gold
> rim and a soft inner shadow, the top face completely blank, centred, isolated, no letters, no text.
> (For `keycap_wide.png`, the same keycap twice as wide, like a SHIFT or SPACE key.)

**The plate's icons** (world, flip, floor, chest, shards) and the remaining text spots (minimap readout, pops,
grades, centre titles, control hints): prompts in `MISSING_ASSETS.md` §0 and §4. The menu's icons stand in until then.

---

## 5. FX sprites

Folder `godot/assets/textures/fx/`.

**fx_sheet.png** (replaces the tiny cubes used as dust and the plain gradient sparkles). 512x512, a 2x2 grid of
256px cells, white/pale so it can be tinted, pure black background.
> A 2x2 sprite sheet of soft game particles on a pure black background, each centred in its own square cell: top-left
> a round soft dust mote, top-right a bright ember spark with a short motion streak, bottom-left a wispy smoke puff,
> bottom-right a four-point glint star. White and pale grey only, soft edges, no text.

---

## 6. Audio (optional; several of the current clips look like synthesized placeholders)

The live sound effects come in identical-length groups: both ambient loops are 481,115 bytes, and win, lose and the
flip warning are 48,945 bytes each. That pattern points to generated stand-ins. Use an SFX generator (ElevenLabs
Sound Effects, Stable Audio) or an instrumental music generator for loops. Confirm the license allows commercial use,
and never use meme or soundboard clips. Save over the same file in `godot/assets/audio/`; no code change is needed.

| File | Prompt |
|---|---|
| `sfx_ambient_calm.mp3` (WAKE + menu) | Dark ambient drone loop for a horror maze: distant low hum, faint dripping water, air moving through stone corridors, a rare far-off metallic creak; no melody, no drums; seamless 60-second loop |
| `sfx_ambient_intense.mp3` (NIGHTMARE) | Oppressive horror drone loop: deep pulsing sub-bass, distorted low strings, faint whispers and breathing, irregular metallic scrapes, constant tension with no climax; seamless 60-second loop |
| `sfx_flip.mp3` | Reality-flip whoosh: a reversed cymbal swell into a deep thud with a glassy shimmer tail, 0.8 s |
| `sfx_flip_denied.mp3` | Short dull negative thunk with a muffled buzz, like hitting a locked door, 0.3 s |
| `sfx_flipping_warning.mp3` | Ominous warning: three accelerating heartbeat-like pulses under a distorted siren swell, 3 s |
| `sfx_sigil.mp3` (key pickup) | Old iron key picked up: a bright metallic clink plus a short magical chime with sparkle, 0.6 s |
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

---

## Not assets, but they make it look worse (code fixes, not done yet)

- **Web size:** `character/character1.glb` (62 MB) and `character/devil.glb` (58 MB), plus their textures, are no
  longer loaded by any scene or script. Godot still exports them by default, which breaks the ~20 MB web budget.
  Delete or exclude them (needs your OK).
- **Wall banding:** horizontal stripes on far walls are shadow acne from the flashlight; raising its shadow bias fixes it.
- **Spawn view:** the player spawns facing a wall corner, so the first frame is black plus a flashlight circle. Face
  down the open corridor instead.
- **HUD font:** the HUD uses Godot's default font while the menu uses Impact. Switch it to `ui.ttf` once the font is in.
- **Death screen:** the HUD (minimap, status, hints, omens) stays drawn on top of GAME OVER, and the Devil tip is cut
  off mid-sentence ("...or stand in a safe"). Hide the HUD on death and wrap the tip.
- **Pause:** a line of mint-green text over the live view, with no dim. Dim the view and centre it.
- **Message colour:** floor title, FLOOR CLEARED and PAUSED are mint green, which clashes with the red/violet look.
  Use bone/gold.
- **Flipping Time warning:** dark red text on the red NIGHTMARE view is barely readable. Brighten it, add an outline
  and add the delivered overlay.
- **Pickers:** the door cards cover the minimap's EXIT readout, and the busy HUD shows through every pick. Hide or dim
  the HUD while choosing.
- **Card stand-in:** with no art, a card's top 60% is empty. Until art lands, centre the text block.
