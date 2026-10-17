class_name Race
extends RefCounted
## The Long Night (plans/11): one long maze a week, the same for everyone, beside the campaign (a second page on the
## dashboard; it never touches the campaign's save). Its week is CrazyGames' leaderboard season, Monday 09:00 UTC to
## Monday. Run it as often as you like: the best time counts and goes to the board (Portal.submit_time). Everyone
## carries the same kit (no torches, mercy or ranks; the week's one rule card) into a 27x27 maze with KEYS keys. Each
## key taken is a split against your best run, whose ghost (RaceGhost) runs with you. Medals are paced on the route
## (spawn, every key, the exit, walked): BRONZE for escaping, SILVER at an A grade's pace, GOLD at an S grade's, DEVIL
## beyond; each pays its shards once a week. this_week() is the only clock read: everything else takes the week.
## v2 (plans/11): with a SERVER (server/long-night), the best goes there instead, to be checked against the week's maze
## and put on the board from the server; the run just ahead of yours comes back as a rival ghost.

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
## The Long Night server's URL (server/long-night/README.md), "" for none. With none, a new best goes straight from
## this client to the CrazyGames board (v1: anyone can fake one). With one, only the server submits: it verifies the
## run first, and a client-side fallback would leave the board as fakeable as before.
const SERVER := ""
## The longest run the server takes (and whose Flipping Times it knows).
const MAX_RUN := 3600.0

## What this week holds (refresh() starts a new week clean): the best time (0 = none yet), when that run took each
## key, and the medals earned.
static var week := 0
static var best := 0.0
static var splits: Array[float] = []
static var medals: Array[String] = []
## Where the Devil broke through the wall on the best run ([x, y, race seconds]; empty if it didn't): the server lets
## the tape through that wall from then on.
static var breach: Array = []
## The best (ms) the server has answered for, and why it refused it ("" = taken). A best it hasn't answered goes again
## (after a network failure, or from the device that holds its tape).
static var sent := 0
static var refused := ""
## Your rank on the board when last shown (0 = not yet): whoever has taken that place since is named on the dashboard.
static var seen_rank := 0
## No CrazyGames login on the last try: a guest's time stays off the board.
static var guest := false
## Your best run's ghost (RaceGhost samples), kept on this device only.
static var ghost_path := "user://race_ghost.bin"
static var server := SERVER


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
	return FloorLayout.generate(floor_seed(n), roundi(Cards.fold(ids, "rooms", rule.rooms)),
			roundi(Cards.fold(ids, "keys", KEYS)), rule.box_empties)


## The floor's seed (RunState.floor_seed in a race): its maze and its Flipping Times.
static func floor_seed(n: int) -> int:
	return hash([seed_of(n), STAGE_FLOOR])


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
		breach.clear()
		sent = 0
		refused = ""
		seen_rank = 0


## An escape from week `n`'s maze in `time` (`run_splits`: when it took each key; `run_breach`: where the Devil broke
## through, if it did). Keeps the week's best with its splits and breach, and each medal up to the one earned pays
## MEDAL_SHARDS the first time this week; saved at once. Returns {best: a new best, medal, shards}.
static func finish(n: int, time: float, run_splits: Array[float], par_s: float, run_breach: Array = []) -> Dictionary:
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
		breach = run_breach.duplicate()
		refused = ""
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
	breach = cfg.get_value("race", "breach", [])
	sent = cfg.get_value("race", "sent", 0)
	refused = cfg.get_value("race", "refused", "")
	seen_rank = cfg.get_value("race", "seen_rank", 0)


static func save_state(cfg: ConfigFile) -> void:
	cfg.set_value("race", "week", week)
	cfg.set_value("race", "best", best)
	cfg.set_value("race", "splits", splits)
	cfg.set_value("race", "medals", medals)
	cfg.set_value("race", "breach", breach)
	cfg.set_value("race", "sent", sent)
	cfg.set_value("race", "refused", refused)
	cfg.set_value("race", "seen_rank", seen_rank)


# --- v2: the server (plans/11; server/long-night) --------------------------------------------------------------------

