extends Node3D
## One FearFlip floor (FEARFLIP_3D_GAME_APPROACH.md §4-§8): a seeded maze that exists in WAKE and
## NIGHTMARE (FloorLayout), World Flip + Flipping Time (FlipSystem), 3 sigils open the exit,
## and the Devil hunts in NIGHTMARE only. Grid is truth; 3D is the projection.

const CELL_SIZE := 2.4
const WALL_HEIGHT := 2.8
const PLAYER_HEIGHT := 1.7
const PLAYER_RADIUS := 0.35
const GRAVITY := 18.0
const CEILING_HEIGHT := 3.0
const WALL_TRIM_HEIGHT := 0.12
const DEVIL_NEAR_DISTANCE := 3
const DEVIL_Y := 0.75
## Player body: feet at the capsule bottom, scaled from the ~1 m model to ~1.85 m.
const PLAYER_MESH_Y := -1.6
const PLAYER_MESH_SCALE := 1.9
## Depth-1 chase speed (§5). Walking (3.0 m/s) can't outrun it; sprinting, loops and flipping can.
const DEVIL_CHASE_SPEED := 3.6
const DEVIL_ENRAGE_MULTIPLIER := 1.2
const DEVIL_ENRAGE_DURATION := 20.0
## A forced flip never drops you closer than this (path cells) to the Devil; it is moved first.
const FAIR_FLIP_DISTANCE := 4
const DEVIL_RETREAT_DISTANCE := 8
## No grab for this long after entering NIGHTMARE: no instant catches.
const FLIP_CATCH_GRACE := 0.6
## How fast the Devil turns to face where it runs (higher = snappier).
const DEVIL_TURN_SPEED := 10.0
const FLIP_ROLL_TIME := 0.35

const WAKE := FloorLayout.World.WAKE
const NIGHTMARE := FloorLayout.World.NIGHTMARE
const WORLD_NAMES: Array[String] = ["WAKE", "NIGHTMARE"]
## Physics layers: 1 = floor + walls in both worlds, 2 = WAKE-only walls, 3 = NIGHTMARE-only walls.
const LAYER_SHARED := 1
const LAYER_WAKE := 2
const LAYER_NIGHTMARE := 4
## Per-world look, indexed by World.
const FOG_COLORS: Array[Color] = [Color(0.04, 0.07, 0.13), Color(0.2, 0.01, 0.02)]
const FOG_DENSITIES: Array[float] = [0.035, 0.07]
const AMBIENT_COLORS: Array[Color] = [Color(0.025, 0.04, 0.07), Color(0.09, 0.01, 0.015)]
const GLOW_COLORS: Array[Color] = [Color(0.12, 0.32, 0.55), Color(0.65, 0.05, 0.03)]
const SIGIL_COLORS: Array[Color] = [Color(0.55, 0.9, 1.0), Color(1.0, 0.35, 0.1)]
const MUSIC_DB := -14.0

const PLAYER_MODEL = preload("res://assets/character/character2withrig.glb")
const DEVIL_MODEL = preload("res://assets/character/skleton_added_devil.glb")
const FOOTSTEP_PATHS: Array[String] = [
	"res://assets/audio/footstep_1.wav",
	"res://assets/audio/footstep_2.wav",
	"res://assets/audio/footstep_3.wav",
]

## Movement, look, head-bob, FOV, flashlight and footstep tunables (res://resources/player_feel.tres).
@export var feel: PlayerFeel

@export_group("Floor")
## 0 = new random floor each run. Set a seed to replay or debug one floor.
@export var fixed_seed: int = 0
## Rooms per side; the maze is (2 * rooms + 1) tiles square. 7 = depth 1 (15x15).
@export_range(4, 13) var rooms: int = 7

@export_group("World Lights")
## Ceiling light on every Nth open cell (by (x+y) % N). Higher = darker, cheaper.
@export_range(2, 8) var world_light_spacing: int = 4
@export_range(0.0, 2.0, 0.05) var world_light_energy: float = 0.4
## Off by default: only the flashlight casts shadows (mobile budget).
@export var world_light_shadows: bool = false

