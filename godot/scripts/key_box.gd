class_name KeyBox
extends Node3D
## A plain wooden box down a dead end (FloorLayout.boxes): the keys hide in some, the rest are empty. Not the exit's
## iron chest: no locks, no gold. open() works the lid loose, then it swings up; main.gd decides what's inside.
## Front = local +Z.

signal opened

const WIDTH := 0.7
const DEPTH := 0.48
const BASE_HEIGHT := 0.4
const LID_HEIGHT := 0.07
const WOOD := Color(0.36, 0.24, 0.14)
## The lid sticks: it cracks CRACK_DEGREES open, holds HOLD_TIME (is it in there?), then swings up.
const CRACK_DEGREES := -14.0
const CRACK_TIME := 0.15
const HOLD_TIME := 0.2
## Just past upright: it rests against the wall behind the box (main.gd::BOX_WALL_GAP) without sinking into it.
const LID_OPEN_DEGREES := -95.0
const OPEN_TIME := 0.4
const LID_TIME := CRACK_TIME + HOLD_TIME + OPEN_TIME
## Locksmith (omen): a box holding a key leaks a faint light of the key's colour round its lid.
const GLINT_ENERGY := 0.35
const GLINT_RANGE := 2.2
## Opening it with your hands (main.gd kneels you; BoxHands and your body's DevilRig poses follow), seconds after the
## click: down on a knee by KNEEL_IN; the right fist takes the lid's edge at GRIP_AT and the lid starts (LID_TIME);
## the left fist dips in from DIP_AT, closes on what's there at TAKE_AT and holds a key up before your eyes by
## SHOW_AT; the key flies to the HUD at FLY_AT; on your feet again by END.
const KNEEL_IN := 0.3
const GRIP_AT := 0.3
const DIP_AT := 0.8
const TAKE_AT := 1.1
const SHOW_AT := 1.35
const FLY_AT := 1.6
const END := 1.9

var lid: Node3D
## Height (local) of the box's opening: the key waits just under it.
var top := BASE_HEIGHT
var is_open := false
## Lid space: the middle of its front edge, where your fist takes it.
var _edge := Vector3(0.0, LID_HEIGHT * 0.5, DEPTH)


## `glint` (alpha > 0) lights the box from inside: the Locksmith's tell.
func build(collision_layer: int, glint := Color(0, 0, 0, 0)) -> void:
	var scene := Art.model("key_box")
	if scene != null:
		_build_model(scene)
	else:
		_build_box()
	if glint.a > 0.0:
		var light := OmniLight3D.new()
		light.light_color = Color(glint, 1.0)
		light.light_energy = GLINT_ENERGY
		light.omni_range = GLINT_RANGE
		light.position = Vector3(0, top + 0.05, 0)
		add_child(light)
	var body := StaticBody3D.new()
	body.collision_layer = collision_layer
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WIDTH, top + LID_HEIGHT, DEPTH)
	shape.shape = box
	shape.position.y = box.size.y * 0.5
	body.add_child(shape)
	add_child(body)


## Work the lid loose, then swing it up; `opened` fires once it's up.
func open() -> void:
	is_open = true
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void: lid.rotation.x = lid_angle(t), 0.0, LID_TIME, LID_TIME)
	tween.tween_callback(opened.emit)


## The lid's tilt (rotation.x, radians) `t` s after it starts: open()'s crack, hold and swing (the Devil Cam replays it).
static func lid_angle(t: float) -> float:
	var crack := deg_to_rad(CRACK_DEGREES)
	if t < CRACK_TIME:
		return float(Tween.interpolate_value(0.0, crack, maxf(t, 0.0), CRACK_TIME, Tween.TRANS_SINE, Tween.EASE_IN_OUT))
	if t < CRACK_TIME + HOLD_TIME:
		return crack
	var swing := minf(t - CRACK_TIME - HOLD_TIME, OPEN_TIME)
	return float(Tween.interpolate_value(crack, deg_to_rad(LID_OPEN_DEGREES) - crack, swing, OPEN_TIME, Tween.TRANS_BACK, Tween.EASE_OUT))


## 0..1: how far down on the knee, `t` s into the opening.
static func kneel_at(t: float) -> float:
	return smoothstep(0.0, KNEEL_IN, t) * (1.0 - smoothstep(FLY_AT, END, t))


## 0..1: the right fist reaching for the lid's edge and working it loose; it shoves the lid up as the swing starts and
## drops back out of sight while the lid swings on by itself.
static func lid_reach(t: float) -> float:
	return smoothstep(0.05, GRIP_AT, t) * (1.0 - smoothstep(GRIP_AT + CRACK_TIME + HOLD_TIME + 0.1, GRIP_AT + CRACK_TIME + HOLD_TIME + 0.35, t))


## 0..1: the right fist closed on the edge, until the shove.
static func lid_grip(t: float) -> float:
	return smoothstep(GRIP_AT - 0.08, GRIP_AT, t) * (1.0 - smoothstep(GRIP_AT + CRACK_TIME + HOLD_TIME + 0.05, GRIP_AT + CRACK_TIME + HOLD_TIME + 0.15, t))


