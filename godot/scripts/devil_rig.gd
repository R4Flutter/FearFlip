class_name DevilRig
extends RefCounted
## Animates the Devil (prowl) and the player (flee, flail). The models have Mixamo bones but no
## animation clips, so every gait is procedural: each swing is a rotation about a skeleton-space axis on top of the
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
## The hands' segments run on through the claws, which hang to the knees.
const CLAW_LENGTH := 0.3
## Limbs and the head reach only their own part of the mesh: a region grown over the surface from the bone outwards
## while it stays within REGION_RADIUS (mesh units; the model is ~1 tall) of the chain. Measured on
## skleton_added_devil.glb: arm surface, spikes and claws lie within 0.10 of their bones and the tendrils hanging beside
## them from 0.11 (0.15 / 0.16 for the legs). Everything outside every region (the tendrils off the head, shoulders and
## back) weighs on the trunk, so raising an arm moves the arm, not a tendril stretched into a long strip.
## Regions (_region_of): an arm is Arm, ForeArm, Hand and its fingers; a leg is UpLeg, Leg, Foot and its toe.
const REGION_RADIUS := {"LeftArm": 0.10, "RightArm": 0.10, "LeftLeg": 0.15, "RightLeg": 0.15, "Head": 0.09}
## The claws are the fingers: each weighs on its own joints (1 -> 2 -> 3), and past the last joint on FINGER_TIP more
## (claw tips measured down to 0.15 below it). The hand bone itself keeps only the palm.
const FINGERS := ["Thumb", "Index", "Middle", "Ring", "Pinky"]
const FINGER_TIP := 0.15
## The claws hook away from their straight segment (tips measured left behind at 0.10): the hand reaches further. Only
## what the walk reaches over the mesh from the hand joins it, so a tendril beside the hand stays out.
const HAND_RADIUS := 0.18
## A region grows from the points within this share of its radius of its bones (or the closest point, for a thick part
## like the head).
const REGION_CORE := 0.35
## roar(): seconds from the coil to the settle (main.gd's wake cut holds on it this long).
const ROAR_TIME := 1.8

## Re-weighted mesh, shared by every devil and kept across scene reloads.
static var _smooth_mesh: ArrayMesh
## Player mesh with the hem freed from the hands (unstick_hands), kept across scene reloads.
static var _unstuck_mesh: ArrayMesh

## Distance covered by one full gait cycle (two steps), metres.
var stride_length := 1.4

## Demon gait tunables for prowl() (degrees / m/s / seconds). Tune by eye.
var hunch := 30.0
var charge_hunch := 20.0
var crouch := 18.0
## At or below: the slow stalking walk. At or above: the full clawing charge.
var prowl_speed := 1.4
var charge_speed := 3.4
## Uneven cadence: one step hurries, the other drags (0 = even).
var limp := 0.3
var head_tilt := 14.0
## Seconds between the sudden head jerks / glances back (min, max).
var twitch_every := Vector2(1.2, 3.5)
## flee(): at or below, a careful walk; at or above, the full sprint (main.gd sets them from PlayerFeel).
var walk_pace := 3.0
var sprint_pace := 4.5

var skeleton: Skeleton3D
var _bones: Dictionary = {}
var _phase := 0.0
var _blend := 0.0
var _idle_time := 0.0
var _speed := 0.0
var _reach := 0.0
## Head yaw/pitch toward the prey (radians), smoothed.
var _look := Vector2.ZERO
var _twitch := Vector3.ZERO
var _twitch_goal := Vector3.ZERO
var _twitch_wait := 1.0
var _twitch_hold := 0.0
## Skeleton-space axis pointing to the devil's left. A negative rotation about it swings a hanging
## limb forward.
var _left_axis := Vector3.RIGHT
## Bones the skin binds (two of the left pinky's joints aren't): only those may curl.
var _bound := {}
## Per finger ("LeftHandIndex"...): the skeleton-space axis its rest joints already bend about. A positive turn about it
## curls the claw further, a negative one straightens it (_curl).
var _curl_axes := {}


## repair = false for clean rigs (e.g. character2withrig.glb: real bone rests, smooth weights).
func _init(model: Node, repair := true) -> void:
	var found := model.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		push_warning("DevilRig: no Skeleton3D in model")
		return
	skeleton = found[0]
	if repair:
		_repair(model)
	for bone in ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head", "LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg",
			"LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand", "RightShoulder", "RightArm", "RightForeArm", "RightHand", "LeftToeBase", "RightToeBase"]:
		_bones[bone] = _find_bone(bone)
	if _bones["LeftUpLeg"] >= 0 and _bones["RightUpLeg"] >= 0:
		var hips_span := skeleton.get_bone_global_rest(_bones["LeftUpLeg"]).origin - skeleton.get_bone_global_rest(_bones["RightUpLeg"]).origin
		_left_axis = Vector3(hips_span.x, 0.0, hips_span.z).normalized()
	for side in ["Left", "Right"]:
		for finger: String in FINGERS:
			var joints: Array[Vector3] = []
			for j in 3:
				var joint: String = side + "Hand" + finger + str(j + 1)
				_bones[joint] = _find_bone(joint)
				if _bound.has(_bones[joint]):
					joints.append(skeleton.get_bone_global_rest(_bones[joint]).origin)
			var bend := (joints[1] - joints[0]).cross(joints[2] - joints[1]) if joints.size() == 3 else Vector3.ZERO
			_curl_axes[side + "Hand" + finger] = bend.normalized() if bend.length() > 0.000001 else _left_axis
	for side in ["Left", "Right"]:  # a finger too short to measure (the left pinky) bends like the middle one
		var pinky: String = side + "HandPinky"
		if _curl_axes[pinky] == _left_axis:
			_curl_axes[pinky] = _curl_axes[side + "HandMiddle"]