## The week's best goes to the server if it hasn't answered for it yet, then `done` gets the board ({week, top, around,
## you}: server/long-night/src/index.js::getBoard) or null (offline). A guest sends nothing and reads the board at their
## best time. Nothing at all without a SERVER.
static func sync(done: Callable) -> void:
	if server.is_empty():
		return
	var n := this_week()
	refresh(n)
	var token: String = await Portal.user_token()
	guest = token.is_empty()
	var mine := roundi(best * 1000.0)
	var tape := load_ghost(n)
	if not guest and mine > 0 and sent != mine and not tape.is_empty():
		var answer: Variant = await _call("/run", run_body(token, n, best, splits, tape, breach))
		# An answer either way, taken or refused for a reason no resend changes; a token it couldn't verify is asked again.
		if answer is Dictionary and answer.get("error", "") != "log in":
			sent = mine
			refused = "" if answer.get("ok", false) else str(answer.get("error", "refused"))
			MetaState.save()
	var board: Variant = await _call("/board?%s&v=%d" % [_who(n, token), mine])
	if done.is_valid():
		done.call(board if board is Dictionary else null)


## Week `n`'s rival: the run just ahead of yours on the board ({name, ms, splits, tape}), for `done`; null when there's
## none (you lead, offline, no SERVER).
static func fetch_rival(n: int, done: Callable) -> void:
	if server.is_empty():
		return
	var token: String = await Portal.user_token()
	var rival: Variant = await _call("/ghost?" + _who(n, token))
	if done.is_valid():
		done.call(rival if rival is Dictionary and rival.has("tape") else null)


## The run as the server checks it: the ghost's samples (x, z, yaw every RaceGhost.STEP, then one at the chest) as
## base64 little-endian floats.
static func run_body(token: String, n: int, time: float, run_splits: Array[float], tape: PackedFloat32Array, run_breach: Array) -> Dictionary:
	return {"token": token, "week": n, "time_ms": roundi(time * 1000.0), "splits": run_splits,
			"tape": Marshalls.raw_to_base64(tape.to_byte_array()), "breach": run_breach}


## The ghost samples in a server answer; empty when it carries none.
static func tape_of(answer: Variant) -> PackedFloat32Array:
	if not answer is Dictionary or not answer.get("tape") is String:
		return PackedFloat32Array()
	var samples := Marshalls.base64_to_raw(answer["tape"]).to_float32_array()
	return samples if samples.size() % 3 == 0 else PackedFloat32Array()


## Your CrazyGames user id, read from the token's payload. The server verifies tokens; here it only says whose board.
static func player_of(token: String) -> String:
	var parts := token.split(".")
	if parts.size() != 3:
		return ""
	var body := parts[1].replace("-", "+").replace("_", "/")
	var payload: Variant = JSON.parse_string(Marshalls.base64_to_utf8(body + "=".repeat((4 - body.length() % 4) % 4)))
	return str(payload.get("userId", "")) if payload is Dictionary else ""


## Who took the place you held when you last looked (`seen`): "NAME TOOK YOUR 3RD PLACE BY 0.4 S", or how many passed
## you when that place is off the rows the board sent; "" when nobody did.
static func passed_line(board: Dictionary, seen: int) -> String:
	var you: Variant = board.get("you")
	if seen <= 0 or not you is Dictionary or you.get("rank") == null or int(you["rank"]) <= seen:
		return ""
	for row: Dictionary in board.get("top", []) + board.get("around", []):
		if row.get("rank") != null and int(row["rank"]) == seen and not row.get("me", false):
			return "%s TOOK YOUR %s PLACE BY %.1f S" % [str(row["name"]).to_upper(), ordinal(seen),
					(float(you["ms"]) - float(row["ms"])) / 1000.0]
	return "%d RUNNERS PASSED YOU" % (int(you["rank"]) - seen)


## "1ST", "2ND", "3RD", "11TH", "22ND".
static func ordinal(n: int) -> String:
	var suffix: String = "TH" if n % 100 in [11, 12, 13] else {1: "ST", 2: "ND", 3: "RD"}.get(n % 10, "TH")
	return "%d%s" % [n, suffix]


