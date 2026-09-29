# FEARFLIP — VIRAL-READY UI / VFX UPGRADE PLAN

**Date:** 2026-09-22
**Companion to:** `plans/02-audit-findings.md`
**Mode:** Plan / scope / no code yet
**Frame:** Adapted `epic-design` skill principles to mobile 2D arcade game UI (no scroll, no DOM — depth layers, GPU-only animated properties, cinematic state transitions, hierarchy, atmosphere, accessibility still apply 1-to-1).

---

## TL;DR — what "viral ready attractive" actually costs in this codebase

| Layer | State today | Cost to upgrade | Priority |
|---|---|---|---|
| Maze + traps render | already strong (painter w/ bob/sway/lean, trap FX 6 states) | polish — none | — |
| Flip warning visual | **empty `if {}` body** — see audit F-02 | 1 file | P0 |
| Particle systems | only stage-clear ring + leaderboard next-level (20 dots) + stage-100 confetti | new module | P0 |
| Camera shake | none | new module | P0 |
| Trail / motion blur | none | small painter change | P1 |
| Devil catch cinematic | death sequence is the trap death; **no cinematic for devil catch** | new | P1 |
| Trap collapse debris | partial — only warning debris; no impact burst | small | P1 |
| Ambient atmosphere | none inside maze | new painter overlay | P1 |
| Haptics | none | add `HapticService` | P1 |
| Adaptive music | audio_manager exists but no intensity-tied ducking | audio change | P2 |
| Character portraits | sprites only — no hero portrait | art | P2 |
| Devil boss variants at 25/50/75/100 | none | art + state | P2 |
| Score popups | none | widget | P1 |
| Cinematic screen transitions | `MaterialPageRoute` defaults | replace | P2 |
| Share / replay moment | none | new | P2 |
| Dynamic tutorial | none — onboarding is separate screen | inline guide | P2 |

Total scope (excluding art): **~12–15 PRs**, mostly additive. None collides with the P0 game-fix PRs in `02-audit-findings.md`.

---

## DESIGN PRINCIPLES ADAPTED FROM `epic-design`

### 1. Six depth layers in the play surface

```
DEPTH 0  Ambient background  — fog / dust motes / dim pulse behind the maze
DEPTH 1  Maze walls + paths  — current CustomPainter (good as-is)
DEPTH 2  Traps + safe zones  — current TrapFxRenderer (good)
DEPTH 3  Player + Devil      — current player+devil in MazePainter (good)
DEPTH 4  UI / HUD / controls — GameHud, joystick, flip indicator
DEPTH 5  Foreground FX       — particles, shockwave, glitch overlay, vignette
```

> Rule: each new layer must NOT animate `width / height / top / left` — only `transform`, `opacity`, `clip-path`, `filter`. `MaskFilter.blur` is allowed on `Paint` for cheap glow.

### 2. Hierarchy before code

The game has **three heroes**:
- **Player** (depth-3, 78 % of cell area)
- **Devil** (depth-3, 65 % of cell area, slightly smaller to imply threat-from-above)
- **Exit portal** (depth-3, 92 % of cell area, pulsing)

Every other visual is **companion / accent**:
- Safe zones — depth-2, 14 % cell inset
- Traps — depth-2, full cell, **but the crack lines are depth-5** (in front of everything)
- Score popups — depth-5, float upward, decay

### 3. Cinematic moments, not just effects

Every state transition is a **cinematic moment**, not a frame swap:

| Trigger | Today's effect | Upgrade |
|---|---|---|
| Flip warning (T-0.6 s) | nothing | HUD pulse + chromatic breath + audio "warning" + haptic |
| Flip activation | nothing visible (just `setState`) | Screen flash 80 ms white→0.05 + ink-bleed shader + audio "flip" + heavy haptic |
| Devil catches player | `setState` then dialog | Slow-mo 0.5 s of game (game tick × 0.5), camera shake, devil lunge anim, red flash, devil's eye pulse, audio "caught" + haptic |
| Trap reveal | crack texture | Crack spreads over 0.4 s with dust particles; subtle audio "tick" |
| Trap collapse | `TrapDeathSequence` overlay (good) | + radial shockwave particle burst + slow-mo 0.3 s + audio "collapse" + haptic |
| Stage clear | `StageClearOverlay` with 1.4 s animation (good) | + confetti burst + portrait zoom + screen-flash gold |
| Time up | dialog | Time-warp: 1 s slowdown + ticking gets louder + red vignette + audio "expire" + heavy haptic |
| Stage 100 cleared | crown dialog | Existing gold confetti, but add: camera dolly (zoom + pan to player), exit portal explodes outward, audio fanfare, character portrait reveals with cinematic light |
| Safe zone entered | ring | + bubble shader (depth-1 radial gradient breathing) + audio hum |
| Devil respawn | nothing | Red glow at spawn cell + audio "spawn" |

