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
## The run's own cards (plans/06 P4): the omens picked, the curse taken and one "descend" per Gate
## descended. mod() folds them into every floor of the run.
static var run_cards: Array[String] = []
## Choices owed before the next floor plays, oldest first: "curse", "omen", "door" or "gate". Saved, so
## quitting at a picker offers the same choice again on relaunch.
static var picks: Array[String] = []
## The floor this run started on: there is something to continue once you're past it.
static var start_floor := 1
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
		last_door = cfg.get_value("run", "last_door", "")
		_cleared_cards.assign(cfg.get_value("run", "cleared", []))
		run_cards.assign(cfg.get_value("run", "run_cards", []))
		picks.assign(cfg.get_value("run", "picks", []))
		start_floor = cfg.get_value("run", "start_floor", StageRule.act_start(act()))
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
	cfg.set_value("run", "last_door", last_door)
	cfg.set_value("run", "cleared", _cleared_cards)
	cfg.set_value("run", "run_cards", run_cards)
	cfg.set_value("run", "picks", picks)
	cfg.set_value("run", "start_floor", start_floor)
	cfg.save(save_path)


## A fresh run from the first floor of `act_number`: new maze, full revives. Locked acts refuse. Once
## Act 1 is cleared it opens on a curse offer, and a later act's start owes one omen pick per act skipped
## (the shortcut start kit).
static func start_run(act_number: int) -> bool:
	if not MetaState.is_act_unlocked(act_number):
		return false
	run_seed = randi() | 1
	current_floor = StageRule.act_start(act_number)
	start_floor = current_floor
	best_floor = maxi(best_floor, current_floor)
	revives_used = 0
	run_over = false
	run_shards = 0
	door = ""
	last_door = ""
	_cleared_cards.clear()
	run_cards.clear()
	picks.clear()
	if MetaState.acts_unlocked > 1:
		picks.append("curse")
	for _i in act_number - 1:
		picks.append("omen")
	_deal()
	save()
	return true


## Banked shards are kept for good, dead or alive, and counted toward this run.
static func bank(amount: int) -> void:
	run_shards += amount
	MetaState.earn(amount)
	save()


## Death ends the run; use_revive() brings it back. A run that's over owes no more choices.
static func end_run() -> void:
	run_over = true
	picks.clear()
	save()


## The Gate is beaten: the next act opens for good and this run is over (RETURN).
static func clear_act() -> void:
	MetaState.unlock_act(act() + 1)
	end_run()


## The Gate is beaten: the next act opens for good. The last act's Gate ends the run; any other owes
## the RETURN / DESCEND choice first.
static func clear_gate() -> void:
	if act() == StageRule.ACT_COUNT:
		clear_act()
		return
	MetaState.unlock_act(act() + 1)
	picks.assign(["gate"])
	save()


## DESCEND: on into the next act's first floor, keeping the omens and the revives left (no refill).
## Every descent pays half again, and the Gate's omen pick comes first.
static func descend() -> void:
	MetaState.unlock_act(act() + 1)
	run_cards.append("descend")
	current_floor = mini(current_floor + 1, StageRule.LAST_FLOOR)
	best_floor = maxi(best_floor, current_floor)
	door = ""
	last_door = ""
	_cleared_cards.clear()
	_deal()
	picks.append("omen")
	save()


static func act() -> int:
	return StageRule.act_of(current_floor)


## A run worth resuming: still alive and past the floor it started on.
static func has_progress() -> bool:
	return not run_over and current_floor > start_floor


## Same run + same floor = same maze: bug reports replay exactly.
static func floor_seed() -> int:
	return hash([run_seed, current_floor])


## On to the next floor, through the normal door until choose_door() picks another. It owes an omen
## pick if the floor cleared promised one (Shrine, Sanctuary), then the door choice where there is one.
static func advance_floor() -> void:
	var omen_owed := mod("omen_pick", 0.0) > 0.0
	_cleared_cards = floor_cards.duplicate()
	last_door = door
	door = "normal"
	current_floor = mini(current_floor + 1, StageRule.LAST_FLOOR)
	best_floor = maxi(best_floor, current_floor)
	_deal()
	picks.clear()
	if omen_owed:
		picks.append("omen")
	if Cards.offers_doors(StageRule.for_floor(current_floor)):
		picks.append("door")
	save()


## The door picked into this floor (just advanced to): its cards are dealt again through it.
static func choose_door(id: String) -> void:
	door = id
	_deal()
	if id == "mystery" and floor_cards.size() > 1:
		door = floor_cards[1]
	save()


## What the oldest owed pick offers: the same cards on every relaunch (drawn from the run and the floor).
static func pick_options() -> Array[String]:
	var ids: Array[String] = []
	if picks.is_empty():
		return ids
	var draw_seed := hash([run_seed, current_floor, run_cards.size()])
	match picks[0]:
		"curse":
			ids = Cards.curses(draw_seed)
		"omen":
			ids = Cards.omens(draw_seed, Cards.omen_pool(MetaState.omen_tokens), run_cards)
		"door":
			ids = Cards.doors(floor_seed(), StageRule.for_floor(current_floor), last_door)
		"gate":
			ids.assign(["return", "descend"])
	return ids


## Settles the oldest owed pick with `id`, one of pick_options() ("" passes: no omen left to offer).
static func take(id: String) -> void:
	if picks.is_empty():
		return
	var kind: String = picks.pop_front()
	match kind:
		"door":
			choose_door(id)
		"gate":
			if id == "descend":
				descend()
			else:
				clear_act()
		_:
			if id != "" and id != "no_curse":
				run_cards.append(id)
				_deal()  # a curse keeps its twin rule card off the floors
	save()


## One mod for this floor: `base` folded through its cards and the run's, held inside the fairness
## limits (Cards.fold).
static func mod(key: String, base: float) -> float:
	return Cards.fold(floor_cards + run_cards, key, base)


static func _deal() -> void:
	var exclude: Array = _cleared_cards.duplicate()
	for id in run_cards:
		exclude.append(Cards.find(id).get("rule", ""))
	floor_cards = Cards.deal(floor_seed(), StageRule.for_floor(current_floor), door, exclude)


static func revives_left() -> int:
	return REVIVES_PER_ACT - revives_used


static func use_revive() -> bool:
	if revives_left() <= 0:
		return false
	revives_used += 1
	run_over = false
	save()
	return true
