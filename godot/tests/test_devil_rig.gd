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


# --- The player, as fully animated as the Devil (user, 15 Oct 2026; seen in the Devil Cams) ---

const STEP := 1.0 / 60.0


## character2withrig.glb as main.gd builds it: a clean rig (no repair), the hem freed from the hands, unscaled at the
## origin. The rig's skeleton space is the model's own (~1 tall), so distances below are in its units.
func _player() -> DevilRig:
	var model: Node3D = load("res://assets/character/character2withrig.glb").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(model)
	track(model)
	var rig := DevilRig.new(model, false)
	rig.unstick_hands()
	return rig


## A bone's posed position, skeleton space.
func _at(rig: DevilRig, bone: String) -> Vector3:
	return rig.skeleton.get_bone_global_pose(rig.skeleton.find_bone("mixamorig_" + bone)).origin


## `frames` frames of flee(); returns its last vertical offset.
func _flee(rig: DevilRig, frames: int, speed: float, fear := 0.0, look := Vector2.ZERO) -> float:
	var y := 0.0
	for frame in frames:
		y = rig.flee(speed, STEP, fear, 0.0, look)
	return y


## Which way the head faces (skeleton space): its turn from rest applied to the body's forward.
func _face(rig: DevilRig) -> Vector3:
	var head := rig.skeleton.find_bone("mixamorig_Head")
	var turn := rig.skeleton.get_bone_global_pose(head).basis.get_rotation_quaternion() * rig.skeleton.get_bone_global_rest(head).basis.get_rotation_quaternion().inverse()
	return turn * Vector3(sin(rig.facing_yaw()), 0.0, cos(rig.facing_yaw()))


func test_the_player_clenches_its_fists_at_a_sprint() -> void:
	var rig := _player()
	var open := _at(rig, "LeftHandIndex4").distance_to(_at(rig, "LeftHand"))
	_flee(rig, 60, rig.sprint_pace)
	assert_true(_at(rig, "LeftHandIndex4").distance_to(_at(rig, "LeftHand")) < open * 0.8, "fingertips curled in toward the palm")


func test_grip_closes_the_hand() -> void:
	var rig := _player()
	_flee(rig, 1, 0.0)
	var open := _at(rig, "RightHandMiddle4").distance_to(_at(rig, "RightHand"))
	rig.grip("Right", 1.0)
	assert_true(_at(rig, "RightHandMiddle4").distance_to(_at(rig, "RightHand")) < open * 0.75, "closed round the lid's edge")


func test_a_walk_bends_the_toes_at_push_off() -> void:
	var rig := _player()
	var rest := _toe_bend(rig)
	var most := 0.0
	for frame in 90:
		rig.flee(rig.walk_pace, STEP, 0.0, 0.0)
		most = maxf(most, _toe_bend(rig))
	assert_true(most > rest + deg_to_rad(12.0), "toes bend as the heel lifts (%.1f deg past rest)" % rad_to_deg(most - rest))


## Angle between the left foot and its toes.
func _toe_bend(rig: DevilRig) -> float:
	var ball := _at(rig, "LeftToeBase")
	return (ball - _at(rig, "LeftFoot")).angle_to(_at(rig, "LeftToe_End") - ball)


func test_the_head_follows_your_look() -> void:
	var rig := _player()
	_flee(rig, 30, 0.0, 0.0, Vector2(0.0, 0.6))
	assert_true(_face(rig).y > 0.35, "looks up with you")
	_flee(rig, 30, 0.0, 0.0, Vector2(0.8, 0.0))
	assert_true(_face(rig).dot(rig._left_axis) > 0.5, "turns left with you")


## Backing away walks backward: a foot travels backward while it's lifted, forward while it's planted.
func test_backing_away_walks_backward() -> void:
	assert_true(_swing(_player(), 3.0) > 0.001, "walking ahead, the lifted foot moves ahead")
	assert_true(_swing(_player(), -3.0) < -0.001, "backing away, the lifted foot moves back")


## Sum over 1.5 s of how far the left foot moves ahead each frame, times how high it's lifted.
func _swing(rig: DevilRig, speed: float) -> float:
	var forward: Vector3 = rig._left_axis.cross(Vector3.UP)
	var last := _at(rig, "LeftFoot")
	var sum := 0.0
	for frame in 90:
		var y := rig.flee(speed, STEP, 0.0, 0.0)
		var foot := _at(rig, "LeftFoot")
		sum += (foot - last).dot(forward) * maxf(foot.y + y - 0.08, 0.0)
		last = foot
	return sum


func test_it_cowers_when_the_devil_is_on_top_of_it() -> void:
	var rig := _player()
	var y := _flee(rig, 60, 0.0, 1.0)
	var head := _at(rig, "Head").y
	assert_true(_at(rig, "LeftHand").y > head - 0.05 and _at(rig, "RightHand").y > head - 0.05, "hands up over the head")
	assert_true(y < -0.05, "crouched low (%.3f)" % y)


