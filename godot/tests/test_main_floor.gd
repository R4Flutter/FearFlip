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
	assert_true(main.devil.visible)


func test_three_sigils_open_exit_then_win() -> void:
	var main := _spawn_floor()
	for i in main.layout.sigils.size():
		main._apply_world(main.layout.sigil_worlds[i])
		main.player_cell = main.layout.sigils[i]
		main._collect_sigils()
	assert_true(main.exit_open)
	main.player_cell = main.layout.exit
	main.devil_cell = main.layout.devil_spawn
	main._process(0.016)
	assert_eq(main.game_state, "won")


func test_wrong_world_sigil_is_not_collected() -> void:
	var main := _spawn_floor()
	var nightmare_sigil: int = main.layout.sigil_worlds.find(NIGHTMARE)
	main.player_cell = main.layout.sigils[nightmare_sigil]
	main._collect_sigils()
	assert_eq(main.sigils_collected, 0)


func test_devil_grabs_only_in_nightmare() -> void:
	var main := _spawn_floor()
	main.devil_cell = main.player_cell
	main.devil_target = main.player_cell
	main._process(0.016)
	assert_eq(main.game_state, "playing", "safe in WAKE")
	main._apply_world(NIGHTMARE)
	main.catch_grace = 0.0
	main._process(0.016)
	assert_eq(main.game_state, "lost")


func test_forced_flip_moves_close_devil_away() -> void:
	var main := _spawn_floor()
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
