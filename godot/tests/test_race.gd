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


func test_times_read_to_the_tenth() -> void:
	assert_eq(Race.format(401.3), "6:41.3")
	assert_eq(Race.format(59.96), "1:00.0")
	assert_eq(Race.format(5.04), "0:05.0")
	assert_eq(Race.share_text(3, 401.3, "gold"), "FearFlip · The Long Night #3 🥇 6:41.3")
