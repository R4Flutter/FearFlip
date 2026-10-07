class_name MetaState
extends RefCounted
## The permanent profile (plans/06 §6): what survives every run. Phase 1 keeps the acts unlocked;
## shards, unlocks and stats join it later. Its own file, because RunState.save() rewrites all of save.cfg.

static var profile_path := "user://profile.cfg"
static var acts_unlocked := 1
static var _loaded := false


## Once per process (RunState.load_save calls it).
static func load_profile() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(profile_path) == OK:
		acts_unlocked = clampi(cfg.get_value("acts", "unlocked", 1), 1, StageRule.ACT_COUNT)


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("acts", "unlocked", acts_unlocked)
	cfg.save(profile_path)


static func is_act_unlocked(act: int) -> bool:
	return act >= 1 and act <= acts_unlocked


## Opens every act up to `act` for good (capped at the last act).
static func unlock_act(act: int) -> void:
	acts_unlocked = clampi(maxi(acts_unlocked, act), 1, StageRule.ACT_COUNT)
	save()
