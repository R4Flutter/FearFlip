extends Node3D
## One FearFlip floor of the Descent: a seeded maze that exists in WAKE and NIGHTMARE (FloorLayout),
## World Flip + Flipping Time (FlipSystem, inverts controls), 3 sigils open the exit, and the Devil
## (DevilBrain) hunts in both worlds (slower in WAKE). plans/05 adds the floor curve + clock (StageRule, RunState),
## safe circles, cracked floors and the death screen. Grid is truth; 3D is the projection.

const CELL_SIZE := 2.4
const WALL_HEIGHT := 2.8
const PLAYER_HEIGHT := 1.7
const PLAYER_RADIUS := 0.35
const GRAVITY := 18.0
const CEILING_HEIGHT := 3.0
const WALL_TRIM_HEIGHT := 0.12
const DEVIL_NEAR_DISTANCE := 3
const DEVIL_Y := 0.75
## Player body: feet at the capsule bottom. Model heights are fractions of WALL_HEIGHT (wall = 1).
const PLAYER_MESH_Y := -1.6
const PLAYER_HEIGHT_RATIO := 0.6
const DEVIL_HEIGHT_RATIO := 0.9
const DEVIL_ENRAGE_MULTIPLIER := 1.2
const DEVIL_ENRAGE_DURATION := 20.0
## A forced flip never drops you closer than this (path cells) to the Devil; it is moved first.
const FAIR_FLIP_DISTANCE := 4
const DEVIL_RETREAT_DISTANCE := 8
## No grab for this long after a flip: no instant catches.
const FLIP_CATCH_GRACE := 0.6
## How fast the Devil turns to face where it runs (higher = snappier).
const DEVIL_TURN_SPEED := 10.0
const FLIP_ROLL_TIME := 0.35
## A cell change only counts once you're this far (m) past the tile edge: grazing a corner is no step.
const STEP_HYSTERESIS := 0.3
## A catch is a visible lunge: it starts on a cell catch and only kills if it ends this close (m).
const LUNGE_TIME := 0.35
const LUNGE_RANGE := 1.3
const LUNGE_SPEED := 7.0
const LUNGE_MISS_STUN := 0.6
## Close Call / Phase Dodge (plans/06 C2): a near miss pays, time slows for a beat and the heart jumps.
const CLOSE_CALL_TIME_SCALE := 0.35
const CLOSE_CALL_SLOWMO := 0.3
const CLOSE_CALL_HEART_PITCH := 1.5
const CLOSE_CALL_HEART_TIME := 1.5
## Your own flip with the Devil this close (path tiles), or mid-lunge, is a Phase Dodge.
const PHASE_DODGE_TILES := 1
## Camera Flash (Altar torch, plans/06 P5): it freezes the Devil this long when it's this close (path tiles) and in sight.
const FLASH_STUN_TIME := 3.0
const FLASH_STUN_TILES := 6
## An act's ending (Lore) the first time its Gate falls; the art is optional (prompt in assets/images/menu/PROMPTS.md).
const ENDING_ART := "res://assets/images/menu/ending_bg.png"
const ENDING_WIDTH := 720.0
## Fear Shards on the HUD: a counter under the keys; every "+3" pops in a line below it (stacking when
## several land at once), drifts up and fades.
const SHARD_COLOR := Color(0.78, 0.62, 1.0)
const SHARD_POP_GAP := 32.0
const SHARD_POP_RISE := 10.0
const SHARD_POP_TIME := 0.9
## The Devil wakes this long after its telegraph (a distant slam).
const SPAWN_TELEGRAPH := 1.5
## Path tiles it backs off to while you stand in a safe circle.
const CIRCLE_RETREAT_DISTANCE := 10
const REVIVE_GRACE := 3.0
const REVIVE_MIN_TIME := 30.0
const PANIC_TIME := 10.0
const FLOOR_CLEAR_TIME := 1.4
## Beating the Gate: time to read "ACT CLEARED" before the menu.
const ACT_CLEAR_TIME := 3.0
## Mid-floor, R costs the whole run (and sits next to the flip key), so a second press must follow this fast.
const RESTART_ARM_TIME := 2.5
const PAUSE_TEXT := "PAUSED  (Esc to resume, R twice to restart the act)"
## Optional art (plans/06 P1 prompts in assets/images/menu/PROMPTS.md); without it the words stand alone.
const ACT_CLEARED_ART := "res://assets/images/menu/act_cleared_burst.png"
const GOLD := Color(1.0, 0.78, 0.3)
const OMEN_COLOR := Color(0.75, 0.6, 1.0, 0.9)
## One line of the 22 px status label (measured), for laying out what sits under it.
const STATUS_LINE := 34.0
const PICK_TITLES := {
	"curse": "TEMPT A CURSE?  ·  MORE SHARDS ON EVERY FLOOR OF THIS RUN",
	"omen": "CHOOSE AN OMEN  ·  YOURS FOR THE REST OF THE RUN",
	"gate": "RETURN WITH YOUR SHARDS, OR DESCEND?",
}
## Trap fall: a jolt, a beat of "oh no", then down the shaft (seconds / metres).
const FALL_BEAT := 0.2
const FALL_TIME := 1.4
const FALL_DEPTH := 7.0
## The camera lets go of you and stays at the rim: this far back toward where you came from, this high.
const FALL_CAM_BACK := 1.25
const FALL_CAM_HEIGHT := 2.7
const FALL_CAM_MOVE := 0.45
## Falling body: turns back toward the camera and tips over backwards (radians).
const FALL_TIP := 1.1
const FALL_FOV_ZOOM := -16.0
const FALL_END := 2.3
## Held camera roll while controls are inverted: a constant "something is wrong" cue.
const INVERT_TILT_DEGREES := 6.0
## Keys float this high (m). At the chest you stop this far from it (m) to watch it open.
const KEY_HEIGHT := 1.2
const CHEST_VIEW_DISTANCE := 1.5
const HEARTBEAT_TILES := 8

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
## How solid the other world's walls look with the Ghost Sight omen.
const GHOST_ALPHA := 0.14
const AMBIENT_COLORS: Array[Color] = [Color(0.025, 0.04, 0.07), Color(0.09, 0.01, 0.015)]
const GLOW_COLORS: Array[Color] = [Color(0.12, 0.32, 0.55), Color(0.65, 0.05, 0.03)]
const SIGIL_COLORS: Array[Color] = [Color(0.55, 0.9, 1.0), Color(1.0, 0.35, 0.1)]
const MUSIC_DB := -14.0
## Deaf Night's card turns the music down to this.
const SILENT_DB := -80.0
## Per-act look (plans/06 A5): each act turns WAKE's cold light and the walls to its own hue (-1 keeps
## the original), Act 5 drains them to ash; NIGHTMARE stays red, so a flip always reads.
const ACT_HUES: Array[float] = [-1.0, 0.42, 0.76, 0.09, -1.0]
const ACT_SATURATION: Array[float] = [1.0, 1.0, 1.0, 1.0, 0.15]
## Light on a chest waiting down a dead end, so it can be found in the dark.
const DETOUR_CHEST_GLOW := 0.8

const PLAYER_MODEL = preload("res://assets/character/character2withrig.glb")
const DEVIL_MODEL = preload("res://assets/character/skleton_added_devil.glb")
const FOOTSTEP_PATHS: Array[String] = [
	"res://assets/audio/sfx_footstep_1.mp3",
	"res://assets/audio/sfx_footstep_2.mp3",
	"res://assets/audio/sfx_footstep_3.mp3",
]

## Movement, look, head-bob, FOV, flashlight and footstep tunables (res://resources/player_feel.tres).
@export var feel: PlayerFeel

@export_group("Floor")
## 0 = new random floor each run. Set a seed to replay or debug one floor.
@export var fixed_seed: int = 0
## Rooms per side; the maze is (2 * rooms + 1) tiles square. 0 = from the floor's StageRule.
@export_range(0, 30) var rooms: int = 0
## Debug: also put a cracked floor on this tile of the route from spawn (3 = third tile). 0 = off.
## Skips the fairness check, so a sigil behind it can force a second crossing.
@export_range(0, 20) var debug_trap_step: int = 3

@export_group("World Lights")
## Ceiling light on every Nth open cell (by (x+y) % N). Higher = darker, cheaper.
@export_range(2, 8) var world_light_spacing: int = 4
@export_range(0.0, 2.0, 0.05) var world_light_energy: float = 0.4
## Off by default: only the flashlight casts shadows (mobile budget).
@export var world_light_shadows: bool = false