func test_a_startle_jerks_the_hands_up_then_settles() -> void:
	var calm := _player()
	var jumpy := _player()
	_flee(calm, 30, 0.0)
	_flee(jumpy, 30, 0.0)
	jumpy.startle(1.0)
	_flee(calm, 8, 0.0)
	_flee(jumpy, 8, 0.0)
	assert_true(_at(jumpy, "RightHand").y > _at(calm, "RightHand").y + 0.08, "hands jerk up toward the chest")
	_flee(calm, 90, 0.0)
	_flee(jumpy, 90, 0.0)
	assert_true(absf(_at(jumpy, "RightHand").y - _at(calm, "RightHand").y) < 0.01, "and settle back")


func test_reach_puts_the_palm_on_the_point() -> void:
	var rig := _player()
	_flee(rig, 1, 0.0)
	var forward: Vector3 = rig._left_axis.cross(Vector3.UP)
	var target := _at(rig, "RightArm") + forward * 0.2 + Vector3.DOWN * 0.15
	rig.reach("Right", rig.skeleton.global_transform * target, 1.0)
	assert_true(_at(rig, "RightHandMiddle1").distance_to(target) < 0.01, "palm on it (%.3f off)" % _at(rig, "RightHandMiddle1").distance_to(target))


func test_watch_turns_the_head_to_a_point() -> void:
	var rig := _player()
	_flee(rig, 1, 0.0)
	var forward: Vector3 = rig._left_axis.cross(Vector3.UP)
	var at := _at(rig, "Head") + forward * 0.3 + rig._left_axis * 0.15 + Vector3.DOWN * 0.3
	rig.watch(rig.skeleton.global_transform * at, 1.0)
	assert_true(_face(rig).dot((at - _at(rig, "Head")).normalized()) > 0.99, "eyes on it")


func test_kneeling_puts_the_right_knee_on_the_floor() -> void:
	var rig := _player()
	_flee(rig, 1, 0.0)
	var y := rig.kneel(1.0)
	var knee := _at(rig, "RightLeg").y + y
	assert_true(knee > -0.005 and knee < 0.06, "right knee down on the floor (%.3f)" % knee)
	assert_true(_at(rig, "LeftFoot").y + y > 0.06, "left foot flat on it, not through it")


func test_holding_the_map_raises_a_sheet_before_the_chest() -> void:
	var rig := _player()
	_flee(rig, 1, 0.0)
	rig.hold_map(1.0)
	var forward: Vector3 = rig._left_axis.cross(Vector3.UP)
	var chest := _at(rig, "Spine2")
	for side in ["Left", "Right"]:
		var palm := _at(rig, side + "HandMiddle1")
		assert_true(palm.y > _at(rig, "Hips").y and palm.y < _at(rig, side + "Arm").y, "%s hand at chest height" % side)
		assert_true((palm - chest).dot(forward) > 0.12, "%s hand out before the chest" % side)
	var sheet := rig.skeleton.find_child("MapSheet", false, false) as MeshInstance3D
	assert_true(sheet != null and sheet.visible, "a sheet in its hands")
	rig.hold_map(0.0)
	assert_false(sheet.visible, "put away")


## No strips (user, 12 Oct 2026: stretched poses are rejected). Kneeling folds the knees past 100 degrees, and the cargo
## pockets on the outer thighs (0.1 above the knee) used to tear off with the shin into a strip down to the floor; the
## hands reaching for the box and over the head used to pull a web off the hip, where the hanging forearm was welded to
## it. No triangle may grow by more than the sprint's worst knee crease did before (0.11).
func test_kneeling_and_reaching_tear_no_strips() -> void:
	var rig := _player()
	var mi: MeshInstance3D = rig.skeleton.get_parent().find_children("*", "MeshInstance3D", true, false)[0]
	var rest := _skinned(rig, mi)
	_flee(rig, 1, 0.0)
	rig.kneel(1.0)
	assert_true(_worst_growth(rig, mi, rest) < 0.11, "kneeling: longest edge growth %.3f" % _worst_growth(rig, mi, rest))
	var forward: Vector3 = rig._left_axis.cross(Vector3.UP)
	var hips := _at(rig, "Hips")
	rig.reach("Right", rig.skeleton.global_transform * (hips + forward * 0.4), 1.0)
	rig.reach("Left", rig.skeleton.global_transform * (hips + forward * 0.45 + Vector3.DOWN * 0.12), 1.0)
	assert_true(_worst_growth(rig, mi, rest) < 0.11, "at the box: longest edge growth %.3f" % _worst_growth(rig, mi, rest))
	var cowering := _player()
	_flee(cowering, 90, 0.0, 1.0)
	assert_true(_worst_growth(cowering, mi, rest) < 0.11, "cowering: longest edge growth %.3f" % _worst_growth(cowering, mi, rest))


