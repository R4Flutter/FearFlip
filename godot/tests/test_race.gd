extends McpTestSuite
## plans/11: the Long Night. One maze a week for everyone (CrazyGames' board season: Monday 09:00 UTC), the same kit,
## four keys, medals paced on the route that pay once a week, the week's best and its splits kept, the ghost on this
## device, and a race that never touches the campaign's save.

const PROFILE := "user://test_profile.cfg"
const SAVE := "user://test_run_state.cfg"
const GHOST := "user://test_race_ghost.bin"


func suite_name() -> String:
	return "race"


func setup() -> void:
	MetaState.profile_path = PROFILE
	RunState.save_path = SAVE
	Race.ghost_path = GHOST
	_fresh()


func teardown() -> void:
	if not RunState.is_campaign():
		RunState.leave_daily()
	MetaState.unlocked.clear()
	MetaState.equipped = {}
	Race.server = Race.SERVER
	Race.guest = false
	_fresh()
	RunState.start_run(1)


func _fresh() -> void:
	for path in [PROFILE, SAVE, GHOST]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_relaunch()


func _relaunch() -> void:
	MetaState._loaded = false
	RunState._loaded = false
	RunState.mode = "campaign"
	RunState.load_save()


func test_a_week_runs_monday_to_monday_at_nine_utc() -> void:
	var start := Time.get_unix_time_from_datetime_string(Race.FIRST_WEEK)
	assert_eq(Time.get_datetime_dict_from_unix_time(start)["weekday"], Time.WEEKDAY_MONDAY)
	assert_eq(Race.week_of(start), 1, "week 1 opens with the board's first season")
	assert_eq(Race.week_of(start + Race.WEEK_SECONDS - 1), 1, "a second before the next Monday 09:00")
	assert_eq(Race.week_of(start + Race.WEEK_SECONDS), 2, "the board resets and a new maze opens")
	assert_eq(Race.week_of(Time.get_unix_time_from_datetime_string("2026-10-19T09:00:00")), 2)
	assert_eq(Race.seconds_left(1, start + 3600), float(Race.WEEK_SECONDS - 3600))


func test_one_long_maze_a_week_for_everyone() -> void:
	assert_eq(Race.seed_of(3), Race.seed_of(3))
	assert_ne(Race.seed_of(3), Race.seed_of(4))
	assert_eq(Race.cards(3), Race.cards(3), "the same card all week")
	assert_eq(Race.cards(3).size(), 1, "one rule card")
	assert_eq(Cards.kind(Race.cards(3)[0]), "rule")
	var a := Race.layout(3)
	var b := Race.layout(3)
	assert_eq(a.spawn, b.spawn)
	assert_eq(a.exit, b.exit)
	assert_eq(a.sigils, b.sigils, "the keys hide in the same boxes for everyone")
	assert_eq(a.sigils.size(), roundi(Cards.fold(Race.cards(3), "keys", Race.KEYS)), "the long maze: four keys")
	assert_true(a.size >= 25, "a big maze")


## The par route goes through every key in the best order: never shorter than the farthest single detour, never longer
## than the keys in the order they're listed.
func test_the_par_route_takes_every_key_in_the_best_order() -> void:
	var maze := Race.layout(3)
	var at := func(from: Vector2i, to: Vector2i) -> int:
		return maze.distances(FloorLayout.ANY, from)[to.y * maze.size + to.x]
	var listed := 0
	var stop := maze.spawn
	var farthest := 0
	for key in maze.sigils:
		listed += at.call(stop, key)
		stop = key
		farthest = maxi(farthest, at.call(maze.spawn, key) + at.call(key, maze.exit))
	listed += at.call(stop, maze.exit)
	var tour := Race.tour_tiles(maze)
	assert_true(tour <= listed, "%d <= %d" % [tour, listed])
	assert_true(tour >= farthest, "%d >= %d" % [tour, farthest])
	assert_eq(Race.par(maze, 3.0), tour * Race.CELL_M / 3.0)


