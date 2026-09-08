# FEARFLIP — AI AGENT PROMPTS LIBRARY

**Purpose:** Each prompt below is a self-contained instruction for an AI coding agent to implement a specific feature. Prompts assume the agent has read access to the codebase at `C:\flutter projects\fearflipgame`.

**How to use:**
1. Read `report_of_fearflip.md` for strategic context first
2. Feed prompts one at a time to an AI agent (Claude, GPT, Cursor, Windsurf)
3. Work through the phases in order — each builds on the previous
4. After each prompt, review, test, and commit before moving to the next

---

## PHASE 0: DIAGNOSTIC & FOUNDATION

### Prompt 0.0: Decompose game_screen.dart

```
You are a senior Flutter architect. FearFlip's game_screen.dart is 2,486 lines of 
spaghetti (in C:\flutter projects\fearflipgame\lib\presentation\gameplay\game_screen.dart).

Read the full file. Identify the 8+ distinct responsibilities crammed into _GameScreenState.
Extract each into its own class/file under a new lib/presentation/gameplay/controllers/ directory.

Responsibilities to extract:
1. GameStateManager — stage transitions, checkpoint tracking, game-over logic
2. DevilController — spawn, A* movement, distance tracking, audio dispatch
3. TrapManager — trap lifecycle from placement to collapse (wraps existing trap files)
4. StageTimerManager — countdown timer, panic mode, low-time audio
5. MazeRenderer — painting logic (wraps MazePainter), dirty-region tracking
6. PlayerProgressionManager — stage rules, difficulty, revive counter
7. SafeZoneManager — safe zone lifecycle, respawn logic
8. FlipController — flip timing, inversion state, glitch effect coordination

Refactor game_screen.dart to compose these controllers instead of inline logic.
Each extracted class must be independently testable. Do NOT change game behavior.
Verify with `flutter test` after refactoring.
```

### Prompt 0.1: State Management Migration

```
FearFlip uses a mix of setState + ValueNotifier + ChangeNotifier for state management.
This is fragile and will break with multiplayer.

Migrate to Riverpod (flutter_riverpod). Create the following providers:
- gameStateProvider (GameState — current stage, score, lives, timer)
- playerProvider (PlayerState — position, direction, inverted, speed)
- devilProvider (DevilState — position, spawned, distance, speed)
- mazeProvider (MazeState — grid, shift phase, traps, safe zones)
- audioProvider (AudioState — current track, volume, ducking)
- adProvider (AdState — loaded, showing, cooldown)
- authProvider (AuthState — user, login status)

Each provider must be hot-reload safe and testable with ProviderContainer.
Keep game_screen.dart watching providers, not managing state.
```

---

## PHASE 1: VISUAL OVERHAUL

### Prompt 1.0: Particle System

```
Add a particle system to FearFlip using Flame's ParticleSystemComponent or
a custom implementation. Particles must be implemented for:

1. Trap collapse: debris particles (gray/brown, 20-30 particles, outward burst)
2. Devil spawn: dark mist particles (purple/black, 15 particles, upward dissipation)
3. Flip activation: screen static particles (white/glitch, 50 particles, full screen)
4. Stage clear: golden light particles (yellow/orange, 40 particles, upward fountain)
5. Safe zone: protective bubble particles (blue/cyan, 10 particles, orbiting ring)

File locations:
- lib/presentation/gameplay/vfx/particle_system.dart
- lib/presentation/gameplay/vfx/particle_effects.dart
- lib/presentation/gameplay/vfx/particle_config.dart

Integrate with existing game loop — particles must not affect gameplay performance.
Use object pooling (ObjectPool from lib/engine/systems/object_pool.dart).
Test on a low-end Android device (Moto G Power or equivalent).
```

### Prompt 1.1: Lighting System

```
Implement a 2D lighting system for FearFlip using Flutter's FragmentProgram
(shader-based rendering).

Requirements:
1. Ambient light (dim, scene-wide, color-tinted per stage)
2. Point lights: devil glow (red/purple), exit portal glow (gold), 
   trap glow (subtle green when cracked), player aura (blue)
3. Light attenuation with distance (quadratic falloff)
4. Multiple light layers (ambient < devil < player < portal)
5. Performance: max 8 concurrent point lights, object-pooled

Files:
- lib/presentation/gameplay/vfx/lighting_system.dart
- lib/presentation/gameplay/vfx/light_source.dart
- lib/presentation/gameplay/vfx/light_shaders/ (FragmentProgram .frag files)

Integrate with MazePainter to draw light overlay on top of maze.
Verify no more than 2ms frame time added on iPhone 12 or equivalent.
```

### Prompt 1.2: UI Overhaul (Gothic Horror Theme)

