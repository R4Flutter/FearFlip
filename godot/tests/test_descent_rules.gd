extends McpTestSuite
## plans/05 invariants: the floor curve (StageRule), the Devil's speed caps and senses (DevilBrain),
## the run's revives (RunState).

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
	assert_eq(StageRule.for_floor(21).act, 2)
	assert_true(StageRule.for_floor(21).is_breather)
	assert_eq(StageRule.for_floor(1).rooms, StageRule.ROOMS_3D.x, "floor 1 = smallest maze")
	assert_eq(StageRule.for_floor(100).rooms, StageRule.ROOMS_3D.y, "floor 100 = largest maze")
	assert_false(StageRule.for_floor(1).dead_end_traps, "no doom traps in Act 1")


func test_devil_is_slower_in_wake() -> void:
	assert_true(DevilBrain.WORLD_SPEED[FloorLayout.World.WAKE] < DevilBrain.WORLD_SPEED[FloorLayout.World.NIGHTMARE])
	assert_true(DevilBrain.speed(10, WALK, SPRINT, 0.85 * DevilBrain.WORLD_SPEED[FloorLayout.World.WAKE]) < WALK, "WAKE Devil outpaces a walk")


## Clearing a floor gives a different maze that is harder than the last (breathers excepted).
func test_next_floor_is_new_and_harder() -> void:
	RunState.run_seed = 12345
	for f in range(2, StageRule.LAST_FLOOR + 1):
		var prev := StageRule.for_floor(f - 1)
		var rule := StageRule.for_floor(f)
		RunState.current_floor = f - 1
		var prev_seed := RunState.floor_seed()
		RunState.current_floor = f
		assert_true(RunState.floor_seed() != prev_seed, "F%d same seed as F%d" % [f, f - 1])
		if rule.is_breather or prev.is_breather:
			continue
		assert_true(rule.devil_base_ratio > prev.devil_base_ratio, "F%d Devil not faster" % f)
		assert_true(rule.time_slack < prev.time_slack, "F%d clock not tighter" % f)
		assert_true(rule.trap_count >= prev.trap_count, "F%d fewer traps" % f)
	assert_true(StageRule.for_floor(10).rooms > StageRule.for_floor(1).rooms, "maze grows over Act 1")


func test_far_devil_is_faster_than_close() -> void:
	assert_gt(DevilBrain.speed(20, WALK, SPRINT, 1.0), DevilBrain.speed(2, WALK, SPRINT, 1.0))


func test_devil_follows_newest_scent_and_waits_at_its_end() -> void:
	var brain := DevilBrain.new()
	for cell in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(2, 1), Vector2i(2, 2)]:
		brain.record(cell, true)
	# At (2,1): its newest visit is index 3, so it skips the (3,1) detour and heads for (2,2).
	assert_eq(brain.target(Vector2i(2, 1), Vector2i(9, 9)), Vector2i(2, 2))
	assert_eq(brain.target(Vector2i(2, 2), Vector2i(9, 9)), Vector2i(2, 2), "end of the scent: wait")
	brain.record(Vector2i(2, 3), false)
	assert_eq(brain.target(Vector2i(2, 2), Vector2i(9, 9)), Vector2i(2, 2), "frozen while you're in WAKE")
	brain.sense(true, false, 0.1)
	assert_eq(brain.target(Vector2i(2, 2), Vector2i(9, 9)), Vector2i(9, 9), "sees you: straight at you")
	brain.sense(false, false, DevilBrain.SENSE_MEMORY + 0.1)
	assert_eq(brain.sense_left, 0.0)


func test_spawn_is_far_behind_and_unseen() -> void:
	var layout := FloorLayout.generate(42, 7)
	var brain := DevilBrain.new()
	var path := layout.route(layout.spawn, layout.exit)
	for cell in path:
		brain.record(cell, true)
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


func test_revives_cap_per_act_and_reset_at_checkpoint() -> void:
	RunState.save_path = "user://test_run_state.cfg"
	RunState.current_floor = StageRule.FLOORS_PER_ACT - 1
	RunState.revives_used = 0
	for _i in RunState.REVIVES_PER_ACT:
		assert_true(RunState.use_revive())
	assert_false(RunState.use_revive(), "max 3 per act")
	RunState.advance_floor()
	assert_eq(RunState.revives_left(), RunState.REVIVES_PER_ACT - RunState.REVIVES_PER_ACT, "last floor of Act 1")
	RunState.advance_floor()
	assert_eq(RunState.current_floor, StageRule.FLOORS_PER_ACT + 1)
	assert_eq(RunState.revives_left(), RunState.REVIVES_PER_ACT, "Act 2 checkpoint resets revives")
	RunState.current_floor = 1
	RunState.revives_used = 0
