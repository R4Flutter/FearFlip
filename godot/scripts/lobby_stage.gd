extends SubViewportContainer
## The dashboard's lobby (BGMI-style): the body you play, in 3D, standing on lobby_bg.png's terrace floor between the
## menu and the right side, with attitude (DevilRig.showcase: chin up, fist on the hip). A transparent 3D view of its own over
## the key art. Its feet stay planted on the floor (user, 17 Oct 2026); only the upper body moves: it looks straight at
## you, breathes and sways, tenses up while a play control is focused (set_nightmare), flinches at the lightning
## (thunder) or a tap (flinch). A drag turns it on the spot (spin); left alone it turns back to face you.

## The body you play (main.gd's PLAYER_MODEL), loaded on a thread so the menu shows at once.
const MODEL := "res://assets/character/character2withrig.glb"
## character2withrig faces +X (main.gd turns it 90 degrees to face -Z); this turns it to +Z, the camera.
const FACE_YAW := -90.0
const HEIGHT := 1.75
## A showcase stance: the body a little off the camera (radians), the head round to you, the fist-on-hip side
## (DevilRig.showcase: the left) toward you.
const REST_TURN := -0.35
## Camera eye, aim and lens, matched to lobby_bg.png: looking down ~7 degrees puts the horizon ~28% down the screen,
## where the painting's sits, so the feet stand on its floor. The menu's sideways parallax (-1..1) swings it round the
## hero this far (radians); never a tilt, which would slide the feet up and down that floor.
const EYE := Vector3(0.0, 1.48, 4.7)
const AIM := Vector3(0.0, 0.92, 0.0)
const FOV := 30.0
const ORBIT := 0.1
## A drag turns it SPIN_PER_PX radians a pixel, followed at SPIN_FOLLOW; left alone SPIN_RETURN_AFTER s, it turns back.
const SPIN_PER_PX := 0.012
const SPIN_FOLLOW := 10.0
const SPIN_RETURN_AFTER := 4.0
const SPIN_RETURN := 1.2
## The drag area: a column GRAB_WIDTH px wide down the middle, from GRAB_TOP to the bottom (above it the dashboard
## still slides).
const GRAB_WIDTH := 240.0
const GRAB_TOP := 120.0
## The head looks straight at you (as far round as NECK radians when the body is turned away), drifting by up to
## LOOK_DRIFT (yaw, pitch radians) over a slow idle, eased at LOOK_FOLLOW. The model's head leans 13 degrees forward at
## rest (Head to HeadTop_End), so CHIN_UP lifts it past level: the face looks straight out, chin up.
const NECK := 1.0
const CHIN_UP := 0.25
const LOOK_DRIFT := Vector2(0.08, 0.03)
const LOOK_FOLLOW := 4.0
## Fear while the demon is awake (DevilRig.COWER_FEAR is 0.75: it tenses but doesn't cower), reached at FEAR_RATE/s.
const AWAKE_FEAR := 0.55
const FEAR_RATE := 1.5
const TAP_FLINCH := 0.8
const THUNDER_FLINCH := 0.35
## Entrance: it fades in where it stands over APPEAR_TIME (no turn: the feet never shift).
const APPEAR_TIME := 0.8
## Light: lava rim from behind (RIM_ENERGY: calm, demon awake), a warm key from the front, violet ambient, a faint red
## bounce off the floor's lava cracks (any brighter and the boots glow off the floor), lightning. The rims stay low:
## brighter, they light the creases of the clothes' normal map like lava cracks.
const RIM := Color(1.0, 0.25, 0.08)
const RIM_ENERGY := Vector2(3.0, 5.0)
const KEY := Color(1.0, 0.92, 0.86)
const KEY_ENERGY := 1.5
const KEY_ANGLES := Vector3(-30.0, -25.0, 0.0)
## The key spot: metres back along that direction, cone half-angle (degrees), the height it aims at (metres).
const KEY_SPOT := Vector3(5.0, 13.0, 1.2)
const AMBIENT := Color(0.45, 0.32, 0.55)
const BOUNCE := Color(1.0, 0.18, 0.06)
const BOUNCE_ENERGY := 0.3
const LIGHTNING := Color(0.62, 0.55, 1.0)
const FLASH_ENERGY := 2.5
## Shadows on the painted floor, so the body stands on it, not over it (this renderer can't catch a real shadow on an
## unseen floor: shadow_to_opacity showed nothing): the body's shadow cast away from the key light, a long soft patch
## (width, length in metres, darkness); a soft pool round the body (metres across, darkness); under each boot a dark
## contact patch that follows the foot (width, length in metres, darkness), solid to SOLE_CORE of the way out; and a
## negative light at the feet (energy, range in metres) that darkens the boots and the hems the way the floor would.
const CAST_SHADOW := Vector3(0.8, 2.0, 0.65)
const SHADOW := Vector2(0.95, 0.85)
const FOOT_SHADOW := Vector3(0.22, 0.45, 1.0)
const SOLE_CORE := 0.55
const FOOT_DARK := Vector2(-1.2, 0.6)

