class_name Cards
extends RefCounted
## Floor variety (plans/06 P3). Every modifier is a card {id, name, text, mods}: the rule cards a floor
## is dealt (a deck per act), the door you pick into it, each act's Gate twist and the Sanctuary.
## RunState.mod() folds a floor's cards and the run's (omens, curse, descents: P4, the Nightmare Rank: P8) into one
## value per mod, and LIMITS keep any stack fair.

## Mods that count (neutral 0) add up across cards; every other mod is a factor (neutral 1).
const ADDED: Array[String] = ["keys", "chests", "mirror", "follow_flips", "devil_awake", "rare_chest", "omen_pick",
		"heartbeat", "time_bonus", "devil_early", "creak_range", "feather", "crack_reveal", "ghost_sight", "last_breath", "flash_stun",
		"extra_circles", "beam_hidden", "flip_echo", "quiet_sprint"]
const MAX_KEYS := 5
const MAX_TRAPS := 16
const MIN_FLIP_INTERVAL := 12.0
## However the cards stack, a Flipping Time holds you at least this long (s).
const MIN_FLIP_DURATION := 5.0
const MIN_CIRCLE_TIME := 2.0
const MIN_ROOMS := 6
## Omens a new profile can be offered; each omen token found adds the next one in OMENS order.
const STARTER_OMENS := 6
const OMEN_CHOICES := 3
const MAX_RANK := 20
## Every rank pays this much more (a factor, like every "shards" mod): rank 20 alone pays about x2.65.
const RANK_SHARDS := 1.05
## Folded values are held inside these (in each system's own units), whatever the stack.
const LIMITS := {
	"devil_speed": Vector2(0.8, 1.3),
	"devil_distance": Vector2(StageRule.MIN_DEVIL_SPAWN_DISTANCE, 99.0),
	"trap_cue": Vector2(StageRule.MIN_TRAP_CUE, 1.0),
	"flip_interval": Vector2(MIN_FLIP_INTERVAL, 999.0),
	"circle_time": Vector2(MIN_CIRCLE_TIME, 99.0),
	"clock": Vector2(0.75, 1.5),
	"keys": Vector2(1.0, MAX_KEYS),
	"chests": Vector2(0.0, 3.0),
	"traps": Vector2(0.0, MAX_TRAPS),
	"circles": Vector2(1.0, 6.0),
	"rooms": Vector2(MIN_ROOMS, 99.0),
	"shards": Vector2(0.5, 3.0),
	"flip_duration": Vector2(MIN_FLIP_DURATION, 99.0),
}
## Hunt doors are Act 2's new thing, and never lead into an act's first two floors.
const HUNT_FROM_ACT := 2
const HUNT_FROM_FLOOR := 3

