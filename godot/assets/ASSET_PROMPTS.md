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

## Priority (what removes the most ugliness first)

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