## Yaw (radians, atan2(x, z)) the model's chest faces, measured from the hips. Set the model's
## rotation.y to (wanted_yaw - facing_yaw()) to make it walk straight along wanted_yaw.
func facing_yaw() -> float:
	var forward := _left_axis.cross(Vector3.UP)
	return atan2(forward.x, forward.z)


## The Devil's own gait, not a person's run: hunched and crouched, an uneven lurching stride that
## turns into a clawing charge with speed, the head locked on `target` (world point; Vector3.INF =
## none, so it searches) and jerking now and then, a heaving breath while it stands. `reach` 0..1
## throws both claws at you (the lunge). speed in m/s. Returns a vertical offset (metres) for the body.
func prowl(speed: float, delta: float, target: Vector3, reach: float) -> float:
	if skeleton == null:
		return 0.0
	_speed = lerpf(_speed, speed, 1.0 - exp(-4.0 * delta))
	_blend = move_toward(_blend, 1.0 if speed > 0.2 else 0.0, delta * 5.0)
	_reach = move_toward(_reach, reach, delta * 4.0)
	_phase += speed / stride_length * TAU * delta * (1.0 + limp * sin(_phase))
	_idle_time += delta
	var t := _idle_time
	var charge := clampf((_speed - prowl_speed) / (charge_speed - prowl_speed), 0.0, 1.0) * _blend
	var left := _left_axis
	var forward := left.cross(Vector3.UP)
	var breath := sin(t * 2.2) * (1.0 - _blend)
	var sway := sin(_phase) * _blend
	# Hips roll onto the planted foot; the spine curls further at a charge or a lunge, twists against
	# the hips and heaves while it stands.
	_pose("Hips", Quaternion(forward, deg_to_rad(6.0) * sway) * Quaternion(Vector3.UP, -deg_to_rad(8.0) * sway))
	var curl := deg_to_rad(hunch + charge_hunch * charge + 25.0 * _reach)
	for bone: String in ["Spine", "Spine1", "Spine2"]:
		_pose(bone, Quaternion(left, curl / 3.0 - deg_to_rad(2.0) * breath) * Quaternion(Vector3.UP, deg_to_rad(4.0) * sway))
	# Neck and head lift the face back out of the hunch, so the stare turns about true vertical.
	_tick_twitch(delta, Vector3(0.45, 0.25, 0.6), Vector2(0.08, 0.2), 40.0)
	_aim_head(target, t, delta)
	var lift := curl * 0.45
	var roll := deg_to_rad(head_tilt) * (1.0 - 0.5 * charge) + deg_to_rad(10.0) * sin(t * 0.5) * (1.0 - _blend) + _twitch.z
	_pose("Neck", Quaternion(left, -lift))
	_pose("Head", Quaternion(left, -lift) * Quaternion(Vector3.UP, _look.x + _twitch.x) * Quaternion(left, _look.y + _twitch.y) * Quaternion(forward, roll))
	var bend := deg_to_rad(crouch)
	var stride := deg_to_rad(lerpf(22.0, 42.0, charge)) * _blend
	var knee := deg_to_rad(lerpf(45.0, 85.0, charge)) * _blend
	for side: float in [1.0, -1.0]:
		var prefix := "Left" if side > 0.0 else "Right"
		var p := _phase + (0.0 if side > 0.0 else PI)
		# Crouched: thigh forward, knee back; the swinging leg folds high at a charge.
		_pose(prefix + "UpLeg", Quaternion(left, -bend - stride * sin(p)))
		_pose(prefix + "Leg", Quaternion(left, 2.0 * bend + knee * maxf(cos(p), 0.0)))
		# Shoulders hunched up and rolled forward, rising with each breath; a twitch jerks one higher.
		var shrug := deg_to_rad(10.0 + 4.0 * breath) + maxf(_twitch.z * side, 0.0) * 0.5
		_pose(prefix + "Shoulder", Quaternion(forward, side * shrug) * Quaternion(Vector3.UP, -side * deg_to_rad(10.0)))
		# Claws hang forward and swing against the legs; at a lunge both rake at you, wrists cocked.
		var arm := -deg_to_rad(lerpf(15.0, 35.0, charge)) + deg_to_rad(lerpf(18.0, 40.0, charge)) * sin(p) * _blend
		_pose(prefix + "Arm", Quaternion(left, lerpf(arm, deg_to_rad(-85.0 + 15.0 * sin(t * 14.0 + side)), _reach)))
		_pose(prefix + "ForeArm", Quaternion(left, lerpf(-deg_to_rad(lerpf(30.0, 60.0, charge)), -deg_to_rad(10.0), _reach)))
		_pose(prefix + "Hand", Quaternion(left, deg_to_rad(-15.0 + 35.0 * _reach) + 0.15 * sin(t * 2.7 + side * 1.3)))
		# Claws half-curled, flexing; at a lunge they open wide to rake. Toes flat (the roar grips with them).
		_curl(prefix, deg_to_rad(8.0) - deg_to_rad(28.0) * _reach, deg_to_rad(4.0), 1.0)
		_mix(prefix + "ToeBase", Quaternion.IDENTITY, 1.0)
	return absf(sin(_phase)) * lerpf(0.03, 0.07, charge) * _blend - _crouch_sink(bend)


