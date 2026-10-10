class_name MetaState
extends RefCounted
## The permanent profile (plans/06 §6): what survives every run. The acts unlocked (P1), the Fear Shards
## every run banks, dead or alive (P2), and the meta hub (P5): Altar items owned and worn (Unlocks). Its own
## file, because RunState.save() rewrites all of save.cfg.

## What pays, in Fear Shards (plans/06 D1). A floor has 2 keys, so a key pays 4 (the plan's 3 keys x 3).
const SIGIL_SHARDS := 4
## A Close Call (C2).
const CLOSE_CALL_SHARDS := 3
## A floor clear pays FLOOR_CLEAR_SHARDS + FLOOR_STEP_SHARDS x its number in the act, plus its grade's bonus.
const FLOOR_CLEAR_SHARDS := 10
const FLOOR_STEP_SHARDS := 2
const GRADE_SHARDS := {"S": 10, "A": 5}
## x the act number, on top of the Gate's floor clear.
const ACT_CLEAR_SHARDS := 50
## Chest rolls (C5): [kind, chance], rolled from the floor seed. Never paid randomness.
const CHEST_ODDS := [["shards", 0.6], ["omen", 0.2], ["note", 0.15], ["rare", 0.05]]
const CHEST_SHARDS := Vector2i(4, 12)
const RARE_SHARDS := 30
const CHEST_TEXT := {"shards": "CHEST", "omen": "OMEN TOKEN", "note": "LORE NOTE", "rare": "RARE CHEST"}
## Hidden mercy (plans/06 G3): from this many deaths on one campaign floor, that floor is kinder (Cards.MERCY) until
## it's cleared. Never shown.
const MERCY_DEATHS := 3
## A bestiary entry's first sighting (D1).
const BESTIARY_SHARDS := 5
## The first unlock costs about one losing first run (the P2 gate); a new profile starts 20% of the way.
const FIRST_UNLOCK_COST := 70
const STARTER_SHARDS := 14

static var profile_path := "user://profile.cfg"
static var acts_unlocked := 1
static var shards := STARTER_SHARDS
## Chest finds kept for the systems that spend them: omen tokens (P4 omens), lore notes (P5 archive).
static var omen_tokens := 0
static var notes_found := 0
## Altar items bought or won (P5). Free gear and the starter omens are owned without being listed here.
static var unlocked: Array[String] = []
## Worn gear, kind -> id (Unlocks.EQUIP_KINDS); a kind not in it wears its free default.
static var equipped := {}
## Lifetime counters, stat -> count, banked with each floor like its shards (record()): challenges read them.
static var stats := {}
## Act mastery (D6), act -> [cleared without a revive, S-grade average, cleared under a curse]: the best of every clear.
static var stars := {}
## Deaths per campaign floor since it was last cleared (mercy).
static var deaths_at := {}
## Nightmare Ranks (plans/06 P8): the highest rank open (0 until floor 50 first falls) and the rank the act picker
## holds.
static var ranks_open := 0
static var rank := 0
## The Abyss's depth score: the most Abyss floors cleared in one run.
static var abyss_best := 0
static var _loaded := false


## Once per process (RunState.load_save calls it). No file yet reads as a new profile.
static func load_profile() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	Portal.pull(profile_path)
	cfg.load(profile_path)
	acts_unlocked = clampi(cfg.get_value("acts", "unlocked", 1), 1, LiveOps.released_acts)
	shards = cfg.get_value("meta", "shards", STARTER_SHARDS)
	omen_tokens = cfg.get_value("meta", "omen_tokens", 0)
	notes_found = cfg.get_value("meta", "notes_found", 0)
	unlocked.assign(cfg.get_value("meta", "unlocked", []))
	equipped = cfg.get_value("meta", "equipped", {})
	stats = cfg.get_value("meta", "stats", {})
	stars = cfg.get_value("meta", "stars", {})
	deaths_at = cfg.get_value("meta", "deaths_at", {})
	ranks_open = clampi(cfg.get_value("meta", "ranks_open", 0), 0, Cards.MAX_RANK)
	rank = cfg.get_value("meta", "rank", 0)
	abyss_best = cfg.get_value("meta", "abyss_best", 0)
	Daily.load_state(cfg)


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("acts", "unlocked", acts_unlocked)
	cfg.set_value("meta", "shards", shards)
	cfg.set_value("meta", "omen_tokens", omen_tokens)
	cfg.set_value("meta", "notes_found", notes_found)
	cfg.set_value("meta", "unlocked", unlocked)
	cfg.set_value("meta", "equipped", equipped)
	cfg.set_value("meta", "stats", stats)
	cfg.set_value("meta", "stars", stars)
	cfg.set_value("meta", "deaths_at", deaths_at)
	cfg.set_value("meta", "ranks_open", ranks_open)
	cfg.set_value("meta", "rank", rank)
	cfg.set_value("meta", "abyss_best", abyss_best)
	Daily.save_state(cfg)
	cfg.save(profile_path)
	Portal.push(profile_path)