### 4. GPU-only animated properties

| Allowed | Banned |
|---|---|
| `transform` (translate / rotate / scale) | `width`, `height` |
| `opacity` | `top`, `left`, `right`, `bottom` |
| `clip-path` | direct `Color` mutation (use `Color.alphaBlend`) |
| `filter` (with `BackdropFilter` only for blurs < 8px) | `text` style changes inside `setState` |
| `Paint.blendMode` | layout-driven animation |

### 5. Cinematic-but-cheap

60 FPS budget = 16.67 ms / frame. Current game tick = 20 Hz = 50 ms between frames. So we have ~50 ms total headroom per visible frame. A particle layer adding 20–30 sprites per frame costs ~0.4 ms on mid-range Android. **Plenty of room.** But:
- **Cap simultaneous particle systems** at 3 (flip + devil catch + trap collapse).
- **Cap particle count** at 200 alive total.
- **Reuse Paint objects** between draws (already done in MazePainter — extend to particle painters).
- **Use `BackdropFilter` for vignette / dust**, not per-cell Paint.blur.

### 6. Accessibility still applies

- `prefers-reduced-motion` → drop shockwave, slow-mo, glitch; keep state changes.
- Color-blind: don't rely on red/green alone for danger/safe. Use shape (devil silhouette vs safe-zone ring) + iconography.
- All decorative painters get `IgnorePointer` (already done for glitch — extend).
- All new CustomPaint widgets need `shouldRepaint` returning false when no state change.

---

## WHAT THE PLAY SURFACE SHOULD LOOK LIKE — AESTHETIC NORTH STAR

> **One sentence:** A neon-cyber horror arcade game where every death looks like a horror movie, every clear feels like breaking out of a nightmare, and every flip makes the world briefly forget which way is up.

### Visual reference anchors

- **Lighting**: warm gold for exit portal (depth-3); magenta-violet for safe-zone rings (depth-2); cool cyan for the player glow (depth-3 base); blood-red for devil proximity (depth-5 vignette only — never recolor the maze itself); emerald pulse for the start cell.
- **Motion grammar**:
  - Idle = slow breathing (1.5 Hz sway)
  - Walking = bob + squash/stretch + lean
  - Flipped = same as normal but colors invert and walls invert (already done) — add a 200 ms "settling" wobble after flip
  - Devil near = screen vignette tightens, breathing rate of vignette matches heart-rate pulse
  - Death = slow-mo + camera shake + radial shockwave + freeze frame for 0.3 s
- **Typography**:
  - HUD numbers in monospace, 16–24 px, all-caps with letter-spacing
  - Stage number in huge bold display weight, gold-accented on clear
  - Devil distance as a thin horizontal bar with a tick mark
  - All HUD text has a 2 px neon outline (paint with `Stroke + Fill` strategy)
- **Color tokens** (extend `AppPalette`):
  - `gold` (`#FFD700`) — exit, stage-100, win
  - `cyan` (`#5FE8FF`) — player glow, "ready"
  - `magenta` (`#E85BDA`) — safe zone, breathing
  - `red` (`#FF3344`) — danger, devil proximity
  - `acidGreen` (`#33FF2B`) — controls normal
  - `inverseBlue` (`#3344FF`) — controls inverted (replaces inverted color logic)
  - `ash` (`#1A1A1A`) — surface
  - `bone` (`#E5E5E5`) — text

### Composition rules

- **One cell-size**: cell size derived from shortest screen side / 12. Player + Devil + Exit all fit inside one cell with 78 / 65 / 92 % insets respectively.
- **Trail**: 6 ghost copies of the player at 35 / 25 / 15 / 8 / 4 / 2 % opacity, drawn on a separate painter at depth-3 (behind live player).
- **Particles**: depth-5, additive blend mode (`BlendMode.plus`), 6 px average, fade-out over 0.6–1.0 s.
- **HUD**: depth-4, all-caps, monospace, 8 % padding from screen edges.