## The player's run, a frightened person's: a careful walk that turns into a desperate sprint with
## speed, shoulders up and a shiver as `fear` (0..1) rises, doubled over panting while `winded` (0..1)
## and standing, and with `look_back` a glance over the shoulder now and then at a run (off in first
## person: you look where you aim). Arm swings stay small: character2withrig's jacket is skinned to
## the arms. speed in m/s. Returns a vertical offset (metres) for the body.
func flee(speed: float, delta: float, fear: float, winded: float, look_back := false) -> float:
	if skeleton == null:
		return 0.0
	_speed = lerpf(_speed, speed, 1.0 - exp(-4.0 * delta))
	_blend = move_toward(_blend, 1.0 if speed > 0.2 else 0.0, delta * 5.0)
	_phase += speed / stride_length * TAU * delta
	_idle_time += delta
	var t := _idle_time
	var run := clampf((_speed - walk_pace) / (sprint_pace - walk_pace), 0.0, 1.0) * _blend
	var left := _left_axis
	var forward := left.cross(Vector3.UP)
	var still := 1.0 - _blend
	var breath := sin(t * lerpf(1.6, 5.5, winded)) * lerpf(0.3, 1.0, winded)
	var shiver := (sin(t * 37.0) + sin(t * 23.0)) * 0.5 * fear
	var sway := sin(_phase) * _blend
	# Hips roll with each step, the forward leg's hip turning forward; weight shifts slowly while standing.
	_pose("Hips", Quaternion(forward, deg_to_rad(3.0) * sway + deg_to_rad(2.0) * sin(t * 0.7) * still) * Quaternion(Vector3.UP, -deg_to_rad(6.0) * sway))
	# Lean into the run and cower with fear (the head lifts back out of both); doubled over while winded.
	var lean := deg_to_rad(lerpf(4.0, 16.0, run) + 6.0 * fear)
	var slump := deg_to_rad(22.0) * winded * still
	_tick_twitch(delta, Vector3(1.9, 0.0, 0.0) if look_back and run > 0.5 else Vector3.ZERO, Vector2(0.4, 0.7), 10.0)
	var turn := _twitch.x
	# The chest turns against the hips, carrying the forward arm's shoulder forward.
	for bone: String in ["Spine", "Spine1", "Spine2"]:
		_pose(bone, Quaternion(left, (lean + slump) / 3.0 - deg_to_rad(1.5) * breath) * Quaternion(Vector3.UP, deg_to_rad(4.0 + 2.0 * run) * sway + turn * 0.1))
	_pose("Neck", Quaternion(left, -lean * 0.35) * Quaternion(Vector3.UP, turn * 0.3))
	_pose("Head", Quaternion(left, -lean * 0.35 + deg_to_rad(1.5) * shiver) * Quaternion(Vector3.UP, turn * 0.4))
	# Knees give with fear, and bend deep with the hands toward them while winded.
	var bend := deg_to_rad(4.0 + 10.0 * fear) + slump * 0.9
	var stride := deg_to_rad(lerpf(24.0, 45.0, run)) * _blend
	var knee := deg_to_rad(lerpf(40.0, 100.0, run)) * _blend
	for side: float in [1.0, -1.0]:
		var prefix := "Left" if side > 0.0 else "Right"
		var p := _phase + (0.0 if side > 0.0 else PI)
		_pose(prefix + "UpLeg", Quaternion(left, -bend - stride * sin(p)))
		_pose(prefix + "Leg", Quaternion(left, 2.0 * bend + knee * maxf(cos(p), 0.0)))
		# Arms swing against the legs a beat behind them (1 = this arm fully forward). Walking: loose,
		# close to the body, the elbow bending a little more on the way forward. Running: elbows near 90,
		# driven back and coming up and across the chest; the hand trails each swing.
		var arm_p := p - 0.2
		var swing := -sin(arm_p) * _blend
		# Shoulders tense up with fear, rise with each breath and roll forward with their arm.
		var shrug := deg_to_rad(4.0 + 10.0 * fear + 3.0 * breath * still) + deg_to_rad(1.0) * shiver
		_pose(prefix + "Shoulder", Quaternion(forward, side * shrug) * Quaternion(Vector3.UP, -side * deg_to_rad(lerpf(3.0, 7.0, run)) * swing))
		# Drawn in with fear, reaching for the knees while winded.
		var reach_fwd := lerpf(4.0 * _blend + 16.0 * swing, -8.0 + 38.0 * swing, run) + 8.0 * fear + rad_to_deg(slump) * 0.7
		var across := 6.0 + 10.0 * run * maxf(swing, 0.0)
		_pose(prefix + "Arm", Quaternion(left, -deg_to_rad(reach_fwd)) * Quaternion(forward, -side * deg_to_rad(across)))
		var elbow := lerpf(10.0 * (_blend + swing), 70.0 + 15.0 * swing, run) + 25.0 * fear * still
		_pose(prefix + "ForeArm", Quaternion(left, -deg_to_rad(elbow)))
		_pose(prefix + "Hand", Quaternion(left, -deg_to_rad(lerpf(10.0, 4.0, run)) * cos(arm_p) * _blend + deg_to_rad(2.0) * shiver * side))
	return absf(sin(_phase)) * lerpf(0.025, 0.06, run) * _blend - _crouch_sink(bend)