var layout: FloorLayout
var flip: FlipSystem
var world: int = WAKE
var player: CharacterBody3D
var player_mesh: Node3D
var player_rig: DevilRig
var camera_pivot: Node3D
var devil: Node3D
var devil_mesh: Node3D
var devil_rig: DevilRig
var goal: Node3D
var minimap: Control
var player_cell := Vector2i(1, 1)
var devil_cell := Vector2i.ZERO
## Where the Devil is heading. In WAKE it keeps the spot where you vanished.
var devil_target := Vector2i.ZERO
var devil_timer := 0.0
var enrage_left := 0.0
var catch_grace := 0.0
var elapsed := 0.0
var pitch := 0.0
var yaw := 0.0
var game_state := "playing"
var sigil_nodes: Array[Node3D] = []
var sigil_collected: Array[bool] = []
var sigils_collected := 0
var exit_open := false
var env: Environment
var world_lights: Array[OmniLight3D] = []
var wake_walls: Node3D
var nightmare_walls: Node3D
var trim_material: StandardMaterial3D
var light_material: StandardMaterial3D
var accent_material: StandardMaterial3D
var goal_material: StandardMaterial3D
var goal_light: OmniLight3D
var status_label: Label
var state_label: Label
var warning_label: Label
var flash_rect: ColorRect
var calm_player: AudioStreamPlayer
var intense_player: AudioStreamPlayer
var win_player: AudioStreamPlayer
var lose_player: AudioStreamPlayer
var flip_player: AudioStreamPlayer
var deny_player: AudioStreamPlayer
var warning_player: AudioStreamPlayer
var sigil_player: AudioStreamPlayer
var devil_approach_player: AudioStreamPlayer
var devil_approach_playing := false
var camera: Camera3D
var flashlight: SpotLight3D
var footstep_player: AudioStreamPlayer3D
var flashlight_on := true
var step_phase := 0.0
var bob_intensity := 0.0
var breath_time := 0.0
var was_on_floor := true
var flicker_value := 0.0
var flicker_target := 0.0
var flicker_timer := 0.0
var stutter_left := 0.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	if feel == null:
		feel = PlayerFeel.new()
	# Main keeps processing while paused so Esc can resume; gameplay loops check the pause flag.
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	var seed_value := fixed_seed if fixed_seed != 0 else rng.randi()
	print("FearFlip floor seed: %d" % seed_value)
	layout = FloorLayout.generate(seed_value, rooms)
	flip = FlipSystem.new(seed_value)
	flip.flipped.connect(_on_flipped)
	flip.flip_denied.connect(_on_flip_denied)
	flip.flipping_time_warning.connect(_on_flipping_time_warning)
	player_cell = layout.spawn
	devil_cell = layout.devil_spawn
	devil_target = devil_cell
	_build_environment()
	_build_audio()
	_build_maze()
	_build_player()
	_build_goal()
	_build_sigils()
	_build_devil()
	_build_hud()
	_apply_world(WAKE)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_update_flashlight(delta)
	for sigil in sigil_nodes:
		sigil.rotate_y(delta * 1.5)
	_animate_devil(delta)
	if game_state != "playing":
		return
	elapsed += delta
	catch_grace = maxf(catch_grace - delta, 0.0)
	enrage_left = maxf(enrage_left - delta, 0.0)
	flip.advance(delta, _spot_open(WAKE), _spot_open(NIGHTMARE))
	_strobe_lights(flip.warning_active)
	devil_timer += delta
	if devil_timer >= _devil_step_interval():
		devil_timer = 0.0
		_step_devil()
	_collect_sigils()
	_update_hud()
	_refresh_minimap()
	_update_devil_audio()
	if exit_open and player_cell == layout.exit:
		_win_game()
	elif world == NIGHTMARE and catch_grace <= 0.0 and devil_cell == player_cell:
		_lose_game()

func _physics_process(delta: float) -> void:
	if player == null or game_state != "playing" or get_tree().paused:
		return
	var look_input := Input.get_vector("look_left", "look_right", "look_up", "look_down", feel.stick_deadzone)
	if look_input != Vector2.ZERO:
		_apply_look(-look_input.x * feel.stick_look_speed * delta, -look_input.y * feel.stick_look_speed * delta)
	var move_input := _move_input()
	var direction := player.transform.basis * Vector3(move_input.x, 0.0, move_input.y)
	var sprinting := Input.is_action_pressed("sprint") and move_input != Vector2.ZERO
	var target_speed := feel.walk_speed * (feel.sprint_multiplier if sprinting else 1.0)
	var horizontal_velocity := Vector3(player.velocity.x, 0.0, player.velocity.z)
	var rate := feel.acceleration if move_input != Vector2.ZERO else feel.friction
	if not player.is_on_floor():
		rate *= feel.air_control
	horizontal_velocity = horizontal_velocity.move_toward(direction * target_speed, rate * delta)
	player.velocity.x = horizontal_velocity.x
	player.velocity.z = horizontal_velocity.z

	if player.is_on_floor():
		if player.velocity.y < 0.0:
			player.velocity.y = -0.5
	else:
		player.velocity.y -= GRAVITY * delta
	player.move_and_slide()
	_update_player_cell()
	# Real velocity: walking into a wall produces no steps and no bob.
	var real_velocity := player.get_real_velocity()
	var h_speed := Vector2(real_velocity.x, real_velocity.z).length()
	_update_head_bob(h_speed, sprinting, delta)
	if player_rig != null:
		player_mesh.position.y = PLAYER_MESH_Y + player_rig.animate(h_speed, delta)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().paused = false
		_restart_game()
		return
	if game_state != "playing":
		return
	if event.is_action_pressed("pause"):
		_toggle_pause()
		return
	if get_tree().paused:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_apply_look(-motion.relative.x * feel.mouse_sensitivity, -motion.relative.y * feel.mouse_sensitivity)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("flashlight"):
		flashlight_on = not flashlight_on
		flashlight.visible = flashlight_on
	elif event.is_action_pressed("flip"):
		flip.request_flip(_spot_open(1 - world))

