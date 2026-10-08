class_name RunState
extends RefCounted
## The act-run (plans/06 §2): one run = one act. It holds the floor, the run seed, revives used and
## whether the run already ended. Death ends it (a revive brings it back); beating the act's Gate (F10)
## unlocks the next act and ends it too. Static so it survives reload_current_scene(); mirrored to a
## ConfigFile so a relaunch resumes.

const REVIVES_PER_ACT := 3
## Act mastery (plans/06 D6): a floor's grade in points; the second star wants an S average.
const GRADE_POINTS := {"S": 3, "A": 2, "B": 1, "C": 0}
const S_AVERAGE := 2.5
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
## This act's record for its stars (reset by start_run and descend): revives used, the grade points and count
## of its floors cleared, and whether you sprinted on any of them.
static var act_revives := 0
static var act_points := 0
static var act_floors := 0
static var act_sprinted := false
## The run's Nightmare Rank (plans/06 P8), fixed as it starts: mod() folds Cards.ranks(rank) into every floor.
static var rank := 0
## The floor this run started on: there is something to continue once you're past it.
static var start_floor := 1
## True once the run has ended (death or act clear): playing again starts a new run, never resumes it.
static var run_over := false
## The run's kind (plans/06 §6): "campaign" (saved), "daily" (today's ranked try) or "practice" (the Daily again,
## for nothing). Only a campaign saves mid-run, so the Daily never touches it; leave_daily() reloads the campaign.
static var mode := "campaign"
## In a Daily: its floor (1..Daily.FLOORS) and the date it belongs to.
static var daily_floor := 0
static var daily_date := ""
## The playtest log (plans/06 P0, read for the §7 KPIs): one JSON line per event. Only the game writes it: a -s script
## (the test runner) or the editor's own test runner leaves it off unless a test turns it on with its own path.
static var events_path := "user://events.jsonl"
static var log_events := is_game()
static var _session := 0
static var _loaded := false


## Once per process: read the profile and the save, or start a fresh run.
static func load_save() -> void:
	if _loaded:
		return
	_loaded = true
	MetaState.load_profile()
	if _session == 0:
		_session = int(Time.get_unix_time_from_system())
		log_event("session", {"acts": MetaState.acts_unlocked, "shards": MetaState.shards})
	var cfg := ConfigFile.new()
	Portal.pull(save_path)
	if cfg.load(save_path) == OK and cfg.get_value("run", "version", 1) == SAVE_VERSION:
		current_floor = clampi(cfg.get_value("run", "floor", 1), 1, StageRule.MAX_FLOOR)
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
		act_revives = cfg.get_value("run", "act_revives", 0)
		act_points = cfg.get_value("run", "act_points", 0)
		act_floors = cfg.get_value("run", "act_floors", 0)
		act_sprinted = cfg.get_value("run", "act_sprinted", false)
		rank = cfg.get_value("run", "rank", 0)
	if run_seed == 0 or not MetaState.is_act_unlocked(act()):
		start_run(1, false)


static func save() -> void:
	if is_daily():
		return
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
	cfg.set_value("run", "act_revives", act_revives)
	cfg.set_value("run", "act_points", act_points)
	cfg.set_value("run", "act_floors", act_floors)
	cfg.set_value("run", "act_sprinted", act_sprinted)
	cfg.set_value("run", "rank", rank)
	cfg.save(save_path)
	Portal.push(save_path)


