class_name TrapPit
extends Node3D
## One cracked floor in 3D (TrapField owns the rule). The tile is a few stone plates over a real
## shaft: HIDDEN = flush floor, CRACKED = the plates sag apart and ember light bleeds up through the
## seams (brighter and faster when you're close), COLLAPSED = they break away and tumble into the dark.

const PLATES := 3
## Irregular cut lines, as a fraction of a plate: rows don't line up, so it reads as broken stone.
const JITTER := 0.28
const PLATE_THICKNESS := 0.15
const FLOOR_TOP := -0.005
const SEAM := 0.014
const SAG := 0.045
const SAG_TILT_DEGREES := 4.0
## Cracked plates shrink toward their centres: the seams open and the ember shows through.
const SAG_SPREAD := 0.9
const SHAFT_DEPTH := 12.0
const GLOW_COLOR := Color(1.0, 0.26, 0.05)
const GLOW_RANGE := 2.8
## Ember alpha while hidden, times the floor's cue strength (early floors teach, late floors hide).
const HIDDEN_EMBER := 0.3
const GRAVITY := 9.8
## Seconds per metre from your feet: the plate under you goes first, the rim last.
const STAGGER := 0.11

var cell_size := 2.4
var cue := 1.0
## Read each frame for the proximity pulse; set by the floor.
var player: Node3D
var plates: Array[MeshInstance3D] = []
var state: int = TrapField.State.HIDDEN

var _rest: Array[Transform3D] = []
var _sag: Array[Transform3D] = []
var _velocity: Array[Vector3] = []
var _spin: Array[Vector3] = []
var _delay: Array[float] = []
var _crack_tween: Tween
var _fall_time := -1.0
var _time := 0.0
var _flare := 0.0
var _glow: OmniLight3D
var _ember: MeshInstance3D
var _ember_material: StandardMaterial3D
var _dust: CPUParticles3D
var _rng := RandomNumberGenerator.new()


func build(cell: Vector2i, floor_material: Material, shaft_material: Material, dust_mesh: Mesh) -> void:
	_rng.seed = hash(cell)
	var half := cell_size * 0.5
	var depth := cell_size / PLATES
	for row in PLATES:
		var cuts: Array[float] = [-half]
		for c in range(1, PLATES):
			cuts.append(-half + (c + _rng.randf_range(-JITTER, JITTER)) * depth)
		cuts.append(half)
		for col in PLATES:
			var mesh := BoxMesh.new()
			mesh.size = Vector3(cuts[col + 1] - cuts[col] - SEAM, PLATE_THICKNESS, depth - SEAM)
			var plate := MeshInstance3D.new()
			plate.mesh = mesh
			plate.material_override = floor_material
			plate.position = Vector3((cuts[col] + cuts[col + 1]) * 0.5, FLOOR_TOP - PLATE_THICKNESS * 0.5, -half + (row + 0.5) * depth)
			add_child(plate)
			plates.append(plate)
			_rest.append(plate.transform)
			var tilt := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.6, 0.6), _rng.randf_range(-1, 1)) * deg_to_rad(SAG_TILT_DEGREES)
			_sag.append(Transform3D(Basis.from_euler(tilt).scaled(Vector3(SAG_SPREAD, 1.0, SAG_SPREAD)), plate.position - Vector3(0, _rng.randf_range(0.35, 1.0) * SAG, 0)))
			_velocity.append(Vector3.ZERO)
			_spin.append(Vector3.ZERO)
			_delay.append(0.0)
	_build_shaft(shaft_material)
	_build_dust(dust_mesh)
	show_state(TrapField.State.HIDDEN)


## Jump straight to a state (build, revive). Plates that fell are put back.
func show_state(new_state: int) -> void:
	state = new_state
	_kill_crack_tween()
	_fall_time = -1.0
	_flare = 0.0
	for i in plates.size():
		plates[i].transform = _sag[i] if state == TrapField.State.CRACKED else _rest[i]
		plates[i].visible = state != TrapField.State.COLLAPSED
	_ember.visible = state != TrapField.State.COLLAPSED
	_set_ember(HIDDEN_EMBER * cue if state == TrapField.State.HIDDEN else 0.8)
	_glow.visible = state == TrapField.State.CRACKED


## First step: the plates drop and split, dust kicks up, the light below flares.
func crack() -> void:
	state = TrapField.State.CRACKED
	_glow.visible = true
	_flare = 1.0
	_kill_crack_tween()
	_crack_tween = create_tween().set_parallel()
	for i in plates.size():
		_crack_tween.tween_property(plates[i], "transform", _sag[i], 0.32).set_delay(_rng.randf() * 0.08).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_burst(28)


