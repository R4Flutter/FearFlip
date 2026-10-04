class_name CharacterRig
extends Node3D

## Splits the static character1.glb mesh into head/torso/arms/legs pivots
## and procedurally animates them (walk swing, head bob/nod, torso sway).

var head_pivot: Node3D
var arm_l_pivot: Node3D
var arm_r_pivot: Node3D
var leg_l_pivot: Node3D
var leg_r_pivot: Node3D
var torso_pivot: Node3D

var _phase := 0.0
var _idle_phase := 0.0


func build(model_scene: PackedScene) -> void:
	var src := model_scene.instantiate()
	var meshes: Array = []
	_collect(src, meshes)
	if meshes.is_empty():
		push_error("CharacterRig: no MeshInstance3D found in model")
		return
	var m: MeshInstance3D = meshes[0]
	var surf = m.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = surf[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = surf[Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array = surf[Mesh.ARRAY_TANGENT]
	var uvs: PackedVector2Array = surf[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = surf[Mesh.ARRAY_INDEX]
	var mat = m.mesh.surface_get_material(0)

	var parts := {
		"head": [],
		"torso": [],
		"arm_l": [],
		"arm_r": [],
		"leg_l": [],
		"leg_r": [],
	}
	for i in range(0, indices.size(), 3):
		var c := (verts[indices[i]] + verts[indices[i + 1]] + verts[indices[i + 2]]) / 3.0
		var pname := _classify(c)
		parts[pname].append(indices[i])
		parts[pname].append(indices[i + 1])
		parts[pname].append(indices[i + 2])

	var pivots := {
		"head": Vector3(0.0, 0.28, 0.0),
		"arm_l": Vector3(-0.135, 0.24, 0.0),
		"arm_r": Vector3(0.135, 0.24, 0.0),
		"leg_l": Vector3(-0.06, -0.02, 0.0),
		"leg_r": Vector3(0.06, -0.02, 0.0),
		"torso": Vector3(0.0, 0.0, 0.0),
	}
	torso_pivot = Node3D.new()
	torso_pivot.name = "TorsoPivot"
	add_child(torso_pivot)
	head_pivot = Node3D.new()
	head_pivot.name = "HeadPivot"
	head_pivot.position = pivots["head"]
	torso_pivot.add_child(head_pivot)
	arm_l_pivot = Node3D.new()
	arm_l_pivot.name = "ArmLPivot"
	arm_l_pivot.position = pivots["arm_l"]
	torso_pivot.add_child(arm_l_pivot)
	arm_r_pivot = Node3D.new()
	arm_r_pivot.name = "ArmRPivot"
	arm_r_pivot.position = pivots["arm_r"]
	torso_pivot.add_child(arm_r_pivot)
	leg_l_pivot = Node3D.new()
	leg_l_pivot.name = "LegLPivot"
	leg_l_pivot.position = pivots["leg_l"]
	add_child(leg_l_pivot)
	leg_r_pivot = Node3D.new()
	leg_r_pivot.name = "LegRPivot"
	leg_r_pivot.position = pivots["leg_r"]
	add_child(leg_r_pivot)

	for name in parts:
		var ppos: Vector3 = pivots[name]
		var remap := {}
		var nv := PackedVector3Array()
		var nn := PackedVector3Array()
		var nt := PackedFloat32Array()
		var nu := PackedVector2Array()
		var ni := PackedInt32Array()
		for idx in parts[name]:
			if not remap.has(idx):
				remap[idx] = nv.size()
				nv.append(verts[idx] - ppos)
				nn.append(normals[idx])
				for k in range(4):
					nt.append(tangents[idx * 4 + k])
				nu.append(uvs[idx])
			ni.append(remap[idx])
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = nv
		arr[Mesh.ARRAY_NORMAL] = nn
		arr[Mesh.ARRAY_TANGENT] = nt
		arr[Mesh.ARRAY_TEX_UV] = nu
		arr[Mesh.ARRAY_INDEX] = ni
		var newmesh := ArrayMesh.new()
		newmesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		newmesh.surface_set_material(0, mat)
		var mi := MeshInstance3D.new()
		mi.mesh = newmesh
		mi.name = name
		match name:
			"head":
				head_pivot.add_child(mi)
			"torso":
				torso_pivot.add_child(mi)
			"arm_l":
				arm_l_pivot.add_child(mi)
			"arm_r":
				arm_r_pivot.add_child(mi)
			"leg_l":
				leg_l_pivot.add_child(mi)
			"leg_r":
				leg_r_pivot.add_child(mi)


func _classify(c: Vector3) -> String:
	if c.y > 0.30:
		return "head"
	if abs(c.x) > 0.13 and c.y > -0.20:
		return "arm_r" if c.x > 0.0 else "arm_l"
	if c.y <= 0.0:
		return "leg_r" if c.x >= 0.0 else "leg_l"
	return "torso"


func animate(moving: bool, delta: float, speed: float) -> void:
	_idle_phase += delta
	if moving:
		_phase += delta * (5.0 + speed * 1.5)
	var t := sin(_phase)
	var a: float = abs(sin(_phase))
	if moving:
		arm_l_pivot.rotation.x = t * 0.55
		arm_r_pivot.rotation.x = -t * 0.55
		leg_l_pivot.rotation.x = -t * 0.6
		leg_r_pivot.rotation.x = t * 0.6
		head_pivot.rotation.x = 0.06 + a * 0.12
		head_pivot.rotation.z = t * 0.08
		torso_pivot.rotation.x = 0.10
		torso_pivot.rotation.z = t * 0.05
	else:
		arm_l_pivot.rotation.x = move_toward(arm_l_pivot.rotation.x, 0.0, delta * 4.0)
		arm_r_pivot.rotation.x = move_toward(arm_r_pivot.rotation.x, 0.0, delta * 4.0)
		leg_l_pivot.rotation.x = move_toward(leg_l_pivot.rotation.x, 0.0, delta * 4.0)
		leg_r_pivot.rotation.x = move_toward(leg_r_pivot.rotation.x, 0.0, delta * 4.0)
		head_pivot.rotation.x = lerp(head_pivot.rotation.x, sin(_idle_phase * 1.2) * 0.05, delta * 3.0)
		head_pivot.rotation.z = lerp(head_pivot.rotation.z, sin(_idle_phase * 0.9) * 0.05, delta * 3.0)
		torso_pivot.rotation.x = lerp(torso_pivot.rotation.x, 0.0, delta * 4.0)
		torso_pivot.rotation.z = lerp(torso_pivot.rotation.z, sin(_idle_phase * 1.1) * 0.02, delta * 3.0)


func _collect(n: Node, arr: Array) -> void:
	if n is MeshInstance3D:
		arr.append(n)
	for c in n.get_children():
		_collect(c, arr)
