class_name DevilRig
extends RefCounted
## Runs skleton_added_devil.glb like a person. The file has Mixamo bones but no animation clips, so
## the run cycle is procedural: each swing is a rotation about a skeleton-space axis on top of the
## bone's rest pose. The model file itself is never modified; three export problems are fixed at load:
## 1. every bone node sits at the origin (the real bind pose exists only in the inverse bind matrices),
## 2. that bind pose is turned BIND_YAW_FIX_DEGREES away from the mesh,
## 3. weights are rigid (one bone per vertex, 59% on Hips), so joints would tear. We re-weight by
##    distance to the bone segments, blending up to 4 bones, and cache the mesh for restarts.

## Bind pose -> mesh alignment for skleton_added_devil.glb (measured: bones sit 90 deg off their vertices).
const BIND_YAW_FIX_DEGREES := -90.0
## Bone -> the bone marking its far end ("" = extend the parent direction by TIP_LENGTH).
const SEGMENTS := {
	"Hips": "Spine", "Spine": "Spine1", "Spine1": "Spine2", "Spine2": "Neck", "Neck": "Head", "Head": "",
	"LeftShoulder": "LeftArm", "LeftArm": "LeftForeArm", "LeftForeArm": "LeftHand", "LeftHand": "",
	"RightShoulder": "RightArm", "RightArm": "RightForeArm", "RightForeArm": "RightHand", "RightHand": "",
	"LeftUpLeg": "LeftLeg", "LeftLeg": "LeftFoot", "LeftFoot": "LeftToeBase",
	"RightUpLeg": "RightLeg", "RightLeg": "RightFoot", "RightFoot": "RightToeBase",
}
const TIP_LENGTH := 0.12

## Re-weighted mesh, shared by every devil and kept across scene reloads.
static var _smooth_mesh: ArrayMesh
## Player mesh with the hem freed from the hands (unstick_hands), kept across scene reloads.
static var _unstuck_mesh: ArrayMesh

## Run-cycle tunables (degrees / metres). Tune by eye.
var stride_angle := 38.0
var knee_bend := 70.0
var arm_swing := 35.0
var elbow_bend := 40.0
var run_lean := 12.0
## Distance covered by one full cycle (two steps).
var stride_length := 1.4

var skeleton: Skeleton3D
var _bones: Dictionary = {}
var _phase := 0.0
var _blend := 0.0
var _idle_time := 0.0
## Skeleton-space axis pointing to the devil's left. A negative rotation about it swings a hanging
## limb forward.
var _left_axis := Vector3.RIGHT


## repair = false for clean rigs (e.g. character2withrig.glb: real bone rests, smooth weights).
func _init(model: Node, repair := true) -> void:
	var found := model.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		push_warning("DevilRig: no Skeleton3D in model")
		return
	skeleton = found[0]
	if repair:
		_repair(model)
	for bone in ["Spine", "Head", "LeftUpLeg", "LeftLeg", "RightUpLeg", "RightLeg", "LeftArm", "LeftForeArm", "RightArm", "RightForeArm"]:
		_bones[bone] = _find_bone(bone)
	if _bones["LeftUpLeg"] >= 0 and _bones["RightUpLeg"] >= 0:
		var hips_span := skeleton.get_bone_global_rest(_bones["LeftUpLeg"]).origin - skeleton.get_bone_global_rest(_bones["RightUpLeg"]).origin
		_left_axis = Vector3(hips_span.x, 0.0, hips_span.z).normalized()


## Yaw (radians, atan2(x, z)) the model's chest faces, measured from the hips. Set the model's
## rotation.y to (wanted_yaw - facing_yaw()) to make it walk straight along wanted_yaw.
func facing_yaw() -> float:
	var forward := _left_axis.cross(Vector3.UP)
	return atan2(forward.x, forward.z)


