extends McpTestSuite
## plans/05 + plans/06 invariants: the floor curve (StageRule: 5 acts of 10, a sawtooth) and the
## Devil's speed caps and senses (DevilBrain). The run itself (RunState) is in test_run_state.gd.

const WALK := 3.0
const SPRINT := 4.5


func suite_name() -> String:
	return "descent_rules"


func test_floor_curve_invariants() -> void:
	for f in range(1, StageRule.LAST_FLOOR + 1):
		var rule := StageRule.for_floor(f)
		assert_true(rule.flip_warning >= 0.8, "F%d warning %.2f" % [f, rule.flip_warning])
		assert_true(rule.devil_spawn_distance >= 8, "F%d spawn distance" % f)
		assert_true(rule.safe_circle_count >= 1, "F%d circles" % f)
		assert_true(rule.trap_cue_strength >= StageRule.MIN_TRAP_CUE, "F%d cue" % f)
		assert_true(rule.forced_interval_min <= rule.forced_interval_max, "F%d flip interval" % f)
		var route_m := 100.0
		assert_true(rule.time_budget(route_m, WALK) >= 1.5 * route_m / WALK, "F%d budget" % f)
		assert_true(rule.rooms >= StageRule.ROOMS_3D.x and rule.rooms <= StageRule.ROOMS_3D.y, "F%d rooms %d" % [f, rule.rooms])
		var enraged: float = rule.devil_base_ratio * 1.2 * DevilBrain.WORLD_SPEED.max()
		for d in 40:
			var speed := DevilBrain.speed(d, WALK, SPRINT, enraged, true)
			assert_true(speed < SPRINT, "F%d d=%d outruns a sprint" % [f, d])
			if d <= DevilBrain.RAGE_CAP_TILES:
				assert_true(speed < WALK, "F%d d=%d enraged Devil faster than a walk" % [f, d])
	assert_eq(StageRule.LAST_FLOOR, 50)
	assert_eq(StageRule.for_floor(10).act, 1)
	assert_eq(StageRule.for_floor(11).act, 2)
	assert_eq(StageRule.for_floor(11).floor_in_act, 1)
	assert_eq(StageRule.act_start(5), 41)
	for f in [5, 15, 45]:
		assert_true(StageRule.for_floor(f).is_sanctuary, "F%d is a Sanctuary" % f)
	for f in [10, 20, 50]:
		assert_true(StageRule.for_floor(f).is_gate, "F%d is a Gate" % f)
	assert_false(StageRule.for_floor(9).is_gate or StageRule.for_floor(9).is_sanctuary)
	assert_eq(StageRule.for_floor(1).rooms, StageRule.ROOMS_3D.x, "Act 1 F1 = smallest maze")
	assert_eq(StageRule.for_floor(49).rooms, StageRule.ROOMS_3D.y, "Act 5 F9 = largest maze")
	assert_false(StageRule.for_floor(1).dead_end_traps, "no doom traps in Act 1")


func test_devil_is_slower_in_wake() -> void:
	assert_true(DevilBrain.WORLD_SPEED[FloorLayout.World.WAKE] < DevilBrain.WORLD_SPEED[FloorLayout.World.NIGHTMARE])
	assert_true(DevilBrain.speed(10, WALK, SPRINT, 0.85 * DevilBrain.WORLD_SPEED[FloorLayout.World.WAKE]) < WALK, "WAKE Devil outpaces a walk")


## Clearing a floor gives a different maze; inside an act every regular floor is harder than the last.
func test_next_floor_is_new_and_harder() -> void:
	RunState.run_seed = 12345
	for f in range(2, StageRule.LAST_FLOOR + 1):
		var prev := StageRule.for_floor(f - 1)
		var rule := StageRule.for_floor(f)
		RunState.current_floor = f - 1
		var prev_seed := RunState.floor_seed()
		RunState.current_floor = f
		assert_true(RunState.floor_seed() != prev_seed, "F%d same seed as F%d" % [f, f - 1])
		# The sawtooth's planned dips (a new act, the Sanctuary, the Gate) have their own test below.
		if rule.floor_in_act == 1 or rule.is_sanctuary or prev.is_sanctuary or rule.is_gate:
			continue
		assert_true(rule.devil_base_ratio > prev.devil_base_ratio, "F%d Devil not faster" % f)
		assert_true(rule.time_slack < prev.time_slack, "F%d clock not tighter" % f)
		assert_true(rule.trap_count >= prev.trap_count, "F%d fewer traps" % f)
	assert_true(StageRule.for_floor(10).rooms > StageRule.for_floor(1).rooms, "maze grows over Act 1")
	RunState.current_floor = 1


## plans/06 §2: each act climbs, the Sanctuary eases off, the Gate plays like F8, and the next act starts
## above this act's start but below its F9. No floor ever gets harder than the old floor 100.
func test_difficulty_is_a_sawtooth() -> void:
	for act in range(1, StageRule.ACT_COUNT + 1):
		var start := StageRule.act_start(act)
		var d := func(k: int) -> float: return StageRule.for_floor(start + k - 1).difficulty
		assert_true(d.call(5) < d.call(4), "Act %d: the Sanctuary eases off" % act)
		assert_true(d.call(10) > d.call(7) and d.call(10) < d.call(9), "Act %d: the Gate plays like F8" % act)
		if act < StageRule.ACT_COUNT:
			var next_start := StageRule.for_floor(StageRule.act_start(act + 1)).difficulty
			assert_true(next_start < d.call(9), "Act %d F1 is easier than Act %d F9" % [act + 1, act])
			assert_true(next_start > d.call(1), "Act %d starts harder than Act %d" % [act + 1, act])
	for f in range(1, StageRule.LAST_FLOOR + 1):
		var t := StageRule.for_floor(f).difficulty
		assert_true(t >= 0.0 and t <= 1.0 + 1e-6, "F%d difficulty %.3f" % [f, t])
	assert_eq(StageRule.for_floor(1).difficulty, 0.0)
	assert_true(is_equal_approx(StageRule.for_floor(49).difficulty, 1.0), "Act 5 F9 is the hardest floor")