```
Replace all FearFlip UI with a gothic-horror neon aesthetic.

Design system:
- Backgrounds: deep black (#0a0a0a) with subtle noise texture
- Primary text: neon green (#39FF14) with glow effect
- Accent: blood red (#FF1744), electric purple (#A855F7), toxic green (#00FF41)
- Buttons: dark glass panels with neon border (1px, animated pulse)
- Typography: Google Fonts "Cinzel Decorative" for headings, "Rajdhani" for body
- Panels: semi-transparent dark glass with blur backdrop

Files to modify:
- lib/presentation/theme/app_palette.dart — add new color constants
- lib/presentation/gameplay/widgets/game_hud.dart — redesign HUD
- lib/presentation/gameplay/widgets/game_controls.dart — redesign controls
- lib/presentation/gameplay/widgets/run_failed_dialog.dart — redesign death screen
- lib/presentation/gameplay/widgets/stage_clear_overlay.dart — redesign win overlay
- lib/app/fear_flip_app.dart — apply new theme to MaterialApp

Add animations:
- Buttons: hover glow effect (animated opacity on neon border)
- Panels: fade in + slide up on appearance
- HUD numbers: count-up animation, not instant digit change
- Stage transitions: screen wipe effect (radial or directional)

All animations must respect prefers-reduced-motion (Motion's useReducedMotion).
```

### Prompt 1.3: Animated Backgrounds

```
Add animated parallax backgrounds to the maze gameplay.

Background layers (back to front):
1. Deep space/void — subtle star field, slow drift (Layer 0, speed 0.1x)
2. Distant city ruins — silhouettes, slow horizontal scroll (Layer 1, speed 0.2x)  
3. Fog/mist — semi-transparent, diagonal drift with turbulence (Layer 2, speed 0.3x)
4. Maze floor — the actual maze (Layer 3, speed 1.0x)
5. Foreground particles — dust motes, floating embers (Layer 4, speed 1.2x)

Each layer is drawn above/below the maze using layer-specific CustomPainters.
Maze is always on Layer 3.

File: lib/presentation/gameplay/background/parallax_background.dart
File: lib/presentation/gameplay/background/background_layer.dart
File: lib/presentation/gameplay/background/void_background.dart
File: lib/presentation/gameplay/background/city_ruins_background.dart
File: lib/presentation/gameplay/background/fog_background.dart

Performance: reuse existing 50ms tick — do NOT add a second update loop.
Skip foreground particles on devices with < 2GB RAM (check via device_info_plus).
```

---

## PHASE 2: GAMEPLAY DEEPENING

### Prompt 2.0: Power-Up System

```
Implement power-ups in FearFlip. 6 power-up types:

1. Speed Boost (icon: lightning) — 2x movement for 8 seconds, green aura
2. Time Freeze (icon: clock) — pause timer for 10 seconds, blue screen tint  
3. Devil Repel (icon: shield) — push devil to farthest cell, holy flash effect
4. Map Reveal (icon: eye) — show full maze for 5 seconds, fade reveal
5. Shield (icon: barrier) — survive one hit (trap or devil), breaks with shatter
6. Inversion Immunity (icon: brain) — skip next flip, brain icon on HUD

Power-up spawning:
- 1-3 power-ups per stage (scales with maze size)
- Spawn at strategic locations (junctions, dead ends that are on the critical path)
- Cannot spawn on trap tiles, safe zone tiles, start, or exit
- Floating glow animation above tile (pulsing, rotating)
- Visual indicator when picked up (screen flash + icon appears in HUD slot)

Files:
- lib/game/power_up/power_up.dart (enum + data model)
- lib/game/power_up/power_up_spawner.dart (placement logic)
- lib/game/power_up/power_up_effect.dart (effect handlers, timed)
- lib/presentation/gameplay/widgets/power_up_hud.dart (HUD slots)
- lib/presentation/gameplay/maze_painter.dart (add power-up rendering)

Power-ups persist between stages if unused (max 3 held at once).
When full, picking up a new one replaces the oldest.
```

### Prompt 2.1: Roguelite Progression (Soul System)

```
Add roguelite permanent progression to FearFlip.

Currency:
- Soul Shards: earned per run (base: 10 × stage reached, bonuses for traps triggered,
  flips survived, devils evaded)
- Souls persist between runs, survive death

Permanent Upgrades (10 levels each, scaling cost):
1. Soul Speed (+5% move speed per level, max +50%, cost: 100/200/400/800/1600/3200/6400/12800/25600/51200)
2. Soul Time (+5 seconds per level, max +50s, cost: same scaling)
3. Soul Sense (+1 trap detection range per level, max +10, cost: same)
4. Soul Delay (+1s devil spawn delay per level, max +10s, cost: same)
5. Soul Stability (+0.5s flip interval per level, max +5s, cost: same)
6. Soul Resilience (+1 revive per level, max +10, cost: same)

Upgrade screen: accessible from landing screen, shows current level + next level
preview + cost. Animated progression bar.

Files:
- lib/domain/progression/soul_manager.dart
- lib/domain/progression/upgrade_tree.dart
- lib/data/progression_repository.dart
- lib/presentation/screens/upgrade_screen.dart

Steam-like prestige system:
- When all upgrades maxed, offer prestige (reset upgrades, gain prestige level)
- Prestige gives exclusive cosmetics (skins, trails, titles)
- Prestige level shown on profile

Balance: a player should max all upgrades after ~200 hours of play.
Prestige should be achievable once every ~50 hours after maxing.
```

