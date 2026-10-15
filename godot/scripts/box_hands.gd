class_name BoxHands
extends Node3D
## Your two fists opening a key box, seen from your own eyes (main.gd kneels you; KeyBox's beats): the right takes the
## lid's front edge and rides it up, the left dips in and comes up holding the key before your eyes (or out empty).
## The map's fist (PaperMap.build_hand; the left is the right one mirrored), the elbow bent between it and a shoulder
## below the frame (DevilRig.elbow), a sleeve over the upper arm. Only your camera draws them (build's `layer`): the
## Devil Cams never see floating fists.

## Right arm (the left mirrors x), in your body's level frame (x right, y up, -z ahead): the shoulder the sleeve runs
## up to, below the eye, and which way the elbow bends (out and down).
const SHOULDER := Vector3(0.2, -0.26, 0.06)
const POLE := Vector3(0.7, -0.7, 0.1)
## Camera space: where a fist waits out of sight, and where the left one holds the key up to your eyes.
const REST := Vector3(0.26, -0.62, -0.18)
const SHOW := Vector3(-0.05, -0.12, -0.36)
## Upper arm (m), the sleeve's radius, and how far the sleeve runs on down over the end of the fist's forearm.
const UPPER_ARM := 0.3
const SLEEVE_RADIUS := 0.045
const SLEEVE_OVERLAP := 0.04
## The key in the left fist: its length (m) and glow.
const KEY_LENGTH := 0.16
const KEY_GLOW := 0.5

var _fists: Array[Node3D] = []
var _sleeves: Array[MeshInstance3D] = []
var _key := Node3D.new()
var _key_light := OmniLight3D.new()
## Grip to elbow (m): as long as the fist model's forearm, so the sleeve picks up where it ends.
var _forearm := PaperMap.ARM_LENGTH


func build(layer: int) -> void:
	var skin := PaperMap.plain_material(PaperMap.SKIN)
	var sleeve := PaperMap.plain_material(PaperMap.SLEEVE)
	var tube := CylinderMesh.new()
	tube.top_radius = SLEEVE_RADIUS
	tube.bottom_radius = SLEEVE_RADIUS
	tube.height = 1.0
	tube.material = PaperMap.plain_material(PaperMap.SLEEVE.darkened(0.4))
	(tube.material as StandardMaterial3D).roughness = 1.0  # dull cloth, not a lit pipe, in the flashlight
	for side in 2:
		var fist := Node3D.new()
		var hand := Node3D.new()
		hand.scale.x = -1.0 if side == 1 else 1.0
		PaperMap.build_hand(hand, skin, sleeve)
		if side == 0:
			var bounds := ModelFit.mesh_bounds(hand)
			_forearm = 0.0
			for corner in 8:
				_forearm = maxf(_forearm, bounds.get_endpoint(corner).dot(PaperMap.ARM.normalized()))
		fist.add_child(hand)
		add_child(fist)
		_fists.append(fist)
		var arm := MeshInstance3D.new()
		arm.mesh = tube
		add_child(arm)
		_sleeves.append(arm)
	# The key lies through the left fist, along the curl of its fingers.
	_key.add_child(KeyPickup.model(KEY_LENGTH, -KEY_LENGTH * 0.5))
	_key.basis = Basis(Quaternion(Vector3.UP, (PaperMap.ARM * Vector3(-1, 1, 1)).cross(PaperMap.PALM * Vector3(-1, 1, 1)).normalized()))
	_fists[1].add_child(_key)
	_key_light.omni_range = 1.2
	_key.add_child(_key_light)
	for part: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		part.layers = layer
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


## One frame: `eye` = your camera (world), `box` the box you kneel at, `t` seconds into the opening (KeyBox's beats),
## `w` how far down you are (0: standing, hidden), `found` = a key in it, `key` its colour (alpha 0: not in your fist).
func pose(eye: Transform3D, box: KeyBox, t: float, w: float, found: bool, key: Color) -> void:
	visible = w > 0.01
	if not visible:
		return
	# Right: up from below the frame onto the lid's front edge, riding it up, the palm in toward the hinge.
	_place(0, eye, (eye * REST).lerp(box.grip_point(), KeyBox.lid_reach(t) * w), -box.lid_front())
	# Left: down into the box, palm down; with a key, up before your eyes, palm toward you.
	var left := KeyBox.left_hand(t, found)
	var target := box.inside_point().lerp(eye * SHOW, left.y)
	_place(1, eye, (eye * (REST * Vector3(-1, 1, 1))).lerp(target, left.x * w), Vector3.DOWN.lerp(eye.basis.z, left.y))
	_key.visible = key.a > 0.0
	_key_light.light_color = Color(key, 1.0)
	_key_light.light_energy = KEY_GLOW


## Where the key in your fist is (world): it pops and flies to the HUD from here.
func key_point() -> Vector3:
	return _key.global_position


## Fist `side` (0 right, 1 left) gripping at `grip` (world), its palm toward `palm`, the elbow bent between it and the
## shoulder, the sleeve over the upper arm. The shoulder hangs off your body, not the camera: looking down into the
## box doesn't swing it up behind you.
func _place(side: int, eye: Transform3D, grip: Vector3, palm: Vector3) -> void:
	var flip := Vector3(-1.0 if side == 1 else 1.0, 1.0, 1.0)
	var ahead := -eye.basis.z
	var body := Basis(Vector3.UP, atan2(-ahead.x, -ahead.z))
	var shoulder := eye.origin + body * (SHOULDER * flip)
	var joint := DevilRig.elbow(shoulder, grip, UPPER_ARM, _forearm, body * (POLE * flip))
	var arm := (joint - grip).normalized()
	var up := palm - arm * palm.dot(arm)
	if up.length() < 0.1:
		up = eye.basis.y  # the palm along the forearm: any roll will do
	var turn := Basis.looking_at(arm, up.normalized()) * Basis.looking_at(PaperMap.ARM * flip, PaperMap.PALM * flip).inverse()
	_fists[side].global_transform = Transform3D(turn, grip)
	var from := joint - arm * SLEEVE_OVERLAP
	var run := shoulder - from
	_sleeves[side].global_transform = Transform3D(Basis(Quaternion(Vector3.UP, run.normalized())) * Basis.from_scale(Vector3(1.0, run.length(), 1.0)), from + run * 0.5)