## The result page's word on the board once a new best has gone to the server (or is still on its way).
static func board_note() -> String:
	if guest:
		return "Log in to CrazyGames to put your time on the board."
	if sent != roundi(best * 1000.0):
		return "Sending your time to the board..."
	if not refused.is_empty():
		return "The board couldn't verify this run (%s)." % refused
	return "Verified and on the board: its top 3 and top 1%, 5% and 10% win trophies when the week ends."


## What the server checks week `n`'s runs against (server/long-night/export_weeks.gd writes every week's): the cells
## open in either world ("1", row by row; both worlds are one maze), the spawn, the exit, the key boxes, and when each
## Flipping Time begins (the only moment the Devil breaks a wall).
static func export_week(n: int) -> Dictionary:
	var maze := layout(n)
	var open := ""
	for i in maze.size * maze.size:
		open += "1" if maze.is_open(FloorLayout.ANY, maze.cell_at(i)) else "0"
	return {"size": maze.size, "open": open, "spawn": [maze.spawn.x, maze.spawn.y], "exit": [maze.exit.x, maze.exit.y],
			"keys": maze.sigils.map(func(cell: Vector2i) -> Array: return [cell.x, cell.y]), "flips": flip_times(n, MAX_RUN)}


## Race seconds at which week `n`'s Flipping Times begin, up to `until`: its FlipSystem stepped from one change to the
## next (in a race nothing else moves it, and a flip never waits for an open spot: both worlds are one maze).
static func flip_times(n: int, until: float) -> Array[float]:
	var flip := FlipSystem.for_floor(floor_seed(n), StageRule.for_floor(STAGE_FLOOR),
			func(key: String, base: float) -> float: return Cards.fold(cards(n), key, base))
	var times: Array[float] = []
	var t := 0.0
	var step := flip.next_forced_in
	while t + step <= until:
		t += step
		flip.advance(step, true, true)
		if flip.forced_active:
			times.append(snappedf(t, 0.001))
		step = flip.forced_left if flip.forced_active else flip.next_forced_in
	return times


## The rules every week's run is checked by, read from the game (export_weeks.gd writes them beside the weeks).
static func server_rules() -> Dictionary:
	var feel := load(FEEL) as PlayerFeel
	var main: Dictionary = (load("res://scripts/main.gd") as GDScript).get_script_constant_map()
	return {"cell": CELL_M, "step": RaceGhost.STEP, "walk": feel.walk_speed, "sprint": feel.walk_speed * feel.sprint_multiplier,
			"sprint_time": feel.sprint_time, "rest_time": feel.sprint_recover_time, "lookahead": main["THIN_WALL_LOOKAHEAD"],
			"chest": main["CHEST_VIEW_DISTANCE"]}


## You on the board: your CrazyGames id, or a guest's best (ms) on this device.
static func _who(n: int, token: String) -> String:
	var player := player_of(token)
	return "week=%d&%s" % [n, "player=" + player.uri_encode() if not player.is_empty() else "ms=%d" % roundi(best * 1000.0)]


## One request to the server: its JSON answer (a refusal included), or null when it can't be reached or failed.
static func _call(path: String, body: Variant = null) -> Variant:
	var tree := Engine.get_main_loop() as SceneTree
	await tree.process_frame  # never mid-setup: a scene's _ready may have asked
	var http := HTTPRequest.new()
	http.timeout = 20.0
	tree.root.add_child(http)
	var result: Array = [HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray()]
	var sent_ok := OK
	if body == null:  # a plain GET: no headers, so the browser needs no CORS preflight for it
		sent_ok = http.request(server + path)
	else:
		sent_ok = http.request(server + path, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(body))
	if sent_ok == OK:
		result = await http.request_completed
	http.queue_free()
	if result[0] != HTTPRequest.RESULT_SUCCESS or result[1] >= 500:
		return null
	return JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())


static func _first_unix() -> int:
	return Time.get_unix_time_from_datetime_string(FIRST_WEEK)