var layout: FloorLayout
var rule: StageRule
var flip: FlipSystem
var brain: DevilBrain
var circles: SafeCircles
var traps: TrapField
## Floor route spawn -> exit (flips allowed) and path distance from spawn; for placement and progress.
var route: Array[Vector2i] = []
var from_spawn := PackedInt32Array()
## Current-world path distance from the player (refreshed on each cell change).
var player_dist := PackedInt32Array()
## Path distance to the exit per world.
var exit_dist: Array[PackedInt32Array] = []
var visited := {}
var last_player_cell := Vector2i(1, 1)
var prev_devil_cell := Vector2i.ZERO
var devil_active := false
var devil_spawning := false
var devil_retreating := false
var steps_since_retreat := 0
var lunge_left := 0.0
var lunge_cooldown := 0.0
var time_left := 0.0
var panic := false
var seed_value := 0
## Metres of the key tour (spawn -> keys -> chest): the clock and the grade are both built on it.
var tour_m := 0.0
## Shards earned on this floor: banked (RunState.bank) at the chest, on death or on a restart.
var floor_shards := 0
## Chest finds (omen tokens, lore notes) on this floor: banked with its shards, never before.
var floor_finds: Array[String] = []
## Counters for the challenges and the bestiary (MetaState.record): banked with the floor, like its shards.
var floor_stats := {}
## You sprinted on this floor (Act 1's no-sprint challenge).
var sprinted := false
var floor_revives := 0
## Seconds with the Devil inside heartbeat range: being hunted costs a grade.
var chased_time := 0.0
var shard_label: Label
var live_pops := 0
## This floor's cards (plans/06 P3), folded once at build through RunState.mod() (_fold_cards).
var shard_factor := 1.0
var devil_enabled := true
var devil_speed := 1.0
var devil_delay := 0.0
var devil_distance := 0
var follow_flips := false
var mirror := false
var fog_factor := 1.0
var trap_cue := 1.0
var light_energy := 0.0
var music_db := MUSIC_DB
var rare_chest := false
var card_names := ""
## The run's omens (plans/06 P4), folded with the floor's cards.
var heartbeat_tiles := HEARTBEAT_TILES
var night_fog := 1.0
var ghost_sight := false
var ghost_material: StandardMaterial3D
## Catches the Last Breath omen still turns into a trip back to your last circle this floor.
var last_breath := 0
## The torch worn (Altar gear, folded like a card): the beam's shape, and Camera Flashes left this floor.
var beam_energy := 1.0
var beam_range := 1.0
var beam_angle := 1.0
var flash_stuns := 0
## The flip flash worn (Altar gear): its colour, or the world's you land in.
var flip_flash := ""
## Seconds the Devil stays frozen by a Camera Flash.
var devil_stun := 0.0
var omens_label: Label
## Chests down dead ends (Vault, Greed) by cell; each opens as you reach it.
var bonus_chests := {}
## This act's look: the per-world arrays with WAKE tinted (_act_tint).
var fog_colors: Array[Color] = []
var ambient_colors: Array[Color] = []
var glow_colors: Array[Color] = []
## Revive point: saved on entering a safe circle {cell, time_left, traps}.
var snapshot := {}
var circle_materials: Array[StandardMaterial3D] = []
var circle_lights: Array[OmniLight3D] = []
var trap_nodes: Array[TrapPit] = []
var floor_material: StandardMaterial3D
var death_screen: DeathScreen
var card_choice: CardChoice
var heartbeat_player: AudioStreamPlayer
var alarm_player: AudioStreamPlayer
var crack_player: AudioStreamPlayer
var fall_player: AudioStreamPlayer
var fall_time := -1.0
var creak_player: AudioStreamPlayer
var circle_player: AudioStreamPlayer
var telegraph_player: AudioStreamPlayer
var world: int = WAKE
var player: CharacterBody3D
var player_mesh: Node3D
var player_rig: DevilRig
var camera_pivot: Node3D
var devil: Node3D
var devil_mesh: Node3D
var devil_rig: DevilRig
var goal: Node3D
var chest: TreasureChest
var key_hud: KeyHud
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
var restart_armed := false

func _ready() -> void:
	if feel == null:
		feel = PlayerFeel.new()
	# Main keeps processing while paused so Esc can resume; gameplay loops check the pause flag.
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 1.0  # a reload can land mid Close Call
	rng.randomize()
	# A fixed seed is a debug floor: it never touches the save.
	if fixed_seed == 0:
		RunState.load_save()
		# A run that already ended (died, then quit) never resumes: its act starts over on a new maze.
		if RunState.run_over:
			RunState.start_run(RunState.act())
		if not RunState.picks.is_empty():
			_choose_before_floor()
			return
	rule = StageRule.for_floor(RunState.current_floor)
	seed_value = fixed_seed if fixed_seed != 0 else RunState.floor_seed()
	print("FearFlip floor %d seed: %d" % [rule.floor_number, seed_value])
	_fold_cards()
	layout = FloorLayout.generate(seed_value, rooms if rooms > 0 else roundi(RunState.mod("rooms", rule.rooms)),
			roundi(RunState.mod("keys", FloorLayout.SIGIL_COUNT)))
	flip = FlipSystem.new(seed_value)
	flip.first_forced_at = RunState.mod("flip_interval", rule.first_forced_at)
	flip.next_forced_in = flip.first_forced_at
	flip.forced_interval_min = RunState.mod("flip_interval", rule.forced_interval_min)
	flip.forced_interval_max = RunState.mod("flip_interval", rule.forced_interval_max)
	flip.min_forced_interval = RunState.mod("flip_interval", rule.min_forced_interval)
	flip.warning_time = rule.flip_warning
	flip.cooldown = RunState.mod("flip_cooldown", flip.cooldown)
	flip.charges = roundi(RunState.mod("flip_charges", 1.0))
	flip.charges_left = flip.charges
	flip.flipped.connect(_on_flipped)
	flip.flip_denied.connect(_on_flip_denied)
	flip.flipping_time_warning.connect(_on_flipping_time_warning)
	route = layout.route(layout.spawn, layout.exit)
	from_spawn = layout.distances(FloorLayout.ANY, layout.spawn)
	exit_dist = [layout.distances(WAKE, layout.exit), layout.distances(NIGHTMARE, layout.exit)]
	circles = SafeCircles.new()
	circles.capacity = RunState.mod("circle_time", rule.safe_circle_protect_s)
	circles.single_use = rule.safe_circle_single_use
	circles.place(route, roundi(RunState.mod("circles", rule.safe_circle_count)), func(cell: Vector2i) -> bool:
		return layout.is_open(WAKE, cell) and layout.is_open(NIGHTMARE, cell) and not layout.sigils.has(cell) and cell != layout.devil_spawn)
	traps = TrapField.new()
	var excluded: Array[Vector2i] = [layout.devil_spawn]
	excluded.append_array(layout.sigils)
	excluded.append_array(circles.cells)
	var trap_rng := RandomNumberGenerator.new()
	trap_rng.seed = seed_value
	traps.place(layout, route, roundi(RunState.mod("traps", rule.trap_count)), excluded, rule.dead_end_traps, trap_rng)
	traps.holds = roundi(RunState.mod("feather", 0.0))
	traps.creak_range = roundi(RunState.mod("creak_range", 1.0))
	if debug_trap_step > 0 and debug_trap_step < route.size() - 1 and not excluded.has(route[debug_trap_step]):
		traps.add(route[debug_trap_step])
	tour_m = _tour_tiles() * CELL_SIZE
	time_left = rule.time_budget(tour_m, feel.walk_speed, RunState.mod("clock", 1.0)) + RunState.mod("time_bonus", 0.0)
	brain = DevilBrain.new()
	player_cell = layout.spawn
	last_player_cell = player_cell
	visited[player_cell] = true
	brain.record(player_cell, true)
	devil_cell = layout.devil_spawn
	devil_target = devil_cell
	prev_devil_cell = devil_cell
	player_dist = layout.distances(world, player_cell)
	_build_environment()
	_build_audio()
	_build_maze()
	_build_player()
	_build_goal()
	_build_sigils()
	_build_circles()
	_build_traps()
	_build_detour_chests()
	_build_devil()
	_build_hud()
	_apply_world(WAKE)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_flash_message(_floor_title())
	if not RunState.floor_cards.is_empty():
		card_choice.flash("", RunState.floor_cards)
	if devil_enabled and RunState.mod("devil_awake", 0.0) > 0.0:
		_wake_devil()  # at its spawn: far away by construction (FloorLayout.MIN_DEVIL_DISTANCE)

## Read this floor's cards once (plans/06 §6): everything below is built from them.
func _fold_cards() -> void:
	shard_factor = RunState.mod("shards", 1.0)
	devil_enabled = RunState.mod("devil", 1.0) > 0.0
	devil_speed = RunState.mod("devil_speed", 1.0)
	devil_delay = maxf(RunState.mod("devil_delay", rule.devil_spawn_delay) - RunState.mod("devil_early", 0.0), 0.0)
	devil_distance = roundi(RunState.mod("devil_distance", rule.devil_spawn_distance))
	follow_flips = RunState.mod("follow_flips", 0.0) > 0.0
	mirror = RunState.mod("mirror", 0.0) > 0.0
	fog_factor = RunState.mod("fog", 1.0)
	trap_cue = RunState.mod("trap_cue", rule.trap_cue_strength)
	light_energy = world_light_energy * RunState.mod("lights", 1.0)
	music_db = MUSIC_DB if RunState.mod("music", 1.0) > 0.0 else SILENT_DB
	rare_chest = RunState.mod("rare_chest", 0.0) > 0.0
	heartbeat_tiles = roundi(RunState.mod("heartbeat", HEARTBEAT_TILES))
	night_fog = RunState.mod("nightmare_fog", 1.0)
	ghost_sight = RunState.mod("ghost_sight", 0.0) > 0.0
	last_breath = roundi(RunState.mod("last_breath", 0.0))
	beam_energy = RunState.mod("beam_energy", 1.0)
	beam_range = RunState.mod("beam_range", 1.0)
	beam_angle = RunState.mod("beam_angle", 1.0)
	flash_stuns = roundi(RunState.mod("flash_stun", 0.0))
	flip_flash = MetaState.wearing("flash")
	var names: Array[String] = []
	for id in RunState.floor_cards:
		names.append(Cards.find(id)["name"])
	card_names = "  ·  ".join(names)
	fog_colors.assign(FOG_COLORS)
	ambient_colors.assign(AMBIENT_COLORS)
	glow_colors.assign(GLOW_COLORS)
	for colors: Array[Color] in [fog_colors, ambient_colors, glow_colors]:
		colors[WAKE] = _act_tint(colors[WAKE])

## `color` in this act's hue (WAKE light and walls; Act 1 keeps it as it is).
func _act_tint(color: Color) -> Color:
	var i := rule.act - 1
	if ACT_HUES[i] < 0.0 and ACT_SATURATION[i] == 1.0:
		return color
	return Color.from_hsv(color.h if ACT_HUES[i] < 0.0 else ACT_HUES[i], color.s * ACT_SATURATION[i], color.v, color.a)