### Prompt 2.2: Character Ability System

```
Give each character unique, unlockable abilities.

Sentinel:
- Passive: automatically reveals traps within 1 cell
- Active (3 charges, recharge 1 per stage cleared): Scan — reveal all traps in 3x3 area for 3 seconds
- Ultimate (unlock at stage 25 completion): Devil Radar — show devil position on HUD for 10 seconds

Phantom:
- Passive: 10% chance to phase through walls when trapped (auto-reroute)
- Active (2 charges, recharge 1 per 2 stages): Phase Walk — walk through 1 wall segment
- Ultimate (unlock at stage 50 completion): Ethereal Form — invisible to devil for 8 seconds

Void Ripper:
- Passive: traps take 1 extra step to collapse (gives more warning)
- Active (3 charges): Gravity Well — slow devil by 50% for 5 seconds in radius
- Ultimate (unlock at stage 75 completion): Void Surge — push all traps in radius to hidden state

Implement ability cooldowns, HUD display (hotkey slots), and visual effects for each.
Files:
- lib/game/abilities/ability_base.dart
- lib/game/abilities/sentinel_abilities.dart
- lib/game/abilities/phantom_abilities.dart
- lib/game/abilities/void_ripper_abilities.dart
- lib/presentation/gameplay/widgets/ability_hud.dart
```

### Prompt 2.3: Boss Stages

```
Add 4 boss stages at milestones (25, 50, 75, 100).

Stage 25 Boss — The Sentinel: 
- Giant devil, occupies 2x2 cells
- Alternates between chase mode and stationary sentry mode
- Sentry mode: sweeps laser across rows/columns (dodge or die)
- 3 health phases: Normal → Enraged (speed x1.5) → Desperate (laser + chase)
- Win condition: survive 90 seconds without dying (exit appears after 90s)
- Visual: red/orange color scheme, sparkle armor, giant sword

Stage 50 Boss — The Phantom:
- Teleporting devil, disappears and reappears near player
- Leaves afterimages that deal damage on contact
- Phases: Teleport Chase → Clone Phase (3 phantoms, 1 real) → Shadow Frenzy
- Win condition: reach the exit that teleports every 15 seconds
- Visual: purple/transparent, trailing smoke, glowing eyes

Stage 75 Boss — The Void Ripper:
- Zone-control devil, creates void zones that grow over time
- Void zones: standing in them deals damage, shrink safe area
- Phases: Void Spread → Zone Divide → Total Darkness (vision shrinks)
- Win condition: activate 3 void anchors before time runs out
- Visual: dark purple/black, space distortion, star particles

Stage 100 Boss — The Fear Lord:
- All abilities combined: teleport + zone + chase + laser
- 5 phases with escalating mechanics
- Final phase: screen-wide glitch, controls random, devil everywhere
- Win condition: survive 120 seconds → cinematic victory → crown
- Visual: all previous boss elements combined, final form

Boss mechanics should reuse existing systems (A* for chase, glitch for effects, traps for zones).

Files:
- lib/game/boss/boss_base.dart
- lib/game/boss/boss_sentinel.dart
- lib/game/boss/boss_phantom.dart
- lib/game/boss/boss_void_ripper.dart
- lib/game/boss/boss_fear_lord.dart
- lib/presentation/gameplay/boss/boss_hud.dart
```

### Prompt 2.4: Alternate Game Modes

```
Add 5 alternate game modes to FearFlip accessible from a new mode-select screen.

1. Endless Mode:
   - Infinite procedural stages, difficulty caps at stage 100 levels
   - Global leaderboard: most stages cleared in single run
   - No continues, no revives — one death ends the run
   - Special endless-only achievements

2. Speedrun Mode:
   - Fixed maze seed per week (same for all players)
   - Fastest completion time wins
   - Ghost overlay shows current #1 run path
   - Weekly leaderboard resets

3. No-Flip Challenge:
   - Devil is faster (1.5x speed)
   - No safe zones
   - No control inversion
   - Higher score multiplier (2x)
   - Separate leaderboard

4. Blind Run:
   - No maze visible (only player position shown)
   - No trap cues (invisible until collapse)
   - Devil has no spawn delay (appears immediately)
   - Wall touching reveals adjacent cells (fog of war)
   - Score multiplier: 3x

5. Daily Challenge:
   - Same seed for all players worldwide
   - Fixed difficulty (stage 50 equivalent)
   - One run per day
   - Leaderboard per day
   - Participation reward (soul shards)

File: lib/presentation/screens/mode_select_screen.dart
File: lib/domain/game_modes/game_mode.dart
File: lib/domain/game_modes/endless_mode.dart (etc. for each mode)
File: lib/data/mode_leaderboard_service.dart
```