## Flipping Time inverts movement (the 2D FearFlip rule): W goes back, A goes right, and so on.
func _move_input() -> Vector2:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back", feel.stick_deadzone)
	return -input if flip.forced_active else input

func _apply_look(yaw_delta: float, pitch_delta: float) -> void:
	yaw += yaw_delta
	pitch = clampf(pitch + pitch_delta, -feel.max_pitch, feel.max_pitch)
	player.rotation.y = yaw
	camera_pivot.rotation.x = pitch

func _toggle_pause() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
	_show_message("PAUSED  (Esc to resume, R to restart)" if paused else "")

func _update_head_bob(h_speed: float, sprinting: bool, delta: float) -> void:
	var on_floor := player.is_on_floor()
	var old_phase := step_phase
	step_phase = feel.advance_step_phase(step_phase, h_speed, delta, on_floor)
	if PlayerFeel.crossed_step(old_phase, step_phase) or (on_floor and not was_on_floor):
		_play_footstep(sprinting)
	was_on_floor = on_floor
	var target_intensity := clampf(h_speed / feel.walk_speed, 0.0, 1.5) if on_floor else 0.0
	bob_intensity = lerpf(bob_intensity, target_intensity, clampf(feel.bob_blend_speed * delta, 0.0, 1.0))
	camera.position = feel.bob_offset(step_phase, bob_intensity)
	var running := sprinting and h_speed > feel.walk_speed * 1.05
	breath_time += delta * (feel.sprint_breath_rate if running else feel.breath_rate)
	var target_fov := feel.base_fov + sin(breath_time * TAU) * feel.breath_fov_amplitude
	if running:
		target_fov += feel.sprint_fov_boost
	camera.fov = lerpf(camera.fov, target_fov, clampf(feel.fov_blend_speed * delta, 0.0, 1.0))

func _play_footstep(sprinting: bool) -> void:
	if footstep_player == null:
		return
	footstep_player.volume_db = feel.footstep_volume_db + (feel.sprint_footstep_boost_db if sprinting else 0.0)
	footstep_player.play()

func _update_flashlight(delta: float) -> void:
	if flashlight == null or not flashlight_on:
		return
	flicker_timer -= delta
	if flicker_timer <= 0.0:
		var interval := rng.randf_range(0.05, 0.2)
		flicker_timer = interval
		flicker_target = rng.randf_range(-1.0, 1.0) * feel.flicker_strength
		if stutter_left <= 0.0 and rng.randf() < feel.stutter_chance * interval:
			stutter_left = feel.stutter_duration
	flicker_value = lerpf(flicker_value, flicker_target, clampf(12.0 * delta, 0.0, 1.0))
	var energy := feel.flashlight_energy * (1.0 + flicker_value)
	if stutter_left > 0.0:
		stutter_left -= delta
		energy *= feel.stutter_energy_ratio
	flashlight.light_energy = energy

func _build_footstep_stream() -> AudioStreamRandomizer:
	var randomizer := AudioStreamRandomizer.new()
	randomizer.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
	randomizer.random_pitch = 1.08
	randomizer.random_volume_offset_db = 1.5
	for path in FOOTSTEP_PATHS:
		randomizer.add_stream(-1, load(path) as AudioStream)
	return randomizer

# --- World Flip -------------------------------------------------------------

## True if the player's capsule footprint is open in `target_world` (a flip would not land in a wall).
func _spot_open(target_world: int) -> bool:
	var center := player.global_position
	for offset in [Vector3(-PLAYER_RADIUS, 0, -PLAYER_RADIUS), Vector3(PLAYER_RADIUS, 0, -PLAYER_RADIUS), Vector3(-PLAYER_RADIUS, 0, PLAYER_RADIUS), Vector3(PLAYER_RADIUS, 0, PLAYER_RADIUS)]:
		if not layout.is_open(target_world, world_to_cell(center + offset)):
			return false
	return true