## How far (metres) bending the knees by `bend` lowers the hips, so the body sinks and the feet stay
## on the floor.
func _crouch_sink(bend: float) -> float:
	var hip: int = _bones.get("LeftUpLeg", -1)
	var foot: int = _bones.get("LeftFoot", -1)
	if hip < 0 or foot < 0:
		return 0.0
	var leg := (skeleton.get_bone_global_rest(hip).origin.y - skeleton.get_bone_global_rest(foot).origin.y) * skeleton.global_basis.get_scale().y
	return leg * (1.0 - cos(bend))


## Head yaw/pitch toward `target` (world point), or a slow searching sweep when it has none.
func _aim_head(target: Vector3, t: float, delta: float) -> void:
	var goal := Vector2(sin(t * 0.6) * deg_to_rad(35.0), 0.0)
	var head: int = _bones.get("Head", -1)
	if target.is_finite() and head >= 0:
		var to := skeleton.global_transform.affine_inverse() * target - skeleton.get_bone_global_pose(head).origin
		goal = Vector2(clampf(atan2(to.dot(_left_axis), to.dot(_left_axis.cross(Vector3.UP))), -1.3, 1.3),
				clampf(atan2(-to.y, Vector2(to.x, to.z).length()), -0.6, 0.6))
	_look = _look.lerp(goal, 1.0 - exp(-8.0 * delta))


## Every `twitch_every` seconds the head turns to a random angle within `size` (yaw, pitch, roll;
## radians) at `snap` speed, holds it for `hold` seconds and eases back: the Devil's jerks, the
## player's glances back.
func _tick_twitch(delta: float, size: Vector3, hold: Vector2, snap: float) -> void:
	_twitch_wait -= delta
	if _twitch_wait <= 0.0:
		_twitch_wait = randf_range(twitch_every.x, twitch_every.y)
		_twitch_hold = randf_range(hold.x, hold.y)
		_twitch_goal = Vector3(randf_range(-size.x, size.x), randf_range(-size.y, size.y * 0.6), randf_range(-size.z, size.z))
	_twitch_hold -= delta
	var held := _twitch_hold > 0.0
	_twitch = _twitch.lerp(_twitch_goal if held else Vector3.ZERO, 1.0 - exp(-(snap if held else 6.0) * delta))


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