---

## PHASE 3: MULTIPLAYER & SOCIAL

### Prompt 3.0: Ghost Replay System

```
The cheapest, highest-impact multiplayer feature. Record player runs and replay them
as ghost overlays.

Recording system:
- Record every player action: position (every tick), direction changes, ability uses, trap triggers
- Compress recording: only store changes (not every tick), delta compression
- Store format: JSON with initial state + array of timed deltas
- Max recording size: < 100KB per run (target: 20KB for 100-stage run)

Playback system:
- Ghost appears as semi-transparent version of player character
- Ghost follows recorded path with exact timing
- Show ghost position relative to current player (ahead/behind indicator)
- Ghost cannot interact with current game state (no collision with traps/devil)

Friend ghost:
- Friend's best run on same stage
- Shown as different color ghost
- Beat-them indicator: "You're X cells ahead/behind"

World ghost:
- Best run globally for current stage
- Shown as gold/legendary ghost
- Not available in boss stages

Storage:
- Firebase Firestore: /replays/{replayId} 
- Shard by stage + month for query performance
- Auto-delete replays older than 90 days

Files:
- lib/services/replay_service.dart
- lib/services/replay_recorder.dart  
- lib/services/replay_player.dart
- lib/presentation/gameplay/ghost_renderer.dart
```

### Prompt 3.1: Async Challenge System

```
Allow players to challenge friends with a shareable link.

Flow:
1. Player completes a run → "Challenge a Friend" button
2. System generates challenge: current stage seed + player's ghost data + timestamp
3. Short code generated (e.g., "FEAR-7X9K") — 6 chars, alphanumeric
4. Deep link: fearflip://challenge/FEAR-7X9K
5. Share via system share sheet (text + link)
6. Recipient opens link → app opens (or store if not installed)
7. Plays same stage with challenger's ghost overlay
8. Result: beat/loss notification sent back to challenger

Leaderboard integration:
- Win/loss tracking per head-to-head matchup
- "Challenger rating" (ELO-like for friend challenges)

Storage:
- Firebase Firestore: /challenges/{code}
- TTL: 7 days auto-delete
- Index by: creator, recipient, stage, timestamp

Files:
- lib/services/challenge_service.dart
- lib/services/deep_link_handler.dart
- lib/presentation/screens/challenge_screen.dart
- lib/presentation/widgets/challenge_result.dart
```

### Prompt 3.2: Real-Time 2-Player Co-op

```
Real-time co-op mode using WebSocket relay server.

Gameplay:
- 2 players, same maze (larger: extra 5 rows/cols)
- Split-screen on same device OR separate devices over network
- Each player starts at different maze locations
- Exit requires two keys (one per player, must reach exit together within 5 seconds)
- Devil chases the player who is closer (distance-based targeting, already implemented)
- If one player dies, the other has 10 seconds to reach a revive altar
- Communication: quick-chat wheel (8 phrases: "Help!", "Follow me", "Devil!", "Go!", "Wait", "Nice!", "Oops", "GG")

Network architecture:
- Client A → WebSocket → Relay Server → WebSocket → Client B
- Server is authoritative for devil AI and collision
- Client is authoritative for input (server validates)
- State sync at 20Hz (every 3rd game tick)
- Lag compensation: client predicts movement, server corrects

Server tech: Node.js + Colyseus (or Nakama if self-hosting preferred)
Deploy: Railway.app or Fly.io for MVP, scale to dedicated later
Max rooms: 1,000 concurrent (2 vCPU, 4GB RAM target)

Files (client):
- lib/services/multiplayer/coop_client.dart
- lib/services/multiplayer/network_message.dart
- lib/presentation/gameplay/coop_screen.dart

Files (server):
- server/package.json
- server/src/index.ts
- server/src/rooms/CoopRoom.ts
- server/Dockerfile
- server/fly.toml
```

### Prompt 3.3: Real-Time PvP Arena

