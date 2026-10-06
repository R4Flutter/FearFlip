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
## Straight-corridor sight range (tiles) and how far a sprint is heard (path tiles).
const SIGHT_TILES := 5
const HEAR_SPRINT_TILES := 6
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
var _newest := {}


func record(cell: Vector2i, following: bool) -> void:
	trail.append(cell)
	_newest[cell] = trail.size() - 1
	if following:
		trail_limit = trail.size()


## Where to walk next turn: you (while sensed), else the next scent cell.
func target(devil_cell: Vector2i, player_cell: Vector2i) -> Vector2i:
	if _newest.has(devil_cell):
		trail_pos = maxi(trail_pos, _newest[devil_cell] + 1)
	if sense_left > 0.0:
		return player_cell
	if trail_pos >= trail_limit:
		return devil_cell
	return trail[trail_pos]


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


## Straight, unbroken corridor between a and b inside `world`, at most SIGHT_TILES long.
static func line_of_sight(layout: FloorLayout, world: int, a: Vector2i, b: Vector2i) -> bool:
	if a.x != b.x and a.y != b.y:
		return false
	var gap := b - a
	var length := absi(gap.x) + absi(gap.y)
	if length > SIGHT_TILES:
		return false
	var step := gap.sign()
	for i in range(1, length):
		if not layout.is_open(world, a + step * i):
			return false
	return true