## Shown as a floor starts: where you are in the act, and what kind of floor this is.
func _floor_title() -> String:
	var title := "%s  ·  FLOOR %d / %d" % [rule.act_name.to_upper(), rule.floor_in_act, StageRule.FLOORS_PER_ACT]
	if rule.is_sanctuary:
		return title + "\nSANCTUARY  ·  NOTHING HUNTS YOU HERE"
	if rule.is_gate:
		return title + "\nTHE GATE  ·  ESCAPE IT TO CLEAR ACT %d" % rule.act
	return title

func _process(delta: float) -> void:
	if player == null or get_tree().paused:
		return  # no floor yet (the pick screen), or paused
	_update_flashlight(delta)
	_animate_devil(delta)
	var tilt := deg_to_rad(INVERT_TILT_DEGREES) if flip.forced_active and game_state == "playing" else 0.0
	camera_pivot.rotation.z = lerpf(camera_pivot.rotation.z, tilt, clampf(4.0 * delta, 0.0, 1.0))
	if game_state == "dying":
		_animate_fall(delta)
	if game_state != "playing":
		return
	elapsed += delta
	time_left -= delta
	catch_grace = maxf(catch_grace - delta, 0.0)
	enrage_left = maxf(enrage_left - delta, 0.0)
	lunge_cooldown = maxf(lunge_cooldown - delta, 0.0)
	flip.advance(delta, _spot_open(WAKE), _spot_open(NIGHTMARE))
	_strobe_lights(flip.warning_active)
	if circles.drain(player_cell, delta):
		_flash_message("The circle is empty. Move.")
	_refresh_circles()
	_tick_devil(delta)
	if devil_active and _devil_distance() <= HEARTBEAT_TILES:
		chased_time += delta
	_collect_sigils()
	if not panic and time_left <= PANIC_TIME:
		panic = true
		alarm_player.play()
	_update_hud()
	_refresh_minimap()
	_update_devil_audio()
	if exit_open and player_cell == layout.exit:
		_unlock_chest()
	elif time_left <= 0.0:
		_lose_game("time")

func _physics_process(delta: float) -> void:
	if player == null or game_state != "playing" or get_tree().paused:
		return
	var look_input := Input.get_vector("look_left", "look_right", "look_up", "look_down", feel.stick_deadzone)
	if look_input != Vector2.ZERO:
		_apply_look(-look_input.x * feel.stick_look_speed * delta, -look_input.y * feel.stick_look_speed * delta)
	var move_input := _move_input()
	var direction := player.transform.basis * Vector3(move_input.x, 0.0, move_input.y)
	var sprinting := Input.is_action_pressed("sprint") and move_input != Vector2.ZERO
	sprinted = sprinted or sprinting
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
	if event.is_action_pressed("restart") and not game_state in ["dying", "won", "choosing"]:
		if game_state == "playing" and not restart_armed:
			restart_armed = true
			_flash_message("PRESS R AGAIN: RESTART ACT %d ON A NEW MAZE" % rule.act)
			get_tree().create_timer(RESTART_ARM_TIME).timeout.connect(_disarm_restart)
			return
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
		if flash_stuns > 0:
			_camera_flash()
			return
		flashlight_on = not flashlight_on
		flashlight.visible = flashlight_on
	elif event.is_action_pressed("flip"):
		flip.request_flip(_spot_open(1 - world))

## Flipping Time inverts movement (the 2D FearFlip rule): W goes back, A goes right, and so on.
func _move_input() -> Vector2:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back", feel.stick_deadzone)
	return -input if flip.forced_active or (mirror and world == NIGHTMARE) else input

func _apply_look(yaw_delta: float, pitch_delta: float) -> void:
	yaw += yaw_delta
	pitch = clampf(pitch + pitch_delta, -feel.max_pitch, feel.max_pitch)
	player.rotation.y = yaw
	camera_pivot.rotation.x = pitch

func _toggle_pause() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
	_show_message(PAUSE_TEXT if paused else "")

## The second R never came: back to normal (and back to the pause notice, if the game is paused).
func _disarm_restart() -> void:
	restart_armed = false
	if get_tree().paused:
		_show_message(PAUSE_TEXT)

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
	var energy := feel.flashlight_energy * beam_energy * (1.0 + flicker_value)
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
	# Your own flip out of its grab (mid-lunge, or with it a step away and able to catch you) is a Phase Dodge.
	var dodged := not forced and devil_active and (lunge_left > 0.0 or
			(_devil_distance() <= PHASE_DODGE_TILES and not devil_retreating and not circles.protects(player_cell)))
	_apply_world(new_world)
	_count("flips")
	if forced:
		_count("forced_flips")
	flip_player.play()
	warning_label.visible = false
	var tween := create_tween().set_parallel()
	camera.rotation.z = 0.0
	tween.tween_property(camera, "rotation:z", TAU, FLIP_ROLL_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flash_rect.color = Color(Unlocks.item(flip_flash).get("color", SIGIL_COLORS[new_world]), 0.6)
	tween.tween_property(flash_rect, "color:a", 0.0, 0.3)
	tween.chain().tween_callback(func() -> void: camera.rotation.z = 0.0)
	# It follows you across worlds: re-path on the new walls, never a catch on the flip itself.
	player_dist = layout.distances(world, player_cell)
	catch_grace = FLIP_CATCH_GRACE
	lunge_left = 0.0
	_move_devil_into_world()
	if forced:
		_keep_devil_fair()
	if dodged:
		_close_call("PHASE DODGE")

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
	wake_walls.visible = ghost_sight or not nightmare
	nightmare_walls.visible = ghost_sight or nightmare
	if ghost_sight:
		ghost_material.albedo_color = Color(glow_colors[1 - world], GHOST_ALPHA)
		_ghost(wake_walls, nightmare)
		_ghost(nightmare_walls, not nightmare)
	env.fog_light_color = fog_colors[world]
	env.fog_density = FOG_DENSITIES[world] * fog_factor * (night_fog if nightmare else 1.0)
	env.ambient_light_color = ambient_colors[world]
	trim_material.emission = glow_colors[world] * 0.3
	light_material.emission = glow_colors[world] if light_energy > 0.0 else Color.BLACK
	accent_material.emission = glow_colors[world] * 0.2
	for light in world_lights:
		light.light_color = glow_colors[world]
	devil.visible = devil_active
	for i in sigil_nodes.size():
		sigil_nodes[i].visible = not sigil_collected[i]
	var tween := create_tween().set_parallel()
	tween.tween_property(calm_player, "volume_db", -60.0 if nightmare else music_db, 0.6)
	tween.tween_property(intense_player, "volume_db", music_db if nightmare else -60.0, 0.6)
	status_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4) if nightmare else Color(0.65, 0.95, 1.0))
	_refresh_minimap()

## Ghost Sight: the other world's walls stand in yours as faint glass you walk through (no shadow).
func _ghost(walls: Node3D, on: bool) -> void:
	for child in walls.get_children():
		var mesh := child as MultiMeshInstance3D
		if mesh == null:
			continue
		if not mesh.has_meta("solid"):
			mesh.set_meta("solid", mesh.material_override)
		mesh.material_override = ghost_material if on else mesh.get_meta("solid")
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if on else GeometryInstance3D.SHADOW_CASTING_SETTING_ON

## Flipping Time warning: ceiling lights stutter.
func _strobe_lights(on: bool) -> void:
	var energy := light_energy * (0.25 if on and fmod(elapsed, 0.25) < 0.12 else 1.0)
	for light in world_lights:
		light.light_energy = energy

func _keep_devil_fair() -> void:
	if not devil_active:
		return
	var dist := player_dist
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

## Only when NIGHTMARE_CHANGE > 0: if its cell is a wall in this world, it reappears on the nearest open one.
func _move_devil_into_world() -> void:
	if not devil_active or layout.is_open(world, devil_cell):
		return
	var best := devil_cell
	var best_d := 1 << 30
	for i in player_dist.size():
		var cell := layout.cell_at(i)
		var d := absi(cell.x - devil_cell.x) + absi(cell.y - devil_cell.y)
		if player_dist[i] >= 0 and d < best_d:
			best = cell
			best_d = d
	devil_cell = best
	prev_devil_cell = best
	devil.position = _devil_world_position()  # teleport: never glide through a wall

# --- Sigils, exit, Devil ----------------------------------------------------

func _collect_sigils() -> void:
	for i in layout.sigils.size():
		if sigil_collected[i] or layout.sigils[i] != player_cell:
			continue
		sigil_collected[i] = true
		(sigil_nodes[i] as KeyPickup).collect()
		key_hud.fly_in(sigils_collected, _screen_point(sigil_nodes[i].global_position))
		sigils_collected += 1
		_count("sigils")
		_earn(MetaState.SIGIL_SHARDS)
		sigil_player.pitch_scale = 1.0
		sigil_player.play()
		if sigils_collected == layout.sigils.size():
			key_hud.all_found()
			_open_exit()
		_refresh_minimap()

func _open_exit() -> void:
	exit_open = true
	enrage_left = DEVIL_ENRAGE_DURATION
	_set_exit_look()
	_show_message("ALL KEYS FOUND — GET TO THE CHEST")
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if game_state == "playing":
			_show_message(""))

## Where a world point is on screen (for the key flying to the HUD); behind you = low centre.
func _screen_point(at: Vector3) -> Vector2:
	if camera.is_position_behind(at):
		return get_viewport().get_visible_rect().size * Vector2(0.5, 0.75)
	return camera.unproject_position(at)