```
2-4 player PvP arena mode. Last survivor wins.

Rules:
- Same maze (large, 20x20)
- Each player has their own devil
- When a player dies, their devil transfers to a random surviving player
- Power-ups in center: speed, shield, devil redirect (send devil to another player), invisibility
- Match time: 3 minutes max
- If multiple survivors at time limit: player with most power-up pickups wins

Matchmaking:
- ELO-based ranking system
- Solo queue (2-4 players)
- Party queue (pre-made teams of 2)
- Ranked and casual queues
- Average queue time target: < 30 seconds

Spectator mode:
- Top-down view of entire maze
- Show all players + devils
- Player POV toggle
- Replay save + share

Server infrastructure (same as co-op, extended):
- Room type: PvPRoom
- States: Lobby, Countdown, Playing, Results
- Matchmaker service: /matchmaking/queue, /matchmaking/leave, /matchmaking/status

Files (client):
- lib/services/multiplayer/pvp_client.dart
- lib/services/multiplayer/matchmaking_service.dart
- lib/presentation/screens/pvp_lobby_screen.dart
- lib/presentation/screens/pvp_match_screen.dart
- lib/presentation/screens/pvp_results_screen.dart

Files (server):
- server/src/rooms/PvPRoom.ts
- server/src/matchmaking/Matchmaker.ts
- server/src/ranking/ELOSystem.ts
```

### Prompt 3.4: Social Features (Friends, Guilds, Profile)

```
Implement social layer.

Friend system:
- Add friend by username or UID
- Friend requests (accept/decline/block)
- Friend list with online status
- Challenge friend button
- Friend leaderboard (only friends' scores)

Guild system:
- Create guild (name, tag, emblem color, description)
- Join/leave guild
- Guild chat (Firebase Realtime Database)
- Guild leaderboard (combined scores of all members)
- Guild boss battles (weekly, guild works together to defeat mega-boss)
- Guild level (XP earned through member activity, unlocks perks)

Player profile:
- Username, avatar frame (from collection)
- Stats: total stages cleared, best endless run, PvP rank, total play time
- Achievement showcase (pick 3 to display)
- Win/loss record
- Character mastery levels
- Prestige level

Files:
- lib/services/social/friend_service.dart
- lib/services/social/guild_service.dart
- lib/services/social/profile_service.dart
- lib/services/social/chat_service.dart
- lib/presentation/screens/profile_screen.dart
- lib/presentation/screens/friends_screen.dart
- lib/presentation/screens/guild_screen.dart
- lib/presentation/screens/guild_chat_screen.dart
- lib/presentation/screens/guild_boss_screen.dart
```

---

## PHASE 4: ECONOMY & MONETIZATION 2.0

### Prompt 4.0: Currency System

```
Replace the current trivial economy with a 3-currency system.

Soul Shards (earned currency):
- Earned by: completing stages (10 per stage), winning PvP (20 per win),
  daily login (50 per day), achievements (100-1000), guild rewards
- Spent on: permanent upgrades, common cosmetics, entry fees for special events
- Max per day from gameplay: 500 (cap prevents grind abuse)
- No IAP for soul shards (player respect)

Fear Crystals (premium currency):
- Earned by: IAP purchases, free from battle pass (30-50 per season),
  rare achievements, first-time PvP rank milestones
- Spent on: premium cosmetics, battle pass unlock, extra revive charges,
  exclusive character skins, name color changes
- IAP packs: 50 ($0.99), 200 ($2.99), 550 ($4.99), 1200 ($9.99), 3000 ($19.99), 8000 ($49.99)

Obsidian (event currency):
- Earned during seasonal events only
- Spent on event-exclusive items (skins, frames, titles)
- Converted to soul shards at 1:10 rate after event ends

Storage:
- Firestore: /players/{uid}/currencies
- Local cache: SharedPreferences for offline balance display
- Server-authoritative: Cloud Function validates all currency mutations
- Receipt validation for premium currency (already built for IAP)

Files:
- lib/domain/economy/currency.dart (enum + amounts)
- lib/domain/economy/currency_manager.dart
- lib/data/currency_repository.dart
- lib/presentation/widgets/currency_display.dart (animated HUD counter)
- functions/src/economy/ (server-side validation)
```

### Prompt 4.1: Battle Pass

```
Implement a seasonal battle pass system.

Structure:
- Season duration: 8 weeks
- 50 tiers (free + premium track)
- XP to level up: 1000 per tier (linear, 50,000 XP to complete)
- XP sources: daily challenge (500 XP), PvP win (100 XP), stage clear (50 XP),
  achievement unlock (250 XP), first login of day (200 XP)

Free track rewards (every 5 tiers):
- 5: 50 Soul Shards
- 10: common trail effect
- 15: 100 Soul Shards
- 20: common profile frame
- 25: 150 Soul Shards
- 30: common avatar
- 35: 200 Soul Shards
- 40: "Survivor" title
- 45: 250 Soul Shards
- 50: free exclusive skin (season-themed)

Premium track ($9.99, adds rewards on every tier):
- Every tier: premium currency + exclusive item
- 10: rare trail effect
- 25: rare skin
- 40: animated profile frame
- 50: legendary skin + season badge

Battle pass screen: visual tier progression, current tier highlighted,
preview next rewards, buy button.

Backend:
- Firestore: /seasons/{seasonId}, /players/{uid}/battle_pass
- Cloud Function: tierUnlock check (validates XP, issues rewards)
- No refund on purchased but unearned premium track (standard practice)

Files:
- lib/services/battle_pass_service.dart
- lib/data/battle_pass_repository.dart
- lib/presentation/screens/battle_pass_screen.dart
- functions/src/battle_pass/
```

