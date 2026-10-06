class_name FloorLayout
extends RefCounted
## One floor that exists twice on the same grid: WAKE and NIGHTMARE (FEARFLIP_3D_GAME_APPROACH.md §4, §8).
## Grid is truth: 3D walls, minimap, flip checks and the Devil all read from here.
## Same seed -> same floor.

enum World { WAKE, NIGHTMARE }

## Pseudo-world for is_open/distances/next_step: open in either world (reachable with flips).
const ANY := -1
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const SIGIL_COUNT := 3
const MAX_ATTEMPTS := 20
## Share of corridor connectors that differ in NIGHTMARE (opened or closed). 0 = same maze in both
## worlds (a flip changes mood, sigils and Devil speed only). Was 0.25 when NIGHTMARE rewired the maze.
const NIGHTMARE_CHANGE := 0.0
## Devil spawn, in NIGHTMARE path cells from the player spawn.
const MIN_DEVIL_DISTANCE := 10

var seed_value: int
var size: int
## walls[World] -> 1 = wall, 0 = open; index y * size + x.
var walls: Array[PackedByteArray] = []
var spawn := Vector2i(1, 1)
var exit := Vector2i.ZERO
var devil_spawn := Vector2i.ZERO
var sigils: Array[Vector2i] = []
var sigil_worlds: Array[int] = []
## Cells never changed between worlds (spawn room, exit chamber).
var _protected: Dictionary = {}


## rooms = rooms per side; the grid is (2 * rooms + 1) tiles square.
static func generate(seed_value: int, rooms: int) -> FloorLayout:
	var layout := FloorLayout.new()
	layout.seed_value = seed_value
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for _attempt in MAX_ATTEMPTS:
		layout._build(rng, rooms)
		if layout.validate().is_empty():
			return layout
	push_warning("FloorLayout: seed %d still invalid after %d rerolls: %s" % [seed_value, MAX_ATTEMPTS, layout.validate()])
	return layout


