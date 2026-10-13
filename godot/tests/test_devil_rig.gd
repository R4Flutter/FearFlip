extends McpTestSuite
## The Devil's re-weight (DevilRig._reweight): a limb reaches only its own part of the mesh, so raising an arm never drags
## a tendril into a long strip; the claws are its fingers; the roar lifts the claws without tearing them off.


func suite_name() -> String:
	return "devil_rig"


## [rig, mesh instance, {bone name: bind}, {bone name: bind origin in mesh space}]
func _devil() -> Array:
	var model: Node3D = load("res://assets/character/skleton_added_devil.glb").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(model)
	track(model)
	var rig := DevilRig.new(model)
	var mi: MeshInstance3D = model.find_children("*", "MeshInstance3D", true, false)[0]
	var bind_of := {}
	var origin_of := {}
	for b in mi.skin.get_bind_count():
		var bone := mi.skin.get_bind_bone(b)
		var bone_name := String(rig.skeleton.get_bone_name(bone)) if bone >= 0 else String(mi.skin.get_bind_name(b))
		bone_name = bone_name.get_slice(":", bone_name.get_slice_count(":") - 1).trim_prefix("mixamorig_")
		bind_of[bone_name] = b
		origin_of[bone_name] = mi.skin.get_bind_pose(b).affine_inverse().origin
	return [rig, mi, bind_of, origin_of]


func test_nothing_far_from_an_arm_weighs_on_it() -> void:
	var devil := _devil()
	var arrays := (devil[1].mesh as ArrayMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var o: Dictionary = devil[3]
	var arm_binds := {}
	for bone_name: String in devil[2]:
		if bone_name in ["LeftArm", "LeftForeArm"] or bone_name.begins_with("LeftHand"):
			arm_binds[devil[2][bone_name]] = true
	var wrist: Vector3 = o["LeftHand"]
	var claw := wrist + (wrist - (o["LeftForeArm"] as Vector3)).normalized() * DevilRig.CLAW_LENGTH
	var chain: Array[Vector3] = [o["LeftArm"], o["LeftForeArm"], o["LeftForeArm"], wrist, wrist, claw]
	var strays := 0
	for v in verts.size():
		if _distance(verts[v], chain) < DevilRig.HAND_RADIUS + 0.04:
			continue
		for k in 4:
			if arm_binds.has(bones[v * 4 + k]) and weights[v * 4 + k] > 0.0:
				strays += 1
				break
	assert_eq(strays, 0, "vertices far from the left arm (its tendrils) that would follow it")


func test_the_claws_are_its_fingers() -> void:
	var devil := _devil()
	var arrays := (devil[1].mesh as ArrayMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var name_of := {}
	for bone_name: String in devil[2]:
		name_of[devil[2][bone_name]] = bone_name
	var tip := -1
	var owner := ""
	for v in verts.size():  # the lowest point the left arm carries: a claw tip, if its region reached them
		var best := 0
		for k in range(1, 4):
			if weights[v * 4 + k] > weights[v * 4 + best]:
				best = k
		var bone_name: String = name_of.get(bones[v * 4 + best], "")
		var arm := bone_name in ["LeftArm", "LeftForeArm"] or bone_name.begins_with("LeftHand")
		if arm and (tip < 0 or verts[v].y < verts[tip].y):
			tip = v
			owner = bone_name
	assert_true(verts[tip].y < 0.2, "the hand reaches its claw tips (hooked down to 0.13), not cut at %.2f" % verts[tip].y)
	assert_true(owner != "LeftHand", "the claw tip follows a finger, not %s" % owner)


func test_the_roar_lifts_its_claws() -> void:
	var rig: DevilRig = _devil()[0]
	var hand := rig.skeleton.find_bone("mixamorig_LeftHand")
	var resting := rig.skeleton.get_bone_global_pose(hand).origin.y
	for frame in 40:  # into the held roar
		rig.roar(frame / 60.0 + 0.2, 1.0 / 60.0, Vector3.INF)
	assert_gt(rig.skeleton.get_bone_global_pose(hand).origin.y, resting + 0.1, "claws flung up")
	assert_true(DevilRig.roar_force(0.8) > 0.9 and DevilRig.roar_force(0.0) == 0.0, "roars in the middle, not at the coil")


func _distance(p: Vector3, segments: Array[Vector3]) -> float:
	var best := INF
	for s in range(0, segments.size(), 2):
		var ab := segments[s + 1] - segments[s]
		var t := clampf((p - segments[s]).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
		best = minf(best, (segments[s] + ab * t).distance_to(p))
	return best
