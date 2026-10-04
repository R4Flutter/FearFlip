extends Control
## Fixed top-left minimap: full maze of the current world, north-up, player arrow + view cone, Devil
## marker that pulses faster as it closes in, sigils, exit, and a danger readout.
## main.gd pushes state every frame (positions are in grid cells, floats).

const MAP_SIZE := 240.0
const PAD := 10.0
const READOUT_HEIGHT := 46.0
const VIEW_CONE_DEGREES := 70.0
const VIEW_CONE_CELLS := 3.0
const NIGHTMARE := FloorLayout.World.NIGHTMARE
const SIGIL_COLORS: Array[Color] = [Color(0.55, 0.9, 1.0), Color(1.0, 0.35, 0.1)]

var layout: FloorLayout
var world := 0
var player_pos := Vector2.ZERO
## Map angle of the player's facing (0 = east, clockwise because map y points down).
var facing := 0.0
var devil_pos := Vector2.ZERO
## Path distance in metres (-1 = no path in NIGHTMARE).
var devil_distance := -1.0
## Path distance to the exit in metres, in the current world (-1 = no path here).
var exit_distance := -1.0
var sigil_collected: Array[bool] = []
var exit_open := false
var _time := 0.0


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
	var cell := map_side / layout.size
	var nightmare := world == NIGHTMARE
	var accent := Color(1.0, 0.35, 0.3) if nightmare else Color(0.35, 0.8, 1.0)
	draw_style_box(_panel(accent), Rect2(0, 0, side, side))
	# Walls dark, corridors lit: the paths you can walk are what stands out.
	var wall_color := Color(0.05, 0.01, 0.015, 0.9) if nightmare else Color(0.02, 0.035, 0.05, 0.9)
	var path_color := Color(0.3, 0.09, 0.1) if nightmare else Color(0.17, 0.24, 0.31)
	draw_rect(Rect2(PAD, PAD, map_side, map_side), wall_color)
	for y in layout.size:
		for x in layout.size:
			if layout.is_open(world, Vector2i(x, y)):
				draw_rect(Rect2(PAD + x * cell, PAD + y * cell, cell + 0.5, cell + 0.5), path_color)
	# Faint grid like a real map.
	var grid_color := Color(1, 1, 1, 0.04)
	for i in range(0, layout.size + 1, 2):
		draw_line(Vector2(PAD + i * cell, PAD), Vector2(PAD + i * cell, PAD + map_side), grid_color)
		draw_line(Vector2(PAD, PAD + i * cell), Vector2(PAD + map_side, PAD + i * cell), grid_color)

	_draw_exit(_to_map(Vector2(layout.exit), cell), cell)
	for i in layout.sigils.size():
		if i < sigil_collected.size() and sigil_collected[i]:
			continue
		var color := SIGIL_COLORS[layout.sigil_worlds[i]]
		if layout.sigil_worlds[i] != world:
			color.a = 0.35
		_draw_diamond(_to_map(Vector2(layout.sigils[i]), cell), cell * 0.32, color)
	_draw_devil(_to_map(devil_pos, cell), cell, nightmare)
	_draw_player(_to_map(player_pos, cell), cell)

	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(side * 0.5 - 5, PAD + 13), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.8))
	_draw_readout(font, side, nightmare)


func _to_map(grid: Vector2, cell: float) -> Vector2:
	return Vector2(PAD, PAD) + (grid + Vector2(0.5, 0.5)) * cell


func _draw_player(at: Vector2, cell: float) -> void:
	var cone := PackedVector2Array([at])
	var half := deg_to_rad(VIEW_CONE_DEGREES * 0.5)
	for step in 9:
		var angle := facing - half + half * 2.0 * step / 8.0
		cone.append(at + Vector2.from_angle(angle) * cell * VIEW_CONE_CELLS)
	draw_colored_polygon(cone, Color(1.0, 0.95, 0.7, 0.18))
	var r := maxf(cell * 0.55, 6.0)
	draw_circle(at, r * 1.25, Color(0.2, 0.6, 1.0, 0.9))
	draw_arc(at, r * 1.25, 0.0, TAU, 24, Color.WHITE, 1.5, true)
	var tip := at + Vector2.from_angle(facing) * r * 1.4
	var left := at + Vector2.from_angle(facing + 2.5) * r
	var right := at + Vector2.from_angle(facing - 2.5) * r
	var back := at + Vector2.from_angle(facing + PI) * r * 0.45
	draw_colored_polygon(PackedVector2Array([tip, left, back, right]), Color.WHITE)


## Pulses faster as it closes in; hollow and dim while it is in the other world.
func _draw_devil(at: Vector2, cell: float, same_world: bool) -> void:
	var r := maxf(cell * 0.5, 5.5)
	var red := Color(1.0, 0.15, 0.12)
	if not same_world:
		draw_arc(at, r, 0.0, TAU, 20, Color(red, 0.45), 1.5, true)
		return
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
	var color := Color(0.2, 1.0, 0.5) if exit_open else Color(0.75, 0.25, 0.3)
	draw_rect(Rect2(at - Vector2(half, half), Vector2(half, half) * 2.0), Color(color, 0.35))
	draw_rect(Rect2(at - Vector2(half, half), Vector2(half, half) * 2.0), color, false, 1.5)
	draw_string(ThemeDB.fallback_font, at + Vector2(-12, -half - 3), "EXIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)


func _draw_diamond(at: Vector2, r: float, color: Color) -> void:
	r = maxf(r, 4.0)
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)]), color)


func _draw_readout(font: Font, side: float, same_world: bool) -> void:
	var text := "DEVIL  --"
	var color := Color(0.7, 0.75, 0.8, 0.85)
	if not same_world:
		text = "DEVIL IN NIGHTMARE"
		color = Color(0.85, 0.5, 0.5, 0.8)
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
	draw_circle(Vector2(x + 4, y - 4), 4.5, Color(0.2, 0.6, 1.0))
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
