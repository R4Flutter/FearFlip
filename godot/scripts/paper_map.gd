class_name PaperMap
extends Control
## The paper map (plans/07): M pulls the strapped roll out of your back pocket, the left hand takes its edge and the
## right hand pulls it open left to right, the paper uncurling for real (CURL_SHADER rolls the sheet around a moving
## spiral), then it comes up close to read. A view model in its own small 3D world drawn over the game, so it never
## pokes into a wall. The sheet is a second minimap in paper mode: the real floor, never the Devil. main.gd gates M,
## the flip and the walk on state(), and snaps it shut on a flip, with the Devil close and when the floor ends.
## Delivered art (MAP_ASSETS/REQUIREMENTS.md) replaces the code-built hands, roll and paper as each file arrives.

enum State { CLOSED, DRAWING, UNROLLING, OPEN, CLOSING }

## Seconds for the whole move: pocket, unroll, lift. Putting it away plays it backwards; a snap is the fast way.
const OPEN_TIME := 1.7
const CLOSE_TIME := 0.8
const SNAP_TIME := 0.3
## Progress where the left hand has the edge, the strap is off and the paper starts to uncurl (DRAWING before it).
const UNROLL_FROM := 0.42
## The sheet in metres, 4:3 like map_paper.png: a big map (about A2), so held at a natural reading distance it fills
## most of the screen while the real-size hands stay in proportion.
const SHEET := Vector2(0.6, 0.45)
## The left edge stays curled this much (m) where the left hand holds it while the right pulls the roll open; both
## let go as it's lifted to read.
const EDGE_CURL := 0.065
## Paper spacing per turn of a roll and its innermost radius (m): rolled up, the map is about 9 cm thick.
const ROLL_LAYER := 0.011
const ROLL_CORE := 0.006
## Quads across the sheet, enough for round rolls.
const CURL_STEPS := 220
## Camera space: the open map held at the chest tipped toward your eyes, then lifted close to read.
const HELD := Vector3(0.0, -0.27, -0.66)
const HELD_TILT := -0.6
const LIFTED := Vector3(0.0, 0.0, -0.348)
## Map space: the right hand comes up from the back pocket here (below the frame; the left hand mirrors it) with the
## roll tipped this much (radians). Both hands hold the side edges at this height, a little below halfway, the way
## you hold a map up to read it.
const POCKET := Vector3(0.36, -0.5, 0.2)
const POCKET_TILT := 0.9
const GRIP_Y := -0.07
## Held flat, the thumbs press this far in from the side edges (m).
const EDGE_HOLD := 0.03
## How far the head turns down and right while the hand reaches back (radians).
const DIP := 0.2
## Right forearm from the grip, straight down to the elbow (a little toward the body; the left is mirrored), its palm
## facing in at the map so the thumb lies over the front of the paper, and fingertip-to-sleeve length.
const ARM := Vector3(0.05, -1.0, 0.2)
const PALM := Vector3(-1.0, 0.0, 0.0)
const ARM_LENGTH := 0.42
## map_hand.glb (a right fist, real size): where the paper's edge goes into the fist (its inner fingers, so the fist
## sits on the outside of the edge, off the maze), which way its forearm runs and its palm faces.
const HAND_GRIP := Vector3(0.003, 0.051, 0.137)
const HAND_ARM := Vector3(0.05, -0.32, -0.95)
const HAND_PALM := Vector3(1.0, 0.0, 0.0)
## The sheet is drawn in this 2D space (the 240 px minimap plus parchment margins) and rendered at SHEET_PIXELS; the
## ink is scaled down to sit inside the frame art.
const SHEET_2D := Vector2i(360, 270)
const SHEET_PIXELS := Vector2i(1152, 864)
const INK_SCALE := 0.75
const PAPER := Color(0.83, 0.75, 0.57)
## The sheet ignores the maze's lights so it can always be read, dimmed a little so it doesn't glare in the dark.
const PAPER_LIGHT := Color(0.85, 0.83, 0.8)
const SKIN := Color(0.62, 0.47, 0.38)
const SLEEVE := Color(0.13, 0.13, 0.15)
const PAPER_ART := Art.HUD + "map_paper.png"
const BACK_ART := Art.HUD + "map_paper_back.png"
const STAIN_ART := Art.HUD + "map_stains.png"
const FRAME_ART := Art.HUD + "map_frame.png"
const OPEN_SOUND := "res://assets/audio/sfx_map_open.mp3"
const CLOSE_SOUND := "res://assets/audio/sfx_map_close.mp3"
const SNAP_SOUND := "res://assets/audio/sfx_map_snap.mp3"
## The open clip peaks right at 0 dBFS: a little headroom so it never clips.
const SOUND_DB := -2.0
## Rolls the sheet up at both side edges: paper left of edges.x curls up to the left, right of edges.y to the right,
## each in a spiral toward you (ink inside, the back of the paper outside), as fat as the paper it holds.
const CURL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D front : source_color, filter_linear;
uniform sampler2D back : source_color, filter_linear;
uniform bool has_back;
uniform vec3 plain : source_color;
uniform vec3 light : source_color = vec3(1.0);
uniform vec2 edges;
uniform float width;
uniform float layer;
uniform float core;

