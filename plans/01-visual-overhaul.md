# FearFlip Visual Overhaul — Asset Generation & Integration Plan

Goal: replace the placeholder pixel blobs and code-drawn primitives with a coherent, premium
"neon cyber-horror" art set, using the sprite pipeline that **already exists** in the code.
No new packages, no renderer rewrite. Each phase is self-contained and can run in a fresh session.

> Note on "Framer Motion": that is a React library and does not exist in Flutter.
> You don't need it. The game already does frame-by-frame animation:
> `MazePainter` steps through sprite-sheet columns driven by an `AnimationController`
> (`maze_painter.dart:235-271`). New art in the right grid drops straight in.

---

## Phase 0 — Current state (verified code facts)

Read these before touching anything. All facts below were verified against source.

### Rendering pipeline
| Fact | Where |
|---|---|
| Maze, player, devil, zones all drawn by one `CustomPainter` | `lib/presentation/gameplay/maze_painter.dart` |
| Player + devil share ONE sheet: `assets/images/characters.png` | `lib/presentation/gameplay/game_screen.dart:1832` |
| Sheet format: 736×128 px = **23 columns × 4 rows** of 32×32 frames | `game_screen.dart:100-102` (`_spriteColumns = 23`, `_spriteRows = 4`) |
| Row 0 = Devil, Row 1 = "Steel Sentinel", Row 2 = "Green Phantom" | `game_screen.dart:2313,2316`, `fear_flip_app.dart:416-427` |
| Idle = frame 0 only; run cycle = frames 0..N-1 while moving | `maze_painter.dart:231` |
| Facing: right = as-drawn, left = horizontal flip, **up/down = ±90° rotation** | `maze_painter.dart:255-267` |
| Sprites drawn with `FilterQuality.none` (crisp pixel-art scaling) | `maze_painter.dart:250` |
| "Flip mode" inverts the world: black bg/white walls ↔ white bg/black walls | `maze_painter.dart:58-63` |
| Trap "cracked/critical" tile texture: `assets/images/464.jpg` | `game_screen.dart:1854`, `lib/game/trap/trap_fx_renderer.dart:48-75` |
| Start beacon / exit gate / safe zones are code-drawn glows (no assets) | `maze_painter.dart:120-171` |
| Character picker preview hardcodes sheet metrics 736/128/32 | `lib/app/fear_flip_app.dart:41-43` |
| Palette: black surfaces, neon green `#33FF2B`, pink `#E85BDA`, purple `#E26AE6` | `lib/presentation/theme/app_palette.dart` |

### Dead code warning
`lib/game/character.dart` (catalog with 256×256 coords) and `lib/ui/game_overlays.dart` belong
to an old Flame overlay path. The live flow is `landing_screen.dart → game_screen.dart`.
**Do not make art for the catalog coordinates — they don't match the real sheet.**

### The two hard constraints every sprite must satisfy
1. **Must read on BOTH pure black and pure white backgrounds** (flip mode). Every sprite needs
   a dark charcoal outline **plus** a neon rim/glow accent. Neither pure-black nor pure-white
   silhouettes are allowed.
2. **Must survive small sizes.** Cells can shrink to ~20 px on a 17×17 maze on a phone.
   Big readable silhouettes, no fine detail, high contrast.

---

## Art direction — STYLE LOCK

Paste this block at the start of EVERY image prompt so all assets look like one game:

```
STYLE LOCK: high-quality 64x64 pixel art game sprite, dark neon cyber-horror
arcade style, glowing rim light, palette anchored to acid neon green #33FF2B,
hot pink #E85BDA, electric purple #E26AE6 on near-black #0D0D0D, 1-px dark
charcoal (#111111) outline around the full silhouette so it reads on both
black and white backgrounds, crisp pixels, no anti-aliasing mush, no dithering
noise, bold readable silhouette at 24px, transparent background, no drop shadow.
```

