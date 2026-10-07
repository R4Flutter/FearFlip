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


static func advance_floor() -> void:
	current_floor = mini(current_floor + 1, StageRule.LAST_FLOOR)
	best_floor = maxi(best_floor, current_floor)
	save()


static func revives_left() -> int:
	return REVIVES_PER_ACT - revives_used


static func use_revive() -> bool:
	if revives_left() <= 0:
		return false
	revives_used += 1
	run_over = false
	save()
	return true