## The roar (main.gd's wake cut), `t` seconds into it (ROAR_TIME long), layered over the standing prowl so it eases
## out of the stance and back into it: it coils (head down, claws drawn in, knees deep), bursts (chest out, head back,
## claws flung wide), holds the roar (head thrusting, claws flexing, chest heaving, the whole body shaking) and settles
## with its eyes on `target`. Arms are aimed by direction, like flail. Returns a vertical offset for the body.
func roar(t: float, delta: float, target: Vector3) -> float:
	var y := prowl(0.0, delta, target, 0.0)
	if skeleton == null:
		return y
	var axis := _left_axis
	var forward := axis.cross(Vector3.UP)
	var coil := _bump(t, 0.0, 0.14, 0.26, 0.4)
	var held := roar_force(t)
	var tremor := deg_to_rad(1.6) * held * (sin(t * 83.0) + sin(t * 117.0)) * 0.5
	var heave := deg_to_rad(2.5) * sin(t * 9.0) * held
	var thrust := deg_to_rad(8.0) * sin(t * 6.0) * held
	for bone: String in ["Spine", "Spine1", "Spine2"]:
		_mix(bone, Quaternion(axis, deg_to_rad(hunch + 18.0) / 3.0), coil)
		_mix(bone, Quaternion(axis, -deg_to_rad(12.0) / 3.0 + heave + tremor), held)
	_mix("Neck", Quaternion(axis, deg_to_rad(10.0)), coil)
	_mix("Neck", Quaternion(axis, -deg_to_rad(22.0)), held)
	_mix("Head", Quaternion(axis, deg_to_rad(14.0)), coil)
	_mix("Head", Quaternion(axis, -deg_to_rad(40.0) + thrust + tremor), held)  # the hooked snout up at the ceiling
	var bend := deg_to_rad(crouch)
	var deep := deg_to_rad(crouch + 12.0)
	for side: float in [1.0, -1.0]:
		var prefix := "Left" if side > 0.0 else "Right"
		_mix(prefix + "Shoulder", Quaternion(forward, side * deg_to_rad(18.0)), coil)
		_mix(prefix + "Shoulder", Quaternion(forward, side * deg_to_rad(12.0)), held)
		_mix(prefix + "UpLeg", Quaternion(axis, -deep), coil)
		_mix(prefix + "Leg", Quaternion(axis, 2.0 * deep), coil)
		_mix(prefix + "UpLeg", Quaternion(axis, -bend) * Quaternion(forward, side * deg_to_rad(6.0)), held)
		_mix(prefix + "Leg", Quaternion(axis, 2.0 * bend), held)
		# Claws clench in the coil and fly open with the roar, flexing; the toes grip the floor throughout.
		_curl(prefix, deg_to_rad(35.0), 0.0, coil)
		_curl(prefix, -deg_to_rad(25.0), deg_to_rad(10.0), held)
		_mix(prefix + "ToeBase", Quaternion(axis, deg_to_rad(25.0)), coil)
		_mix(prefix + "ToeBase", Quaternion(axis, deg_to_rad(15.0)), held)
		var arm: int = _bones.get(prefix + "Arm", -1)
		var fore: int = _bones.get(prefix + "ForeArm", -1)
		if arm < 0 or fore < 0:
			continue
		var rest_dir := (skeleton.get_bone_global_rest(fore).origin - skeleton.get_bone_global_rest(arm).origin).normalized()
		var out := Vector3(rest_dir.x, 0.0, rest_dir.z)
		out = out.normalized() if out.length() > 0.1 else axis * side
		# Coiled: claws drawn in before the belly. Roaring: flung out at shoulder height, a little forward, wrists back.
		_mix(prefix + "Arm", Quaternion(rest_dir, (forward * 0.8 + Vector3.DOWN * 0.5 - out * 0.15).normalized()), coil)
		_mix(prefix + "ForeArm", Quaternion(axis, -deg_to_rad(70.0)), coil)
		_mix(prefix + "Hand", Quaternion(axis, deg_to_rad(25.0)), coil)
		_mix(prefix + "Arm", Quaternion(rest_dir, (out + Vector3.UP * 0.3 + forward * 0.35).normalized()), held)
		_mix(prefix + "ForeArm", Quaternion(axis, -deg_to_rad(40.0) + tremor * 2.0), held)
		_mix(prefix + "Hand", Quaternion(axis, -deg_to_rad(20.0) + deg_to_rad(10.0) * sin(t * 6.0 + side)), held)
	return y - (_crouch_sink(deep) - _crouch_sink(bend)) * coil


## How hard it roars `t` seconds into roar() (0..1): the burst and the held roar. main.gd shakes the camera by it.
static func roar_force(t: float) -> float:
	return _bump(t, 0.28, 0.42, 1.25, 1.7)


## 0 before `a`, easing up to 1 by `b`, held to `c`, easing back down to 0 by `d`.
static func _bump(t: float, a: float, b: float, c: float, d: float) -> float:
	return smoothstep(a, b, t) * (1.0 - smoothstep(c, d, t))


## Apply `rotation` (skeleton space, relative to the rest pose) to a bone.
func _pose(bone: String, rotation: Quaternion) -> void:
	var index: int = _bones.get(bone, -1)
	if index < 0:
		return
	skeleton.set_bone_pose_rotation(index, _pose_rotation(index, rotation))


## Ease a bone from the pose it already has this frame (prowl's) toward `rotation` (as for _pose) by `w`.
func _mix(bone: String, rotation: Quaternion, w: float) -> void:
	var index: int = _bones.get(bone, -1)
	if index < 0 or w <= 0.0:
		return
	skeleton.set_bone_pose_rotation(index, skeleton.get_bone_pose_rotation(index).slerp(_pose_rotation(index, rotation), w))


## Mix every claw on one side toward a curl of `angle` per joint (radians, about that finger's own bend axis; negative
## opens and splays them), each joint fluttering by up to `flutter` out of step with the others, by `w`. Joints the
## skin doesn't bind (two of the left pinky's) are left alone.
func _curl(side: String, angle: float, flutter: float, w: float) -> void:
	for f in FINGERS.size():
		var finger: String = side + "Hand" + FINGERS[f]
		var axis: Vector3 = _curl_axes.get(finger, _left_axis)
		for j in 3:
			var joint := finger + str(j + 1)
			if _bound.has(_bones.get(joint, -1)):
				_mix(joint, Quaternion(axis, angle + flutter * sin(_idle_time * 7.0 + f * 1.3 + j * 0.7)), w)


