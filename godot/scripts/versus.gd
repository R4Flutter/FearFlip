class_name Versus
extends RefCounted
## VERSUS (plans/12): one player is the Devil, the other runs, in a room of two (Net, server/versus). The runner's game
## is the referee: it plays the real floor (Flipping Time, boxes, keys, the exit, the clock, the catch) and tells the
## Devil's game what happened; the Devil's game moves the Devil and says where it is. A match is two rounds on two
## mazes with the roles swapped, and the better runner wins it. The Devil knows where the runner is only from sight
## (down a straight corridor) and sound (footsteps, the map opening; user, 17 Oct 2026: nothing else), so the referee
## never sends the runner's position otherwise (runner_visible). EASY: the runner has the paper map and the Devil Cam
## corner; HARD: neither. This holds the rules, the messages and the match; VersusMatch plays a round.

## The wire: Net sends var_to_bytes([type, ...]) and drops whatever decode() doesn't recognise.
const PROTOCOL := 1
enum { HELLO = 1, START, READY, GO, POS, SEEN, HEARD, EVENT, END, NEXT, PING }
## Net's own notices, queued beside the peer's messages.
const PEER_JOINED := -1
const PEER_LEFT := -2
## Each message's fields after its type, checked on arrival.
const SHAPES := {
	HELLO: [TYPE_INT, TYPE_STRING],  # protocol, name
	START: [TYPE_INT, TYPE_INT, TYPE_INT],  # match seed, hard, round
	READY: [TYPE_INT],  # round: the floor is built
	GO: [TYPE_INT],  # round: the clock starts
	POS: [TYPE_INT, TYPE_FLOAT, TYPE_FLOAT, TYPE_FLOAT, TYPE_FLOAT],  # snap epoch, x, z, facing, speed
	SEEN: [TYPE_FLOAT, TYPE_FLOAT, TYPE_FLOAT, TYPE_FLOAT, TYPE_INT],  # x, z, yaw, speed, flags
	HEARD: [TYPE_INT, TYPE_INT, TYPE_INT],  # cell x, cell y, Sound
	EVENT: [TYPE_INT, TYPE_FLOAT, TYPE_FLOAT],  # Event, a, b
	END: [TYPE_INT, TYPE_INT, TYPE_FLOAT],  # round, Result, seconds
	NEXT: [TYPE_INT],  # round: ready for the next one
	PING: [],
}
## The relay closes a socket that sends more (server/versus).
const MAX_BYTES := 256
const MAX_NAME := 24
## SEEN's flags.
const KNEEL := 1
const MAP_UP := 2
const WINDED := 4
const LIGHT := 8
enum Sound { STEP, SPRINT, MAP }
enum Event { WARN, FLIP, BOX, KEY, EXIT, WAKE, LUNGE, STUN, SNAP }
enum Result { ESCAPED, CAUGHT, TIME, RUNNER_LEFT, DEVIL_LEFT }

## The floor: Act 1's third (25x25: big mazes only), and nothing on it but the maze, its boxes and the exit.
const STAGE_FLOOR := 3
## The Devil sleeps this long (it can look and listen, not move), then tears out of its wall.
const HEAD_START := 20.0
## Hard has no map: the clock gives the runner a little more.
const HARD_CLOCK := 1.2
## The map opening carries this far (path tiles); footsteps carry as in solo (DevilBrain.NOISE_WALK, HEAR_SPRINT_TILES).
const NOISE_MAP := 4
## The Devil sees the runner down a straight corridor this far (the fog hides farther), or anywhere this close by path.
const SIGHT_TILES := 7
const NEAR_TILES := 2
## The Devil's legs on the runner's (PlayerFeel): a little faster at a walk, a short charge and a long rest, enraged
## once the exit opens, slower in WAKE as in solo. Tune after playtests (plans/12 V6).
const DEVIL_WALK := 1.1
const DEVIL_CHARGE := 1.5
const DEVIL_CHARGE_TIME := 3.0
const DEVIL_REST := 8.0
const DEVIL_ENRAGED := 1.15
const DEVIL_WAKE := 0.9
## The referee never moves the Devil faster than its top speed and this much over: a speed hack goes nowhere.
const SPEED_GUARD := 1.25
## Positions go out this often; a PING when nothing else did for PING_EVERY. A peer silent this long is gone (a hidden
## browser tab stops its game loop), longer while a floor loads.
const SEND_HZ := 10.0
const PING_EVERY := 1.0
const SILENT_LIMIT := 10.0
const LOAD_LIMIT := 45.0

## The match, kept across a round's scene reload: whether you made the room, the mode, its seed (round 2 plays seed + 1),
## the round, the rounds played ({"host_ran", "result", "seconds"}) and the names.
static var host := true
static var hard := false
static var match_seed := 0
static var round_number := 1
static var results: Array[Dictionary] = []
static var my_name := ""
static var peer_name := ""
## When this round was dealt (real seconds; INF = not yet): its floor loading counts as standing still (VersusMatch).
static var dealt_at := INF


## A new match in a new room.
static func reset() -> void:
	round_number = 1
	results.clear()
	peer_name = ""
	dealt_at = INF


## The room's maker runs first; the roles swap for round 2.
static func i_run() -> bool:
	return host == (round_number == 1)


static func round_seed() -> int:
	return match_seed + round_number - 1


static func new_seed() -> int:
	return randi()