## Second step: it gives way, starting under `from` (world position of your feet).
func collapse(from: Vector3) -> void:
	state = TrapField.State.COLLAPSED
	_kill_crack_tween()
	var local := to_local(from)
	for i in plates.size():
		var p := plates[i].position
		_delay[i] = Vector2(p.x - local.x, p.z - local.z).length() * STAGGER + _rng.randf() * 0.04
		# Inward and down: plates fall into the shaft, never through its walls.
		_velocity[i] = Vector3(-p.x * 0.5, -_rng.randf_range(0.2, 0.8), -p.z * 0.5)
		_spin[i] = Vector3(_rng.randf_range(-5, 5), _rng.randf_range(-2, 2), _rng.randf_range(-5, 5))
	_fall_time = 0.0
	_flare = 1.6
	_burst(64)


func _process(delta: float) -> void:
	_time += delta
	_flare = maxf(_flare - delta * 1.8, 0.0)
	if _fall_time >= 0.0:
		_advance_fall(delta)
	if state == TrapField.State.CRACKED:
		_pulse()


func _advance_fall(delta: float) -> void:
	_fall_time += delta
	for i in plates.size():
		if _fall_time < _delay[i] or not plates[i].visible:
			continue
		_velocity[i].y -= GRAVITY * delta
		plates[i].position += _velocity[i] * delta
		plates[i].rotate_object_local(_spin[i].normalized(), _spin[i].length() * delta)
		plates[i].visible = plates[i].position.y > -SHAFT_DEPTH
	# The ember was the light under the floor; with the floor gone it burns out fast.
	_set_ember(maxf(0.8 - _fall_time * 4.0, 0.0))
	_glow.light_energy = maxf(1.0 - _fall_time, 0.0) * 2.5
	_ember.visible = _fall_time < 0.25


## The 2D "critical" state: breathing while cracked, faster and brighter as you get close.
func _pulse() -> void:
	var near := 0.0
	if player != null:
		var gap := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()
		near = clampf(1.0 - (gap - cell_size * 0.5) / cell_size, 0.0, 1.0)
	var wave := 0.5 + 0.5 * sin(_time * lerpf(2.5, 11.0, near))
	_glow.light_energy = (lerpf(0.35, 1.5, near) * (0.55 + 0.45 * wave)) * (1.0 + _flare * 3.0)
	_set_ember(lerpf(0.5, 1.0, wave) + _flare)


func _kill_crack_tween() -> void:
	if _crack_tween != null and _crack_tween.is_valid():
		_crack_tween.kill()


func _set_ember(alpha: float) -> void:
	_ember_material.albedo_color = Color(GLOW_COLOR, clampf(alpha, 0.0, 1.0))


func _burst(amount: int) -> void:
	_dust.amount = amount
	_dust.restart()


func _build_shaft(material: Material) -> void:
	var half := cell_size * 0.5
	for side in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var wall := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.1 if side.x != 0 else cell_size + 0.2, SHAFT_DEPTH, 0.1 if side.z != 0 else cell_size + 0.2)
		wall.mesh = mesh
		wall.material_override = material
		wall.position = side * (half + 0.05) + Vector3(0, -SHAFT_DEPTH * 0.5, 0)
		add_child(wall)
	_ember_material = StandardMaterial3D.new()
	_ember_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ember_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ember = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * (cell_size - 0.02)
	_ember.mesh = plane
	_ember.material_override = _ember_material
	_ember.position.y = FLOOR_TOP - PLATE_THICKNESS - SAG - 0.02
	add_child(_ember)
	_glow = OmniLight3D.new()
	_glow.light_color = GLOW_COLOR
	_glow.omni_range = GLOW_RANGE
	# Above the floor: a red danger aura on the tile and the walls around it.
	_glow.position.y = 0.35
	add_child(_glow)


func _build_dust(mesh: Mesh) -> void:
	_dust = CPUParticles3D.new()
	_dust.mesh = mesh
	_dust.emitting = false
	_dust.one_shot = true
	_dust.explosiveness = 0.9
	_dust.lifetime = 1.3
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(cell_size * 0.45, 0.02, cell_size * 0.45)
	_dust.direction = Vector3.UP
	_dust.spread = 40.0
	_dust.initial_velocity_min = 0.4
	_dust.initial_velocity_max = 1.4
	_dust.gravity = Vector3(0, -GRAVITY, 0)
	_dust.scale_amount_min = 0.4
	_dust.scale_amount_max = 1.6
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0))
	_dust.scale_amount_curve = shrink
	add_child(_dust)
