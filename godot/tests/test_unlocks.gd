extends McpTestSuite
## plans/06 P5: the meta hub. The Altar (costs, what must come first, the omen pool, gear and omen slots),
## challenges and act stars banked from stat counters, and the profile keeping all of it through a relaunch.

const PROFILE := "user://test_profile.cfg"
const SAVE := "user://test_run_state.cfg"


func suite_name() -> String:
	return "unlocks"


func setup() -> void:
	MetaState.profile_path = PROFILE
	RunState.save_path = SAVE
	_fresh_profile()


func teardown() -> void:
	_fresh_profile()
	RunState.start_run(1)


func test_every_altar_item_is_a_real_option() -> void:
	var defaults := {}
	var cheapest := 9999
	for entry: Dictionary in Unlocks.ALTAR:
		var id: String = entry["id"]
		var item := Unlocks.item(id)
		assert_true(Unlocks.KINDS.has(item["kind"]), id)
		assert_false(String(item.get("name", "")).is_empty(), "%s has a name" % id)
		assert_false(String(item.get("text", "")).is_empty(), "%s says what it does" % id)
		if item["cost"] == 0:
			assert_true(Unlocks.EQUIP_KINDS.has(item["kind"]), "%s: only gear you start with is free" % id)
			assert_false(defaults.has(item["kind"]), "one default %s" % item["kind"])
			defaults[item["kind"]] = id
		else:
			cheapest = mini(cheapest, item["cost"])
		if item.has("after"):
			var before := Unlocks.item(item["after"])
			assert_eq(before.get("kind"), item["kind"], "%s comes after an item of its own kind" % id)
			assert_gt(item["cost"], before["cost"], "%s costs more than what it comes after" % id)
		match item["kind"]:
			"omen":
				assert_eq(Cards.kind(id), "omen", id)
				assert_false(Cards.find(id).has("needs"), "%s works today" % id)
				assert_false(Cards.omen_pool(0).has(id), "%s isn't a starter" % id)
			"torch":
				assert_eq(Cards.kind(id), "torch", id)
	assert_eq(defaults.keys().size(), Unlocks.EQUIP_KINDS.size(), "every kind of gear has a default")
	assert_eq(cheapest, MetaState.FIRST_UNLOCK_COST, "the first unlock costs about one run")


func test_buying_needs_the_shards_and_what_comes_first() -> void:
	MetaState.shards = MetaState.FIRST_UNLOCK_COST - 1
	assert_eq(MetaState.next_unlock(), "twin_flip")
	assert_false(MetaState.buy("twin_flip"), "one shard short")
	MetaState.shards += 1
	assert_true(MetaState.buy("twin_flip"))
	assert_eq(MetaState.shards, 0, "it costs what it says")
	assert_true(MetaState.owns("twin_flip"))
	MetaState.shards = 999
	assert_false(MetaState.buy("twin_flip"), "owned already")
	assert_false(MetaState.buy("uv_light"), "the Lantern comes first")
	assert_true(MetaState.buy("lantern"))
	assert_true(MetaState.buy("uv_light"))
	assert_false(MetaState.buy("no_such_thing"))
	assert_eq(MetaState.shards, 999 - Unlocks.item("lantern")["cost"] - Unlocks.item("uv_light")["cost"])


func test_tokens_and_purchases_share_the_omen_pool() -> void:
	assert_eq(MetaState.omen_pool(), Cards.omen_pool(0), "a new profile has the starters")
	MetaState.shards = 999
	assert_true(MetaState.buy("cartographer"))
	assert_true(MetaState.omen_pool().has("cartographer"), "bought omens join the pool")
	MetaState.keep_find("omen")
	assert_true(MetaState.owns("twin_flip"), "a token adds the first omen you don't own")
	assert_false(MetaState.buy("twin_flip"), "a token's omen is never sold to you again")
	MetaState.keep_find("omen")
	assert_true(MetaState.owns("feather_step"))
	assert_false(MetaState.owns("locksmith"), "cartographer was bought: the token skipped it")
	assert_eq(MetaState.omen_pool().size(), Cards.STARTER_OMENS + 3)


func test_gear_needs_owning_and_folds_into_every_floor() -> void:
	assert_eq(MetaState.wearing("torch"), "old_torch")
	assert_eq(MetaState.wearing("light"), "cold_light")
	assert_false(MetaState.equip("lantern"), "not owned")
	MetaState.shards = 999
	MetaState.buy("lantern")
	MetaState.buy("ember_light")
	assert_true(MetaState.equip("lantern"))
	assert_true(MetaState.equip("ember_light"))
	assert_eq(MetaState.gear(), ["lantern"])
	assert_eq(RunState.mod("beam_angle", 1.0), Cards.find("lantern")["mods"]["beam_angle"], "the torch is folded like a card")
	assert_eq(MetaState.light_color(), Unlocks.item("ember_light")["color"])
	MetaState.buy("twin_flip")
	assert_false(MetaState.equip("twin_flip"), "omens are picked in a run, not worn")
	assert_true(MetaState.equip("old_torch"), "the default is always yours")
	assert_eq(RunState.mod("beam_angle", 1.0), 1.0)


