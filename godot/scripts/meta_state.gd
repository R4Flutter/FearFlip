class_name MetaState
extends RefCounted
## The permanent profile (plans/06 §6): what survives every run. The acts unlocked (P1) and the Fear
## Shards every run banks, dead or alive (P2); unlocks and stats join it later. Its own file, because
## RunState.save() rewrites all of save.cfg.

## What pays, in Fear Shards (plans/06 D1). A floor has 2 keys, so a key pays 4 (the plan's 3 keys x 3).
const SIGIL_SHARDS := 4
## A Close Call or a Phase Dodge (C2).
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
## The first unlock costs about one losing first run (the P2 gate); a new profile starts 20% of the way.
const FIRST_UNLOCK_COST := 70
const STARTER_SHARDS := 14

static var profile_path := "user://profile.cfg"
static var acts_unlocked := 1
static var shards := STARTER_SHARDS
## Chest finds kept for the systems that spend them: omen tokens (P4 omens), lore notes (P5 archive).
static var omen_tokens := 0
static var notes_found := 0
static var _loaded := false


## Once per process (RunState.load_save calls it). No file yet reads as a new profile.
static func load_profile() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	cfg.load(profile_path)
	acts_unlocked = clampi(cfg.get_value("acts", "unlocked", 1), 1, StageRule.ACT_COUNT)
	shards = cfg.get_value("meta", "shards", STARTER_SHARDS)
	omen_tokens = cfg.get_value("meta", "omen_tokens", 0)
	notes_found = cfg.get_value("meta", "notes_found", 0)


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("acts", "unlocked", acts_unlocked)
	cfg.set_value("meta", "shards", shards)
	cfg.set_value("meta", "omen_tokens", omen_tokens)
	cfg.set_value("meta", "notes_found", notes_found)
	cfg.save(profile_path)


static func earn(amount: int) -> void:
	shards += amount
	save()


## A chest find, kept for the system that spends it.
static func keep_find(kind: String) -> void:
	if kind == "omen":
		omen_tokens += 1
	elif kind == "note":
		notes_found += 1
	save()


## 0..1 toward the next unlock (the Altar spends shards from plans/06 P5).
static func unlock_progress() -> float:
	return clampf(float(shards) / FIRST_UNLOCK_COST, 0.0, 1.0)


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
	return act >= 1 and act <= acts_unlocked


## Opens every act up to `act` for good (capped at the last act).
static func unlock_act(act: int) -> void:
	acts_unlocked = clampi(maxi(acts_unlocked, act), 1, StageRule.ACT_COUNT)
	save()