func _on_flipped(new_world: int, forced: bool) -> void:
	_apply_world(new_world)
	flip_player.play()
	warning_label.visible = false
	var tween := create_tween().set_parallel()
	camera.rotation.z = 0.0
	tween.tween_property(camera, "rotation:z", TAU, FLIP_ROLL_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flash_rect.color = Color(SIGIL_COLORS[new_world], 0.6)
	tween.tween_property(flash_rect, "color:a", 0.0, 0.3)
	tween.chain().tween_callback(func() -> void: camera.rotation.z = 0.0)
	if new_world == NIGHTMARE:
		catch_grace = FLIP_CATCH_GRACE
		if forced:
			_keep_devil_fair()
	else:
		devil_target = player_cell

func _on_flip_denied() -> void:
	deny_player.play()
	var tween := create_tween()
	tween.tween_property(camera, "h_offset", 0.05, 0.04)
	tween.tween_property(camera, "h_offset", -0.05, 0.08)
	tween.tween_property(camera, "h_offset", 0.0, 0.04)

func _on_flipping_time_warning() -> void:
	warning_player.play()
	warning_label.visible = true

## Swap everything that differs between worlds. Called on every flip and once at start.
func _apply_world(new_world: int) -> void:
	world = new_world
	var nightmare := world == NIGHTMARE
	player.collision_mask = LAYER_SHARED | (LAYER_NIGHTMARE if nightmare else LAYER_WAKE)
	wake_walls.visible = not nightmare
	nightmare_walls.visible = nightmare
	env.fog_light_color = FOG_COLORS[world]
	env.fog_density = FOG_DENSITIES[world]
	env.ambient_light_color = AMBIENT_COLORS[world]
	trim_material.emission = GLOW_COLORS[world] * 0.3
	light_material.emission = GLOW_COLORS[world]
	accent_material.emission = GLOW_COLORS[world] * 0.2
	for light in world_lights:
		light.light_color = GLOW_COLORS[world]
	devil.visible = nightmare
	for i in sigil_nodes.size():
		sigil_nodes[i].visible = not sigil_collected[i] and layout.sigil_worlds[i] == world
	var tween := create_tween().set_parallel()
	tween.tween_property(calm_player, "volume_db", -60.0 if nightmare else MUSIC_DB, 0.6)
	tween.tween_property(intense_player, "volume_db", MUSIC_DB if nightmare else -60.0, 0.6)
	status_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4) if nightmare else Color(0.65, 0.95, 1.0))
	_refresh_minimap()

## Flipping Time warning: ceiling lights stutter.
func _strobe_lights(on: bool) -> void:
	var energy := world_light_energy * (0.25 if on and fmod(elapsed, 0.25) < 0.12 else 1.0)
	for light in world_lights:
		light.light_energy = energy

func _keep_devil_fair() -> void:
	var dist := layout.distances(NIGHTMARE, player_cell)
	var devil_dist := dist[devil_cell.y * layout.size + devil_cell.x]
	if devil_dist < 0 or devil_dist >= FAIR_FLIP_DISTANCE:
		return
	var options: Array[Vector2i] = []
	for i in dist.size():
		if dist[i] >= DEVIL_RETREAT_DISTANCE:
			options.append(layout.cell_at(i))
	if options.is_empty():
		return
	devil_cell = options[rng.randi_range(0, options.size() - 1)]
	devil.position = _devil_world_position()

# --- Sigils, exit, Devil ----------------------------------------------------

func _collect_sigils() -> void:
	for i in layout.sigils.size():
		if sigil_collected[i] or layout.sigil_worlds[i] != world or layout.sigils[i] != player_cell:
			continue
		sigil_collected[i] = true
		sigil_nodes[i].visible = false
		sigils_collected += 1
		sigil_player.play()
		if sigils_collected == FloorLayout.SIGIL_COUNT:
			_open_exit()
		_refresh_minimap()

func _open_exit() -> void:
	exit_open = true
	enrage_left = DEVIL_ENRAGE_DURATION
	_set_exit_look()
	_show_message("THE EXIT IS OPEN — RUN")
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if game_state == "playing":
			_show_message(""))

func _devil_step_interval() -> float:
	return CELL_SIZE / (DEVIL_CHASE_SPEED * (DEVIL_ENRAGE_MULTIPLIER if enrage_left > 0.0 else 1.0))

func _devil_world_position() -> Vector3:
	return cell_to_world(devil_cell) + Vector3(0, DEVIL_Y, 0)

