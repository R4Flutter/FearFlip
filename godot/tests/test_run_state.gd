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
	MetaState.stats = {}
	MetaState.ranks_open = 0
	MetaState.rank = 0
	MetaState.abyss_best = 0
	MetaState.save()
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


func test_a_later_act_owes_its_start_kit_and_curses_open_after_act_1() -> void:
	assert_eq(RunState.picks, [], "a first run just plays")
	MetaState.unlock_act(3)
	RunState.start_run(3)
	assert_eq(RunState.picks, ["curse", "omen", "omen"], "a curse offer, then one omen per act skipped")
	var curses := RunState.pick_options()
	assert_eq(curses[0], "no_curse")
	RunState.take(curses[1])
	assert_eq(RunState.run_cards, [curses[1]])
	assert_false(RunState.floor_cards.has(Cards.find(curses[1])["rule"]), "its twin rule card is never dealt too")
	var omens := RunState.pick_options()
	assert_eq(omens.size(), Cards.OMEN_CHOICES)
	RunState.take(omens[0])
	assert_false(RunState.pick_options().has(omens[0]), "an omen you hold is never offered again")
	RunState.take("")
	assert_eq(RunState.picks, [])
	assert_eq(RunState.run_cards.size(), 2, "passing takes nothing")
	assert_false(RunState.has_progress(), "still on the floor the run started on")


func test_declining_the_curse_keeps_the_run_clean() -> void:
	MetaState.unlock_act(2)
	RunState.start_run(1)
	RunState.take("no_curse")
	assert_eq(RunState.run_cards, [])


func test_omens_fold_into_every_floor_of_the_run() -> void:
	RunState.run_cards.assign(["quick_veil", "blood_pact"])
	RunState.advance_floor()
	assert_true(is_equal_approx(RunState.mod("flip_cooldown", 6.0), 4.2))
	assert_eq(RunState.mod("devil_speed", 1.0), 1.1)
	RunState.advance_floor()
	assert_eq(RunState.mod("shards", 1.0), Cards.fold(RunState.floor_cards, "shards", 1.0) * 1.5, "still there a floor later")


func test_a_shrine_or_the_sanctuary_owes_an_omen_before_the_door() -> void:
	RunState.advance_floor()
	assert_eq(RunState.picks, ["door"], "every floor after the first opens with a door")
	RunState.take("shrine")
	assert_eq(RunState.door, "shrine")
	RunState.advance_floor()
	assert_eq(RunState.picks, ["omen", "door"], "the Shrine pays its omen first")
	RunState.take("")
	RunState.take("normal")
	RunState.advance_floor()
	RunState.take("normal")
	RunState.advance_floor()
	assert_eq(RunState.picks, [], "no door into the Sanctuary")
	assert_eq(RunState.floor_cards, ["sanctuary"])
	RunState.advance_floor()
	assert_eq(RunState.picks, ["omen", "door"], "it sends you off with an omen")


func test_a_quit_at_a_picker_offers_the_same_choice_on_relaunch() -> void:
	MetaState.unlock_act(2)
	RunState.start_run(2)
	RunState.take("no_curse")
	RunState.take(RunState.pick_options()[0])
	RunState.advance_floor()
	RunState.take("shrine")
	RunState.advance_floor()
	var picks := RunState.picks.duplicate()
	var omens := RunState.pick_options()
	var held := RunState.run_cards.duplicate()
	RunState.take("")
	var doors := RunState.pick_options()
	RunState.picks.assign(picks)
	RunState.save()
	_relaunch()
	assert_eq(RunState.picks, picks)
	assert_eq(RunState.run_cards, held, "the omens survive too")
	assert_eq(RunState.pick_options(), omens, "the same omens")
	RunState.take("")
	assert_eq(RunState.pick_options(), doors, "the same doors (still no Shrine twice running)")
	assert_true(RunState.has_progress())


func test_a_gate_owes_return_or_descend() -> void:
	RunState.current_floor = StageRule.GATE_FLOOR
	RunState.clear_gate()
	assert_true(MetaState.is_act_unlocked(2), "the next act opens at once")
	assert_eq(RunState.picks, ["gate"])
	assert_eq(RunState.pick_options(), ["return", "descend"])
	assert_true(RunState.has_progress(), "a quit here comes back to the choice")
	RunState.take("return")
	assert_true(RunState.run_over)


func test_descending_keeps_the_omens_and_the_revives_used() -> void:
	RunState.run_cards.assign(["night_owl"])
	RunState.use_revive()
	RunState.current_floor = StageRule.GATE_FLOOR
	RunState.clear_gate()
	RunState.take("descend")
	assert_eq(RunState.current_floor, StageRule.act_start(2))
	assert_false(RunState.run_over)
	assert_eq(RunState.run_cards, ["night_owl", "descend"])
	assert_eq(RunState.revives_left(), RunState.REVIVES_PER_ACT - 1, "revives don't refill")
	assert_eq(RunState.picks, ["omen"], "the Gate's omen pick")
	assert_eq(Cards.fold(RunState.run_cards, "shards", 1.0), 1.5)
	assert_true(RunState.has_progress(), "an act's first floor, but deep into this run")


# --- plans/06 P8: the Abyss and the Nightmare Ranks ----------------------------------------------------

