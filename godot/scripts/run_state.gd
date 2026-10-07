class_name RunState
extends RefCounted
## The act-run (plans/06 §2): one run = one act. It holds the floor, the run seed, revives used and
## whether the run already ended. Death ends it (a revive brings it back); beating the act's Gate (F10)
## unlocks the next act and ends it too. Static so it survives reload_current_scene(); mirrored to a
## ConfigFile so a relaunch resumes.

const REVIVES_PER_ACT := 3
## Bumped when the save's meaning changes: an older save starts a fresh run.
const SAVE_VERSION := 2

static var save_path := "user://save.cfg"
static var current_floor := 1
static var run_seed := 0
static var best_floor := 1
static var revives_used := 0
## Shards banked since this run started: the death screen's "dying still pays".
static var run_shards := 0
## This floor's cards (Cards ids, plans/06 P3): what mod() folds. Dealt from the floor seed and its door.
static var floor_cards: Array[String] = []
## The door taken into this floor ("" on an act's first floor; a Mystery keeps the door it turned out to
## be) and the one into the floor before (doors never offer a Shrine twice running).
static var door := ""
static var last_door := ""
## The cards of the floor just cleared: a door picked afterwards never deals one of them again.
static var _cleared_cards: Array[String] = []
## True once the run has ended (death or act clear): playing again starts a new run, never resumes it.
static var run_over := false
static var _loaded := false


## Once per process: read the profile and the save, or start a fresh run.
static func load_save() -> void:
	if _loaded:
		return
	_loaded = true
	MetaState.load_profile()
	var cfg := ConfigFile.new()
	if cfg.load(save_path) == OK and cfg.get_value("run", "version", 1) == SAVE_VERSION:
		current_floor = clampi(cfg.get_value("run", "floor", 1), 1, StageRule.LAST_FLOOR)
		run_seed = cfg.get_value("run", "seed", 0)
		best_floor = cfg.get_value("run", "best_floor", 1)
		revives_used = cfg.get_value("run", "revives_used", 0)
		run_over = cfg.get_value("run", "run_over", false)
		run_shards = cfg.get_value("run", "shards", 0)
		floor_cards.assign(cfg.get_value("run", "cards", []))
		door = cfg.get_value("run", "door", "")
	if run_seed == 0 or not MetaState.is_act_unlocked(act()):
		start_run(1)


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("run", "version", SAVE_VERSION)
	cfg.set_value("run", "floor", current_floor)
	cfg.set_value("run", "seed", run_seed)
	cfg.set_value("run", "best_floor", best_floor)
	cfg.set_value("run", "revives_used", revives_used)
	cfg.set_value("run", "run_over", run_over)
	cfg.set_value("run", "shards", run_shards)
	cfg.set_value("run", "cards", floor_cards)
	cfg.set_value("run", "door", door)
	cfg.save(save_path)


## A fresh run from the first floor of `act_number`: new maze, full revives. Locked acts refuse.
static func start_run(act_number: int) -> bool:
	if not MetaState.is_act_unlocked(act_number):
		return false
	run_seed = randi() | 1
	current_floor = StageRule.act_start(act_number)
	best_floor = maxi(best_floor, current_floor)
	revives_used = 0
	run_over = false
	run_shards = 0
	door = ""
	last_door = ""
	_cleared_cards.clear()
	_deal()
	save()
	return true


## Banked shards are kept for good, dead or alive, and counted toward this run.
static func bank(amount: int) -> void:
	run_shards += amount
	MetaState.earn(amount)
	save()


## Death ends the run; use_revive() brings it back.
static func end_run() -> void:
	run_over = true
	save()


## The Gate is beaten: the next act opens for good and this run is over.
static func clear_act() -> void:
	MetaState.unlock_act(act() + 1)
	end_run()


static func act() -> int:
	return StageRule.act_of(current_floor)


## A run worth resuming: still alive and past its act's first floor.
static func has_progress() -> bool:
	return not run_over and current_floor > StageRule.act_start(act())


## Same run + same floor = same maze: bug reports replay exactly.
static func floor_seed() -> int:
	return hash([run_seed, current_floor])


## On to the next floor, through the normal door until choose_door() picks another.
static func advance_floor() -> void:
	_cleared_cards = floor_cards.duplicate()
	last_door = door
	door = "normal"
	current_floor = mini(current_floor + 1, StageRule.LAST_FLOOR)
	best_floor = maxi(best_floor, current_floor)
	_deal()
	save()


## The door picked into this floor (just advanced to): its cards are dealt again through it.
static func choose_door(id: String) -> void:
	door = id
	_deal()
	if id == "mystery" and floor_cards.size() > 1:
		door = floor_cards[1]
	save()


## One mod for this floor: `base` folded through its cards, held inside the fairness limits (Cards.fold).
static func mod(key: String, base: float) -> float:
	return Cards.fold(floor_cards, key, base)


static func _deal() -> void:
	floor_cards = Cards.deal(floor_seed(), StageRule.for_floor(current_floor), door, _cleared_cards)


static func revives_left() -> int:
	return REVIVES_PER_ACT - revives_used


static func use_revive() -> bool:
	if revives_left() <= 0:
		return false
	revives_used += 1
	run_over = false
	save()
	return true