## Glide toward the Devil's grid cell, face the way it runs, and drive the run cycle from real speed.
func _animate_devil(delta: float) -> void:
	var next := devil.position.move_toward(_devil_world_position(), CELL_SIZE / _devil_step_interval() * delta)
	var moved := next - devil.position
	devil.position = next
	if moved.length_squared() > 0.000001:
		devil.rotation.y = lerp_angle(devil.rotation.y, atan2(moved.x, moved.z), clampf(DEVIL_TURN_SPEED * delta, 0.0, 1.0))
	var speed := moved.length() / delta if delta > 0.0 else 0.0
	devil_mesh.position.y = -DEVIL_Y + devil_rig.animate(speed, delta)

func _step_devil() -> void:
	# ponytail: omniscient in NIGHTMARE, waits where you vanished in WAKE. Senses + Director (§7) replace this.
	if world == NIGHTMARE:
		devil_target = player_cell
	devil_cell = layout.next_step(NIGHTMARE, devil_cell, devil_target)

# --- Build ------------------------------------------------------------------

func _build_environment() -> void:
	var environment := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.003, 0.005, 0.01)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.fog_enabled = true
	environment.environment = env
	add_child(environment)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-55, -25, 0)
	moon.light_color = Color(0.25, 0.35, 0.55)
	moon.light_energy = 0.25
	add_child(moon)

func _build_audio() -> void:
	calm_player = _audio("CalmLoop", "res://assets/audio/calm_loop.mp3", MUSIC_DB)
	intense_player = _audio("IntenseLoop", "res://assets/audio/intense_loop.mp3", -60.0)
	for music in [calm_player, intense_player]:
		(music.stream as AudioStreamMP3).loop = true
		music.play()
	win_player = _audio("WinSfx", "res://assets/audio/winning_soundeffect.mp3", -4.0)
	lose_player = _audio("LoseSfx", "res://assets/audio/gamelost_soundeffect.mp3", -4.0)
	flip_player = _audio("FlipSfx", "res://assets/audio/maze_shift_audio.mp3", -6.0)
	deny_player = _audio("FlipDenied", "res://assets/audio/glitch_screen_sound_effect.mp3", -8.0)
	warning_player = _audio("FlippingTimeWarning", "res://assets/audio/fahhhhh_flippingtime.mp3", -4.0)
	sigil_player = _audio("SigilSfx", "res://assets/audio/safe_zone_sound.mp3", -6.0)
	devil_approach_player = _audio("DevilApproach", "res://assets/audio/devil_approach.wav", -10.0)

func _audio(node_name: String, path: String, volume_db: float) -> AudioStreamPlayer:
	var audio := AudioStreamPlayer.new()
	audio.name = node_name
	audio.stream = load(path)
	audio.volume_db = volume_db
	add_child(audio)
	return audio

func _build_maze() -> void:
	var span := layout.size * CELL_SIZE
	var center := Vector3((layout.size - 1) * CELL_SIZE * 0.5, 0, (layout.size - 1) * CELL_SIZE * 0.5)
	var floor_body := StaticBody3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(span, 0.15, span)
	floor_body.position = center + Vector3(0, -0.08, 0)
	var floor := MeshInstance3D.new()
	floor.mesh = floor_mesh
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.025, 0.035, 0.05)
	floor_material.roughness = 0.9
	floor.material_override = floor_material
	floor_body.add_child(floor)
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = floor_mesh.size
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	add_child(floor_body)

	var ceiling := MeshInstance3D.new()
	var ceiling_mesh := BoxMesh.new()
	ceiling_mesh.size = Vector3(span, 0.18, span)
	ceiling.mesh = ceiling_mesh
	ceiling.position = center + Vector3(0, CEILING_HEIGHT, 0)
	var ceiling_material := StandardMaterial3D.new()
	ceiling_material.albedo_color = Color(0.008, 0.012, 0.02)
	ceiling_material.roughness = 1.0
	ceiling.material_override = ceiling_material
	add_child(ceiling)

	trim_material = _trim_material()
	light_material = _light_material()
	accent_material = _floor_accent_material()
	var shared: Array[Vector2i] = []
	var wake_only: Array[Vector2i] = []
	var nightmare_only: Array[Vector2i] = []
	var light_cells: Array[Vector2i] = []
	var accent_cells: Array[Vector2i] = []
	for y in layout.size:
		for x in layout.size:
			var cell := Vector2i(x, y)
			var wake_wall := not layout.is_open(WAKE, cell)
			var nightmare_wall := not layout.is_open(NIGHTMARE, cell)
			if wake_wall and nightmare_wall:
				shared.append(cell)
			elif wake_wall:
				wake_only.append(cell)
			elif nightmare_wall:
				nightmare_only.append(cell)
			else:
				if (x + y) % world_light_spacing == 0:
					light_cells.append(cell)
				if (x + y) % 2 == 0:
					accent_cells.append(cell)
	_build_wall_set("SharedWalls", shared, LAYER_SHARED)
	wake_walls = _build_wall_set("WakeWalls", wake_only, LAYER_WAKE)
	nightmare_walls = _build_wall_set("NightmareWalls", nightmare_only, LAYER_NIGHTMARE)

	var fixture_mesh := BoxMesh.new()
	fixture_mesh.size = Vector3(0.5, 0.05, 0.5)
	add_child(_multimesh(fixture_mesh, light_material, light_cells, CEILING_HEIGHT - 0.12))
	for cell in light_cells:
		var light := OmniLight3D.new()
		light.light_energy = world_light_energy
		light.omni_range = 4.5
		light.shadow_enabled = world_light_shadows
		light.position = cell_to_world(cell) + Vector3(0, CEILING_HEIGHT - 0.12, 0)
		add_child(light)
		world_lights.append(light)

	var accent_mesh := BoxMesh.new()
	accent_mesh.size = Vector3(CELL_SIZE * 0.72, 0.012, 0.04)
	add_child(_multimesh(accent_mesh, accent_material, accent_cells, 0.015))