func _pose_rotation(index: int, rotation: Quaternion) -> Quaternion:
	var rest := skeleton.get_bone_rest(index).basis.get_rotation_quaternion()
	var global_rest := skeleton.get_bone_global_rest(index).basis.get_rotation_quaternion()
	return rest * (global_rest.inverse() * rotation * global_rest)


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
	# Bone indices are parent-before-child, so parents are fixed before their children. A bone the skin doesn't bind
	# keeps its imported rest, and its children rest relative to where that really puts it (two left pinky joints).
	var globals: Dictionary = {}
	for bone in skeleton.get_bone_count():
		var parent_global: Transform3D = globals.get(skeleton.get_bone_parent(bone), Transform3D.IDENTITY)
		if not bind_globals.has(bone):
			globals[bone] = parent_global * skeleton.get_bone_rest(bone)
			continue
		_bound[bone] = true
		globals[bone] = bind_globals[bone]
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
	var body_origin := {}
	var origin := {}
	for b in skin.get_bind_count():
		var bone := skin.get_bind_bone(b)
		var bone_name := skeleton.get_bone_name(bone) if bone >= 0 else String(skin.get_bind_name(b))
		if bone_name.contains("ForeArm") or bone_name.contains("Hand"):
			hand_binds[b] = true
		if bone_name.contains("Arm") or bone_name.contains("Hand") or bone_name.contains("Shoulder"):
			arm_binds[b] = true
		else:
			body_origin[b] = skin.get_bind_pose(b).affine_inverse().origin
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
		var strays := _strays(vertices, arrays[Mesh.ARRAY_INDEX], bones, weights, per, hand_binds, body_origin)
		for v: int in strays:
			for k in per:
				bones[v * per + k] = strays[v] if k == 0 else 0
				weights[v * per + k] = 1.0 if k == 0 else 0.0
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		arrays[Mesh.ARRAY_INDEX] = _cut_fused(arrays[Mesh.ARRAY_INDEX], bones, weights, per, hand_binds, arm_binds)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, source.surface_get_format(surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		mesh.surface_set_material(surface, source.surface_get_material(surface))
	return mesh


## The model also fuses bits of trouser strap to the fingertips: islands of hand-dominated vertices
## far smaller than a hand (measured: 91 and 31 vertices against ~1,800 per hand), which fly off with
## the hand once the elbow bends. Returns {vertex: the body bind nearest its island} to move them to.
static func _strays(vertices: PackedVector3Array, indices: PackedInt32Array, bones: PackedInt32Array, weights: PackedFloat32Array, per: int, hand_binds: Dictionary, body_origin: Dictionary) -> Dictionary:
	if body_origin.is_empty():
		return {}
	var parent := range(vertices.size())
	var handy := {}
	var at := {}
	for v in vertices.size():
		var hand := 0.0
		for k in per:
			if hand_binds.has(bones[v * per + k]):
				hand += weights[v * per + k]
		if hand < 0.5:
			continue
		handy[v] = true
		var key := vertices[v].snapped(Vector3.ONE * 0.0001)  # copies split at UV seams share a position
		if at.has(key):
			_union(parent, v, at[key])
		else:
			at[key] = v
	for t in range(0, indices.size(), 3):
		if handy.has(indices[t]) and handy.has(indices[t + 1]) and handy.has(indices[t + 2]):
			_union(parent, indices[t], indices[t + 1])
			_union(parent, indices[t], indices[t + 2])
	var islands := {}
	var biggest := 0
	for v: int in handy:
		var island: Array = islands.get_or_add(_root(parent, v), [])
		island.append(v)
		biggest = maxi(biggest, island.size())
	var moved := {}
	for island: Array in islands.values():
		if island.size() * 5 >= biggest:
			continue
		var centre := Vector3.ZERO
		for v: int in island:
			centre += vertices[v]
		centre /= island.size()
		var best := -1
		for b: int in body_origin:
			if best < 0 or centre.distance_squared_to(body_origin[b]) < centre.distance_squared_to(body_origin[best]):
				best = b
		for v: int in island:
			moved[v] = best
	return moved


static func _root(parent: Array, v: int) -> int:
	while parent[v] != v:
		parent[v] = parent[parent[v]]
		v = parent[v]
	return v


static func _union(parent: Array, a: int, b: int) -> void:
	parent[_root(parent, a)] = _root(parent, b)


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


## Each vertex gets the 4 nearest bone segments, weighted by 1/d^4 (smooth blend across joints), among the trunk's
## segments and its own region's (_grow_regions): a tendril never weighs on the arm it hangs beside.
func _reweight(source: ArrayMesh, bind_globals: Dictionary, bind_of_bone: Dictionary) -> ArrayMesh:
	var starts := PackedVector3Array()
	var spans := PackedVector3Array()
	var inv_len2 := PackedFloat32Array()
	var binds := PackedInt32Array()
	var segment_region := PackedInt32Array()
	var segment_reach := PackedFloat32Array()
	var segment_weighs := PackedByteArray()  # 0: a claw guide, for the region walk only
	var names := REGION_RADIUS.keys()
	var segments := _segments()
	for bone_name: String in segments:
		var bone := _find_bone(bone_name)
		if not bind_globals.has(bone):
			continue
		var a: Vector3 = (bind_globals[bone] as Transform3D).origin
		var b: Vector3
		var end_bone := _find_bone(segments[bone_name]) if segments[bone_name] != "" else -1
		if bind_globals.has(end_bone):
			b = (bind_globals[end_bone] as Transform3D).origin
		else:  # a tip: on along the way from the nearest bound ancestor
			var up := skeleton.get_bone_parent(bone)
			while up >= 0 and not bind_globals.has(up):
				up = skeleton.get_bone_parent(up)
			var from: Vector3 = (bind_globals[up] as Transform3D).origin if up >= 0 else a - Vector3.UP
			var finger := bone_name.contains("Hand") and not bone_name.ends_with("Hand")
			b = a + (a - from).normalized() * (FINGER_TIP if finger else TIP_LENGTH)
		var part := names.find(_region_of(bone_name))
		_add_segment(a, b, bind_of_bone[bone], part, REGION_RADIUS[names[part]] if part >= 0 else 0.0, true,
				starts, spans, inv_len2, binds, segment_region, segment_reach, segment_weighs)
	for side in ["Left", "Right"]:  # the hooked claws, straight on from the forearm: they keep the tips in the hand's region
		var hand := _find_bone(side + "Hand")
		var fore := _find_bone(side + "ForeArm")
		if bind_globals.has(hand) and bind_globals.has(fore):
			var wrist: Vector3 = (bind_globals[hand] as Transform3D).origin
			var claw := wrist + (wrist - (bind_globals[fore] as Transform3D).origin).normalized() * CLAW_LENGTH
			_add_segment(wrist, claw, bind_of_bone[hand], names.find(side + "Arm"), HAND_RADIUS, false,
					starts, spans, inv_len2, binds, segment_region, segment_reach, segment_weighs)
	var arrays := source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var region := _grow_regions(vertices, arrays[Mesh.ARRAY_INDEX], starts, spans, inv_len2, segment_region, segment_reach)
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	bones.resize(vertices.size() * 4)
	weights.resize(vertices.size() * 4)
	# What a vertex may weigh on, per region (index + 1; 0 = the trunk): the trunk's segments and its region's, never
	# a claw guide or another limb's (or the head's) bone.
	var candidates := []
	for r in names.size() + 1:
		var allowed := PackedInt32Array()
		for s in starts.size():
			if segment_weighs[s] == 1 and (segment_region[s] < 0 or segment_region[s] == r - 1):
				allowed.append(s)
		candidates.append(allowed)
	for v in vertices.size():
		var p := vertices[v]
		var best_w := [0.0, 0.0, 0.0, 0.0]
		var best_s := [0, 0, 0, 0]
		for s: int in candidates[region[v] + 1]:
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
	arrays[Mesh.ARRAY_INDEX] = _cut_welds(arrays[Mesh.ARRAY_INDEX], bones, weights, bind_of_bone)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, source.surface_get_material(0))
	return mesh


