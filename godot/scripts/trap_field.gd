class_name TrapField
extends RefCounted
## Cracked floors (plans/05 §3.6), the 2D two-step rule: the first step cracks it, the second kills.
## Placement scores junctions over corridors and never puts a trap you'd have to cross twice
## (the 2D rule, so it works in a perfect maze). Dead-end entrances only from Act 2 on.

enum State { HIDDEN, CRACKED, COLLAPSED }

const SPAWN_CLEARANCE := 3
const EXIT_CLEARANCE := 2
## No traps in the first part of the route: you learn the maze first.
const ROUTE_GRACE := 0.3
const MIN_SPACING := 2
const ROUTE_GAP := 4
const SCORE_T_JUNCTION := 86.0
const SCORE_DEAD_END_ENTRANCE := 78.0
const SCORE_CROSSROADS := 52.0
const SCORE_CORRIDOR := 30.0
const SCORE_ON_ROUTE := 12.0
const SCORE_NOISE := 20.0

var cells: Array[Vector2i] = []
var states: Array[int] = []
## Cracked floors that hold instead of collapsing, once each (the Feather Step omen).
var holds := 0
## A creak plays once when you come within this many tiles (the Keen Eye omen: 2); it re-arms past it.
var creak_range := 1
var _primed: Array[bool] = []


func place(layout: FloorLayout, route: Array[Vector2i], count: int, excluded: Array[Vector2i], dead_end_traps: bool, rng: RandomNumberGenerator) -> void:
	cells.clear()
	var route_index := {}
	for i in route.size():
		route_index[route[i]] = i
	var grace := ceili(route.size() * ROUTE_GRACE)
	var scored: Array = []
	for y in layout.size:
		for x in layout.size:
			var cell := Vector2i(x, y)
			if excluded.has(cell) or not (layout.is_open(FloorLayout.World.WAKE, cell) and layout.is_open(FloorLayout.World.NIGHTMARE, cell)):
				continue
			if _manhattan(cell, layout.spawn) <= SPAWN_CLEARANCE or _manhattan(cell, layout.exit) <= EXIT_CLEARANCE:
				continue
			if route_index.get(cell, grace) < grace:
				continue
			var degree := _degree(layout, cell)
			if degree <= 1:
				continue
			if not _safe_to_crack(layout, cell):
				continue
			var score := SCORE_CORRIDOR
			if _dead_end_entrance(layout, cell):
				if not dead_end_traps:
					continue
				score = SCORE_DEAD_END_ENTRANCE
			elif degree == 3:
				score = SCORE_T_JUNCTION
			elif degree == 4:
				score = SCORE_CROSSROADS
			if route_index.has(cell):
				score += SCORE_ON_ROUTE
			scored.append([score + rng.randf() * SCORE_NOISE, cell])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for entry in scored:
		if cells.size() >= count:
			break
		var cell: Vector2i = entry[1]
		if _spaced(cell, route_index):
			cells.append(cell)
	states.clear()
	_primed.clear()
	for _cell in cells:
		states.append(State.HIDDEN)
		_primed.append(true)


## Extra hidden trap at `cell`, no placement rules (debug / hand-placed).
func add(cell: Vector2i) -> void:
	if cells.has(cell):
		return
	cells.append(cell)
	states.append(State.HIDDEN)
	_primed.append(true)


func index_at(cell: Vector2i) -> int:
	return cells.find(cell)


## You stepped onto `cell`. Returns the trap's new state, or -1 if there is no trap there. A crack that
## should give way stays CRACKED while `holds` are left (and uses one).
func step(cell: Vector2i) -> int:
	var i := index_at(cell)
	if i < 0:
		return -1
	if states[i] == State.CRACKED and holds > 0:
		holds -= 1
		return states[i]
	states[i] = mini(states[i] + 1, State.COLLAPSED)
	return states[i]


## True if a creak should play now that you entered `cell`.
func creak(cell: Vector2i) -> bool:
	var play := false
	for i in cells.size():
		var d := _manhattan(cell, cells[i])
		if d >= 1 and d <= creak_range and _primed[i] and states[i] != State.COLLAPSED:
			_primed[i] = false
			play = true
		elif d > creak_range + 1:
			_primed[i] = true
	return play


func _spaced(cell: Vector2i, route_index: Dictionary) -> bool:
	for other in cells:
		if _manhattan(cell, other) < MIN_SPACING:
			return false
		if route_index.has(cell) and route_index.has(other) and absi(route_index[cell] - route_index[other]) < ROUTE_GAP:
			return false
	return true


static func _degree(layout: FloorLayout, cell: Vector2i) -> int:
	var n := 0
	for d in FloorLayout.DIRS:
		if layout.is_open(FloorLayout.World.WAKE, cell + d):
			n += 1
	return n


static func _dead_end_entrance(layout: FloorLayout, cell: Vector2i) -> bool:
	for d in FloorLayout.DIRS:
		var next: Vector2i = cell + d
		if layout.is_open(FloorLayout.World.WAKE, next) and _degree(layout, next) == 1:
			return true
	return false


## Fair: everything you must reach (sigils, exit) is on one side of this cell, so the tour crosses
## it at most once. Crack it at the mouth of an empty branch and you can still back off. In a maze
## with loops this also holds whenever there's a way around.
## ponytail: O(cells) BFS per candidate; fine up to 25x25 tiles.
static func _safe_to_crack(layout: FloorLayout, cell: Vector2i) -> bool:
	var seen := {cell: true, layout.spawn: true}
	var queue: Array[Vector2i] = [layout.spawn]
	var head := 0
	while head < queue.size():
		var current := queue[head]
		head += 1
		for d in FloorLayout.DIRS:
			var next: Vector2i = current + d
			if layout.is_open(FloorLayout.ANY, next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	var targets: Array[Vector2i] = layout.sigils.duplicate()
	targets.append(layout.exit)
	var behind := 0
	for target in targets:
		if seen.has(target):
			behind += 1
	return behind == 0 or behind == targets.size()


static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
