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