## Rule cards (A1): one per floor from its act's deck ("from" = the first act that deals it). An "event" card joins
## the decks only while its event runs (LiveOps, plans/06 P9); "art" names card art shared by a set.
const RULES: Array[Dictionary] = [
	{"id": "thick_fog", "from": 1, "name": "THICK FOG", "text": "Fog rolls in. You see half as far.", "mods": {"fog": 1.8}},
	{"id": "safe_haven", "from": 1, "name": "SAFE HAVEN", "text": "Twice the safe circles, but they drain twice as fast.", "mods": {"circles": 2.0, "circle_time": 0.5}},
	{"id": "blackout", "from": 1, "name": "BLACKOUT", "text": "The ceiling lights are dead. Your flashlight is all you have.", "mods": {"lights": 0.0}},
	{"id": "hungry_dark", "from": 2, "name": "HUNGRY DARK", "text": "It runs faster tonight, and every shard counts half again.", "mods": {"devil_speed": 1.15, "shards": 1.5}},
	{"id": "short_fuse", "from": 2, "name": "SHORT FUSE", "text": "Flipping Time comes twice as often.", "mods": {"flip_interval": 0.5}},
	{"id": "cracked_earth", "from": 2, "name": "CRACKED EARTH", "text": "Twice the cracked floors, but every crack glows.", "mods": {"traps": 2.0, "trap_cue": 2.0}},
	{"id": "greed", "from": 2, "name": "GREED", "text": "A chest waits down a dead end. It wakes sooner.", "mods": {"chests": 1, "devil_delay": 0.6}},
	{"id": "deaf_night", "from": 3, "name": "DEAF NIGHT", "text": "No music. Only your heartbeat says it's close.", "mods": {"music": 0.0}},
	{"id": "mirror_night", "from": 3, "name": "MIRROR NIGHT", "text": "In NIGHTMARE your controls are mirrored.", "mods": {"mirror": 1}},
	{"id": "static", "from": 3, "name": "STATIC", "text": "The map is gone. Remember the way.", "mods": {"minimap": 0.0}},
	{"id": "tight_clock", "from": 4, "name": "TIGHT CLOCK", "text": "Less time, more shards.", "mods": {"clock": 0.85, "shards": 1.3}},
	{"id": "relentless", "from": 5, "name": "RELENTLESS", "text": "WAKE no longer slows it down.", "mods": {"follow_flips": 1}},
	{"id": "blood_moon", "from": 2, "event": "blood_moon", "art": "blood_moon", "name": "BLOOD MOON", "text": "The moon is red. It runs faster, and every shard counts double.", "mods": {"devil_speed": 1.15, "shards": 2.0}},
	{"id": "harvest", "from": 2, "event": "blood_moon", "art": "blood_moon", "name": "HARVEST", "text": "Two chests wait down dead ends. It wakes sooner.", "mods": {"chests": 2, "devil_delay": 0.7}},
	{"id": "whiteout", "from": 1, "event": "frozen_nightmare", "art": "frozen_nightmare", "name": "WHITEOUT", "text": "Snow-blind fog fills the maze, but the frozen cracks glow.", "mods": {"fog": 1.6, "trap_cue": 1.5}},
	{"id": "deep_freeze", "from": 1, "event": "frozen_nightmare", "art": "frozen_nightmare", "name": "DEEP FREEZE", "text": "The cold slows it down, but NIGHTMARE holds you longer.", "mods": {"devil_speed": 0.9, "flip_duration": 1.3}},
	{"id": "frozen_wards", "from": 1, "event": "frozen_nightmare", "art": "frozen_nightmare", "name": "FROZEN WARDS", "text": "Safe circles freeze solid: they hold twice as long, but there are fewer.", "mods": {"circle_time": 2.0, "circles": 0.7}},
]
## Doors into the next floor (A2). "safe" doors never raise the danger.
const DOORS: Array[Dictionary] = [
	{"id": "normal", "name": "NORMAL", "text": "The floor's own rule card. Nothing more.", "mods": {}, "safe": true},
	{"id": "shrine", "name": "SHRINE", "text": "A quiet floor with no rule card. Clear it and pick an omen; fewer shards.", "mods": {"shards": 0.75, "omen_pick": 1}, "safe": true},
	{"id": "vault", "name": "VAULT", "text": "One more key and two chests down dead ends. It wakes sooner.", "mods": {"keys": 1, "chests": 2, "devil_delay": 0.6}},
	{"id": "hunt", "name": "HUNT", "text": "Two rule cards, double shards and a rare chest.", "mods": {"shards": 2.0, "rare_chest": 1}},
	{"id": "mystery", "name": "MYSTERY", "text": "One of the other doors; you find out inside. A quarter more shards.", "mods": {"shards": 1.25}},
]
## Each act's Gate (F10, A3): its F8 difficulty plus one twist, never a raw spike.
const GATES: Array[Dictionary] = [
	{"id": "first_blood", "name": "FIRST BLOOD", "text": "It is awake from the start, but far away.", "mods": {"devil_awake": 1}},
	{"id": "ritual", "name": "RITUAL", "text": "Five keys. Flipping Time every 25 seconds.", "mods": {"keys": 3, "flip_interval": 0.55}},
	{"id": "mind_break", "name": "MIND BREAK", "text": "Flipping Time keeps coming back, and there is no map.", "mods": {"flip_interval": 0.6, "minimap": 0.0}},
	{"id": "precision_hell", "name": "PRECISION HELL", "text": "A gauntlet of cracked floors on a tight clock.", "mods": {"traps": 1.8, "clock": 0.85}},
	{"id": "the_breaker", "name": "THE BREAKER", "text": "Awake from the start, and WAKE won't slow it. Run.", "mods": {"devil_awake": 1, "follow_flips": 1}},
]
## The Sanctuary (F5, A4): the act's breather.
const SANCTUARY := {"id": "sanctuary", "name": "SANCTUARY", "text": "A small, quiet floor. Nothing hunts you here. Leave with an omen.", "mods": {"devil": 0.0, "rooms": 0.6, "omen_pick": 1}}
## Omens (B1): pick 1 of 3 at Shrines, Sanctuaries, Gates you descend from and a later act's start; kept
## all run. In unlock order: the first STARTER_OMENS, then one per omen token. "needs" waits for that system.
const OMENS: Array[Dictionary] = [
	{"id": "quick_veil", "name": "QUICK VEIL", "text": "NIGHTMARE lets go of you 30% sooner.", "mods": {"flip_duration": 0.7}},
	{"id": "cold_blood", "name": "COLD BLOOD", "text": "Your heartbeat warns you 3 cells earlier.", "mods": {"heartbeat": 3}},
	{"id": "circle_keeper", "name": "CIRCLE KEEPER", "text": "Safe circles drain half as fast.", "mods": {"circle_time": 2.0}},
	{"id": "borrowed_time", "name": "BORROWED TIME", "text": "20 more seconds on every clock. It wakes 5 seconds sooner.", "mods": {"time_bonus": 20, "devil_early": 5}},
	{"id": "keen_eye", "name": "KEEN EYE", "text": "Cracks glow brighter and creak a cell farther away.", "mods": {"trap_cue": 1.5, "creak_range": 1}},
	{"id": "night_owl", "name": "NIGHT OWL", "text": "NIGHTMARE's fog thins by a third.", "mods": {"nightmare_fog": 0.7}},
	{"id": "twin_flip", "name": "SOUND SLEEPER", "text": "Flipping Time comes a quarter less often.", "mods": {"flip_interval": 1.25}},
	{"id": "feather_step", "name": "FEATHER STEP", "text": "Once a floor, a cracked floor holds when it should give way.", "mods": {"feather": 1}},
	{"id": "cartographer", "name": "CARTOGRAPHER", "text": "The map marks hidden cracks within 6 cells.", "mods": {"crack_reveal": 6}},
	{"id": "locksmith", "name": "LOCKSMITH", "text": "Keys glow brighter, and one more chest waits down a dead end.", "mods": {"key_glow": 2.0, "chests": 1}},
	{"id": "blood_pact", "name": "BLOOD PACT", "text": "Half again the shards. It runs 10% faster.", "mods": {"shards": 1.5, "devil_speed": 1.1}},
	{"id": "ghost_sight", "name": "GHOST SIGHT", "text": "You see the other world's walls, faintly.", "mods": {"ghost_sight": 1}},
	{"id": "last_breath", "name": "LAST BREATH", "text": "Once a floor, a catch sends you back to your last safe circle.", "mods": {"last_breath": 1}},
	{"id": "lantern_heart", "name": "LANTERN HEART", "text": "Your flashlight never gives you away.", "mods": {"beam_hidden": 1}},
	{"id": "echo_step", "name": "ECHO STEP", "text": "Every flip leaves an echo it chases instead of you.", "mods": {"flip_echo": 1}},
	{"id": "soft_soles", "name": "SOFT SOLES", "text": "It can't hear you sprint.", "mods": {"quiet_sprint": 1}},
]
## Curses (B2): offered at a run's start once Act 1 is cleared; one lies on every floor of the run. "rule" is
## the rule card it doubles, which the run's floors then never deal.
const CURSES: Array[Dictionary] = [
	{"id": "no_curse", "name": "NO CURSE", "text": "Play it straight.", "mods": {}},
	{"id": "curse_blackout", "rule": "blackout", "name": "BLACKOUT", "text": "No ceiling light on any floor of this run. +40% shards.", "mods": {"lights": 0.0, "shards": 1.4}},
	{"id": "curse_hungry_dark", "rule": "hungry_dark", "name": "HUNGRY DARK", "text": "It runs 15% faster all run. +50% shards.", "mods": {"devil_speed": 1.15, "shards": 1.5}},
	{"id": "curse_short_fuse", "rule": "short_fuse", "name": "SHORT FUSE", "text": "Flipping Time twice as often all run. +40% shards.", "mods": {"flip_interval": 0.5, "shards": 1.4}},
	{"id": "curse_deaf_night", "rule": "deaf_night", "name": "DEAF NIGHT", "text": "No music all run, only your heartbeat. +25% shards.", "mods": {"music": 0.0, "shards": 1.25}},
]
## Cursed Week (plans/06 E6, P9): one a week, picked by the week number, offered with the run-start curses. A cost, a
## consolation and more shards than most curses.
const WEEKLY: Array[Dictionary] = [
	{"id": "week_blood_tide", "art": "cursed_week", "name": "BLOOD TIDE", "text": "It runs 10% faster all run, but the ceiling lights burn brighter. +60% shards.", "mods": {"devil_speed": 1.1, "lights": 1.5, "shards": 1.6}},
	{"id": "week_long_night", "art": "cursed_week", "name": "LONG NIGHT", "text": "15% less time on every clock, but a chest waits on every floor. +50% shards.", "mods": {"clock": 0.85, "chests": 1, "shards": 1.5}},
	{"id": "week_blind", "art": "cursed_week", "name": "BLIND WEEK", "text": "Thick fog all run, but your map marks cracks within 3 cells. +50% shards.", "mods": {"fog": 1.5, "crack_reveal": 3, "shards": 1.5}},
	{"id": "week_restless_dead", "art": "cursed_week", "name": "RESTLESS DEAD", "text": "It wakes far sooner, but every floor has one more safe circle. +50% shards.", "mods": {"devil_delay": 0.6, "extra_circles": 1, "shards": 1.5}},
	{"id": "week_broken_floors", "art": "cursed_week", "name": "BROKEN FLOORS", "text": "Half again the cracked floors, but every crack glows. +50% shards.", "mods": {"traps": 1.5, "trap_cue": 1.4, "shards": 1.5}},
	{"id": "week_quicksilver", "art": "cursed_week", "name": "QUICKSILVER", "text": "Flipping Time comes far sooner, but lets go of you sooner. +50% shards.", "mods": {"flip_interval": 0.7, "flip_duration": 0.8, "shards": 1.5}},
	{"id": "week_silent", "art": "cursed_week", "name": "SILENT WEEK", "text": "No music all run, but your heartbeat warns you 2 cells earlier. +40% shards.", "mods": {"music": 0.0, "heartbeat": 2, "shards": 1.4}},
	{"id": "week_dark", "art": "cursed_week", "name": "DARK WEEK", "text": "No ceiling light all run, but your beam reaches a third farther. +50% shards.", "mods": {"lights": 0.0, "beam_range": 1.3, "shards": 1.5}},
]
## Events (plans/06 E7, P9): a card set (RULES with this "event") and cosmetics (Unlocks.ALTAR items with it) that switch
## on by date: "MM-DD", both days in, a span may cross the new year.
const EVENTS: Array[Dictionary] = [
	{"id": "blood_moon", "name": "BLOOD MOON", "from": "10-24", "to": "11-02", "text": "Halloween in the maze: a red moon over the floors, double shards when it rises, and two cosmetics at the Altar."},
	{"id": "frozen_nightmare", "name": "FROZEN NIGHTMARE", "from": "12-15", "to": "01-07", "text": "Winter in the maze: whiteouts, deep freezes and frozen wards on the floors, and two cosmetics at the Altar."},
]
## Flashlights (plans/06 D2): bought at the Altar (Unlocks), one carried into every run. Side-grades, not raw power.
const TORCHES: Array[Dictionary] = [
	{"id": "old_torch", "name": "OLD TORCH", "text": "A steady cold beam. It has never let you down.", "mods": {}},
	{"id": "lantern", "name": "LANTERN", "text": "A wide warm glow: more of the corridor, less of the distance.", "mods": {"beam_angle": 1.6, "beam_range": 0.7}},
	{"id": "uv_light", "name": "UV LIGHT", "text": "A dim violet beam. Your map marks hidden cracks within 3 cells.", "mods": {"beam_energy": 0.7, "crack_reveal": 3}},
	{"id": "camera_flash", "name": "CAMERA FLASH", "text": "Once a floor, F fires a flash: if it's close and in sight, it freezes for 3 seconds.", "mods": {"flash_stun": 1}},
]
## Hidden mercy (plans/06 G3, MetaState.mercy_on): one more safe circle, a slower Devil, fewer Director hints.
const MERCY := {"id": "mercy", "name": "MERCY", "text": "", "mods": {"extra_circles": 1, "devil_speed": 0.95, "hint_stretch": 1.0 / 0.7}}
## Nightmare Ranks (plans/06 D7, P8): opened by the first floor-50 clear, one more per Gate cleared at your top rank.
## Rank n plays every rank up to n, Hades-Heat style: each adds one rule and pays RANK_SHARDS more.
const RANKS: Array[Dictionary] = [
	{"id": "rank_1", "name": "RESTLESS", "text": "It wakes 15% sooner.", "mods": {"devil_delay": 0.85, "shards": RANK_SHARDS}},
	{"id": "rank_2", "name": "SHORT NIGHT", "text": "5% less time on every clock.", "mods": {"clock": 0.95, "shards": RANK_SHARDS}},
	{"id": "rank_3", "name": "FEWER HAVENS", "text": "Fewer safe circles.", "mods": {"circles": 0.7, "shards": RANK_SHARDS}},
	{"id": "rank_4", "name": "QUICKENING", "text": "Flipping Time comes around 10% sooner.", "mods": {"flip_interval": 0.9, "shards": RANK_SHARDS}},
	{"id": "rank_5", "name": "BRITTLE", "text": "A quarter more cracked floors.", "mods": {"traps": 1.25, "shards": RANK_SHARDS}},
	{"id": "rank_6", "name": "THIN WARDS", "text": "Safe circles drain a fifth faster.", "mods": {"circle_time": 0.8, "shards": RANK_SHARDS}},
	{"id": "rank_7", "name": "HEAVY VEIL", "text": "NIGHTMARE holds you a fifth longer.", "mods": {"flip_duration": 1.2, "shards": RANK_SHARDS}},
	{"id": "rank_8", "name": "DIM", "text": "The ceiling lights burn at half strength.", "mods": {"lights": 0.5, "shards": RANK_SHARDS}},
	{"id": "rank_9", "name": "MIST", "text": "The fog is a fifth thicker.", "mods": {"fog": 1.2, "shards": RANK_SHARDS}},
	{"id": "rank_10", "name": "HUNGER", "text": "It runs 5% faster.", "mods": {"devil_speed": 1.05, "shards": RANK_SHARDS}},
	{"id": "rank_11", "name": "QUIET CRACKS", "text": "Cracks are a fifth harder to see.", "mods": {"trap_cue": 0.8, "shards": RANK_SHARDS}},
	{"id": "rank_12", "name": "SHORTER NIGHT", "text": "Another 5% off every clock.", "mods": {"clock": 0.95, "shards": RANK_SHARDS}},
	{"id": "rank_13", "name": "RED MIST", "text": "NIGHTMARE's fog thickens by a fifth.", "mods": {"nightmare_fog": 1.2, "shards": RANK_SHARDS}},
	{"id": "rank_14", "name": "THIRD KEY", "text": "One more key on every floor.", "mods": {"keys": 1, "shards": RANK_SHARDS}},
	{"id": "rank_15", "name": "STARVED", "text": "It runs another 5% faster.", "mods": {"devil_speed": 1.05, "shards": RANK_SHARDS}},
	{"id": "rank_16", "name": "DULL HEART", "text": "Your heartbeat warns you 2 cells later.", "mods": {"heartbeat": -2, "shards": RANK_SHARDS}},
	{"id": "rank_17", "name": "HOLLOW WARDS", "text": "Safe circles drain another fifth faster.", "mods": {"circle_time": 0.8, "shards": RANK_SHARDS}},
	{"id": "rank_18", "name": "EAGER", "text": "It wakes another 15% sooner.", "mods": {"devil_delay": 0.85, "shards": RANK_SHARDS}},
	{"id": "rank_19", "name": "FRENZY", "text": "Flipping Time comes around another 10% sooner.", "mods": {"flip_interval": 0.9, "shards": RANK_SHARDS}},
	{"id": "rank_20", "name": "NO REFUGE", "text": "WAKE no longer slows it down.", "mods": {"follow_flips": 1, "shards": RANK_SHARDS}},
]
## After a Gate: bank and leave, or push your luck into the next act, or below the last into the Abyss (plans/06 §2).
const GATE_CHOICES: Array[Dictionary] = [
	{"id": "return", "name": "RETURN", "text": "Bank your shards and climb back out. The next act stays open.", "mods": {}},
	{"id": "descend", "name": "DESCEND", "text": "Keep your omens and go deeper: half again the shards. Revives don't refill.", "mods": {"shards": 1.5}},
]


