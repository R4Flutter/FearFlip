class_name StageRule
extends Resource
## Per-floor balance for the Descent (plans/05 §3.1): 100 floors in 5 acts of 20.
## Maze size is the 2D game's per-stage table; every other knob lerps from floor 1 to floor 100.
## F21/41/61/81 are breathers + checkpoints.

const LAST_FLOOR := 100
const FLOORS_PER_ACT := 20
const ACT_NAMES: Array[String] = ["Awakening", "Hunted", "Mind Break", "Precision Hell", "THE BREAKER"]
## A breather plays like the floor this many floors earlier.
const BREATHER_EASE := 6

## 2D `mazeSize` per stage (lib/presentation/gameplay/stage_rules.dart), floors 1..100. Only its shape
## is used: first person walks every corridor, so it is squeezed into ROOMS_3D (29 rooms = ~1.4 km).
const MAZE_SIZES: Array[int] = [
	10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 19, 20, 20, 21, 21, 20, 21, 21, 22, 22,
	22, 22, 22, 22, 20, 22, 22, 23, 23, 23, 23, 24, 24, 24, 24, 24, 24, 25, 25, 25,
	25, 25, 26, 26, 26, 26, 26, 26, 26, 24, 24, 25, 25, 25, 25, 25, 25, 26, 26, 26,
	26, 26, 26, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 25, 27, 27, 27, 28, 28,
	28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 29,
]

const MAZE_SIZE_RANGE := Vector2i(10, 29)
## Rooms per side for the smallest / largest 2D maze. Tune here if floors feel too short or long.
const ROOMS_3D := Vector2i(8, 14)

# Curve endpoints: [floor 1, floor 100].
const TIME_SLACK := Vector2(2.6, 1.7)
const FIRST_FORCED_AT := Vector2(45.0, 22.0)
const FORCED_INTERVAL_MIN := Vector2(40.0, 20.0)
const FORCED_INTERVAL_MAX := Vector2(60.0, 30.0)
const MIN_FORCED_INTERVAL := Vector2(25.0, 14.0)
const FLIP_WARNING := Vector2(3.0, 1.5)
const MIN_FLIP_WARNING := 0.8
## Devil base speed as a fraction of walk speed (the rubber band in DevilBrain scales it).
const DEVIL_BASE_RATIO := Vector2(0.85, 1.05)
const DEVIL_SPAWN_DELAY := Vector2(20.0, 6.0)
## Path tiles behind you on your own trail. Never under MIN_DEVIL_SPAWN_DISTANCE.
const DEVIL_SPAWN_DISTANCE := Vector2(12.0, 8.0)
const MIN_DEVIL_SPAWN_DISTANCE := 8
const DEVIL_RESPAWN_STEPS := Vector2(5.0, 2.0)
const SAFE_CIRCLE_PROTECT := Vector2(8.0, 3.0)
const SAFE_CIRCLE_SINGLE_USE_FROM := 75
const TRAPS := Vector2(2.0, 10.0)
const TRAP_CUE := Vector2(1.0, 0.06)
## Cracks must stay readable: a doom trap is only fair if you can see it coming (§2.5).
const MIN_TRAP_CUE := 0.35

@export var floor_number := 1
@export var act := 1
@export var act_name := ""
@export var is_breather := false
@export var rooms := 8
@export var time_slack := 2.6
@export var first_forced_at := 45.0
@export var forced_interval_min := 40.0
@export var forced_interval_max := 60.0
@export var min_forced_interval := 25.0
@export var flip_warning := 3.0
@export var devil_base_ratio := 0.85
@export var devil_spawn_delay := 20.0
@export var devil_spawn_distance := 12
@export var devil_respawn_steps := 5
@export var safe_circle_count := 2
@export var safe_circle_protect_s := 8.0
@export var safe_circle_single_use := false
@export var trap_count := 1
@export var trap_cue_strength := 1.0
## Traps on dead-end entrances (crack going in, die coming out). Act 2+ only.
@export var dead_end_traps := false


static func for_floor(number: int) -> StageRule:
	var f := clampi(number, 1, LAST_FLOOR)
	var rule := StageRule.new()
	rule.floor_number = f
	@warning_ignore("integer_division")
	rule.act = (f - 1) / FLOORS_PER_ACT + 1
	rule.act_name = ACT_NAMES[rule.act - 1]
	rule.is_breather = is_checkpoint(f) and f > 1
	var t := float((f - BREATHER_EASE if rule.is_breather else f) - 1) / float(LAST_FLOOR - 1)
	rule.rooms = roundi(lerpf(ROOMS_3D.x, ROOMS_3D.y, inverse_lerp(MAZE_SIZE_RANGE.x, MAZE_SIZE_RANGE.y, MAZE_SIZES[f - 1])))
	rule.time_slack = _curve(TIME_SLACK, t)
	rule.first_forced_at = _curve(FIRST_FORCED_AT, t)
	rule.forced_interval_min = _curve(FORCED_INTERVAL_MIN, t)
	rule.forced_interval_max = _curve(FORCED_INTERVAL_MAX, t)
	rule.min_forced_interval = _curve(MIN_FORCED_INTERVAL, t)
	rule.flip_warning = maxf(_curve(FLIP_WARNING, t), MIN_FLIP_WARNING)
	rule.devil_base_ratio = _curve(DEVIL_BASE_RATIO, t)
	rule.devil_spawn_delay = _curve(DEVIL_SPAWN_DELAY, t)
	rule.devil_spawn_distance = maxi(roundi(_curve(DEVIL_SPAWN_DISTANCE, t)), MIN_DEVIL_SPAWN_DISTANCE)
	rule.devil_respawn_steps = roundi(_curve(DEVIL_RESPAWN_STEPS, t))
	rule.safe_circle_protect_s = _curve(SAFE_CIRCLE_PROTECT, t)
	rule.safe_circle_single_use = f >= SAFE_CIRCLE_SINGLE_USE_FROM
	rule.trap_count = 1 if f == 1 else roundi(_curve(TRAPS, t))
	rule.trap_cue_strength = maxf(_curve(TRAP_CUE, t), MIN_TRAP_CUE)
	rule.dead_end_traps = rule.act >= 2
	return rule


## Act starts (1, 21, 41, 61, 81): where a run resumes and where revives reset.
static func is_checkpoint(number: int) -> bool:
	return (number - 1) % FLOORS_PER_ACT == 0


## Seconds for a floor: walking the route at `walk` m/s, times the slack, plus 15 s, rounded up to 5 s.
func time_budget(route_m: float, walk: float) -> float:
	return ceilf((route_m / walk * time_slack + 15.0) / 5.0) * 5.0


static func _curve(ends: Vector2, t: float) -> float:
	return lerpf(ends.x, ends.y, t)