func test_medals_are_paced_on_the_route() -> void:
	var times := Race.medal_times(100.0)
	assert_true(times["devil"] < times["gold"] and times["gold"] < times["silver"], "each medal asks for more")
	assert_eq(Race.medal(times["devil"], 100.0), "devil")
	assert_eq(Race.medal(times["gold"], 100.0), "gold")
	assert_eq(Race.medal(times["gold"] + 0.1, 100.0), "silver")
	assert_eq(Race.medal(times["silver"] + 0.1, 100.0), "bronze", "any escape is bronze")


func test_each_medal_pays_once_a_week_and_the_best_is_kept() -> void:
	var times := Race.medal_times(100.0)
	var shards := MetaState.shards
	var first := Race.finish(5, times["silver"], [10.0, 20.0, 30.0, 40.0], 100.0)
	assert_true(first["best"])
	assert_eq(first["medal"], "silver")
	assert_eq(first["shards"], Race.MEDAL_SHARDS["bronze"] + Race.MEDAL_SHARDS["silver"], "every medal up to it")
	var slower := Race.finish(5, times["silver"] + 5.0, [11.0, 21.0, 31.0, 41.0], 100.0)
	assert_false(slower["best"])
	assert_eq(slower["shards"], 0, "a medal pays once a week")
	assert_eq(Race.best, times["silver"])
	assert_eq(Race.splits[3], 40.0, "the best run's splits")
	var gold := Race.finish(5, times["gold"], [9.0, 19.0, 29.0, 39.0], 100.0)
	assert_eq(gold["shards"], Race.MEDAL_SHARDS["gold"], "only the new medal pays")
	assert_eq(MetaState.shards, shards + Race.MEDAL_SHARDS["bronze"] + Race.MEDAL_SHARDS["silver"] + Race.MEDAL_SHARDS["gold"])
	assert_eq(Race.top_medal(), "gold")
	_relaunch()
	assert_eq(Race.best, times["gold"], "kept in the profile")
	assert_eq(Race.splits[0], 9.0)
	assert_eq(Race.medals.size(), 3)
	Race.refresh(6)
	assert_eq(Race.best, 0.0, "a new week starts clean")
	assert_true(Race.medals.is_empty() and Race.splits.is_empty())


func test_the_ghost_belongs_to_its_week() -> void:
	var samples := PackedFloat32Array([0.0, 0.0, 0.0, 2.4, 0.0, 0.0])
	Race.save_ghost(7, samples)
	assert_eq(Race.load_ghost(7), samples)
	assert_true(Race.load_ghost(8).is_empty(), "a new week has no ghost yet")
	assert_true(RaceGhost.due(0, 0.0), "the first sample at once")
	assert_false(RaceGhost.due(3, 0.1))
	assert_true(RaceGhost.due(3, RaceGhost.STEP))


func test_a_race_carries_the_same_kit_and_never_touches_the_campaign() -> void:
	RunState.start_run(1)
	RunState.current_floor = 3
	RunState.save()
	MetaState.unlocked.append("camera_flash")
	assert_true(MetaState.equip("camera_flash"))
	assert_eq(RunState.mod("flash_stun", 0.0), 1.0, "the campaign carries your torch")
	RunState.start_race()
	assert_true(RunState.is_race() and not RunState.is_daily() and not RunState.is_campaign())
	assert_false(RunState.banks(), "the same maze again would be a farm")
	assert_eq(RunState.mod("flash_stun", 0.0), 0.0, "the Altar's torches stay home: one kit on one board")
	assert_eq(RunState.race_week, Race.this_week())
	assert_eq(RunState.current_floor, Race.STAGE_FLOOR)
	assert_eq(RunState.floor_seed(), hash([Race.seed_of(RunState.race_week), Race.STAGE_FLOOR]))
	assert_eq(RunState.floor_cards, Race.cards(RunState.race_week))
	assert_eq(RunState.revives_left(), 0, "one life a run; RUN IT AGAIN instead")
	assert_false(RunState.has_sanctuary())
	RunState.end_run()
	RunState.leave_daily()
	assert_eq(RunState.current_floor, 3, "the campaign as its save left it")


