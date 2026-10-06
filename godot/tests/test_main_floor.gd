extends McpTestSuite
## Integration: the real main scene wires FloorLayout + FlipSystem into physics, visuals and win/lose.

const WAKE := FloorLayout.World.WAKE
const NIGHTMARE := FloorLayout.World.NIGHTMARE


func suite_name() -> String:
	return "main_floor"


func _spawn_floor() -> Node3D:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	main.fixed_seed = 42
	(Engine.get_main_loop() as SceneTree).root.add_child(main)
	track(main)
	return main


func test_flip_swaps_collision_and_visuals() -> void:
	var main := _spawn_floor()
	assert_eq(main.world, WAKE)
	assert_eq(main.player.collision_mask, main.LAYER_SHARED | main.LAYER_WAKE)
	assert_false(main.devil.visible, "Devil only exists in NIGHTMARE")
	assert_true(main.flip.request_flip(main._spot_open(NIGHTMARE)), "spawn is open in both worlds")
	assert_eq(main.world, NIGHTMARE)
	assert_eq(main.player.collision_mask, main.LAYER_SHARED | main.LAYER_NIGHTMARE)
	assert_true(main.nightmare_walls.visible and not main.wake_walls.visible)
	assert_false(main.devil.visible, "asleep until it wakes")
	main._wake_devil()
	assert_true(main.devil.visible)


func test_all_keys_open_exit_then_win() -> void:
	var main := _spawn_floor()
	for i in main.layout.sigils.size():
		main._apply_world(main.layout.sigil_worlds[i])
		main.player_cell = main.layout.sigils[i]
		main._collect_sigils()
	assert_true(main.exit_open)
	main.player_cell = main.layout.exit
	main.devil_cell = main.layout.devil_spawn
	main._process(0.016)
	assert_eq(main.game_state, "unlocking", "keys go into the chest first; clock and Devil freeze")
	main._on_chest_opened()
	main._win_game()
	assert_eq(main.game_state, "won")


func test_keys_collect_and_show_in_either_world() -> void:
	var main := _spawn_floor()
	main._apply_world(NIGHTMARE)
	for i in main.layout.sigils.size():
		assert_true(main.sigil_nodes[i].visible, "key %d visible in NIGHTMARE" % i)
		for w in [WAKE, NIGHTMARE]:
			assert_true(main.layout.is_open(w, main.layout.sigils[i]), "key %d cell open in world %d" % [i, w])
	var nightmare_sigil: int = main.layout.sigil_worlds.find(NIGHTMARE)
	main._apply_world(WAKE)
	main.player_cell = main.layout.sigils[nightmare_sigil]
	main._collect_sigils()
	assert_eq(main.sigils_collected, 1, "a NIGHTMARE-coloured key is collectible in WAKE")


func _run(main: Node3D, seconds: float) -> void:
	for _frame in int(seconds / 0.05):
		main._process(0.05)


func test_devil_walks_shortest_path_through_open_cells() -> void:
	var main := _spawn_floor()
	main._wake_devil()
	main.devil_cell = main.layout.devil_spawn
	var left: int = main._devil_distance()
	while left > 0:
		var from: Vector2i = main.devil_cell
		main._step_devil()
		var to: Vector2i = main.devil_cell
		assert_eq(absi(to.x - from.x) + absi(to.y - from.y), 1, "one neighbour per step")
		assert_true(main.layout.is_open(main.world, to), "walked into a wall at %s" % to)
		left -= 1
		assert_eq(main._devil_distance(), left, "not the shortest path")
	assert_eq(main.devil_cell, main.player_cell)


func test_devil_grabs_in_both_worlds_with_a_lunge() -> void:
	for w: int in [WAKE, NIGHTMARE]:
		var main := _spawn_floor()
		main._wake_devil()
		main._apply_world(w)
		main.catch_grace = 0.0
		main.devil_cell = main.player_cell
		main.devil.position = main._devil_world_position()
		main._process(0.05)
		assert_gt(main.lunge_left, 0.0, "a catch is a visible lunge first (world %d)" % w)
		assert_eq(main.game_state, "playing")
		_run(main, 0.5)
		assert_eq(main.game_state, "lost", "world %d" % w)
		assert_true(main.death_screen.visible)


func test_safe_circle_blocks_catch_and_revive_returns_there() -> void:
	var main := _spawn_floor()
	var circle: Vector2i = main.circles.cells[0]
	main._wake_devil()
	main._apply_world(NIGHTMARE)
	main.catch_grace = 0.0
	main._enter_cell(circle)
	assert_false(main.snapshot.is_empty(), "entering a circle saves the revive point")
	assert_true(main.devil_retreating)
	main.devil_cell = circle
	_run(main, 0.5)
	assert_eq(main.game_state, "playing", "no catch inside a circle")
	RunState.save_path = "user://test_run_state.cfg"
	main._lose_game("time")
	var revives: int = RunState.revives_left()
	main._revive()
	assert_eq(main.game_state, "playing")
	assert_eq(main.player_cell, circle)
	assert_eq(RunState.revives_left(), revives - 1)
	RunState.revives_used = 0


func test_cracked_floor_kills_on_second_step() -> void:
	var main := _spawn_floor()
	var away: Vector2i = main.player_cell
	var cell := away
	for d in FloorLayout.DIRS:
		if main.layout.is_open(WAKE, away + d):
			cell = away + d
	main.traps.cells.assign([cell])
	main.traps.states.assign([TrapField.State.HIDDEN])
	main.traps._primed.assign([true])
	main.trap_nodes.clear()
	main._build_traps()
	main._enter_cell(cell)
	assert_eq(main.traps.states[0], TrapField.State.CRACKED)
	assert_eq(main.game_state, "playing", "the first step is always safe")
	main._enter_cell(away)
	main._enter_cell(cell)
	assert_eq(main.game_state, "dying")


func test_clock_zero_loses() -> void:
	var main := _spawn_floor()
	assert_gt(main.time_left, 60.0)
	main.time_left = 0.01
	main._process(0.05)
	assert_eq(main.game_state, "lost")


func test_forced_flip_moves_close_devil_away() -> void:
	var main := _spawn_floor()
	main._wake_devil()
	for d in FloorLayout.DIRS:
		if main.layout.is_open(NIGHTMARE, main.player_cell + d):
			main.devil_cell = main.player_cell + d
	main._on_flipped(NIGHTMARE, true)
	var dist: PackedInt32Array = main.layout.distances(NIGHTMARE, main.player_cell)
	assert_true(dist[main.devil_cell.y * main.layout.size + main.devil_cell.x] >= main.DEVIL_RETREAT_DISTANCE)


func test_flipping_time_inverts_movement() -> void:
	var main := _spawn_floor()
	Input.action_press("move_forward")
	Input.action_press("move_left")
	var normal: Vector2 = main._move_input()
	main.flip.forced_active = true
	var inverted: Vector2 = main._move_input()
	Input.action_release("move_forward")
	Input.action_release("move_left")
	assert_true(normal.y < 0.0 and normal.x < 0.0, "W forward, A left normally")
	assert_eq(inverted, -normal, "Flipping Time: W goes back, A goes right")