static func earn(amount: int) -> void:
	shards += amount
	save()


static func stat(key: String) -> int:
	return stats.get(key, 0)


## Banks counters (stat -> amount) and pays what they complete: every challenge, each bestiary entry seen for the
## first time, and the day's quests (Daily). Returns what to announce.
static func record(counts: Dictionary) -> Array[String]:
	Daily.refresh_quests(Daily.today())
	var news: Array[String] = []
	for key: String in counts:
		var before := stat(key)
		stats[key] = before + counts[key]
		for challenge: Dictionary in Unlocks.CHALLENGES:
			if challenge["stat"] == key and before < challenge["goal"] and stats[key] >= challenge["goal"]:
				_pay(challenge)
				news.append("CHALLENGE  ·  " + challenge["name"])
		for beast: Dictionary in Lore.BESTIARY:
			if beast["seen"] == key and before == 0 and stats[key] > 0:
				shards += BESTIARY_SHARDS
				news.append("BESTIARY  ·  " + beast["name"])
	news.append_array(Daily.check_quests())
	save()
	return news


static func note_death(floor_number: int) -> void:
	deaths_at[floor_number] = int(deaths_at.get(floor_number, 0)) + 1
	save()


static func note_clear(floor_number: int) -> void:
	if deaths_at.erase(floor_number):
		save()


static func mercy_on(floor_number: int) -> bool:
	return int(deaths_at.get(floor_number, 0)) >= MERCY_DEATHS


static func stars_of(act: int) -> Array:
	return stars.get(act, [false, false, false])


## Keeps the best of `earned` (RunState.act_stars) for `act`.
static func award_stars(act: int, earned: Array) -> void:
	var best := stars_of(act).duplicate()
	for i in best.size():
		best[i] = best[i] or earned[i]
	stars[act] = best
	save()


## A chest find, kept for the system that spends it.
static func keep_find(kind: String) -> void:
	if kind == "omen":
		omen_tokens += 1
	elif kind == "note":
		notes_found += 1
	save()


## 0..1 toward the next unlock (full once the Altar has nothing left).
static func unlock_progress() -> float:
	var next := next_unlock()
	if next == "":
		return 1.0
	return clampf(float(shards) / Unlocks.item(next)["cost"], 0.0, 1.0)


## The cheapest Altar item not owned yet whose "after" is owned ("" once there is nothing left to buy).
static func next_unlock() -> String:
	var best := ""
	var best_cost := 0
	for entry: Dictionary in Unlocks.ALTAR:
		if not owns(entry["id"]) and _reachable(entry) and (best == "" or entry["cost"] < best_cost):
			best = entry["id"]
			best_cost = entry["cost"]
	return best


static func owns(id: String) -> bool:
	var item := Unlocks.item(id)
	if item.is_empty():
		return false
	return item["cost"] == 0 or unlocked.has(id) or (item["kind"] == "omen" and omen_pool().has(id))


## The omens a pick can offer: the starters, the Altar's and one per omen token (Cards.omen_pool).
static func omen_pool() -> Array[String]:
	return Cards.omen_pool(omen_tokens, unlocked)


## Not owned yet, what comes before it is owned, and the shards are there.
static func can_buy(id: String) -> bool:
	var item := Unlocks.item(id)
	return not item.is_empty() and not owns(id) and _reachable(item) and shards >= item["cost"]


## Spends shards on an Altar item (refused unless can_buy).
static func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	shards -= Unlocks.item(id)["cost"]
	unlocked.append(id)
	save()
	RunState.log_event("unlock", {"id": id, "shards": shards})
	return true


