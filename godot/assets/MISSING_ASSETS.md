# FearFlip 3D: missing and redo assets (checked 7 Oct 2026)

Every file in `godot/assets/new_assets/` was checked for size, background, transparency, tiling and (for models)
triangle count. Everything you still need to make is in this file, so you don't have to dig through the older
prompt files. Save new files in `godot/assets/new_assets/` with the exact names below; Claude moves them into
place and wires them.

## What's good already (no action)

card_frame, pick_backdrop, omen_sigils, hud_plate, minimap_frame (transparent centre, as asked), banner (on white,
as asked), keycap (square + wide in one image is fine), key_icon, wake_wall / wake_floor / wake_ceiling (seamless),
wall_trim, safe_circle, exit_circle, crack_hairline, crack_glow, decal_scratches, nightmare_overlay,
flip_warning_overlay, fx_sheet, Oswald.zip (has SemiBold). The thin grey grid lines in omen_sigils and fx_sheet are
fine: Claude crops each cell slightly.

---

## 1. Redo: problems in delivered files

### 1a. 3D models are ~200x too heavy (most important)

Each model is about **1.9 million triangles** with 4K textures, and each file is ~60 MB. The game budget is a few
thousand triangles per prop and ~20 MB for the **whole** web build. The key already in the game
(`assets/assets/key.glb`) has the same problem, and the floor shows several keys at once. Don't regenerate them:
re-export the same models from Meshy / Tripo with these settings.

- **Meshy:** open the model, *Remesh*, choose **Triangle**, set the target count below, keep *Quad* off, then
  *Download → GLB* with texture resolution **1024 (1K)**.
- **Tripo:** *Smart Low Poly* (or *Retopology*) with the target count below, then export GLB with 1K textures.

| File (same name again) | Target triangles | Real size |
|---|---|---|
| `chest.glb` | 8,000 | 0.9 m wide, 0.6 m deep, 0.6 m tall |
| `key_new.glb` | 3,000 | 0.3 m long |
| `ceiling_lamp.glb` | 1,500 | 0.35 m tall |
| `gate_arch.glb` | 12,000 | fits a 2.4 m wide x 2.8 m tall opening |
| `sanctuary_altar.glb` | 8,000 | about 1.2 m wide, 1 m tall |

Each finished GLB should be roughly 1.5–4 MB.

### 1b. NIGHTMARE textures: not square and not seamless

`nightware_wall.png`, `nightmare_floor.png` and `nightmare_ceiling.png` are 1408x768 (16:9), so they would stretch on
square wall cells, and the top/bottom edges don't wrap (visible seam). Regenerate all three **square, 1024x1024,
with the tool's tiling switch on** (Midjourney `--tile`, Leonardo "Tiling", SD tiling). Flat even lighting, straight
on, no shadows, no perspective, no vignette. Please also fix the spelling: save the wall as `nightmare_wall.png`.

**nightmare_wall.png**
> Seamless tileable texture, square, straight-on orthographic view: the same rough stone block wall corrupted into
> hell, blackened charred stone blocks split by glowing molten red seams, thin dark red veins and roots creeping
> across the surface, dried blood streaks, flat even lighting, no shadows, no perspective, no vignette, no text.

**nightmare_floor.png**
> Seamless tileable texture, square, top-down orthographic view: large square stone floor tiles, scorched black and
> cracked, faint ember-red glow deep inside the cracks, dark dried blood pooled in the grout lines, small ash flecks,
> flat even lighting, no shadows, no perspective, no vignette, no text.

**nightmare_ceiling.png**
> Seamless tileable texture, square, straight-on orthographic view looking up: a dark stone ceiling overgrown with
> thick blackened red organic veins and roots, slow drips of dark blood, soot stains, very dark overall, flat even
> lighting, no shadows, no perspective, no vignette, no text.

### 1c. Two decals

- `decal_handprint.jpeg` is a photo of a real hand and arm with black bars top and bottom; it can't be used as a
  floor/wall print.
- `decal_blood.jpeg` is on light grey, not pure white, so a grey square would show around it.

Save both as **PNG, 1024x1024, top-down, on pure white** (Godot multiplies them, so white disappears).

