extends McpTestSuite
## Generator rules (FEARFLIP_3D_GAME_APPROACH.md §8): deterministic, always solvable, flip required.

const ROOMS := 7  # depth 1: 15x15
const WAKE := FloorLayout.World.WAKE
const NIGHTMARE := FloorLayout.World.NIGHTMARE


func suite_name() -> String:
	return "floor_layout"


func test_same_seed_same_floor() -> void:
	var a := FloorLayout.generate(1234, ROOMS)
	var b := FloorLayout.generate(1234, ROOMS)
	assert_eq(a.walls, b.walls)
	assert_eq(a.sigils, b.sigils)
	assert_eq(a.devil_spawn, b.devil_spawn)
	assert_ne(FloorLayout.generate(1235, ROOMS).walls, a.walls, "different seeds should differ")


func test_1000_seeds_valid_and_fast() -> void:
	var worst_ms := 0.0
	var total_ms := 0.0
	for seed_value in 1000:
		var start := Time.get_ticks_usec()
		var layout := FloorLayout.generate(seed_value, ROOMS)
		var ms := (Time.get_ticks_usec() - start) / 1000.0
		total_ms += ms
		worst_ms = maxf(worst_ms, ms)
		var problem := layout.validate()
		if not problem.is_empty():
			assert_true(false, "seed %d: %s" % [seed_value, problem])
			return
	assert_true(total_ms / 1000.0 < 50.0, "average %.1f ms (worst %.1f ms) over 50 ms budget" % [total_ms / 1000.0, worst_ms])


## Fair keys: 2 of them, on the spawn -> exit route (no dead-end branch), in the half nearest the exit.
func test_keys_on_route_near_exit() -> void:
	for rooms in [ROOMS, StageRule.ROOMS_3D.x, StageRule.ROOMS_3D.y]:
		for seed_value in 100:
			var layout := FloorLayout.generate(seed_value, rooms)
			var path := layout.route(layout.spawn, layout.exit)
			assert_eq(layout.sigils.size(), 2)
			for key in layout.sigils:
				var at := path.find(key)
				assert_true(at >= 0, "rooms %d seed %d: key %s off the exit route" % [rooms, seed_value, key])
				assert_true(at >= path.size() * (1.0 - FloorLayout.KEY_ROUTE_SHARE) - 1.0, "rooms %d seed %d: key %s far from exit" % [rooms, seed_value, key])


## A flip never moves walls: WAKE and NIGHTMARE are the same maze.
func test_nightmare_keeps_the_same_maze() -> void:
	for seed_value in 50:
		var layout := FloorLayout.generate(seed_value, ROOMS)
		assert_eq(layout.walls[NIGHTMARE], layout.walls[WAKE], "seed %d" % seed_value)


func test_wake_is_a_perfect_maze_like_2d() -> void:
	var layout := FloorLayout.generate(7, ROOMS)
	var open := 0
	for y in layout.size:
		for x in layout.size:
			if layout.is_open(WAKE, Vector2i(x, y)):
				open += 1
	# A perfect maze has exactly rooms^2 room cells + (rooms^2 - 1) connectors.
	assert_eq(open, ROOMS * ROOMS * 2 - 1)


func test_spawn_and_exit_identical_in_both_worlds() -> void:
	var layout := FloorLayout.generate(99, ROOMS)
	for center in [layout.spawn, layout.exit]:
		for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var cell: Vector2i = center + offset
			assert_eq(layout.is_open(WAKE, cell), layout.is_open(NIGHTMARE, cell), "cell %s" % cell)


func test_next_step_moves_closer() -> void:
	var layout := FloorLayout.generate(5, ROOMS)
	var dist := layout.distances(NIGHTMARE, layout.spawn)
	var step := layout.next_step(NIGHTMARE, layout.devil_spawn, layout.spawn)
	assert_eq(dist[step.y * layout.size + step.x], dist[layout.devil_spawn.y * layout.size + layout.devil_spawn.x] - 1)
	assert_eq(layout.next_step(NIGHTMARE, layout.spawn, layout.spawn), layout.spawn)


func test_key_count_is_a_parameter() -> void:
	var valid := 0
	for seed_value in 200:
		var layout := FloorLayout.generate(seed_value, ROOMS + 2, Cards.MAX_KEYS)
		if layout.sigils.size() == Cards.MAX_KEYS and layout.validate().is_empty():
			valid += 1
	assert_eq(valid, 200, "five keys placed and reachable on every seed")


func test_sanctuary_sized_floors_stay_valid() -> void:
	var valid := 0
	for seed_value in 300:
		if FloorLayout.generate(seed_value, Cards.MIN_ROOMS).validate().is_empty():
			valid += 1
	assert_eq(valid, 300)


func test_detours_are_dead_ends_off_the_route() -> void:
	var checked := 0
	for seed_value in 100:
		var layout := FloorLayout.generate(seed_value, ROOMS + 2)
		var route := layout.route(layout.spawn, layout.exit)
		var every := layout.detours(999, [])
		var problem := "" if layout.detours(3, layout.sigils).size() == 3 else "fewer than 3"
		for cell in layout.detours(3, layout.sigils):
			if layout.sigils.has(cell):
				problem = "%s is excluded" % cell
		for cell in every:
			var ways := 0
			for d in FloorLayout.DIRS:
				ways += 1 if layout.is_open(FloorLayout.ANY, cell + d) else 0
			if ways != 1 or route.has(cell) or every.count(cell) > 1 					or not (layout.is_open(WAKE, cell) and layout.is_open(NIGHTMARE, cell)):
				problem = "%s is no dead end off the route" % cell
		if problem != "":
			assert_true(false, "seed %d: %s" % [seed_value, problem])
			return
		checked += 1
	assert_eq(checked, 100)
