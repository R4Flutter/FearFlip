extends McpTestSuite
## Through the wall: rooms side by side, the way round long. With Flipping Time coming the Devil stands at the wall
## beside you and pounds it; the flip breaks it through and it reels in the hole. Otherwise it slams it as it passes.

const WAKE := FloorLayout.World.WAKE
const NIGHTMARE := FloorLayout.World.NIGHTMARE
const NOWHERE := DevilBrain.NOWHERE


func suite_name() -> String:
	return "thin_wall"


func suite_setup(_ctx: Dictionary) -> void:
	MetaState.profile_path = "user://test_profile.cfg"
	RunState.save_path = "user://test_run_state.cfg"


## 7x7, the same in both worlds: a U of rooms (1,1) (1,3) (1,5) (3,5) (3,3) (3,1). The walls (2,1) and (2,3) keep the
## arms apart: (1,1) -> (3,1) is 10 tiles round, 2 through the wall.
func _u_layout() -> FloorLayout:
	var layout := FloorLayout.new()
	layout.size = 7
	var grid := PackedByteArray()
	grid.resize(49)
	grid.fill(1)
	for cell: Vector2i in [Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(1, 4), Vector2i(1, 5), Vector2i(2, 5),
			Vector2i(3, 5), Vector2i(3, 4), Vector2i(3, 3), Vector2i(3, 2), Vector2i(3, 1)]:
		grid[cell.y * 7 + cell.x] = 0
	layout.walls.append(grid)
	layout.walls.append(grid.duplicate())
	return layout


func test_the_wall_between_rooms_side_by_side() -> void:
	var layout := _u_layout()
	assert_eq(DevilBrain.wall_between(layout, WAKE, Vector2i(1, 1), Vector2i(3, 1)), Vector2i(2, 1))
	assert_eq(DevilBrain.wall_between(layout, WAKE, Vector2i(3, 3), Vector2i(1, 3)), Vector2i(2, 3), "either way")
	assert_eq(DevilBrain.wall_between(layout, WAKE, Vector2i(1, 1), Vector2i(1, 3)), NOWHERE, "open between")
	assert_eq(DevilBrain.wall_between(layout, WAKE, Vector2i(1, 1), Vector2i(3, 3)), NOWHERE, "diagonal")
	assert_eq(DevilBrain.wall_between(layout, WAKE, Vector2i(1, 1), Vector2i(5, 1)), NOWHERE, "two walls away")
	assert_eq(DevilBrain.wall_between(layout, WAKE, Vector2i(1, 1), Vector2i(-1, 1)), NOWHERE, "the outer wall")


func test_it_waits_at_the_wall_only_if_it_gets_there_in_time_and_saves_the_way_round() -> void:
	var layout := _u_layout()
	var at_wall := layout.distances(WAKE, Vector2i(3, 1))
	assert_eq(DevilBrain.thin_wall(layout, WAKE, Vector2i(1, 1), at_wall, 10, 0), Vector2i(2, 1), "10 round, 2 through")
	assert_eq(DevilBrain.thin_wall(layout, WAKE, Vector2i(1, 1), at_wall, 5, 0), NOWHERE, "a short way round: it walks it")
	var two_off := layout.distances(WAKE, Vector2i(3, 3))  # the far side is 2 steps on, you are 8 round
	assert_eq(DevilBrain.thin_wall(layout, WAKE, Vector2i(1, 1), two_off, 8, 1), NOWHERE, "can't get there before the flip")
	assert_eq(DevilBrain.thin_wall(layout, WAKE, Vector2i(1, 1), two_off, 8, 2), Vector2i(2, 1))
	assert_eq(DevilBrain.thin_wall(layout, WAKE, Vector2i(1, 2), at_wall, 9, 3), NOWHERE, "only walls right beside you")


