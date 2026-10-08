class_name KeyPickup
extends Node3D
## A key waiting on the floor (it replaces the sigil cube; the rules are the same). The 3D key spins,
## bobs and glows in its world's colour inside a soft halo, with sparkles drifting off it.
## collect() pops it: a flash, a burst, gone.

## The old key model, until the delivered one (Art.model("key")) exists. The HUD and minimap use Art.key_icon().
const OLD_MODEL := "res://assets/assets/key.glb"
## Key length (metres).
const LENGTH := 0.95
const SPIN_SPEED := 2.4
const BOB := 0.07
const BOB_SPEED := 2.2
const HALO_SIZE := 1.4
const POP_TIME := 0.2

var _key: Node3D
var _halo: Sprite3D
var _light: OmniLight3D
var _time := 0.0
var _base_y := 0.0


## `glow` scales its light (the Locksmith omen: brighter, seen from farther).
func build(color: Color, phase: float, glow := 1.0) -> void:
	_time = phase
	_base_y = position.y
	_halo = Sprite3D.new()
	_halo.texture = _halo_texture()
	_halo.pixel_size = HALO_SIZE / 128.0
	_halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_halo.shaded = false
	_halo.modulate = Color(color, 0.55)
	add_child(_halo)
	_key = Node3D.new()
	_key.add_child(model(LENGTH, -LENGTH * 0.5))
	add_child(_key)
	_light = OmniLight3D.new()
	_light.light_color = color
	_light.light_energy = 1.3 * glow
	_light.omni_range = 3.0 * sqrt(glow)
	add_child(_light)
	add_child(_sparkles(color, false))


func _process(delta: float) -> void:
	_time += delta
	_key.rotation.y += SPIN_SPEED * delta
	position.y = _base_y + sin(_time * BOB_SPEED) * BOB
	_halo.modulate.a = 0.4 + 0.2 * sin(_time * 3.1)


## Grabbed: swell, flash and burst, then hide. The HUD shows the key flying to its slot.
func collect() -> void:
	set_process(false)
	add_child(_sparkles(_light.light_color, true))
	var tween := create_tween().set_parallel()
	tween.tween_property(_key, "scale", Vector3.ONE * 1.6, POP_TIME * 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_key, "scale", Vector3.ZERO, POP_TIME * 0.5).set_delay(POP_TIME * 0.5).set_ease(Tween.EASE_IN)
	tween.tween_property(_halo, "scale", Vector3.ONE * 2.5, POP_TIME)
	tween.tween_property(_halo, "modulate:a", 0.0, POP_TIME)
	tween.tween_property(_light, "light_energy", 0.0, POP_TIME * 2.0).from(5.0)
	tween.chain().tween_interval(0.6)
	tween.chain().tween_callback(hide)


## The key model, `length` m from blade tip to bow, tip at local `tip_y`, face toward +Z.
static func model(length: float, tip_y: float) -> Node3D:
	var scene := Art.model("key")
	var key: Node3D = (scene if scene != null else load(OLD_MODEL) as PackedScene).instantiate()
	ModelFit.fit_height(key, length, tip_y)
	key.rotation.y = PI * 0.5
	return key


## Idle: a few motes drifting up. Burst: one shot of sparks flying out.
static func _sparkles(color: Color, burst: bool) -> CPUParticles3D:
	var mesh := QuadMesh.new()
	var material := Art.fx_material(Art.Fx.SPARKLE, color.lightened(0.4), true)
	mesh.size = Vector2.ONE * ((0.12 if burst else 0.08) * (2.0 if material != null else 1.0))
	if material == null:
		material = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.albedo_color = color.lightened(0.4)
		material.albedo_texture = _halo_texture()
	mesh.material = material
	var p := CPUParticles3D.new()
	p.mesh = mesh
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25
	p.gravity = Vector3.ZERO if burst else Vector3(0, 0.4, 0)
	p.spread = 180.0
	p.initial_velocity_min = 2.0 if burst else 0.05
	p.initial_velocity_max = 4.0 if burst else 0.2
	p.damping_min = 4.0 if burst else 0.0
	p.damping_max = 6.0 if burst else 0.0
	p.amount = 40 if burst else 10
	p.lifetime = 0.6 if burst else 1.6
	p.one_shot = burst
	p.explosiveness = 1.0 if burst else 0.0
	var fade := Curve.new()
	fade.add_point(Vector2(0, 1))
	fade.add_point(Vector2(1, 0))
	p.scale_amount_curve = fade
	p.emitting = true
	return p


static var _halo_cache: GradientTexture2D

static func _halo_texture() -> GradientTexture2D:
	if _halo_cache == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		_halo_cache = GradientTexture2D.new()
		_halo_cache.gradient = gradient
		_halo_cache.fill = GradientTexture2D.FILL_RADIAL
		_halo_cache.fill_from = Vector2(0.5, 0.5)
		_halo_cache.fill_to = Vector2(1.0, 0.5)
		_halo_cache.width = 128
		_halo_cache.height = 128
	return _halo_cache
