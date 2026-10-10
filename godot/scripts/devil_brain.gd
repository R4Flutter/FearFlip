class_name DevilBrain
extends RefCounted
## The Devil's mind (plans/05 §3.4), pure grid logic. main.gd feeds it cells and senses and moves
## the body. It always hunts you down the shortest path (user, 9 Oct 2026: never off somewhere else); what it
## senses only sets its pace, and an Echo Step echo is the one thing that draws it aside.

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
## Seconds it keeps chasing at full pace after it last saw or heard you.
const SENSE_MEMORY := 8.0
## Fraction of the floor route you must cover before it can wake.
const SPAWN_PROGRESS := 0.3

## Cells you entered, oldest first: where it may wake (pick_spawn), always behind you.
var trail: Array[Vector2i] = []
var sense_left := 0.0
## An echo it heard (Echo Step): it walks there instead of at you, until it gets there or senses you.
var interest := NOWHERE


func record(cell: Vector2i) -> void:
	trail.append(cell)


## Where to walk next turn: you, unless an echo draws it aside.
func target(devil_cell: Vector2i, player_cell: Vector2i) -> Vector2i:
	if interest == devil_cell:
		interest = NOWHERE  # nothing there
	return player_cell if interest == NOWHERE else interest


func investigate(cell: Vector2i) -> void:
	interest = cell


## Back to the first `size` cells of the trail (a revive or Last Breath puts you back at a circle): it forgets where you
## went after, and that it sensed you, so it can't wake ahead of you on the way you're about to walk again.
func rewind(size: int) -> void:
	trail.resize(clampi(size, 0, trail.size()))
	sense_left = 0.0
	interest = NOWHERE


## "chase" (it senses you), "investigate" (an echo) or "patrol" (neither: it still comes for you, at a prowl).
func mode() -> String:
	if sense_left > 0.0:
		return "chase"
	return "investigate" if interest != NOWHERE else "patrol"


func sense(sees: bool, hears: bool, delta: float) -> void:
	if sees or hears:
		sense_left = SENSE_MEMORY
		interest = NOWHERE  # it has you: the echo is forgotten
	else:
		sense_left = maxf(sense_left - delta, 0.0)


static func can_spawn(elapsed: float, delay: float, progress: float, in_circle: bool) -> bool:
	return elapsed >= delay and progress >= SPAWN_PROGRESS and not in_circle


## Newest trail cell at least `min_dist` path tiles behind you that you can't see. -1,-1 if none.
## `dist` = NIGHTMARE path distance from the player; `size` = grid side.
func pick_spawn(dist: PackedInt32Array, size: int, min_dist: int, visible: Callable) -> Vector2i:
	for i in range(trail.size() - 1, -1, -1):
		var cell := trail[i]
		if dist[cell.y * size + cell.x] >= min_dist and not visible.call(cell):
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