## A fresh run from the first floor of `act_number` (StageRule.ABYSS_ACT: the Abyss) at the rank the act picker
## holds: new maze, full revives. Locked acts refuse. Once Act 1 is cleared it opens on a curse offer, and a later
## act's start owes one omen pick per act skipped (the shortcut start kit) plus one per Altar omen slot. `played` =
## false for the run a fresh profile is handed at load: nobody's run yet, so the playtest log doesn't count it.
static func start_run(act_number: int, played := true) -> bool:
	if not MetaState.is_act_unlocked(act_number):
		return false
	run_seed = randi() | 1
	current_floor = StageRule.act_start(act_number)
	start_floor = current_floor
	best_floor = maxi(best_floor, current_floor)
	revives_used = 0
	run_over = false
	run_shards = 0
	rank = MetaState.chosen_rank()
	door = ""
	last_door = ""
	_cleared_cards.clear()
	run_cards.clear()
	picks.clear()
	_new_act()
	if MetaState.acts_unlocked > 1:
		picks.append("curse")
	for _i in act_number - 1 + MetaState.slots():
		picks.append("omen")
	_deal()
	save()
	if played:
		log_event("run", {"act": act_number, "mode": mode})
	return true


## Today's Daily from its first floor: the ranked try while it's open (unless `practice`), else practice. One
## life, the day's omen and cards, no picks.
static func start_daily(practice: bool) -> void:
	var date := Daily.today()
	mode = "daily" if not practice and Daily.ranked_open(date) else "practice"
	if mode == "daily":
		Daily.begin_ranked(date)
	daily_date = date
	daily_floor = 1
	run_seed = Daily.seed_of(date)
	current_floor = Daily.STAGE_FLOORS[0]
	rank = 0
	revives_used = REVIVES_PER_ACT
	run_over = false
	run_shards = 0
	door = ""
	last_door = ""
	_cleared_cards.clear()
	run_cards.assign([Daily.omen(date)])
	picks.clear()
	_new_act()
	_deal()
	log_event("run", {"act": 0, "mode": mode})


## Back from the Daily: the campaign as its save left it (a fresh run if it never had one).
static func leave_daily() -> void:
	mode = "campaign"
	run_seed = 0
	_loaded = false
	load_save()


static func is_daily() -> bool:
	return mode != "campaign"


## True in the game itself; false under a -s script (the test runner) or the editor's own test runner.
static func is_game() -> bool:
	var loop := Engine.get_main_loop()
	return loop != null and loop.get_script() == null and not Engine.is_editor_hint()


