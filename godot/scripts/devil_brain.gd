class_name DevilBrain
extends RefCounted
## The Devil's mind (plans/05 §3.4), pure grid logic. main.gd feeds it cells and senses and moves
## the body. It is no longer omniscient: it follows your scent trail (newest visit wins, so it
## even walks your dead-end detours), and only cuts straight to you while it sees or hears you.

## Speed multiplier per world [WAKE, NIGHTMARE]: it hunts in both, slower while you are awake.
const WORLD_SPEED: Array[float] = [0.6, 1.15]
## Path tiles: inside CLOSE it crawls, beyond FAR it runs.
const CLOSE_TILES := 4
const FAR_TILES := 16
const BAND_CLOSE := 0.8
const BAND_FAR := 1.45
## Up close it is always slower than your walk; it never outruns your sprint.
const CLOSE_CAP := 0.9
const SPRINT_CAP := 0.92
## Enraged it may run faster far away, but inside this many path tiles it stays under your walk.
const RAGE_CAP_TILES := 8
## Straight-corridor sight range (tiles); a flashlight beam pointed at it is seen from farther (plans/06 P7).
const SIGHT_TILES := 5
const BEAM_TILES := 7
## How far a noise carries along corridors (path tiles, master plan §7).
const HEAR_SPRINT_TILES := 6
const NOISE_WALK := 2
const NOISE_FLIP := 6
const NOISE_CRACK := 8
## Its top speed (m/s) for what it's doing, unless it's chasing at the Director's peak (then speed() alone rules).
const CALM_SPEEDS := {"patrol": 2.2, "investigate": 3.0, "chase": 3.0}
const NOWHERE := Vector2i(-1, -1)
## Seconds it keeps hunting you directly after it last saw or heard you.
const SENSE_MEMORY := 8.0
## Fraction of the floor route you must cover before it can wake.
const SPAWN_PROGRESS := 0.3

## Cells you entered, oldest first (only cells that exist in NIGHTMARE).
var trail: Array[Vector2i] = []
## The Devil follows the trail only up to here. Frozen while you are in WAKE: it waits where you vanished.
var trail_limit := 0
## Index of the trail cell it is walking to.
var trail_pos := 0
var sense_left := 0.0
## A noise it heard or a hint the Director gave: it walks there unless it senses you.
var interest := NOWHERE
var _newest := {}


func record(cell: Vector2i, following: bool) -> void:
	trail.append(cell)
	_newest[cell] = trail.size() - 1
	if following:
		trail_limit = trail.size()


## Where to walk next turn: you while it senses you, else its interest (a noise, a hint), else your scent.
func target(devil_cell: Vector2i, player_cell: Vector2i) -> Vector2i:
	if _newest.has(devil_cell):
		trail_pos = maxi(trail_pos, _newest[devil_cell] + 1)
	if sense_left > 0.0:
		return player_cell
	if interest == devil_cell:
		interest = NOWHERE  # nothing there
	if interest != NOWHERE:
		return interest
	if trail_pos >= trail_limit:
		return devil_cell
	return trail[trail_pos]


func investigate(cell: Vector2i) -> void:
	interest = cell


## "chase" (it senses you), "investigate" (a noise or a hint) or "patrol" (your scent).
func mode() -> String:
	if sense_left > 0.0:
		return "chase"
	return "investigate" if interest != NOWHERE else "patrol"


func sense(sees: bool, hears: bool, delta: float) -> void:
	sense_left = SENSE_MEMORY if sees or hears else maxf(sense_left - delta, 0.0)


static func can_spawn(elapsed: float, delay: float, progress: float, in_circle: bool) -> bool:
	return elapsed >= delay and progress >= SPAWN_PROGRESS and not in_circle


## Newest trail cell at least `min_dist` path tiles behind you that you can't see. -1,-1 if none.
## `dist` = NIGHTMARE path distance from the player; `size` = grid side.
func pick_spawn(dist: PackedInt32Array, size: int, min_dist: int, visible: Callable) -> Vector2i:
	for i in range(trail.size() - 1, -1, -1):
		var cell := trail[i]
		if dist[cell.y * size + cell.x] >= min_dist and not visible.call(cell):
			trail_pos = i + 1
			return cell
	return Vector2i(-1, -1)


## m/s for `d` path tiles between it and you. far = faster, close = slower, capped both ends.
static func speed(d: int, walk: float, sprint: float, base_ratio: float, enraged := false) -> float:
	var band := lerpf(BAND_CLOSE, BAND_FAR, clampf(inverse_lerp(float(CLOSE_TILES), float(FAR_TILES), float(d)), 0.0, 1.0))
	var s := walk * base_ratio * band
	if d <= (RAGE_CAP_TILES if enraged else CLOSE_TILES):
		s = minf(s, CLOSE_CAP * walk)
	return minf(s, SPRINT_CAP * sprint)


## It sees you: down a straight corridor within SIGHT_TILES, ahead of it (`facing` = its last step; zero = every
## way) or right next to it.
static func sees(layout: FloorLayout, world: int, devil_cell: Vector2i, facing: Vector2i, player_cell: Vector2i) -> bool:
	if not line_of_sight(layout, world, devil_cell, player_cell):
		return false
	var gap := player_cell - devil_cell
	return facing == Vector2i.ZERO or absi(gap.x) + absi(gap.y) <= 1 or gap.sign() == facing


## Straight, unbroken corridor between a and b inside `world`, at most `reach` tiles long.
static func line_of_sight(layout: FloorLayout, world: int, a: Vector2i, b: Vector2i, reach := SIGHT_TILES) -> bool:
	if a.x != b.x and a.y != b.y:
		return false
	var gap := b - a
	var length := absi(gap.x) + absi(gap.y)
	if length > reach:
		return false
	var step := gap.sign()
	for i in range(1, length):
		if not layout.is_open(world, a + step * i):
			return false
	return true