static func find(id: String) -> Dictionary:
	return _lookup(id)[0]


## "rule", "door", "gate", "sanctuary", "omen", "curse", "choice", "torch", "mercy" or "rank" ("" for an unknown id).
static func kind(id: String) -> String:
	return _lookup(id)[1]


## `act`'s rule cards, and `event`'s while it runs.
static func deck(act: int, event := "") -> Array[String]:
	var ids: Array[String] = []
	for card: Dictionary in RULES:
		if card["from"] <= act and card.get("event", event) == event:
			ids.append(card["id"])
	return ids


## `count` rule cards from `act`'s deck (with `event`'s), none of them in `exclude`, shuffled by `seed_value`.
static func draw(seed_value: int, act: int, count: int, exclude: Array, event := "") -> Array[String]:
	var pool: Array[String] = []
	for id in deck(act, event):
		if not exclude.has(id):
			pool.append(id)
	_shuffle(pool, hash([seed_value, "rules"]))
	return pool.slice(0, count)


## A floor's cards: the Gate's or the Sanctuary's own, else the door taken (a Mystery also shows which door
## it was) and the floor's rule cards (one more through a Hunt, one fewer through a Shrine), none repeated from
## `exclude` (the floor before), from the act's deck and the running `event`'s cards. The game's first floor has none:
## the core loop comes first.
static func deal(seed_value: int, rule: StageRule, door: String, exclude: Array, event := "") -> Array[String]:
	var cards: Array[String] = []
	if rule.is_gate:
		cards.append(GATES[rule.act - 1]["id"])
		return cards
	if rule.is_sanctuary:
		cards.append(SANCTUARY["id"])
		return cards
	if rule.floor_number == 1:
		return cards
	if door == "mystery":
		cards.append(door)
		door = _mystery(seed_value, rule, exclude)
		cards.append(door)
	elif door != "normal" and door != "":
		cards.append(door)
	var count := rule.rule_cards + (1 if door == "hunt" else 0) - (1 if door == "shrine" else 0)
	cards.append_array(draw(seed_value, rule.act, count, exclude, event))
	return cards