---

## ARCHITECTURE FOR THE UPGRADE

### New modules (all live under `lib/presentation/gameplay/effects/`)

```
effects/
  particle_system.dart       # base — ParticleSystem, ParticleEmitter, Particle
  particles/
    flip_shockwave.dart      # 12 radiating rings, 0.5 s
    devil_catch_burst.dart   # 24 radial sparks + 6 slow embers, 1.2 s
    trap_collapse_debris.dart # 18 dust + 6 shards, 0.8 s
    ambient_dust.dart        # 40 always-on, slow drift
    safe_zone_pulse.dart     # 1 ring expanding 1.5x → 0
    score_popup.dart         # "+1 STAGE" floating text
  camera_shake.dart          # CameraShakeController — value-based, mount above MazePainter
  trail_painter.dart         # TrailPainter — depth-3 behind live player
  vignette_painter.dart      # dynamic vignette — depth-5; tied to devil distance / damage
  screen_flash.dart          # ScreenFlashController — solid white/red/gold overlay, 60–300 ms
  slow_motion.dart           # SlowMotionController — scales game tick by 0.3–1.0
  haptic_service.dart        # HapticService — thin wrapper over HapticFeedback with patterns
  flip_warning_visual.dart   # HUD-side: pulse the mode label, screen tint breath
```

### Wiring

```
GameAudioEvent.flipImminent        → GameScreen → FlipWarningVisual.pulse()
GameAudioEvent.flipTriggered       → FlipShockwave.emit() + ScreenFlash.bleed() + Haptic.heavy()
GameAudioEvent.devilCaughtPlayer   → DevilCatchBurst.emit() + CameraShake.heavy()
GameAudioEvent.trapCollapsed       → TrapCollapseDebris.emit() + ScreenFlash.red() + Haptic.medium()
GameAudioEvent.playerWon           → StageClear (existing) + ScorePopup.emit("STAGE N CLEAR")
GameAudioEvent.timeExpired         → SlowMotion.start(0.3) + Vignette.tighten()
GameAudioEvent.safeZoneEntered     → SafeZonePulse.emit() + Ambient.magenta()
GameAudioEvent.mazeShiftStarted    → GlitchEffect (existing) + CameraShake.light()
```

Each emission is a single async function returning `Future<void>`. They never block the game tick.

### Painter layering (depth order, bottom up)

```
CustomPaint(GlitchEffectOverlay)        ← depth-5 (foreground FX top)
  └─ Stack
     ├─ CustomPaint(AmbientDust)        ← depth-0 (background atmosphere)
     ├─ CustomPaint(MazePainter)        ← depth-1 (walls)
     ├─ CustomPaint(TrailPainter)       ← depth-3 behind player
     ├─ CustomPaint(TrapFxRenderer)     ← depth-2 (traps + safe zones)
     ├─ CustomPaint(MazePainter player+devil)  ← depth-3 (heroes)
     ├─ CustomPaint(VignettePainter)    ← depth-5 (radial dim)
     ├─ CustomPaint(ParticlePainter)    ← depth-5 (particles above maze)
     └─ GameHud (depth-4 text overlay)
```

This is wrapped in a single `RepaintBoundary` already (`gameSurfaceKey`) — we just stack more CustomPaint widgets inside.

### Cinematic controllers (state, not widgets)

- `ParticleSystem` — `List<Particle>` with `update(dt)` + `emit(config)`. Renders via a single `CustomPaint` with one `ParticlePainter`.
- `CameraShakeController` — `Offset trauma` (0..1), decays at rate; multiplied into the painter's translate.
- `ScreenFlashController` — single value `alpha` and `color`, decays.
- `SlowMotionController` — value `0.3..1.0` multiplied into the game tick dt before any other controller.
- `HapticService` — singleton; `light/medium/heavy/selection/warning` methods.

Each controller has a `dispose()` and a `ValueNotifier` so widgets rebuild only when relevant fields change.

### Performance budgets

