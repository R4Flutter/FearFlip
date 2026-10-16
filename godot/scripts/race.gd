class_name Race
extends RefCounted
## The Long Night (plans/11): one long maze a week, the same for everyone, beside the campaign (a second page on the
## dashboard; it never touches the campaign's save). Its week is CrazyGames' leaderboard season, Monday 09:00 UTC to
## Monday. Run it as often as you like: the best time counts and goes to the board (Portal.submit_time). Everyone
## carries the same kit (no torches, mercy or ranks; the week's one rule card) into a 27x27 maze with KEYS keys. Each
## key taken is a split against your best run, whose ghost (RaceGhost) runs with you. Medals are paced on the route
## (spawn, every key, the exit, walked): BRONZE for escaping, SILVER at an A grade's pace, GOLD at an S grade's, DEVIL
## beyond; each pays its shards once a week. this_week() is the only clock read: everything else takes the week.

## Week 1 began with CrazyGames' board season: Monday 12 Oct 2026, 09:00 UTC.
const FIRST_WEEK := "2026-10-12T09:00:00"
const WEEK_SECONDS := 7 * 86400
## The campaign floor it borrows its rules from (Act 2, floor 4: a 27x27 maze) and its keys (FloorLayout.SIGIL_COUNT
## is 2): the long maze.
const STAGE_FLOOR := 14
const KEYS := 4
## The deck its one rule card comes from.
const DECK_ACT := 2
## Medals, worst to best. A pace is run time over par (the route at a walk): an A and an S grade's
## (StageRule.GRADE_PACE) for SILVER and GOLD, DEVIL_PACE for a near-perfect run. Tune after playtests.
const MEDALS: Array[String] = ["bronze", "silver", "gold", "devil"]
const DEVIL_PACE := 1.05
const MEDAL_SHARDS := {"bronze": 10, "silver": 15, "gold": 25, "devil": 40}
const MEDAL_MARKS := {"bronze": "🥉", "silver": "🥈", "gold": "🥇", "devil": "😈"}
## main.gd's CELL_SIZE: the menu prices the medals without loading the floor's scene (a test keeps them equal).
const CELL_M := 2.4
const FEEL := "res://resources/player_feel.tres"

## What this week holds (refresh() starts a new week clean): the best time (0 = none yet), when that run took each
## key, and the medals earned.
static var week := 0
static var best := 0.0
static var splits: Array[float] = []
static var medals: Array[String] = []
## Your best run's ghost (RaceGhost samples), kept on this device only.
static var ghost_path := "user://race_ghost.bin"


static func this_week() -> int:
	return week_of(Time.get_unix_time_from_system())


static func week_of(unix: float) -> int:
	return floori((unix - _first_unix()) / WEEK_SECONDS) + 1


## Seconds from `unix` until week `n` ends and the next maze opens.
static func seconds_left(n: int, unix: float) -> float:
	return _first_unix() + n * WEEK_SECONDS - unix


static func seed_of(n: int) -> int:
	return hash(["long_night", n]) | 1


## The week's rule card, the same for everyone.
static func cards(n: int) -> Array[String]:
	return Cards.draw(seed_of(n), DECK_ACT, 1, [])


## Week `n`'s maze, exactly as the floor builds it (in a race RunState.mod folds only the week's card).
static func layout(n: int) -> FloorLayout:
	var rule := StageRule.for_floor(STAGE_FLOOR)
	var ids := cards(n)
	return FloorLayout.generate(hash([seed_of(n), STAGE_FLOOR]), roundi(Cards.fold(ids, "rooms", rule.rooms)),
			roundi(Cards.fold(ids, "keys", KEYS)), rule.box_empties)


## Seconds to walk the route at `walk` m/s: from the spawn through every key box, in the best order, to the exit.
static func par(maze: FloorLayout, walk: float) -> float:
	return tour_tiles(maze) * CELL_M / walk


## Week `n`'s par at the game's own walking pace (the dashboard's medal times).
static func par_of(n: int) -> float:
	return par(layout(n), (load(FEEL) as PlayerFeel).walk_speed)


## Tiles on the shortest walk from the spawn through every key box to the exit (every order tried: a handful of keys).
static func tour_tiles(maze: FloorLayout) -> int:
	var maps := {maze.spawn: maze.distances(FloorLayout.ANY, maze.spawn)}
	for cell in maze.sigils:
		maps[cell] = maze.distances(FloorLayout.ANY, cell)
	var stops: Array[Vector2i] = maze.sigils.duplicate()
	return _shortest(maze, maps, maze.spawn, stops)