### Prompt 4.2: Cosmetics System

```
Implement a full cosmetics system.

Cosmetic categories:
1. Character skins (per character, 10+ each)
2. Devil skins (change devil appearance, 6+)
3. Trail effects (footstep particles, 8+)
4. Death animations (custom death screen, 6+)
5. Portal skins (exit portal appearance, 6+)
6. HUD themes (color schemes, 6+)
7. Profile frames (animated, 12+)
8. Avatar icons (20+)
9. Titles (displayed on profile, 20+)

Rarity tiers:
- Common (free/battle pass free track)
- Rare (battle pass premium, 200 crystals)
- Epic (400 crystals, event exclusive)
- Legendary (800 crystals, battle pass tier 50, prestige reward)

Cosmetic screen:
- Grid layout with category tabs
- Preview: see skin on character model, play death animation, show trail
- Owned/unowned state with lock icon
- Equip button
- "Complete set" indicator

Storage:
- Firestore: /players/{uid}/cosmetics/{category}/{itemId}
- Each cosmetic is a Firestore document with: owned, equipped, equippedAt
- Cosmetics data: /cosmetics/{category}/{itemId} (name, description, rarity, asset path)

Files:
- lib/services/cosmetics_service.dart
- lib/data/cosmetic_catalog.dart
- lib/presentation/screens/cosmetics_screen.dart
- lib/presentation/screens/cosmetic_detail_screen.dart
- lib/presentation/widgets/cosmetic_tile.dart
```

### Prompt 4.3: IAP Restructure

```
Expand FearFlip's IAP beyond the single "remove_ads_01" SKU.

New IAP catalog:

Consumables:
- crystals_50: 50 Fear Crystals, $0.99
- crystals_200: 200 Fear Crystals, $2.99
- crystals_550: 550 Fear Crystals, $4.99
- crystals_1200: 1200 Fear Crystals, $9.99
- crystals_3000: 3000 Fear Crystals, $19.99
- crystals_8000: 8000 Fear Crystals, $49.99

Non-consumables:
- remove_ads_01: Remove Ads, $4.99 (existing, keep)
- starter_pack: 300 Crystals + exclusive Sentinel skin + 1000 Soul Shards, $2.99

Subscriptions:
- fear_pass_monthly: 500 Crystals/month + daily reward booster + exclusive items, $4.99/month

Auto-renewable subscription with:
- Free trial (3 days)
- Introductory price ($1.99 for first month)
- Regular price ($4.99/month) after intro
- Cancel anytime

Server-side validation (already built for remove_ads):
- verifyOneTimePurchase extended for all non-consumable IAP
- verifySubscription for subscriptions
- Receipt validation via Play Developer API + App Store Server API

Store listing updates:
- iOS: update StoreKit configuration
- Android: update Play Console managed products

Files:
- lib/services/purchase_service.dart (extend for new SKUs)
- lib/services/subscription_service.dart (new)
- lib/presentation/screens/shop_screen.dart (new)
- functions/src/payments/
- docs/iap-catalog.md (document all SKUs)
```

### Prompt 4.4: Ad Strategy Revision

```
Revise FearFlip's ad strategy to maximize revenue without harming player experience.

Current issues:
- Interstitials are too frequent (player resentment)
- Rewarded ads only for revive (limited utility)
- No offerwall

New strategy:

Interstitials:
- Max 1 per 5 minutes of play
- Never between stage 1-5 (protect onboarding)
- Never during boss fights
- Always after a death (not during gameplay)
- HIGHLY REDUCED from current frequency

Rewarded ads:
- Revive (existing, keep)
- Bonus Souls: watch ad → 1.5x soul shards for next stage
- Extra Time: watch ad → +30 seconds on timer
- Power-up Refill: watch ad → regain one ability charge
- Battle Pass XP: watch ad → +500 XP (one time per day)
- Free Cosmetic Reroll: watch ad → reroll daily free cosmetic offer

Offerwall:
- Implement via FYBER or Tapjoy SDK
- Players earn premium currency by completing offers
- Available from shop screen
- No ads required — user opts in

Banner ads:
- Only on landing screen and profile screen
- Never during gameplay
- Removed by remove_ads IAP (existing)

File changes:
- lib/services/ad_manager.dart (update placement logic)
- lib/services/ad_placement_policy.dart (new frequency rules)
- lib/services/ads_facade.dart (add offerwall support)
- lib/services/offerwall_service.dart (new)
- lib/presentation/gameplay/widgets/revive_dialog.dart (add other rewarded options)
```

