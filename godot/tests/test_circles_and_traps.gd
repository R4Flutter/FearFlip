extends McpTestSuite
## plans/05 §3.5-§3.6 on real floors: circle placement + drain, trap exclusions + two-step rule.

const WAKE := FloorLayout.World.WAKE
const NIGHTMARE := FloorLayout.World.NIGHTMARE
const SEEDS := 200


func suite_name() -> String:
	return "circles_and_traps"


func _both_open(layout: FloorLayout, cell: Vector2i) -> bool:
	return layout.is_open(WAKE, cell) and layout.is_open(NIGHTMARE, cell)


func test_circles_on_route_thirds_and_traps_fair_over_seeds() -> void:
	var placed := 0
	for seed_value in range(1, SEEDS + 1):
		var layout := FloorLayout.generate(seed_value, 7)
		var route := layout.route(layout.spawn, layout.exit)
		assert_true(route.size() > 2, "seed %d: no route" % seed_value)
		var circles := SafeCircles.new()
		circles.place(route, 2, func(cell: Vector2i) -> bool: return _both_open(layout, cell))
		assert_eq(circles.cells.size(), 2, "seed %d circles" % seed_value)
		for cell in circles.cells:
			assert_true(route.has(cell) and cell != layout.spawn and cell != layout.exit, "seed %d circle %s" % [seed_value, cell])
		assert_true(route.find(circles.cells[0]) < route.find(circles.cells[1]), "seed %d circle order" % seed_value)
		var traps := TrapField.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		traps.place(layout, route, 6, circles.cells, seed_value % 2 == 0, rng)
		placed += traps.cells.size()
		for cell in traps.cells:
			assert_false(circles.cells.has(cell), "seed %d trap in a circle" % seed_value)
			assert_true(_both_open(layout, cell))
			assert_true(TrapField._manhattan(cell, layout.spawn) > TrapField.SPAWN_CLEARANCE, "seed %d trap near spawn" % seed_value)
			assert_true(TrapField._manhattan(cell, layout.exit) > TrapField.EXIT_CLEARANCE, "seed %d trap near exit" % seed_value)
			if not TrapField._dead_end_entrance(layout, cell):
				assert_true(TrapField._safe_to_crack(layout, cell), "seed %d trap %s dooms you" % [seed_value, cell])
		for i in traps.cells.size():
			for j in range(i + 1, traps.cells.size()):
				assert_true(TrapField._manhattan(traps.cells[i], traps.cells[j]) >= TrapField.MIN_SPACING)
	assert_true(placed >= SEEDS * 2, "traps must actually spawn in a perfect maze (got %d)" % placed)


func test_circle_drains_then_recharges_after_new_cells() -> void:
	var circles := SafeCircles.new()
	circles.capacity = 2.0
	circles.place([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)], 1, func(_c: Vector2i) -> bool: return true)
	var cell := circles.cells[0]
	assert_true(circles.protects(cell))
	assert_false(circles.drain(cell, 1.0))
	assert_true(circles.drain(cell, 1.5), "runs dry")
	assert_false(circles.protects(cell))
	for _i in SafeCircles.RECHARGE_CELLS:
		circles.on_new_cell()
	assert_true(circles.protects(cell), "refilled after exploring")
	circles.single_use = true
	circles.drain(cell, 5.0)
	for _i in SafeCircles.RECHARGE_CELLS * 2:
		circles.on_new_cell()
	assert_false(circles.protects(cell), "single-use circles stay dark")


func test_trap_two_step_and_creak() -> void:
	var traps := TrapField.new()
	traps.cells.assign([Vector2i(5, 5)])
	traps.states.assign([TrapField.State.HIDDEN])
	traps._primed.assign([true])
	assert_true(traps.creak(Vector2i(5, 4)), "creaks at 1 tile")
	assert_false(traps.creak(Vector2i(5, 4)), "once")
	traps.creak(Vector2i(5, 1))
	assert_true(traps.creak(Vector2i(4, 5)), "re-armed after > 2 tiles")
	assert_eq(traps.step(Vector2i(5, 5)), TrapField.State.CRACKED)
	assert_eq(traps.step(Vector2i(5, 5)), TrapField.State.COLLAPSED)
	assert_eq(traps.step(Vector2i(1, 1)), -1)


func test_feather_step_holds_one_crack_and_keen_eye_creaks_farther() -> void:
	var traps := TrapField.new()
	traps.cells.assign([Vector2i(5, 5), Vector2i(9, 9)])
	traps.states.assign([TrapField.State.HIDDEN, TrapField.State.HIDDEN])
	traps._primed.assign([true, true])
	traps.holds = 1
	traps.step(Vector2i(5, 5))
	assert_eq(traps.step(Vector2i(5, 5)), TrapField.State.CRACKED, "the first one that should give way holds")
	assert_eq(traps.holds, 0)
	assert_eq(traps.step(Vector2i(5, 5)), TrapField.State.COLLAPSED, "once")
	traps.creak_range = 2
	assert_true(traps.creak(Vector2i(9, 7)), "heard from 2 tiles")
	traps.creak(Vector2i(9, 4))
	assert_false(traps.creak(Vector2i(9, 6)), "3 tiles is still too far")


## The 3D pit: plates sit flush with the floor, fall down the shaft on collapse, and a revive puts them back.
func test_trap_pit_falls_and_revive_restores() -> void:
	var pit := TrapPit.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(pit)
	track(pit)
	pit.build(Vector2i(3, 4), StandardMaterial3D.new(), StandardMaterial3D.new(), BoxMesh.new())
	assert_eq(pit.plates.size(), TrapPit.PLATES * TrapPit.PLATES)
	for plate in pit.plates:
		assert_true(absf(plate.position.y + TrapPit.PLATE_THICKNESS * 0.5 - TrapPit.FLOOR_TOP) < 0.001, "hidden = flush floor")
	pit.collapse(pit.global_position)
	for _i in 120:
		pit._process(1.0 / 60.0)
	for plate in pit.plates:
		assert_true(plate.position.y < -3.0, "fell down the shaft")
	pit.show_state(TrapField.State.CRACKED)
	for plate in pit.plates:
		assert_true(plate.visible and plate.position.y > TrapPit.FLOOR_TOP - TrapPit.PLATE_THICKNESS - TrapPit.SAG, "revive restores the cracked plates")