# --- v2: the server (server/long-night) ----------------------------------------------------------------------------

func test_the_server_reads_the_run_the_way_the_game_sends_it() -> void:
	var body := Race.run_body("a.b.c", 3, 401.3456, [10.0, 20.5], PackedFloat32Array([1.0, 2.0, 0.5]), [5, 6, 40.1])
	assert_eq(body["tape"], "AACAPwAAAEAAAAA/", "base64 little-endian floats: server/long-night/test/checks.test.js pins the same")
	assert_eq(body["time_ms"], 401346)
	assert_eq(body["week"], 3)
	assert_eq(body["splits"], [10.0, 20.5])
	assert_eq(body["breach"], [5, 6, 40.1])
	assert_eq(Race.tape_of({"tape": body["tape"]}), PackedFloat32Array([1.0, 2.0, 0.5]), "a rival's tape comes back the same way")
	assert_true(Race.tape_of({"tape": "AACAPw=="}).is_empty(), "not whole samples")
	assert_true(Race.tape_of(null).is_empty())


func test_your_place_on_the_board_is_read_by_the_id_in_your_token() -> void:
	var payload := Marshalls.utf8_to_base64(JSON.stringify({"userId": "UOuZ-8_b", "username": "RustyCake.ZU9H"}))
	payload = payload.replace("+", "-").replace("/", "_").trim_suffix("=").trim_suffix("=")
	assert_eq(Race.player_of("eyJhbGciOiJSUzI1NiJ9.%s.c2ln" % payload), "UOuZ-8_b")
	assert_eq(Race.player_of(""), "", "a guest")
	assert_eq(Race.player_of("not a token"), "")


func test_whoever_took_your_place_is_named() -> void:
	var board: Dictionary = JSON.parse_string(JSON.stringify({"you": {"rank": 4, "ms": 401300},
			"top": [{"rank": 1, "name": "Ash", "ms": 390000}, {"rank": 2, "name": "Bo", "ms": 399000},
				{"rank": 3, "name": "Vex.QX", "ms": 400900}, {"rank": 4, "name": "", "ms": 401300, "me": true}],
			"around": [{"rank": 3, "name": "Vex.QX", "ms": 400900}, {"rank": 4, "name": "", "ms": 401300, "me": true}]}))
	assert_eq(Race.passed_line(board, 3), "VEX.QX TOOK YOUR 3RD PLACE BY 0.4 S")
	assert_eq(Race.passed_line(board, 4), "", "still where you were")
	assert_eq(Race.passed_line(board, 0), "", "first look this week")
	board["you"]["rank"] = 40.0
	assert_eq(Race.passed_line(board, 15), "25 RUNNERS PASSED YOU", "your old place is off the rows sent")
	board["you"]["rank"] = null
	assert_eq(Race.passed_line(board, 15), "", "past the ranks the server counts")
	for pair: Array in [[1, "1ST"], [2, "2ND"], [3, "3RD"], [4, "4TH"], [11, "11TH"], [12, "12TH"], [13, "13TH"],
			[21, "21ST"], [22, "22ND"], [101, "101ST"], [111, "111TH"]]:
		assert_eq(Race.ordinal(pair[0]), pair[1])


## A best goes to the server once: its answer (taken, or refused and why) is kept, a new best asks again, a new week
## starts clean.
func test_a_best_is_answered_for_once() -> void:
	Race.finish(5, 300.0, [100.0], 400.0, [3, 4, 50.0])
	assert_eq(Race.breach, [3, 4, 50.0], "where the Devil broke through goes with it")
	assert_eq(Race.board_note(), "Sending your time to the board...")
	Race.sent = 300000
	Race.refused = "too fast"
	Race.seen_rank = 7
	MetaState.save()
	_relaunch()
	assert_eq(Race.sent, 300000, "kept in the profile")
	assert_eq(Race.refused, "too fast")
	assert_eq(Race.seen_rank, 7)
	assert_true(Race.board_note().contains("too fast"), Race.board_note())
	Race.finish(5, 290.0, [90.0], 400.0)
	assert_eq(Race.refused, "", "a new best is a new question")
	assert_true(Race.breach.is_empty())
	assert_eq(Race.board_note(), "Sending your time to the board...")
	Race.sent = 290000
	assert_true(Race.board_note().begins_with("Verified"), Race.board_note())
	Race.guest = true
	assert_true(Race.board_note().begins_with("Log in"), Race.board_note())
	Race.refresh(6)
	assert_true(Race.sent == 0 and Race.seen_rank == 0 and Race.refused.is_empty() and Race.breach.is_empty())