---

## PHASE 5: PLATFORM EXPANSION & LIVE OPS

### Prompt 5.0: Steam Release

```
Port FearFlip to Steam using Flutter's desktop support.

Requirements:
- Windows + macOS support (verify on both)
- Steamworks SDK integration (achievements, cloud saves, friends list)
- Big Picture mode support (controller navigation)
- Steam leaderboards (replace Firebase leaderboards on Steam)
- Steam Inventory for cosmetics (if desired)

Flutter desktop setup:
- Enable Windows and macOS in flutter config
- Create windows/ and macos/ platform directories
- Test on actual Windows PC and Mac

Steam-specific changes:
- Keyboard + mouse controls (aim with mouse, WASD movement)
- Controller support (Xbox/PlayStation controllers via Flutter gamepad)
- 16:9 aspect ratio lock
- Scalable UI for different resolutions (720p, 1080p, 1440p, 4K)
- Windowed + fullscreen toggle
- Steam overlay compatibility
- FPS counter option (players expect it on PC)

Steam page:
- Create Steamworks app
- Upload build periodically
- Set up depots for Windows + macOS
- Steam Pipe bootstrapper

Files:
- lib/platform/steam/steam_manager.dart
- lib/platform/steam/steam_achievements.dart
- lib/platform/steam/steam_leaderboard.dart
- lib/platform/input/controller_input.dart
- windows/ (various C++ wrapper files)
- macos/ (various Swift wrapper files)
- steamworks/ (SDK setup)
```

### Prompt 5.1: Nintendo Switch Port

```
Optimize FearFlip for Nintendo Switch (Flutter + Flame supports Switch).

Switch-specific considerations:
- 720p handheld / 1080p docked resolution targets
- Joy-Con controller support (both single and dual)
- Touch screen support (handheld mode)
- Performance target: smooth 60fps at 720p
- Significantly smaller texture budget (max 1024x1024 per sprite)
- Save data via Switch save API
- No ads (Switch doesn't allow in-game ads)
- DLC-based monetization (cosmetic packs on eShop)

Optimizations needed:
- Reduce texture atlas sizes
- Object pool everything (no runtime allocations)
- Kill particles on Switch (too GPU intensive)
- Simpler background layers (2 instead of 5)
- Reduce trap state update frequency (every 100ms instead of 50ms)
- Use 16-bit textures where possible

Nintendo specific:
- Apply for Nintendo Developer Portal access
- Implement NNID authentication (optional)
- Implement save data management
- Achievements in-game (Switch has no system achievements)
- eShop DLC configuration

Files:
- lib/platform/switch/switch_manager.dart
- lib/platform/switch/switch_save_data.dart
- lib/platform/input/joycon_input.dart
```

### Prompt 5.2: WebGL Build

```
Build FearFlip as a WebGL game playable in browser.

Flutter Web setup:
- Configure for CanvasKit renderer (not HTML renderer)
- Optimize initial bundle size
- Implement lazy loading for assets
- Enable brotli compression

Web-specific:
- URL routing for challenge links (fearflip.com/challenge/FEAR-7X9K)
- Social share API integration (Web Share API)
- Keyboard controls only (no touch joystick on desktop)
- Touch-friendly UI for mobile browsers
- Service worker for offline support
- SEO: meta tags, Open Graph for share links
- Firebase hosting (already configured in .firebaserc)

Performance targets:
- Initial load: < 3 seconds on fast connection (brotli + brotli)
- Runtime: 30fps minimum on modern browser
- Memory: < 200MB
- Bundle size: < 5MB initial, 10MB total

Viral optimization:
- Share link plays embedded version on social media
- "Play in browser — no download required" CTA
- Web version has timer-based demo (play 5 stages, then install prompt)
- Saves progress to local storage (no account needed for web)

Files:
- web/ (Flutter web setup)
- lib/platform/web/web_share.dart
- lib/platform/web/seo_manager.dart
- firebase.json (hosting config)
```

### Prompt 5.3: Live Operations Infrastructure