## At the chest with every key: you stop facing it (clock and Devil freeze), the keys fly into its
## locks, it opens, the floor is cleared.
func _unlock_chest() -> void:
	game_state = "unlocking"
	_show_message("")
	# Looking down at the chest you would see your own head.
	player_mesh.visible = false
	var exit_world := cell_to_world(layout.exit)
	var arrival := cell_to_world(last_player_cell) - exit_world
	arrival = arrival.normalized() if arrival.length() > 0.1 else chest.global_transform.basis.z
	chest.rotation.y = atan2(arrival.x, arrival.z)
	var stand := exit_world + arrival * CHEST_VIEW_DISTANCE
	stand.y = player.global_position.y
	yaw = player.rotation.y + wrapf(atan2(arrival.x, arrival.z) - player.rotation.y, -PI, PI)
	var eye_y := stand.y + camera_pivot.position.y
	pitch = -atan2(eye_y - TreasureChest.BASE_HEIGHT, CHEST_VIEW_DISTANCE)
	var tween := create_tween().set_parallel()
	tween.tween_property(player, "global_position", stand, 0.45).set_trans(Tween.TRANS_SINE)
	tween.tween_property(player, "rotation:y", yaw, 0.45).set_trans(Tween.TRANS_SINE)
	tween.tween_property(camera_pivot, "rotation:x", pitch, 0.45).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_callback(chest.unlock.bind(camera))

func _on_key_turned(index: int) -> void:
	key_hud.spend(index)
	sigil_player.pitch_scale = 1.3 + 0.15 * index
	sigil_player.play()

## The lid is up: the chest pays its roll for this floor's seed (plans/06 C5), then the floor is cleared.
func _on_chest_opened() -> void:
	_pay_chest({"kind": "rare", "shards": MetaState.RARE_SHARDS} if rare_chest else MetaState.chest_roll(seed_value))
	flash_rect.color = Color(1.0, 0.85, 0.5, 0.55)
	var tween := create_tween()
	tween.tween_property(flash_rect, "color", Color(1.0, 0.85, 0.5, 0.0), 0.6)
	tween.tween_callback(_win_game).set_delay(0.2)

## Seconds per cell: DevilBrain's rubber band (far = faster, close = slower), enraged once the exit opens.
func _devil_step_interval() -> float:
	var enraged := enrage_left > 0.0
	var ratio := rule.devil_base_ratio * devil_speed * DevilBrain.WORLD_SPEED[NIGHTMARE if follow_flips else world] * (DEVIL_ENRAGE_MULTIPLIER if enraged else 1.0)
	return CELL_SIZE / DevilBrain.speed(_devil_distance(), feel.walk_speed, feel.walk_speed * feel.sprint_multiplier, ratio, enraged)

## Current-world path tiles between the Devil and you (a large number if there is no path).
func _devil_distance() -> int:
	var d := player_dist[devil_cell.y * layout.size + devil_cell.x]
	return d if d >= 0 else 999

func _devil_world_position() -> Vector3:
	return cell_to_world(devil_cell) + Vector3(0, DEVIL_Y, 0)

## Glide toward the Devil's grid cell (or lunge at you), face the way it runs, drive the run cycle.
func _animate_devil(delta: float) -> void:
	if devil_stun > 0.0:
		return  # frozen by a Camera Flash, mid-stride
	var goal_position := _devil_world_position()
	var move_speed := CELL_SIZE / _devil_step_interval()
	if lunge_left > 0.0:
		goal_position = Vector3(player.global_position.x, DEVIL_Y, player.global_position.z)
		move_speed = LUNGE_SPEED
	var next := devil.position.move_toward(goal_position, move_speed * delta)
	var moved := next - devil.position
	devil.position = next
	var face := Vector3.ZERO
	if moved.length_squared() > 0.000001:
		face = moved
	elif devil_active and _devil_distance() <= DevilBrain.SIGHT_TILES and DevilBrain.line_of_sight(layout, world, devil_cell, player_cell):
		face = player.global_position - devil.position  # paused but sees you: turn to track you
	if face != Vector3.ZERO:
		devil.rotation.y = lerp_angle(devil.rotation.y, atan2(face.x, face.z), clampf(DEVIL_TURN_SPEED * delta, 0.0, 1.0))
	var speed := moved.length() / delta if delta > 0.0 else 0.0
	devil_mesh.position.y = -DEVIL_Y + devil_rig.animate(speed, delta)

func _tick_devil(delta: float) -> void:
	if not devil_enabled:
		return
	if not devil_active:
		if not devil_spawning and DevilBrain.can_spawn(elapsed, devil_delay, _progress(), circles.protects(player_cell)):
			_try_spawn_devil()
		return
	if devil_stun > 0.0:
		devil_stun -= delta  # a Camera Flash: it neither walks nor grabs
		return
	devil_timer += delta
	# Next cell only once the body is on its current cell centre: it walks corridors, never cuts a wall corner.
	if devil_timer >= _devil_step_interval() and devil.position.distance_to(_devil_world_position()) < 0.05:
		devil_timer = 0.0
		_step_devil()
	_check_catch(delta)

## One cell along the BFS shortest path to you (or to its retreat spot), through open cells only.
func _step_devil() -> void:
	prev_devil_cell = devil_cell
	if devil_retreating and steps_since_retreat >= rule.devil_respawn_steps and not circles.protects(player_cell):
		devil_retreating = false
	devil_cell = layout.next_step(world, devil_cell, devil_target if devil_retreating else player_cell)

## Same cell or a cross-through starts a 0.35 s lunge; it only kills if it really reaches you.
func _check_catch(delta: float) -> void:
	if lunge_left > 0.0:
		if circles.protects(player_cell):
			lunge_left = 0.0
			return
		lunge_left -= delta
		if lunge_left <= 0.0:
			var gap := Vector2(devil.position.x - player.global_position.x, devil.position.z - player.global_position.z)
			if gap.length() < LUNGE_RANGE and last_breath > 0:
				last_breath -= 1
				_return_to_circle()
				_flash_message("LAST BREATH  ·  back to your last safe circle")
			elif gap.length() < LUNGE_RANGE:
				_lose_game("devil")
			else:
				lunge_cooldown = LUNGE_MISS_STUN
				_close_call("CLOSE CALL")
		return
	if catch_grace > 0.0 or lunge_cooldown > 0.0 or devil_retreating or circles.protects(player_cell):
		return
	var crossed := devil_cell == last_player_cell and prev_devil_cell == player_cell
	if devil_cell == player_cell or crossed:
		lunge_left = LUNGE_TIME

## Fraction of the spawn -> exit distance you've covered (flips allowed).
func _progress() -> float:
	var total := maxi(from_spawn[layout.exit.y * layout.size + layout.exit.x], 1)
	return float(from_spawn[player_cell.y * layout.size + player_cell.x]) / float(total)

## Wakes behind you on your own trail, far away and out of sight, after a telegraph. Never ahead.
func _try_spawn_devil() -> void:
	var cell := brain.pick_spawn(player_dist, layout.size, devil_distance, _seen_by_player)
	if cell.x < 0:
		var fallback := layout.devil_spawn
		if player_dist[fallback.y * layout.size + fallback.x] < devil_distance or _seen_by_player(fallback):
			return
		cell = fallback
	devil_spawning = true
	devil_cell = cell
	prev_devil_cell = cell
	telegraph_player.play()
	_flash_message("Something woke up behind you...")
	get_tree().create_timer(SPAWN_TELEGRAPH).timeout.connect(_wake_devil)

func _wake_devil() -> void:
	devil_spawning = false
	devil_active = true
	_count("devil_wakes")
	devil.position = _devil_world_position()
	devil.visible = true

func _seen_by_player(cell: Vector2i) -> bool:
	return DevilBrain.line_of_sight(layout, world, player_cell, cell) or circles.index_at(cell) >= 0

## In a safe circle: it backs off (visibly, at its own speed) to the nearest spot far from you.
func _start_retreat() -> void:
	if lunge_left > 0.0:
		_close_call("CLOSE CALL")  # dove into the circle mid-lunge
	devil_retreating = true
	steps_since_retreat = 0
	lunge_left = 0.0
	var from_devil := layout.distances(world, devil_cell)
	var best := -1
	for i in player_dist.size():
		if player_dist[i] >= CIRCLE_RETREAT_DISTANCE and from_devil[i] >= 0 and (best < 0 or from_devil[i] < from_devil[best]):
			best = i
	devil_target = layout.cell_at(best) if best >= 0 else devil_cell

# --- Fear Shards (plans/06 P2) ------------------------------------------------------

## Shards for something you did: counted now, popped on the HUD, banked by _bank().
func _earn(amount: int, why := "") -> void:
	amount = roundi(amount * shard_factor)
	floor_shards += amount
	_pop(("+%d  %s" % [amount, why]).strip_edges())

## A "+3" under the shard counter that drifts up and fades; pops landing together stack downwards.
func _pop(text: String) -> void:
	var pop := shard_label.duplicate() as Label
	pop.text = text
	shard_label.add_sibling(pop)
	live_pops += 1
	pop.position.y += SHARD_POP_GAP * live_pops + SHARD_POP_RISE
	var tween := pop.create_tween().set_parallel()
	tween.tween_property(pop, "position:y", pop.position.y - SHARD_POP_RISE, SHARD_POP_TIME).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(pop, "modulate:a", 0.0, SHARD_POP_TIME * 0.5).set_delay(SHARD_POP_TIME * 0.5)
	tween.chain().tween_callback(func() -> void:
		live_pops -= 1
		pop.queue_free())

## A near miss: it pays, time slows for a beat (on a real-time timer, so slow motion can't stretch it)
## and the heart jumps.
func _close_call(what: String) -> void:
	_earn(MetaState.CLOSE_CALL_SHARDS, what)
	_count("phase_dodges" if what == "PHASE DODGE" else "close_calls")
	_count("devil_escapes")
	Engine.time_scale = CLOSE_CALL_TIME_SCALE
	get_tree().create_timer(CLOSE_CALL_SLOWMO, true, false, true).timeout.connect(Engine.set.bind("time_scale", 1.0))
	heartbeat_player.pitch_scale = CLOSE_CALL_HEART_PITCH
	create_tween().tween_property(heartbeat_player, "pitch_scale", 1.0, CLOSE_CALL_HEART_TIME)