## Wears owned gear, one per kind. Omens and slots aren't worn.
static func equip(id: String) -> bool:
	var item := Unlocks.item(id)
	if item.is_empty() or not Unlocks.EQUIP_KINDS.has(item["kind"]) or not owns(id):
		return false
	equipped[item["kind"]] = id
	save()
	return true


## The gear worn of `kind` (a save naming something not owned wears the default).
static func wearing(kind: String) -> String:
	var id: String = equipped.get(kind, "")
	return id if owns(id) else Unlocks.default_gear(kind)


## What RunState.mod() folds into every floor on top of the run's cards: the torch (only torches carry mods).
static func gear() -> Array[String]:
	var ids: Array[String] = [wearing("torch")]
	return ids


static func light_color() -> Color:
	return Unlocks.item(wearing("light"))["color"]


## Omen picks every run opens with (the Altar's omen slots).
static func slots() -> int:
	return unlocked.filter(func(id: String) -> bool: return Unlocks.item(id).get("kind") == "slot").size()


## An Altar item given (a challenge, a streak milestone): yours, or its price in shards if it already is.
static func grant(id: String) -> void:
	if owns(id):
		shards += Unlocks.item(id)["cost"]
	else:
		unlocked.append(id)


## A challenge's reward: shards and/or its Altar item.
static func _pay(challenge: Dictionary) -> void:
	shards += challenge.get("shards", 0)
	if challenge.has("item"):
		grant(challenge["item"])


## What comes before it is owned, and it's in season (an event's cosmetics: LiveOps).
static func _reachable(item: Dictionary) -> bool:
	return (not item.has("after") or owns(item["after"])) and LiveOps.in_season(item)


static func floor_clear_shards(floor_in_act: int, grade: String) -> int:
	return FLOOR_CLEAR_SHARDS + FLOOR_STEP_SHARDS * floor_in_act + int(GRADE_SHARDS.get(grade, 0))


static func act_clear_shards(act: int) -> int:
	return ACT_CLEAR_SHARDS * act


## Same floor, same chest: {"kind": a CHEST_ODDS kind, "shards": what it pays}.
static func chest_roll(floor_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([floor_seed, "chest"])
	var roll := rng.randf()
	var kind: String = CHEST_ODDS[-1][0]
	for odds: Array in CHEST_ODDS:
		if roll < odds[1]:
			kind = odds[0]
			break
		roll -= odds[1]
	var pay := 0
	if kind == "shards":
		pay = rng.randi_range(CHEST_SHARDS.x, CHEST_SHARDS.y)
	elif kind == "rare":
		pay = RARE_SHARDS
	return {"kind": kind, "shards": pay}


static func is_act_unlocked(act: int) -> bool:
	if act == StageRule.ABYSS_ACT:
		return abyss_open()
	return act >= 1 and act <= acts_unlocked


## Floor 50 has fallen at least once: the Abyss is open (and the ranks with it).
static func abyss_open() -> bool:
	return stat("clears_act_%d" % StageRule.ACT_COUNT) > 0


## The rank a new run plays: the picker's, never above the ranks open.
static func chosen_rank() -> int:
	return clampi(rank, 0, ranks_open)


## A Gate fell on a run at rank `cleared`: the first floor-50 clear opens rank 1, and a Gate at your top rank
## opens the next (up to Cards.MAX_RANK). Returns what to announce.
static func open_ranks(cleared: int, last_act: bool) -> Array[String]:
	var before := ranks_open
	if last_act:
		ranks_open = maxi(ranks_open, 1)
	if cleared > 0 and cleared == ranks_open:
		ranks_open = mini(ranks_open + 1, Cards.MAX_RANK)
	var news: Array[String] = []
	for opened in range(before + 1, ranks_open + 1):
		news.append("NIGHTMARE RANK %d OPEN" % opened)
	if ranks_open != before:
		save()
	return news


## An Abyss floor cleared `depth` floors down: the depth score keeps the deepest.
static func note_depth(depth: int) -> void:
	if depth > abyss_best:
		abyss_best = depth
		save()
		Portal.submit_depth(depth)


## Opens every act up to `act` for good (capped at the last act that is out: LiveOps.released_acts).
static func unlock_act(act: int) -> void:
	acts_unlocked = clampi(maxi(acts_unlocked, act), 1, LiveOps.released_acts)
	save()
