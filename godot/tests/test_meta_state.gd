extends McpTestSuite
## plans/06 P2: Fear Shards. What pays, chest rolls from the floor seed, the unlock bar, and the profile
## keeping every banked shard through death and relaunch.

const PROFILE := "user://test_profile.cfg"
const SAVE := "user://test_run_state.cfg"


func suite_name() -> String:
	return "meta_state"


func setup() -> void:
	MetaState.profile_path = PROFILE
	RunState.save_path = SAVE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE))
	_relaunch()


func teardown() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE))
	_relaunch()
	RunState.start_run(1)


func test_a_new_profile_starts_the_unlock_bar_part_full() -> void:
	MetaState.shards = 999
	_relaunch()
	assert_eq(MetaState.shards, MetaState.STARTER_SHARDS, "no profile file = a new profile")
	assert_true(absf(MetaState.unlock_progress() - 0.2) < 0.001, "the bar starts 20%% full: %f" % MetaState.unlock_progress())


func test_deeper_floors_and_better_grades_pay_more() -> void:
	assert_eq(MetaState.floor_clear_shards(1, "C"), 12, "10 + 2 x floor 1")
	assert_eq(MetaState.floor_clear_shards(10, "B"), 30, "the Gate: 10 + 2 x 10")
	assert_eq(MetaState.floor_clear_shards(3, "A") - MetaState.floor_clear_shards(3, "B"), 5)
	assert_eq(MetaState.floor_clear_shards(3, "S") - MetaState.floor_clear_shards(3, "B"), 10)
	assert_eq(MetaState.floor_clear_shards(3, "C"), MetaState.floor_clear_shards(3, "B"))
	assert_eq(MetaState.act_clear_shards(2), 100, "50 x the act")


func test_a_typical_floor_pays_25_to_40() -> void:
	var chest := _average_chest()
	for floor_in_act in range(1, 6):
		for grade: String in ["A", "B"]:
			var pay := FloorLayout.SIGIL_COUNT * MetaState.SIGIL_SHARDS + chest + MetaState.floor_clear_shards(floor_in_act, grade)
			assert_true(pay >= 25.0 and pay <= 40.0, "floor %d, grade %s pays %.1f" % [floor_in_act, grade, pay])


func test_chest_rolls_repeat_for_the_same_seed() -> void:
	var kinds := {}
	for seed_value in 60:
		var roll := MetaState.chest_roll(seed_value)
		assert_eq(roll, MetaState.chest_roll(seed_value), "seed %d" % seed_value)
		kinds[roll["kind"]] = true
	assert_gt(kinds.size(), 2, "different floors roll different chests")


func test_chest_odds_follow_the_table() -> void:
	const ROLLS := 4000
	var counts := {}
	for i in ROLLS:
		var roll := MetaState.chest_roll(i * 7919 + 1)
		var kind: String = roll["kind"]
		counts[kind] = counts.get(kind, 0) + 1
		var pay: int = roll["shards"]
		if kind == "shards":
			assert_true(pay >= MetaState.CHEST_SHARDS.x and pay <= MetaState.CHEST_SHARDS.y, "shards chest pays %d" % pay)
		elif kind == "rare":
			assert_eq(pay, MetaState.RARE_SHARDS)
		else:
			assert_eq(pay, 0, "%s chests hold a find, not shards" % kind)
	for odds: Array in MetaState.CHEST_ODDS:
		var share := float(counts.get(odds[0], 0)) / ROLLS
		assert_true(absf(share - odds[1]) < 0.03, "%s: %.3f, table says %.2f" % [odds[0], share, odds[1]])


func test_a_losing_first_run_earns_about_one_unlock() -> void:
	# Clears F1 and F2 with B grades and average chests, then dies on F3 holding one key.
	var run := float(MetaState.STARTER_SHARDS + MetaState.SIGIL_SHARDS)
	for floor_in_act in [1, 2]:
		run += FloorLayout.SIGIL_COUNT * MetaState.SIGIL_SHARDS + _average_chest() + MetaState.floor_clear_shards(floor_in_act, "B")
	assert_true(run >= MetaState.FIRST_UNLOCK_COST, "%.1f of %d" % [run, MetaState.FIRST_UNLOCK_COST])


func test_banked_shards_survive_death_and_relaunch() -> void:
	RunState.start_run(1)
	RunState.bank(25)
	RunState.end_run()
	MetaState.keep_find("omen")
	MetaState.keep_find("note")
	_relaunch()
	assert_eq(MetaState.shards, MetaState.STARTER_SHARDS + 25, "dying keeps every shard")
	assert_eq(MetaState.omen_tokens, 1)
	assert_eq(MetaState.notes_found, 1)
	assert_eq(RunState.run_shards, 25, "the run's total survives a relaunch")
	RunState.start_run(1)
	assert_eq(RunState.run_shards, 0, "a new run counts from zero")
	assert_eq(MetaState.shards, MetaState.STARTER_SHARDS + 25, "the profile keeps them")


func _average_chest() -> float:
	var total := 0
	for seed_value in 1000:
		total += MetaState.chest_roll(seed_value)["shards"]
	return total / 1000.0


## Forget everything in memory and read it back, as a new process would.
func _relaunch() -> void:
	MetaState._loaded = false
	RunState._loaded = false
	RunState.run_shards = 0
	RunState.load_save()