func test_without_a_server_the_client_submits_as_before() -> void:
	Race.server = ""
	var called := [false]
	Race.sync(func(_board: Variant) -> void: called[0] = true)
	Race.fetch_rival(1, func(_rival: Variant) -> void: called[0] = true)
	assert_false(called[0], "no requests: v1's Portal.submit_time stands")


## The server checks each week's runs against what export_weeks.gd wrote from this game: the maze open in either world,
## its keys, and when each Flipping Time begins (the race's only flips: a stepped schedule within a frame of the
## frame-by-frame one). The committed export must still match the game, or honest runs are refused.
func test_the_server_holds_the_mazes_the_game_builds() -> void:
	var n := 3
	var maze := Race.layout(n)
	var week := Race.export_week(n)
	var open: String = week["open"]
	assert_eq(open.length(), maze.size * maze.size)
	for i in open.length():
		assert_eq(open[i] == "1", maze.is_open(FloorLayout.ANY, maze.cell_at(i)))
	assert_eq(week["spawn"], [maze.spawn.x, maze.spawn.y])
	assert_eq(week["exit"], [maze.exit.x, maze.exit.y])
	assert_eq(week["keys"].size(), maze.sigils.size())
	var flips: Array[float] = week["flips"]
	assert_gt(flips.size(), 20, "an hour of Flipping Times")
	var mod := func(key: String, base: float) -> float: return Cards.fold(Race.cards(n), key, base)
	var flip := FlipSystem.for_floor(Race.floor_seed(n), StageRule.for_floor(Race.STAGE_FLOOR), mod)
	var frame := 1.0 / 60.0
	var k := 0
	for step in roundi(600.0 / frame):
		var was := flip.forced_active
		flip.advance(frame, true, true)
		if flip.forced_active and not was:
			assert_true(absf((step + 1) * frame - flips[k]) <= (2 * k + 2) * frame, "flip %d: %f vs %f" % [k, (step + 1) * frame, flips[k]])
			k += 1
	assert_gt(k, 5)
	RunState.start_race()
	for key in ["flip_interval", "flip_duration"]:
		assert_eq(RunState.mod(key, 1.0), mod.call(key, 1.0), "the race folds the same card the export does: " + key)
	var path := ProjectSettings.globalize_path("res://").path_join("../server/long-night/src/weeks.json")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_true(data is Dictionary, "server/long-night/src/weeks.json: run export_weeks.gd")
	var now := str(Race.this_week())
	assert_true(data["weeks"].has(now), "the server must know this week's maze: run export_weeks.gd, then redeploy")
	var fresh := func(value: Variant) -> String: return JSON.stringify(JSON.parse_string(JSON.stringify(value)))
	assert_eq(JSON.stringify(data["weeks"][now]), fresh.call(Race.export_week(int(now))), "the maze code changed: re-export")
	assert_eq(JSON.stringify(data["rules"]), fresh.call(Race.server_rules()), "the pace or stamina changed: re-export")


func test_times_read_to_the_tenth() -> void:
	assert_eq(Race.format(401.3), "6:41.3")
	assert_eq(Race.format(59.96), "1:00.0")
	assert_eq(Race.format(5.04), "0:05.0")
	assert_eq(Race.share_text(3, 401.3, "gold"), "FearFlip · The Long Night #3 🥇 6:41.3")
