extends McpTestSuite
## plans/12: VERSUS. The wire refuses whatever isn't a message; the referee says where the runner is only when the
## Devil could see them; the better runner wins the match; a versus floor folds nothing in; the Devil's legs; the track
## the other player is drawn from; and a real floor built for each role.

const PROFILE := "user://test_profile.cfg"
const SAVE := "user://test_run_state.cfg"
const WAKE := FloorLayout.World.WAKE


func suite_name() -> String:
	return "versus"


func suite_setup(_ctx: Dictionary) -> void:
	MetaState.profile_path = PROFILE
	RunState.save_path = SAVE


func teardown() -> void:
	RunState.mode = "campaign"
	RunState.current_floor = 1
	Versus.host = true
	Versus.hard = false
	Versus.reset()


func test_messages_cross_the_wire_unchanged_and_small() -> void:
	for msg: Array in [
		[Versus.HELLO, Versus.PROTOCOL, "RustyCake"],
		[Versus.START, 123456, 1, 2],
		[Versus.READY, 1],
		[Versus.POS, 3, 12.5, -4.0, 1.2, 3.3],
		[Versus.SEEN, 1.0, 2.0, 0.5, 4.0, Versus.KNEEL | Versus.LIGHT],
		[Versus.HEARD, 7, 9, Versus.Sound.SPRINT],
		[Versus.EVENT, Versus.Event.FLIP, 1.0, 0.0],
		[Versus.END, 2, Versus.Result.ESCAPED, 140.5],
		[Versus.PING],
	]:
		assert_eq(Versus.decode(Versus.encode(msg)), msg, "type %d" % msg[0])
		assert_true(Versus.encode(msg).size() <= Versus.MAX_BYTES, "under the relay's limit: type %d" % msg[0])


func test_untrusted_bytes_are_dropped() -> void:
	for bad: Variant in [
		[],
		[99, 1],  # an unknown type
		[Versus.READY],  # a field short
		[Versus.READY, 1, 2],  # a field over
		[Versus.POS, 1, 2, 3.0, 4.0, 5.0],  # an int where a float goes
		[Versus.POS, 1, INF, 0.0, 0.0, 0.0],  # not finite
		[Versus.POS, 1, NAN, 0.0, 0.0, 0.0],
		[Versus.HELLO, Versus.PROTOCOL, "x".repeat(Versus.MAX_NAME + 1)],  # a name too long
		{"type": Versus.PING},  # not an Array
		"PING",
	]:
		assert_true(Versus.decode(var_to_bytes(bad)).is_empty(), str(bad))
	assert_true(Versus.decode(PackedByteArray()).is_empty(), "nothing")
	assert_true(Versus.decode(var_to_bytes([Versus.HELLO, Versus.PROTOCOL, "x".repeat(400)])).is_empty(), "over MAX_BYTES")


func test_the_runner_is_sent_only_where_the_devil_could_see_them() -> void:
	var layout := FloorLayout.generate(7, 12, 2, 1)
	var seen := 0
	var hidden := 0
	var near := 0
	for y in layout.size:
		for x in layout.size:
			var a := Vector2i(x, y)
			if not layout.is_open(WAKE, a):
				continue
			var dist := layout.distances(WAKE, a)
			for step in range(1, Versus.SIGHT_TILES + 1):
				var b := a + Vector2i(step, 0)
				if not layout.is_open(WAKE, b):
					continue
				var gap := dist[b.y * layout.size + b.x]
				var clear := true
				for i in range(1, step):
					clear = clear and layout.is_open(WAKE, a + Vector2i(i, 0))
				if clear:
					seen += 1
					assert_true(Versus.runner_visible(layout, WAKE, a, b, gap), "down a straight corridor: %s %s" % [a, b])
				elif gap > Versus.NEAR_TILES:
					hidden += 1
					assert_false(Versus.runner_visible(layout, WAKE, a, b, gap), "a wall between: %s %s" % [a, b])
			# Round a corner but close by path: seen (it hears your breath; the puppet never pops in at a corner).
			for d in [Vector2i(1, 1), Vector2i(-1, 1)]:
				var c: Vector2i = a + d
				var by_path := dist[c.y * layout.size + c.x] if layout.is_open(WAKE, c) else -1
				if by_path > 0 and by_path <= Versus.NEAR_TILES:
					near += 1
					assert_true(Versus.runner_visible(layout, WAKE, a, c, by_path), "close by path: %s %s" % [a, c])
	assert_true(seen > 50 and hidden > 50 and near > 10, "the maze tried every case: %d %d %d" % [seen, hidden, near])