| Layer | Max sprites per frame | Cost target |
|---|---|---|
| Particles total | 200 | ≤ 0.6 ms |
| Vignette | 1 painter | ≤ 0.2 ms |
| Trail | 6 ghosts | ≤ 0.3 ms |
| Camera shake | 1 transform | ≤ 0.05 ms |
| Ambient dust | 40 | ≤ 0.2 ms |

Total FX cost ≤ 1.4 ms. Combined with current MazePainter (~3–4 ms on 17×17), we sit at ~5–6 ms / frame. **Plenty of headroom for 60 FPS even on low-end Android.**

---

## CINEMATIC MOMENTS — DETAILED PLANS

### C-01 — Flip Warning (0.6 s ramp) **[P0, ties to audit F-02]**

**Visual:**
- HUD mode label "NORMAL" / "FLIPPED" pulses from 1.0 → 1.15 → 1.0 scale at 4 Hz.
- Screen tint breathes red→black→red→black at 4 Hz, opacity 0 → 0.06 → 0.
- Chromatic aberration (depth-5 overlay, RGB split) at 0.5 px → 2 px over the ramp.
- Audio: existing `GameAudioEvent.flipImminent` (new event — add to enum).
- Haptic: light tap at T-0.6, T-0.3.

**Implementation:** `FlipWarningVisual` widget above the HUD; reads `secondsUntilFlip` from a `ValueNotifier<double>` (already exists as part of game state). When ≤ warning time, run a 600 ms `AnimationController` driving the visuals.

### C-02 — Flip Activation (200 ms burst) **[P0]**

**Visual:**
- Screen flashes white 0.05 alpha for 60 ms.
- FlipShockwave: 12 rings radiating from player position, 1.0 → 2.5x scale, fade out over 500 ms.
- Maze colors invert over 80 ms (already done by `isFlippedMode` toggle; add an `AnimationController` to make the transition 80 ms instead of instant).
- Audio: existing `GameAudioEvent.flipTriggered`.
- Haptic: heavy (50 ms vibration).

**Why viral:** Flip is the core identity. Every flip must feel physical, not just a state change.

### C-03 — Devil Catch Cinematic **[P1]**

**Visual:**
- Slow-mo: game tick × 0.4 for 0.6 s, then snap back to 1.0.
- Camera shake: trauma 0.6 → 0 over 0.6 s.
- DevilCatchBurst: 24 radial sparks + 6 slow embers from player's last position.
- Screen flash: red 0.10 alpha for 120 ms.
- Vignette: tighten to 0.85 radius for 0.6 s.
- Audio: `GameAudioEvent.playerLost` (already exists) + low drone.
- Haptic: heavy (50 ms) + double-tap pattern.

**Current state:** `_onDevilCaught` just calls `setState({_showLossOverlay: true})`. No cinematic.

### C-04 — Trap Collapse Cinematic **[P1, ties to audit F-09]**

**Visual:**
- TrapCollapseDebris: 18 dust + 6 shards from trap cell.
- Camera shake: light.
- Screen flash: red 0.04 alpha 60 ms.
- Slow-mo: 0.3 s × 0.5.
- Audio: existing `GameAudioEvent.trapDeath` (already).
- Haptic: medium.
- Existing `TrapDeathSequence` painter overlay (good) stays.

**Current state:** `TrapDeathSequence` already does a nice expanding ring + crack. We're adding the missing burst particles.

### C-05 — Stage Clear Cinematic **[P1]**

**Visual:**
- Camera dolly: zoom 1.0 → 1.04 → 1.02 over 1.4 s.
- Player trail (gold) emits 30 sparks in a 360° pattern.
- Exit portal grows 1.0 → 1.4 → 1.0.
- Audio: existing `GameAudioEvent.playerWon` + chord.
- Existing `StageClearOverlay` (1.4 s) keeps but adds gold light burst.

### C-06 — Time Expired Cinematic **[P1]**

**Visual:**
- Slow-mo: 1 s × 0.3.
- Vignette: tightens over 600 ms.
- Audio: existing `GameAudioEvent.playerLost` + ticking drone.
- Haptic: heavy.
- Existing `RunFailedDialog` (good) stays.

### C-07 — Stage 100 Cleared **[P2, ties to "crown victory" already built]**

**Visual:**
- Existing `Stage100WinDialog` + gold confetti stays.
- Add: exit portal explodes outward (radial shockwave), camera dolly to player, character portrait reveals with cinematic light bar.
- Audio: fanfare.