## speed in m/s. Returns a vertical bob offset (metres) for the body.
func animate(speed: float, delta: float) -> float:
	if skeleton == null:
		return 0.0
	_blend = move_toward(_blend, 1.0 if speed > 0.2 else 0.0, delta * 5.0)
	_phase += speed / stride_length * TAU * delta
	_idle_time += delta
	var axis := _left_axis
	var idle := sin(_idle_time * 1.7) * deg_to_rad(3.0) * (1.0 - _blend)
	_pose("Spine", Quaternion(axis, deg_to_rad(run_lean) * _blend + idle))
	_pose("Head", Quaternion(axis, -deg_to_rad(run_lean) * 0.5 * _blend))
	for side in [1.0, -1.0]:
		var prefix := "Left" if side > 0.0 else "Right"
		var p := _phase + (0.0 if side > 0.0 else PI)
		# Thigh swings forward on sin > 0; the knee folds while the leg travels forward (cos > 0).
		_pose(prefix + "UpLeg", Quaternion(axis, -deg_to_rad(stride_angle) * sin(p) * _blend))
		_pose(prefix + "Leg", Quaternion(axis, deg_to_rad(knee_bend) * maxf(cos(p), 0.1) * _blend))
		# Arm swings opposite to the same-side leg; elbow stays bent like a runner's.
		_pose(prefix + "Arm", Quaternion(axis, deg_to_rad(arm_swing) * sin(p) * _blend))
		_pose(prefix + "ForeArm", Quaternion(axis, -deg_to_rad(elbow_bend) * _blend))
	return absf(sin(_phase)) * 0.04 * _blend


## Falling: arms thrown up overhead and grabbing at nothing, legs kicking, back arched. t = seconds falling.
## Arms are aimed by direction (works for T- and A-pose rests) and stay mostly overhead: wide or
## forward swings stretch the character2withrig jacket, which is skinned to the arms.
func flail(t: float) -> void:
	if skeleton == null:
		return
	var axis := _left_axis
	var forward := axis.cross(Vector3.UP)
	var panic := minf(t * 7.0, 1.0)
	_pose("Spine", Quaternion(axis, -deg_to_rad(20.0) * panic))
	_pose("Head", Quaternion(axis, -deg_to_rad(25.0) * panic))
	for side in [1.0, -1.0]:
		var prefix := "Left" if side > 0.0 else "Right"
		var w := t * 11.0 + (0.0 if side > 0.0 else 1.9)
		_pose(prefix + "UpLeg", Quaternion(axis, -deg_to_rad(20.0 + 30.0 * sin(w * 0.8)) * panic))
		_pose(prefix + "Leg", Quaternion(axis, deg_to_rad(35.0 + 30.0 * sin(w * 0.8 + 1.2)) * panic))
		var arm: int = _bones.get(prefix + "Arm", -1)
		var fore: int = _bones.get(prefix + "ForeArm", -1)
		if arm < 0 or fore < 0:
			continue
		var rest_dir := (skeleton.get_bone_global_rest(fore).origin - skeleton.get_bone_global_rest(arm).origin).normalized()
		var out := Vector3(rest_dir.x, 0.0, rest_dir.z)
		out = out.normalized() if out.length() > 0.1 else axis * side
		var reach := (Vector3.UP + out * 0.3 + forward * 0.2 * sin(w)).normalized()
		_pose(prefix + "Arm", Quaternion(rest_dir, rest_dir.slerp(reach, panic).normalized()))
		_pose(prefix + "ForeArm", Quaternion(axis, -deg_to_rad(30.0 + 30.0 * sin(w + 1.0)) * panic))


## Apply `rotation` (skeleton space, relative to the rest pose) to a bone.
func _pose(bone: String, rotation: Quaternion) -> void:
	var index: int = _bones.get(bone, -1)
	if index < 0:
		return
	var rest := skeleton.get_bone_rest(index).basis.get_rotation_quaternion()
	var global_rest := skeleton.get_bone_global_rest(index).basis.get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(index, rest * (global_rest.inverse() * rotation * global_rest))