// A point s metres into a roll holding `rolled` metres of paper: (along the sheet, out toward you, angle turned).
vec3 curl(float s, float rolled) {
	float outer = sqrt(core * core + layer * rolled / PI);
	float a = layer / TAU;
	float turn = (outer - sqrt(max(outer * outer - 2.0 * a * s, 0.0))) / a;
	float r = outer - a * turn;
	return vec3(r * sin(turn), outer - r * cos(turn), turn);
}

void vertex() {
	if (VERTEX.x > edges.y) {
		vec3 c = curl(VERTEX.x - edges.y, width - edges.y);
		VERTEX.xz = vec2(edges.y + c.x, c.y);
		NORMAL = vec3(-sin(c.z), 0.0, cos(c.z));
	} else if (VERTEX.x < edges.x) {
		vec3 c = curl(edges.x - VERTEX.x, edges.x);
		VERTEX.xz = vec2(edges.x - c.x, c.y);
		NORMAL = vec3(sin(c.z), 0.0, cos(c.z));
	}
}

void fragment() {
	vec4 ink = texture(front, UV);
	if (ink.a < 0.5) {
		discard;
	}
	vec3 paper = ink.rgb;
	if (!FRONT_FACING) {
		paper = has_back ? texture(back, vec2(1.0 - UV.x, UV.y)).rgb : plain * 0.8;
	}
	// Unlit so it always reads; darker where the paper turns away, so the rolls look round.
	ALBEDO = paper * light * mix(0.4, 1.0, clamp(NORMAL.z, 0.0, 1.0));
}
"""

## 0 = in the pocket, 1 = lifted to read (tweened by open/close).
var progress := 0.0:
	set(value):
		progress = value
		_pose()
## Head turn for main.gd's camera while the hand reaches back (radians; 0 outside the reach).
var dip := 0.0
## Camera-space nudge from main.gd's footsteps: the held map lags each step, so you feel the slow walk.
var bob := Vector3.ZERO:
	set(value):
		bob = value
		_pose()
## True from open() until close().
var opening := false
## The paper-mode minimap on the sheet (main.gd keeps it live while the map is up).
var sheet: Control
var _fov: float
var _view := SubViewport.new()
var _rig := Node3D.new()
var _paper := MeshInstance3D.new()
var _curl := ShaderMaterial.new()
## Right, left.
var _hands: Array[Node3D] = [Node3D.new(), Node3D.new()]
## The strapped roll in the right hand, until the left hand takes its edge and it becomes the sheet.
var _roll := Node3D.new()
var _sound := AudioStreamPlayer.new()
var _open_sound: AudioStream = load(OPEN_SOUND) if ResourceLoader.exists(OPEN_SOUND) else null
var _close_sound: AudioStream = load(CLOSE_SOUND) if ResourceLoader.exists(CLOSE_SOUND) else null
var _snap_sound: AudioStream = load(SNAP_SOUND) if ResourceLoader.exists(SNAP_SOUND) else null
var _tween: Tween


func _init(map: Control, fov: float) -> void:
	sheet = map
	_fov = fov


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The sheet: the map in ink on parchment, laid out small and rendered big so the lines stay sharp up close.
	var paper_view := SubViewport.new()
	paper_view.size = SHEET_PIXELS
	paper_view.size_2d_override = SHEET_2D
	paper_view.size_2d_override_stretch = true
	paper_view.transparent_bg = true
	paper_view.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	add_child(paper_view)
	paper_view.add_child(_parchment())
	_overlay(paper_view, STAIN_ART)  # blood and grime under the ink
	sheet.paper = true
	paper_view.add_child(sheet)
	sheet.scale = Vector2.ONE * INK_SCALE
	sheet.position = (Vector2(SHEET_2D) - Vector2.ONE * sheet.size.x * INK_SCALE) * 0.5
	_overlay(paper_view, FRAME_ART)  # the frame over it
	# The hands and the map in a world of their own, drawn over the game.
	_view.own_world_3d = true
	_view.transparent_bg = true
	_view.msaa_3d = Viewport.MSAA_4X
	_view.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	add_child(_view)
	var screen := TextureRect.new()
	screen.texture = _view.get_texture()
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var camera := Camera3D.new()
	camera.fov = _fov
	camera.near = 0.02
	camera.environment = Environment.new()
	camera.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	camera.environment.ambient_light_color = Color(0.5, 0.46, 0.42)
	_view.add_child(camera)
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.8, 0.5, 0.0)
	_view.add_child(light)
	_view.add_child(_rig)
	# The paper: a strip of thin quads from its left edge (x = 0) that the shader rolls up at both sides.
	var quad := QuadMesh.new()
	quad.size = SHEET
	quad.center_offset = Vector3(SHEET.x * 0.5, 0.0, 0.0)
	quad.subdivide_width = CURL_STEPS
	_paper.mesh = quad
	_paper.extra_cull_margin = SHEET.x  # the rolls stand out of the flat sheet's bounds
	_paper.position.x = -SHEET.x * 0.5
	var shader := Shader.new()
	shader.code = CURL_SHADER
	_curl.shader = shader
	var back := Art.tex(BACK_ART)
	_curl.set_shader_parameter("front", paper_view.get_texture())
	_curl.set_shader_parameter("back", back)
	_curl.set_shader_parameter("has_back", back != null)
	_curl.set_shader_parameter("plain", PAPER)
	_curl.set_shader_parameter("light", PAPER_LIGHT)
	_curl.set_shader_parameter("width", SHEET.x)
	_curl.set_shader_parameter("layer", ROLL_LAYER)
	_curl.set_shader_parameter("core", ROLL_CORE)
	_paper.material_override = _curl
	_rig.add_child(_paper)
	var skin := _material(SKIN)
	var sleeve := _material(SLEEVE)
	for hand in _hands:
		_build_hand(hand, skin, sleeve)
		_rig.add_child(hand)
	_hands[1].scale.x = -1.0  # the left hand is the right one mirrored
	_build_roll()
	_hands[0].add_child(_roll)
	_sound.volume_db = SOUND_DB
	_sound.bus = Settings.SFX_BUS
	add_child(_sound)
	_show(false)
	_pose()


## Out of the pocket and up to read, from wherever it is now.
func open() -> void:
	_play(true, OPEN_TIME, _open_sound)


## Back into the pocket; a snap is the fast way (a flip, the Devil close).
func close(snap := false) -> void:
	if visible:
		_play(false, SNAP_TIME if snap else CLOSE_TIME, _snap_sound if snap and _snap_sound != null else _close_sound)


## Gone at once (the floor is over).
func stow() -> void:
	if _tween != null:
		_tween.kill()
	opening = false
	progress = 0.0
	_show(false)


## In your hands: coming out, open or going back.
func is_up() -> bool:
	return visible


## Where the map is in the move (main.gd gates M, the flip and the walk on it).
func state() -> State:
	if not visible:
		return State.CLOSED
	if not opening:
		return State.CLOSING
	if progress >= 1.0:
		return State.OPEN
	return State.DRAWING if progress < UNROLL_FROM else State.UNROLLING


## Outer radius (m) of a roll holding `rolled` metres of paper (CURL_SHADER's curl()).
static func roll_radius(rolled: float) -> float:
	return sqrt(ROLL_CORE * ROLL_CORE + ROLL_LAYER * rolled / PI)


func _play(up: bool, time: float, sound: AudioStream) -> void:
	opening = up
	_show(true)
	if up:
		# Rendered at the screen's real pixels, so the map stays crisp at any window size.
		_view.size = Vector2i((size * get_viewport().get_final_transform().get_scale()).round()).max(Vector2i.ONE)
	if _tween != null:
		_tween.kill()
	var goal := 1.0 if up else 0.0
	_tween = create_tween()
	_tween.tween_property(self, "progress", goal, absf(goal - progress) * time)
	if not up:
		_tween.tween_callback(_show.bind(false))
	if sound != null:
		_sound.stream = sound
		_sound.play()


func _show(on: bool) -> void:
	visible = on
	sheet.visible = on  # a hidden sheet isn't redrawn every frame


## Everything at `progress`: the right hand brings the strapped roll up from the pocket, the left takes its edge, the
## right pulls the roll across and the paper uncurls behind it, then the open map comes up to the eyes.
func _pose() -> void:
	var reach := smoothstep(0.0, 0.3, progress)
	var grab := smoothstep(0.15, UNROLL_FROM, progress)
	var unroll := smoothstep(UNROLL_FROM, 0.78, progress)
	var lift := smoothstep(0.75, 1.0, progress)
	dip = sin(clampf(progress / 0.3, 0.0, 1.0) * PI) * DIP
	_rig.position = HELD.lerp(LIFTED, lift) + bob
	_rig.rotation.x = lerpf(HELD_TILT, 0.0, lift)
	# Sheet x (from its left edge) where the right roll starts: everything right of it is rolled up. Lifted to read, the
	# last curls let go and the map is held flat by its side edges.
	var curl := lerpf(EDGE_CURL, 0.0, lift)
	var roll_at := lerpf(EDGE_CURL, SHEET.x - curl, unroll)
	_curl.set_shader_parameter("edges", Vector2(curl, roll_at))
	var unstrapped := progress >= UNROLL_FROM
	_paper.visible = unstrapped
	_roll.visible = not unstrapped
	var left_edge := -SHEET.x * 0.5
	var hold := EDGE_HOLD * lift
	var right_grip := Vector3(left_edge + roll_at - hold, GRIP_Y, roll_radius(SHEET.x - roll_at))
	_hands[0].position = POCKET.lerp(right_grip, reach)
	_hands[0].rotation.z = lerpf(POCKET_TILT, 0.0, reach)
	var left_grip := Vector3(left_edge + curl + hold, GRIP_Y, roll_radius(curl))
	_hands[1].position = Vector3(-POCKET.x, POCKET.y, POCKET.z).lerp(left_grip, grab)


## The paper under the ink: the delivered parchment, else a plain sheet with a darker edge.
func _parchment() -> Control:
	var art := Art.tex(PAPER_ART)
	if art != null:
		return _sheet_image(art)
	var plain := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = PAPER.darkened(0.4)
	style.set_border_width_all(3)
	plain.add_theme_stylebox_override("panel", style)
	plain.size = Vector2(SHEET_2D)
	return plain


## A delivered picture over the whole sheet (the stains, the frame); nothing until it arrives.
func _overlay(view: SubViewport, path: String) -> void:
	var art := Art.tex(path)
	if art != null:
		view.add_child(_sheet_image(art))


func _sheet_image(art: Texture2D) -> TextureRect:
	var image := TextureRect.new()
	image.texture = art
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.size = Vector2(SHEET_2D)
	return image


## A right hand gripping a roll at its origin, the forearm running back along ARM: the delivered fist, else a skin
## block, a thumb over the front of the paper and a dark sleeve.
func _build_hand(hand: Node3D, skin: StandardMaterial3D, sleeve: StandardMaterial3D) -> void:
	var art := Art.model("map_hand")
	if art != null:
		var model: Node3D = art.instantiate()
		# Turn the fist so its forearm runs along ARM with the palm toward PALM, the paper's edge at HAND_GRIP.
		var turn := Basis.looking_at(ARM, PALM) * Basis.looking_at(HAND_ARM, HAND_PALM).inverse()
		model.transform = Transform3D(turn, -(turn * HAND_GRIP))
		hand.add_child(model)
		return
	var arm := Node3D.new()
	arm.basis = Basis(Quaternion(Vector3.DOWN, ARM.normalized()))
	hand.add_child(arm)
	var palm := BoxMesh.new()
	palm.size = Vector3(0.045, 0.09, 0.03)
	hand.add_child(_part(palm, Vector3(0.022, -0.015, 0.0), skin))
	var thumb := CapsuleMesh.new()
	thumb.radius = 0.009
	thumb.height = 0.048
	var thumb_part := _part(thumb, Vector3(-0.004, 0.006, 0.03), skin)
	thumb_part.rotation.z = 0.5
	hand.add_child(thumb_part)
	var forearm := CylinderMesh.new()
	forearm.top_radius = 0.026
	forearm.bottom_radius = 0.034
	forearm.height = ARM_LENGTH - 0.06
	arm.add_child(_part(forearm, Vector3(0.0, -0.06 - forearm.height * 0.5, 0.0), sleeve))


## The strapped roll, upright on the sheet's middle (the hand holds it GRIP_Y below): the delivered model, else a
## paper tube. Either way as tall as the sheet and as thick as the sheet rolled up, so it becomes the sheet without a
## jump.
func _build_roll() -> void:
	_roll.position.y = -GRIP_Y
	var art := Art.model("map_roll")
	if art != null:
		var model: Node3D = art.instantiate()
		var size := ModelFit.mesh_bounds(model).size
		var thick := 2.0 * roll_radius(SHEET.x - EDGE_CURL) / size.z
		model.scale = Vector3(thick, SHEET.y / size.y, thick)
		_roll.add_child(model)
		return
	var tube := CylinderMesh.new()
	tube.top_radius = roll_radius(SHEET.x - EDGE_CURL)
	tube.bottom_radius = tube.top_radius
	tube.height = SHEET.y
	_roll.add_child(_part(tube, Vector3.ZERO, _material(PAPER.darkened(0.15))))


func _part(mesh: PrimitiveMesh, at: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	return part


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material