---

## UX-LEVEL UPGRADES (NOT JUST VFX)

### U-01 — Dynamic Tutorial (Inline, Not Modal)

**Today:** `OnboardingConsentScreen` is a separate screen. New player drops into a 17×17 maze with no guidance.

**Upgrade:** Detect first 3 stages and overlay inline hints:
- Stage 1: subtle arrow above player "Move" — fades after first 3 player steps.
- Stage 2 (flipped): mode label "FLIPPED" pulses red, then arrow on screen "↑ moves ↓" — fades when player completes one cell of inverted movement.
- Stage 3 (devil near): heart-rate audio + devil silhouette zoom — fades after 5 s.

**Why viral:** Lower first-time-player death rate → longer retention → viral coefficient improves.

### U-02 — Combo / Streak Visual

**Today:** nothing tracks consecutive stages cleared without dying.

**Upgrade:** Maintain `_consecutiveClears` in `_GameScreenState`. Show "STREAK ×N" badge in HUD when N ≥ 3. Color escalates: 3 = cyan, 5 = magenta, 10 = gold. Reset on death (without revive).

**Why viral:** Streak counter is a strong retention loop and a strong share hook ("Stage 23, streak 8").

### U-03 — Score Popups

**Today:** no in-game feedback when a milestone happens.

**Upgrade:** `ScorePopup` widget emits floating text from the HUD area:
- "+1 STAGE" (gold) on clear
- "DEVIL +0.4s" (red) on devil distance change crossing threshold
- "SAFE ZONE +1.5s" (cyan) on entering safe zone
- "FLIP +1" (magenta) on first flip survived
- "REVIVE" (gold) on revive

**Why viral:** Every moment of progress is now visually celebrated — the same dopamine loop that makes arcade viral.

### U-04 — Cinematic Screen Transitions

**Today:** `Navigator.push(MaterialPageRoute(...))` — defaults to platform slide.

**Upgrade:** Custom `PageRouteBuilder` with a 250 ms glitch-out (RGB shift + scanlines intensifying) → scene swap → 250 ms glitch-in (reverse). Used for: landing → game, game → loss dialog, game → stage clear, any modal.

**Why viral:** Every navigation feels like entering/leaving a horror film scene.

### U-05 — Haptic Service

**Today:** zero haptics.

**Upgrade:** `HapticService` with patterns:
- `light()` — 10 ms — UI tap
- `medium()` — 25 ms — trap reveal, safe zone entered
- `heavy()` — 50 ms — flip, devil catch, trap collapse
- `warning()` — 10 + 30 + 10 ms — flip warning
- `victory()` — 20 + 30 + 20 + 50 ms — stage clear

**Why viral:** Mobile players spend 80 % of their playtime on mute / with audio off. Haptics is the silent channel.

### U-06 — Character Portraits

**Today:** only sprite sheets.

**Upgrade:** Each character gets a 1024×1024 portrait PNG used on:
- Landing screen "select character" tile (replaces `_CharacterSpritePreview` which crops the sprite)
- Onboarding consent screen
- Stage-100 win screen

**Why viral:** A real portrait reads as "designed game" not "asset pack". The current `_CharacterSpritePreview` is a sprite crop in a colored box — fine for engineering, weak for marketing.

### U-07 — Devil Boss Variants at 25 / 50 / 75 / 100

**Today:** same devil sprite sheet at all stages.

**Upgrade:** Four variants:
- Stage 25: "The Sentinel" — bulky silhouette, deeper red glow
- Stage 50: "The Phantom" — translucent, screen-trail
- Stage 75: "The Void Ripper" — angular, magenta core
- Stage 100: "The Fear Lord" — composite of all three

Each variant is a different sprite sheet. Devil picks the variant based on stage band. Adds a "boss" feel without changing AI behaviour.

**Why viral:** Milestone players see a NEW devil. This is the single highest "did you see that?!" moment a 2D arcade game can deliver.

### U-08 — Adaptive Audio Intensity

**Today:** audio_manager.handle(events) → one-shot sounds. No state-tied ducking.

**Upgrade:** When `devilDistance ≤ 6`, audio_manager ducks BGM to 0.4x and lifts heart-rate layer. When `devilDistance ≤ 2`, full panic. When in safe zone, BGM ducks ambient down, raises safe-zone hum.