func is_open(world: int, cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= size or cell.y >= size:
		return false
	if world == ANY:
		return walls[0][_idx(cell)] == 0 or walls[1][_idx(cell)] == 0
	return walls[world][_idx(cell)] == 0


## Shortest path from -> to (both included) over cells open in either world. Empty if none.
func route(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var dist := distances(ANY, to)
	var path: Array[Vector2i] = []
	if dist[_idx(from)] < 0:
		return path
	var cell := from
	path.append(cell)
	while cell != to:
		for d in DIRS:
			var next: Vector2i = cell + d
			if is_open(ANY, next) and dist[_idx(next)] == dist[_idx(cell)] - 1:
				cell = next
				break
		path.append(cell)
	return path


## BFS path distance inside one world. -1 = unreachable.
func distances(world: int, from: Vector2i) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(size * size)
	dist.fill(-1)
	if not is_open(world, from):
		return dist
	dist[_idx(from)] = 0
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		for d in DIRS:
			var next: Vector2i = cell + d
			if is_open(world, next) and dist[_idx(next)] == -1:
				dist[_idx(next)] = dist[_idx(cell)] + 1
				queue.append(next)
	return dist


## One cell along the shortest path inside `world`, or `from` if there is no path.
func next_step(world: int, from: Vector2i, to: Vector2i) -> Vector2i:
	var dist := distances(world, to)
	var best := from
	var best_dist := dist[_idx(from)]
	if best_dist <= 0:
		return from
	for d in DIRS:
		var next: Vector2i = from + d
		if is_open(world, next) and dist[_idx(next)] >= 0 and dist[_idx(next)] < best_dist:
			best = next
			best_dist = dist[_idx(next)]
	return best


## Empty string = valid. BFS over (cell, world) with flips as edges. Moves and flips are both
## reversible, so the state graph is undirected: anything reachable can also reach the exit (no pockets).
func validate() -> String:
	if not (is_open(World.WAKE, spawn) and is_open(World.NIGHTMARE, spawn)):
		return "spawn must be open in both worlds"
	var reach := _state_distances(spawn)
	if reach[_idx(exit)] < 0 and reach[size * size + _idx(exit)] < 0:
		return "exit unreachable"
	if not sigil_worlds.has(World.NIGHTMARE):
		return "no NIGHTMARE-only sigil"
	for i in sigils.size():
		if reach[sigil_worlds[i] * size * size + _idx(sigils[i])] < 0:
			return "sigil %d unreachable" % i
	var devil_dist := distances(World.NIGHTMARE, spawn)[_idx(devil_spawn)]
	if devil_dist < MIN_DEVIL_DISTANCE:
		return "devil spawn %d cells from player" % devil_dist
	return ""


func cell_at(index: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(index % size, index / size)


func _idx(cell: Vector2i) -> int:
	return cell.y * size + cell.x


func _interior(cell: Vector2i) -> bool:
	return cell.x >= 1 and cell.y >= 1 and cell.x <= size - 2 and cell.y <= size - 2


func _build(rng: RandomNumberGenerator, rooms: int) -> void:
	size = rooms * 2 + 1
	var wake := PackedByteArray()
	wake.resize(size * size)
	wake.fill(1)
	walls = [wake]
	_carve(rng)
	var from_spawn := distances(World.WAKE, spawn)
	exit = _farthest(from_spawn)
	_protected.clear()
	for center in [spawn, exit]:
		_protected[center] = true
		for d in DIRS:
			_protected[center + d] = true
	_make_nightmare(rng)
	_place_sigils(rng)
	_place_devil(rng)


## The 2D game's MazeGenerator (lib/presentation/gameplay/maze_generator.dart): recursive
## backtracker from the spawn room, one route only (a perfect maze). Exit = farthest room.
func _carve(rng: RandomNumberGenerator) -> void:
	var grid := walls[World.WAKE]
	grid[_idx(spawn)] = 0
	var stack: Array[Vector2i] = [spawn]
	while not stack.is_empty():
		var cell: Vector2i = stack.back()
		var options: Array[Vector2i] = []
		for d in DIRS:
			var next: Vector2i = cell + d * 2
			if _interior(next) and grid[_idx(next)] == 1:
				options.append(next)
		if options.is_empty():
			stack.pop_back()
			continue
		var pick: Vector2i = options[rng.randi_range(0, options.size() - 1)]
		grid[_idx(cell + (pick - cell) / 2)] = 0
		grid[_idx(pick)] = 0
		stack.append(pick)


## Copy WAKE, then toggle a share of the corridor connectors (one odd + one even coordinate).
## Room cells stay open in both worlds, so the centre of every room is always a safe flip spot.
func _make_nightmare(rng: RandomNumberGenerator) -> void:
	var nightmare := walls[World.WAKE].duplicate()
	for y in range(1, size - 1):
		for x in range(1, size - 1):
			var cell := Vector2i(x, y)
			if x % 2 == y % 2 or _protected.has(cell):
				continue
			if rng.randf() < NIGHTMARE_CHANGE:
				nightmare[_idx(cell)] = 1 - nightmare[_idx(cell)]
	walls.append(nightmare)


## Sigil 0 in WAKE, 1 in NIGHTMARE, 2 either. NIGHTMARE sigils prefer corridors that only exist
## there. Spread by farthest-point sampling on path distance (flips allowed).
func _place_sigils(rng: RandomNumberGenerator) -> void:
	sigils.clear()
	sigil_worlds.clear()
	var taken: Array[Vector2i] = [spawn, exit]
	var nearest := PackedInt32Array()
	nearest.resize(size * size)
	nearest.fill(1 << 30)
	_update_nearest(nearest, spawn)
	_update_nearest(nearest, exit)
	for i in SIGIL_COUNT:
		var world: int = [World.WAKE, World.NIGHTMARE, rng.randi_range(0, 1)][i]
		var candidates: Array[Vector2i] = []
		if world == World.NIGHTMARE:
			candidates = _nightmare_only_cells(taken)
		if candidates.is_empty():
			candidates = _room_cells(taken)
		var pick := candidates[0]
		for cell in candidates:
			if nearest[_idx(cell)] > nearest[_idx(pick)]:
				pick = cell
		sigils.append(pick)
		sigil_worlds.append(world)
		taken.append(pick)
		_update_nearest(nearest, pick)


func _place_devil(rng: RandomNumberGenerator) -> void:
	var dist := distances(World.NIGHTMARE, spawn)
	var excluded: Array[Vector2i] = [spawn, exit]
	excluded.append_array(sigils)
	var options: Array[Vector2i] = []
	for cell in _room_cells(excluded):
		if dist[_idx(cell)] >= MIN_DEVIL_DISTANCE:
			options.append(cell)
	devil_spawn = options[rng.randi_range(0, options.size() - 1)] if not options.is_empty() else spawn


func _room_cells(excluded: Array[Vector2i]) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(1, size, 2):
		for x in range(1, size, 2):
			var cell := Vector2i(x, y)
			if not _protected.has(cell) and not excluded.has(cell):
				cells.append(cell)
	return cells


func _nightmare_only_cells(excluded: Array[Vector2i]) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(1, size - 1):
		for x in range(1, size - 1):
			var cell := Vector2i(x, y)
			if is_open(World.NIGHTMARE, cell) and not is_open(World.WAKE, cell) and not excluded.has(cell):
				cells.append(cell)
	return cells


func _farthest(dist: PackedInt32Array) -> Vector2i:
	var best := spawn
	for i in dist.size():
		if dist[i] > dist[_idx(best)]:
			best = cell_at(i)
	return best


## nearest[i] = path distance (flips allowed) from cell i to the closest already-placed point.
func _update_nearest(nearest: PackedInt32Array, from: Vector2i) -> void:
	var reach := _state_distances(from)
	var area := size * size
	for i in area:
		var d := _min_reach(reach[i], reach[area + i])
		if d >= 0 and d < nearest[i]:
			nearest[i] = d


func _min_reach(a: int, b: int) -> int:
	if a < 0:
		return b
	if b < 0:
		return a
	return mini(a, b)


## BFS over (cell, world), starting at `from` in every world where it is open.
## Index = world * size * size + cell index. A flip costs one step and needs the cell open in both worlds.
func _state_distances(from: Vector2i) -> PackedInt32Array:
	var area := size * size
	var dist := PackedInt32Array()
	dist.resize(area * 2)
	dist.fill(-1)
	var queue: Array[Vector3i] = []
	for world in [World.WAKE, World.NIGHTMARE]:
		if is_open(world, from):
			dist[world * area + _idx(from)] = 0
			queue.append(Vector3i(from.x, from.y, world))
	var head := 0
	while head < queue.size():
		var state: Vector3i = queue[head]
		head += 1
		var here: int = dist[state.z * area + state.y * size + state.x]
		for move in 5:
			var next := Vector3i(state.x, state.y, 1 - state.z)
			if move < 4:
				next = Vector3i(state.x + DIRS[move].x, state.y + DIRS[move].y, state.z)
			var at := next.z * area + next.y * size + next.x
			if dist[at] == -1 and walls[next.z][at - next.z * area] == 0:
				dist[at] = here + 1
				queue.append(next)
	return dist