func test_omen_slots_open_every_run_with_omen_picks() -> void:
	RunState.start_run(1)
	assert_eq(RunState.picks, [], "a new profile just plays")
	MetaState.shards = 999
	MetaState.buy("slot_1")
	RunState.start_run(1)
	assert_eq(RunState.picks, ["omen"])
	MetaState.buy("slot_2")
	RunState.start_run(1)
	assert_eq(RunState.picks, ["omen", "omen"])


func test_next_unlock_fills_the_bar() -> void:
	assert_true(absf(MetaState.unlock_progress() - 0.2) < 0.001, "a new profile starts 20%% of the way")
	MetaState.shards = 99999
	while MetaState.buy(MetaState.next_unlock()):
		pass
	assert_eq(MetaState.next_unlock(), "", "everything owned")
	for entry: Dictionary in Unlocks.ALTAR:
		assert_true(MetaState.owns(entry["id"]), entry["id"])
	assert_eq(MetaState.unlock_progress(), 1.0)


## The plans/06 P5 gate, for a player who dies on floor 3 every run (P2's losing first run) and spends at the
## Altar whenever they can: for the first 15 runs the next unlock is never more than 2 runs away.
func test_something_is_always_unlockable_within_two_runs() -> void:
	var income := MetaState.SIGIL_SHARDS + 0.0
	for floor_in_act in [1, 2]:
		income += FloorLayout.SIGIL_COUNT * MetaState.SIGIL_SHARDS + _average_chest() + MetaState.floor_clear_shards(floor_in_act, "B")
	for run in 15:
		var next := MetaState.next_unlock()
		assert_ne(next, "", "run %d: the Altar ran dry" % run)
		var cost: int = Unlocks.item(next)["cost"]
		assert_true(cost - MetaState.shards <= 2.0 * income, "run %d: %s costs %d, %d banked, a run pays %.0f" % [run + 1, next, cost, MetaState.shards, income])
		MetaState.shards += roundi(income)
		while MetaState.buy(MetaState.next_unlock()):
			pass


func test_the_profile_keeps_the_hub_through_a_relaunch() -> void:
	MetaState.shards = 999
	MetaState.buy("lantern")
	MetaState.equip("lantern")
	MetaState.keep_find("omen")
	_relaunch()
	assert_true(MetaState.owns("lantern"))
	assert_eq(MetaState.wearing("torch"), "lantern")
	assert_true(MetaState.owns("twin_flip"), "the token's omen")
	assert_eq(MetaState.shards, 999 - Unlocks.item("lantern")["cost"])


func test_the_senses_omens_are_sold_and_won() -> void:
	for id: String in ["lantern_heart", "echo_step", "soft_soles"]:
		assert_eq(Unlocks.item(id).get("kind"), "omen", "%s at the Altar" % id)
	assert_eq(Unlocks.challenge("soft_steps")["item"], "soft_soles", "clear Act 1 without sprinting: Soft Soles")
	assert_eq(Unlocks.challenge("phase_walker")["item"], "echo_step", "10 Phase Dodges: Echo Step")


func test_every_challenge_is_well_formed() -> void:
	var ids := {}
	for challenge: Dictionary in Unlocks.CHALLENGES:
		var id: String = challenge["id"]
		assert_false(ids.has(id), "%s is unique" % id)
		ids[id] = true
		assert_false(String(challenge["name"]).is_empty() or String(challenge["text"]).is_empty(), id)
		assert_gt(challenge["goal"], 0, id)
		assert_true(challenge.has("shards") or challenge.has("item"), "%s pays something" % id)
		if challenge.has("item"):
			assert_false(Unlocks.item(challenge["item"]).is_empty(), "%s pays an Altar item" % id)
	assert_true(ids.size() >= 35 and ids.size() <= 45, "about 40 challenges: %d" % ids.size())