## The menu's parallax (-1..1 each way), set every frame.
var parallax := Vector2.ZERO
var _view: SubViewport
var _camera: Camera3D
var _turntable: Node3D
var _body: Node3D
var _rig: DevilRig
var _feet_y := 0.0
var _rims: Array[OmniLight3D] = []
var _flash: DirectionalLight3D
## Per boot: its ankle and ball-of-the-foot bones and the contact patch under them.
var _feet: Array[Array] = []
var _world_tween: Tween
var _loading := false
## The drag's turn and the body's turn following it (radians); seconds since the last drag.
var _spin := 0.0
var _turn := 0.0
var _alone := 0.0
var _look := Vector2.ZERO
var _fear := 0.0
var _fear_goal := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The view renders premultiplied (its edges and haze are colour x coverage over a clear background), so it's drawn
	# that way, and faded by modulating colour and alpha together.
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	modulate = Color.TRANSPARENT
	_view = SubViewport.new()
	_view.transparent_bg = true
	_view.own_world_3d = true
	_view.msaa_3d = Viewport.MSAA_4X
	add_child(_view)
	stretch = true
	_build_light()
	_build_shadow()
	_turntable = Node3D.new()
	_view.add_child(_turntable)
	_camera = Camera3D.new()
	_camera.fov = FOV
	_view.add_child(_camera)
	_camera.look_at_from_position(EYE, AIM)
	if ResourceLoader.exists(MODEL):
		_loading = ResourceLoader.load_threaded_request(MODEL) == OK
	if not _loading:
		_appear()


func _process(delta: float) -> void:
	if _loading and ResourceLoader.load_threaded_get_status(MODEL) != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		_loading = false
		_build_body(ResourceLoader.load_threaded_get(MODEL) as PackedScene)
		_appear()
	_camera.look_at_from_position(AIM + (EYE - AIM).rotated(Vector3.UP, -parallax.x * ORBIT), AIM)
	_alone += delta
	if _alone > SPIN_RETURN_AFTER:  # back to face you, the short way round
		_spin = lerpf(_spin, roundf(_spin / TAU) * TAU, 1.0 - exp(-SPIN_RETURN * delta))
	_turn = lerpf(_turn, _spin, 1.0 - exp(-SPIN_FOLLOW * delta))
	_turntable.rotation.y = REST_TURN + _turn
	if _rig == null:
		return
	var t := Time.get_ticks_msec() * 0.001
	var away := wrapf(_turntable.rotation.y, -PI, PI)
	var goal := Vector2(clampf(-away, -NECK, NECK) + LOOK_DRIFT.x * sin(t * 0.37), CHIN_UP + LOOK_DRIFT.y * sin(t * 0.23))
	_look = _look.lerp(goal, 1.0 - exp(-LOOK_FOLLOW * delta))
	_fear = move_toward(_fear, _fear_goal, FEAR_RATE * delta)
	_rig.flee(0.0, delta, _fear, 0.0, _look)
	_body.position.y = _feet_y + _rig.showcase(1.0)
	var bones := _rig.skeleton.global_transform
	for foot in _feet:
		var ankle: Vector3 = bones * _rig.skeleton.get_bone_global_pose(foot[0]).origin
		var ball: Vector3 = bones * _rig.skeleton.get_bone_global_pose(foot[1]).origin
		var patch: Node3D = foot[2]
		patch.position = Vector3((ankle.x + ball.x) * 0.5, 0.004, (ankle.z + ball.z) * 0.5)
		patch.rotation.y = atan2(ball.x - ankle.x, ball.z - ankle.z)


func _exit_tree() -> void:
	if _loading:  # gone before the body came: collect the load, or the loader holds it until exit
		ResourceLoader.load_threaded_get(MODEL)


## True when a press at `point` (canvas) should turn the body rather than slide the dashboard.
func grabs(point: Vector2) -> bool:
	var column := Rect2(global_position + Vector2((size.x - GRAB_WIDTH) * 0.5, GRAB_TOP), Vector2(GRAB_WIDTH, size.y - GRAB_TOP))
	return column.has_point(point)


func spin(pixels: float) -> void:
	_spin += pixels * SPIN_PER_PX
	_alone = 0.0


func flinch(strength := TAP_FLINCH) -> void:
	if _rig != null:
		_rig.startle(strength)


## The demon wakes (a play control focused): the body tenses, the rim light burns brighter.
func set_nightmare(on: bool) -> void:
	_fear_goal = AWAKE_FEAR if on else 0.0
	if _world_tween:
		_world_tween.kill()
	_world_tween = create_tween().set_parallel().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	for rim in _rims:
		_world_tween.tween_property(rim, "light_energy", RIM_ENERGY[1 if on else 0], 0.3)


## The menu's lightning: the same double flicker lights the body from behind, and it flinches.
func thunder() -> void:
	flinch(THUNDER_FLINCH)
	var flash := create_tween()
	flash.tween_property(_flash, "light_energy", FLASH_ENERGY, 0.04)
	flash.tween_property(_flash, "light_energy", FLASH_ENERGY * 0.15, 0.06)
	flash.tween_property(_flash, "light_energy", FLASH_ENERGY * 0.7, 0.04)
	flash.tween_property(_flash, "light_energy", 0.0, 0.6)