func test_the_better_runner_wins_the_match() -> void:
	var host_fast := {"host_ran": true, "result": Versus.Result.ESCAPED, "seconds": 120.0}
	var guest_slow := {"host_ran": false, "result": Versus.Result.ESCAPED, "seconds": 150.0}
	var guest_caught_late := {"host_ran": false, "result": Versus.Result.CAUGHT, "seconds": 200.0}
	var host_caught_early := {"host_ran": true, "result": Versus.Result.CAUGHT, "seconds": 90.0}
	assert_eq(Versus.winner(_rounds([host_fast, guest_slow])), "host", "both got out: the faster")
	assert_eq(Versus.winner(_rounds([guest_slow, host_fast])), "host", "who ran each round counts, not the order")
	assert_eq(Versus.winner(_rounds([host_fast, guest_caught_late])), "host", "out beats caught, however long it took")
	assert_eq(Versus.winner(_rounds([host_caught_early, guest_caught_late])), "guest", "both caught: the longer")
	var guest_timed_out := {"host_ran": false, "result": Versus.Result.TIME, "seconds": 90.0}
	assert_eq(Versus.winner(_rounds([host_caught_early, guest_timed_out])), "draw")
	assert_eq(Versus.winner(_rounds([host_fast])), "", "one round: not over yet")
	var fled := {"host_ran": false, "result": Versus.Result.RUNNER_LEFT, "seconds": 3.0}
	assert_eq(Versus.winner(_rounds([host_fast, fled])), "", "someone left: no winner")


func test_roles_swap_and_each_round_has_its_maze() -> void:
	Versus.host = true
	Versus.round_number = 1
	assert_true(Versus.i_run(), "the room's maker runs first")
	Versus.round_number = 2
	assert_false(Versus.i_run(), "then is the Devil")
	Versus.host = false
	assert_true(Versus.i_run(), "the friend runs round 2")
	Versus.match_seed = 500
	assert_eq(Versus.round_seed(), 501)
	Versus.round_number = 1
	assert_eq(Versus.round_seed(), 500)


func test_a_versus_floor_folds_nothing_in() -> void:
	RunState.start_versus(42)
	assert_true(RunState.is_versus())
	assert_true(RunState.floor_cards.is_empty(), "no rule cards")
	assert_false(RunState.banks(), "nothing banked")
	assert_eq(RunState.current_floor, Versus.STAGE_FLOOR)
	for key: String in ["traps", "circles", "extra_circles", "chests", "devil_awake"]:
		assert_eq(RunState.mod(key, 5.0), 0.0, key)
	assert_eq(RunState.mod("devil_speed", 1.0), 1.0, "everything else as it is")
	Versus.hard = false
	assert_eq(RunState.mod("minimap", 1.0), 1.0, "EASY: the map")
	assert_eq(RunState.mod("clock", 1.0), 1.0)
	Versus.hard = true
	assert_eq(RunState.mod("minimap", 1.0), 0.0, "HARD: no map")
	assert_true(RunState.mod("clock", 1.0) > 1.0, "and a little more time")
	RunState.leave_daily()
	assert_true(RunState.is_campaign(), "back to the campaign after")


func test_the_devils_legs() -> void:
	var runner := PlayerFeel.new()
	runner.walk_speed = 3.0
	var devil := Versus.devil_feel(runner)
	assert_eq(runner.walk_speed, 3.0, "the runner's own feel is untouched")
	assert_true(is_equal_approx(devil.walk_speed, 3.0 * Versus.DEVIL_WALK))
	assert_eq(devil.sprint_time, Versus.DEVIL_CHARGE_TIME)
	assert_eq(devil.sprint_recover_time, Versus.DEVIL_REST)
	var fastest := devil.walk_speed * devil.sprint_multiplier * Versus.devil_pace(true, true)
	assert_true(Versus.devil_top_speed(runner) > fastest, "the referee's cap leaves an honest Devil room")
	assert_true(Versus.devil_pace(false, false) < Versus.devil_pace(true, false), "slower in WAKE")


