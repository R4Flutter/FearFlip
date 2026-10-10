extends McpTestSuite
## plans/06 P3: floor variety. Decks by act, the Gate and Sanctuary cards, what each door deals and the
## rules doors are offered by, the fold RunState.mod() uses, and fairness limits no stack of cards breaks.

const SEEDS := 1000
const WALK := 3.0
## Door draws are checked on a spread of floors in every act (all 50 x 1,000 seeds is needlessly slow).
const DOOR_FLOORS: Array[int] = [2, 3, 4, 12, 13, 17, 23, 26, 33, 38, 43, 49]


func suite_name() -> String:
	return "cards"


func test_decks_filter_by_act() -> void:
	for act in range(1, StageRule.ACT_COUNT + 1):
		var deck := Cards.deck(act)
		assert_gt(deck.size(), 2, "act %d has a deck" % act)
		for id in deck:
			assert_true(int(Cards.find(id)["from"]) <= act, "%s is not dealt in act %d" % [id, act])
	assert_gt(Cards.deck(StageRule.ACT_COUNT).size(), Cards.deck(1).size(), "later acts add cards")


func test_the_gate_and_the_sanctuary_play_their_own_card() -> void:
	for act in range(1, StageRule.ACT_COUNT + 1):
		var gate := StageRule.for_floor(StageRule.act_start(act) + StageRule.GATE_FLOOR - 1)
		assert_eq(Cards.deal(7, gate, "hunt", []), [Cards.GATES[act - 1]["id"]], "act %d Gate" % act)
		var sanctuary := StageRule.for_floor(StageRule.act_start(act) + StageRule.SANCTUARY_FLOOR - 1)
		assert_eq(Cards.deal(7, sanctuary, "vault", []), ["sanctuary"])
		assert_false(Cards.offers_doors(gate) or Cards.offers_doors(sanctuary), "no door into them")
	assert_eq(Cards.deal(7, StageRule.for_floor(1), "", []), [], "the very first floor teaches the core loop")
	assert_eq(Cards.deal(7, StageRule.for_floor(11), "", []).size(), 1, "later acts open on a rule card")


func test_doors_deal_what_they_promise() -> void:
	var rule := StageRule.for_floor(23)
	var hunt := Cards.deal(11, rule, "hunt", [])
	assert_eq(hunt[0], "hunt")
	assert_eq(hunt.size(), 3, "Hunt deals two rule cards")
	assert_eq(Cards.deal(11, rule, "shrine", []), ["shrine"], "a Shrine floor has no rule card")
	var vault := Cards.deal(11, rule, "vault", [])
	assert_eq(vault[0], "vault")
	assert_eq(vault.size(), 2)
	assert_eq(Cards.deal(11, rule, "normal", []).size(), 1, "Normal: the floor's own rule card")
	var mystery := Cards.deal(11, rule, "mystery", [])
	assert_eq(mystery[0], "mystery")
	assert_eq(Cards.kind(mystery[1]), "door", "the Mystery door shows which door it was")
	assert_eq(Cards.deal(11, rule, "mystery", []), mystery, "same floor, same mystery")


func test_door_rules_hold_over_1000_seeds() -> void:
	var rules: Array[StageRule] = []
	for number in DOOR_FLOORS:
		rules.append(StageRule.for_floor(number))
	var checked := 0
	for seed_value in SEEDS:
		for rule in rules:
			for last: String in ["", "shrine"]:
				var doors := Cards.doors(seed_value, rule, last)
				var problem := _door_problem(doors, rule, last)
				if problem != "":
					assert_true(false, "seed %d floor %d after '%s' %s: %s" % [seed_value, rule.floor_number, last, doors, problem])
					return
				checked += 1
	assert_eq(checked, SEEDS * DOOR_FLOORS.size() * 2)


func test_fold_multiplies_factors_adds_counts_and_holds_limits() -> void:
	assert_eq(Cards.fold([], "fog", 1.0), 1.0)
	assert_eq(Cards.fold(["thick_fog"], "fog", 1.0), 1.8)
	assert_eq(Cards.fold(["hunt", "hungry_dark"], "shards", 1.0), 3.0, "factors multiply")
	assert_eq(Cards.fold(["vault"], "keys", 2.0), 3.0, "counts add")
	assert_eq(Cards.fold(["ritual", "vault"], "keys", 2.0), float(Cards.MAX_KEYS), "held at the key limit")
	assert_eq(Cards.fold(["short_fuse"], "flip_interval", 20.0), Cards.MIN_FLIP_INTERVAL, "never under the flip floor")