static func _shortest(maze: FloorLayout, maps: Dictionary, at: Vector2i, left: Array[Vector2i]) -> int:
	var from: PackedInt32Array = maps[at]
	if left.is_empty():
		return maxi(from[maze.exit.y * maze.size + maze.exit.x], 0)
	var shortest := -1
	for cell in left:
		var rest: Array[Vector2i] = left.duplicate()
		rest.erase(cell)
		var total := maxi(from[cell.y * maze.size + cell.x], 0) + _shortest(maze, maps, cell, rest)
		if shortest < 0 or total < shortest:
			shortest = total
	return shortest


## The time each medal past BRONZE (any escape) asks for, on a route of `par_s` seconds.
static func medal_times(par_s: float) -> Dictionary:
	return {"silver": par_s * StageRule.GRADE_PACE[1], "gold": par_s * StageRule.GRADE_PACE[0], "devil": par_s * DEVIL_PACE}


static func medal(time: float, par_s: float) -> String:
	var times := medal_times(par_s)
	for id: String in ["devil", "gold", "silver"]:
		if time <= times[id]:
			return id
	return "bronze"


## The best medal earned this week ("" for none).
static func top_medal() -> String:
	var top := ""
	for id in MEDALS:
		if medals.has(id):
			top = id
	return top


## It's week `n`: a new week starts with no best, splits or medals.
static func refresh(n: int) -> void:
	if week != n:
		week = n
		best = 0.0
		splits.clear()
		medals.clear()


## An escape from week `n`'s maze in `time` (`run_splits`: when it took each key). Keeps the week's best and its
## splits, and each medal up to the one earned pays MEDAL_SHARDS the first time this week; saved at once.
## Returns {best: a new best, medal, shards}.
static func finish(n: int, time: float, run_splits: Array[float], par_s: float) -> Dictionary:
	refresh(n)
	var got := medal(time, par_s)
	var shards := 0
	for id in MEDALS.slice(0, MEDALS.find(got) + 1):
		if not medals.has(id):
			medals.append(id)
			shards += MEDAL_SHARDS[id]
	var new_best := best <= 0.0 or time < best
	if new_best:
		best = time
		splits = run_splits.duplicate()
	MetaState.earn(shards)
	return {"best": new_best, "medal": got, "shards": shards}


## "6:41.3"
static func format(seconds: float) -> String:
	var tenths := roundi(maxf(seconds, 0.0) * 10.0)
	@warning_ignore("integer_division")
	return "%d:%02d.%d" % [tenths / 600, (tenths % 600) / 10, tenths % 10]


## The share line: "FearFlip · The Long Night #3 🥇 6:41.3".
static func share_text(n: int, time: float, got: String) -> String:
	return "FearFlip · The Long Night #%d %s %s" % [n, MEDAL_MARKS.get(got, ""), format(time)]


static func save_ghost(n: int, samples: PackedFloat32Array) -> void:
	var file := FileAccess.open(ghost_path, FileAccess.WRITE)
	if file != null:
		file.store_var([n, samples])


## Week `n`'s best run on this device (empty for none: a new week, another device, a cleared save).
static func load_ghost(n: int) -> PackedFloat32Array:
	var file := FileAccess.open(ghost_path, FileAccess.READ)
	if file == null:
		return PackedFloat32Array()
	var data: Variant = file.get_var()
	if data is Array and data.size() == 2 and data[0] == n and data[1] is PackedFloat32Array:
		return data[1]
	return PackedFloat32Array()


static func load_state(cfg: ConfigFile) -> void:
	week = cfg.get_value("race", "week", 0)
	best = cfg.get_value("race", "best", 0.0)
	splits.assign(cfg.get_value("race", "splits", []))
	medals.assign(cfg.get_value("race", "medals", []))


static func save_state(cfg: ConfigFile) -> void:
	cfg.set_value("race", "week", week)
	cfg.set_value("race", "best", best)
	cfg.set_value("race", "splits", splits)
	cfg.set_value("race", "medals", medals)


static func _first_unix() -> int:
	return Time.get_unix_time_from_datetime_string(FIRST_WEEK)
