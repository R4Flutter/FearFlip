class_name TreasureChest
extends Node3D
## The floor's exit: an iron-banded chest with one lock per key. unlock() flies the keys in from
## the camera one by one; each drops into its lock and turns with a click and a gold glint. Then
## the chest shudders and the lid bursts open on a flood of gold light. Front = local +Z.

signal key_turned(index: int)
signal opened

const WIDTH := 1.05
const DEPTH := 0.66
const BASE_HEIGHT := 0.52
const LID_HEIGHT := 0.24
const LOCK_X: Array[float] = [-0.32, 0.0, 0.32]
const LOCK_Y := 0.3
## Key in hand: length (metres). In the lock it hangs blade-down from the keyhole, then turns.
const KEY_LENGTH := 0.28
const FLY_TIME := 0.5
const TURN_TIME := 0.22
const LID_OPEN_DEGREES := -110.0
const WOOD := Color(0.2, 0.09, 0.05)
const IRON := Color(0.75, 0.56, 0.24)

var lid: Node3D
var _locks: Array[StandardMaterial3D] = []
var _glow: OmniLight3D
var _treasure: StandardMaterial3D


func build(collision_layer: int) -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = WOOD
	wood.roughness = 0.85
	var iron := StandardMaterial3D.new()
	iron.albedo_color = IRON
	iron.metallic = 0.85
	iron.roughness = 0.35
	_box(self, Vector3(WIDTH, BASE_HEIGHT, DEPTH), Vector3(0, BASE_HEIGHT * 0.5, 0), wood)
	# Iron bands round the base and up the corners.
	_box(self, Vector3(WIDTH + 0.03, 0.06, DEPTH + 0.03), Vector3(0, BASE_HEIGHT - 0.03, 0), iron)
	_box(self, Vector3(WIDTH + 0.03, 0.06, DEPTH + 0.03), Vector3(0, 0.05, 0), iron)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			_box(self, Vector3(0.06, BASE_HEIGHT, 0.06), Vector3(x * WIDTH * 0.5, BASE_HEIGHT * 0.5, z * DEPTH * 0.5), iron)
	for i in LOCK_X.size():
		var plate := StandardMaterial3D.new()
		plate.albedo_color = IRON.darkened(0.3)
		plate.metallic = 0.9
		plate.roughness = 0.3
		plate.emission_enabled = true
		plate.emission = Color(1.0, 0.75, 0.3)
		plate.emission_energy_multiplier = 0.0
		_locks.append(plate)
		_box(self, Vector3(0.14, 0.18, 0.03), Vector3(LOCK_X[i], LOCK_Y, DEPTH * 0.5 + 0.015), plate)
		var hole := StandardMaterial3D.new()
		hole.albedo_color = Color.BLACK
		_box(self, Vector3(0.03, 0.07, 0.01), Vector3(LOCK_X[i], LOCK_Y - 0.01, DEPTH * 0.5 + 0.032), hole)
	# The treasure: hidden under the lid until it opens.
	_treasure = StandardMaterial3D.new()
	_treasure.albedo_color = Color(1.0, 0.8, 0.3)
	_treasure.emission_enabled = true
	_treasure.emission = Color(1.0, 0.72, 0.25)
	_treasure.emission_energy_multiplier = 0.3
	_box(self, Vector3(WIDTH - 0.12, 0.04, DEPTH - 0.12), Vector3(0, BASE_HEIGHT - 0.04, 0), _treasure)
	# Lid hinged on the back top edge.
	lid = Node3D.new()
	lid.position = Vector3(0, BASE_HEIGHT, -DEPTH * 0.5)
	add_child(lid)
	_box(lid, Vector3(WIDTH, LID_HEIGHT, DEPTH), Vector3(0, LID_HEIGHT * 0.5, DEPTH * 0.5), wood)
	_box(lid, Vector3(WIDTH + 0.03, 0.05, DEPTH + 0.03), Vector3(0, 0.03, DEPTH * 0.5), iron)
	for x in [-0.3, 0.3]:
		_box(lid, Vector3(0.08, LID_HEIGHT + 0.02, DEPTH + 0.03), Vector3(x, LID_HEIGHT * 0.5, DEPTH * 0.5), iron)
	_glow = OmniLight3D.new()
	_glow.light_color = Color(1.0, 0.75, 0.35)
	_glow.light_energy = 0.0
	_glow.omni_range = 5.0
	_glow.position = Vector3(0, BASE_HEIGHT + 0.3, 0)
	add_child(_glow)
	var body := StaticBody3D.new()
	body.collision_layer = collision_layer
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WIDTH, BASE_HEIGHT + LID_HEIGHT, DEPTH)
	shape.shape = box
	shape.position.y = box.size.y * 0.5
	body.add_child(shape)
	add_child(body)