func test_the_last_gate_offers_the_abyss() -> void:
	MetaState.unlock_act(StageRule.ACT_COUNT)
	RunState.start_run(StageRule.ACT_COUNT)
	RunState.current_floor = StageRule.LAST_FLOOR
	RunState.master_act("A")
	RunState.clear_gate()
	assert_true(MetaState.abyss_open(), "floor 50 has fallen")
	assert_eq(RunState.pick_options(), ["return", "descend"])
	RunState.take("descend")
	assert_eq(RunState.current_floor, StageRule.LAST_FLOOR + 1, "down into the Abyss")
	assert_eq(RunState.act(), StageRule.ABYSS_ACT)
	assert_eq(MetaState.acts_unlocked, StageRule.ACT_COUNT, "still five acts")
	assert_false(RunState.run_over)
	_relaunch()
	assert_eq(RunState.current_floor, StageRule.LAST_FLOOR + 1, "the Abyss survives a relaunch")


func test_the_abyss_opens_with_floor_50() -> void:
	MetaState.unlock_act(StageRule.ACT_COUNT)
	assert_false(RunState.start_run(StageRule.ABYSS_ACT), "locked until floor 50 falls")
	MetaState.record({"clears_act_%d" % StageRule.ACT_COUNT: 1})
	assert_true(RunState.start_run(StageRule.ABYSS_ACT))
	assert_eq(RunState.current_floor, StageRule.LAST_FLOOR + 1)
	assert_eq(RunState.picks.count("omen"), StageRule.ACT_COUNT, "the start kit: an omen for every act above it")


func test_the_deepest_floor_cleared_is_the_depth_score() -> void:
	MetaState.unlock_act(StageRule.ACT_COUNT)
	MetaState.record({"clears_act_%d" % StageRule.ACT_COUNT: 1})
	RunState.start_run(StageRule.ABYSS_ACT)
	RunState.note_floor("A", false)
	assert_eq(MetaState.abyss_best, 1, "depth 1 cleared")
	for i in 3:
		RunState.advance_floor()
	RunState.note_floor("B", false)
	assert_eq(MetaState.abyss_best, 4)
	RunState.start_run(StageRule.ABYSS_ACT)
	RunState.note_floor("S", false)
	assert_eq(MetaState.abyss_best, 4, "a shallower run never lowers it")
	RunState.start_run(1)
	RunState.note_floor("S", false)
	assert_eq(MetaState.abyss_best, 4, "campaign floors are no depth")


func test_ranks_open_with_floor_50_and_climb_one_gate_at_a_time() -> void:
	MetaState.rank = 3
	RunState.start_run(1)
	assert_eq(RunState.rank, 0, "no rank before floor 50 falls")
	MetaState.unlock_act(StageRule.ACT_COUNT)
	RunState.start_run(StageRule.ACT_COUNT)
	RunState.current_floor = StageRule.LAST_FLOOR
	var news := RunState.master_act("A")
	assert_eq(MetaState.ranks_open, 1)
	assert_true(news.has("NIGHTMARE RANK 1 OPEN"), str(news))
	MetaState.rank = 1
	RunState.start_run(1)
	assert_eq(RunState.rank, 1)
	RunState.current_floor = StageRule.GATE_FLOOR
	assert_true(RunState.master_act("B").has("NIGHTMARE RANK 2 OPEN"))
	assert_eq(MetaState.ranks_open, 2, "a Gate at your top rank opens the next")
	RunState.start_run(1)
	RunState.current_floor = StageRule.GATE_FLOOR
	RunState.master_act("B")
	assert_eq(MetaState.ranks_open, 2, "a Gate below your top rank opens nothing")
	MetaState.ranks_open = Cards.MAX_RANK
	MetaState.rank = Cards.MAX_RANK
	RunState.start_run(1)
	RunState.current_floor = StageRule.GATE_FLOOR
	RunState.master_act("B")
	assert_eq(MetaState.ranks_open, Cards.MAX_RANK, "twenty is the top")


func test_a_rank_folds_into_every_floor_but_never_the_daily() -> void:
	MetaState.ranks_open = Cards.MAX_RANK
	MetaState.rank = 5
	RunState.start_run(1)
	assert_eq(RunState.rank, 5)
	assert_eq(RunState.mod("shards", 1.0), Cards.fold(Cards.ranks(5), "shards", 1.0), "floor 1 holds nothing but the rank")
	_relaunch()
	assert_eq(RunState.rank, 5, "a run keeps its rank through a relaunch")
	MetaState.rank = 0
	assert_eq(RunState.rank, 5, "the picker never changes a run in progress")
	RunState.start_daily(true)
	assert_eq(RunState.rank, 0, "the Daily is the same maze for everyone")
	RunState.leave_daily()
	assert_eq(RunState.rank, 5, "back to the campaign run")


## Forget everything in memory and read it back, as a new process would.
func _relaunch() -> void:
	RunState._loaded = false
	MetaState._loaded = false
	RunState.current_floor = 1
	RunState.run_seed = 0
	RunState.floor_cards.clear()
	RunState.door = ""
	RunState.last_door = ""
	RunState._cleared_cards.clear()
	RunState.run_cards.clear()
	RunState.picks.clear()
	RunState.start_floor = 1
	MetaState.acts_unlocked = 1
	RunState.load_save()