func test_a_challenge_pays_once_when_its_counter_crosses_the_goal() -> void:
	var challenge := Unlocks.challenge("finders_keepers")
	var goal: int = challenge["goal"]
	MetaState.record({"chests": goal - 1})
	var shards := MetaState.shards
	assert_eq(MetaState.record({"chests": 1}), ["CHALLENGE  ·  " + challenge["name"]])
	assert_eq(MetaState.shards, shards + challenge["shards"])
	assert_eq(MetaState.record({"chests": 1}), [], "paid once")
	assert_eq(MetaState.stat("chests"), goal + 1)
	assert_eq(MetaState.stat("never_counted"), 0)


func test_a_challenge_item_is_given_or_paid_out_if_you_own_it() -> void:
	var challenge := Unlocks.challenge("chest_hunter")
	var item: String = challenge["item"]
	MetaState.record({"chests": challenge["goal"] - 1})
	assert_false(MetaState.owns(item))
	MetaState.record({"chests": 1})
	assert_true(MetaState.owns(item), "won, not bought")
	_fresh_profile()
	MetaState.shards = 999
	MetaState.buy(item)
	MetaState.record({"chests": challenge["goal"] - 1})
	var shards := MetaState.shards
	MetaState.record({"chests": 1})
	assert_eq(MetaState.shards, shards + Unlocks.item(item)["cost"], "already yours: its price instead")


func test_a_first_bestiary_sighting_pays_once() -> void:
	var shards := MetaState.shards
	var news := MetaState.record({"devil_wakes": 1})
	assert_true(news.has("BESTIARY  ·  THE DEVIL"), str(news))
	assert_eq(MetaState.shards, shards + MetaState.BESTIARY_SHARDS)
	assert_eq(MetaState.record({"devil_wakes": 1}), [], "seen already")
	assert_eq(MetaState.shards, shards + MetaState.BESTIARY_SHARDS)


func test_act_stars_need_no_revive_an_s_average_and_a_curse() -> void:
	RunState.start_run(1)
	for i in 9:
		RunState.note_floor("S", false)
	RunState.note_floor("A", false)
	assert_eq(RunState.act_stars(), [true, true, false])
	RunState.note_floor("C", false)
	RunState.note_floor("C", false)
	assert_eq(RunState.act_stars()[1], false, "29 points over 12 floors is under an S average")
	RunState.use_revive()
	assert_eq(RunState.act_stars()[0], false, "a revive costs the first star")
	RunState.run_cards.append("curse_blackout")
	assert_eq(RunState.act_stars()[2], true, "cleared under a curse")


func test_mastering_an_act_keeps_its_best_stars_and_counts_the_clear() -> void:
	RunState.start_run(1)
	for i in 10:
		RunState.note_floor("S", false)
	var news := RunState.master_act("S")
	assert_eq(MetaState.stars_of(1), [true, true, false])
	for stat: String in ["acts", "clears_act_1", "acts_clean", "act1_no_sprint", "gate_s"]:
		assert_eq(MetaState.stat(stat), 1, stat)
	assert_true(news.has("CHALLENGE  ·  " + Unlocks.challenge("soft_steps")["name"]), str(news))
	RunState.start_run(1)
	RunState.use_revive()
	RunState.note_floor("B", true)
	RunState.run_cards.append("curse_blackout")
	RunState.master_act("B")
	assert_eq(MetaState.stars_of(1), [true, true, true], "the best of every clear")
	assert_eq(MetaState.stat("act1_no_sprint"), 1, "this clear sprinted")
	assert_eq(MetaState.stars_of(2), [false, false, false])


func test_descending_counts_the_next_act_fresh() -> void:
	MetaState.unlock_act(2)
	RunState.start_run(1)
	RunState.note_floor("C", true)
	RunState.use_revive()
	RunState.descend()
	assert_eq(RunState.act_stars(), [true, false, false], "a new act: no revive yet, no floors yet")
	assert_eq(RunState.act_sprinted, false)
	assert_eq(MetaState.stat("descents"), 1)


func test_the_profile_keeps_stats_and_stars_through_a_relaunch() -> void:
	RunState.start_run(1)
	RunState.note_floor("S", true)
	RunState.use_revive()
	MetaState.record({"flips": 3})
	MetaState.award_stars(2, [false, true, false])
	_relaunch()
	assert_eq(MetaState.stat("flips"), 3)
	assert_eq(MetaState.stars_of(2), [false, true, false])
	assert_eq(RunState.act_stars()[0], false, "the act's revive survives a relaunch")
	assert_eq(RunState.act_sprinted, true)


func _average_chest() -> float:
	var total := 0
	for seed_value in 1000:
		total += MetaState.chest_roll(seed_value)["shards"]
	return total / 1000.0


func _fresh_profile() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE))
	_relaunch()


## Forget everything in memory and read it back, as a new process would.
func _relaunch() -> void:
	MetaState._loaded = false
	RunState._loaded = false
	RunState.load_save()