func test_no_card_stack_breaks_the_fairness_limits() -> void:
	for number in range(1, StageRule.LAST_FLOOR + 1):
		var rule := StageRule.for_floor(number)
		var stacks := _stacks(rule)
		assert_gt(stacks.size(), 0)
		for cards: Array in stacks:
			var problem := _fairness_problem(cards, rule)
			if problem != "":
				assert_true(false, "floor %d %s: %s" % [number, cards, problem])
				return


func test_two_floors_in_a_row_never_play_the_same() -> void:
	var rules: Array[StageRule] = []
	for number in range(1, StageRule.LAST_FLOOR + 1):
		rules.append(StageRule.for_floor(number))
	var checked := 0
	for run in 200:
		var rng := RandomNumberGenerator.new()
		rng.seed = run
		for act in range(1, StageRule.ACT_COUNT + 1):
			var previous: Array = []
			var last_door := ""
			for number in range(StageRule.act_start(act), StageRule.act_start(act) + StageRule.FLOORS_PER_ACT):
				var rule := rules[number - 1]
				var seed_value := run * 1000 + number
				var door := ""
				if number > StageRule.act_start(act) and Cards.offers_doors(rule):
					door = Cards.doors(seed_value, rule, last_door)[rng.randi() % 3]
				var cards := Cards.deal(seed_value, rule, door, previous)
				var repeats := cards.any(func(id: String) -> bool: return Cards.kind(id) == "rule" and previous.has(id))
				if repeats or (number > StageRule.act_start(act) and cards == previous):
					assert_true(false, "run %d floor %d plays like the floor before: %s after %s" % [run, number, cards, previous])
					return
				previous = cards
				last_door = cards[1] if door == "mystery" else door
				checked += 1
	assert_eq(checked, 200 * StageRule.LAST_FLOOR)


func test_the_omen_pool_starts_small_and_grows_with_tokens() -> void:
	var starters := Cards.omen_pool(0)
	assert_eq(starters.size(), Cards.STARTER_OMENS)
	var all := Cards.omen_pool(99)
	assert_eq(all.size(), Cards.OMENS.size(), "every omen works now the Devil can hear and see (P7)")
	for id in all:
		assert_eq(Cards.kind(id), "omen")
		assert_false(Cards.find(id).has("needs"), "%s waits for its system" % id)
	assert_eq(Cards.omen_pool(1).size(), Cards.STARTER_OMENS + 1, "one more per token")
	assert_eq(all.slice(0, Cards.STARTER_OMENS), starters, "tokens add to the starters, never swap them")


func test_omen_draws_never_repeat_or_offer_one_you_hold() -> void:
	var pool := Cards.omen_pool(99)
	for seed_value in SEEDS:
		var held: Array = pool.slice(0, seed_value % 11)
		var offer := Cards.omens(seed_value, pool, held)
		var problem := ""
		if offer.size() != mini(Cards.OMEN_CHOICES, pool.size() - held.size()):
			problem = "offers %d" % offer.size()
		for id in offer:
			if held.has(id) or offer.count(id) > 1:
				problem = "%s repeats" % id
		if problem != "":
			assert_true(false, "seed %d holding %s: %s (%s)" % [seed_value, held, problem, offer])
			return
	assert_eq(Cards.omens(5, pool, pool), [], "nothing left to offer")
	assert_eq(Cards.omens(5, pool, []), Cards.omens(5, pool, []), "same seed, same offer")


func test_a_curse_offer_always_lets_you_decline() -> void:
	for seed_value in 100:
		var offer := Cards.curses(seed_value)
		assert_eq(offer[0], "no_curse")
		assert_eq(offer.size(), 4)
		for id in offer:
			assert_eq(Cards.kind(id), "curse")
			assert_eq(offer.count(id), 1)
	for curse: Dictionary in Cards.CURSES.slice(1):
		var bonus := Cards.fold([curse["id"]], "shards", 1.0)
		assert_true(bonus >= 1.25 and bonus <= 1.5, "%s pays 25-50%% more" % curse["id"])
		assert_eq(Cards.kind(curse["rule"]), "rule", "%s doubles a real rule card" % curse["id"])


