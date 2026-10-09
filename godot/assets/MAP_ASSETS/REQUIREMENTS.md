# Paper map: assets needed for a real 3D opening and closing

What the finished move looks like: you press **M**, the head turns toward the back pocket, and the **right hand** brings
up the rolled map. The **left hand** grips its left edge, and the right hand pulls the roll across to the right. The
sheet **physically uncurls** as it goes: it is real bent 3D paper, not a flat picture getting wider. The open map is
then lifted to read, with both hands holding the curled edges at the lower left and lower right. Closing plays the same
move backwards.

The curl is **done in code**: a bendable sheet that rolls around a moving tube. That means **no unrolling model and no
unrolling animation** are needed from you. What is missing is mainly the **hands** (and sound).

---

## 1. What you delivered and where it goes

| # | File in `MAP_ASSETS/` | Used as | Status |
|---|---|---|---|
| 0 | Aged Folded Parchment Texture.png | **Front of the sheet** (the maze is inked on it) -> `images/hud/map_paper.png` | ✅ used |
| 4 | Grungy Bloodstained Parchment Frame.png | Blood and grime **under** the ink -> `map_stains.png` | ✅ used |
| 2 | Demonic Parchment Map Frame.png | Ornament frame **over** the ink -> `map_frame.png` (the maze shrinks to fit inside it) | ✅ used |
| 1 | Cursed Ancient Map Scroll.png | Concept only: the delivered `map_roll.glb` is the roll now | ➖ not needed |
| 6 | Paired Weathered Parchment Scroll Ends.png | Not needed: the code curl makes real rolled edges | ➖ not needed |
| 7 | Weathered Fantasy Leather Roll Strap.png | Reference for the strap on `map_roll.glb` | ⚠️ 2D only |
| 3 | Gothic Demon-Bound Parchment Map.png | Not used: opaque, with black corners (#0 + #2 + #4 already make this look) | ❌ |
| 8 | Weathered Fantasy Parchment Map.png | Not used: opaque, with black corners | ❌ |
| 5 | Infernal Gothic Claw Artifact.png | **No role yet.** Tell me what it is for (a clasp on the strap? a "you are here" pin?) | ❓ |

The originals stay untouched in `MAP_ASSETS/`; that folder is now `.gdignore`d. Resized copies are in `images/hud/`.

**Why the flat PNGs can't do the job on their own:** a picture of a scroll only looks right from the one angle it was
drawn at. The roll turns in your hand, tilts toward your eyes and uncurls, so it has to be real geometry.

---

## 2. REQUIRED (without these it can't look like real 3D)

### 2a. Hand and forearm: `models/map_hand.glb` ⭐ the most important missing piece

Today the hands are skin-coloured boxes. **One right hand**: the game mirrors it to make the left.

- **Format:** GLB, about **6k triangles max**, PBR textures at **1K** (albedo, normal, roughness), real-world size
  (metres), Y-up.
- **Length:** about **42 cm** from fingertips to the cut end, cut cleanly **just below the elbow**. The cut end stays
  off-screen.
- **Pose:** a **loose fist closed around a vertical rod about 4 cm thick** (the curled edge of the map), with the
  thumb wrapped over the front and the four fingers behind. The wrist is straight and the forearm in line with the hand.
  *(This replaces the "pinch grip" in ASSET_PROMPTS.md §3c: both hands now hold curled edges, so one grip pose fits
  both.)*
- **Leave the rod out** of the model. If the generator puts something in the hand anyway, deliver it and say so.
- **Sleeve:** the hero's worn **dark grey jacket** covers the forearm to the wrist.
- **Check before sending:** five separate fingers (image-to-3D tools often fuse them) and no holes at the wrist.

Concept-image prompt (then run image-to-3D in Meshy or Tripo):
> Game asset concept, side view: a single right human hand and forearm, cut off cleanly just below the elbow, the hand
> closed in a loose fist around an invisible vertical rod about 4 cm thick (thumb wrapped over the front, four fingers
> together behind), wrist straight, the sleeve of a worn dark grey jacket covering the forearm to the wrist, pale skin
> with grime on the knuckles and a few small scratches, short dirty nails, semi-realistic, dark horror game style.
> Isolated on a plain white background, even studio lighting, no object in the hand, no body, no shadow, no text.

### 2b. Sounds (`audio/`): the move is silent today

MP3, peaks around -3 dB, **no silence at the start**. Use ElevenLabs Sound Effects, or cut from CC0 clips on
freesound.org ("paper unroll", "parchment", "pocket rustle", "leather strap").

| File | Length | What it is |
|---|---|---|
| `sfx_map_open.mp3` | **1.7 s** | 0.0-0.5 s fabric and leather pocket rustle; 0.5-1.4 s dry parchment crackling as it unrolls; 1.4-1.7 s a soft taut snap as it is held open |
| `sfx_map_close.mp3` | **0.8 s** | A fast paper crinkle as it rolls up, then a short pocket rustle |
| `sfx_map_snap.mp3` *(new)* | **0.3 s** | Panicked: paper crushed shut in one grab, a sharp crumple with a low thud. Plays when the Devil forces the map shut |

> Prompt pattern: *"Close-up, dry, no music, no voice: <the description above>."*

---

## 3. OPTIONAL upgrades (the game works without them)

### 3a. Rigged first-person arms with animations (replaces 2a; best quality, most work)
Both arms, one skeleton, animated in Blender (or a licensed FP-arms asset, CC0 or CC-BY). If you go this way, the code
plays your animations and attaches the map to the hand bones.
- Bones for each hand (any names; tell me which ones).
- Actions: `map_draw` (0.5 s: right hand to the back pocket and forward), `map_unroll` (0.9 s: left hand grips the left
  edge, right hand pulls right), `map_hold` (a loop: slight breathing sway), `map_close` (0.6 s).
- About 10k triangles for both arms, 1K textures, same sleeve as 2a.

### 3b. Back of the parchment: `images/hud/map_paper_back.png`
The rolled-up outside of the map shows the **back** of the paper. Until this exists, the game uses the front (#0)
mirrored and darkened, which looks fine. **2048x1536**, transparent PNG, the same torn outline as #0 seen from behind:
> The back side of one sheet of aged yellowed parchment seen straight on, flat, filling the frame, ragged torn edges,
> faint ink bleeding through from the other side as blurred mirrored lines, stains and grime, no readable words, flat
> even lighting, isolated on a transparent background.

### 3c. Strapped closed roll: `models/map_roll.glb`
Only needed if you want the **leather strap** visible while the roll comes out of the pocket. Without it, the fully
curled sheet *is* the roll. Feed **#1 (Cursed Ancient Map Scroll.png)** straight into Meshy or Tripo image-to-3D:
about 2k triangles, 1K texture, **33 cm long, 5 cm thick**, long axis +Y, pivot at the base centre. The strap pops off
(it swaps out) as the left hand takes the roll.

### 3d. "You are here" marker: `images/hud/map_marker.png`
The game draws a red ink arrow today. If you want a painted one: **256x256** transparent PNG, a hand-inked dried-blood
arrowhead **pointing up** (the game rotates it to your facing), rough brush edge. If #5 (the claw) was meant for this,
say so.

### 3e. Not needed from you
- **Normal map for the folds and creases:** I'll derive it from #0.
- **Unrolling model or shape keys:** the curl is code.
- **Roll-end caps:** the curl makes real spiral ends.

---

## 4. Checklist (updated 9 Oct 2026, in the game now)

- [x] `models/map_hand.glb`: from `clenched-fist-3d-model-*.glb` (2M -> 6k tris, 1K textures, 42 cm, mirrored for
      the left hand). A fist round a roll, not the pinch from 2a.
- [x] `models/map_roll.glb`: from `ancient-map-scroll-3d-model-*.glb` (2M -> 2.5k tris, 33 cm), the strapped roll that
      comes out of the pocket.
- [x] `images/hud/map_paper_back.png`: from `Weathered Antique Parchment Texture.png`.
- [x] `images/hud/map_marker.png`: from `Grungy Crimson Upward Marker.png`.
- [x] `audio/sfx_map_open.mp3` (1.68 s), `audio/sfx_map_close.mp3` (0.80 s), `audio/sfx_map_snap.mp3` (0.48 s, the
      0.5 s minimum): generated with the ElevenLabs Sound Effects API from the 2b prompts (30 credits); played at
      `PaperMap.SOUND_DB` because the open clip peaks at 0 dBFS.
- [ ] `models/map_arms.glb` + animations: optional (replaces map_hand)
- [ ] Answer: what is #5 (the claw) for? Still unused, like #3, #8, `Antique Bound Map Scroll.png` (the roll's concept)
      and the flat scroll-end/strap pictures (#1, #6, #7: the 3D roll and the code curl replace them).

Drop originals into `MAP_ASSETS/` as before, and I'll resize them into place. Every slot keeps working with a code
stand-in until its file arrives, so the map can be built and played now and upgraded as the art lands.