**Why viral:** Audio tells the player when they're safe vs in danger even with eyes closed.

### U-09 — Replay Highlight (Auto)

**Today:** none.

**Upgrade:** During stage 1..5, capture the last 5 seconds of player movement into a 60-frame ring buffer. On stage clear, replay it as a 1-second loop with gold tint above the stage-clear overlay.

**Why viral:** Lets players see their own skill — and share it. (Optional: enable save-to-gallery.)

### U-10 — Share Moment

**Today:** none.

**Upgrade:** On stage 100 win, an auto-generated share card (rendered via Flutter widgets, exported via `RenderRepaintBoundary.toImage()`):
- "I escaped Hell. Stage 100."
- Character portrait
- Survival time
- Streak badge if ≥ 10
- App branding + App Store / Play badge

Hook into `share_plus` (already not in pubspec — add it).

---

## ORDER OF IMPLEMENTATION — 12-PR ROADMAP

```
PR-1  ui/hud-flip-warning         ~120 LoC    P0  — ties to audit F-02
PR-2  ui/screen-flash             ~80  LoC    P0  — reusable infra
PR-3  ui/camera-shake             ~100 LoC    P0  — reusable infra
PR-4  ui/slow-motion              ~60  LoC    P0  — reusable infra
PR-5  ui/particle-system          ~250 LoC    P0  — base module + 2 emitters
PR-6  ui/devil-catch-cinematic    ~120 LoC    P1  — ties to C-03
PR-7  ui/trap-collapse-debris     ~80  LoC    P1  — ties to C-04
PR-8  ui/flip-shockwave           ~80  LoC    P0  — ties to C-02
PR-9  ui/trail-painter            ~80  LoC    P1  — C-05 polish
PR-10 ui/vignette-painter         ~80  LoC    P1  — devil-proximity atmosphere
PR-11 ui/ambient-dust             ~80  LoC    P2  — depth-0 atmosphere
PR-12 ui/haptic-service           ~60  LoC    P1  — U-05

— UX layer —
PR-13 ui/score-popups             ~120 LoC    P1  — U-03
PR-14 ui/streak-counter           ~80  LoC    P2  — U-02
PR-15 ui/dynamic-tutorial         ~150 LoC    P2  — U-01

— Cinematic transitions —
PR-16 ui/glitch-page-route        ~80  LoC    P2  — U-04

— Higher-order (needs art) —
PR-17 ui/character-portraits      + art       P2  — U-06
PR-18 ui/devil-boss-variants      + art       P2  — U-07
PR-19 ui/share-card               + share_plus P2  — U-10
PR-20 ui/replay-highlight         ~200 LoC    P2  — U-09
```

**Critical path: PR-1 → PR-5 → PR-8 (the flip cinematic + base particles) unblock everything else.**

After PR-1..PR-5 land, every later PR adds a particle emitter / a haptic / a popup using the existing infra.

---

## DEPENDENCIES (NEW)

| Package | Why | Risk |
|---|---|---|
| `share_plus` | U-10 share card | low — official FPP package |
| `flutter_animate` | optional, for declarative enter animations | none — pure-Dart |

No new platform deps. All shaders use built-in `dart:ui` `Paint` ops and `MaskFilter`. **No GLSL, no Skia custom shaders needed** — Flutter's 2D pipeline is fast enough for this scope.

---

## ART PIPELINE NEEDED

| Asset | Size target | Purpose |
|---|---|---|
| `portrait_sentinel.png` | 1024×1024, transparent | U-06 |
| `portrait_phantom.png` | 1024×1024, transparent | U-06 |
| `portrait_void_ripper.png` | 1024×1024, transparent | U-06 |
| `devil_sentinel.png` (sprite sheet, 8 dirs × 7) | 1024×1024 | U-07 stage 25 |
| `devil_phantom.png` | 1024×1024 | U-07 stage 50 |
| `devil_void.png` | 1024×1024 | U-07 stage 75 |
| `devil_lord.png` | 1280×1280 | U-07 stage 100 |
| `dust_mote.png` | 32×32, transparent | PR-11 |
| `spark.png` | 16×16, additive | PR-5 |
| `shard.png` | 24×24, additive | PR-7 |
| `gold_burst.png` | 64×64, radial gradient | PR-5 |

