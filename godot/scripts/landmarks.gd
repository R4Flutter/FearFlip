class_name Landmarks
extends RefCounted
## Landmarks (plans/07): something to remember at the maze's decisions, so a route can be learned ("left at the
## red lamp") and found again after a flip. Pure data from FloorLayout: main.gd builds them, the minimap marks
## them. Only on cells open in both worlds, never on a gameplay cell, never changes a wall. Same seed -> same set.

enum Kind { LAMP, FLICKER, GLYPH, STATUE, DEBRIS }

## Every open cell ends up this many path cells or fewer from a landmark (as far as the budget allows).
const COVER_RADIUS := 4
## Landmarks at least this many path cells apart.
const MIN_SPACING := 4
## Two of a kind at least this far apart, so "the statue" points at one place nearby.
const SAME_KIND_SPACING := 6
## The budget: one landmark per this many open cells (~9 on a 15x15 floor, ~31 on 27x27).
const CELLS_PER_LANDMARK := 11
## A big floor needs more landmarks than there are names, so a name comes back, but only this many tiles from its
## twin (Manhattan, so at least as many path cells): "the red lamp in the north half".
const REPEAT_SPACING := 14
## How much a cell is worth as a landmark: junction, corner, straight corridor.
const TIER_WEIGHT: Array[float] = [1.0, 0.75, 0.4]
## Kept apart from both worlds' looks so a red lamp reads red in WAKE and in NIGHTMARE.
const LAMP_COLORS: Array[Color] = [Color(1.0, 0.16, 0.1), Color(0.2, 1.0, 0.3), Color(1.0, 0.62, 0.12), Color(0.75, 0.35, 1.0)]
const GLYPHS: Array[String] = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"]

var cells: Array[Vector2i] = []
var kinds: Array[int] = []
## LAMP: index into LAMP_COLORS. GLYPH: index into GLYPHS. Otherwise 0.
var variants: Array[int] = []
## The wall a glyph or prop leans on (Vector2i.ZERO at a crossroads, which has none).
var sides: Array[Vector2i] = []