Production notes (apply to all sheet assets):
- Generate at 512–1024 px per frame, then downscale to 64×64 nearest-neighbor. Never upscale.
- AI models rarely nail a whole animation sheet in one shot. Workflow that works:
  1) generate ONE hero frame you love, 2) reuse it as an image reference/edit input for each
  remaining frame with the per-frame pose text below, 3) assemble the grid in any editor
  (Aseprite/Photopea, strict 64-px grid, no gaps, no margins).
- Transparent background: if the generator can't do alpha, generate on flat `#FF00FF` magenta
  and run background removal.
- I can generate these directly for you (Higgsfield image tools are connected) — just ask.

---

## Phase 1 — New character sheet (the single highest-impact change)

### Asset 1: `assets/images/characters.png` (REPLACE existing file, same name)

**Spec:** PNG with alpha, **512×256 px = 8 columns × 4 rows**, each frame exactly 64×64.
Character centered, feet at ~y=56, ~48 px tall inside the frame, drawn in **3/4 side view
facing RIGHT** (the code flips it for left; see Phase 2 for up/down).

Frame-by-frame pose guide (same 8-frame run cycle for every row; frame 1 doubles as idle,
so it must be a strong neutral stance):

| Frame | Pose |
|---|---|
| 1 | Idle/contact — upright neutral stance, both feet planted, neon accents at full glow |
| 2 | Run contact — right foot forward striking ground, body leans forward |
| 3 | Run down — body lowest, knees bent, cape/scarf compressed |
| 4 | Run pass — legs crossing, left leg swinging through |
| 5 | Run up — body highest, brief airborne moment, accents trail 2-3 px of glow |
| 6 | Run contact mirror — left foot forward striking |
| 7 | Run down mirror | 
| 8 | Run pass mirror — right leg swinging through, glow trail |

**Row 0 — THE DEVIL (the villain finally stops being an orange blob):**
```
[STYLE LOCK] + Character: a floating shadow demon called The Devil — a jagged,
smoke-edged black wraith silhouette with a cracked horned skull face, two
blazing hot-pink #E85BDA eyes and a thin glitching purple #E26AE6 aura, ragged
smoke tendrils instead of legs, claws of pink neon light. Menacing hunched
hover pose, 3/4 side view facing right. Terrifying but cute-enough for an
arcade game, like a Pac-Man ghost redesigned by a horror movie.
Animation rows note: it hovers, so frames 1-8 are a float cycle instead of a
run: bob up/down 3px, tendrils and aura flames dragging with 1-frame lag,
eyes flicker brighter on frames 3 and 7.
```