## Fixes 1-3 from the header. Skin is duplicated per instance; the mesh is shared.
func _repair(model: Node) -> void:
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty() or (meshes[0] as MeshInstance3D).skin == null:
		return
	var mesh_instance: MeshInstance3D = meshes[0]
	var skin: Skin = mesh_instance.skin.duplicate()
	mesh_instance.skin = skin
	var fix := Transform3D(Basis(Vector3.UP, deg_to_rad(BIND_YAW_FIX_DEGREES)), Vector3.ZERO)
	var bind_globals: Dictionary = {}
	var bind_of_bone: Dictionary = {}
	for b in skin.get_bind_count():
		var bone := skin.get_bind_bone(b)
		if bone < 0:
			bone = skeleton.find_bone(skin.get_bind_name(b))
		if bone < 0:
			continue
		var bind_global: Transform3D = fix * skin.get_bind_pose(b).affine_inverse()
		bind_globals[bone] = bind_global
		bind_of_bone[bone] = b
		skin.set_bind_pose(b, bind_global.affine_inverse())
	# Bone indices are parent-before-child, so parents are fixed before their children.
	for bone in skeleton.get_bone_count():
		if not bind_globals.has(bone):
			continue
		var parent_global: Transform3D = bind_globals.get(skeleton.get_bone_parent(bone), Transform3D.IDENTITY)
		var rest: Transform3D = parent_global.affine_inverse() * bind_globals[bone]
		skeleton.set_bone_rest(bone, rest)
		skeleton.set_bone_pose_position(bone, rest.origin)
		skeleton.set_bone_pose_rotation(bone, rest.basis.get_rotation_quaternion())
		skeleton.set_bone_pose_scale(bone, rest.basis.get_scale())
	if _smooth_mesh == null:
		_smooth_mesh = _reweight(mesh_instance.mesh as ArrayMesh, bind_globals, bind_of_bone)
	mesh_instance.mesh = _smooth_mesh


## character2withrig.glb rests in A-pose with the hands against the jacket hem, and ~3k hem vertices
## carry forearm/hand weight. Raise the arms and they stretch from hip to hand like rope. Measured:
## sleeves and hands sit within 0.05 (mesh units) of the arm bones, the stray hem 0.06-0.16. A vertex
## drops its forearm/hand weights when it is further than `arm_radius` from the arm, or when those
## weights are a minority (the hem touching the hand at rest). The model is AI-generated and its hands
## are fused into the hips, so triangles joining a hand to bare body are cut out. Cached across reloads.
func unstick_hands(arm_radius := 0.055, min_share := 0.5) -> void:
	if skeleton == null:
		return
	var meshes := skeleton.get_parent().find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty() or (meshes[0] as MeshInstance3D).skin == null:
		return
	var mesh_instance: MeshInstance3D = meshes[0]
	if _unstuck_mesh == null:
		_unstuck_mesh = _drop_hand_weights(mesh_instance.mesh as ArrayMesh, mesh_instance.skin, arm_radius, min_share)
	mesh_instance.mesh = _unstuck_mesh


