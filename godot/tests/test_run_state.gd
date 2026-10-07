extends McpTestSuite
## plans/06 P1: one run = one act. Beating the Gate opens the next act and ends the run; death ends it
## too and a revive brings it back; the save survives a relaunch, and an old 100-floor save starts fresh.

const SAVE := "user://test_run_state.cfg"
const PROFILE := "user://test_profile.cfg"


func suite_name() -> String:
	return "run_state"


func setup() -> void:
	RunState.save_path = SAVE
	MetaState.profile_path = PROFILE
	RunState._loaded = true
	MetaState._loaded = true
	MetaState.acts_unlocked = 1
	RunState.best_floor = 1
	RunState.start_run(1)


func teardown() -> void:
	MetaState.acts_unlocked = 1
	RunState.start_run(1)
	RunState.best_floor = 1


func test_locked_act_cannot_start() -> void:
	assert_false(RunState.start_run(2), "Act 2 is locked")
	assert_eq(RunState.current_floor, 1)
	assert_false(RunState.start_run(0))


func test_gate_opens_the_next_act_and_ends_the_run() -> void:
	RunState.current_floor = StageRule.act_start(1) + StageRule.GATE_FLOOR - 1
	RunState.clear_act()
	assert_true(MetaState.is_act_unlocked(2))
	assert_false(MetaState.is_act_unlocked(3))
	assert_true(RunState.run_over)
	assert_false(RunState.has_progress())
	assert_true(RunState.start_run(2))
	assert_eq(RunState.current_floor, StageRule.act_start(2))
	assert_eq(RunState.act(), 2)
	assert_eq(RunState.best_floor, StageRule.act_start(2), "reaching an act counts as a floor reached")


func test_last_gate_keeps_the_act_count() -> void:
	MetaState.unlock_act(StageRule.ACT_COUNT)
	RunState.start_run(StageRule.ACT_COUNT)
	RunState.current_floor = StageRule.LAST_FLOOR
	RunState.clear_act()
	assert_eq(MetaState.acts_unlocked, StageRule.ACT_COUNT)


func test_death_ends_the_run_and_a_revive_resumes_it() -> void:
	assert_false(RunState.has_progress(), "a fresh run sits on its act's first floor")
	RunState.advance_floor()
	assert_true(RunState.has_progress())
	RunState.end_run()
	assert_false(RunState.has_progress(), "dead: nothing to continue")
	assert_true(RunState.use_revive())
	assert_true(RunState.has_progress(), "revived: the run goes on")


func test_revives_cap_per_act_and_refill_on_a_new_run() -> void:
	for _i in RunState.REVIVES_PER_ACT:
		assert_true(RunState.use_revive())
	assert_false(RunState.use_revive(), "max 3 per act")
	RunState.advance_floor()
	assert_eq(RunState.revives_left(), 0, "the next floor doesn't refill them")
	RunState.start_run(1)
	assert_eq(RunState.revives_left(), RunState.REVIVES_PER_ACT)


func test_each_run_is_a_new_maze() -> void:
	var first := RunState.floor_seed()
	RunState.start_run(1)
	assert_ne(RunState.floor_seed(), first)


func test_save_survives_a_relaunch() -> void:
	MetaState.unlock_act(3)
	RunState.start_run(3)
	RunState.advance_floor()
	var floor_number := RunState.current_floor
	var seed_value := RunState.run_seed
	_relaunch()
	assert_eq(RunState.current_floor, floor_number)
	assert_eq(RunState.run_seed, seed_value)
	assert_eq(MetaState.acts_unlocked, 3)
	assert_true(RunState.has_progress())


func test_old_saves_start_a_fresh_run() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("run", "floor", 37)
	cfg.set_value("run", "seed", 99)
	cfg.save(SAVE)
	_relaunch()
	assert_eq(RunState.current_floor, 1)
	assert_ne(RunState.run_seed, 99)


func test_mod_folds_this_floors_cards() -> void:
	RunState.floor_cards.assign(["thick_fog", "hunt"])
	assert_eq(RunState.mod("fog", 1.0), 1.8)
	assert_eq(RunState.mod("shards", 1.0), 2.0)
	assert_eq(RunState.mod("keys", 2.0), 2.0, "no card here touches the keys")


func test_each_floor_is_dealt_its_cards() -> void:
	assert_eq(RunState.floor_cards, [], "the game opens on the core loop")
	RunState.advance_floor()
	assert_eq(RunState.floor_cards.size(), 1, "floor 2 through the normal door: one rule card")
	for _i in StageRule.SANCTUARY_FLOOR - 2:
		RunState.advance_floor()
	assert_eq(RunState.floor_cards, ["sanctuary"])


func test_a_door_redeals_the_floor_and_survives_a_relaunch() -> void:
	MetaState.unlock_act(2)
	RunState.start_run(2)
	RunState.advance_floor()
	var cleared := RunState.floor_cards.duplicate()
	RunState.advance_floor()
	RunState.choose_door("hunt")
	assert_eq(RunState.door, "hunt")
	assert_eq(RunState.floor_cards[0], "hunt")
	assert_eq(RunState.floor_cards.size(), 3, "Hunt: two rule cards")
	for id in cleared:
		assert_false(RunState.floor_cards.has(id), "%s was on the floor before" % id)
	var dealt := RunState.floor_cards.duplicate()
	_relaunch()
	assert_eq(RunState.floor_cards, dealt, "a relaunch replays the same cards")
	assert_eq(RunState.door, "hunt")


func test_the_door_taken_is_remembered_for_the_next_choice() -> void:
	RunState.advance_floor()
	RunState.choose_door("mystery")
	var resolved := RunState.door
	assert_eq(resolved, RunState.floor_cards[1], "a Mystery keeps the door it turned out to be")
	RunState.advance_floor()
	assert_eq(RunState.last_door, resolved)
	RunState.choose_door("shrine")
	RunState.advance_floor()
	assert_eq(RunState.last_door, "shrine", "the next doors know a Shrine came last")


## Forget everything in memory and read it back, as a new process would.
func _relaunch() -> void:
	RunState._loaded = false
	MetaState._loaded = false
	RunState.current_floor = 1
	RunState.run_seed = 0
	RunState.floor_cards.clear()
	RunState.door = ""
	MetaState.acts_unlocked = 1
	RunState.load_save()