## The run's cards (every omen, a curse, four descents) on top of every card set a floor can be dealt,
## on the door floors plus every Sanctuary and Gate.
func test_omens_curses_and_descents_stay_inside_the_limits() -> void:
	var run: Array = Cards.omen_pool(99)
	run.append_array(["descend", "descend", "descend", "descend"])
	var floors: Array[int] = DOOR_FLOORS.duplicate()
	for act in StageRule.ACT_COUNT:
		floors.append_array([act * StageRule.FLOORS_PER_ACT + StageRule.SANCTUARY_FLOOR, act * StageRule.FLOORS_PER_ACT + StageRule.GATE_FLOOR])
	for number in floors:
		var rule := StageRule.for_floor(number)
		var stacks := _stacks(rule)
		for i in stacks.size():
			var cards: Array = stacks[i] + run + [Cards.CURSES[i % Cards.CURSES.size()]["id"]]
			var problem := _fairness_problem(cards, rule)
			if problem != "":
				assert_true(false, "floor %d %s: %s" % [number, cards, problem])
				return
	assert_eq(Cards.fold(["twin_flip"], "flip_interval", 40.0), 50.0, "Sound Sleeper: Flipping Time a quarter less often")
	assert_true(is_equal_approx(Cards.fold(["quick_veil"], "flip_duration", 12.0), 8.4), "Quick Veil: it lets go 30% sooner")


## Every card set `rule`'s floor can be dealt: its fixed card, or each door with each rule card (pairs for Hunt).
func _stacks(rule: StageRule) -> Array:
	if not Cards.offers_doors(rule):
		return [Cards.deal(0, rule, "", [])]
	var deck := Cards.deck(rule.act)
	var stacks: Array = [["shrine"], ["mystery", "shrine"]]
	for prefix: Array in [[], ["mystery"]]:
		for id in deck:
			stacks.append(prefix + [id])
			stacks.append(prefix + ["vault", id])
			for other in deck:
				if other > id:
					stacks.append(prefix + ["hunt", id, other])
	return stacks


## "" when a draw of doors follows the rules, else what's wrong with it.
func _door_problem(doors: Array[String], rule: StageRule, last: String) -> String:
	if doors.size() != 3:
		return "not three doors"
	var safe := false
	for id in doors:
		if Cards.kind(id) != "door" or doors.count(id) > 1:
			return "three different doors"
		if id == "hunt" and (rule.act < Cards.HUNT_FROM_ACT or rule.floor_in_act < Cards.HUNT_FROM_FLOOR):
			return "Hunt too early"
		if id == "shrine" and last == "shrine":
			return "a Shrine twice in a row"
		safe = safe or Cards.find(id).get("safe", false)
	return "" if safe else "no safe door"


## "" when a floor dealt `cards` stays inside every fairness limit, else the limit it breaks.
func _fairness_problem(cards: Array, rule: StageRule) -> String:
	var route := 120.0 * WALK
	if Cards.fold(cards, "devil_distance", rule.devil_spawn_distance) < StageRule.MIN_DEVIL_SPAWN_DISTANCE:
		return "Devil spawns too close"
	var cue := Cards.fold(cards, "trap_cue", rule.trap_cue_strength)
	if cue < StageRule.MIN_TRAP_CUE or cue > 1.0:
		return "cracks unreadable"
	for base: float in [rule.first_forced_at, rule.forced_interval_min, rule.forced_interval_max, rule.min_forced_interval]:
		if Cards.fold(cards, "flip_interval", base) < Cards.MIN_FLIP_INTERVAL:
			return "Flipping Time too often"
	if rule.time_budget(route, WALK, Cards.fold(cards, "clock", 1.0)) < route / WALK * StageRule.MIN_TIME_SLACK:
		return "clock too tight"
	if Cards.fold(cards, "devil_speed", 1.0) > 1.3:
		return "Devil too fast"
	var keys := Cards.fold(cards, "keys", FloorLayout.SIGIL_COUNT)
	if keys < 1 or keys > Cards.MAX_KEYS:
		return "key count"
	if Cards.fold(cards, "traps", rule.trap_count) > Cards.MAX_TRAPS:
		return "too many traps"
	if Cards.fold(cards, "circle_time", rule.safe_circle_protect_s) < Cards.MIN_CIRCLE_TIME:
		return "circles drain too fast"
	if Cards.fold(cards, "rooms", rule.rooms) < Cards.MIN_ROOMS:
		return "floor too small"
	if Cards.fold(cards, "flip_duration", 12.0) < Cards.MIN_FLIP_DURATION:
		return "Flipping Time too short"
	if Cards.fold(cards, "shards", 1.0) > 3.0:
		return "shards run away"
	return ""


# --- plans/06 P8: the Abyss and the Nightmare Ranks ----------------------------------------------------

