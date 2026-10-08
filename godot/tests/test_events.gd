extends McpTestSuite
## plans/06 P0: the playtest log behind the §7 KPIs. One JSON line per session, run, floor clear, death, run end,
## pick (with what was offered), Altar unlock and shared result, in user://events.jsonl. Tests never write the real one.

const PROFILE := "user://test_profile.cfg"
const SAVE := "user://test_run_state.cfg"
const EVENTS := "user://test_events.jsonl"

## Read as the suite is built, before any setup() turns the log on for a test.
var _logging_by_default: bool = RunState.log_events


func suite_name() -> String:
	return "events"


func setup() -> void:
	MetaState.profile_path = PROFILE
	RunState.save_path = SAVE
	RunState.events_path = EVENTS
	for path in [PROFILE, SAVE, EVENTS]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	RunState.log_events = true
	RunState._session = 0  # a fresh launch
	MetaState._loaded = false
	RunState._loaded = false
	RunState.load_save()


func teardown() -> void:
	RunState.log_events = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(EVENTS))


## Every line of the test log, parsed.
func _events() -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	var file := FileAccess.open(EVENTS, FileAccess.READ)
	if file == null:
		return lines
	while not file.eof_reached():
		var line := file.get_line()
		if not line.is_empty():
			lines.append(JSON.parse_string(line))
	return lines


func _last(kind: String) -> Dictionary:
	var found := {}
	for event in _events():
		if event["e"] == kind:
			found = event
	return found


func test_the_test_runner_never_writes_the_playtest_log() -> void:
	assert_false(_logging_by_default, "only the game itself logs; tests turn it on with their own path")


func test_an_event_is_one_json_line_with_its_time_and_session() -> void:
	RunState.log_event("probe", {"value": 7})
	RunState.log_event("probe", {"value": 8})
	var probes := _events().filter(func(event: Dictionary) -> bool: return event["e"] == "probe")
	assert_eq(probes.size(), 2, "appended, never rewritten")
	assert_eq(probes[1]["value"], 8.0)
	assert_true(probes[1]["t"] >= probes[0]["t"] and probes[0]["t"] > 1.7e9, "unix seconds")
	assert_eq(probes[0]["s"], _last("session")["s"], "every line carries its session")


func test_a_session_starts_once_per_launch() -> void:
	var session := _last("session")
	assert_false(session.is_empty(), "the first load of a launch")
	RunState.load_save()
	assert_eq(_events().filter(func(event: Dictionary) -> bool: return event["e"] == "session").size(), 1)


func test_a_fresh_profiles_first_run_counts_only_once_played() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	RunState._loaded = false
	RunState.run_seed = 0  # a new process: no run in memory, none saved
	RunState.load_save()
	assert_eq(_events().filter(func(event: Dictionary) -> bool: return event["e"] == "run").size(), 0,
			"the run a new profile is handed at load is nobody's run yet")
	RunState.start_run(1)
	assert_eq(_events().filter(func(event: Dictionary) -> bool: return event["e"] == "run").size(), 1)


func test_runs_picks_and_run_ends_are_logged() -> void:
	RunState.start_run(1)
	assert_eq(_last("run").get("act"), 1.0)
	assert_eq(_last("run").get("mode"), "campaign")
	RunState.picks.assign(["omen"])
	var offered := RunState.pick_options()
	RunState.take(offered[1])
	var pick := _last("pick")
	assert_eq(pick.get("kind"), "omen")
	assert_eq(pick.get("id"), offered[1])
	assert_eq(pick.get("offered"), offered, "what was offered: the pick-rate KPI needs both")
	RunState.end_run()
	assert_eq(_last("run_end").get("floor"), 1.0)


func test_an_altar_unlock_is_logged() -> void:
	MetaState.shards = 9999
	var id := MetaState.next_unlock()
	assert_true(MetaState.buy(id))
	assert_eq(_last("unlock").get("id"), id)


func test_a_copied_result_is_logged() -> void:
	Daily.copy("FearFlip Daily #1")
	assert_eq(_last("share").get("text"), "FearFlip Daily #1", "the share-rate KPI")


func test_a_floor_clear_and_a_death_are_logged() -> void:
	RunState.start_run(1)
	var cleared: Node3D = load("res://scenes/main.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(cleared)
	track(cleared)
	cleared.elapsed = 61.0
	cleared._win_game()
	var floor_event := _last("floor")
	assert_eq(floor_event.get("floor"), 1.0)
	assert_eq(floor_event.get("act"), 1.0)
	assert_eq(floor_event.get("time"), 61.0)
	assert_true("SABC".contains(floor_event.get("grade", "?")))
	RunState.picks.clear()  # the door owed into floor 2
	var died: Node3D = load("res://scenes/main.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(died)
	track(died)
	died.elapsed = 12.0
	died._lose_game("trap")
	var death := _last("death")
	assert_eq(death.get("cause"), "trap")
	assert_eq(death.get("floor"), 2.0, "the floor after the one cleared")
	assert_eq(death.get("time"), 12.0)
	assert_eq(_last("run_end").get("floor"), 2.0, "dying ends the run")