## One world's walls: one static body (shared box shape per cell) + 3 multimeshes = 3 draw calls.
func _build_wall_set(set_name: String, cells: Array[Vector2i], layer: int) -> Node3D:
	var body := StaticBody3D.new()
	body.name = set_name
	body.collision_layer = layer
	body.collision_mask = 0
	add_child(body)
	var shape := BoxShape3D.new()
	shape.size = Vector3(CELL_SIZE, WALL_HEIGHT, CELL_SIZE)
	for cell in cells:
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = cell_to_world(cell) + Vector3(0, WALL_HEIGHT * 0.5, 0)
		body.add_child(collision)
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = shape.size
	var top_mesh := BoxMesh.new()
	top_mesh.size = Vector3(CELL_SIZE + 0.03, WALL_TRIM_HEIGHT, CELL_SIZE + 0.03)
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(CELL_SIZE + 0.04, 0.08, CELL_SIZE + 0.04)
	body.add_child(_multimesh(wall_mesh, _wall_material(), cells, WALL_HEIGHT * 0.5))
	body.add_child(_multimesh(top_mesh, trim_material, cells, WALL_HEIGHT - WALL_TRIM_HEIGHT * 0.5))
	body.add_child(_multimesh(base_mesh, trim_material, cells, 0.04))
	return body

func _multimesh(mesh: Mesh, material: Material, cells: Array[Vector2i], height: float) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = cells.size()
	for i in cells.size():
		multimesh.set_instance_transform(i, Transform3D(Basis(), cell_to_world(cells[i]) + Vector3(0, height, 0)))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = material
	return instance

func _wall_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.038, 0.055, 0.08)
	material.metallic = 0.18
	material.roughness = 0.82
	return material

func _trim_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.08, 0.2, 0.28)
	material.emission_enabled = true
	material.emission_energy_multiplier = 1.5
	material.metallic = 0.4
	material.roughness = 0.4
	return material

func _light_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.65, 1.0)
	material.emission_enabled = true
	material.emission_energy_multiplier = 4.0
	return material

func _floor_accent_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.05, 0.18, 0.24)
	material.emission_enabled = true
	material.emission_energy_multiplier = 1.2
	return material

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = cell_to_world(player_cell) + Vector3(0, PLAYER_HEIGHT, 0)
	player.floor_snap_length = 0.2
	add_child(player)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = PLAYER_RADIUS
	capsule.height = 1.6
	collision.shape = capsule
	collision.position.y = -0.8
	player.add_child(collision)

	player_mesh = PLAYER_MODEL.instantiate()
	player_mesh.name = "CharacterMesh"
	player_mesh.position.y = PLAYER_MESH_Y
	# character2withrig.glb faces +X and is ~1 m tall; turn it to face -Z and scale to body height.
	player_mesh.rotation_degrees.y = 90.0
	player_mesh.scale = Vector3.ONE * PLAYER_MESH_SCALE
	player.add_child(player_mesh)
	player_rig = DevilRig.new(player_mesh, false)

	camera_pivot = Node3D.new()
	camera_pivot.position.y = 0.45
	player.add_child(camera_pivot)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = feel.base_fov
	camera_pivot.add_child(camera)
	flashlight = SpotLight3D.new()
	flashlight.name = "Flashlight"
	flashlight.light_color = Color(0.68, 0.82, 1.0)
	flashlight.light_energy = feel.flashlight_energy
	flashlight.spot_range = feel.flashlight_range
	flashlight.spot_angle = feel.flashlight_angle
	flashlight.shadow_enabled = true
	camera.add_child(flashlight)

	footstep_player = AudioStreamPlayer3D.new()
	footstep_player.name = "Footsteps"
	footstep_player.stream = _build_footstep_stream()
	footstep_player.position = Vector3(0, -1.5, 0)
	footstep_player.unit_size = 4.0
	footstep_player.max_polyphony = 2
	player.add_child(footstep_player)

