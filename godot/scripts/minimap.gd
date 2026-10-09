extends Control
## Full maze of the current world, north-up, player arrow + view cone, sigils, exit, landmarks. In game it is the
## paper map's sheet (paper = true: ink, no panel, no readout, never the Devil); the screen mode (a Devil marker that
## pulses faster as it closes in, a danger readout) is the old corner map, kept for a tutorial floor.
## main.gd pushes state every frame while the map is up (positions are in grid cells, floats).

const MAP_SIZE := 240.0
const PAD := 10.0
const READOUT_HEIGHT := 46.0
const VIEW_CONE_DEGREES := 70.0
const VIEW_CONE_CELLS := 3.0
## Wall line thickness relative to a corridor, for the classic thin-wall maze look.
const WALL_RATIO := 0.28
const NIGHTMARE := FloorLayout.World.NIGHTMARE
const PLAYER_COLOR := Color(0.92, 0.95, 1.0)
## Paper mode: wall ink and the red "you are here" (the delivered marker art, pointing up, turned to your facing).
const INK := Color(0.17, 0.11, 0.07)
const INK_PLAYER := Color(0.72, 0.08, 0.05)
var key_icon := Art.key_icon()
var marker := Art.tex(Art.HUD + "map_marker.png")
## Key icon size (px) on the map.
const KEY_SIZE := 24.0

## The game's per-world palette, handed down by main.gd so the map matches the 3D look:
## glowing wall lines on fog-dark corridors, keys in their world's colour.
var fog_colors: Array[Color]
var glow_colors: Array[Color]
var sigil_colors: Array[Color]
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
var landmarks: Landmarks
## Hidden cracks this many cells from you show faintly (the Cartographer omen; 0 = only cracks you found).
var crack_reveal := 0
## Ink on parchment for the paper map (PaperMap): no panel or readout, ink walls, darker markers.
var paper := false
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
	var glow := glow_colors[world].lightened(0.25)
	if paper:
		# Ink walls straight on the parchment.
		for y in layout.size:
			for x in layout.size:
				if not layout.is_open(world, Vector2i(x, y)):
					draw_rect(Rect2(_axis(x), _axis(y), _span(x) + 0.5, _span(y) + 0.5), INK)
	else:
		draw_style_box(_panel(glow), Rect2(0, 0, side, side))
		# Line maze: glowing wall strokes (even grid lines are thin) over fog-dark corridors.
		draw_rect(Rect2(PAD, PAD, map_side, map_side), glow)
		for y in layout.size:
			for x in layout.size:
				if layout.is_open(world, Vector2i(x, y)):
					draw_rect(Rect2(_axis(x), _axis(y), _span(x) + 0.5, _span(y) + 0.5), fog_colors[world])

	_draw_exit(_to_map(Vector2(layout.exit), cell), cell)
	for i in layout.sigils.size():
		if i < sigil_collected.size() and sigil_collected[i]:
			continue
		_draw_key(_to_map(Vector2(layout.sigils[i]), cell), KEY_SIZE, sigil_colors[layout.sigil_worlds[i]])
	if circles != null:
		for i in circles.cells.size():
			var fill := circles.charge[i] / circles.capacity
			draw_arc(_to_map(Vector2(circles.cells[i]), cell), maxf(cell * 0.45, 5.0), 0.0, TAU, 20, Color(0.1, 0.35, 0.9, 0.25 + 0.75 * fill), 2.0, true)
	if landmarks != null:
		for i in landmarks.cells.size():
			_draw_landmark(i, _to_map(Vector2(landmarks.cells[i]), cell), cell)
	if traps != null:
		for i in traps.cells.size():
			var hidden := traps.states[i] == TrapField.State.HIDDEN
			if hidden and not shows_hidden_crack(traps.cells[i]):
				continue
			var at := _to_map(Vector2(traps.cells[i]), cell)
			var r := maxf(cell * 0.35, 4.0)
			var color := Color(1.0, 0.55, 0.15, 0.45 if hidden else 1.0)
			draw_line(at - Vector2(r, r), at + Vector2(r, r), color, 2.0)
			draw_line(at + Vector2(-r, r), at + Vector2(r, -r), color, 2.0)
	if shows_devil():
		_draw_devil(_to_map(devil_pos, cell), cell)
	_draw_player(_to_map(player_pos, cell), cell)

	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(side * 0.5 - 4, PAD - 1), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK if paper else Color(1, 1, 1, 0.8))
	if not paper:
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


func shows_hidden_crack(trap_cell: Vector2i) -> bool:
	return crack_reveal > 0 and absf(trap_cell.x - player_pos.x) + absf(trap_cell.y - player_pos.y) <= crack_reveal