func test_far_devil_is_faster_than_close() -> void:
	assert_gt(DevilBrain.speed(20, WALK, SPRINT, 1.0), DevilBrain.speed(2, WALK, SPRINT, 1.0))


func test_spawn_is_far_behind_and_unseen() -> void:
	var layout := FloorLayout.generate(42, 7)
	var brain := DevilBrain.new()
	var path := layout.route(layout.spawn, layout.exit)
	for cell in path:
		brain.record(cell)
	var player: Vector2i = path[path.size() - 1]
	var dist := layout.distances(FloorLayout.World.NIGHTMARE, player)
	var seen := func(cell: Vector2i) -> bool: return DevilBrain.line_of_sight(layout, FloorLayout.World.NIGHTMARE, player, cell)
	var spawn := brain.pick_spawn(dist, layout.size, 8, seen)
	if spawn.x >= 0:
		assert_true(dist[spawn.y * layout.size + spawn.x] >= 8)
		assert_false(seen.call(spawn))
	assert_false(DevilBrain.can_spawn(5.0, 10.0, 0.9, false), "too early")
	assert_false(DevilBrain.can_spawn(20.0, 10.0, 0.1, false), "not far enough in")
	assert_false(DevilBrain.can_spawn(20.0, 10.0, 0.9, true), "you're in a circle")
	assert_true(DevilBrain.can_spawn(20.0, 10.0, 0.9, false))


func test_grade_boundaries() -> void:
	# A key tour walked in 100 s: pace = seconds used / 100.
	var route := 100.0 * WALK
	assert_eq(StageRule.grade(135.0, route, WALK, 0, 0.0), "S", "pace 1.35 is still S")
	assert_eq(StageRule.grade(136.0, route, WALK, 0, 0.0), "A")
	assert_eq(StageRule.grade(180.0, route, WALK, 0, 0.0), "A")
	assert_eq(StageRule.grade(181.0, route, WALK, 0, 0.0), "B")
	assert_eq(StageRule.grade(240.0, route, WALK, 0, 0.0), "B")
	assert_eq(StageRule.grade(241.0, route, WALK, 0, 0.0), "C")
	assert_eq(StageRule.grade(100.0, route, WALK, 1, 0.0), "A", "a revive drops one grade")
	assert_eq(StageRule.grade(100.0, route, WALK, 0, 41.0), "A", "chased for over 40% of the floor drops one")
	assert_eq(StageRule.grade(100.0, route, WALK, 0, 40.0), "S", "40% exactly is fine")
	assert_eq(StageRule.grade(241.0, route, WALK, 3, 241.0), "C", "never below C")


func test_floors_to_gate_counts_down_to_the_shortcut() -> void:
	assert_eq(StageRule.floors_to_gate(1), 10)
	assert_eq(StageRule.floors_to_gate(8), 3)
	assert_eq(StageRule.floors_to_gate(StageRule.GATE_FLOOR), 1, "standing on the Gate")
	assert_eq(StageRule.floors_to_gate(11), 10, "each act counts on its own")
	assert_eq(StageRule.floors_to_gate(StageRule.LAST_FLOOR), 1)


# --- plans/06 P8: the Abyss -------------------------------------------------------------------------

func test_the_abyss_lies_below_floor_50() -> void:
	var first := StageRule.for_floor(StageRule.LAST_FLOOR + 1)
	assert_eq(first.act, StageRule.ABYSS_ACT)
	assert_eq(first.act_name, StageRule.ABYSS_NAME)
	assert_eq(first.floor_in_act, 1, "depth 1")
	assert_false(first.is_sanctuary or first.is_gate, "no Sanctuary and no Gate: it never ends")
	assert_eq(first.difficulty, 1.0, "the hardest endpoints and never past them")
	assert_eq(StageRule.act_of(StageRule.LAST_FLOOR + 37), StageRule.ABYSS_ACT)
	assert_eq(StageRule.act_start(StageRule.ABYSS_ACT), StageRule.LAST_FLOOR + 1)
	var deep := StageRule.for_floor(StageRule.LAST_FLOOR + 50)
	assert_eq(deep.floor_number, 100, "floor 100 is a real floor: the bragging goal")
	assert_eq(deep.floor_in_act, 50)
	assert_eq(deep.devil_base_ratio, first.devil_base_ratio, "deeper adds rules, not speed (GEMINI: complexity, not unfair speed)")
	assert_eq(deep.time_slack, first.time_slack)
	assert_eq(StageRule.for_floor(StageRule.LAST_FLOOR).act, StageRule.ACT_COUNT, "floor 50 is still the last Gate")


func test_an_extra_rule_card_every_five_floors_down() -> void:
	var counts: Array[int] = []
	for depth: int in [1, 5, 6, 10, 11, 16, 40]:
		counts.append(StageRule.for_floor(StageRule.LAST_FLOOR + depth).rule_cards)
	assert_eq(counts, [1, 1, 2, 2, 3, 4, StageRule.ABYSS_MAX_RULES], "one more every %d floors, up to %d" % [
			StageRule.ABYSS_CARD_EVERY, StageRule.ABYSS_MAX_RULES])
	for f in range(1, StageRule.LAST_FLOOR + 1):
		if StageRule.for_floor(f).rule_cards != 1:
			assert_true(false, "campaign floor %d deals one rule card" % f)
			return
