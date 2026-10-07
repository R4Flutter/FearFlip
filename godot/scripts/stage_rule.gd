class_name StageRule
extends Resource
## Per-floor balance for the Descent (plans/06 §2): 50 floors in 5 acts of 10, and each act is one run.
## Difficulty is a sawtooth, not a ramp: it climbs through an act, eases at the Sanctuary (F5), and the
## Gate (F10) plays like F8 (its twist arrives with plans/06 P3). The next act starts above this act's
## first floor but below its F9. Every knob lerps from its [easiest, hardest] pair by `difficulty`.

const ACT_COUNT := 5
const FLOORS_PER_ACT := 10
const LAST_FLOOR := ACT_COUNT * FLOORS_PER_ACT
const ACT_NAMES: Array[String] = ["Awakening", "Hunted", "Mind Break", "Precision Hell", "THE BREAKER"]
const SANCTUARY_FLOOR := 5
const GATE_FLOOR := 10
## The Sanctuary plays like its act's F2, the Gate like its F8.
const SANCTUARY_PLAYS_AS := 2
const GATE_PLAYS_AS := 8
## Difficulty climbs IN_ACT_RAMP from an act's F1 to its F9, and each act starts ACT_STEP above the last.
## IN_ACT_RAMP > ACT_STEP is what makes a new act's F1 easier than the last act's F9.
## Act 5's F9 lands on exactly 1.0 (the old floor-100 endpoints).
const IN_ACT_RAMP := 0.3
const ACT_STEP := (1.0 - IN_ACT_RAMP) / (ACT_COUNT - 1)

## 2D `mazeSize` per stage (lib/presentation/gameplay/stage_rules.dart), easiest to hardest. Only its shape
## is used: it is sampled by difficulty, then squeezed into ROOMS_3D (first person walks every corridor;
## 29 rooms = ~1.4 km).
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

# Curve endpoints: [difficulty 0 (Act 1 F1), difficulty 1 (Act 5 F9)].
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
## Safe circles go single-use from this difficulty on (late Act 4, most of Act 5).
const SAFE_CIRCLE_SINGLE_USE_FROM := 0.75
const TRAPS := Vector2(2.0, 10.0)
const TRAP_CUE := Vector2(1.0, 0.06)
## Cracks must stay readable: a doom trap is only fair if you can see it coming (§2.5).
const MIN_TRAP_CUE := 0.35

@export var floor_number := 1
@export var act := 1
@export var act_name := ""
## 1..FLOORS_PER_ACT: which floor of its act this is.
@export var floor_in_act := 1
@export var is_sanctuary := false
@export var is_gate := false
## 0 (Act 1 F1) .. 1 (Act 5 F9): where this floor sits on the sawtooth.
@export var difficulty := 0.0
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
	rule.act = act_of(f)
	rule.act_name = ACT_NAMES[rule.act - 1]
	rule.floor_in_act = f - act_start(rule.act) + 1
	rule.is_sanctuary = rule.floor_in_act == SANCTUARY_FLOOR
	rule.is_gate = rule.floor_in_act == GATE_FLOOR
	var plays_as := rule.floor_in_act
	if rule.is_sanctuary:
		plays_as = SANCTUARY_PLAYS_AS
	elif rule.is_gate:
		plays_as = GATE_PLAYS_AS
	# F1 = the act's base, F9 = base + IN_ACT_RAMP.
	var t := (rule.act - 1) * ACT_STEP + IN_ACT_RAMP * float(plays_as - 1) / (GATE_FLOOR - 2)
	rule.difficulty = t
	var maze_size := MAZE_SIZES[roundi(t * (MAZE_SIZES.size() - 1))]
	rule.rooms = roundi(lerpf(ROOMS_3D.x, ROOMS_3D.y, inverse_lerp(MAZE_SIZE_RANGE.x, MAZE_SIZE_RANGE.y, maze_size)))
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
	rule.safe_circle_single_use = t >= SAFE_CIRCLE_SINGLE_USE_FROM
	rule.trap_count = 1 if f == 1 else roundi(_curve(TRAPS, t))
	rule.trap_cue_strength = maxf(_curve(TRAP_CUE, t), MIN_TRAP_CUE)
	rule.dead_end_traps = rule.act >= 2
	return rule


static func act_of(number: int) -> int:
	@warning_ignore("integer_division")
	return (clampi(number, 1, LAST_FLOOR) - 1) / FLOORS_PER_ACT + 1


## An act's first floor (1, 11, 21, 31, 41): every run of that act starts here.
static func act_start(act_number: int) -> int:
	return (clampi(act_number, 1, ACT_COUNT) - 1) * FLOORS_PER_ACT + 1


## Seconds for a floor: walking the route at `walk` m/s, times the slack, plus 15 s, rounded up to 5 s.
func time_budget(route_m: float, walk: float) -> float:
	return ceilf((route_m / walk * time_slack + 15.0) / 5.0) * 5.0


static func _curve(ends: Vector2, t: float) -> float:
	return lerpf(ends.x, ends.y, t)