## SEGMENTS plus each claw (finger joints 1 -> 2 -> 3 -> tip) and each toe.
static func _segments() -> Dictionary:
	var all := SEGMENTS.duplicate()
	for side in ["Left", "Right"]:
		all[side + "ToeBase"] = side + "Toe_End"
		for finger: String in FINGERS:
			var bone: String = side + "Hand" + finger
			all[bone + "1"] = bone + "2"
			all[bone + "2"] = bone + "3"
			all[bone + "3"] = ""
	return all


## The region a bone belongs to (a key of REGION_RADIUS), or "" for the trunk.
static func _region_of(bone_name: String) -> String:
	for side in ["Left", "Right"]:
		if bone_name.begins_with(side + "Hand") or bone_name == side + "Arm" or bone_name == side + "ForeArm":
			return side + "Arm"
		if bone_name.begins_with(side + "Toe") or bone_name == side + "UpLeg" or bone_name == side + "Leg" or bone_name == side + "Foot":
			return side + "Leg"
	return "Head" if bone_name == "Head" else ""


static func _add_segment(a: Vector3, b: Vector3, bind: int, region: int, reach: float, weighs: bool, starts: PackedVector3Array,
		spans: PackedVector3Array, inv_len2: PackedFloat32Array, binds: PackedInt32Array, segment_region: PackedInt32Array,
		segment_reach: PackedFloat32Array, segment_weighs: PackedByteArray) -> void:
	starts.append(a)
	spans.append(b - a)
	inv_len2.append(1.0 / maxf((b - a).length_squared(), 0.000001))
	binds.append(bind)
	segment_region.append(region)
	segment_reach.append(reach)
	segment_weighs.append(1 if weighs else 0)