## A chest's roll: shards pop and count; a find (omen token, lore note) waits to be banked with them.
func _pay_chest(roll: Dictionary) -> void:
	_count("chests")
	var find: String = MetaState.CHEST_TEXT[roll["kind"]]
	if roll["shards"] > 0:
		_earn(roll["shards"], find)
	else:
		_pop("+1  " + find)
		floor_finds.append(roll["kind"])

## A chest down a dead end opens as you reach it and pays its own roll.
func _open_detour_chest(cell: Vector2i) -> void:
	var box: TreasureChest = bonus_chests[cell]
	bonus_chests.erase(cell)
	box.open_now()
	_pay_chest(MetaState.chest_roll(hash([seed_value, cell])))

## This floor's shards, finds and counters go to the profile for good, and what they complete (challenges, bestiary
## entries) pops and is returned. Quitting mid-floor banks nothing: the floor replays.
func _bank() -> Array[String]:
	var news: Array[String] = []
	if fixed_seed != 0 or (floor_shards == 0 and floor_finds.is_empty() and floor_stats.is_empty()):
		return news  # a debug floor never touches the save
	RunState.bank(floor_shards)
	for find in floor_finds:
		MetaState.keep_find(find)
		if find == "note":
			_count("notes")
	news = MetaState.record(floor_stats)
	floor_shards = 0
	floor_finds.clear()
	floor_stats.clear()
	for line in news:
		_pop(line)
	return news

## One more of `stat` this floor (plans/06 P5 challenges and bestiary), banked by _bank().
func _count(stat: String, amount := 1) -> void:
	floor_stats[stat] = floor_stats.get(stat, 0) + amount

## Camera Flash (Altar torch): F fires it once a floor. It freezes the Devil for FLASH_STUN_TIME if it's within
## FLASH_STUN_TILES and in sight; fired at nothing, it's spent all the same.
func _camera_flash() -> void:
	flash_stuns -= 1
	flash_rect.color = Color(1, 1, 1, 0.85)
	create_tween().tween_property(flash_rect, "color:a", 0.0, 0.5)
	if devil_active and _devil_distance() <= FLASH_STUN_TILES and DevilBrain.line_of_sight(layout, world, player_cell, devil_cell):
		devil_stun = FLASH_STUN_TIME
		lunge_left = 0.0
		_flash_message("CAMERA FLASH  ·  it froze")

# --- Cells, circles, traps ------------------------------------------------------

## Hysteresis: the new cell only counts once you're STEP_HYSTERESIS past its edge.
func _update_player_cell() -> void:
	var candidate := world_to_cell(player.global_position)
	if candidate == player_cell or not layout.is_open(world, candidate):
		return
	var offset := Vector2(player.global_position.x, player.global_position.z) - Vector2(candidate) * CELL_SIZE
	if maxf(absf(offset.x), absf(offset.y)) > CELL_SIZE * 0.5 - STEP_HYSTERESIS:
		return
	_enter_cell(candidate)

func _enter_cell(cell: Vector2i) -> void:
	last_player_cell = player_cell
	player_cell = cell
	player_dist = layout.distances(world, player_cell)
	if not visited.has(cell):
		visited[cell] = true
		circles.on_new_cell()
		steps_since_retreat += 1
	brain.record(cell, true)
	if bonus_chests.has(cell):
		_open_detour_chest(cell)
	if cell == layout.exit and not exit_open:
		_flash_message("THE CHEST IS LOCKED   find %d more keys" % (layout.sigils.size() - sigils_collected))
	if traps.creak(cell):
		creak_player.play()
	var holds := traps.holds
	match traps.step(cell):
		TrapField.State.CRACKED:
			_count("cracks")
			crack_player.play()
			trap_nodes[traps.index_at(cell)].crack()
			create_tween().tween_method(_shake, 0.035, 0.0, 0.3)
			_flash_message("FEATHER STEP  ·  it held, once" if traps.holds < holds else "The floor cracked. It won't hold you twice.")
		TrapField.State.COLLAPSED:
			_collapse(traps.index_at(cell))
	if game_state == "playing" and circles.protects(cell):
		_enter_circle()

func _enter_circle() -> void:
	_count("circles")
	circle_player.play()
	snapshot = {"cell": player_cell, "time_left": time_left, "traps": traps.states.duplicate()}
	if devil_active and not devil_retreating:
		_start_retreat()

func _refresh_circles() -> void:
	for i in circles.cells.size():
		var fill := circles.charge[i] / circles.capacity
		circle_materials[i].emission_energy_multiplier = 0.15 + 3.0 * fill
		circle_lights[i].light_energy = 0.1 + 1.2 * fill

func _refresh_traps() -> void:
	for i in traps.cells.size():
		trap_nodes[i].show_state(traps.states[i])