> **JUDGE whether background needs removing:** portraits — yes (use remove.bg / Adobe Express / Photoshop); devil sheets — yes; particles — already transparent by design (radial gradients with alpha 0).

---

## WHAT TO **NOT** DO

| Anti-pattern | Why |
|---|---|
| Add `flutter_game` or any 2D engine rewrite | the audit shows the runtime is `_GameScreenState`; rewrite is Y-combinator of risk |
| Use `BackdropFilter` for the entire play surface | O(n) on every pixel; reserved for vignette only |
| Repaint entire game surface at 60 Hz | already mitigated by `RepaintBoundary` — keep |
| Add 3D / shaders / particle physics | viral-mobile-2D-arcade doesn't need it; keep the CustomPainter approach |
| Add real-time multiplayer | different scope; not in this plan |
| Use AI-generated character art | the existing spreadsheets are stylised, AI art will break the visual identity |

---

## METRICS THAT PROVE THE UPGRADE WORKED

You can't measure "viral", but you can measure what predicts it:

| Metric | Today | Target |
|---|---|---|
| D1 retention | (unknown — needs Firebase) | +5 % from tutorial + first-death polish |
| Median session length | (unknown) | +20 % from streak counter + score popups |
| Stage 100 completion rate | (unknown) | +10 % from warning + boss variants |
| Crash-free boot | likely OK | unchanged |
| 60 FPS on Pixel 4a | likely OK | unchanged (we have headroom) |
| App Store rating | (unknown) | +0.3 from "feels premium" comments |
| Share rate | 0 | ≥ 1 % of stage-100 winners share |

Add `FirebaseAnalytics` events for each cinematic moment and each popup; track in the existing `analytics_service.dart` (currently mostly dead — this brings it alive).

---

## RISK MATRIX

| Risk | Likelihood | Mitigation |
|---|---|---|
| Particles tank low-end Android FPS | medium | hard cap 200 particles; `prefers-reduced-motion` drops them; cap simultaneous systems at 3 |
| Camera shake triggers motion sickness | low | shake is bounded trauma ≤ 0.6; respects reduced-motion |
| New haptic patterns are too aggressive | low | ship 5 patterns, A/B test, easy to dial down |
| Portrait art doesn't match the cyber-horror tone | medium | brief in PR-17 — see `AppPalette` for color anchors |
| Devil boss variants change the difficulty feel | medium | same AI behaviour; just visual; no game-balance risk |
| Share card exposes PII | low | only shows display name + stage + time, all already public on leaderboard |

---

## WHAT TO BUILD FIRST

**Do these in this order and you'll have a viral-ready UI in 3 weeks:**

1. **PR-1** (flip warning visual) — closes audit F-02, immediately makes the game fairer and more dramatic.
2. **PR-5** (particle system + 2 emitters) — gives every other PR a tool to use.
3. **PR-8** (flip shockwave) — ties to C-02, the game's core identity.
4. **PR-2..PR-4** (flash, shake, slow-mo) — reusable for C-03 / C-04 / C-06.
5. **PR-6** (devil catch cinematic) — biggest "did you see that" moment.
6. **PR-12** (haptics) — silent channel, low cost.
7. **PR-13** (score popups) — dopamine loop, low cost.
8. **PR-11** (ambient dust) — atmosphere polish.
9. **PR-15** (dynamic tutorial) — retention.
10. **PR-17** (character portraits) — needs art; can run in parallel.

After that, you're feature-complete for a viral mobile arcade game. Marketing will get screenshots from C-05 / C-07 / U-07 / U-10 and you'll have something that looks like it cost 50× the budget.

---

## CONNECTION TO THE FORENSIC AUDIT

This plan deliberately **does not overlap** with the P0 game-fix PRs in `plans/02-audit-findings.md`. The two together cover everything:

- **Audit fixes** = make the game **fair and correct**
- **VFX upgrades** = make the game **feel premium and viral**

Order: do the audit fixes first (F-01 → F-02 → F-13 → F-06 → F-19), get them into a beta, **then** stack the VFX upgrades. The VFX work won't fix bugs but will make the bugs *feel* worse if they exist; fixing them first means the VFX work amplifies a fair game, not paper-over a broken one.