func _build_goal() -> void:
	goal = Node3D.new()
	goal.name = "ExitPortal"
	goal.position = cell_to_world(layout.exit)
	add_child(goal)

	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.72
	base_mesh.bottom_radius = 0.72
	base_mesh.height = 0.08
	base.mesh = base_mesh
	base.position.y = 0.06
	goal.add_child(base)

	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.48
	ring_mesh.outer_radius = 0.58
	ring_mesh.rings = 32
	ring_mesh.ring_segments = 12
	ring.mesh = ring_mesh
	ring.position.y = 1.0
	ring.rotation_degrees.x = 90
	goal.add_child(ring)

	goal_material = StandardMaterial3D.new()
	goal_material.emission_enabled = true
	goal_material.emission_energy_multiplier = 3.0
	base.material_override = goal_material
	ring.material_override = goal_material

	var beam := MeshInstance3D.new()
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.06
	beam_mesh.bottom_radius = 0.06
	beam_mesh.height = 2.0
	beam.mesh = beam_mesh
	beam.position.y = 1.0
	beam.material_override = goal_material
	goal.add_child(beam)

	var portal_texture := load("res://assets/images/exit_portal.png") as Texture2D
	if portal_texture != null:
		var portal_sprite := Sprite3D.new()
		portal_sprite.texture = portal_texture
		portal_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		portal_sprite.pixel_size = 0.004
		portal_sprite.position = Vector3(0, 1.0, 0)
		goal.add_child(portal_sprite)

	goal_light = OmniLight3D.new()
	goal_light.omni_range = 4.0
	goal.add_child(goal_light)
	_set_exit_look()

## Locked: dim and red. Open (3 sigils): bright green.
func _set_exit_look() -> void:
	var color := Color(0.1, 1.0, 0.45) if exit_open else Color(0.35, 0.05, 0.08)
	goal_material.albedo_color = color
	goal_material.emission = color * (0.65 if exit_open else 0.3)
	goal_light.light_color = color
	goal_light.light_energy = 2.5 if exit_open else 0.6

func _build_sigils() -> void:
	var materials: Array[StandardMaterial3D] = []
	for color in SIGIL_COLORS:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 3.0
		materials.append(material)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.3, 0.3, 0.3)
	for i in layout.sigils.size():
		var sigil_world := layout.sigil_worlds[i]
		var sigil := Node3D.new()
		sigil.name = "Sigil%d" % i
		sigil.position = cell_to_world(layout.sigils[i]) + Vector3(0, 1.1, 0)
		var gem := MeshInstance3D.new()
		gem.mesh = mesh
		gem.rotation_degrees = Vector3(45, 0, 45)
		gem.material_override = materials[sigil_world]
		sigil.add_child(gem)
		var light := OmniLight3D.new()
		light.light_color = SIGIL_COLORS[sigil_world]
		light.light_energy = 1.2
		light.omni_range = 3.0
		sigil.add_child(light)
		add_child(sigil)
		sigil_nodes.append(sigil)
		sigil_collected.append(false)

func _build_devil() -> void:
	devil = Node3D.new()
	devil.name = "Devil"
	devil.position = _devil_world_position()
	add_child(devil)

	devil_mesh = DEVIL_MODEL.instantiate()
	devil_mesh.name = "DevilMesh"
	devil_mesh.position = Vector3(0, -DEVIL_Y, 0)
	devil.add_child(devil_mesh)
	devil_rig = DevilRig.new(devil_mesh)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.02, 0.02)
	light.light_energy = 1.2
	light.omni_range = 3.0
	devil.add_child(light)

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)
	minimap = preload("res://scripts/minimap.gd").new()
	minimap.name = "Minimap"
	minimap.layout = layout
	minimap.sigil_collected = sigil_collected
	hud.add_child(minimap)

	status_label = _hud_label(hud, "Status", 22, Control.PRESET_TOP_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT)
	status_label.offset_left = -360
	status_label.offset_right = -24
	status_label.offset_top = 20

	state_label = _hud_label(hud, "Message", 30, Control.PRESET_CENTER_TOP, HORIZONTAL_ALIGNMENT_CENTER)
	state_label.offset_left = -560
	state_label.offset_right = 560
	state_label.offset_top = 90
	state_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))

	warning_label = _hud_label(hud, "FlippingTime", 44, Control.PRESET_CENTER, HORIZONTAL_ALIGNMENT_CENTER)
	warning_label.offset_left = -400
	warning_label.offset_right = 400
	warning_label.offset_top = -120
	warning_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.15))
	warning_label.visible = false

	var hint := _hud_label(hud, "Hint", 16, Control.PRESET_BOTTOM_WIDE, HORIZONTAL_ALIGNMENT_LEFT)
	hint.offset_left = 24
	hint.offset_top = -34
	hint.text = "WASD  MOVE     SHIFT  SPRINT     SPACE / E  FLIP     F  FLASHLIGHT     ESC  PAUSE     R  RESTART"
	hint.add_theme_color_override("font_color", Color(0.55, 0.7, 0.82, 0.8))

	flash_rect = ColorRect.new()
	flash_rect.name = "FlipFlash"
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1, 1, 1, 0)
	hud.add_child(flash_rect)

