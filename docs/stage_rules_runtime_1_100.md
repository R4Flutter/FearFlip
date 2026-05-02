# Stage 1-100 runtime rules (generated)

Generated on 2026-05-02 from:
- lib/presentation/gameplay/stage_rules.dart
- lib/presentation/gameplay/game_screen.dart (maze clamp + devil runtime math)
- lib/game/trap/trap_difficulty_scaler.dart (trap scaling)

## Notes (important)
- GameScreen clamps maze size to 17 (`_maxPlayableMazeSize`), so any StageRule `mazeSize` > 17 plays as 17x17.
- StageRules.forStage() overrides `devilSpeedMultiplier` when `devilEnabled == true`: it becomes `playerSpeedMultiplier - 0.01`.
- GameScreen clamps devil movement to max **3.0 steps/sec** (`devilStepsPerSecond` after scaling).
- In GameScreen, `warningTime`, `safeZoneCount`, and `safeZoneDurationSeconds` are currently not wired into gameplay logic.

## Key formulas (as implemented)
- Effective maze size: `clamp(mazeSize, 10, 17)`
- Devil speed multiplier (runtime): `clamp(playerSpeedMultiplier - 0.01, 0.01, playerSpeedMultiplier)`
- Devil steps/sec (runtime): `clamp(devilStepsPerSecond * (devilSpeedMultiplier / playerSpeedMultiplier), 0.2, 3.0)`
- Devil respawn steps after safe zone: `round(5 + (2-5) * ((stage-1)/99))`, clamped to 2-5
- Maze shift eligibility: every 6th stage (`stage % 6 == 0`)

## Full per-stage table
Columns:
- `Maze(def)` = value in StageRules map
- `Maze(eff)` = what GameScreen actually uses
- `DevSteps(base)` = StageRules `devilStepsPerSecond`
- `DevSteps(rt)` = what GameScreen actually uses after speed-ratio + clamp
- `TrapTarget` = TrapDifficultyScaler target count (before placement validation / safe-zone filtering)