## Second step on a cracked floor: it drops under you, a beat, then the camera lets go and stays at
## the rim while your body tips back and falls flailing into the shaft. Then the death screen.
func _collapse(index: int) -> void:
	game_state = "dying"
	fall_time = 0.0
	trap_nodes[index].collapse(player.global_position)
	fall_player.pitch_scale = 0.75
	fall_player.play()
	var start := player.global_position
	var hole := cell_to_world(traps.cells[index])
	# Toward where you came from: always open, so the rim camera never sits in a wall.
	var back := cell_to_world(last_player_cell) - hole
	back = back.normalized() if back.length() > 0.1 else player.global_transform.basis.z
	var rim := hole + back * FALL_CAM_BACK + Vector3(0, FALL_CAM_HEIGHT, 0)
	var t := create_tween().set_parallel()
	t.tween_method(_shake, 0.08, 0.0, 0.45)
	t.tween_property(player, "global_position:y", start.y - 0.08, 0.07).set_ease(Tween.EASE_OUT)
	t.tween_callback(_release_camera).set_delay(FALL_BEAT)
	t.tween_property(camera, "global_position", rim, FALL_CAM_MOVE).set_delay(FALL_BEAT + 0.01).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(camera, "fov", feel.base_fov + FALL_FOV_ZOOM, FALL_TIME).set_delay(FALL_BEAT).set_trans(Tween.TRANS_SINE)
	# The body: stumbles over the hole, twists back toward you, tips over backwards and drops.
	t.tween_property(player, "global_position:x", lerpf(start.x, hole.x, 0.8), 0.35).set_delay(FALL_BEAT).set_trans(Tween.TRANS_SINE)
	t.tween_property(player, "global_position:z", lerpf(start.z, hole.z, 0.8), 0.35).set_delay(FALL_BEAT).set_trans(Tween.TRANS_SINE)
	t.tween_property(player, "rotation:y", _facing(back), 0.4).set_delay(FALL_BEAT).set_trans(Tween.TRANS_SINE)
	t.tween_property(player, "rotation:x", FALL_TIP, FALL_TIME).set_delay(FALL_BEAT + 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Gravity: slow first, then gone.
	t.tween_property(player, "global_position:y", start.y - FALL_DEPTH, FALL_TIME).set_delay(FALL_BEAT + 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	flash_rect.color = Color(0.55, 0.05, 0.0, 0.35)
	t.tween_property(flash_rect, "color", Color(0.55, 0.05, 0.0, 0.0), 0.25)
	t.tween_property(flash_rect, "color", Color(0, 0, 0, 1), FALL_TIME * 0.5).set_delay(FALL_BEAT + FALL_TIME * 0.65).set_ease(Tween.EASE_IN)
	t.tween_callback(_fall_impact).set_delay(FALL_BEAT + FALL_TIME)
	t.tween_callback(_lose_game.bind("trap")).set_delay(FALL_END)

## Yaw that makes the body (forward = -Z) face `direction`, unwrapped next to the current yaw.
func _facing(direction: Vector3) -> float:
	var target := atan2(-direction.x, -direction.z)
	return player.rotation.y + wrapf(target - player.rotation.y, -PI, PI)

## Camera stops following the body: it stays where it is in the world.
func _release_camera() -> void:
	var at := camera.global_transform
	camera.top_level = true
	camera.global_transform = at
	camera.rotation.z = 0.0

func _animate_fall(delta: float) -> void:
	fall_time += delta
	if player_rig != null and fall_time > FALL_BEAT:
		player_rig.flail(fall_time - FALL_BEAT)
	if camera.top_level:
		camera.look_at(player.global_position + Vector3(0, 0.3, 0))

func _fall_impact() -> void:
	fall_player.pitch_scale = 0.45
	fall_player.play()
	_shake(0.12)

## Camera shake via lens offset, so it never fights look, bob or flip roll.
func _shake(amount: float) -> void:
	camera.h_offset = randf_range(-amount, amount)
	camera.v_offset = randf_range(-amount, amount)

## Spawn -> each sigil (nearest first) -> exit, in path tiles: what the clock budgets for.
func _tour_tiles() -> int:
	var total := 0
	var at := layout.spawn
	var left: Array[Vector2i] = layout.sigils.duplicate()
	while not left.is_empty():
		var dist := layout.distances(FloorLayout.ANY, at)
		var pick := left[0]
		for cell in left:
			if dist[cell.y * layout.size + cell.x] < dist[pick.y * layout.size + pick.x]:
				pick = cell
		total += maxi(dist[pick.y * layout.size + pick.x], 0)
		at = pick
		left.erase(pick)
	return total + maxi(layout.distances(FloorLayout.ANY, at)[layout.exit.y * layout.size + layout.exit.x], 0)

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
	calm_player = _audio("CalmLoop", "res://assets/audio/sfx_ambient_calm.mp3", music_db)
	intense_player = _audio("IntenseLoop", "res://assets/audio/sfx_ambient_intense.mp3", -60.0)
	for music in [calm_player, intense_player]:
		(music.stream as AudioStreamMP3).loop = true
		music.play()
	win_player = _audio("WinSfx", "res://assets/audio/sfx_win.mp3", -4.0)
	lose_player = _audio("LoseSfx", "res://assets/audio/sfx_lose.mp3", -4.0)
	flip_player = _audio("FlipSfx", "res://assets/audio/sfx_flip.mp3", -6.0)
	deny_player = _audio("FlipDenied", "res://assets/audio/sfx_flip_denied.mp3", -8.0)
	warning_player = _audio("FlippingTimeWarning", "res://assets/audio/sfx_flipping_warning.mp3", -4.0)
	sigil_player = _audio("SigilSfx", "res://assets/audio/sfx_sigil.mp3", -6.0)
	devil_approach_player = _audio("DevilApproach", "res://assets/audio/sfx_devil_approach.mp3", -10.0)
	heartbeat_player = _audio("Heartbeat", "res://assets/audio/sfx_heartbeat.mp3", -20.0)
	(heartbeat_player.stream as AudioStreamMP3).loop = true
	alarm_player = _audio("LowTimeAlarm", "res://assets/audio/sfx_low_time.mp3", -8.0)
	crack_player = _audio("FloorCrack", "res://assets/audio/sfx_floor_crack.mp3", -6.0)
	fall_player = _audio("FloorCollapse", "res://assets/audio/sfx_floor_crack.mp3", 0.0)
	creak_player = _audio("FloorCreak", "res://assets/audio/sfx_floor_creak.mp3", -12.0)
	circle_player = _audio("SafeCircle", "res://assets/audio/sfx_safe_circle.mp3", -6.0)
	telegraph_player = _audio("DevilWakes", "res://assets/audio/sfx_devil_wakes.mp3", -4.0)

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
	floor_body.position = center + Vector3(0, -0.08, 0)
	floor_material = StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.025, 0.035, 0.05)
	floor_material.roughness = 0.9
	# One tile per cell so trap cells are real holes (TrapPit fills them). Collision stays one slab:
	# the grid decides who falls, not physics.
	var tile_mesh := BoxMesh.new()
	tile_mesh.size = Vector3(CELL_SIZE, 0.15, CELL_SIZE)
	tile_mesh.material = floor_material
	var tiles := MultiMesh.new()
	tiles.transform_format = MultiMesh.TRANSFORM_3D
	tiles.mesh = tile_mesh
	tiles.instance_count = layout.size * layout.size - traps.cells.size()
	var tile := 0
	for row in layout.size:
		for col in layout.size:
			if traps.cells.has(Vector2i(col, row)):
				continue
			tiles.set_instance_transform(tile, Transform3D(Basis(), cell_to_world(Vector2i(col, row)) + Vector3(0, -0.08, 0)))
			tile += 1
	var floor_tiles := MultiMeshInstance3D.new()
	floor_tiles.name = "FloorTiles"
	floor_tiles.multimesh = tiles
	add_child(floor_tiles)
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(span, 0.15, span)
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
	if ghost_sight:
		ghost_material = StandardMaterial3D.new()
		ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var fixture_mesh := BoxMesh.new()
	fixture_mesh.size = Vector3(0.5, 0.05, 0.5)
	add_child(_multimesh(fixture_mesh, light_material, light_cells, CEILING_HEIGHT - 0.12))
	for cell in light_cells:
		if light_energy <= 0.0:
			break  # Blackout: the fixtures hang dead
		var light := OmniLight3D.new()
		light.light_energy = light_energy
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
	material.albedo_color = _act_tint(Color(0.038, 0.055, 0.08))
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
	# character2withrig.glb faces +X; turn it to face -Z.
	player_mesh.rotation_degrees.y = 90.0
	ModelFit.fit_height(player_mesh, WALL_HEIGHT * PLAYER_HEIGHT_RATIO, PLAYER_MESH_Y)
	player.add_child(player_mesh)
	player_rig = DevilRig.new(player_mesh, false)
	player_rig.unstick_hands()

	camera_pivot = Node3D.new()
	camera_pivot.position.y = 0.45
	player.add_child(camera_pivot)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = feel.base_fov
	camera_pivot.add_child(camera)
	flashlight = SpotLight3D.new()
	flashlight.name = "Flashlight"
	flashlight.light_color = MetaState.light_color()
	flashlight.light_energy = feel.flashlight_energy * beam_energy
	flashlight.spot_range = feel.flashlight_range * beam_range
	flashlight.spot_angle = feel.flashlight_angle * beam_angle
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

	goal_material = StandardMaterial3D.new()
	goal_material.emission_enabled = true
	goal_material.emission_energy_multiplier = 3.0
	base.material_override = goal_material

	# The exit is a treasure chest on the glowing disc, its locks facing the way in.
	chest = TreasureChest.new()
	chest.name = "TreasureChest"
	goal.add_child(chest)
	chest.build(LAYER_SHARED, layout.sigils.size())
	for d in FloorLayout.DIRS:
		if layout.is_open(FloorLayout.ANY, layout.exit + d):
			chest.rotation.y = atan2(float(d.x), float(d.y))
			break
	chest.key_turned.connect(_on_key_turned)
	chest.opened.connect(_on_chest_opened)

	goal_light = OmniLight3D.new()
	goal_light.omni_range = 4.0
	goal.add_child(goal_light)
	_set_exit_look()

## Locked: dim and red. Open (all keys): bright green.
func _set_exit_look() -> void:
	var color := Color(0.1, 1.0, 0.45) if exit_open else Color(0.35, 0.05, 0.08)
	goal_material.albedo_color = color
	goal_material.emission = color * (0.65 if exit_open else 0.3)
	goal_light.light_color = color
	goal_light.light_energy = 2.5 if exit_open else 0.6

## Chests down dead ends (Vault, Greed: plans/06 B3), each a real detour off the route, glowing faintly.
func _build_detour_chests() -> void:
	var taken: Array[Vector2i] = [layout.devil_spawn]
	taken.append_array(layout.sigils)
	taken.append_array(circles.cells)
	taken.append_array(traps.cells)
	for cell in layout.detours(roundi(RunState.mod("chests", 0.0)), taken, traps.cells):
		var box := TreasureChest.new()
		box.name = "DetourChest"
		box.position = cell_to_world(cell)
		add_child(box)
		box.build(LAYER_SHARED, 0, DETOUR_CHEST_GLOW)
		for d in FloorLayout.DIRS:
			if layout.is_open(FloorLayout.ANY, cell + d):
				box.rotation.y = atan2(float(d.x), float(d.y))
		bonus_chests[cell] = box

## Keys (the sigils' rules, the key art): one per sigil cell, glowing in the colour of its world.
func _build_sigils() -> void:
	for i in layout.sigils.size():
		var key := KeyPickup.new()
		key.name = "Key%d" % i
		key.position = cell_to_world(layout.sigils[i]) + Vector3(0, KEY_HEIGHT, 0)
		add_child(key)
		key.build(SIGIL_COLORS[layout.sigil_worlds[i]], i * 1.3, RunState.mod("key_glow", 1.0))
		sigil_nodes.append(key)
		sigil_collected.append(false)

## A blue floor ring per circle; its glow is the drain meter.
func _build_circles() -> void:
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.8
	ring_mesh.outer_radius = 0.95
	for cell in circles.cells:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.2, 0.55, 1.0)
		material.emission_enabled = true
		material.emission = Color(0.25, 0.6, 1.0)
		var ring := MeshInstance3D.new()
		ring.name = "SafeCircle"
		ring.mesh = ring_mesh
		ring.scale = Vector3(1.0, 0.15, 1.0)
		ring.position = cell_to_world(cell) + Vector3(0, 0.03, 0)
		ring.material_override = material
		add_child(ring)
		var light := OmniLight3D.new()
		light.light_color = Color(0.3, 0.6, 1.0)
		light.omni_range = 2.5
		light.position = ring.position + Vector3(0, 0.6, 0)
		add_child(light)
		circle_materials.append(material)
		circle_lights.append(light)
	_refresh_circles()

## Cracked floors: stone plates over a shaft (TrapPit). Seams glow faintly (cue strength) while hidden.
func _build_traps() -> void:
	var shaft_material := StandardMaterial3D.new()
	shaft_material.albedo_color = Color(0.05, 0.04, 0.04)
	shaft_material.roughness = 1.0
	var dust_mesh := BoxMesh.new()
	dust_mesh.size = Vector3.ONE * 0.035
	var dust_material := StandardMaterial3D.new()
	dust_material.albedo_color = Color(0.32, 0.28, 0.24)
	dust_mesh.material = dust_material
	for cell in traps.cells:
		var pit := TrapPit.new()
		pit.name = "CrackedFloor"
		pit.process_mode = Node.PROCESS_MODE_PAUSABLE
		pit.cell_size = CELL_SIZE
		pit.cue = trap_cue
		pit.player = player
		pit.position = cell_to_world(cell)
		add_child(pit)
		pit.build(cell, floor_material, shaft_material, dust_mesh)
		trap_nodes.append(pit)
	_refresh_traps()

