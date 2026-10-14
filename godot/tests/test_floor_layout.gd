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
	assert_eq(a.boxes, b.boxes, "the same boxes, the keys in the same ones: a Daily is the same for everyone")
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


## Keys hide in boxes (user, 14 Oct 2026): 2 keys + 3 empty boxes, each in a cell of its own, down every dead end at most
## BOX_MAX_DETOUR path tiles off the spawn -> exit route they can take while SPARE_DEAD_ENDS stay free (chests, the
## Sanctuary's altar), the rest on the route. On the real floors nearly all of them go down dead ends.
func test_keys_hide_in_boxes_down_short_dead_ends() -> void:
	for rooms in [7, StageRule.ROOMS_3D.x, StageRule.ROOMS_3D.y]:
		var routed := 0
		for seed_value in 100:
			var layout := FloorLayout.generate(seed_value, rooms, 2, 3)
			var path := layout.route(layout.spawn, layout.exit)
			var off := layout._distances_from(FloorLayout.ANY, path)
			var dead_ends := 0
			var short_ends: Array[Vector2i] = []
			for y in range(1, layout.size, 2):
				for x in range(1, layout.size, 2):
					var cell := Vector2i(x, y)
					if cell != layout.spawn and cell != layout.exit and _ways(layout, cell) == 1:
						dead_ends += 1
						if off[y * layout.size + x] <= FloorLayout.BOX_MAX_DETOUR:
							short_ends.append(cell)
			var down := layout.boxes.filter(func(cell: Vector2i) -> bool: return short_ends.has(cell)).size()
			routed += layout.boxes.size() - down
			var problem := "" if layout.boxes.size() == 5 and layout.sigils.size() == 2 else "%d boxes" % layout.boxes.size()
			if down != mini(5, mini(short_ends.size(), maxi(dead_ends - FloorLayout.SPARE_DEAD_ENDS, 0))):
				problem = "%d boxes down %d short dead ends of %d" % [down, short_ends.size(), dead_ends]
			for cell in layout.boxes:
				if layout.boxes.count(cell) > 1 or not (short_ends.has(cell) or path.has(cell)):
					problem = "box %s is neither alone down a short dead end nor on the route" % cell
			for key in layout.sigils:
				if not layout.boxes.has(key):
					problem = "key %s outside the boxes" % key
			if problem != "":
				assert_true(false, "rooms %d seed %d: %s" % [rooms, seed_value, problem])
				return
		if rooms != 7:
			assert_true(routed < 50, "rooms %d: %d of 500 boxes on the route" % [rooms, routed])


func _ways(layout: FloorLayout, cell: Vector2i) -> int:
	var ways := 0
	for d in FloorLayout.DIRS:
		ways += 1 if layout.is_open(FloorLayout.ANY, cell + d) else 0
	return ways


## A flip never moves walls: WAKE and NIGHTMARE are the same maze.
func test_nightmare_keeps_the_same_maze() -> void:
	for seed_value in 50:
		var layout := FloorLayout.generate(seed_value, ROOMS)
		assert_eq(layout.walls[NIGHTMARE], layout.walls[WAKE], "seed %d" % seed_value)


## The 2D perfect maze (FloorLayout.BRAID 0, user 11 Oct 2026: long routes, no loops).
func test_wake_is_a_perfect_maze() -> void:
	var rooms := StageRule.ROOMS_3D.x
	var loops := 0
	for seed_value in 50:
		var layout := FloorLayout.generate(seed_value, rooms)
		var open := 0
		for y in layout.size:
			for x in layout.size:
				if layout.is_open(WAKE, Vector2i(x, y)):
					open += 1
		# A perfect maze has exactly rooms^2 room cells + (rooms^2 - 1) connectors; every loop opens one more.
		assert_true(open >= rooms * rooms * 2 - 1, "seed %d lost a corridor" % seed_value)
		loops += open - (rooms * rooms * 2 - 1)
	assert_eq(loops, 0, "%d loops over 50 floors" % loops)


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
		var layout := FloorLayout.generate(seed_value, ROOMS + 2, Cards.MAX_KEYS, 3)
		if layout.sigils.size() == Cards.MAX_KEYS and layout.boxes.size() == Cards.MAX_KEYS + 3 and layout.validate().is_empty():
			valid += 1
	assert_eq(valid, 200, "five keys in eight boxes, placed and reachable on every seed")


func test_sanctuary_sized_floors_stay_valid() -> void:
	var valid := 0
	for seed_value in 300:
		if FloorLayout.generate(seed_value, Cards.MIN_ROOMS).validate().is_empty():
			valid += 1
	assert_eq(valid, 300)


func test_detours_are_dead_ends_off_the_route() -> void:
	var checked := 0
	for seed_value in 100:
		var layout := FloorLayout.generate(seed_value, StageRule.ROOMS_3D.x)  # the real size: boxes take dead ends too
		var route := layout.route(layout.spawn, layout.exit)
		var every := layout.detours(999, [])
		var problem := "" if layout.detours(3, layout.boxes).size() == 3 else "fewer than 3"
		for cell in layout.detours(3, layout.boxes):
			if layout.boxes.has(cell):
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


func test_detours_never_send_you_back_over_a_crack() -> void:
	var checked := 0
	for seed_value in 100:
		var layout := FloorLayout.generate(seed_value, ROOMS + 2)
		var chest: Vector2i = layout.detours(999, [])[0]
		var blocked: Array[Vector2i] = []
		for d in FloorLayout.DIRS:
			if layout.is_open(FloorLayout.ANY, chest + d):
				blocked.append(chest + d)
		if layout.detours(999, [], blocked).has(chest):
			assert_true(false, "seed %d: the chest at %s sits past a crack" % [seed_value, chest])
			return
		checked += 1
	assert_eq(checked, 100)