## The AI mesh welds the claw tips to the shins and tendrils to the forearms where they touch: once the hand or the
## foot moves, those triangles stretch into long bars. Drops every triangle joining a vertex mostly on a hand or
## forearm (shin or foot) to a vertex with no weight at all on that limb. Joints never qualify: a shoulder or hip
## vertex isn't mostly on the far end of the limb.
func _cut_welds(indices: PackedInt32Array, bones: PackedInt32Array, weights: PackedFloat32Array, bind_of_bone: Dictionary) -> PackedInt32Array:
	var limb_of := {}  # bind -> limb (0..3)
	var far_end := {}  # binds of forearms, hands, claws, shins, feet, toes
	var limbs := ["LeftArm", "RightArm", "LeftLeg", "RightLeg"]
	for bone_name: String in _segments():
		var bind: int = bind_of_bone.get(_find_bone(bone_name), -1)
		var limb := limbs.find(_region_of(bone_name))
		if bind < 0 or limb < 0:
			continue
		limb_of[bind] = limb
		if not bone_name in ["LeftArm", "RightArm", "LeftUpLeg", "RightUpLeg"]:  # the shin is "LeftLeg": far end
			far_end[bind] = true
	var kept := PackedInt32Array()
	for t in range(0, indices.size(), 3):
		var on_limb := [[0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 0.0]]  # per corner, per limb
		var on_end := [[0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 0.0]]
		for c in 3:
			var v := indices[t + c]
			for k in 4:
				var bind := bones[v * 4 + k]
				if limb_of.has(bind):
					on_limb[c][limb_of[bind]] += weights[v * 4 + k]
					if far_end.has(bind):
						on_end[c][limb_of[bind]] += weights[v * 4 + k]
		var welded := false
		for l in 4:
			var ends := false
			var bare := false
			for c in 3:
				ends = ends or on_end[c][l] >= 0.5
				bare = bare or on_limb[c][l] <= 0.001
			welded = welded or (ends and bare)
		if not welded:
			kept.append_array([indices[t], indices[t + 1], indices[t + 2]])
	return kept


## Which region (index into REGIONS; -1 = the trunk) each vertex belongs to. Per region, a breadth-first walk over the
## mesh from the points at its bones' core, through points within its radius of them (REGION_RADIUS, HAND_RADIUS for a
## hand), distances measured as a share of that radius; a point two regions reach goes to the nearer. Copies of a point
## split at UV seams share one answer.
func _grow_regions(vertices: PackedVector3Array, indices: PackedInt32Array, starts: PackedVector3Array, spans: PackedVector3Array, inv_len2: PackedFloat32Array, segment_region: PackedInt32Array, segment_reach: PackedFloat32Array) -> PackedInt32Array:
	var point_of := PackedInt32Array()
	point_of.resize(vertices.size())
	var points := PackedVector3Array()
	var at := {}
	for v in vertices.size():
		var key := vertices[v].snapped(Vector3.ONE * 0.00001)
		if not at.has(key):
			at[key] = points.size()
			points.append(vertices[v])
		point_of[v] = at[key]
	var neighbours := []
	neighbours.resize(points.size())
	for p in points.size():
		neighbours[p] = PackedInt32Array()
	for t in range(0, indices.size(), 3):
		for c in 3:
			var a := point_of[indices[t + c]]
			var b := point_of[indices[t + (c + 1) % 3]]
			neighbours[a].append(b)
			neighbours[b].append(a)
	var owner := PackedInt32Array()
	owner.resize(points.size())
	owner.fill(-1)
	var owner_d := PackedFloat32Array()
	owner_d.resize(points.size())
	owner_d.fill(INF)
	var names := REGION_RADIUS.keys()
	for r in names.size():
		var own := PackedInt32Array()
		for s in starts.size():
			if segment_region[s] == r:
				own.append(s)
		var d := PackedFloat32Array()
		d.resize(points.size())
		var closest := 0
		for p in points.size():
			var best := INF
			for s in own:
				var t := clampf((points[p] - starts[s]).dot(spans[s]) * inv_len2[s], 0.0, 1.0)
				best = minf(best, (starts[s] + spans[s] * t).distance_to(points[p]) / segment_reach[s])
			d[p] = best
			if best < d[closest]:
				closest = p
		var reached := PackedByteArray()
		reached.resize(points.size())
		var queue := PackedInt32Array()
		for p in points.size():
			if d[p] < REGION_CORE:
				reached[p] = 1
				queue.append(p)
		if queue.is_empty():
			reached[closest] = 1
			queue.append(closest)
		var next := 0
		while next < queue.size():
			var p := queue[next]
			next += 1
			for q: int in neighbours[p]:
				if reached[q] == 0 and d[q] < 1.0:
					reached[q] = 1
					queue.append(q)
		for p in queue:
			if d[p] < owner_d[p]:
				owner[p] = r
				owner_d[p] = d[p]
	var region := PackedInt32Array()
	region.resize(vertices.size())
	for v in vertices.size():
		region[v] = owner[point_of[v]]
	return region


## Mixamo names arrive as "mixamorig:Hips" or "mixamorig_Hips" depending on import.
func _find_bone(bone: String) -> int:
	if bone.is_empty():
		return -1
	for i in skeleton.get_bone_count():
		var bone_name := skeleton.get_bone_name(i)
		if bone_name == bone or bone_name.ends_with(":" + bone) or bone_name.ends_with("_" + bone):
			return i
	return -1