func _appear() -> void:
	create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).tween_property(self, "modulate", Color.WHITE, APPEAR_TIME)


func _build_body(scene: PackedScene) -> void:
	if scene == null:
		return
	_body = scene.instantiate()
	_body.rotation_degrees.y = FACE_YAW
	ModelFit.fit_height(_body, HEIGHT, 0.0)
	_feet_y = _body.position.y
	_turntable.add_child(_body)
	_rig = DevilRig.new(_body, false)
	_rig.unstick_hands()
	for side in ["Left", "Right"]:
		var patch := _shadow(Vector2(FOOT_SHADOW.x, FOOT_SHADOW.y), FOOT_SHADOW.z, SOLE_CORE)
		_feet.append([_rig.skeleton.find_bone("mixamorig_%sFoot" % side), _rig.skeleton.find_bone("mixamorig_%sToeBase" % side), patch])


func _build_light() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIENT
	env.ambient_light_energy = 0.6
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED  # the grey clear colour rimmed every edge cyan-white
	var world := WorldEnvironment.new()
	world.environment = env
	_view.add_child(world)
	# The key: a spot from the front left and above on the upper body, fading off by the boots, so they sit in the floor's
	# shade instead of glowing over it.
	var key := SpotLight3D.new()
	key.light_color = KEY
	key.light_energy = KEY_ENERGY
	key.spot_range = KEY_SPOT.x * 2.0
	key.spot_attenuation = 0.0  # no fall-off with distance: only the cone's edge dims it
	key.spot_angle = KEY_SPOT.y
	_view.add_child(key)
	var aim := Vector3.UP * KEY_SPOT.z
	key.look_at_from_position(aim - Basis.from_euler(KEY_ANGLES * PI / 180.0) * Vector3.FORWARD * KEY_SPOT.x, aim)
	for side: float in [-1.0, 1.0]:  # well behind, so they only catch the edges
		var rim := OmniLight3D.new()
		rim.light_color = RIM
		rim.light_energy = RIM_ENERGY.x
		rim.omni_range = 4.0
		rim.position = Vector3(side * 0.6, 1.7, -2.2)
		_view.add_child(rim)
		_rims.append(rim)
	var bounce := OmniLight3D.new()  # the floor's lava cracks light the boots from below
	bounce.light_color = BOUNCE
	bounce.light_energy = BOUNCE_ENERGY
	bounce.omni_range = 1.0
	bounce.position = Vector3(0.0, 0.1, 0.45)
	_view.add_child(bounce)
	var dark := OmniLight3D.new()  # the floor shades the boots
	dark.light_energy = FOOT_DARK.x
	dark.omni_range = FOOT_DARK.y
	dark.position = Vector3(0.0, 0.03, 0.0)
	_view.add_child(dark)
	_flash = DirectionalLight3D.new()  # from behind, above
	_flash.light_color = LIGHTNING
	_flash.light_energy = 0.0
	_flash.rotation_degrees = Vector3(-50.0, 160.0, 0.0)
	_view.add_child(_flash)


## The body's shadow cast away from the key light, and the soft pool it stands in, lying on the painted floor.
func _build_shadow() -> void:
	var away := Basis.from_euler(KEY_ANGLES * PI / 180.0) * Vector3.FORWARD
	away = Vector3(away.x, 0.0, away.z).normalized()
	var cast := _shadow(Vector2(CAST_SHADOW.x, CAST_SHADOW.y), CAST_SHADOW.z, 0.0)
	cast.position = away * CAST_SHADOW.y * 0.4 + Vector3.UP * 0.001
	cast.rotation.y = atan2(away.x, away.z)
	_shadow(Vector2.ONE * SHADOW.x, SHADOW.y, 0.0).position.y = 0.002


## A dark patch `extent` metres (x across, z along) on the floor, `darkness` at its middle, nearly as dark out to `solid`
## of the way to its rim (0: fading all the way), then fading.
func _shadow(extent: Vector2, darkness: float, solid: float) -> MeshInstance3D:
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dark.albedo_color = Color(0.0, 0.0, 0.0, darkness)
	dark.albedo_texture = _radial()
	if solid > 0.0:
		(dark.albedo_texture as GradientTexture2D).gradient.add_point(solid, Color(1.0, 1.0, 1.0, 0.85))
	var plane := PlaneMesh.new()
	plane.size = extent
	var patch := MeshInstance3D.new()
	patch.mesh = plane
	patch.material_override = dark
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_view.add_child(patch)
	return patch


## White, opaque in the middle, clear at the rim.
static func _radial() -> GradientTexture2D:
	var fade := GradientTexture2D.new()
	fade.fill = GradientTexture2D.FILL_RADIAL
	fade.fill_from = Vector2(0.5, 0.5)
	fade.fill_to = Vector2(0.5, 0.0)
	fade.gradient = Gradient.new()
	fade.gradient.set_color(0, Color.WHITE)
	fade.gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	return fade