**Row 1 — STEEL SENTINEL (playable, accent color #5A9FD9 steel blue):**
```
[STYLE LOCK] + Character: a sleek android runner called Steel Sentinel —
gunmetal armored body with steel-blue #5A9FD9 energy core in the chest, one
glowing cyan visor eye strip, thin neon-blue circuit seams across the armor,
compact heroic proportions (2.5 heads tall, big head, sturdy legs built for
sprinting). 3/4 side view facing right, run cycle per pose guide, visor and
chest core leave a subtle 2px light trail on frames 5 and 8.
```

**Row 2 — GREEN PHANTOM (playable, accent color #40D66A neon green):**
```
[STYLE LOCK] + Character: a hooded ghost-runner called Green Phantom — a
tattered dark hooded cloak with nothing inside but two acid-green #40D66A
glowing eyes and green ectoplasm wisps, ragged cloak hem dissolving into
green embers at the bottom, small ghostly hands. 3/4 side view facing right,
run cycle per pose guide but the cloak flows and ember particles detach on
frames 4 and 8; eyes are the brightest pixels in the sprite.
```

**Row 3 — VOID RIPPER (new third playable, accent color #E85BDA pink — unlocks roster growth):**
```
[STYLE LOCK] + Character: a glitch-creature called Void Ripper — a small
feral imp made of broken black glass shards held together by hot-pink #E85BDA
energy, one big cyclops eye, jagged crystal spikes down its back, pink
lightning arcing between shards. 3/4 side view facing right, run cycle per
pose guide, on frames 3 and 7 one shard briefly separates (glitch effect)
and snaps back.
```

### Verification (Phase 1)
- [ ] File is exactly 512×256, alpha channel present, frames on a strict 64-px grid
- [ ] Every frame reads clearly when viewed at 24×24 on white AND on black
- [ ] Frame 1 of each row works as a standalone idle pose

---

## Phase 2 — Code integration for the new sheet (≈6 lines total)

1. `lib/presentation/gameplay/game_screen.dart:100-102` — update the comment and constant:
   `_spriteColumns = 23` → `_spriteColumns = 8`. (`_spriteRows = 4` stays.)
   Frame size is auto-computed from image dimensions (`maze_painter.dart:244-245`), so
   nothing else changes.
2. `lib/app/fear_flip_app.dart:41-43` — picker preview metrics:
   `_sheetWidth = 736` → `512`, `_sheetHeight = 128` → `256`, `_frameSize = 32` → `64`.
3. **Kill the 90° rotation** (a humanoid rotated sideways while running "up" looks broken —
   this is half the reason the game reads as ugly). In `maze_painter.dart:261-266` make
   `Direction4.up` and `Direction4.down` `break;` like `right` (no transform). 3/4-view
   sprites flipped horizontally are the standard for top-down arcade (Among Us, Soul Knight).
4. Optional: add Void Ripper (row 3) to `_characterOptions` in `fear_flip_app.dart:416-427`:
   `_CharacterOption(title: 'Void Ripper', color: Color(0xFFE85BDA), spriteRowIndex: 3)`.

### Verification (Phase 2)
- [ ] `flutter analyze` clean
- [ ] Run game: player animates 8-frame cycle, stands on frame 1 when idle
- [ ] Move up/down: sprite is NOT lying sideways
- [ ] Trigger flip mode (controls inverted): sprite still readable on white
- [ ] Devil renders row 0, both picker characters render rows 1-2

### Anti-pattern guards
- Do NOT add flame/rive/lottie/anything for this. The painter already animates.
- Do NOT touch `lib/game/character.dart` or `lib/ui/game_overlays.dart` (dead Flame path).

---

## Phase 3 — Environment assets

### Asset 2: `assets/images/breaking_trap.png` (replaces `464.jpg`, currently a cyan ice blob)

**Spec:** PNG, 256×256, square, seamless enough to sit in one cell. Drawn by
`trap_fx_renderer.dart:_drawRevealedTexture` for `cracked` and `critical` trap states
(renderer adds its own pulsing red border, so the texture itself carries no border).

```
[STYLE LOCK] + Asset: a single square floor tile of cracking dark obsidian
glass, top-down view, deep fracture lines glowing hot-pink #E85BDA from
inside like magma under black ice, small glass shards lifting at the crack
edges, center crack forming a subtle skull shape, edges of the tile clean
and straight (it must tile within a grid cell), mostly dark so the pink
cracks scream danger. No border, no text.
```

Code: `game_screen.dart:1854` — change `'assets/images/464.jpg'` to
`'assets/images/breaking_trap.png'`, delete `464.jpg`.

### Asset 3: `assets/images/exit_portal.png` — OPTIONAL animated exit gate

Today the exit is a flat gold rectangle (`maze_painter.dart:129-144`). It's functional;
replace only if you want the extra wow. **Spec:** 512×64 = 8 frames × 64×64 loop.

```
[STYLE LOCK] + Asset: a swirling escape portal tile, top-down view, a ring
of golden #FFD700 light with acid-green #33FF2B lightning arcing across a
black void center, tiny light particles being sucked inward, 8-frame loop
where the ring rotates 45 degrees per frame and the center void pulses.
```

Code hook (small, contained): pass `exitSprite`/frame to `MazePainter` exactly like
`breakingTrapTexture` is passed today, draw with `drawImageRect` in place of the gold
rect block. Skip if Phase 1-2 already made the game feel good — the glow rect works.

Start beacon and safe zones: **keep code-drawn.** They're animated glows already and
cost zero bytes. Revisit only after everything else ships.

### Verification (Phase 3)
- [ ] Trap tiles show new texture in cracked AND critical states, red pulse border intact
- [ ] `464.jpg` deleted, no references left (`grep -r "464" lib/`)

---

## Phase 4 — Landing screen, icon, store presence

### Asset 4: `assets/images/landing_hero.png` — landing screen hero art

**Spec:** PNG with alpha, 1024×1024, the Devil looming behind/above the runner trio.
Place it in `landing_screen.dart` above the wordmark (the screen currently has only
text + a code-drawn glitch grid, `landing_screen.dart:775`).

```
[STYLE LOCK, but rendered as a polished key-art illustration in the same
pixel-art-inspired neon style, higher detail allowed] + Scene: the shadow
demon Devil (huge, hot-pink eyes, smoke horns) looming out of a dark glitching
maze, and below it the small brave silhouettes of Steel Sentinel and Green
Phantom sprinting toward the viewer down a neon-lit corridor, acid-green maze
lines receding into darkness, scanline glitch bands, vignette to pure black
at the edges so it blends into a #000000 app background. Vertical composition,
top 40% = devil, bottom 30% fades to black. No text, no logo.
```

### Asset 5: `assets/images/app_icon.png` — REPLACE (regenerate launchers after)

**Spec:** 1024×1024, no transparency, works in a circle mask.

```
Asset: mobile game app icon, extreme close-up of the shadow devil's face —
cracked horned skull, two blazing hot-pink #E85BDA eyes, thin acid-green
#33FF2B maze lines etched across the black background like circuitry, subtle
vertical glitch slice through one eye, bold and readable at 48px, centered
composition with 12% safe margin, no text, near-black #0D0D0D background,
premium neon cyber-horror arcade style.
```

Then run: `dart run flutter_launcher_icons` (already configured, `pubspec.yaml:74-77`).

### Asset 6 (not bundled in app — keep in `store/` folder at repo root, gitignored or not, your call)
- `store/feature_graphic.png` 1024×500 — same prompt as landing hero but horizontal:
  devil face left, runners sprinting right, add nothing where Google overlays the play button.
- `store/screenshots/` — capture real gameplay AFTER phases 1-3, on a dark frame with a
  one-line neon caption each ("OUTRUN THE DEVIL", "THE MAZE FLIPS", "TRAPS LIE IN WAIT").
  Real screenshots of the new art will sell better than mockups.

### Verification (Phase 4)
- [ ] Icon legible at 48 px, launcher regenerated on device
- [ ] Landing hero doesn't push CTA buttons below the fold on a 640-dp-tall phone
- [ ] `flutter build apk --release` succeeds; APK size increase < 2 MB (PNGs are tiny at these dims)

---

## Final phase — Full verification

- [ ] `flutter analyze` — zero issues
- [ ] `flutter test` — existing tests green
- [ ] Play stages 1-5: player run cycle smooth, devil animates its float cycle, traps show new texture
- [ ] Force flip mode: every sprite readable on the white background
- [ ] Shrink test: stage with 17×17 maze — sprites still readable
- [ ] `grep -r "464.jpg" lib/` and `grep -r "_spriteColumns = 23" lib/` return nothing

## Asset manifest (quick reference)

| # | File | Size | Grid | Phase |
|---|---|---|---|---|
| 1 | `assets/images/characters.png` | 512×256 | 8×4 @ 64px | 1 |
| 2 | `assets/images/breaking_trap.png` | 256×256 | single | 3 |
| 3 | `assets/images/exit_portal.png` (optional) | 512×64 | 8×1 @ 64px | 3 |
| 4 | `assets/images/landing_hero.png` | 1024×1024 | single | 4 |
| 5 | `assets/images/app_icon.png` | 1024×1024 | single | 4 |
| 6 | `store/feature_graphic.png` | 1024×500 | single | 4 |

One honest line about the 5M-installs goal: art is necessary but not sufficient — after this
overhaul, the levers are store listing (icon + screenshots above), retention tuning, and paid UA.
Ship phases 1-2 first; they're 90% of the perceived quality jump for ~6 lines of code.
