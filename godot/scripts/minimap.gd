extends Control
## Fixed top-left minimap: full maze of the current world, north-up, player arrow + view cone, Devil
## marker that pulses faster as it closes in, sigils, exit, and a danger readout.
## main.gd pushes state every frame (positions are in grid cells, floats).

const MAP_SIZE := 240.0
const PAD := 10.0
const READOUT_HEIGHT := 46.0
const VIEW_CONE_DEGREES := 70.0
const VIEW_CONE_CELLS := 3.0
## Wall line thickness relative to a corridor, for the classic thin-wall maze look.
const WALL_RATIO := 0.28
const NIGHTMARE := FloorLayout.World.NIGHTMARE
const SIGIL_COLORS: Array[Color] = [Color(0.0, 0.5, 0.7), Color(0.9, 0.3, 0.0)]
const WALL_COLOR := Color(0.97, 0.97, 0.95)
const PATH_COLORS: Array[Color] = [Color(0.69, 0.81, 1.0), Color(1.0, 0.53, 0.68)]
const PLAYER_COLOR := Color(0.05, 0.2, 0.75)

var layout: FloorLayout
var world := 0
var player_pos := Vector2.ZERO
## Map angle of the player's facing (0 = east, clockwise because map y points down).
var facing := 0.0
var devil_pos := Vector2.ZERO
## Path distance in metres, in the current world (-1 = no path).
var devil_distance := -1.0
## Path distance to the exit in metres, in the current world (-1 = no path here).
var exit_distance := -1.0
var sigil_collected: Array[bool] = []
var exit_open := false
## False until the Devil wakes on this floor (plans/05 §3.4 spawn gating).
var devil_awake := false
var circles: SafeCircles
var traps: TrapField
var _time := 0.0
## Corridor and wall widths in pixels for the current layout (set each draw).
var _room := 0.0
var _wall := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(20, 20)
	size = Vector2(MAP_SIZE, MAP_SIZE + READOUT_HEIGHT)
	clip_contents = true


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if layout == null:
		return
	var side := MAP_SIZE
	var map_side := side - PAD * 2.0
	@warning_ignore("integer_division")
	var rooms := (layout.size - 1) / 2
	_room = map_side / (rooms + (rooms + 1) * WALL_RATIO)
	_wall = _room * WALL_RATIO
	# Marker scale (corridor-relative).
	var cell := _room * 0.6
	var accent := PATH_COLORS[world]
	draw_style_box(_panel(accent), Rect2(0, 0, side, side))
	# Classic line maze: white wall strokes (even grid lines are thin), pastel corridors.
	draw_rect(Rect2(PAD, PAD, map_side, map_side), WALL_COLOR)
	for y in layout.size:
		for x in layout.size:
			if layout.is_open(world, Vector2i(x, y)):
				draw_rect(Rect2(_axis(x), _axis(y), _span(x) + 0.5, _span(y) + 0.5), PATH_COLORS[world])

	_draw_exit(_to_map(Vector2(layout.exit), cell), cell)
	for i in layout.sigils.size():
		if i < sigil_collected.size() and sigil_collected[i]:
			continue
		var color := SIGIL_COLORS[layout.sigil_worlds[i]]
		if layout.sigil_worlds[i] != world:
			color.a = 0.35
		_draw_diamond(_to_map(Vector2(layout.sigils[i]), cell), cell * 0.32, color)
	if circles != null:
		for i in circles.cells.size():
			var fill := circles.charge[i] / circles.capacity
			draw_arc(_to_map(Vector2(circles.cells[i]), cell), maxf(cell * 0.45, 5.0), 0.0, TAU, 20, Color(0.1, 0.35, 0.9, 0.25 + 0.75 * fill), 2.0, true)
	if traps != null:
		for i in traps.cells.size():
			if traps.states[i] != TrapField.State.HIDDEN:
				var at := _to_map(Vector2(traps.cells[i]), cell)
				var r := maxf(cell * 0.35, 4.0)
				draw_line(at - Vector2(r, r), at + Vector2(r, r), Color(1.0, 0.55, 0.15), 2.0)
				draw_line(at + Vector2(-r, r), at + Vector2(r, -r), Color(1.0, 0.55, 0.15), 2.0)
	if devil_awake:
		_draw_devil(_to_map(devil_pos, cell), cell)
	_draw_player(_to_map(player_pos, cell), cell)

	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(side * 0.5 - 4, PAD - 1), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.8))
	_draw_readout(font, side)


## Grid cell centre (float, for smooth markers) -> map pixels on the thin-wall layout.
func _to_map(grid: Vector2, _cell: float) -> Vector2:
	return Vector2(_lerp_axis(grid.x + 0.5), _lerp_axis(grid.y + 0.5))


## Pixel start of grid line i: even lines are thin walls, odd lines are corridors.
func _axis(i: int) -> float:
	@warning_ignore("integer_division")
	return PAD + (i / 2) * (_room + _wall) + (_wall if i % 2 == 1 else 0.0)


func _span(i: int) -> float:
	return _room if i % 2 == 1 else _wall


func _lerp_axis(u: float) -> float:
	var i := clampi(floori(u), 0, layout.size - 1)
	return _axis(i) + (u - i) * _span(i)


