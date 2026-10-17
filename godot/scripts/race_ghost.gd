class_name RaceGhost
extends Node3D
## The Long Night's ghost (plans/11): your best run of the week walks the maze beside you, in step with the race
## clock, as a pale see-through copy of your body (the same rig and gait, paced by the recorded speed). Only you see
## it (build()'s layer: never the Devil Cams), it fades as you walk into it, and it fades away at the exit.

## A run is kept as one sample every STEP seconds of race time: x, z and the way the body faced.
const STEP := 0.2
## Your best run is pale blue; a rival's (v2: the run just ahead of yours on the board) is ember red, under its name.
const LOOK := Color(0.62, 0.8, 1.0, 0.24)
const RIVAL_LOOK := Color(1.0, 0.42, 0.3, 0.3)
## Fully clear within NEAR metres of you (you'd be inside its head), fully there past NEAR + FADE_IN.
const NEAR := 0.8
const FADE_IN := 1.5
const FADE_OUT_TIME := 1.2

var samples := PackedFloat32Array()
var look := LOOK
var _mesh: Node3D
var _tag: Label3D
var _rig: DevilRig
var _look: StandardMaterial3D
var _feet_y := 0.0
var _gone := 0.0


## True once `time` seconds of a run are due their next sample (a run of `count` floats so far).
static func due(count: int, time: float) -> bool:
	return time >= count / 3.0 * STEP


## A copy of `model` fitted like the player's body (height, feet at `feet_y`, turned by `yaw_degrees`), on `layer`.
func build(model: PackedScene, height: float, feet_y: float, yaw_degrees: float, walk: float, sprint: float, layer: int) -> void:
	_mesh = model.instantiate()
	_mesh.rotation_degrees.y = yaw_degrees
	ModelFit.fit_height(_mesh, height, feet_y)
	add_child(_mesh)
	_feet_y = feet_y
	_rig = DevilRig.new(_mesh, false)
	_rig.unstick_hands()
	_rig.walk_pace = walk
	_rig.sprint_pace = sprint
	_look = StandardMaterial3D.new()
	_look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_look.albedo_color = look
	for part: MeshInstance3D in _mesh.find_children("*", "MeshInstance3D", true, false):
		part.layers = layer
		part.material_override = _look
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


## `text` over its head (a rival's name and time), on `layer` like the body; fades with it.
func tag(text: String, height: float, layer: int) -> void:
	_tag = Label3D.new()
	_tag.text = text
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.position.y = _feet_y + height + 0.25
	_tag.modulate = Color(look, 0.0)
	_tag.layers = layer
	add_child(_tag)


## Where the run was `time` seconds in (you stand at `you`): walking there, fading near you and once it has escaped.
func seek(time: float, delta: float, you: Vector3) -> void:
	@warning_ignore("integer_division")
	var count := samples.size() / 3
	if _mesh == null or count < 2:
		return
	var at := time / STEP
	var i := mini(floori(at), count - 2)
	var t := clampf(at - i, 0.0, 1.0)
	var a := Vector2(samples[i * 3], samples[i * 3 + 1])
	var b := Vector2(samples[i * 3 + 3], samples[i * 3 + 4])
	var here := a.lerp(b, t)
	position = Vector3(here.x, position.y, here.y)
	rotation.y = lerp_angle(samples[i * 3 + 2], samples[i * 3 + 5], t)
	var escaped := at >= count - 1
	_mesh.position.y = _feet_y + _rig.flee(0.0 if escaped else a.distance_to(b) / STEP, delta, 0.0, 0.0)
	_gone = move_toward(_gone, 1.0 if escaped else 0.0, delta / FADE_OUT_TIME)
	var near := clampf((Vector2(you.x, you.z).distance_to(here) - NEAR) / FADE_IN, 0.0, 1.0)
	_look.albedo_color.a = look.a * near * (1.0 - _gone)
	if _tag != null:
		_tag.modulate.a = near * (1.0 - _gone)
	visible = _look.albedo_color.a > 0.01
