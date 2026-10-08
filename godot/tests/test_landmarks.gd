extends McpTestSuite
## plans/07: landmarks on real floors: seeded, spread out, covering the maze, names apart, never on a gameplay
## cell, always on a cell open in both worlds; on small floors and on the big ones every floor uses now.

const WAKE := FloorLayout.World.WAKE
const NIGHTMARE := FloorLayout.World.NIGHTMARE
## Measured with junction-only landmarks: ~50% of open cells on average at every size (worst floor ~24% on 15x15,
## ~36% on 25x25 and 27x27); a floor has only ~16 junctions open in both worlds, and nearly all get one.
const MIN_FLOOR_COVER := 0.2
const MIN_AVERAGE_COVER := 0.42


func suite_name() -> String:
	return "landmarks"


func _excluded(layout: FloorLayout) -> Array[Vector2i]:
	var excluded: Array[Vector2i] = [layout.spawn, layout.exit, layout.devil_spawn]
	excluded.append_array(layout.sigils)
	return excluded


## Every rule on `seeds` floors of `rooms`; returns the average share of open cells within COVER_RADIUS.
func _check(rooms: int, seeds: int) -> float:
	var cover_sum := 0.0
	for seed_value in range(1, seeds + 1):
		var layout := FloorLayout.generate(seed_value, rooms)
		var excluded := _excluded(layout)
		var marks := Landmarks.new(layout, seed_value, excluded)
		var where := "rooms %d seed %d" % [rooms, seed_value]
		for i in marks.cells.size():
			var cell := marks.cells[i]
			assert_true(layout.is_open(WAKE, cell) and layout.is_open(NIGHTMARE, cell), "%s: landmark %s in a wall" % [where, cell])
			assert_false(excluded.has(cell), "%s: landmark on gameplay cell %s" % [where, cell])
			assert_eq(marks.at(cell), i)
			var ways := 0
			for d in FloorLayout.DIRS:
				ways += 1 if layout.is_open(WAKE, cell + d) and layout.is_open(NIGHTMARE, cell + d) else 0
			assert_true(ways >= 3, "%s: landmark %s not at a junction" % [where, cell])
			var side := marks.sides[i]
			if side != Vector2i.ZERO:
				assert_false(layout.is_open(FloorLayout.ANY, cell + side), "%s: %s leans on an open side" % [where, cell])
			if marks.kinds[i] == Landmarks.Kind.GLYPH:
				assert_ne(side, Vector2i.ZERO, "%s: glyph with no wall" % where)
			var reach := layout.distances(WAKE, cell)
			for j in range(i + 1, marks.cells.size()):
				var other := marks.cells[j]
				assert_true(reach[other.y * layout.size + other.x] >= Landmarks.MIN_SPACING, "%s: landmarks %s and %s too close" % [where, cell, other])
				if marks.kinds[j] == marks.kinds[i] and marks.variants[j] == marks.variants[i]:
					var apart := absi(other.x - cell.x) + absi(other.y - cell.y)
					assert_true(apart >= Landmarks.REPEAT_SPACING, "%s: twin names %s and %s only %d apart" % [where, cell, other, apart])
		var dist := layout._distances_from(WAKE, marks.cells)
		var open := 0
		var covered := 0
		for i in dist.size():
			if layout.is_open(WAKE, layout.cell_at(i)):
				open += 1
				covered += 1 if dist[i] >= 0 and dist[i] <= Landmarks.COVER_RADIUS else 0
		var share := float(covered) / open
		assert_true(share >= MIN_FLOOR_COVER, "%s: landmarks cover only %.0f%%" % [where, share * 100.0])
		assert_true(marks.cells.size() <= ceili(open / float(Landmarks.CELLS_PER_LANDMARK)), "%s: over budget" % where)
		cover_sum += share
	return cover_sum / seeds


func test_same_seed_same_landmarks() -> void:
	var layout := FloorLayout.generate(42, StageRule.ROOMS_3D.x)
	var a := Landmarks.new(layout, 42, _excluded(layout))
	var b := Landmarks.new(layout, 42, _excluded(layout))
	assert_eq(a.cells, b.cells)
	assert_eq(a.kinds, b.kinds)
	assert_eq(a.variants, b.variants)
	assert_eq(a.sides, b.sides)


func test_small_floors_fair_and_memorable() -> void:
	var average := _check(7, 100)
	assert_true(average >= MIN_AVERAGE_COVER, "average cover %.2f" % average)


func test_big_floors_fair_and_memorable() -> void:
	var average := _check(StageRule.ROOMS_3D.x, 15)
	assert_true(average >= MIN_AVERAGE_COVER, "average cover %.2f" % average)


func test_excluded_cells_stay_clear() -> void:
	var layout := FloorLayout.generate(7, 7)
	var everything: Array[Vector2i] = []
	for y in layout.size:
		for x in layout.size:
			everything.append(Vector2i(x, y))
	assert_eq(Landmarks.new(layout, 7, everything).cells.size(), 0)