func _hud_label(hud: CanvasLayer, node_name: String, font_size: int, preset: Control.LayoutPreset, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.name = node_name
	label.set_anchors_preset(preset)
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	hud.add_child(label)
	return label

func _format_time(seconds: float) -> String:
	var total := int(seconds)
	@warning_ignore("integer_division")
	return "%d:%02d" % [total / 60, total % 60]

func _update_hud() -> void:
	var flip_line := "FLIP READY  [SPACE]"
	if flip.forced_active:
		flip_line = "CONTROLS INVERTED  %ds" % ceili(maxf(flip.forced_left, 0.0))
	elif flip.cooldown_left > 0.0:
		flip_line = "FLIP  %.1fs" % flip.cooldown_left
	var goal_line := "EXIT OPEN" if exit_open else "SIGILS  %d / %d" % [sigils_collected, FloorLayout.SIGIL_COUNT]
	status_label.text = "%s   %s\n%s\n%s" % [WORLD_NAMES[world], _format_time(elapsed), goal_line, flip_line]
	if warning_label.visible:
		warning_label.text = "FLIPPING TIME  %d
CONTROLS WILL INVERT" % maxi(ceili(flip.next_forced_in), 0)
		warning_label.modulate.a = 0.55 + 0.45 * sin(elapsed * 18.0)

func _update_devil_audio() -> void:
	var should_play := world == NIGHTMARE and _manhattan(devil_cell, player_cell) <= DEVIL_NEAR_DISTANCE
	if should_play and not devil_approach_playing:
		devil_approach_player.play()
		devil_approach_playing = true
	elif not should_play and devil_approach_playing:
		devil_approach_player.stop()
		devil_approach_playing = false

func _win_game() -> void:
	if game_state == "won":
		return
	game_state = "won"
	win_player.play()
	devil_approach_player.stop()
	warning_label.visible = false
	_show_message("ESCAPED IN %s   (R for a new floor)" % _format_time(elapsed))

## The death screen teaches the rule and shows how close you were (§5).
func _lose_game() -> void:
	if game_state == "lost":
		return
	game_state = "lost"
	lose_player.play()
	devil_approach_player.stop()
	warning_label.visible = false
	var steps := layout.distances(world, layout.exit)[player_cell.y * layout.size + player_cell.x]
	var near := "  You were %d m from the exit." % roundi(steps * CELL_SIZE) if steps > 0 else ""
	_show_message("THE DEVIL GOT YOU.%s\nIt only hunts in NIGHTMARE: sprint, use loops, or flip to WAKE.   (R to retry)" % near)

func _restart_game() -> void:
	get_tree().reload_current_scene()

func _update_player_cell() -> void:
	var candidate := world_to_cell(player.global_position)
	if candidate != player_cell and layout.is_open(world, candidate):
		player_cell = candidate

## Push live positions to the minimap (grid cells, floats). Devil distance = NIGHTMARE path length.
func _refresh_minimap() -> void:
	if minimap == null:
		return
	minimap.world = world
	minimap.exit_open = exit_open
	minimap.player_pos = Vector2(player.global_position.x, player.global_position.z) / CELL_SIZE
	minimap.devil_pos = Vector2(devil.position.x, devil.position.z) / CELL_SIZE
	var forward := -player.global_transform.basis.z
	minimap.facing = Vector2(forward.x, forward.z).angle()
	var steps := layout.distances(NIGHTMARE, devil_cell)[player_cell.y * layout.size + player_cell.x]
	minimap.devil_distance = steps * CELL_SIZE if steps >= 0 else -1.0
	var to_exit := layout.distances(world, layout.exit)[player_cell.y * layout.size + player_cell.x]
	minimap.exit_distance = to_exit * CELL_SIZE if to_exit >= 0 else -1.0

func _show_message(text: String) -> void:
	if state_label == null:
		return
	state_label.text = text

func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * CELL_SIZE, 0, cell.y * CELL_SIZE)

func world_to_cell(position: Vector3) -> Vector2i:
	return Vector2i(round(position.x / CELL_SIZE), round(position.z / CELL_SIZE))

func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)