## The left fist, `t` s into the opening: x = its reach into the box (0 = at your side), y = how far from in the box up
## to before your eyes, z = closed. A key comes up held; from an empty box the fist comes back out.
static func left_hand(t: float, found: bool) -> Vector3:
	var into := smoothstep(DIP_AT, TAKE_AT, t)
	var closed := smoothstep(TAKE_AT - 0.08, TAKE_AT, t)
	if found:
		return Vector3(into * (1.0 - smoothstep(FLY_AT, END, t)), smoothstep(TAKE_AT, SHOW_AT, t), closed * (1.0 - smoothstep(FLY_AT, FLY_AT + 0.1, t)))
	var back := smoothstep(TAKE_AT + 0.05, SHOW_AT + 0.1, t)
	return Vector3(into * (1.0 - back), 0.0, closed * (1.0 - back))


## Where your fist takes the lid (world): the middle of its front edge, wherever the lid has swung.
func grip_point() -> Vector3:
	return lid.global_transform * _edge


## The lid's front, out from the hinge (world): it tips up as the lid swings.
func lid_front() -> Vector3:
	return lid.global_basis.z.normalized()


## Down inside the box (world): where your left fist takes the key.
func inside_point() -> Vector3:
	return global_transform * Vector3(0.0, top * 0.5, 0.0)


## Empty: a breath of dust out of the open box (the smoke FX sprite, else grains).
func puff() -> void:
	var mesh: Mesh
	var smoke := Art.fx_material(Art.Fx.SMOKE, Color(0.42, 0.37, 0.33, 0.7), false)
	if smoke != null:
		mesh = QuadMesh.new()
		(mesh as QuadMesh).size = Vector2.ONE * 0.3
		mesh.material = smoke
	else:
		mesh = BoxMesh.new()
		(mesh as BoxMesh).size = Vector3.ONE * 0.03
		var grain := StandardMaterial3D.new()
		grain.albedo_color = Color(0.32, 0.28, 0.24)
		mesh.material = grain
	var dust := CPUParticles3D.new()
	dust.mesh = mesh
	dust.position = Vector3(0, top + 0.05, 0)
	dust.one_shot = true
	dust.explosiveness = 0.8
	dust.amount = 16
	dust.lifetime = 1.2
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(WIDTH * 0.4, 0.02, DEPTH * 0.4)
	dust.direction = Vector3.UP
	dust.spread = 25.0
	dust.initial_velocity_min = 0.3
	dust.initial_velocity_max = 0.7
	dust.gravity = Vector3(0, -0.4, 0)
	dust.emitting = true
	add_child(dust)


## The delivered model (Art slot models/key_box.glb), WIDTH wide; its "Lid" node pivots on the back hinge.
func _build_model(scene: PackedScene) -> void:
	var model := scene.instantiate() as Node3D
	model.scale = Vector3.ONE * (WIDTH / ModelFit.mesh_bounds(model).size.x)
	add_child(model)
	# A scanned hull has no inner walls: once the lid is up, its underside and the box's inside must still draw.
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var two_sided := part.mesh.surface_get_material(0).duplicate() as BaseMaterial3D
		two_sided.cull_mode = BaseMaterial3D.CULL_DISABLED
		part.material_override = two_sided
	lid = model.find_child("Lid", true, false)
	top = lid.position.y * model.scale.y if lid != null else ModelFit.mesh_bounds(model).end.y * model.scale.y
	if lid == null:
		lid = Node3D.new()  # fused model: nothing swings
		add_child(lid)
		_edge = Vector3(0.0, top, DEPTH * 0.5)
	else:
		var bounds := ModelFit.mesh_bounds(lid)
		_edge = Vector3(bounds.get_center().x, bounds.get_center().y, bounds.end.z)


## The stand-in: a plain dark wooden box with two darker slats and a lid hinged on the back top edge. A black
## inset under the lid reads as its hollow.
func _build_box() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = WOOD
	wood.roughness = 0.9
	var slat := StandardMaterial3D.new()
	slat.albedo_color = WOOD.darkened(0.5)
	slat.roughness = 0.95
	var hollow := StandardMaterial3D.new()
	hollow.albedo_color = Color.BLACK
	TreasureChest._box(self, Vector3(WIDTH, BASE_HEIGHT, DEPTH), Vector3(0, BASE_HEIGHT * 0.5, 0), wood)
	for y in [0.08, BASE_HEIGHT - 0.08]:
		TreasureChest._box(self, Vector3(WIDTH + 0.02, 0.05, DEPTH + 0.02), Vector3(0, y, 0), slat)
	TreasureChest._box(self, Vector3(WIDTH - 0.08, 0.004, DEPTH - 0.08), Vector3(0, BASE_HEIGHT + 0.002, 0), hollow)
	lid = Node3D.new()
	lid.position = Vector3(0, BASE_HEIGHT, -DEPTH * 0.5)
	add_child(lid)
	TreasureChest._box(lid, Vector3(WIDTH, LID_HEIGHT, DEPTH), Vector3(0, LID_HEIGHT * 0.5, DEPTH * 0.5), wood)