| Stage | Name | Maze(def) | Maze(eff) | PlayerMul | Flip(s) | Rand(min-max) | FirstFlip(s) | DevilDelay(s) | DevilDist(c) | DevSteps(base) | DevSteps(rt) | RespawnSteps | Shift? | TrapTarget | TrapBand | HiddenCue | Chokes? |
|---:|---|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|:---:|---:|---|---:|:---:|
| 1 | Awakening | 10 | 10 | 1.00 | 5.00 | 0.00-0.00 | 4.00 | 8.00 | 9 | 0.35 | 0.35 | 5 |  | 1 | tutorial | 1.00 |  |
| 2 | Inversion | 11 | 11 | 1.00 | 5.00 | 0.00-0.00 | 3.00 | 7.00 | 8 | 0.45 | 0.45 | 5 |  | 1 | tutorial | 1.00 |  |
| 3 | Control | 12 | 12 | 1.05 | 5.00 | 0.10-0.20 | 3.00 | 6.00 | 8 | 0.55 | 0.54 | 5 |  | 1 | tutorial | 1.00 |  |
| 4 | Distortion | 13 | 13 | 1.05 | 4.50 | 0.20-0.30 | 2.50 | 5.50 | 7 | 0.65 | 0.64 | 5 |  | 2 | tutorial | 1.00 |  |
| 5 | First Contact | 14 | 14 | 1.08 | 4.00 | 0.20-0.30 | 2.50 | 5.00 | 7 | 0.75 | 0.74 | 5 |  | 2 | tutorial | 1.00 |  |
| 6 | Pursuit | 15 | 15 | 1.08 | 4.00 | 0.25-0.25 | 2.50 | 3.00 | 6 | 0.85 | 0.84 | 5 | Y | 2 | tutorial | 0.82 |  |
| 7 | Decisions | 16 | 16 | 1.10 | 3.80 | 0.30-0.30 | 2.50 | 3.00 | 5 | 0.95 | 0.94 | 5 |  | 2 | tutorial | 0.82 |  |
| 8 | Acceleration | 17 | 17 | 1.12 | 3.50 | 0.35-0.35 | 2.20 | 2.50 | 4 | 1.05 | 1.04 | 5 |  | 6 | tutorial | 0.82 |  |
| 9 | Instability | 18 | 17 | 1.12 | 3.50 | 0.40-0.40 | 2.20 | 2.50 | 4 | 1.15 | 1.14 | 5 |  | 6 | tutorial | 0.82 |  |
| 10 | Trial | 19 | 17 | 1.15 | 3.25 | 0.45-0.45 | 2.00 | 2.00 | 3 | 1.30 | 1.29 | 5 |  | 6 | tutorial | 0.82 |  |
| 11 | Disturbance | 19 | 17 | 1.15 | 3.25 | 0.45-0.45 | 2.00 | 2.00 | 3 | 1.35 | 1.34 | 5 |  | 9 | pressure | 0.82 |  |
| 12 | Split Mind | 20 | 17 | 1.16 | 3.20 | 0.50-0.50 | 2.00 | 2.00 | 3 | 1.40 | 1.39 | 5 | Y | 9 | pressure | 0.82 |  |
| 13 | Deception | 20 | 17 | 1.17 | 3.05 | 0.50-0.50 | 1.80 | 1.80 | 3 | 1.50 | 1.49 | 5 |  | 9 | pressure | 0.82 |  |
| 14 | Instability | 21 | 17 | 1.18 | 2.95 | 0.55-0.55 | 1.80 | 1.80 | 2 | 1.60 | 1.59 | 5 |  | 9 | pressure | 0.82 |  |
| 15 | Instability Peak | 21 | 17 | 1.20 | 2.80 | 0.55-0.55 | 1.50 | 1.50 | 2 | 1.68 | 1.67 | 5 |  | 9 | pressure | 0.82 |  |
| 16 | Stabilization | 20 | 17 | 1.18 | 3.25 | 0.40-0.40 | 2.20 | 3.00 | 5 | 1.50 | 1.49 | 5 |  | 9 | pressure | 0.58 |  |
| 17 | Re-engage | 21 | 17 | 1.20 | 3.00 | 0.45-0.45 | 2.00 | 2.50 | 4 | 1.58 | 1.57 | 5 |  | 9 | pressure | 0.58 |  |
| 18 | Disruption | 21 | 17 | 1.22 | 2.85 | 0.50-0.50 | 2.00 | 2.20 | 3 | 1.65 | 1.64 | 4 | Y | 9 | pressure | 0.58 |  |
| 19 | Compression | 22 | 17 | 1.22 | 2.65 | 0.55-0.55 | 1.90 | 2.00 | 3 | 1.72 | 1.71 | 4 |  | 9 | pressure | 0.58 |  |
| 20 | Chaos Entry | 22 | 17 | 1.25 | 2.55 | 0.60-0.60 | 1.80 | 1.80 | 2 | 1.80 | 1.79 | 4 |  | 9 | pressure | 0.58 |  |
| 21 | Overload Begins | 22 | 17 | 1.25 | 2.45 | 0.60-0.60 | 1.80 | 1.80 | 2 | 1.86 | 1.85 | 4 |  | 10 | pressure | 0.58 |  |
| 22 | Instability Surge | 22 | 17 | 1.27 | 2.35 | 0.65-0.65 | 1.60 | 1.60 | 2 | 1.93 | 1.91 | 4 |  | 10 | pressure | 0.58 |  |
| 23 | Mental Break | 22 | 17 | 1.28 | 2.25 | 0.70-0.70 | 1.50 | 1.50 | 2 | 2.00 | 1.98 | 4 |  | 10 | pressure | 0.58 |  |
| 24 | Final Stretch | 22 | 17 | 1.30 | 2.15 | 0.75-0.75 | 1.50 | 1.50 | 1 | 2.08 | 2.06 | 4 | Y | 10 | pressure | 0.58 |  |
| 25 | Checkpoint Break | 20 | 17 | 1.28 | 2.75 | 0.50-0.50 | 3.00 | 3.00 | 5 | 1.60 | 1.59 | 4 |  | 10 | pressure | 0.58 |  |
| 26 | False Security | 22 | 17 | 1.30 | 2.55 | 0.50-0.50 | 2.40 | 2.40 | 2 | 2.15 | 2.13 | 4 |  | 10 | pressure | 0.58 |  |
| 27 | Tracking Shift | 22 | 17 | 1.32 | 2.45 | 0.55-0.55 | 2.20 | 2.20 | 2 | 2.22 | 2.20 | 4 |  | 10 | pressure | 0.58 |  |
| 28 | Shifted Reality | 23 | 17 | 1.34 | 2.35 | 0.58-0.58 | 2.00 | 2.00 | 2 | 2.30 | 2.28 | 4 |  | 10 | pressure | 0.58 |  |
| 29 | Pressure Loop | 23 | 17 | 1.35 | 2.25 | 0.60-0.60 | 1.90 | 1.90 | 1 | 2.36 | 2.34 | 4 |  | 10 | pressure | 0.58 |  |
| 30 | Collapse Entry | 23 | 17 | 1.36 | 2.15 | 0.60-0.60 | 1.80 | 1.80 | 1 | 2.42 | 2.40 | 4 | Y | 10 | pressure | 0.58 |  |
| 31 | Unstable Flow | 23 | 17 | 1.36 | 2.15 | 0.60-0.60 | 1.80 | 1.80 | 1 | 2.46 | 2.44 | 4 |  | 10 | pressure | 0.34 |  |
| 32 | Cut-Off | 24 | 17 | 1.38 | 2.05 | 0.60-0.60 | 1.70 | 1.70 | 1 | 2.52 | 2.50 | 4 |  | 10 | pressure | 0.34 |  |
| 33 | Dual Pressure | 24 | 17 | 1.39 | 2.05 | 0.60-0.60 | 1.70 | 1.70 | 1 | 2.58 | 2.56 | 4 |  | 10 | pressure | 0.34 |  |
| 34 | Distorted Reality | 24 | 17 | 1.40 | 1.95 | 0.60-0.60 | 1.60 | 1.60 | 1 | 2.64 | 2.62 | 4 |  | 10 | pressure | 0.34 |  |
| 35 | Breaking Point | 24 | 17 | 1.41 | 1.95 | 0.60-0.60 | 1.60 | 1.60 | 1 | 2.68 | 2.66 | 4 |  | 10 | pressure | 0.34 |  |
| 36 | Pressure Continuum | 24 | 17 | 1.42 | 1.90 | 0.60-0.60 | 1.60 | 1.60 | 1 | 2.72 | 2.70 | 4 | Y | 10 | mastery | 0.34 |  |
| 37 | Prediction Lock | 24 | 17 | 1.43 | 1.90 | 0.60-0.60 | 1.60 | 1.60 | 1 | 2.76 | 2.74 | 4 |  | 10 | mastery | 0.34 |  |
| 38 | Distortion Stack | 25 | 17 | 1.44 | 1.85 | 0.60-0.60 | 1.50 | 1.50 | 1 | 2.80 | 2.78 | 4 |  | 10 | mastery | 0.34 |  |
| 39 | False Reality | 25 | 17 | 1.45 | 1.80 | 0.60-0.60 | 1.50 | 1.50 | 1 | 2.84 | 2.82 | 4 |  | 10 | mastery | 0.34 |  |
| 40 | Control Break | 25 | 17 | 1.46 | 1.80 | 0.60-0.60 | 1.50 | 1.50 | 1 | 2.88 | 2.86 | 4 |  | 10 | mastery | 0.34 |  |
| 41 | Pressure Reloaded | 25 | 17 | 1.47 | 1.80 | 0.60-0.60 | 1.50 | 1.50 | 1 | 2.92 | 2.90 | 4 |  | 10 | mastery | 0.34 |  |
| 42 | Hunted | 25 | 17 | 1.48 | 1.75 | 0.60-0.60 | 1.40 | 1.40 | 1 | 2.96 | 2.94 | 4 | Y | 10 | mastery | 0.34 |  |
| 43 | Distortion Core | 26 | 17 | 1.49 | 1.75 | 0.60-0.60 | 1.40 | 1.40 | 1 | 3.00 | 2.98 | 4 |  | 10 | mastery | 0.34 |  |
| 44 | False Signals | 26 | 17 | 1.50 | 1.70 | 0.60-0.60 | 1.40 | 1.40 | 1 | 3.04 | 3.00 | 4 |  | 10 | mastery | 0.34 |  |
| 45 | Dual Threat | 26 | 17 | 1.50 | 1.70 | 0.60-0.60 | 1.40 | 1.40 | 1 | 3.08 | 3.00 | 4 |  | 10 | mastery | 0.34 |  |
| 46 | Collapse Flow | 26 | 17 | 1.50 | 1.70 | 0.60-0.60 | 1.40 | 1.40 | 1 | 3.10 | 3.00 | 4 |  | 10 | mastery | 0.34 |  |
| 47 | No Escape | 26 | 17 | 1.50 | 1.70 | 0.60-0.60 | 1.40 | 1.40 | 1 | 3.12 | 3.00 | 4 |  | 10 | mastery | 0.34 |  |
| 48 | Final Chaos | 26 | 17 | 1.50 | 1.70 | 0.60-0.60 | 1.40 | 1.40 | 1 | 3.14 | 3.00 | 4 | Y | 10 | mastery | 0.34 |  |
| 49 | Last Attempt | 26 | 17 | 1.50 | 1.70 | 0.60-0.60 | 1.40 | 1.40 | 1 | 3.16 | 3.00 | 4 |  | 10 | mastery | 0.34 |  |
| 50 | Checkpoint Break | 24 | 17 | 1.45 | 2.50 | 0.50-0.50 | 2.60 | 2.60 | 4 | 2.40 | 2.38 | 4 |  | 10 | mastery | 0.34 |  |
| 51 | False Calm | 24 | 17 | 1.45 | 1.95 | 0.60-0.60 | 1.60 | 1.60 | 3 | 2.70 | 2.68 | 3 |  | 10 | mastery | 0.16 |  |
| 52 | Rebuild Threat | 25 | 17 | 1.46 | 1.85 | 0.62-0.62 | 1.50 | 1.50 | 2 | 2.76 | 2.74 | 3 |  | 10 | mastery | 0.16 |  |
| 53 | Route Control | 25 | 17 | 1.47 | 1.85 | 0.65-0.65 | 1.50 | 1.50 | 2 | 2.82 | 2.80 | 3 |  | 10 | mastery | 0.16 |  |
| 54 | Perception Break | 25 | 17 | 1.48 | 1.75 | 0.67-0.67 | 1.40 | 1.40 | 2 | 2.88 | 2.86 | 3 | Y | 10 | mastery | 0.16 |  |
| 55 | Master Entry | 25 | 17 | 1.48 | 1.75 | 0.68-0.68 | 1.40 | 1.40 | 2 | 2.94 | 2.92 | 3 |  | 10 | mastery | 0.16 |  |
| 56 | Controlled Chaos | 25 | 17 | 1.49 | 1.75 | 0.68-0.68 | 1.40 | 1.40 | 2 | 2.98 | 2.96 | 3 |  | 10 | mastery | 0.16 |  |
| 57 | Trap Routes | 25 | 17 | 1.49 | 1.75 | 0.70-0.70 | 1.35 | 1.35 | 2 | 3.02 | 3.00 | 3 |  | 10 | mastery | 0.16 |  |
| 58 | Mind Loop | 26 | 17 | 1.50 | 1.75 | 0.70-0.70 | 1.35 | 1.35 | 2 | 3.06 | 3.00 | 3 |  | 10 | mastery | 0.16 |  |
| 59 | Precision Lock | 26 | 17 | 1.50 | 1.65 | 0.72-0.72 | 1.30 | 1.30 | 1 | 3.10 | 3.00 | 3 |  | 10 | mastery | 0.16 | Y |
| 60 | Master Pressure | 26 | 17 | 1.50 | 1.65 | 0.72-0.72 | 1.30 | 1.30 | 1 | 3.14 | 3.00 | 3 | Y | 10 | mastery | 0.16 | Y |
| 61 | Endurance Start | 26 | 17 | 1.50 | 1.65 | 0.72-0.72 | 1.30 | 1.30 | 1 | 3.16 | 3.00 | 3 |  | 10 | mastery | 0.16 | Y |
| 62 | Pattern Break | 26 | 17 | 1.51 | 1.65 | 0.73-0.73 | 1.30 | 1.30 | 1 | 3.20 | 3.00 | 3 |  | 10 | mastery | 0.16 | Y |
| 63 | Mental Load | 26 | 17 | 1.51 | 1.65 | 0.74-0.74 | 1.30 | 1.30 | 1 | 3.24 | 3.00 | 3 |  | 10 | mastery | 0.16 | Y |
| 64 | Fatigue Zone | 27 | 17 | 1.52 | 1.60 | 0.74-0.74 | 1.25 | 1.25 | 1 | 3.28 | 3.00 | 3 |  | 10 | mastery | 0.16 | Y |
| 65 | Consistency Test | 27 | 17 | 1.52 | 1.60 | 0.75-0.75 | 1.25 | 1.25 | 1 | 3.32 | 3.00 | 3 |  | 10 | mastery | 0.16 | Y |
| 66 | Pressure Sustain | 27 | 17 | 1.52 | 1.60 | 0.75-0.75 | 1.20 | 1.20 | 1 | 3.34 | 3.00 | 3 | Y | 10 | mastery | 0.16 | Y |
| 67 | Trap Memory | 27 | 17 | 1.52 | 1.60 | 0.75-0.75 | 1.20 | 1.20 | 1 | 3.36 | 3.00 | 3 |  | 10 | mastery | 0.16 | Y |
| 68 | Dual Panic | 27 | 17 | 1.52 | 1.60 | 0.75-0.75 | 1.20 | 1.20 | 1 | 3.38 | 3.00 | 3 |  | 10 | mastery | 0.16 | Y |
| 69 | Near Collapse | 27 | 17 | 1.52 | 1.60 | 0.75-0.75 | 1.20 | 1.20 | 1 | 3.40 | 3.00 | 3 |  | 10 | mastery | 0.16 | Y |
| 70 | Pre-Breakpoint | 27 | 17 | 1.52 | 1.60 | 0.75-0.75 | 1.20 | 1.20 | 1 | 3.42 | 3.00 | 3 |  | 10 | mastery | 0.16 | Y |
| 71 | Checkpoint Grind I | 27 | 17 | 1.52 | 1.70 | 0.72-0.72 | 1.30 | 1.30 | 1 | 3.30 | 3.00 | 3 |  | 10 | nightmare | 0.06 | Y |
| 72 | Checkpoint Grind II | 27 | 17 | 1.52 | 1.70 | 0.72-0.72 | 1.30 | 1.30 | 1 | 3.32 | 3.00 | 3 | Y | 10 | nightmare | 0.06 | Y |
| 73 | Checkpoint Grind III | 27 | 17 | 1.52 | 1.70 | 0.73-0.73 | 1.30 | 1.30 | 1 | 3.34 | 3.00 | 3 |  | 10 | nightmare | 0.06 | Y |
| 74 | Checkpoint Grind IV | 27 | 17 | 1.52 | 1.70 | 0.74-0.74 | 1.30 | 1.30 | 1 | 3.36 | 3.00 | 3 |  | 10 | nightmare | 0.06 | Y |
| 75 | Checkpoint Break | 25 | 17 | 1.50 | 2.35 | 0.55-0.55 | 2.40 | 2.40 | 4 | 2.55 | 2.53 | 3 |  | 10 | nightmare | 0.06 | Y |
| 76 | Extreme Skill I | 27 | 17 | 1.50 | 1.75 | 0.70-0.70 | 1.30 | 1.30 | 1 | 3.20 | 3.00 | 3 |  | 10 | nightmare | 0.06 | Y |
| 77 | Extreme Skill II | 27 | 17 | 1.50 | 1.75 | 0.72-0.72 | 1.30 | 1.30 | 1 | 3.24 | 3.00 | 3 |  | 10 | nightmare | 0.06 | Y |
| 78 | Pattern Hunt | 27 | 17 | 1.50 | 1.65 | 0.74-0.74 | 1.25 | 1.25 | 1 | 3.28 | 3.00 | 3 | Y | 10 | nightmare | 0.06 | Y |
| 79 | Route Pressure | 28 | 17 | 1.50 | 1.65 | 0.75-0.75 | 1.25 | 1.25 | 1 | 3.32 | 3.00 | 3 |  | 10 | nightmare | 0.06 | Y |
| 80 | End Of Certainty | 28 | 17 | 1.50 | 1.65 | 0.76-0.76 | 1.25 | 1.25 | 1 | 3.36 | 3.00 | 3 |  | 10 | nightmare | 0.06 | Y |
| 81 | Mental Pressure I | 28 | 17 | 1.50 | 1.65 | 0.76-0.76 | 1.25 | 1.25 | 1 | 3.38 | 3.00 | 3 |  | 10 | nightmare | 0.06 | Y |
| 82 | Mental Pressure II | 28 | 17 | 1.50 | 1.65 | 0.77-0.77 | 1.25 | 1.25 | 1 | 3.40 | 3.00 | 3 |  | 10 | nightmare | 0.06 | Y |
| 83 | Loop Trap | 28 | 17 | 1.50 | 1.55 | 0.78-0.78 | 1.20 | 1.20 | 1 | 3.42 | 3.00 | 3 |  | 10 | nightmare | 0.06 | Y |
| 84 | Do Not Panic | 28 | 17 | 1.50 | 1.55 | 0.78-0.78 | 1.20 | 1.20 | 1 | 3.44 | 3.00 | 2 | Y | 10 | nightmare | 0.06 | Y |
| 85 | Mental Wall | 28 | 17 | 1.50 | 1.55 | 0.79-0.79 | 1.20 | 1.20 | 1 | 3.46 | 3.00 | 2 |  | 10 | nightmare | 0.06 | Y |
| 86 | Precision Hell I | 28 | 17 | 1.50 | 1.55 | 0.79-0.79 | 1.20 | 1.20 | 1 | 3.48 | 3.00 | 2 |  | 10 | nightmare | 0.06 | Y |
| 87 | Precision Hell II | 28 | 17 | 1.50 | 1.55 | 0.79-0.79 | 1.20 | 1.20 | 1 | 3.49 | 3.00 | 2 |  | 10 | nightmare | 0.06 | Y |
| 88 | Accuracy Tax | 28 | 17 | 1.50 | 1.50 | 0.80-0.80 | 1.15 | 1.15 | 1 | 3.50 | 3.00 | 2 |  | 10 | nightmare | 0.06 | Y |
| 89 | Needle Run | 28 | 17 | 1.50 | 1.45 | 0.80-0.80 | 1.10 | 1.10 | 1 | 3.51 | 3.00 | 2 |  | 10 | nightmare | 0.06 | Y |
| 90 | Precision Crown | 28 | 17 | 1.50 | 1.45 | 0.80-0.80 | 1.10 | 1.10 | 1 | 3.52 | 3.00 | 2 | Y | 10 | nightmare | 0.06 | Y |
| 91 | Mind Break I | 28 | 17 | 1.50 | 1.45 | 0.80-0.80 | 1.10 | 1.10 | 1 | 3.53 | 3.00 | 2 |  | 10 | nightmare | 0.06 | Y |
| 92 | Mind Break II | 28 | 17 | 1.50 | 1.45 | 0.80-0.80 | 1.10 | 1.10 | 1 | 3.54 | 3.00 | 2 |  | 10 | nightmare | 0.06 | Y |
| 93 | Instinct Route | 28 | 17 | 1.50 | 1.45 | 0.80-0.80 | 1.10 | 1.10 | 1 | 3.55 | 3.00 | 2 |  | 10 | nightmare | 0.06 | Y |
| 94 | Blind Discipline | 28 | 17 | 1.50 | 1.45 | 0.80-0.80 | 1.10 | 1.10 | 1 | 3.56 | 3.00 | 2 |  | 10 | nightmare | 0.06 | Y |
| 95 | Nerve Lock | 28 | 17 | 1.50 | 1.45 | 0.80-0.80 | 1.10 | 1.10 | 1 | 3.57 | 3.00 | 2 |  | 10 | nightmare | 0.06 | Y |
| 96 | Final Trial I | 28 | 17 | 1.50 | 1.45 | 0.80-0.80 | 1.10 | 1.10 | 1 | 3.58 | 3.00 | 2 | Y | 10 | nightmare | 0.06 | Y |
| 97 | Final Trial II | 28 | 17 | 1.50 | 1.45 | 0.80-0.80 | 1.10 | 1.10 | 1 | 3.59 | 3.00 | 2 |  | 10 | nightmare | 0.06 | Y |
| 98 | Final Trial III | 28 | 17 | 1.50 | 1.45 | 0.80-0.80 | 1.10 | 1.10 | 1 | 3.60 | 3.00 | 2 |  | 10 | nightmare | 0.06 | Y |
| 99 | Final Trial IV | 28 | 17 | 1.50 | 1.45 | 0.80-0.80 | 1.10 | 1.10 | 1 | 3.61 | 3.00 | 2 |  | 10 | nightmare | 0.06 | Y |
| 100 | THE BREAKER | 29 | 17 | 1.50 | 1.60 | 0.70-0.80 | 1.80 | 1.00 | 1 | 3.62 | 3.00 | 2 |  | 10 | nightmare | 0.06 | Y |