## Doors lead into every floor but the Sanctuary and the Gate (they play their own card).
static func offers_doors(rule: StageRule) -> bool:
	return not rule.is_gate and not rule.is_sanctuary


## Three different doors into `rule`'s floor, at least one of them safe; never a Shrine twice in a row
## (`last_door` = the door taken into the floor just cleared).
static func doors(seed_value: int, rule: StageRule, last_door: String) -> Array[String]:
	var pool := _open_doors(rule)
	if last_door == "shrine":
		pool.erase("shrine")
	_shuffle(pool, hash([seed_value, "doors"]))
	var picks := pool.slice(0, 3)
	if not picks.any(_is_safe):
		for id in pool:
			if _is_safe(id):
				picks[2] = id
				break
		_shuffle(picks, hash([seed_value, "door order"]))
	return picks


## The omens a profile can be offered: the starters, the ones it bought at the Altar (`unlocked`), and one more
## per omen token (the first it doesn't own yet, in OMENS order).
static func omen_pool(tokens: int, unlocked: Array = []) -> Array[String]:
	var ids: Array[String] = []
	for i in OMENS.size():
		var id: String = OMENS[i]["id"]
		if OMENS[i].has("needs"):
			continue
		if i < STARTER_OMENS or unlocked.has(id):
			ids.append(id)
		elif tokens > 0:
			ids.append(id)
			tokens -= 1
	return ids