## Fly the keys in from `camera`, turn each in its lock, then open. Emits key_turned per key and
## opened when the lid is up.
func unlock(camera: Camera3D) -> void:
	var tween := create_tween()
	for i in LOCK_X.size():
		# Pivot at the blade tip, so in the lock the key turns about its keyhole.
		var key := Node3D.new()
		key.visible = false
		add_child(key)
		var art := Sprite3D.new()
		art.texture = KeyPickup.TEXTURE
		art.pixel_size = KEY_LENGTH / KeyPickup.TEXTURE.get_height()
		art.shaded = false
		art.position.y = KEY_LENGTH * 0.45
		key.add_child(art)
		var side := camera.global_transform.basis.x * (i - 1) * 0.22
		var start := camera.global_position - camera.global_transform.basis.z * 0.7 - camera.global_transform.basis.y * 0.18 + side
		var hole := Vector3(LOCK_X[i], LOCK_Y - 0.03, DEPTH * 0.5 + 0.04)
		var front := hole + Vector3(0, 0.05, 0.4)
		tween.tween_callback(func() -> void:
			key.global_position = start
			key.visible = true)
		# Arc to just in front of the lock, spinning.
		tween.tween_method(func(t: float) -> void:
			var from := to_local(start)
			var mid := from.lerp(front, 0.5) + Vector3(0, 0.35, 0)
			var u := 1.0 - t
			key.position = u * u * from + 2.0 * u * t * mid + t * t * front
			art.rotation.y = t * TAU * 1.5, 0.0, 1.0, FLY_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# Into the keyhole, square to the lock, then a quarter turn seen head-on.
		tween.tween_property(art, "rotation:y", 0.0, 0.08)
		tween.tween_property(key, "position", hole, 0.12).set_ease(Tween.EASE_IN)
		tween.tween_property(key, "rotation:z", -PI * 0.5 if i < 2 else PI * 0.5, TURN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_callback(_turned.bind(i))
		tween.tween_interval(0.08)
	# Shudder, then the lid bursts open on a flood of gold.
	for n in 6:
		tween.tween_property(self, "position:x", position.x + (0.03 if n % 2 == 0 else -0.03), 0.04)
	tween.tween_property(self, "position:x", position.x, 0.04)
	tween.tween_property(lid, "rotation:x", deg_to_rad(LID_OPEN_DEGREES), 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_glow, "light_energy", 7.0, 0.3)
	tween.parallel().tween_property(_treasure, "emission_energy_multiplier", 4.0, 0.3)
	tween.parallel().tween_callback(_burst)
	tween.tween_callback(opened.emit)


func _turned(index: int) -> void:
	_locks[index].emission_energy_multiplier = 3.0
	_glow.light_energy += 0.6
	key_turned.emit(index)


func _burst() -> void:
	var p := KeyPickup._sparkles(Color(1.0, 0.78, 0.35), true)
	p.amount = 90
	p.position = Vector3(0, BASE_HEIGHT + 0.1, 0)
	p.direction = Vector3.UP
	p.spread = 35.0
	p.gravity = Vector3(0, -3.0, 0)
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 5.0
	p.lifetime = 1.2
	add_child(p)


static func _box(parent: Node3D, box_size: Vector3, at: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
