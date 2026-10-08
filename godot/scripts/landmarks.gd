class_name Landmarks
extends RefCounted
## Landmarks (plans/07): something to remember at the maze's decisions, so a route can be learned ("left at the
## red lamp") and found again after a flip. Pure data from FloorLayout: main.gd builds them, the minimap marks
## them. Only on cells open in both worlds, never on a gameplay cell, never changes a wall. Same seed -> same set.

enum Kind { LAMP, FLICKER, GLYPH, STATUE, DEBRIS }

## Every open cell ends up this many path cells or fewer from a landmark (as far as MAX_LANDMARKS allows).
const COVER_RADIUS := 4
## Landmarks at least this many path cells apart.
const MIN_SPACING := 4
## Two of a kind at least this far apart, so "the statue" points at one place.
const SAME_KIND_SPACING := 6
const MAX_LANDMARKS := 10
## How much a cell is worth as a landmark: junction, corner, straight corridor.
const TIER_WEIGHT: Array[float] = [1.0, 0.75, 0.4]
## Kept apart from both worlds' looks so a red lamp reads red in WAKE and in NIGHTMARE.
const LAMP_COLORS: Array[Color] = [Color(1.0, 0.16, 0.1), Color(0.2, 1.0, 0.3), Color(1.0, 0.62, 0.12), Color(0.75, 0.35, 1.0)]
const GLYPHS: Array[String] = ["I", "II", "III", "IV"]

var cells: Array[Vector2i] = []
var kinds: Array[int] = []
## LAMP: index into LAMP_COLORS. GLYPH: index into GLYPHS. Otherwise 0.
var variants: Array[int] = []
## The wall a glyph or prop leans on (Vector2i.ZERO at a crossroads, which has none).
var sides: Array[Vector2i] = []


func _init(layout: FloorLayout, seed_value: int, excluded: Array[Vector2i]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "landmarks"])
	var uncovered := {}
	var candidates: Array[Vector2i] = []
	for y in layout.size:
		for x in layout.size:
			var cell := Vector2i(x, y)
			if not _open(layout, cell):
				continue
			uncovered[cell] = true
			if _ways(layout, cell).size() >= 2 and not excluded.has(cell):
				candidates.append(cell)
	_shuffle(candidates, rng)
	# cell -> {nearby cell: path cells}, out to the widest rule (SAME_KIND_SPACING).
	var reach := {}
	for cell in candidates:
		reach[cell] = _within(layout, cell, SAME_KIND_SPACING)
	var picks: Array[Vector2i] = []
	# Greedy set cover: the cell that covers the most still-uncovered cells, decisions weighted up.
	while picks.size() < MAX_LANDMARKS and not uncovered.is_empty():
		var best := Vector2i(-1, -1)
		var best_score := 0.0
		for cell in candidates:
			if picks.any(func(p: Vector2i) -> bool: return reach[p].get(cell, MIN_SPACING) < MIN_SPACING):
				continue
			var gain := 0
			for near: Vector2i in reach[cell]:
				if reach[cell][near] <= COVER_RADIUS and uncovered.has(near):
					gain += 1
			var score := gain * TIER_WEIGHT[_tier(layout, cell)]
			if score > best_score:
				best = cell
				best_score = score
		if best_score <= 0.0:
			break
		picks.append(best)
		for near: Vector2i in reach[best]:
			if reach[best][near] <= COVER_RADIUS:
				uncovered.erase(near)
	# One of each name: every lamp colour, every glyph, one flicker, one statue, one debris pile.
	var pool: Array[Vector2i] = [Vector2i(Kind.FLICKER, 0), Vector2i(Kind.STATUE, 0), Vector2i(Kind.DEBRIS, 0)]
	for i in LAMP_COLORS.size():
		pool.append(Vector2i(Kind.LAMP, i))
	for i in GLYPHS.size():
		pool.append(Vector2i(Kind.GLYPH, i))
	_shuffle(pool, rng)
	for cell in picks:
		var walls: Array[Vector2i] = []
		for d in FloorLayout.DIRS:
			if not layout.is_open(FloorLayout.ANY, cell + d):
				walls.append(d)
		var side := walls[rng.randi() % walls.size()] if not walls.is_empty() else Vector2i.ZERO
		var fits := pool.filter(func(entry: Vector2i) -> bool: return entry.x != Kind.GLYPH or side != Vector2i.ZERO)
		var spaced := fits.filter(func(entry: Vector2i) -> bool:
			for i in cells.size():
				if kinds[i] == entry.x and reach[cells[i]].get(cell, SAME_KIND_SPACING) < SAME_KIND_SPACING:
					return false
			return true)
		if fits.is_empty():
			continue  # a crossroads with only glyphs left: nothing to paint on
		var entry: Vector2i = spaced[0] if not spaced.is_empty() else fits[0]
		pool.erase(entry)
		cells.append(cell)
		kinds.append(entry.x)
		variants.append(entry.y)
		sides.append(side)


## Index of the landmark on `cell`, or -1.
func at(cell: Vector2i) -> int:
	return cells.find(cell)


## True for the lamp kinds, which hang their own light instead of the corridor lamp.
func lit(i: int) -> bool:
	return kinds[i] == Kind.LAMP or kinds[i] == Kind.FLICKER


func color(i: int) -> Color:
	return LAMP_COLORS[variants[i]] if kinds[i] == Kind.LAMP else Color(0.92, 0.9, 0.82)


static func _open(layout: FloorLayout, cell: Vector2i) -> bool:
	return layout.is_open(FloorLayout.World.WAKE, cell) and layout.is_open(FloorLayout.World.NIGHTMARE, cell)


static func _ways(layout: FloorLayout, cell: Vector2i) -> Array[Vector2i]:
	var ways: Array[Vector2i] = []
	for d in FloorLayout.DIRS:
		if _open(layout, cell + d):
			ways.append(d)
	return ways


## 0 junction (3+ ways), 1 corner, 2 straight corridor.
static func _tier(layout: FloorLayout, cell: Vector2i) -> int:
	var ways := _ways(layout, cell)
	if ways.size() >= 3:
		return 0
	return 2 if ways[0] == -ways[1] else 1


## {cell: path cells} for cells open in both worlds up to `limit` path cells from `from` (a bounded BFS).
static func _within(layout: FloorLayout, from: Vector2i, limit: int) -> Dictionary:
	var dist := {from: 0}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		if dist[cell] == limit:
			continue
		for d in FloorLayout.DIRS:
			if not dist.has(cell + d) and _open(layout, cell + d):
				dist[cell + d] = dist[cell] + 1
				queue.append(cell + d)
	return dist


## Seeded Fisher-Yates (Array.shuffle uses the global RNG, which would break same seed -> same floor).
static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Variant = items[i]
		items[i] = items[j]
		items[j] = swap