func test_a_broken_wall_is_open_in_both_worlds() -> void:
	var layout := _u_layout()
	layout.open_cell(Vector2i(2, 1))
	assert_true(layout.is_open(WAKE, Vector2i(2, 1)))
	assert_true(layout.is_open(NIGHTMARE, Vector2i(2, 1)))
	assert_eq(layout.distances(WAKE, Vector2i(1, 1))[1 * 7 + 3], 2, "the way through")
	assert_eq(DevilBrain.wall_between(layout, WAKE, Vector2i(1, 1), Vector2i(3, 1)), NOWHERE, "nothing left to break")


# --- The real floor ---------------------------------------------------------

func _spawn_floor() -> Node3D:
	RunState.floor_cards.clear()
	RunState.run_cards.clear()
	RunState.current_floor = 1
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	main.fixed_seed = 42
	(Engine.get_main_loop() as SceneTree).root.add_child(main)
	track(main)
	return main


## [your room, the wall, the room beside it] with the way round at least `round_tiles` long, outside safe circles.
func _side_by_side(main: Node3D, round_tiles := 6) -> Array[Vector2i]:
	var layout: FloorLayout = main.layout
	for y in range(1, layout.size - 1, 2):
		for x in range(1, layout.size - 1, 2):
			var you := Vector2i(x, y)
			for d in FloorLayout.DIRS:
				var far := you + d * 2
				var wall := DevilBrain.wall_between(layout, WAKE, you, far)
				if wall == NOWHERE or main.circles.protects(you) or main.circles.protects(far):
					continue
				if layout.distances(WAKE, you)[far.y * layout.size + far.x] >= round_tiles:
					return [you, wall, far]
	return []


func _move_player(main: Node3D, cell: Vector2i) -> void:
	main.player.global_position = main.cell_to_world(cell) + Vector3(0, main.PLAYER_HEIGHT, 0)
	main.player_cell = cell
	main.last_player_cell = cell
	main.player_dist = main.layout.distances(main.world, cell)


## The first open cell next to `cell`.
func _open_neighbour(main: Node3D, cell: Vector2i) -> Vector2i:
	for d in FloorLayout.DIRS:
		if main.layout.is_open(WAKE, cell + d):
			return cell + d
	return cell


func _stage(main: Node3D, you: Vector2i, devil: Vector2i) -> void:
	_move_player(main, you)
	main._wake_devil()
	main.devil_cell = devil
	main.prev_devil_cell = devil
	main.devil.position = main._devil_world_position()


func _solid(main: Node3D, cell: Vector2i) -> bool:
	var at: Vector3 = main.cell_to_world(cell)
	for child in main.get_node("SharedWalls").get_children():
		var shape := child as CollisionShape3D
		if shape != null and not shape.disabled and is_equal_approx(shape.position.x, at.x) and is_equal_approx(shape.position.z, at.z):
			return true
	return false


func test_flipping_time_it_pounds_the_wall_beside_you_then_breaks_through() -> void:
	var main := _spawn_floor()
	var spot := _side_by_side(main)
	assert_false(spot.is_empty(), "seed 42 has rooms side by side")
	_stage(main, spot[0], spot[2])
	main.flip.warning_active = true
	main.flip.next_forced_in = 2.5
	main._tick_wall(0.05)
	assert_eq(main.thin_wall, spot[1], "it takes the wall between you")
	assert_eq(main._devil_goal(), spot[2], "and stays at it instead of walking round")
	assert_eq(main.pound_left, main.THIN_WALL_POUND, "first blow")
	assert_true(_solid(main, spot[1]), "pounding breaks nothing yet")
	main._on_flipped(NIGHTMARE, true)
	assert_true(main.layout.is_open(WAKE, spot[1]) and main.layout.is_open(NIGHTMARE, spot[1]), "the flip breaks it")
	assert_false(_solid(main, spot[1]), "nothing solid left in the hole")
	assert_eq(main.devil_cell, spot[2], "no fair-flip teleport: it stands in the hole it made")
	assert_eq(main.devil_stun, main.THIN_WALL_STUN, "and reels: your head start")
	assert_eq(main.player_dist[spot[2].y * main.layout.size + spot[2].x], 2, "two tiles through the hole")
	assert_eq(main.thin_wall, NOWHERE)
	var next := _side_by_side(main)
	_stage(main, next[0], next[2])
	main.flip.warning_active = true
	main._tick_wall(0.05)
	assert_eq(main.thin_wall, NOWHERE, "once a floor")