## The dashboard's lobby stance (user, 17 Oct 2026: "look straight"; map removed 17 Oct 2026): the right arm hangs loose at the side
## and nothing tears.
func test_the_lobby_stance_tears_no_strips() -> void:
	var rig := _player()
	var mi: MeshInstance3D = rig.skeleton.get_parent().find_children("*", "MeshInstance3D", true, false)[0]
	var rest := _skinned(rig, mi)
	_flee(rig, 1, 0.0)
	rig.showcase(1.0)
	assert_true(rig.skeleton.find_child("FoldedMap", false, false) == null, "no folded map in the lobby stance")
	assert_true(_worst_growth(rig, mi, rest) < 0.11, "longest edge growth %.3f" % _worst_growth(rig, mi, rest))
	_flee(rig, 1, 0.0, 0.55)  # the demon awake (a play control focused)
	rig.showcase(1.0)
	assert_true(_worst_growth(rig, mi, rest) < 0.11, "tensed: longest edge growth %.3f" % _worst_growth(rig, mi, rest))


## The lobby stance plants the feet (user, 17 Oct 2026: "keep foot static on the floor, let upper body move"): the
## breathing, the sway, the demon waking (fear) and a flinch move the upper body, never the boots or the body's height.
func test_the_lobby_stance_plants_the_feet() -> void:
	var rig := _player()
	var boots: Array[String] = ["LeftFoot", "RightFoot", "LeftToeBase", "RightToeBase"]
	_flee(rig, 1, 0.0)
	var height := rig.showcase(1.0)
	var leg := _at(rig, "LeftUpLeg").distance_to(_at(rig, "LeftFoot"))
	var planted: Array[Vector3] = []
	for bone in boots:
		planted.append(_at(rig, bone))
	var head := _at(rig, "Head")
	var drift := 0.0
	var lift := 0.0
	var nod := 0.0
	for frame in 180:  # three seconds: calm, then tense, a flinch on the way
		if frame == 90:
			rig.startle(1.0)
		_flee(rig, 1, 0.0, 0.0 if frame < 60 else 0.55)
		lift = maxf(lift, absf(rig.showcase(1.0) - height))
		for i in boots.size():
			drift = maxf(drift, _at(rig, boots[i]).distance_to(planted[i]))
		nod = maxf(nod, _at(rig, "Head").distance_to(head))
	assert_true(drift < leg * 0.002, "the boots moved %.4f (leg %.3f)" % [drift, leg])
	assert_true(lift < 0.0001, "the body rose or sank %.4f m" % lift)
	assert_true(nod > leg * 0.02, "the upper body moves: head %.4f (leg %.3f)" % [nod, leg])


## How much the most stretched edge of the skin has grown since `rest` (mesh units).
func _worst_growth(rig: DevilRig, mi: MeshInstance3D, rest: PackedVector3Array) -> float:
	var posed := _skinned(rig, rig.skeleton.get_parent().find_children("*", "MeshInstance3D", true, false)[0])
	var indices: PackedInt32Array = (mi.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_INDEX]
	var worst := 0.0
	for t in range(0, indices.size(), 3):
		for e in 3:
			var a := indices[t + e]
			var b := indices[t + (e + 1) % 3]
			worst = maxf(worst, posed[a].distance_to(posed[b]) - rest[a].distance_to(rest[b]))
	return worst


## Every vertex where the skin puts it now (mesh space): the GPU's skinning, by hand.
func _skinned(rig: DevilRig, mi: MeshInstance3D) -> PackedVector3Array:
	var arrays := (mi.mesh as ArrayMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var per := bones.size() / verts.size()
	var mats: Array[Transform3D] = []
	for b in mi.skin.get_bind_count():
		var bone := mi.skin.get_bind_bone(b)
		bone = bone if bone >= 0 else rig.skeleton.find_bone(mi.skin.get_bind_name(b))
		mats.append(rig.skeleton.get_bone_global_pose(bone) * mi.skin.get_bind_pose(b))
	var out := PackedVector3Array()
	out.resize(verts.size())
	for v in verts.size():
		var p := Vector3.ZERO
		for k in per:
			if weights[v * per + k] > 0.0:
				p += (mats[bones[v * per + k]] * verts[v]) * weights[v * per + k]
		out[v] = p
	return out


## Which way the body turns and how it walks for a move (local velocity, -Z ahead): toward it, or backing away.
func test_heading_turns_toward_the_move_or_backs_away() -> void:
	assert_true(DevilRig.heading(Vector3(0, 0, -2)).is_equal_approx(Vector2(0.0, 2.0)), "straight ahead")
	assert_true(DevilRig.heading(Vector3(-2, 0, 0)).is_equal_approx(Vector2(PI * 0.5, 2.0)), "sidestep left: turned left")
	assert_true(DevilRig.heading(Vector3(0, 0, 2)).is_equal_approx(Vector2(0.0, -2.0)), "straight back: backing away")
	assert_true(DevilRig.heading(Vector3(-1, 0, 1)).is_equal_approx(Vector2(-PI * 0.25, -sqrt(2.0))), "back-left: backing away, turned right")


func _distance(p: Vector3, segments: Array[Vector3]) -> float:
	var best := INF
	for s in range(0, segments.size(), 2):
		var ab := segments[s + 1] - segments[s]
		var t := clampf((p - segments[s]).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
		best = minf(best, (segments[s] + ab * t).distance_to(p))
	return best