func test_the_other_player_is_drawn_a_little_behind() -> void:
	var track := Versus.Track.new()
	assert_true(track.sample(1.0).is_empty())
	track.push(1.0, Vector3.ZERO, 0.0, 2.0)
	track.push(1.1, Vector3(1, 0, 0), 0.2, 4.0)
	var mid := track.sample(1.15)  # drawn at 1.05: halfway
	assert_true((mid[0] as Vector3).is_equal_approx(Vector3(0.5, 0, 0)), str(mid[0]))
	assert_true(is_equal_approx(mid[1], 0.1))
	assert_true(is_equal_approx(mid[2], 3.0))
	assert_true((track.sample(0.5)[0] as Vector3).is_equal_approx(Vector3.ZERO), "before the first: the first")
	assert_true((track.sample(9.0)[0] as Vector3).is_equal_approx(Vector3(1, 0, 0)), "past the last: the last")
	assert_true(is_equal_approx(track.age(1.6), 0.5))
	for i in 20:
		track.push(2.0 + i, Vector3.ZERO, 0.0, 0.0)
	assert_eq(track.samples.size(), Versus.Track.KEEP)


func test_the_referee_plays_the_floor_with_the_other_players_devil() -> void:
	var main := _spawn_versus(true)
	assert_true(main.versus.runner)
	assert_eq(main.game_state, "waiting", "both floors first")
	assert_eq(main.traps.cells.size(), 0, "no traps")
	assert_eq(main.circles.cells.size(), 0, "no safe circles")
	assert_true(main.has_map, "EASY: the map")
	main.versus._take([Versus.READY, 1])
	assert_eq(main.game_state, "playing", "the Devil is in: GO")
	assert_true(main._hears(main.player_cell, 1 << 20), "it listens while it sleeps")
	main.elapsed = Versus.HEAD_START - 0.1
	main._tick_devil(0.016)
	assert_false(main.devil_active, "asleep through the head start")
	main.elapsed = Versus.HEAD_START
	main._tick_devil(0.016)
	assert_true(main.devil_active, "then it tears out of its wall")
	var home: Vector3 = main.cell_to_world(main.layout.devil_spawn) + Vector3(0, main.DEVIL_Y, 0)
	main.versus.devil_track.push(main.versus._now() - 1.0, home, 0.0, 0.0)
	for _i in 120:
		main._animate_devil(1.0 / 60.0)
	assert_true(main.devil.position.distance_to(home) < 0.1, "it goes where the other player's Devil is")
	main.versus.devil_track.clear()
	main.versus.devil_track.push(main.versus._now() - 1.0, home + Vector3(20, 0, 0), 0.0, 0.0)
	main._animate_devil(0.1)
	assert_true(main.devil.position.distance_to(home) <= Versus.devil_top_speed(main.feel) * 0.1 + 0.001,
			"a teleport goes no faster than its top speed")
	main.versus.devil_track.push(main.versus._now() - 1.0, home, 0.0, 0.0)
	main.versus.snapped()
	assert_true(main.versus.devil_track.samples.is_empty(), "a snap drops what it sent before it knew")
	main.versus._take([Versus.POS, 0, 1.0, 1.0, 0.0, 0.0])
	assert_true(main.versus.devil_track.samples.is_empty(), "a POS from before the snap is dropped")
	main.versus._take([Versus.POS, 1, 1.0, 1.0, 0.0, 0.0])
	assert_eq(main.versus.devil_track.samples.size(), 1, "one sent after it is taken")
	main._lose_game("devil")
	assert_true(main.versus.over, "caught: the round is over")
	assert_eq(Versus.results[0]["result"], Versus.Result.CAUGHT)
	assert_true(Versus.results[0]["host_ran"], "the room's maker ran")