```
Build the backend for live operations.

Remote Config:
- Firebase Remote Config for: feature flags, tuning parameters, event schedules, shop prices
- Cache locally for 1 hour
- Config parameters documented in a source of truth

CMS (Content Management System):
- Firebase Admin SDK-based CMS for: stages, items, cosmetics, events, messages
- Admin can add/modify without app update
- Content versioning (current + next version)
- Content preview for testing

Event System:
- Configure via Firestore: /events/{eventId}
- Event types: DailyChallenge, BossWeekend, DoubleSouls, PvPSeason, HolidayEvent
- Event start/end times (UTC), rewards, modifiers
- Client polls /events on startup + every hour

Push Notifications:
- Firebase Cloud Messaging
- Events: daily challenge available, friend request, PvP match found, 
  guild boss defeated, season ending soon, login streak about to break
- Notification preferences per player (opt-in per category)
- Throttled: max 3 per day per player

A/B Testing:
- Use Firebase Remote Config conditions
- Test: battle pass price ($9.99 vs $7.99), revive cost (1 ad vs 2 ads vs free),
  daily reward amounts, interstitial frequency
- Metrics: conversion rate, retention, ARPU, session length
- Minimum 10,000 players per variant for statistical significance

Files:
- lib/services/live_ops/remote_config_service.dart
- lib/services/live_ops/event_service.dart
- lib/services/live_ops/notification_service.dart
- lib/services/live_ops/ab_testing_service.dart
- functions/src/live_ops/ (admin endpoints)
- docs/live-ops-runbook.md
```

### Prompt 5.4: Community Level Editor

```
Build a drag-and-drop level editor for FearFlip.

Editor features:
- Canvas: tap to place/remove walls, start, exit, traps, safe zones, power-ups
- Grid overlay with snap
- Difficulty rating auto-calculated (path length, trap density, maze complexity)
- Test play button (run the maze immediately)
- Save as: local draft (device storage), published (Firestore after validation)

Level format:
- Seed + override data (tile mutations from procedural result)
- Compressed JSON: under 2KB per level
- Versioned format for backward compatibility

Publishing:
- Upload to Firestore: /community_levels/{levelId}
- Required: name (3-30 chars), difficulty rating (auto), creator UID
- Optional: description, tags
- Auto-validated: must be solvable (BFS path check), must have at least 2 traps,
  must not be trivial (path length >= 10)

Browsing:
- Home tab: featured, recent, top-rated, friends' levels
- Search by name, creator, difficulty, tags
- Rating: 1-5 stars
- Reports: inappropriate content flag

Rewards:
- Creator earns souls when their level is played (1 soul per play, max 100/day)
- Weekly contest: top 3 levels by rating get premium currency
- Creator level badge on profile

Files:
- lib/presentation/screens/level_editor_screen.dart
- lib/presentation/screens/level_browser_screen.dart
- lib/services/community_level_service.dart
- lib/data/community_level_repository.dart
- functions/src/community_levels/
```

---

## URGENT FIXES (Do Before Anything Else)

### Hotfix 0: Performance Audit

```
Read lib/presentation/gameplay/game_screen.dart. The _onStageTick method calls
setState every 50ms, which rebuilds the entire widget tree.

Implement a dirty-region flag system:
- Replace setState with conditional rebuild
- Only repaint when: player moved, devil moved, timer changed, trap state changed,
  flip happened, maze shifted
- Use ValueNotifier<int> revisions per subsystem instead of single boolean

Expected result: setState calls drop from 20/sec to ~3-5/sec on average.
```

---

## DEPENDENCY GRAPH

```
Prompt 0.0 (Decompose) ─┬─ Prompt 0.1 (State Mgmt)
                         │
Prompt 1.0 (Particles)   │
Prompt 1.1 (Lighting)    │
Prompt 1.2 (UI) ─────────┤
Prompt 1.3 (Backgrounds) │
                         │
Prompt 2.0 (Power-ups) ──┤
Prompt 2.1 (Progression) │
Prompt 2.2 (Abilities) ──┤
Prompt 2.3 (Bosses)      │
Prompt 2.4 (Modes)       │
                         │
Prompt 3.0 (Ghosts) ─────┤
Prompt 3.1 (Challenges) ─┤
Prompt 3.2 (Co-op) ──────┤
Prompt 3.3 (PvP) ────────┤
Prompt 3.4 (Social)       │
                         │
Prompt 4.0 (Currency) ───┤
Prompt 4.1 (Battle Pass) │
Prompt 4.2 (Cosmetics) ──┤
Prompt 4.3 (IAP) ────────┤
Prompt 4.4 (Ads)         │
                         │
Prompt 5.0 (Steam)       │
Prompt 5.1 (Switch)      │
Prompt 5.2 (Web)         │
Prompt 5.3 (Live Ops) ───┤
Prompt 5.4 (Level Editor)
```

**Arrow (→) means "depends on".** Execute in order within each phase.
Phases 1-5 can run sequentially top-to-bottom.
Prompts without arrows are independent within their phase.

---

*Generated by gstack AI Agent Prompts Library*
*Each prompt is designed to be fed to an AI coding agent with read/write access to the codebase*