## What the other player is called on screen.
static func peer() -> String:
	return peer_name.to_upper() if not peer_name.is_empty() else "YOUR FRIEND"


## A versus floor's knobs (RunState.mod): nothing folded in (no cards, gear or mercy), no traps, safe circles or chests,
## and Hard without the map.
static func mod(key: String, base: float) -> float:
	match key:
		"traps", "circles", "extra_circles", "chests", "devil_awake":
			return 0.0
		"minimap":
			return 0.0 if hard else 1.0
		"clock":
			return base * (HARD_CLOCK if hard else 1.0)
	return base


## The Devil's legs: the runner's feel, faster at a walk, with a short charge and a long rest.
static func devil_feel(runner: PlayerFeel) -> PlayerFeel:
	var feel := runner.duplicate() as PlayerFeel
	feel.walk_speed = runner.walk_speed * DEVIL_WALK
	feel.sprint_multiplier = DEVIL_CHARGE
	feel.sprint_time = DEVIL_CHARGE_TIME
	feel.sprint_recover_time = DEVIL_REST
	return feel


## The fastest the referee lets the Devil move: charging, enraged, and SPEED_GUARD over.
static func devil_top_speed(runner: PlayerFeel) -> float:
	return runner.walk_speed * DEVIL_WALK * DEVIL_CHARGE * DEVIL_ENRAGED * SPEED_GUARD


## The Devil's pace on its legs: slower in WAKE, faster enraged.
static func devil_pace(nightmare: bool, enraged: bool) -> float:
	return (1.0 if nightmare else DEVIL_WAKE) * (DEVIL_ENRAGED if enraged else 1.0)


## The referee says where the runner is only while the Devil could perceive them: close by path, or down a straight
## corridor within sight, whichever way it faces (turning never pops them in).
static func runner_visible(layout: FloorLayout, world: int, devil_cell: Vector2i, runner_cell: Vector2i, path_gap: int) -> bool:
	if path_gap >= 0 and path_gap <= NEAR_TILES:
		return true
	return DevilBrain.line_of_sight(layout, world, devil_cell, runner_cell, SIGHT_TILES)


static func encode(msg: Array) -> PackedByteArray:
	return var_to_bytes(msg)


## The message in `bytes`, or [] if it isn't one: peer bytes are untrusted, so the wrong size, anything but an Array of
## a known type with its fields' count and types, a float that isn't finite or a name too long is dropped.
static func decode(bytes: PackedByteArray) -> Array:
	if bytes.is_empty() or bytes.size() > MAX_BYTES:
		return []
	var value: Variant = bytes_to_var(bytes)
	return value if value is Array and valid(value) else []


static func valid(msg: Array) -> bool:
	if msg.is_empty() or typeof(msg[0]) != TYPE_INT or not SHAPES.has(msg[0]):
		return false
	var shape: Array = SHAPES[msg[0]]
	if msg.size() != shape.size() + 1:
		return false
	for i in shape.size():
		var field: Variant = msg[i + 1]
		if typeof(field) != shape[i]:
			return false
		if field is float and not is_finite(field):
			return false
		if field is String and (field as String).length() > MAX_NAME:
			return false
	return true


## A runner's round as one number to compare: escaping beats being caught; between escapes the faster, between catches
## (or clocks run out) the longer survived.
static func score(round_result: Dictionary) -> float:
	var seconds: float = round_result["seconds"]
	return 100000.0 - seconds if round_result["result"] == Result.ESCAPED else seconds


## The match: "host", "guest" or "draw" once both rounds are played; "" before, or if someone left.
static func winner(rounds: Array[Dictionary]) -> String:
	if rounds.size() < 2:
		return ""
	for played in rounds:
		if played["result"] in [Result.RUNNER_LEFT, Result.DEVIL_LEFT]:
			return ""
	var first_host: bool = rounds[0]["host_ran"]
	var host_run := score(rounds[0] if first_host else rounds[1])
	var guest_run := score(rounds[1] if first_host else rounds[0])
	if is_equal_approx(host_run, guest_run):
		return "draw"
	return "host" if host_run > guest_run else "guest"


## Where the other player was, DELAY behind (SEND_HZ samples, smoothed): each side draws the other from it.
class Track:
	const DELAY := 0.1
	const KEEP := 8
	## [time, position, facing, speed], oldest first.
	var samples: Array[Array] = []

	func push(time: float, at: Vector3, facing: float, speed: float) -> void:
		samples.append([time, at, facing, speed])
		if samples.size() > KEEP:
			samples.pop_front()

	func clear() -> void:
		samples.clear()

	## Seconds since the last sample (INF with none).
	func age(time: float) -> float:
		return INF if samples.is_empty() else time - float(samples[-1][0])

	## [position, facing, speed] at `time` - DELAY, between the samples around it (else the nearest end); [] with none.
	func sample(time: float) -> Array:
		if samples.is_empty():
			return []
		var at := time - DELAY
		if at <= float(samples[0][0]):
			return samples[0].slice(1)
		for i in range(1, samples.size()):
			var b: Array = samples[i]
			if at <= float(b[0]):
				var a: Array = samples[i - 1]
				var t := inverse_lerp(float(a[0]), float(b[0]), at) if float(b[0]) > float(a[0]) else 1.0
				return [(a[1] as Vector3).lerp(b[1], t), lerp_angle(a[2], b[2], t), lerpf(a[3], b[3], t)]
		return samples[-1].slice(1)