## Up to OMEN_CHOICES different omens from `pool`, none already `held`, shuffled by `seed_value`.
static func omens(seed_value: int, pool: Array[String], held: Array) -> Array[String]:
	var options: Array[String] = []
	for id in pool:
		if not held.has(id):
			options.append(id)
	_shuffle(options, hash([seed_value, "omens"]))
	return options.slice(0, OMEN_CHOICES)


## The rank cards rank `rank` plays: every one up to it.
static func ranks(rank: int) -> Array[String]:
	var ids: Array[String] = []
	for card: Dictionary in RANKS.slice(0, clampi(rank, 0, MAX_RANK)):
		ids.append(card["id"])
	return ids


## The cursed card of `date`'s week (weeks run Monday to Sunday, UTC, like the Daily).
static func weekly(date: String) -> String:
	return WEEKLY[posmod(_week(date), WEEKLY.size())]["id"]


## Days left in `date`'s week, today included: 7 on a Monday, 1 on a Sunday.
static func week_days_left(date: String) -> int:
	return 7 - posmod(Daily.day_index(date) + 3, 7)


## The event running on `date` ({} when none).
static func event_on(date: String) -> Dictionary:
	var day := date.substr(5, 5)
	for event: Dictionary in EVENTS:
		var from: String = event["from"]
		var to: String = event["to"]
		if (day >= from and day <= to) if from <= to else (day >= from or day <= to):
			return event
	return {}