## Cells are grid indices (y * size + x) inside: FloorLayout.is_open costs ~2 us a call, too slow for a few hundred
## bounded searches on a 29x29 floor.
func _init(layout: FloorLayout, seed_value: int, excluded: Array[Vector2i]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "landmarks"])
	var size := layout.size
	# 1 = open in both worlds, border cells never (so an open cell's four neighbours are always on the grid).
	var open := PackedByteArray()
	open.resize(size * size)
	for i in open.size():
		var cell := layout.cell_at(i)
		var inside := cell.x > 0 and cell.y > 0 and cell.x < size - 1 and cell.y < size - 1
		open[i] = 1 if inside and layout.is_open(FloorLayout.World.WAKE, cell) and layout.is_open(FloorLayout.World.NIGHTMARE, cell) else 0
	var steps := PackedInt32Array([1, -1, size, -size])
	var skip := {}
	for cell in excluded:
		skip[cell.y * size + cell.x] = true
	var uncovered := {}
	var candidates: Array[int] = []
	var weight := {}
	for i in open.size():
		if open[i] == 0:
			continue
		uncovered[i] = true
		var ways := open[i + 1] + open[i - 1] + open[i + size] + open[i - size]
		if ways < 2 or skip.has(i):
			continue
		candidates.append(i)
		var straight := ways == 2 and (open[i + 1] + open[i - 1] == 2 or open[i + size] + open[i - size] == 2)
		weight[i] = TIER_WEIGHT[0 if ways >= 3 else (2 if straight else 1)]
	var budget := ceili(uncovered.size() / float(CELLS_PER_LANDMARK))
	_shuffle(candidates, rng)
	# Per candidate: {nearby cell: path cells} out to the widest rule, the cells it covers and how many of those are
	# still uncovered (kept up to date below). Per cell: the candidates that would cover it.
	var reach := {}
	var covers := {}
	var gains := {}
	var covered_by := {}
	for i in candidates:
		var near := _within(open, steps, i, SAME_KIND_SPACING)
		reach[i] = near
		var mine: Array[int] = []
		for c: int in near:
			if near[c] <= COVER_RADIUS:
				mine.append(c)
				covered_by.get_or_add(c, []).append(i)
		covers[i] = mine
		gains[i] = mine.size()
	var picks: Array[int] = []
	var blocked := {}
	# Greedy set cover: the cell that covers the most still-uncovered cells, decisions weighted up.
	while picks.size() < budget and not uncovered.is_empty():
		var best := -1
		var best_score := 0.0
		for i in candidates:
			var score: float = gains[i] * weight[i]
			if score > best_score and not blocked.has(i):
				best = i
				best_score = score
		if best < 0:
			break
		picks.append(best)
		for near: int in reach[best]:
			if reach[best][near] < MIN_SPACING:
				blocked[near] = true
		for near: int in covers[best]:
			if uncovered.erase(near):
				for other: int in covered_by[near]:
					gains[other] -= 1
	# Names: every lamp colour, every glyph, one flicker, one statue, one debris pile; reshuffled when they run out.
	var names: Array[Vector2i] = [Vector2i(Kind.FLICKER, 0), Vector2i(Kind.STATUE, 0), Vector2i(Kind.DEBRIS, 0)]
	for i in LAMP_COLORS.size():
		names.append(Vector2i(Kind.LAMP, i))
	for i in GLYPHS.size():
		names.append(Vector2i(Kind.GLYPH, i))
	var pool: Array[Vector2i] = []
	var named: Array[int] = []
	for i in picks:
		var cell := layout.cell_at(i)
		var walls: Array[Vector2i] = []
		for d in FloorLayout.DIRS:
			if not layout.is_open(FloorLayout.ANY, cell + d):
				walls.append(d)
		var side := walls[rng.randi() % walls.size()] if not walls.is_empty() else Vector2i.ZERO
		var entry := _name_for(i, cell, side, pool, named, reach)
		if entry.x < 0:
			var fresh := names.duplicate()
			_shuffle(fresh, rng)
			pool.append_array(fresh)
			entry = _name_for(i, cell, side, pool, named, reach)
		if entry.x < 0:
			continue  # nothing fits here (a crossroads among glyphs, twins too close): leave it plain
		pool.erase(entry)
		named.append(i)
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


## The first name in `pool` that suits grid index `index` (`cell`): a glyph needs a wall, a name already used must be
## REPEAT_SPACING from its twin, and one whose kind sits within SAME_KIND_SPACING is only the fallback. (-1, -1) if
## none. `named` = the grid index of each landmark so far.
func _name_for(index: int, cell: Vector2i, side: Vector2i, pool: Array[Vector2i], named: Array[int], reach: Dictionary) -> Vector2i:
	var fallback := Vector2i(-1, -1)
	for entry in pool:
		if entry.x == Kind.GLYPH and side == Vector2i.ZERO:
			continue
		var twin := false
		var crowded := false
		for i in cells.size():
			if kinds[i] != entry.x:
				continue
			if variants[i] == entry.y and absi(cells[i].x - cell.x) + absi(cells[i].y - cell.y) < REPEAT_SPACING:
				twin = true
				break
			crowded = crowded or reach[named[i]].get(index, SAME_KIND_SPACING) < SAME_KIND_SPACING
		if twin:
			continue
		if not crowded:
			return entry
		if fallback.x < 0:
			fallback = entry
	return fallback


## {grid index: path cells} for open cells up to `limit` path cells from `from` (a bounded BFS on the flat grid;
## `steps` = the four neighbour offsets).
static func _within(open: PackedByteArray, steps: PackedInt32Array, from: int, limit: int) -> Dictionary:
	var dist := {from: 0}
	var queue: Array[int] = [from]
	var head := 0
	while head < queue.size():
		var here := queue[head]
		head += 1
		var d: int = dist[here]
		if d == limit:
			continue
		for step in steps:
			var next := here + step
			if open[next] == 1 and not dist.has(next):
				dist[next] = d + 1
				queue.append(next)
	return dist


## Seeded Fisher-Yates (Array.shuffle uses the global RNG, which would break same seed -> same floor).
static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Variant = items[i]
		items[i] = items[j]
		items[j] = swap