## Every Abyss floor deals its whole stack (one more through a Hunt, one fewer through a Shrine), never a rule card
## the floor before had, never a curse's twin, whatever the doors and the curse.
func test_the_abyss_deals_its_whole_stack_every_floor() -> void:
	var checked := 0
	for run in 60:
		var rng := RandomNumberGenerator.new()
		rng.seed = run
		var curse: Dictionary = Cards.CURSES[1 + run % (Cards.CURSES.size() - 1)]
		var previous: Array = []
		var last_door := ""
		for depth in range(1, 31):
			var rule := StageRule.for_floor(StageRule.LAST_FLOOR + depth)
			var seed_value := run * 1000 + depth
			var door := "" if depth == 1 else Cards.doors(seed_value, rule, last_door)[rng.randi() % 3]
			var exclude := previous.duplicate()
			exclude.append(curse["rule"])
			var cards := Cards.deal(seed_value, rule, door, exclude)
			var taken: String = cards[1] if door == "mystery" else door
			var want := rule.rule_cards + (1 if taken == "hunt" else (-1 if taken == "shrine" else 0))
			var rules := cards.filter(func(id: String) -> bool: return Cards.kind(id) == "rule")
			var stale := rules.any(func(id: String) -> bool: return previous.has(id) or id == curse["rule"])
			if rules.size() != want or stale:
				assert_true(false, "run %d depth %d through %s: %s after %s" % [run, depth, door, cards, previous])
				return
			previous = cards
			last_door = taken
			checked += 1
	assert_eq(checked, 60 * 30)


func test_twenty_ranks_each_add_one_rule() -> void:
	assert_eq(Cards.RANKS.size(), Cards.MAX_RANK)
	assert_eq(Cards.ranks(0), [])
	assert_eq(Cards.ranks(3), [Cards.RANKS[0]["id"], Cards.RANKS[1]["id"], Cards.RANKS[2]["id"]], "a rank holds every rank below it")
	assert_eq(Cards.ranks(99).size(), Cards.MAX_RANK)
	var pay := 1.0
	for i in Cards.MAX_RANK:
		var card: Dictionary = Cards.RANKS[i]
		assert_eq(Cards.kind(card["id"]), "rank")
		assert_eq(card["mods"].size(), 2, "%s: one rule and its shards" % card["id"])
		var more := Cards.fold(Cards.ranks(i + 1), "shards", 1.0)
		assert_true(more > pay, "rank %d pays more than rank %d" % [i + 1, i])
		pay = more


## Every rank on top of everything else a floor can hold: every rule card, every door, every omen, a curse and five
## descents, on campaign door floors, Gates and the Abyss.
func test_stacked_cards_and_ranks_never_break_the_fairness_limits() -> void:
	var run: Array = Cards.omen_pool(99)
	run.append_array(["descend", "descend", "descend", "descend", "descend"])
	var floors: Array[int] = DOOR_FLOORS.duplicate()
	for act in StageRule.ACT_COUNT:
		floors.append(act * StageRule.FLOORS_PER_ACT + StageRule.GATE_FLOOR)
	for depth in [1, 6, 11, 16, 50]:
		floors.append(StageRule.LAST_FLOOR + depth)
	var checked := 0
	for number in floors:
		var rule := StageRule.for_floor(number)
		for rank in [1, 10, Cards.MAX_RANK]:
			for curse: Dictionary in Cards.CURSES:
				var cards: Array = Cards.deck(rule.act) + ["vault", "hunt", "mystery"] + run + Cards.ranks(rank) + [curse["id"]]
				var problem := _fairness_problem(cards, rule)
				if problem == "" and roundi(Cards.fold(cards, "circles", 2.0)) < 1:
					problem = "no safe circle"
				if problem != "":
					assert_true(false, "floor %d rank %d %s: %s" % [number, rank, curse["id"], problem])
					return
				checked += 1
	assert_eq(checked, floors.size() * 3 * Cards.CURSES.size())


## plans/06 P9: an event's rule cards and every Cursed Week card stack like any other, on top of the top rank.
func test_event_and_weekly_cards_stay_inside_the_limits() -> void:
	var weekly: Array = Cards.WEEKLY.map(func(card: Dictionary) -> String: return card["id"])
	var floors: Array[int] = DOOR_FLOORS.duplicate()
	floors.append(StageRule.LAST_FLOOR + 16)
	var checked := 0
	for event: Dictionary in Cards.EVENTS:
		for number in floors:
			var rule := StageRule.for_floor(number)
			var cards: Array = Cards.deck(rule.act, event["id"]) + ["vault", "hunt"] + Cards.ranks(Cards.MAX_RANK) + weekly
			var problem := _fairness_problem(cards, rule)
			if problem != "":
				assert_true(false, "%s floor %d: %s" % [event["id"], number, problem])
				return
			checked += 1
	assert_eq(checked, Cards.EVENTS.size() * floors.size())