func test_no_breach_unless_it_stands_at_the_wall_when_the_flip_lands() -> void:
	var main := _spawn_floor()
	var spot := _side_by_side(main, 10)
	assert_false(spot.is_empty(), "seed 42 has a long way round somewhere")
	_stage(main, spot[0], _open_neighbour(main, spot[2]))  # one step off the far side
	main.flip.warning_active = true
	main.flip.next_forced_in = 9.0  # time for that step, whatever its pace
	main._tick_wall(0.05)
	assert_eq(main.thin_wall, spot[1], "it heads for the wall")
	main._on_flipped(NIGHTMARE, true)
	assert_true(_solid(main, spot[1]), "the flip came first: the wall holds")
	assert_eq(main.thin_wall, NOWHERE)
	assert_eq(main.devil_stun, 0.0)


func test_without_flipping_time_it_slams_the_wall_once_as_it_passes() -> void:
	var main := _spawn_floor()
	var spot := _side_by_side(main)
	_stage(main, spot[0], spot[2])
	main._tick_wall(0.05)
	assert_eq(main.thin_wall, NOWHERE, "no flip coming: it doesn't stop")
	assert_eq(main.knock_left, main.KNOCK_COOLDOWN, "one slam")
	main._tick_wall(0.05)
	assert_true(main.knock_left < main.KNOCK_COOLDOWN, "not another right away")
	assert_true(_solid(main, spot[1]), "a slam breaks nothing")


func test_an_echo_or_a_safe_circle_calls_it_off_the_wall() -> void:
	var main := _spawn_floor()
	var spot := _side_by_side(main)
	_stage(main, spot[0], spot[2])
	main.flip.warning_active = true
	main.flip.next_forced_in = 2.5
	main.brain.investigate(main.layout.spawn)
	main._tick_wall(0.05)
	assert_eq(main.thin_wall, NOWHERE, "an Echo Step echo draws it aside")
	main.brain.interest = NOWHERE
	main._tick_wall(0.05)
	assert_eq(main.thin_wall, spot[1])
	main.devil_retreating = true
	main._tick_wall(0.05)
	assert_eq(main.thin_wall, NOWHERE, "so does a safe circle")


func test_before_the_warning_it_slips_to_the_wall_and_waits_there_in_silence() -> void:
	var main := _spawn_floor()
	var spot := _side_by_side(main, 10)
	_stage(main, spot[0], _open_neighbour(main, spot[2]))
	main.flip.next_forced_in = 8.0  # Flipping Time soon, no warning yet
	main._tick_wall(0.05)
	assert_eq(main.thin_wall, spot[1], "it plans the breach before the warning")
	main._step_devil()
	assert_eq(main.devil_cell, spot[2], "and walks to the wall")
	main.devil.position = main._devil_world_position()
	main._tick_wall(0.05)
	assert_eq(main.pound_left, 0.0, "silent until the warning")
	main.flip.warning_active = true
	main._tick_wall(0.05)
	assert_eq(main.pound_left, main.THIN_WALL_POUND, "the warning sounds and it pounds")


func test_it_follows_you_room_to_room_until_it_pounds_then_it_is_committed() -> void:
	var main := _spawn_floor()
	var spot := _side_by_side(main)
	var passage := _open_neighbour(main, spot[0])
	var next_room := passage * 2 - spot[0]
	_stage(main, spot[0], spot[2])
	main.flip.next_forced_in = 8.0
	main._tick_wall(0.05)
	assert_eq(main.thin_wall, spot[1])
	_move_player(main, passage)
	main._tick_wall(0.05)
	assert_eq(main.thin_wall, spot[1], "in a passage it keeps the wall by the room you just left")
	_move_player(main, next_room)
	main._tick_wall(0.05)
	assert_ne(main.thin_wall, spot[1], "a new room before the warning: it re-picks, or comes round")
	_move_player(main, spot[0])
	main.flip.warning_active = true
	main.flip.next_forced_in = 2.5
	main._tick_wall(0.05)
	assert_eq(main.pound_left, main.THIN_WALL_POUND, "beside it in the warning: it pounds")
	_move_player(main, next_room)
	main._tick_wall(0.05)
	assert_eq(main.thin_wall, spot[1], "pounding, it's committed: run")