func _draw_player(at: Vector2, cell: float) -> void:
	var cone := PackedVector2Array([at])
	var half := deg_to_rad(VIEW_CONE_DEGREES * 0.5)
	for step in 9:
		var angle := facing - half + half * 2.0 * step / 8.0
		cone.append(at + Vector2.from_angle(angle) * cell * VIEW_CONE_CELLS)
	draw_colored_polygon(cone, Color(PLAYER_COLOR, 0.25))
	var r := maxf(cell * 0.55, 6.0)
	draw_circle(at, r * 1.25, PLAYER_COLOR)
	draw_arc(at, r * 1.25, 0.0, TAU, 24, Color.WHITE, 1.5, true)
	var tip := at + Vector2.from_angle(facing) * r * 1.4
	var left := at + Vector2.from_angle(facing + 2.5) * r
	var right := at + Vector2.from_angle(facing - 2.5) * r
	var back := at + Vector2.from_angle(facing + PI) * r * 0.45
	draw_colored_polygon(PackedVector2Array([tip, left, back, right]), Color.WHITE)


## Pulses faster as it closes in.
func _draw_devil(at: Vector2, cell: float) -> void:
	var r := maxf(cell * 0.5, 5.5)
	var red := Color(0.8, 0.0, 0.05)
	var urgency := 1.0 if devil_distance < 0.0 else clampf(1.0 - devil_distance / 30.0, 0.15, 1.0)
	var pulse := fmod(_time * (1.0 + urgency * 3.0), 1.0)
	draw_circle(at, r * (1.0 + pulse * 2.2), Color(red, 0.45 * (1.0 - pulse)))
	draw_circle(at, r, red)
	draw_arc(at, r, 0.0, TAU, 20, Color(1, 1, 1, 0.9), 1.5, true)
	# Horns, so the marker reads as the Devil at a glance.
	draw_colored_polygon(PackedVector2Array([at + Vector2(-r * 0.75, -r * 0.5), at + Vector2(-r * 1.0, -r * 1.5), at + Vector2(-r * 0.2, -r * 0.9)]), red)
	draw_colored_polygon(PackedVector2Array([at + Vector2(r * 0.75, -r * 0.5), at + Vector2(r * 1.0, -r * 1.5), at + Vector2(r * 0.2, -r * 0.9)]), red)


func _draw_exit(at: Vector2, cell: float) -> void:
	var half := maxf(cell * 0.42, 5.0)
	var color := Color(0.0, 0.6, 0.25) if exit_open else Color(0.45, 0.1, 0.2)
	draw_rect(Rect2(at - Vector2(half, half), Vector2(half, half) * 2.0), Color(color, 0.45))
	draw_rect(Rect2(at - Vector2(half, half), Vector2(half, half) * 2.0), color, false, 1.5)
	draw_string(ThemeDB.fallback_font, at + Vector2(-12, -half - 3), "EXIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)


func _draw_diamond(at: Vector2, r: float, color: Color) -> void:
	r = maxf(r, 4.0)
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)]), color)


func _draw_readout(font: Font, side: float) -> void:
	var text := "DEVIL  --"
	var color := Color(0.7, 0.75, 0.8, 0.85)
	if not devil_awake:
		text = "DEVIL  ASLEEP"
	elif devil_distance >= 0.0:
		text = "DEVIL  %d m" % roundi(devil_distance)
		if devil_distance <= 10.0:
			text = "DEVIL CLOSE  %d m" % roundi(devil_distance)
			color = Color(1.0, 0.2, 0.15, 0.6 + 0.4 * absf(sin(_time * 8.0)))
		elif devil_distance <= 20.0:
			color = Color(1.0, 0.6, 0.2)
	draw_rect(Rect2(0, side + 4, side, READOUT_HEIGHT - 4), Color(0, 0, 0, 0.85))
	draw_string(font, Vector2(8, side + 20), text, HORIZONTAL_ALIGNMENT_LEFT, side * 0.6, 13, color)
	var exit_text := "EXIT  %d m" % roundi(exit_distance) if exit_distance >= 0.0 else "EXIT  --"
	var exit_color := Color(0.3, 1.0, 0.55) if exit_open else Color(0.85, 0.55, 0.6)
	draw_string(font, Vector2(8, side + 20), exit_text, HORIZONTAL_ALIGNMENT_RIGHT, side - 16, 13, exit_color)
	# Legend.
	var y := side + 36.0
	var x := 10.0
	draw_circle(Vector2(x + 4, y - 4), 4.5, PLAYER_COLOR.lightened(0.3))
	draw_string(font, Vector2(x + 12, y), "YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.7))
	x += 50.0
	draw_circle(Vector2(x + 4, y - 4), 4.5, Color(1.0, 0.15, 0.12))
	draw_string(font, Vector2(x + 12, y), "DEVIL", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.7))
	x += 58.0
	_draw_diamond(Vector2(x + 4, y - 4), 4.5, SIGIL_COLORS[0])
	draw_string(font, Vector2(x + 12, y), "SIGIL", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.7))
	x += 56.0
	draw_rect(Rect2(x, y - 8, 8, 8), exit_color, false, 1.5)
	draw_string(font, Vector2(x + 12, y), "EXIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.7))


func _panel(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.88)
	style.border_color = Color(accent, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	return style