func _build_devil() -> void:
	devil = Node3D.new()
	devil.name = "Devil"
	devil.position = _devil_world_position()
	add_child(devil)

	devil_mesh = DEVIL_MODEL.instantiate()
	devil_mesh.name = "DevilMesh"
	ModelFit.fit_height(devil_mesh, WALL_HEIGHT * DEVIL_HEIGHT_RATIO, -DEVIL_Y)
	devil.add_child(devil_mesh)
	devil_rig = DevilRig.new(devil_mesh)
	# The devil model's chest is ~24 deg off +Z; square it up so it runs straight, not crabwise.
	devil_mesh.rotation.y = -devil_rig.facing_yaw()

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
	minimap.fog_colors = fog_colors
	minimap.glow_colors = glow_colors
	minimap.sigil_colors = SIGIL_COLORS
	minimap.sigil_collected = sigil_collected
	minimap.circles = circles
	minimap.traps = traps
	hud.add_child(minimap)
	minimap.visible = RunState.mod("minimap", 1.0) > 0.0
	minimap.crack_reveal = roundi(RunState.mod("crack_reveal", 0.0))

	status_label = _hud_label(hud, "Status", 22, Control.PRESET_TOP_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT)
	status_label.offset_left = -360
	status_label.offset_right = -24
	status_label.offset_top = 20
	status_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN  # a long card line grows left, never off-screen

	# A floor with cards has one more status line: the keys and the shard counter sit below it.
	var below := STATUS_LINE if card_names != "" else 0.0
	key_hud = KeyHud.new()
	key_hud.name = "Keys"
	hud.add_child(key_hud)
	key_hud.build(layout.sigils.size())
	key_hud.offset_top += below
	key_hud.offset_bottom += below

	shard_label = _hud_label(hud, "Shards", 22, Control.PRESET_TOP_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT)
	shard_label.offset_left = -360
	shard_label.offset_right = -24
	shard_label.offset_top = KeyHud.MARGIN_TOP + KeyHud.SLOT_HEIGHT + 8 + below
	shard_label.add_theme_color_override("font_color", SHARD_COLOR)

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
	hint.text = "WASD  MOVE     SHIFT  SPRINT     SPACE / E  FLIP     F  FLASHLIGHT     ESC  PAUSE     R R  RESTART ACT"
	hint.add_theme_color_override("font_color", Color(0.55, 0.7, 0.82, 0.8))

	# The run's build: its omens, curse and descents (plans/06 P4).
	omens_label = _hud_label(hud, "Omens", 16, Control.PRESET_BOTTOM_WIDE, HORIZONTAL_ALIGNMENT_LEFT)
	omens_label.offset_left = 24
	omens_label.offset_top = -60
	omens_label.add_theme_color_override("font_color", OMEN_COLOR)
	var run_names: Array[String] = []
	for id in RunState.run_cards:
		run_names.append(("CURSED: " if Cards.kind(id) == "curse" else "") + Cards.find(id)["name"])
	omens_label.text = "  ·  ".join(run_names)

	flash_rect = ColorRect.new()
	flash_rect.name = "FlipFlash"
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1, 1, 1, 0)
	hud.add_child(flash_rect)

	var overlays := CanvasLayer.new()
	overlays.name = "Overlays"
	overlays.layer = 10
	add_child(overlays)
	death_screen = DeathScreen.new()
	death_screen.name = "DeathScreen"
	death_screen.retry_pressed.connect(_restart_game)
	death_screen.revive_pressed.connect(_revive)
	overlays.add_child(death_screen)
	card_choice = CardChoice.new()
	card_choice.name = "CardChoice"
	card_choice.picked.connect(_take_pick)
	overlays.add_child(card_choice)

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
	var flip_line := "FLIP READY  x%d  [SPACE]" % flip.charges_left if flip.charges > 1 else "FLIP READY  [SPACE]"
	if flip.forced_active:
		flip_line = "CONTROLS INVERTED  %ds" % ceili(maxf(flip.forced_left, 0.0))
	elif flip.charges_left == 0:
		flip_line = "FLIP  %.1fs" % flip.cooldown_left
	var goal_line := "OPEN THE CHEST" if exit_open else "KEYS  %d / %d" % [sigils_collected, layout.sigils.size()]
	var where := "ACT %d  ·  FLOOR %d / %d" % [rule.act, rule.floor_in_act, StageRule.FLOORS_PER_ACT]
	if card_names != "":
		where += "\n" + ("THE GATE  ·  " if rule.is_gate else "") + card_names
	status_label.text = "%s\n%s   %s\n%s\n%s" % [where, WORLD_NAMES[world], _format_time(maxf(time_left, 0.0)), goal_line, flip_line]
	status_label.modulate = Color(1.0, 0.35, 0.3, 0.6 + 0.4 * absf(sin(elapsed * 6.0))) if panic else Color.WHITE
	shard_label.text = "SHARDS  %d" % (MetaState.shards + floor_shards)
	if warning_label.visible:
		warning_label.text = "FLIPPING TIME  %d
CONTROLS WILL INVERT" % maxi(ceili(flip.next_forced_in), 0)
		warning_label.modulate.a = 0.55 + 0.45 * sin(elapsed * 18.0)

## Heartbeat inside heartbeat_tiles (louder as it closes), its breath inside DEVIL_NEAR_DISTANCE.
func _update_devil_audio() -> void:
	var d := _devil_distance() if devil_active else 999
	if d <= heartbeat_tiles:
		heartbeat_player.volume_db = lerpf(-4.0, -22.0, float(d) / heartbeat_tiles)
		if not heartbeat_player.playing:
			heartbeat_player.play()
	elif heartbeat_player.playing:
		heartbeat_player.stop()
	var should_play := d <= DEVIL_NEAR_DISTANCE
	if should_play and not devil_approach_playing:
		devil_approach_player.play()
		devil_approach_playing = true
	elif not should_play and devil_approach_playing:
		devil_approach_player.stop()
		devil_approach_playing = false

func _stop_tension_audio() -> void:
	for audio in [devil_approach_player, heartbeat_player, alarm_player]:
		audio.stop()
	devil_approach_playing = false
	warning_label.visible = false

## Floor clear (2D): a short overlay, then the next floor with a new maze and a fresh clock.
## The Gate (F10) clears the act instead: the next act opens for good and the run ends at the menu.
func _win_game() -> void:
	if game_state == "won":
		return
	game_state = "won"
	win_player.play()
	_stop_tension_audio()
	var grade := StageRule.grade(elapsed, tour_m, feel.walk_speed, floor_revives, chased_time)
	var pay := MetaState.floor_clear_shards(rule.floor_in_act, grade)
	if rule.is_gate:
		pay += MetaState.act_clear_shards(rule.act)
	_earn(pay, "GRADE " + grade)
	_count("floors")
	if grade == "S":
		_count("grade_s")
	if rule.is_sanctuary:
		floor_finds.append("note")  # the Sanctuary's lore note (plans/06 A4)
		_pop("+1  " + MetaState.CHEST_TEXT["note"])
	var earned := "GRADE %s   ·   +%d SHARDS" % [grade, floor_shards]
	# Read before this clear is banked: an ending plays the first time only.
	var ending := _gate_ending() if rule.is_gate and fixed_seed == 0 else ""
	if fixed_seed == 0:
		RunState.note_floor(grade, sprinted)
	_bank()
	# Save progress now (with the picks it owes), so quitting during the overlay still lands past this floor.
	if not rule.is_gate:
		if fixed_seed == 0:
			RunState.advance_floor()
		_show_message("FLOOR %d / %d CLEARED   %s to spare\n%s" % [rule.floor_in_act, StageRule.FLOORS_PER_ACT, _format_time(time_left), earned])
		get_tree().create_timer(FLOOR_CLEAR_TIME).timeout.connect(_offer_picks)
		return
	if fixed_seed == 0:
		for line in RunState.master_act(grade):
			_pop(line)
		RunState.clear_gate()
	if rule.act == StageRule.ACT_COUNT:
		_show_message("YOU ESCAPED THE DESCENT\n" + earned)
	else:
		_show_message("ACT %d CLEARED\nACT %d  ·  %s  UNLOCKED\n%s" % [rule.act, rule.act + 1, StageRule.ACT_NAMES[rule.act].to_upper(), earned])
	_show_act_cleared()
	var title := "THE TRUE ENDING" if ending == Lore.TRUE_ENDING else "ACT %s  ·  %s" % [MainMenu.ROMAN[rule.act - 1], rule.act_name.to_upper()]
	get_tree().create_timer(ACT_CLEAR_TIME).timeout.connect(_offer_picks if ending.is_empty() else _show_ending.bind(title, ending))

## The ending this Gate plays (plans/06 §2): the true one on a first run from floor 1 through the last Gate, else
## the act's own the first time it falls ("" once seen).
func _gate_ending() -> String:
	if rule.act == StageRule.ACT_COUNT and RunState.start_floor == 1 and MetaState.stat("deep_runs") == 0:
		return Lore.TRUE_ENDING
	return Lore.ACT_ENDINGS[rule.act - 1] if MetaState.stat("clears_act_%d" % rule.act) == 0 else ""

## An ending on a dark page (its art behind, once it exists): read it, then carry on to the Gate's choice.
func _show_ending(title: String, text: String) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_message("")
	var page := ColorRect.new()
	page.name = "Ending"
	page.color = Color(0.0, 0.0, 0.0, 0.94)
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_node("Overlays").add_child(page)
	if ResourceLoader.exists(ENDING_ART):
		var art := TextureRect.new()
		art.texture = load(ENDING_ART)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.modulate.a = 0.35
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		page.add_child(art)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 24)
	page.add_child(column)
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 30)
	heading.add_theme_color_override("font_color", GOLD)
	column.add_child(heading)
	var words := Label.new()
	words.text = text
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.custom_minimum_size.x = ENDING_WIDTH
	words.add_theme_font_size_override("font_size", 19)
	words.add_theme_color_override("font_color", MainMenu.BONE)
	column.add_child(words)
	var carry_on := Button.new()
	carry_on.name = "CarryOn"
	carry_on.text = "CARRY ON   [ENTER]"
	carry_on.flat = true
	carry_on.add_theme_font_size_override("font_size", 20)
	carry_on.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	carry_on.add_theme_color_override("font_focus_color", GOLD)
	carry_on.add_theme_color_override("font_hover_color", GOLD)
	carry_on.pressed.connect(func() -> void:
		page.queue_free()
		_offer_picks())
	column.add_child(carry_on)
	carry_on.grab_focus()
	page.modulate.a = 0.0
	page.create_tween().tween_property(page, "modulate:a", 1.0, 0.6)