## Weeks since the epoch's first Monday (1970-01-01 was a Thursday).
static func _week(date: String) -> int:
	return floori((Daily.day_index(date) + 3) / 7.0)


## NO CURSE first, then three of the curses, shuffled by `seed_value`.
static func curses(seed_value: int) -> Array[String]:
	var ids: Array[String] = []
	for curse: Dictionary in CURSES.slice(1):
		ids.append(curse["id"])
	_shuffle(ids, hash([seed_value, "curses"]))
	ids = ids.slice(0, 3)
	ids.push_front(CURSES[0]["id"])
	return ids


## `base` folded through every card in `ids` that has `key` (factors multiply, ADDED mods add), then
## held inside LIMITS. RunState.mod() is this over the floor's cards and the run's.
static func fold(ids: Array, key: String, base: float) -> float:
	var value := base
	for id in ids:
		var mods: Dictionary = find(id).get("mods", {})
		if mods.has(key):
			value = value + mods[key] if ADDED.has(key) else value * mods[key]
	if LIMITS.has(key):
		var limit: Vector2 = LIMITS[key]
		value = clampf(value, limit.x, limit.y)
	return value


## id -> [card, kind], built on first use (every fold looks cards up).
static var _by_id := {}


static func _lookup(id: String) -> Array:
	if _by_id.is_empty():
		for entry: Array in [[RULES, "rule"], [DOORS, "door"], [GATES, "gate"], [[SANCTUARY], "sanctuary"],
				[OMENS, "omen"], [CURSES, "curse"], [GATE_CHOICES, "choice"], [TORCHES, "torch"], [[MERCY], "mercy"],
				[RANKS, "rank"], [WEEKLY, "curse"]]:
			for card: Dictionary in entry[0]:
				_by_id[card["id"]] = [card, entry[1]]
	return _by_id.get(id, [{}, ""])


static func _is_safe(id: String) -> bool:
	return find(id).get("safe", false)


static func _open_doors(rule: StageRule) -> Array[String]:
	var ids: Array[String] = []
	for door: Dictionary in DOORS:
		if door["id"] != "hunt" or (rule.act >= HUNT_FROM_ACT and rule.floor_in_act >= HUNT_FROM_FLOOR):
			ids.append(door["id"])
	return ids


## Which door a Mystery was: any other door this floor could have offered (no Shrine right after a Shrine
## floor, `exclude` being the floor before), from the floor's seed.
static func _mystery(seed_value: int, rule: StageRule, exclude: Array) -> String:
	var options := _open_doors(rule)
	options.erase("mystery")
	if exclude.has("shrine"):
		options.erase("shrine")
	_shuffle(options, hash([seed_value, "mystery"]))
	return options[0]


## Fisher-Yates from a seed (Array.shuffle() uses the global RNG, so it would not repeat).
static func _shuffle(items: Array, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Variant = items[i]
		items[i] = items[j]
		items[j] = swap
