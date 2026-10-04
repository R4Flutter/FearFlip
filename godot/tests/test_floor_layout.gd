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


func test_nightmare_changes_target_share_of_connectors() -> void:
	var changed := 0
	var connectors := 0
	for seed_value in 50:
		var layout := FloorLayout.generate(seed_value, ROOMS)
		for y in range(1, layout.size - 1):
			for x in range(1, layout.size - 1):
				if x % 2 == y % 2:
					continue
				connectors += 1
				if layout.is_open(WAKE, Vector2i(x, y)) != layout.is_open(NIGHTMARE, Vector2i(x, y)):
					changed += 1
	var share := float(changed) / connectors
	assert_true(share > 0.15 and share < 0.35, "nightmare changed %.2f of connectors" % share)


func test_braiding_adds_loops() -> void:
	var layout := FloorLayout.generate(7, ROOMS)
	var open := 0
	for y in layout.size:
		for x in layout.size:
			if layout.is_open(WAKE, Vector2i(x, y)):
				open += 1
	# A perfect maze has exactly rooms^2 room cells + (rooms^2 - 1) connectors.
	assert_gt(open, ROOMS * ROOMS * 2 - 1)


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
