extends McpTestSuite
## plans/07: landmarks on real floors: seeded, spread out, covering the maze, one of each name, never on a
## gameplay cell, always on a cell open in both worlds.

const WAKE := FloorLayout.World.WAKE
const NIGHTMARE := FloorLayout.World.NIGHTMARE
const SEEDS := 200
## The greedy cover with MAX_LANDMARKS reaches ~91% of open cells on average on 15x15 (measured).
const MIN_FLOOR_COVER := 0.8
const MIN_AVERAGE_COVER := 0.88


func suite_name() -> String:
	return "landmarks"


func _excluded(layout: FloorLayout) -> Array[Vector2i]:
	var excluded: Array[Vector2i] = [layout.spawn, layout.exit, layout.devil_spawn]
	excluded.append_array(layout.sigils)
	return excluded


func test_same_seed_same_landmarks() -> void:
	var layout := FloorLayout.generate(42, 7)
	var a := Landmarks.new(layout, 42, _excluded(layout))
	var b := Landmarks.new(layout, 42, _excluded(layout))
	assert_eq(a.cells, b.cells)
	assert_eq(a.kinds, b.kinds)
	assert_eq(a.variants, b.variants)
	assert_eq(a.sides, b.sides)


func test_landmarks_fair_and_memorable_over_seeds() -> void:
	var cover_sum := 0.0
	for seed_value in range(1, SEEDS + 1):
		var layout := FloorLayout.generate(seed_value, 7)
		var excluded := _excluded(layout)
		var marks := Landmarks.new(layout, seed_value, excluded)
		assert_true(marks.cells.size() >= Landmarks.MAX_LANDMARKS - 2, "seed %d: only %d landmarks" % [seed_value, marks.cells.size()])
		var names := {}
		for i in marks.cells.size():
			var cell := marks.cells[i]
			assert_true(layout.is_open(WAKE, cell) and layout.is_open(NIGHTMARE, cell), "seed %d landmark %s in a wall" % [seed_value, cell])
			assert_false(excluded.has(cell), "seed %d landmark on gameplay cell %s" % [seed_value, cell])
			assert_eq(marks.at(cell), i)
			var label := Vector2i(marks.kinds[i], marks.variants[i])
			assert_false(names.has(label), "seed %d: two landmarks named %s" % [seed_value, label])
			names[label] = true
			var side := marks.sides[i]
			if side != Vector2i.ZERO:
				assert_false(layout.is_open(FloorLayout.ANY, cell + side), "seed %d: %s leans on an open side" % [seed_value, cell])
			if marks.kinds[i] == Landmarks.Kind.GLYPH:
				assert_ne(side, Vector2i.ZERO, "seed %d: glyph with no wall" % seed_value)
			var reach := layout.distances(WAKE, cell)
			for j in range(i + 1, marks.cells.size()):
				var other := marks.cells[j]
				assert_true(reach[other.y * layout.size + other.x] >= Landmarks.MIN_SPACING, "seed %d: landmarks %s and %s too close" % [seed_value, cell, other])
		var dist := layout._distances_from(WAKE, marks.cells)
		var open := 0
		var covered := 0
		for i in dist.size():
			if layout.is_open(WAKE, layout.cell_at(i)):
				open += 1
				covered += 1 if dist[i] >= 0 and dist[i] <= Landmarks.COVER_RADIUS else 0
		var share := float(covered) / open
		assert_true(share >= MIN_FLOOR_COVER, "seed %d: landmarks cover only %.0f%%" % [seed_value, share * 100.0])
		cover_sum += share
	assert_true(cover_sum / SEEDS >= MIN_AVERAGE_COVER, "average cover %.2f" % (cover_sum / SEEDS))


func test_excluded_cells_stay_clear() -> void:
	var layout := FloorLayout.generate(7, 7)
	var everything: Array[Vector2i] = []
	for y in layout.size:
		for x in layout.size:
			everything.append(Vector2i(x, y))
	assert_eq(Landmarks.new(layout, 7, everything).cells.size(), 0)