## The paper map never shows the Devil: you read the maze, it hunts you in the real one.
func shows_devil() -> bool:
	return devil_awake and not paper


func _draw_player(at: Vector2, cell: float) -> void:
	var you := INK_PLAYER if paper else PLAYER_COLOR
	var cone := PackedVector2Array([at])
	var half := deg_to_rad(VIEW_CONE_DEGREES * 0.5)
	for step in 9:
		var angle := facing - half + half * 2.0 * step / 8.0
		cone.append(at + Vector2.from_angle(angle) * cell * VIEW_CONE_CELLS)
	draw_colored_polygon(cone, Color(you, 0.25))
	if paper and marker != null:
		var tall := maxf(cell * 2.2, 16.0)
		var wide := tall * marker.get_width() / marker.get_height()
		draw_set_transform(at, facing + PI * 0.5)  # the art points up
		draw_texture_rect(marker, Rect2(-wide * 0.5, -tall * 0.5, wide, tall), false)
		draw_set_transform(Vector2.ZERO)
		return
	var r := maxf(cell * 0.55, 6.0)
	draw_circle(at, r * 1.25, you)
	draw_arc(at, r * 1.25, 0.0, TAU, 24, glow_colors[world].lightened(0.4), 1.5, true)
	var tip := at + Vector2.from_angle(facing) * r * 1.4
	var left := at + Vector2.from_angle(facing + 2.5) * r
	var right := at + Vector2.from_angle(facing - 2.5) * r
	var back := at + Vector2.from_angle(facing + PI) * r * 0.45
	draw_colored_polygon(PackedVector2Array([tip, left, back, right]), fog_colors[world])


## The same names as in the maze: a lamp is a dot in its colour, a glyph its numeral, the statue a triangle,
## the debris a square.
func _draw_landmark(i: int, at: Vector2, cell: float) -> void:
	var r := maxf(cell * 0.24, 3.5)
	match landmarks.kinds[i]:
		Landmarks.Kind.LAMP, Landmarks.Kind.FLICKER:
			draw_circle(at, r + 1.0, Color(0, 0, 0, 0.7))
			draw_circle(at, r, landmarks.color(i))
		Landmarks.Kind.GLYPH:
			var text: String = Landmarks.GLYPHS[landmarks.variants[i]]
			var font_size := clampi(roundi(_room * 0.62), 7, 11)  # VIII fits the corridor on a 29x29 map too
			var width := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			draw_string(ThemeDB.fallback_font, at + Vector2(-width * 0.5, font_size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _ink(Color(1.0, 0.4, 0.32)))
		Landmarks.Kind.STATUE:
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -r * 1.2), at + Vector2(r, r * 0.8), at + Vector2(-r, r * 0.8)]), _ink(Color(0.85, 0.85, 0.9)))
		Landmarks.Kind.DEBRIS:
			draw_rect(Rect2(at - Vector2(r, r) * 0.8, Vector2(r, r) * 1.6), _ink(Color(0.78, 0.56, 0.34)))


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
	var color := _ink(Color(0.3, 1.0, 0.55) if exit_open else Color(0.85, 0.55, 0.6))
	draw_rect(Rect2(at - Vector2(half, half), Vector2(half, half) * 2.0), Color(color, 0.45))
	draw_rect(Rect2(at - Vector2(half, half), Vector2(half, half) * 2.0), color, false, 1.5)
	draw_string(ThemeDB.fallback_font, at + Vector2(-12, -half - 3), "EXIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)


## The key icon tinted its world's colour, on a dark drop shadow so it reads on the glow lines.
func _draw_key(at: Vector2, icon: float, color: Color) -> void:
	var rect := Rect2(at - Vector2(icon, icon) * 0.5, Vector2(icon, icon))
	draw_texture_rect(key_icon, Rect2(rect.position + Vector2(1, 1), rect.size), false, Color(0, 0, 0, 0.8))
	draw_texture_rect(key_icon, rect, false, color.lightened(0.3))


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
	_draw_key(Vector2(x + 4, y - 4), 12.0, sigil_colors[world])
	draw_string(font, Vector2(x + 12, y), "KEY", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.7))
	x += 56.0
	draw_rect(Rect2(x, y - 8, 8, 8), exit_color, false, 1.5)
	draw_string(font, Vector2(x + 12, y), "EXIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.7))


## Marker colours made for the dark minimap, darkened to read on parchment.
func _ink(color: Color) -> Color:
	return color.darkened(0.5) if paper else color


func _panel(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(fog_colors[world].darkened(0.5), 0.9)
	style.border_color = Color(accent, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	return style