## What the run owes before the next floor, one card picker at a time (plans/06 P4): an omen after a
## Shrine or the Sanctuary, the next floor's door (A2), RETURN or DESCEND after a Gate, a run's curse and
## start kit. Then on to the next floor, or the menu once the run is over. A debug floor just reloads.
func _offer_picks() -> void:
	if fixed_seed != 0:
		if rule.is_gate:
			_to_menu()
		else:
			_next_floor()
		return
	if RunState.picks.is_empty():
		if RunState.run_over:
			_to_menu()
		else:
			_next_floor()
		return
	var ids := RunState.pick_options()
	if ids.is_empty():
		RunState.take("")  # every omen in the pool is already yours
		_offer_picks()
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_message("")
	card_choice.offer(_pick_title(), ids)

func _take_pick(id: String) -> void:
	RunState.take(id)
	_offer_picks()

func _pick_title() -> String:
	if RunState.picks[0] == "door":
		var next := StageRule.for_floor(RunState.current_floor)
		return "CHOOSE YOUR DOOR  ·  FLOOR %d / %d" % [next.floor_in_act, StageRule.FLOORS_PER_ACT]
	return PICK_TITLES.get(RunState.picks[0], "")

## Picks owed before this floor plays (a run's curse and start kit, or one a quit left open): offered on a
## dark screen; the floor then loads with them.
func _choose_before_floor() -> void:
	game_state = "choosing"
	var overlays := CanvasLayer.new()
	overlays.name = "Overlays"
	overlays.layer = 10
	add_child(overlays)
	var dark := ColorRect.new()
	dark.color = Color.BLACK
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlays.add_child(dark)
	card_choice = CardChoice.new()
	card_choice.name = "CardChoice"
	card_choice.picked.connect(_take_pick)
	overlays.add_child(card_choice)
	_offer_picks()

func _next_floor() -> void:
	get_tree().reload_current_scene()

func _to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(DeathScreen.MENU_SCENE)

## The act-clear moment in gold; the burst art (once it lands in assets/images/menu/) flares behind it.
func _show_act_cleared() -> void:
	state_label.add_theme_color_override("font_color", GOLD)
	if not ResourceLoader.exists(ACT_CLEARED_ART):
		return
	var burst := TextureRect.new()
	burst.name = "ActClearedBurst"
	burst.texture = load(ACT_CLEARED_ART)
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burst.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	burst.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD  # painted on black: the black vanishes
	burst.material = additive
	burst.set_anchors_preset(Control.PRESET_CENTER_TOP)
	burst.offset_left = -480
	burst.offset_right = 480
	burst.offset_top = 10
	burst.offset_bottom = 330
	burst.pivot_offset = Vector2(480, 160)
	state_label.add_sibling(burst)
	state_label.get_parent().move_child(burst, state_label.get_index())  # behind the words
	var tween := burst.create_tween().set_parallel().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(burst, "modulate:a", 1.0, 0.3).from(0.0)
	tween.tween_property(burst, "scale", Vector2.ONE, 0.6).from(Vector2.ONE * 1.4)

const DEATH_TEXT := {
	"devil": ["THE DEVIL GOT YOU", "It is slow up close: keep walking. It is slower in WAKE: flip to lose it, or stand in a safe circle."],
	"trap": ["THE FLOOR GAVE WAY", "Cracked floors break on the second step. Listen for the creak; look for the cracks."],
	"time": ["CLOCK HIT ZERO", "Dead ends eat time. Grab the keys on the way, not one at a time."],
}

## The death screen teaches the rule and shows how close you were (plans/05 §3.8).
func _lose_game(cause: String = "devil") -> void:
	if game_state == "lost":
		return
	game_state = "lost"
	Engine.time_scale = 1.0
	lose_player.play()
	_stop_tension_audio()
	_show_message("")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_count("deaths")
	_count("deaths_" + cause)
	var news := _bank()  # dying keeps every shard
	# Death ends the run now (quitting here can't buy a retry of this maze); a revive brings it back.
	if fixed_seed == 0:
		RunState.end_run()
	var steps := maxi(exit_dist[world][player_cell.y * layout.size + player_cell.x], 0)
	var floor_progress := clampf(_progress(), 0.0, 1.0)
	var comeback := Lore.voice(cause, MetaState.stat("deaths"), floor_progress, rule.floor_in_act)
	var detail := "%d m from the exit   ·   Act %d, floor %d / %d   ·   best floor %d / %d\n%s" % [
		roundi(steps * CELL_SIZE), rule.act, rule.floor_in_act, StageRule.FLOORS_PER_ACT,
		RunState.best_floor, StageRule.LAST_FLOOR, comeback]
	var can_revive := not snapshot.is_empty() and RunState.revives_left() > 0
	var revive_text := "%d LEFT  ·  [V]" % RunState.revives_left() if not snapshot.is_empty() else "REACH A SAFE CIRCLE FIRST"
	var progress := MetaState.unlock_progress()
	var business := "+%d SHARDS THIS RUN   ·   %s   ·   %s" % [RunState.run_shards + floor_shards,
			"UNLOCK READY" if progress >= 1.0 else "NEXT UNLOCK %d%%" % floori(progress * 100.0), _shortcut_line()]
	if not news.is_empty():
		business += "\n" + "   ·   ".join(news)
	death_screen.show_death(DEATH_TEXT[cause][0], DEATH_TEXT[cause][1], detail, revive_text, can_revive,
			"NEW RUN  ·  ACT %d  ·  [R]" % rule.act, business)

## How far the next act's shortcut is (just the Gate once that act is open; the escape in the last act).
func _shortcut_line() -> String:
	var left := StageRule.floors_to_gate(rule.floor_number)
	var floors := "%d FLOOR%s" % [left, "" if left == 1 else "S"]
	if rule.act == StageRule.ACT_COUNT:
		return floors + " TO THE ESCAPE"
	if MetaState.is_act_unlocked(rule.act + 1):
		return floors + " TO THE GATE"
	return "%s TO THE ACT %d SHORTCUT" % [floors, rule.act + 1]

## Back to the last safe circle you used, with its clock and floor cracks. Max 3 per act.
func _revive() -> void:
	if game_state != "lost" or snapshot.is_empty() or not RunState.use_revive():
		return
	floor_revives += 1
	# Ad hook: a rewarded ad plays here before the revive; premium skips it (plans/ads_managment_prompt.md).
	death_screen.visible = false
	_return_to_circle()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_flash_message("REVIVED   %d left this act" % RunState.revives_left())

## Back to the last safe circle you used (the spawn if none yet) with its clock and floor cracks; it backs off.
func _return_to_circle() -> void:
	var at: Dictionary = snapshot if not snapshot.is_empty() else {"cell": layout.spawn, "time_left": time_left, "traps": traps.states.duplicate()}
	var cell: Vector2i = at["cell"]
	player.global_position = cell_to_world(cell) + Vector3(0, PLAYER_HEIGHT, 0)
	player.velocity = Vector3.ZERO
	camera_pivot.position.y = 0.45
	camera_pivot.rotation.x = pitch
	player.rotation = Vector3(0.0, yaw, 0.0)
	camera.top_level = false
	camera.transform = Transform3D()
	fall_time = -1.0
	camera.fov = feel.base_fov
	_shake(0.0)
	flash_rect.color = Color(1, 1, 1, 0)
	player_cell = cell
	last_player_cell = cell
	player_dist = layout.distances(world, cell)
	time_left = maxf(at["time_left"], REVIVE_MIN_TIME)
	panic = false
	traps.states.assign(at["traps"])
	_refresh_traps()
	var circle := circles.index_at(cell)
	if circle >= 0:
		circles.charge[circle] = circles.capacity
	catch_grace = REVIVE_GRACE
	lunge_left = 0.0
	if devil_active:
		_start_retreat()
	game_state = "playing"

## TRY AGAIN: a new run from this act's first floor, on a new maze (a debug seed just reloads).
func _restart_game() -> void:
	_bank()
	if fixed_seed == 0:
		RunState.start_run(rule.act)
	get_tree().reload_current_scene()

## Push live positions to the minimap (grid cells, floats). Devil distance = current-world path length.
func _refresh_minimap() -> void:
	if minimap == null:
		return
	minimap.world = world
	minimap.exit_open = exit_open
	minimap.devil_awake = devil_active
	minimap.player_pos = Vector2(player.global_position.x, player.global_position.z) / CELL_SIZE
	minimap.devil_pos = Vector2(devil.position.x, devil.position.z) / CELL_SIZE
	var forward := -player.global_transform.basis.z
	minimap.facing = Vector2(forward.x, forward.z).angle()
	var steps := _devil_distance()
	minimap.devil_distance = steps * CELL_SIZE if steps < 999 else -1.0
	var to_exit := exit_dist[world][player_cell.y * layout.size + player_cell.x]
	minimap.exit_distance = to_exit * CELL_SIZE if to_exit >= 0 else -1.0

func _show_message(text: String) -> void:
	if state_label == null:
		return
	state_label.text = text

## A message that clears itself after 2.5 s (unless the game ended meanwhile).
func _flash_message(text: String) -> void:
	_show_message(text)
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if game_state == "playing" and state_label.text == text:
			_show_message(""))

func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * CELL_SIZE, 0, cell.y * CELL_SIZE)

func world_to_cell(position: Vector3) -> Vector2i:
	return Vector2i(round(position.x / CELL_SIZE), round(position.z / CELL_SIZE))