func _drop_hand_weights(source: ArrayMesh, skin: Skin, arm_radius: float, min_share: float) -> ArrayMesh:
	var hand_binds := {}
	var arm_binds := {}
	var origin := {}
	for b in skin.get_bind_count():
		var bone := skin.get_bind_bone(b)
		var bone_name := skeleton.get_bone_name(bone) if bone >= 0 else String(skin.get_bind_name(b))
		if bone_name.contains("ForeArm") or bone_name.contains("Hand"):
			hand_binds[b] = true
		if bone_name.contains("Arm") or bone_name.contains("Hand") or bone_name.contains("Shoulder"):
			arm_binds[b] = true
		for part in ["Arm", "ForeArm", "Hand"]:
			for side in ["Left", "Right"]:
				if bone_name.ends_with("_" + side + part) or bone_name.ends_with(":" + side + part) or bone_name == side + part:
					origin[side + part] = skin.get_bind_pose(b).affine_inverse().origin
	# Shoulder -> elbow -> wrist -> fingertips, both arms, in mesh space.
	var segments: Array[Vector3] = []
	for side in ["Left", "Right"]:
		if not (origin.has(side + "Arm") and origin.has(side + "ForeArm") and origin.has(side + "Hand")):
			return source
		var hand: Vector3 = origin[side + "Hand"]
		var tip: Vector3 = hand + (hand - (origin[side + "ForeArm"] as Vector3)) * 0.6
		segments.append_array([origin[side + "Arm"], origin[side + "ForeArm"], origin[side + "ForeArm"], hand, hand, tip])
	var mesh := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per := bones.size() / maxi(vertices.size(), 1)
		for v in vertices.size():
			var hand := 0.0
			for k in per:
				if hand_binds.has(bones[v * per + k]):
					hand += weights[v * per + k]
			if hand <= 0.0 or hand >= 0.999 or (hand >= min_share and _distance_to_segments(vertices[v], segments) <= arm_radius):
				continue
			for k in per:
				var i := v * per + k
				weights[i] = 0.0 if hand_binds.has(bones[i]) else weights[i] / (1.0 - hand)
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		arrays[Mesh.ARRAY_INDEX] = _cut_fused(arrays[Mesh.ARRAY_INDEX], bones, weights, per, hand_binds, arm_binds)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, source.surface_get_format(surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		mesh.surface_set_material(surface, source.surface_get_material(surface))
	return mesh


## Drops triangles that join a hand-dominated vertex to a vertex with no arm weight at all.
static func _cut_fused(indices: PackedInt32Array, bones: PackedInt32Array, weights: PackedFloat32Array, per: int, hand_binds: Dictionary, arm_binds: Dictionary) -> PackedInt32Array:
	var kept := PackedInt32Array()
	for t in range(0, indices.size(), 3):
		var handy := false
		var bare := false
		for c in 3:
			var v := indices[t + c]
			var hand := 0.0
			var arm := 0.0
			for k in per:
				var w := weights[v * per + k]
				if hand_binds.has(bones[v * per + k]):
					hand += w
				if arm_binds.has(bones[v * per + k]):
					arm += w
			handy = handy or hand >= 0.5
			bare = bare or arm <= 0.001
		if not (handy and bare):
			kept.append_array([indices[t], indices[t + 1], indices[t + 2]])
	return kept


static func _distance_to_segments(p: Vector3, segments: Array[Vector3]) -> float:
	var best := INF
	for s in range(0, segments.size(), 2):
		var a := segments[s]
		var ab := segments[s + 1] - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
		best = minf(best, (a + ab * t).distance_to(p))
	return best


## Each vertex gets the 4 nearest bone segments, weighted by 1/d^4 (smooth blend across joints).
func _reweight(source: ArrayMesh, bind_globals: Dictionary, bind_of_bone: Dictionary) -> ArrayMesh:
	var starts := PackedVector3Array()
	var spans := PackedVector3Array()
	var inv_len2 := PackedFloat32Array()
	var binds := PackedInt32Array()
	for bone_name: String in SEGMENTS:
		var bone := _find_bone(bone_name)
		if not bind_globals.has(bone):
			continue
		var a: Vector3 = (bind_globals[bone] as Transform3D).origin
		var b: Vector3
		var end_bone := _find_bone(SEGMENTS[bone_name]) if SEGMENTS[bone_name] != "" else -1
		if bind_globals.has(end_bone):
			b = (bind_globals[end_bone] as Transform3D).origin
		else:
			var parent_origin: Vector3 = (bind_globals.get(skeleton.get_bone_parent(bone), Transform3D(Basis(), a - Vector3.UP)) as Transform3D).origin
			b = a + (a - parent_origin).normalized() * TIP_LENGTH
		starts.append(a)
		spans.append(b - a)
		inv_len2.append(1.0 / maxf((b - a).length_squared(), 0.000001))
		binds.append(bind_of_bone[bone])
	var arrays := source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	bones.resize(vertices.size() * 4)
	weights.resize(vertices.size() * 4)
	var segment_count := starts.size()
	for v in vertices.size():
		var p := vertices[v]
		var best_w := [0.0, 0.0, 0.0, 0.0]
		var best_s := [0, 0, 0, 0]
		for s in segment_count:
			var t := clampf((p - starts[s]).dot(spans[s]) * inv_len2[s], 0.0, 1.0)
			var d2 := (starts[s] + spans[s] * t - p).length_squared()
			var w := 1.0 / (d2 * d2 + 0.00000001)
			if w <= best_w[3]:
				continue
			var slot := 3
			while slot > 0 and w > best_w[slot - 1]:
				best_w[slot] = best_w[slot - 1]
				best_s[slot] = best_s[slot - 1]
				slot -= 1
			best_w[slot] = w
			best_s[slot] = s
		var total: float = best_w[0] + best_w[1] + best_w[2] + best_w[3]
		for k in 4:
			bones[v * 4 + k] = binds[best_s[k]]
			weights[v * 4 + k] = best_w[k] / total
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, source.surface_get_material(0))
	return mesh


## Mixamo names arrive as "mixamorig:Hips" or "mixamorig_Hips" depending on import.
func _find_bone(bone: String) -> int:
	if bone.is_empty():
		return -1
	for i in skeleton.get_bone_count():
		var bone_name := skeleton.get_bone_name(i)
		if bone_name == bone or bone_name.ends_with(":" + bone) or bone_name.ends_with("_" + bone):
			return i
	return -1