**decal_handprint.png**
> A single bloody handprint smeared on a surface, the print only (no hand, no arm, no person), top-down flat view,
> dark red and almost black dried blood with drag streaks from the fingers, centred, isolated on a pure white
> background, no shadow, no text.

**decal_blood.png**
> A dark red blood splatter with a few drips and small droplets, top-down flat view, dried dark crimson edges,
> centred, isolated on a pure white background, no shadow, no text.

---

## 2. Still missing (never delivered)

### 2a. Card art (26 files)

Shown in the art band at the top of every picker card. **PNG, 880x520**, no transparency needed. Keep the subject in
the centre (the top and bottom may crop).

**Style line (start every prompt with it):** dark fantasy horror mobile game art, semi-realistic painterly anime style,
first-person stone maze at night, crimson red + deep violet + ember orange (cold blue where it says WAKE), volumetric
fog, glowing rim light, no text/UI/watermark/letters/numbers.

| File | Card | Subject |
|---|---|---|
| `thick_fog.png` | rule | a narrow stone maze corridor swallowed by fog, a flashlight beam dying a few metres in |
| `safe_haven.png` | rule | four glowing blue floor rings at a dark junction, their light guttering low |
| `blackout.png` | rule (also the Blackout curse) | dead ceiling lamps over a black corridor, one flashlight cone the only light |
| `hungry_dark.png` | rule (also the curse) | a horned devil silhouette sprinting down a corridor, eyes and mouth burning like embers |
| `short_fuse.png` | rule (also the curse) | a burning fuse snaking across the maze floor toward a cracked hourglass |
| `cracked_earth.png` | rule | floor tiles split by glowing orange cracks, one collapsing into a pit |
| `greed.png` | rule | an iron-banded chest glowing at the end of a dead-end alcove, a shadow looming at the turn |
| `deaf_night.png` | rule (also the curse) | a silent corridor, a single red heartbeat line floating in the dark |
| `mirror_night.png` | rule | the maze reflected upside down in a cracked mirror, cold blue above, blood red below |
| `static.png` | rule | a torn paper map dissolving into TV static and ash |
| `tight_clock.png` | rule | a stopwatch with blood-red hands, sand pouring out fast, maze walls leaning in |
| `relentless.png` | rule | the devil striding through a rift between a cold blue world and a red one, never slowing |
| `normal.png` | door | a plain stone doorway into a dim maze corridor |
| `shrine.png` | door | a candlelit shrine niche in the maze wall, a violet omen sigil floating over offerings |
| `vault.png` | door | a heavy iron vault door half open, gold light and chests inside, keys hanging from hooks |
| `hunt.png` | door | a blood-red door gouged by claws, a horned shadow behind its peephole |
| `mystery.png` | door | a door wrapped in black fog, violet smoke leaking from the keyhole |
| `first_blood.png` | Gate | the devil already awake at the far end of a long corridor, the player tiny in the foreground |
| `ritual.png` | Gate | five glowing keys floating in a ring of red candles, an hourglass burning above |
| `mind_break.png` | Gate | a maze shaped like a cracked skull, flickering between cold blue and red |
| `precision_hell.png` | Gate | a corridor of cracked glowing tiles over an abyss, a clock face burning in the ceiling |
| `the_breaker.png` | Gate | the devil tearing through the wall between the blue and red worlds, a final chase |
| `sanctuary.png` | Sanctuary | a small quiet candlelit chamber in soft blue light, an omen resting on an altar |
| `no_curse.png` | curse | a single unlit black candle on a clean stone ledge, one thin wisp of smoke, calm faint blue light |
| `return.png` | Gate choice | a worn stone stairway climbing up out of the maze toward a pale grey dawn, a lantern left on the steps |
| `descend.png` | Gate choice | a spiral stairway plunging down into red glowing depths, embers rising, maze walls continuing far below |

The 16 omen cards need no art of their own: they use `omen_sigils.png`.

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

1. 1a: re-export the 5 models (and the old key) low-poly. Nothing 3D can go in the game until this is done.
2. 1b: the 3 NIGHTMARE textures.
3. 2a: card art (start with the doors and the 3 new cards: they show after every floor).
4. 2b: act cards, padlock, burst.
5. 1c: decals; then section 3 when you have time.