func test_f9_stages_a_breach_through_the_real_flip() -> void:
	var main := _spawn_floor()
	var spot := _side_by_side(main)
	_move_player(main, spot[0])
	main._debug_thin_wall()
	assert_ne(DevilBrain.wall_between(main.layout, WAKE, main.player_cell, main.devil_cell), NOWHERE, "it waits beside you")
	for _frame in 120:  # 6 s of game: the warning, the blows, the flip
		main._process(0.05)
		if main.thin_walls == 1:
			break
	assert_eq(main.thin_walls, 1, "the real Flipping Time broke it through")
	assert_eq(main.world, NIGHTMARE)


func test_it_wakes_out_of_the_wall_behind_it_as_it_sets_off() -> void:
	var layout := _u_layout()
	assert_eq(DevilBrain.burst_wall(layout, WAKE, Vector2i(1, 1), Vector2i(0, 1)), Vector2i(1, 0), "behind it")
	assert_eq(DevilBrain.burst_wall(layout, WAKE, Vector2i(1, 3), Vector2i(0, 1)), Vector2i(2, 3), "open behind: a wall beside")
	assert_eq(DevilBrain.burst_wall(layout, WAKE, Vector2i(1, 2), Vector2i.ZERO), Vector2i(2, 2), "a passage has its pillars")


func test_waking_it_tears_out_of_a_wall() -> void:
	var main := _spawn_floor()
	main._wake_devil()
	var cell: Vector2i = main.devil_cell
	var inside: Vector2i = main.world_to_cell(main.devil.position)
	assert_eq(absi(inside.x - cell.x) + absi(inside.y - cell.y), 1, "it starts in a wall beside its cell")
	assert_false(main.layout.is_open(WAKE, inside), "inside the stone")
	assert_true(_solid(main, inside), "the wall stays: the maze doesn't change")
	for _frame in 60:  # 3 s
		main._process(0.05)
	assert_true(main.layout.is_open(WAKE, main.world_to_cell(main.devil.position)), "out in the corridor, hunting")


func test_the_wake_cut_leaves_you_for_its_roar_then_rushes_back_while_the_world_holds() -> void:
	var main := _spawn_floor()
	var clock: float = main.time_left
	main._wake_devil()
	main._start_wake_cut()
	assert_eq(main.game_state, "waking")
	assert_true(main.camera.top_level, "the camera leaves your eyes")
	assert_false(main.get_node("HUD").visible, "no HUD in the shot")
	var frames := 0
	while main.game_state == "waking" and frames < 200:
		main._process(0.05)
		frames += 1
	assert_eq(main.game_state, "playing", "and comes back")
	assert_true(frames * 0.05 > main.WAKE_TEAR + main.WAKE_ROAR, "after the roar and the rush")
	assert_false(main.camera.top_level)
	assert_eq(main.camera.transform, Transform3D(), "right back in your eyes")
	assert_true(main.get_node("HUD").visible)
	assert_eq(main.time_left, clock, "your clock held still")
	assert_true(main.devil.position.is_equal_approx(main._devil_world_position()), "it stands where it woke")


func test_any_key_skips_the_wake_cut() -> void:
	var main := _spawn_floor()
	main._wake_devil()
	main._start_wake_cut()
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	main._unhandled_input(key)
	assert_eq(main.game_state, "playing")
	assert_false(main.camera.top_level)
	assert_true(main.devil.position.is_equal_approx(main._devil_world_position()))