## One line of the playtest log: `data` plus the event's kind ("e"), unix time ("t") and session ("s").
static func log_event(kind: String, data := {}) -> void:
	if not log_events:
		return
	var file := FileAccess.open(events_path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(events_path, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	var line := data.duplicate()
	line.merge({"e": kind, "t": int(Time.get_unix_time_from_system()), "s": _session})
	file.store_line(JSON.stringify(line))


## A Daily floor is over, cleared or died on: its square on the share line. Only the ranked try keeps it.
static func note_daily(square: String, seconds: float) -> void:
	if mode == "daily":
		Daily.add_result(square, seconds)


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
	log_event("run_end", {"floor": current_floor, "act": act(), "mode": mode, "shards": run_shards})


## The Gate is beaten: the next act opens for good and this run is over (RETURN).
static func clear_act() -> void:
	MetaState.unlock_act(act() + 1)
	end_run()


## The Gate is beaten: the next act opens for good, and the run owes the RETURN / DESCEND choice (below the last
## Gate, DESCEND leads into the Abyss). Before an act that isn't out yet (LiveOps.released_acts), the run just ends.
static func clear_gate() -> void:
	if act() < StageRule.ACT_COUNT and act() >= LiveOps.released_acts:
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
	current_floor = mini(current_floor + 1, StageRule.MAX_FLOOR)
	best_floor = maxi(best_floor, current_floor)
	door = ""
	last_door = ""
	_cleared_cards.clear()
	_new_act()
	_deal()
	picks.append("omen")
	MetaState.record({"descents": 1})
	save()


## A floor cleared: its grade and whether you sprinted count toward this act's stars; in the Abyss, its depth.
static func note_floor(grade: String, sprinted: bool) -> void:
	if act() == StageRule.ABYSS_ACT:
		MetaState.note_depth(current_floor - StageRule.LAST_FLOOR)
	act_points += GRADE_POINTS.get(grade, 0)
	act_floors += 1
	act_sprinted = act_sprinted or sprinted
	save()


## This act so far: [no revive, S-grade average, under a curse] (plans/06 D6).
static func act_stars() -> Array:
	var cursed := run_cards.any(func(id: String) -> bool: return Cards.kind(id) == "curse")
	return [act_revives == 0, act_floors > 0 and float(act_points) / act_floors >= S_AVERAGE, cursed]


## The Gate is beaten: this act's stars are kept for good, its clear counted for the challenges (a deep run is the
## last Gate on a run from the first floor) and the Nightmare Ranks climb (MetaState.open_ranks). Returns what to
## announce.
static func master_act(gate_grade: String) -> Array[String]:
	var earned := act_stars()
	MetaState.award_stars(act(), earned)
	var counts := {"acts": 1, "clears_act_%d" % act(): 1}
	if earned[0]:
		counts["acts_clean"] = 1
	if earned[2]:
		counts["acts_cursed"] = 1
	if act() == 1 and not act_sprinted:
		counts["act1_no_sprint"] = 1
	if gate_grade == "S":
		counts["gate_s"] = 1
	if act() == StageRule.ACT_COUNT and start_floor == 1:
		counts["deep_runs"] = 1
	var news := MetaState.record(counts)
	news.append_array(MetaState.open_ranks(rank, act() == StageRule.ACT_COUNT))
	return news


static func _new_act() -> void:
	act_revives = 0
	act_points = 0
	act_floors = 0
	act_sprinted = false


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
	if is_daily():
		daily_floor = mini(daily_floor + 1, Daily.FLOORS)
		current_floor = Daily.STAGE_FLOORS[daily_floor - 1]
		_deal()
		picks.clear()
		return
	var omen_owed := mod("omen_pick", 0.0) > 0.0
	_cleared_cards = floor_cards.duplicate()
	last_door = door
	door = "normal"
	current_floor = mini(current_floor + 1, StageRule.MAX_FLOOR)
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
			var week := LiveOps.cursed_week()
			if week != "":
				ids[-1] = week  # the Cursed Week takes the last place (plans/06 E6)
		"omen":
			ids = Cards.omens(draw_seed, MetaState.omen_pool(), run_cards)
		"door":
			ids = Cards.doors(floor_seed(), StageRule.for_floor(current_floor), last_door)
		"gate":
			ids.assign(["return", "descend"])
	return ids


## Settles the oldest owed pick with `id`, one of pick_options() ("" passes: no omen left to offer).
static func take(id: String) -> void:
	if picks.is_empty():
		return
	log_event("pick", {"kind": picks[0], "id": id, "offered": pick_options(), "floor": current_floor})
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


## One mod for this floor: `base` folded through its cards, the run's, the gear worn (MetaState.gear), the run's
## rank and hidden mercy (a campaign floor that keeps killing you), held inside the fairness limits (Cards.fold).
static func mod(key: String, base: float) -> float:
	var ids: Array[String] = floor_cards + run_cards + MetaState.gear() + Cards.ranks(rank)
	if not is_daily() and MetaState.mercy_on(current_floor):
		ids.append(Cards.MERCY["id"])
	return Cards.fold(ids, key, base)


static func _deal() -> void:
	if is_daily():
		floor_cards = Daily.cards(daily_date, daily_floor)
		return
	var exclude: Array = _cleared_cards.duplicate()
	for id in run_cards:
		exclude.append(Cards.find(id).get("rule", ""))
	floor_cards = Cards.deal(floor_seed(), StageRule.for_floor(current_floor), door, exclude, LiveOps.event().get("id", ""))


static func revives_left() -> int:
	return REVIVES_PER_ACT - revives_used


static func use_revive() -> bool:
	if revives_left() <= 0:
		return false
	revives_used += 1
	act_revives += 1
	run_over = false
	save()
	return true