func test_the_devils_machine_wears_the_runner_on_a_puppet() -> void:
	var runner_walk := (load("res://resources/player_feel.tres") as PlayerFeel).walk_speed
	var main := _spawn_versus(false, true)
	assert_false(main.versus.runner)
	assert_true(is_equal_approx(main.feel.walk_speed, runner_walk * Versus.DEVIL_WALK), "the Devil's legs")
	assert_eq(main.player_mesh.get_parent(), main.versus.puppet, "the runner's body is on the puppet")
	assert_false(main.has_map, "HARD: no map")
	assert_eq(main._box_in_reach(), -1, "the Devil opens no boxes")
	main.versus._take([Versus.GO, 1])
	assert_eq(main.game_state, "playing")
	assert_false(main.versus.lets_move(), "asleep through the head start")
	main.versus._event(Versus.Event.WAKE, 0.0, 0.0)
	assert_true(main.versus.lets_move(), "awake")
	main.versus._event(Versus.Event.FLIP, main.NIGHTMARE, 0.0)
	assert_eq(main.world, main.NIGHTMARE, "the flip lands")
	main.versus._event(Versus.Event.BOX, 0.0, 0.0)
	assert_true(main.box_opened[0], "the lid it opened is open here too")
	main.versus._event(Versus.Event.KEY, 0.0, 1.0)
	assert_eq(main.sigils_collected, 1, "the key count, never where it was")
	main.versus._event(Versus.Event.EXIT, 0.0, 0.0)
	assert_true(main.exit_open and main.versus.enraged, "every key: enraged")
	main.versus._event(Versus.Event.STUN, 0.6, 0.0)
	assert_false(main.versus.lets_move(), "a missed lunge stuns it")
	main.versus._take([Versus.SEEN, 5.0, 7.0, 0.0, 0.0, 0])
	main.versus._pose_puppet(0.016)
	assert_true(main.versus.puppet.visible, "seen: where the referee said")
	main.versus.runner_track.samples[-1][0] = main.versus._now() - 1.0
	main.versus._pose_puppet(0.016)
	assert_false(main.versus.puppet.visible, "unseen a moment: gone")
	main.versus._take([Versus.END, 1, Versus.Result.ESCAPED, 95.0])
	assert_true(main.versus.over)
	assert_true(Versus.results[0]["host_ran"], "the room's maker ran this round")


## A hidden browser tab stops the game loop, and the other game calls it gone: back past that, this player left the
## match, never playing on in a ghost of it that waits for a NEXT that can't come.
func test_a_game_that_stood_still_past_the_limit_left_the_match() -> void:
	var main := _spawn_versus(true)
	main.versus._take([Versus.READY, 1])
	assert_false(main.versus._stood_still(), "the first frame")
	main.versus._frame_at -= Versus.SILENT_LIMIT - Versus.PING_EVERY - 0.5
	assert_false(main.versus._stood_still(), "a slow frame is no leaving")
	main.versus._frame_at -= Versus.SILENT_LIMIT
	assert_true(main.versus._stood_still(), "a tab hidden past the limit")
	assert_true(main.versus.away and main.versus.over and main.versus.peer_gone, "the round is over here too")
	assert_eq(Versus.results[-1]["result"], Versus.Result.RUNNER_LEFT, "the runner left it")
	assert_eq(main.game_state, "lost", "the floor stops")


## Its floor loading counts: dealt (START), then the tab hidden while it loaded past the load limit.
func test_a_floor_that_loaded_past_the_limit_stood_still_too() -> void:
	var main := _spawn_versus(false)
	main.versus._frame_at = main.versus._now() - Versus.LOAD_LIMIT
	assert_true(main.versus._stood_still())
	assert_true(main.versus.away and main.versus.peer_gone and not main.versus.started, "out before the round began")
	assert_eq(main.versus._title(), "YOU WERE AWAY TOO LONG")


func _rounds(list: Array) -> Array[Dictionary]:
	var typed: Array[Dictionary] = []
	typed.assign(list)
	return typed


## A real versus floor for the runner (the room's maker, round 1) or the Devil (its friend): fixed seed, never the save.
func _spawn_versus(as_runner: bool, hard := false) -> Node3D:
	Versus.reset()
	Versus.host = as_runner
	Versus.hard = hard
	RunState.start_versus(42)
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	main.fixed_seed = 42
	(Engine.get_main_loop() as SceneTree).root.add_child(main)
	track(main)
	return main
