class_name Cards
extends RefCounted
## Floor variety (plans/06 P3). Every modifier is a card {id, name, text, mods}: the rule cards a floor
## is dealt (a deck per act), the door you pick into it, each act's Gate twist and the Sanctuary.
## RunState.mod() folds a floor's cards and the run's (omens, curse, descents: P4) into one value per
## mod, and LIMITS keep any stack fair. Ranks (P8) join later as more cards of the same shape.

## Mods that count (neutral 0) add up across cards; every other mod is a factor (neutral 1).
const ADDED: Array[String] = ["keys", "chests", "mirror", "follow_flips", "devil_awake", "rare_chest", "omen_pick",
		"flip_charges", "heartbeat", "time_bonus", "devil_early", "creak_range", "feather", "crack_reveal", "ghost_sight", "last_breath", "flash_stun",
		"extra_circles", "beam_hidden", "flip_echo", "quiet_sprint"]
const MAX_KEYS := 5
const MAX_TRAPS := 16
const MIN_FLIP_INTERVAL := 12.0
const MIN_FLIP_COOLDOWN := 3.0
const MIN_CIRCLE_TIME := 2.0
const MIN_ROOMS := 6
## Omens a new profile can be offered; each omen token found adds the next one in OMENS order.
const STARTER_OMENS := 6
const OMEN_CHOICES := 3
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
	"flip_cooldown": Vector2(MIN_FLIP_COOLDOWN, 99.0),
	"flip_charges": Vector2(1.0, 2.0),
}
## Hunt doors are Act 2's new thing, and never lead into an act's first two floors.
const HUNT_FROM_ACT := 2
const HUNT_FROM_FLOOR := 3

## Rule cards (A1): one per floor from its act's deck ("from" = the first act that deals it).
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
	{"id": "quick_veil", "name": "QUICK VEIL", "text": "Your flip recharges 30% faster.", "mods": {"flip_cooldown": 0.7}},
	{"id": "cold_blood", "name": "COLD BLOOD", "text": "Your heartbeat warns you 3 cells earlier.", "mods": {"heartbeat": 3}},
	{"id": "circle_keeper", "name": "CIRCLE KEEPER", "text": "Safe circles drain half as fast.", "mods": {"circle_time": 2.0}},
	{"id": "borrowed_time", "name": "BORROWED TIME", "text": "20 more seconds on every clock. It wakes 5 seconds sooner.", "mods": {"time_bonus": 20, "devil_early": 5}},
	{"id": "keen_eye", "name": "KEEN EYE", "text": "Cracks glow brighter and creak a cell farther away.", "mods": {"trap_cue": 1.5, "creak_range": 1}},
	{"id": "night_owl", "name": "NIGHT OWL", "text": "NIGHTMARE's fog thins by a third.", "mods": {"nightmare_fog": 0.7}},
	{"id": "twin_flip", "name": "TWIN FLIP", "text": "Two flip charges.", "mods": {"flip_charges": 1}},
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
## Flashlights (plans/06 D2): bought at the Altar (Unlocks), one carried into every run. Side-grades, not raw power.
const TORCHES: Array[Dictionary] = [
	{"id": "old_torch", "name": "OLD TORCH", "text": "A steady cold beam. It has never let you down.", "mods": {}},
	{"id": "lantern", "name": "LANTERN", "text": "A wide warm glow: more of the corridor, less of the distance.", "mods": {"beam_angle": 1.6, "beam_range": 0.7}},
	{"id": "uv_light", "name": "UV LIGHT", "text": "A dim violet beam. Your map marks hidden cracks within 3 cells.", "mods": {"beam_energy": 0.7, "crack_reveal": 3}},
	{"id": "camera_flash", "name": "CAMERA FLASH", "text": "Once a floor, F fires a flash: if it's close and in sight, it freezes for 3 seconds.", "mods": {"flash_stun": 1}},
]
## Hidden mercy (plans/06 G3, MetaState.mercy_on): one more safe circle, a slower Devil, fewer Director hints.
const MERCY := {"id": "mercy", "name": "MERCY", "text": "", "mods": {"extra_circles": 1, "devil_speed": 0.95, "hint_stretch": 1.0 / 0.7}}
## After a Gate (not the last): bank and leave, or push your luck into the next act (plans/06 §2).
const GATE_CHOICES: Array[Dictionary] = [
	{"id": "return", "name": "RETURN", "text": "Bank your shards and climb back out. The next act stays open.", "mods": {}},
	{"id": "descend", "name": "DESCEND", "text": "Keep your omens and go deeper: half again the shards. Revives don't refill.", "mods": {"shards": 1.5}},
]


static func find(id: String) -> Dictionary:
	return _lookup(id)[0]


## "rule", "door", "gate", "sanctuary", "omen", "curse", "choice" or "torch" ("" for an unknown id).
static func kind(id: String) -> String:
	return _lookup(id)[1]


static func deck(act: int) -> Array[String]:
	var ids: Array[String] = []
	for card: Dictionary in RULES:
		if card["from"] <= act:
			ids.append(card["id"])
	return ids


## `count` rule cards from `act`'s deck, none of them in `exclude`, shuffled by `seed_value`.
static func draw(seed_value: int, act: int, count: int, exclude: Array) -> Array[String]:
	var pool: Array[String] = []
	for id in deck(act):
		if not exclude.has(id):
			pool.append(id)
	_shuffle(pool, hash([seed_value, "rules"]))
	return pool.slice(0, count)


## A floor's cards: the Gate's or the Sanctuary's own, else the door taken (a Mystery also shows which door
## it was) and the rule cards it deals, none repeated from `exclude` (the floor before). The game's first
## floor has none: the core loop comes first.
static func deal(seed_value: int, rule: StageRule, door: String, exclude: Array) -> Array[String]:
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
	var count := 0 if door == "shrine" else (2 if door == "hunt" else 1)
	cards.append_array(draw(seed_value, rule.act, count, exclude))
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
				[OMENS, "omen"], [CURSES, "curse"], [GATE_CHOICES, "choice"], [TORCHES, "torch"], [[MERCY], "mercy"]]:
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
