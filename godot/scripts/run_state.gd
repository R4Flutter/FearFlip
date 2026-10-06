class_name RunState
extends RefCounted
## The Descent run (plans/05 §3.8): current floor, run seed, best floor, revives used this act.
## Static so it survives reload_current_scene(); mirrored to a ConfigFile so a relaunch resumes.

const REVIVES_PER_ACT := 3

static var save_path := "user://save.cfg"
static var current_floor := 1
static var run_seed := 0
static var best_floor := 1
static var revives_used := 0
static var _loaded := false


## Once per process: read the save, or start a fresh run.
static func load_save() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(save_path) == OK:
		current_floor = cfg.get_value("run", "floor", 1)
		run_seed = cfg.get_value("run", "seed", 0)
		best_floor = cfg.get_value("run", "best_floor", 1)
		revives_used = cfg.get_value("run", "revives_used", 0)
	if run_seed == 0:
		new_run()


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("run", "floor", current_floor)
	cfg.set_value("run", "seed", run_seed)
	cfg.set_value("run", "best_floor", best_floor)
	cfg.set_value("run", "revives_used", revives_used)
	cfg.save(save_path)


static func new_run() -> void:
	run_seed = randi() | 1
	current_floor = 1
	revives_used = 0
	save()


## Same run + same floor = same maze: retries and bug reports replay exactly.
static func floor_seed() -> int:
	return hash([run_seed, current_floor])


static func advance_floor() -> void:
	current_floor = mini(current_floor + 1, StageRule.LAST_FLOOR)
	best_floor = maxi(best_floor, current_floor)
	if StageRule.is_checkpoint(current_floor):
		revives_used = 0
	save()


static func revives_left() -> int:
	return REVIVES_PER_ACT - revives_used


static func use_revive() -> bool:
	if revives_left() <= 0:
		return false
	revives_used += 1
	save()
	return true
