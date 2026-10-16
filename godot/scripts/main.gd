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
## character2withrig.glb faces +X; this turns it to face -Z (the body's forward).
const PLAYER_MESH_YAW := 90.0
const PLAYER_HEIGHT_RATIO := 0.6
const DEVIL_HEIGHT_RATIO := 0.9
const DEVIL_ENRAGE_MULTIPLIER := 1.2
const DEVIL_ENRAGE_DURATION := 20.0
## A forced flip never drops you closer than this (path cells) to the Devil; it is moved first.
const FAIR_FLIP_DISTANCE := 4
const DEVIL_RETREAT_DISTANCE := 8
## No grab for this long after a flip: no instant catches.
const FLIP_CATCH_GRACE := 0.6
## Through the wall (DevilBrain.thin_wall): from THIN_WALL_LOOKAHEAD s before Flipping Time it slips to the room beside
## you and waits there in silence (re-picking the wall as you move); the warning sounds and it pounds every
## THIN_WALL_POUND s; the flip breaks it through and it reels in the hole for THIN_WALL_STUN (instead of the fair-flip
## teleport). It must be there THIN_WALL_LEAD s before the flip. A big scare, so THIN_WALLS_PER_FLOOR.
const THIN_WALL_LOOKAHEAD := 10.0
const THIN_WALL_STUN := 1.5
const THIN_WALL_POUND := 0.6
const THIN_WALL_LEAD := 1.0
const THIN_WALLS_PER_FLOOR := 1
## No flip coming: it slams the wall once as it passes you on the other side, at most this often.
const KNOCK_COOLDOWN := 10.0
## A blow: a camera jolt that fades out SLAM_FEEL m from the wall, red light through its seams.
const SLAM_SHAKE := 0.06
const SLAM_FEEL := 9.0
const SLAM_LIGHT := 3.0
const SLAM_SFX := "res://assets/audio/sfx_wall_slam.mp3"
const BREAK_SFX := "res://assets/audio/sfx_wall_break.mp3"
## A blow is heard about SLAM_UNIT m off (AudioStreamPlayer3D unit size); the crash of it waking carries WAKE_HEARD.
const SLAM_UNIT := 4.0
const WAKE_HEARD := 30.0
## Waking (user, 12 Oct 2026): it tears out of a wall beside its cell (_burst_out). After a telegraphed wake the camera
## leaves you for it (_start_wake_cut): WAKE_TEAR s while it tears out, WAKE_ROAR s of echoing roar, then a WAKE_RUSH_TIME
## s rush down the last WAKE_RUSH_TAIL m of corridor into your eyes (a cut first if it's farther). Bars WAKE_BARS high.
const WAKE_TEAR := 0.7
const WAKE_ROAR := DevilRig.ROAR_TIME
const WAKE_RUSH_TAIL := 45.0
const WAKE_RUSH_TIME := 1.75
const WAKE_BARS := 0.11
## Seconds into the roar the sound starts: just before the burst (DevilRig.roar_force), after the coil's breath.
const WAKE_ROAR_SOUND := 0.22
const ROAR_SFX := "res://assets/audio/sfx_devil_roar.mp3"
const ECHO_BUS := &"Echo"
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
## Close Call (plans/06 C2): a near miss pays, time slows for a beat and the heart jumps.
const CLOSE_CALL_TIME_SCALE := 0.35
const CLOSE_CALL_SLOWMO := 0.3
const CLOSE_CALL_HEART_PITCH := 1.5
const CLOSE_CALL_HEART_TIME := 1.5
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
## Devil Cam (plans/06 C6): the last TAPE_SECONDS of the hunt, sampled every TAPE_STEP, replayed through its eyes on
## the death screen at REPLAY_SPEED. Its model sits on DEVIL_LAYER so its own camera looks out, not at its skull.
const TAPE_SECONDS := 4.0
const TAPE_STEP := 0.1
const REPLAY_SPEED := 0.75
const DEVIL_LAYER := 1 << 1
## Your own body: the Devil Cams and the trap fall's rim camera see it, your eyes never do (looking down you would see
## the top of your head).
const PLAYER_LAYER := 1 << 2
## Your fists opening a box (BoxHands): your own eyes only, never the Devil Cams.
const HANDS_LAYER := 1 << 3
## Your eye above the body's origin (camera_pivot).
const EYE_HEIGHT := 0.45
const DEVIL_EYE := 2.2
const DEVIL_CAM_SIZE := Vector2(320, 180)
## While it hunts, a smaller live Devil Cam rides in the top-left corner over its distance (user, 9 Oct 2026), which
## turns amber inside DEVIL_METER_WARN.y metres and red, pulsing, inside .x.
const LIVE_CAM_SIZE := Vector2(256, 144)
const DEVIL_METER_WARN := Vector2(10.0, 20.0)
## It sees in the dark: its eye's ambient light and exposure multiplied, the fog thinned, and a red glare from its
## eyes (energy, range, cone degrees) that lights what it looks at, in both Devil Cams and in the maze itself.
const DEVIL_SIGHT := Vector3(6.0, 1.8, 0.4)
const DEVIL_GLARE := Vector3(6.0, 16.0, 50.0)
## Echo Step: a flip's echo sounds this many path tiles from you.
const ECHO_DISTANCE := Vector2i(2, 4)
const REVIVE_GRACE := 3.0
const REVIVE_MIN_TIME := 30.0
const PANIC_TIME := 10.0
const FLOOR_CLEAR_TIME := 1.4
## Beating the Gate: time to read "ACT CLEARED" before the menu.
const ACT_CLEAR_TIME := 3.0
## Mid-floor, R costs the whole run (and sits right by WASD), so a second press must follow this fast.
const RESTART_ARM_TIME := 2.5
## Optional art (plans/06 P1 prompts in assets/images/menu/PROMPTS.md); without it the words stand alone.
const ACT_CLEARED_ART := "res://assets/images/menu/act_cleared_burst.png"
const GOLD := Color(1.0, 0.78, 0.3)
const OMEN_COLOR := Color(0.75, 0.6, 1.0, 0.9)
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
## At the chest you stop this far from it (m) to watch it open.
const CHEST_VIEW_DISTANCE := 1.5
const HEARTBEAT_TILES := 8

const WAKE := FloorLayout.World.WAKE
const NIGHTMARE := FloorLayout.World.NIGHTMARE
## Physics layers: 1 = floor + walls in both worlds, 2 = WAKE-only walls, 3 = NIGHTMARE-only walls.
const LAYER_SHARED := 1
const LAYER_WAKE := 2
const LAYER_NIGHTMARE := 4
## Per-world look, indexed by World.
const FOG_COLORS: Array[Color] = [Color(0.04, 0.07, 0.13), Color(0.2, 0.01, 0.02)]
const FOG_DENSITIES: Array[float] = [0.035, 0.07]
## Ghost Sight (omen): within this many path tiles its glow shows through the walls, this wide (m) at chest height.
const GHOST_SIGHT_TILES := 10
const GHOST_GLOW_SIZE := 1.6
const GHOST_GLOW_COLOR := Color(1.0, 0.12, 0.05)
const AMBIENT_COLORS: Array[Color] = [Color(0.025, 0.04, 0.07), Color(0.09, 0.01, 0.015)]
const GLOW_COLORS: Array[Color] = [Color(0.12, 0.32, 0.55), Color(0.65, 0.05, 0.03)]
const SIGIL_COLORS: Array[Color] = [Color(0.55, 0.9, 1.0), Color(1.0, 0.35, 0.1)]
const MUSIC_DB := -14.0
## Deaf Night's card turns the music down to this.
const SILENT_DB := -80.0
## Per-act look (plans/06 A5): each act turns WAKE's cold light and the walls to its own hue (-1 keeps
## the original), Act 5 drains them to ash, the Abyss bruises them violet; NIGHTMARE stays red, so a flip always reads.
const ACT_HUES: Array[float] = [-1.0, 0.42, 0.76, 0.09, -1.0, 0.83]
const ACT_SATURATION: Array[float] = [1.0, 1.0, 1.0, 1.0, 0.15, 0.5]
## Light on a chest waiting down a dead end, so it can be found in the dark.
const DETOUR_CHEST_GLOW := 0.8
## Keys hide in boxes (KeyBox): you open the one in your cell once it's within this angle of your view (degrees).
const BOX_FACE_ANGLE := 50.0
## A key in its box is drawn this much smaller than KeyPickup.LENGTH (sized to float in a corridor), so it fits.
const BOX_KEY_SCALE := 0.55
## A box stands this far (m) off the wall behind it.
const BOX_WALL_GAP := 0.1
## Opening a box (KeyBox's beats): you kneel KNEEL_GAP (m) before its front, sliding there (KNEEL_PULL per s, at most
## walk speed), the eye sinking KNEEL_DROP and leaning KNEEL_LEAN toward it; once you stand you're up in KNEEL_RISE s.
const KNEEL_GAP := 0.75
const KNEEL_PULL := 8.0
const KNEEL_DROP := 0.95
const KNEEL_LEAN := 0.22
const KNEEL_RISE := 0.25
## The key in your fist pops at this scale (of its own), then flies to the HUD.
const HELD_KEY_SCALE := 0.18
## The body raises the map this fast (per s) in the Devil Cams.
const MAP_RAISE := 3.0
## Delivered box sounds (assets/ASSET_PROMPTS.md §6); until then the floor creak and the floor crack stand in.
const BOX_OPEN_SFX := "res://assets/audio/sfx_box_open.mp3"
const BOX_EMPTY_SFX := "res://assets/audio/sfx_box_empty.mp3"
## The flashlight's shadow bias (depth, normal): lower brings back the stripes on far walls (shadow acne).
const FLASHLIGHT_SHADOW_BIAS := Vector2(0.1, 2.0)
## Delivered art (Art; prompts in assets/ASSET_PROMPTS.md). Textured surfaces: how bright each world's textures show
## (WAKE takes the act's hue), ceilings a shade darker; the trim texture repeats every TRIM_TILE.
const SURFACE_WORLDS: Array[String] = ["wake", "nightmare"]
const SURFACE_TINTS: Array[Color] = [Color(0.62, 0.66, 0.72), Color(0.9, 0.82, 0.82)]
const CEILING_DARKEN := 0.4
const TRIM_TILE := Vector3(CELL_SIZE, 0.6, CELL_SIZE)
## Ceiling lamps (model): the bulb glows in the world's colour this far below the ceiling, inside the cage.
const LAMP_BULB_DROP := 0.35
const LAMP_BULB_RADIUS := 0.06
## Rune circles and the exit circle (decals): metres across, and the circles' own blue.
const CIRCLE_DECAL_SIZE := 2.0
const CIRCLE_COLOR := Color(0.3, 0.65, 1.0)
const EXIT_DECAL_SIZE := 1.9
## NIGHTMARE dressing per floor: blood on floors, claw marks on walls.
const BLOOD_DECALS := 6
const SCRATCH_DECALS := 8
const HANDPRINT_DECALS := 4
## The Sanctuary's altar: its collision box and soft blue light.
const ALTAR_SIZE := Vector3(1.2, 1.0, 0.85)
const ALTAR_LIGHT := Color(0.35, 0.6, 1.0)
## Landmarks (plans/07). Lamps: energy, range; they keep their colour in both worlds and stay lit in a Blackout.
const LANDMARK_LIGHT := Vector2(1.1, 5.0)
## Halo around a landmark bulb, metres across: the far cue (walls are one mesh each, and the Compatibility
## renderer lights a mesh with 8 lights at most, so a lamp's colour barely reaches them).
## It hangs no higher than its own radius below the ceiling, so its top edge never cuts into it.
const LANDMARK_HALO := 0.9
## The flickering lamp drops out twice every this many seconds.
const LANDMARK_FLICKER_BEAT := 2.6
## Glyphs painted on the wall: colour, metres tall, centre height.
const LANDMARK_GLYPH_COLOR := Color(0.75, 0.12, 0.08)
const LANDMARK_GLYPH_SIZE := 0.9
const LANDMARK_GLYPH_Y := 1.5
## Statue and debris stand this far from the cell centre toward a corner, out of the walking line.
const LANDMARK_CORNER := 0.82
const LANDMARK_STATUE_HEIGHT := 2.0
const LANDMARK_DEBRIS_HEIGHT := 0.8
const LANDMARK_CANDLE := Color(1.0, 0.58, 0.25)
## HUD art: the status plate, drawn at the 720x400 art's own shape so its thorned corners never stretch, its gap to
## the screen's top-right corner, and the inset that keeps the icon rows inside its border (left, top, right, bottom).
const PLATE_SIZE := Vector2(380, 211)
const PLATE_MARGIN := Vector2(12, 8)
const PLATE_INSET := Vector4(44, 36, 44, 40)
## Icons on the plate (keys use KeyHud.SLOT_HEIGHT): the main rows, the floor row, a rule card's chip.
const PLATE_ICON := 40.0
const FLOOR_ICON := 30.0
const CARD_CHIP := Vector2(46, 27)
## The flip icon while Flipping Time blocks it.
const FLIP_BLOCKED := Color(1.0, 0.3, 0.25)
## How strong the NIGHTMARE overlay shows (far, near).
const NIGHTMARE_OVERLAY_ALPHA := Vector2(0.35, 0.9)
const HINTS := [["WASD", "MOVE"], ["SHIFT", "SPRINT"], ["F", "FLASHLIGHT"], ["M", "MAP"],
		["ESC", "PAUSE"], ["R R", "RESTART ACT"]]

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
## Skips the fairness check, so a sigil behind it can force a second crossing. Never ship it on.
@export_range(0, 20) var debug_trap_step: int = 0

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
## Things to remember at the maze's decisions (plans/07).
var landmarks: Landmarks
## The flickering landmark lamp and its bulb (null when the floor has none).
var flicker_light: OmniLight3D
var flicker_bulb: StandardMaterial3D
var flicker_halo: MeshInstance3D
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
## Share (0..1) of the feel.sprint_time sprint left; once a sprint ends you rest feel.sprint_recover_time.
var stamina := 1.0
## Seconds before you can sprint again (> 0 = winded).
var rest_left := 0.0
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
## The run's omens (plans/06 P4), folded with the floor's cards.
var heartbeat_tiles := HEARTBEAT_TILES
var night_fog := 1.0
var ghost_sight := false
## Ghost Sight's glow on the Devil, drawn over the walls (null without the omen).
var ghost_glow: MeshInstance3D
## Esc: Resume / Quit to menu over the paused game.
var pause_menu: Control
## Catches the Last Breath omen still turns into a trip back to your last circle this floor.
var last_breath := 0
## The senses omens (plans/06 P7): your beam never gives you away, a flip leaves an echo, a sprint is silent.
var beam_hidden := false
var flip_echo := false
var quiet_sprint := false
## The Director (menace: when the Devil comes) and where the Devil last stepped (it sees ahead of it).
var director: Director
var devil_facing := Vector2i.ZERO
## Devil Cam: [its position, its yaw, your position] every TAPE_STEP while it hunts, and the replay on death.
var tape: Array = []
var devil_cam: SubViewportContainer
## The Long Night (plans/11): the route's par (the medal times), when each key was taken, this run as a ghost's
## samples (RaceGhost), and the week's best run walking beside you.
var race_par := 0.0
var race_splits: Array[float] = []
var race_tape := PackedFloat32Array()
var race_ghost: RaceGhost
var _tape_clock := 0.0
var _replay_time := 0.0
## The top-left corner while it hunts: the live Devil Cam and its distance under it (_update_devil_corner).
var devil_corner: VBoxContainer
var live_cam: SubViewportContainer
var devil_meter: Label
## The torch worn (Altar gear, folded like a card): the beam's shape, and Camera Flashes left this floor.
var beam_energy := 1.0
var beam_range := 1.0
var beam_angle := 1.0
var flash_stuns := 0
## The flip flash worn (Altar gear): its colour, or the world's you land in.
var flip_flash := ""
## Seconds the Devil stays frozen by a Camera Flash (or reels in a wall it broke).
var devil_stun := 0.0
## Through the wall: the wall it goes for (DevilBrain.NOWHERE = none) and the cell it pounds from, time to the next blow,
## whether it has struck this wall yet (for the one teaching line), the cells it last planned from, walls broken this
## floor, time until it may slam one in passing again; the blow's sound, light and dust.
var thin_wall := DevilBrain.NOWHERE
var thin_wall_from := DevilBrain.NOWHERE
var pound_left := 0.0
var pounded := false
var thin_wall_plan := Vector4i(-1, -1, -1, -1)
var thin_walls := 0
var knock_left := 0.0
var slam_player: AudioStreamPlayer3D
var slam_light: OmniLight3D
var slam_dust: CPUParticles3D
## The wake cut: seconds into it (-1 = none), where the Devil starts (in the stone), the shot and what it looks at, the
## rush back to you (points, length, seconds); the roar, its fill light and the letterbox.
var wake_t := -1.0
var wake_devil_from := Vector3.ZERO
var wake_cam_at := Vector3.ZERO
var wake_cam_look := Vector3.ZERO
var wake_path := PackedVector3Array()
var wake_path_length := 0.0
var wake_rush := 0.0
var roar_player: AudioStreamPlayer
var wake_light: OmniLight3D
var letterbox: CanvasLayer
var omens_label: RichTextLabel
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
var breath_calm: AudioStreamPlayer
var breath_heavy: AudioStreamPlayer
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
## The map in your hands (M), the only map: no minimap on screen, you navigate from memory. has_map is false on a no-map
## floor. When it last came out and went back (elapsed s; -1 = not yet), for the playtest log.
var paper_map: PaperMap
var has_map := true
var map_opened_at := 0.0
var map_closed_at := -1.0
var player_cell := Vector2i(1, 1)
var devil_cell := Vector2i.ZERO
## Where the Devil backs off to while devil_retreating (a safe circle sent it away).
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
## The boxes the keys hide in (layout.boxes order) and which you've opened (the paper map shares the array).
var box_nodes: Array[KeyBox] = []
var box_opened: Array[bool] = []
## Kneeling at a box (_tick_box): the box (-1: on your feet), seconds into it (KeyBox's beats), the box your body is
## posed at while you rise (-1: none), how far down you are, the key waiting for your left fist (-1: none).
var opening_box := -1
var open_t := 0.0
var kneel_box := -1
var kneel_w := 0.0
var key_in_box := -1
var box_hands: BoxHands
## Your body in the Devil Cams: its turn from your view toward where it walks or the box (DevilRig.heading), its gait
## speed (negative backing away), how far the map is up (0..1).
var body_turn := 0.0
var gait_speed := 0.0
var map_w := 0.0
## Shown while a closed box is in reach (_box_in_reach).
var open_prompt: TextureRect
var exit_open := false
var env: Environment
var world_lights: Array[OmniLight3D] = []
var wake_walls: Node3D
var nightmare_walls: Node3D
var trim_material: StandardMaterial3D
var light_material: StandardMaterial3D
var accent_material: StandardMaterial3D
var ceiling_material: StandardMaterial3D
## Walls both worlds share: they change texture with the world (the others only ever show one).
var shared_wall_material: StandardMaterial3D
## The delivered circle and exit decals are lit by their colour, not emission (_refresh_circles, _set_exit_look).
var circle_decals := false
var exit_decal := false
var dressing: Node3D
var banner: TextureRect
var nightmare_overlay: TextureRect
var warning_overlay: TextureRect
var goal_material: StandardMaterial3D
var goal_light: OmniLight3D
## The status plate (top right): floor count, world icon + clock, the flip, the chest once it opens.
var floor_label: Label
var world_icon: TextureRect
var world_icons: Array[Texture2D] = []
var clock_label: Label
var flip_icon: TextureRect
var stamina_bar: ProgressBar
var flip_label: Label
var chest_icon: TextureRect
var state_label: Label
var warning_label: Label
var flash_rect: ColorRect
var calm_player: AudioStreamPlayer
var intense_player: AudioStreamPlayer
var win_player: AudioStreamPlayer
var lose_player: AudioStreamPlayer
var flip_player: AudioStreamPlayer
var warning_player: AudioStreamPlayer
var sigil_player: AudioStreamPlayer
var box_open_player: AudioStreamPlayer
var box_empty_player: AudioStreamPlayer
var devil_approach_player: AudioStreamPlayer
var devil_approach_playing := false
var camera: Camera3D
var flashlight: SpotLight3D
var footstep_player: AudioStreamPlayer
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
## Gameplay picks (where the Devil reappears after a flip, the Echo Step's echo) draw from the floor's seed, apart from
## rng's flicker, so one maze plays the same for everyone (the Daily, the Long Night) at any frame rate.
var fair_rng := RandomNumberGenerator.new()
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
		if RunState.run_over and RunState.is_daily():
			RunState.start_daily(true)
		elif RunState.run_over and RunState.is_race():
			RunState.start_race()
		elif RunState.run_over:
			RunState.start_run(RunState.act())
		if not RunState.picks.is_empty():
			_choose_before_floor()
			return
	rule = StageRule.for_floor(RunState.current_floor)
	seed_value = fixed_seed if fixed_seed != 0 else RunState.floor_seed()
	fair_rng.seed = hash([seed_value, "fair"])
	print("FearFlip floor %d seed: %d" % [rule.floor_number, seed_value])
	_fold_cards()
	layout = FloorLayout.generate(seed_value, rooms if rooms > 0 else roundi(RunState.mod("rooms", rule.rooms)),
			roundi(RunState.mod("keys", Race.KEYS if RunState.is_race() else FloorLayout.SIGIL_COUNT)), rule.box_empties)
	flip = FlipSystem.new(seed_value)
	flip.first_forced_at = RunState.mod("flip_interval", rule.first_forced_at)
	flip.arm()  # no flip button: the first Flipping Time comes at a random moment
	flip.forced_interval_min = RunState.mod("flip_interval", rule.forced_interval_min)
	flip.forced_interval_max = RunState.mod("flip_interval", rule.forced_interval_max)
	flip.min_forced_interval = RunState.mod("flip_interval", rule.min_forced_interval)
	flip.forced_duration_min = RunState.mod("flip_duration", flip.forced_duration_min)
	flip.forced_duration_max = RunState.mod("flip_duration", flip.forced_duration_max)
	flip.warning_time = rule.flip_warning
	flip.flipped.connect(_on_flipped)
	flip.flipping_time_warning.connect(_on_flipping_time_warning)
	route = layout.route(layout.spawn, layout.exit)
	from_spawn = layout.distances(FloorLayout.ANY, layout.spawn)
	exit_dist = [layout.distances(WAKE, layout.exit), layout.distances(NIGHTMARE, layout.exit)]
	circles = SafeCircles.new()
	circles.capacity = RunState.mod("circle_time", rule.safe_circle_protect_s)
	circles.single_use = rule.safe_circle_single_use
	circles.place(route, roundi(RunState.mod("circles", rule.safe_circle_count)) + roundi(RunState.mod("extra_circles", 0.0)), func(cell: Vector2i) -> bool:
		return layout.is_open(WAKE, cell) and layout.is_open(NIGHTMARE, cell) and not layout.boxes.has(cell) and cell != layout.devil_spawn)
	traps = TrapField.new()
	var excluded: Array[Vector2i] = [layout.devil_spawn]
	excluded.append_array(layout.boxes)
	excluded.append_array(circles.cells)
	var trap_rng := RandomNumberGenerator.new()
	trap_rng.seed = seed_value
	traps.place(layout, route, roundi(RunState.mod("traps", rule.trap_count)), excluded, rule.dead_end_traps, trap_rng)
	traps.holds = roundi(RunState.mod("feather", 0.0))
	traps.creak_range = roundi(RunState.mod("creak_range", 1.0))
	if debug_trap_step > 0 and debug_trap_step < route.size() - 1 and not excluded.has(route[debug_trap_step]):
		traps.add(route[debug_trap_step])
	# Chests and the Altar sit down dead ends, which are never landmark cells.
	var landmark_free: Array[Vector2i] = [layout.spawn, layout.exit]
	landmark_free.append_array(excluded)
	landmark_free.append_array(traps.cells)
	landmarks = Landmarks.new(layout, seed_value, landmark_free)
	tour_m = _tour_tiles() * CELL_SIZE
	time_left = rule.time_budget(tour_m, feel.walk_speed, RunState.mod("clock", 1.0)) + RunState.mod("time_bonus", 0.0)
	if RunState.is_race():
		time_left = INF  # its clock counts up instead: no time limit, the Devil is the threat
	brain = DevilBrain.new()
	director = Director.new(seed_value)
	director.hint_stretch = RunState.mod("hint_stretch", 1.0)
	player_cell = layout.spawn
	last_player_cell = player_cell
	visited[player_cell] = true
	brain.record(player_cell)
	devil_cell = layout.devil_spawn
	devil_target = devil_cell
	prev_devil_cell = devil_cell
	player_dist = layout.distances(world, player_cell)
	_build_environment()
	_build_audio()
	_build_devil_fx()
	_build_maze()
	_build_player()
	_build_goal()
	_build_boxes()
	_build_circles()
	_build_traps()
	_build_detour_chests()
	_build_altar()
	_build_dressing()
	_build_landmarks()
	_build_devil()
	_build_hud()
	if RunState.is_race():
		_start_race()
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
	beam_hidden = RunState.mod("beam_hidden", 0.0) > 0.0
	flip_echo = RunState.mod("flip_echo", 0.0) > 0.0
	quiet_sprint = RunState.mod("quiet_sprint", 0.0) > 0.0
	beam_energy = RunState.mod("beam_energy", 1.0)
	beam_range = RunState.mod("beam_range", 1.0)
	beam_angle = RunState.mod("beam_angle", 1.0)
	flash_stuns = roundi(RunState.mod("flash_stun", 0.0))
	flip_flash = MetaState.wearing("flash")
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
	if RunState.is_race():
		var keys := layout.sigils.size()
		var line := "%d KEYS  ·  ONE MAZE FOR EVERYONE  ·  BEAT THE DEVIL: %s" % [keys, Race.format(Race.medal_times(race_par)["devil"])]
		if Race.best > 0.0:
			line = "%d KEYS  ·  YOUR BEST %s  ·  YOUR GHOST RUNS IT WITH YOU" % [keys, Race.format(Race.best)]
		return "THE LONG NIGHT  #%d\n%s" % [RunState.race_week, line]
	if RunState.is_daily():
		return "%s  ·  FLOOR %d / %d\n%s" % [_daily_name(), RunState.daily_floor, Daily.FLOORS,
				"PRACTICE  ·  NOTHING IS BANKED" if RunState.mode == "practice" else "ONE TRY  ·  MAKE IT COUNT"]
	var lines: Array[String] = ["%s  ·  %s" % [rule.act_name.to_upper(), _where(rule)]]
	if rule.is_sanctuary:
		lines.append("SANCTUARY  ·  NOTHING HUNTS YOU HERE")
	elif rule.is_gate:
		lines.append("THE GATE  ·  ESCAPE IT TO CLEAR ACT %d" % rule.act)
	if RunState.rank > 0:
		lines.append("NIGHTMARE RANK %d" % RunState.rank)
	return "\n".join(lines)

## Where a floor sits: "FLOOR 3 / 10" in an act, "DEPTH 7" in the Abyss (plans/06 P8).
func _where(of: StageRule) -> String:
	if of.act == StageRule.ABYSS_ACT:
		return "DEPTH %d" % of.floor_in_act
	return "FLOOR %d / %d" % [of.floor_in_act, StageRule.FLOORS_PER_ACT]

func _process(delta: float) -> void:
	if player == null or get_tree().paused:
		return  # no floor yet (the pick screen), or paused
	if game_state == "waking":
		_tick_wake(delta)  # the world holds still while the camera is away
		return
	_update_flashlight(delta)
	_flicker_landmark()
	_animate_devil(delta)
	_update_devil_corner()
	_update_ghost_glow()
	if devil_cam != null:
		_replay(delta)
	var tilt := deg_to_rad(INVERT_TILT_DEGREES) if flip.forced_active and game_state == "playing" and not Settings.reduce_motion else 0.0
	camera_pivot.rotation.z = lerpf(camera_pivot.rotation.z, tilt, clampf(4.0 * delta, 0.0, 1.0))
	if game_state == "dying":
		_animate_fall(delta)
	if game_state != "playing":
		if paper_map != null and paper_map.is_up():
			_close_map("end")
			camera.rotation = Vector3(0.0, 0.0, camera.rotation.z)
		_abandon_box()
		return
	_record_tape(delta)
	# The head turns toward the back pocket while the hand reaches for the map; the map snaps shut near the Devil.
	camera.rotation = Vector3(-paper_map.dip, -paper_map.dip * 0.6, camera.rotation.z)
	_tick_box(delta)
	if paper_map.opening and _map_unsafe():
		_close_map("devil")
	elapsed += delta
	if RunState.is_race():
		_tick_race(delta)
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
	if _devil_close():
		chased_time += delta
	if not panic and time_left <= PANIC_TIME:
		panic = true
		alarm_player.play()
	_update_hud()
	_refresh_minimap()
	_update_devil_audio()
	_update_breath(delta)
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
	if move_input != Vector2.ZERO:
		_stand_up()  # never stuck on your knees
	var direction := player.transform.basis * Vector3(move_input.x, 0.0, move_input.y)
	var reading := paper_map.is_up()  # the map in your hands: a slow walk, no sprint
	var sprinting := Input.is_action_pressed("sprint") and move_input != Vector2.ZERO and not reading and rest_left <= 0.0
	sprinted = sprinted or sprinting
	_tick_breath(sprinting, delta)
	var target_speed := feel.walk_speed * (feel.sprint_multiplier if sprinting else 1.0)
	if reading:
		target_speed *= feel.map_walk_ratio
	var horizontal_velocity := Vector3(player.velocity.x, 0.0, player.velocity.z)
	var rate := feel.acceleration if move_input != Vector2.ZERO else feel.friction
	if not player.is_on_floor():
		rate *= feel.air_control
	horizontal_velocity = horizontal_velocity.move_toward(direction * target_speed, rate * delta)
	if opening_box >= 0:
		horizontal_velocity = _kneel_glide()
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
	_update_head_bob(h_speed if opening_box < 0 and kneel_w <= 0.0 else 0.0, sprinting, delta)  # no steps sliding onto your knees
	if player_rig != null:
		_pose_player(real_velocity, delta)

## One sprint lasts up to feel.sprint_time; when it ends (run dry or let go) you rest feel.sprint_recover_time.
func _tick_breath(sprinting: bool, delta: float) -> void:
	if rest_left > 0.0:
		rest_left = maxf(rest_left - delta, 0.0)
		if rest_left == 0.0:
			stamina = 1.0
	elif sprinting:
		stamina = maxf(stamina - delta / feel.sprint_time, 0.0)
		if stamina == 0.0:
			rest_left = feel.sprint_recover_time
	elif stamina < 1.0:
		rest_left = feel.sprint_recover_time  # let go mid-sprint: that sprint is spent

func _unhandled_input(event: InputEvent) -> void:
	if game_state == "waking":
		if event.is_pressed() and not event.is_echo():
			_end_wake_cut()  # any key or button skips it
		return
	# Not while the keys turn in the chest either: one stray R there would throw the cleared floor away.
	if event.is_action_pressed("restart") and not game_state in ["dying", "won", "choosing", "unlocking"]:
		if game_state == "playing" and not restart_armed:
			restart_armed = true
			_flash_message("PRESS R AGAIN: RUN IT AGAIN FROM THE START" if RunState.is_race() else "PRESS R AGAIN: RESTART ACT %d ON A NEW MAZE" % rule.act)
			get_tree().create_timer(RESTART_ARM_TIME).timeout.connect(_disarm_restart)
			return
		get_tree().paused = false
		_restart_game()
		return
	if event.is_action_pressed("pause") and card_choice != null and card_choice.is_picking():
		_to_menu()  # the choice is saved: the run offers it again when it resumes
		return
	if game_state != "playing":
		return
	if event.is_action_pressed("pause"):
		_toggle_pause()
		return
	if get_tree().paused:
		if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_Q:
			_to_menu()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_apply_look(-motion.relative.x * feel.mouse_sensitivity, -motion.relative.y * feel.mouse_sensitivity)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("interact"):
		var box := _box_in_reach()
		if box >= 0:
			_open_box(box)
	elif event.is_action_pressed("flashlight"):
		if flash_stuns > 0:
			if not paper_map.is_up():  # both hands are on the map
				_camera_flash()
			return
		flashlight_on = not flashlight_on
		flashlight.visible = flashlight_on
	elif event.is_action_pressed("map"):
		_toggle_map()
	elif OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F9:
		_debug_thin_wall()

## Flipping Time inverts movement (the 2D FearFlip rule): W goes back, A goes right, and so on.
func _move_input() -> Vector2:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back", feel.stick_deadzone)
	return -input if flip.forced_active else input

## Mouse and stick both land here, so the player's sensitivity and invert cover both.
func _apply_look(yaw_delta: float, pitch_delta: float) -> void:
	if mirror and world == NIGHTMARE:
		yaw_delta = -yaw_delta  # Mirror Night: on top of Flipping Time's inverted steps, the look turns the wrong way
	var invert := -1.0 if Settings.invert_y else 1.0
	yaw += yaw_delta * Settings.sensitivity
	pitch = clampf(pitch + pitch_delta * Settings.sensitivity * invert, -feel.max_pitch, feel.max_pitch)
	player.rotation.y = yaw
	camera_pivot.rotation.x = pitch

func _toggle_pause() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
	pause_menu.visible = paused
	if paused:
		(pause_menu.find_child("Resume", true, false) as Control).grab_focus()

## Alt-tab, or a browser tab switched away, pauses the floor: never left running blind.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_inside_tree() and player != null and game_state == "playing" \
			and not get_tree().paused:
		_toggle_pause()

## The second R never came: back to normal.
func _disarm_restart() -> void:
	restart_armed = false

func _update_head_bob(h_speed: float, sprinting: bool, delta: float) -> void:
	var on_floor := player.is_on_floor()
	var old_phase := step_phase
	step_phase = feel.advance_step_phase(step_phase, h_speed, delta, on_floor)
	if PlayerFeel.crossed_step(old_phase, step_phase) or (on_floor and not was_on_floor):
		_play_footstep(sprinting)
	was_on_floor = on_floor
	var target_intensity := clampf(h_speed / feel.walk_speed, 0.0, 1.5) if on_floor else 0.0
	bob_intensity = lerpf(bob_intensity, target_intensity, clampf(feel.bob_blend_speed * delta, 0.0, 1.0))
	camera.position = Vector3.ZERO if Settings.reduce_motion else feel.bob_offset(step_phase, bob_intensity)
	if paper_map.is_up():
		paper_map.bob = -camera.position  # the map in your hands lags each step
	var running := sprinting and h_speed > feel.walk_speed * 1.05
	breath_time += delta * (feel.sprint_breath_rate if running else feel.breath_rate)
	var target_fov := feel.base_fov + sin(breath_time * TAU) * feel.breath_fov_amplitude
	if running:
		target_fov += feel.sprint_fov_boost
	camera.fov = lerpf(camera.fov, target_fov, clampf(feel.fov_blend_speed * delta, 0.0, 1.0))

func _play_footstep(sprinting: bool) -> void:
	_noise(player_cell, DevilBrain.HEAR_SPRINT_TILES if sprinting and not quiet_sprint else DevilBrain.NOISE_WALK)
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

## True if the player's capsule footprint is open in `target_world` (a flip would not land in a wall): no wall cell of
## that world within PLAYER_RADIUS of you. A circle, not a square: rounding a corner, the pillar diagonal to you is clear.
func _spot_open(target_world: int) -> bool:
	var at := Vector2(player.global_position.x, player.global_position.z)
	var here := world_to_cell(player.global_position)
	for y in range(-1, 2):
		for x in range(-1, 2):
			var cell := here + Vector2i(x, y)
			var low := (Vector2(cell) - Vector2(0.5, 0.5)) * CELL_SIZE
			if not layout.is_open(target_world, cell) and at.distance_to(at.clamp(low, low + Vector2.ONE * CELL_SIZE)) < PLAYER_RADIUS:
				return false
	return true

## The map stays in your hands through a flip (plans/10 §4: 20 of 52 closes were flips, 7 reopened within 3 s).
## Only the Devil close (_map_unsafe) snaps it shut.
func _on_flipped(new_world: int, forced: bool) -> void:
	_apply_world(new_world)
	_stand_up()
	if player_rig != null:
		player_rig.startle(1.0)
	if not flip_echo:
		_noise(player_cell, DevilBrain.NOISE_FLIP)
	elif _hears(player_cell, DevilBrain.NOISE_FLIP):
		brain.sense_left = 0.0  # it heard the flip, but chases its echo instead of you
		brain.investigate(_cell_near_player(ECHO_DISTANCE.x, ECHO_DISTANCE.y))
	_count("flips")
	if forced:
		_count("forced_flips")
	if new_world == WAKE:
		_count("nightmares")  # a Flipping Time ridden out
	flip_player.play()
	warning_label.visible = false
	if warning_overlay != null:
		warning_overlay.visible = false
	var tween := create_tween().set_parallel()
	camera.rotation.z = 0.0
	if not Settings.reduce_motion:
		tween.tween_property(camera, "rotation:z", TAU, FLIP_ROLL_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_screen_flash(Color(Unlocks.item(flip_flash).get("color", SIGIL_COLORS[new_world]), 0.6))
	tween.tween_property(flash_rect, "color:a", 0.0, 0.3)
	tween.chain().tween_callback(func() -> void: camera.rotation.z = 0.0)
	# It follows you across worlds: re-path on the new walls, never a catch on the flip itself.
	player_dist = layout.distances(world, player_cell)
	catch_grace = FLIP_CATCH_GRACE
	lunge_left = 0.0
	_move_devil_into_world()
	if not _breach_thin_wall() and forced:
		_keep_devil_fair()

func _on_flipping_time_warning() -> void:
	warning_player.play()
	warning_label.visible = true
	if warning_overlay != null:
		warning_overlay.visible = true

## Swap everything that differs between worlds. Called on every flip and once at start.
func _apply_world(new_world: int) -> void:
	world = new_world
	var nightmare := world == NIGHTMARE
	player.collision_mask = LAYER_SHARED | (LAYER_NIGHTMARE if nightmare else LAYER_WAKE)
	wake_walls.visible = not nightmare
	nightmare_walls.visible = nightmare
	env.fog_light_color = fog_colors[world]
	env.fog_density = FOG_DENSITIES[world] * fog_factor * (night_fog if nightmare else 1.0)
	env.ambient_light_color = ambient_colors[world]
	trim_material.emission = glow_colors[world] * 0.3
	light_material.emission = glow_colors[world] if light_energy > 0.0 else Color.BLACK
	accent_material.emission = glow_colors[world] * 0.2
	_dress(floor_material, "floor", world)
	_dress(ceiling_material, "ceiling", world)
	_dress(shared_wall_material, "wall", world)
	if dressing != null:
		dressing.visible = nightmare
	if nightmare_overlay != null:
		nightmare_overlay.visible = nightmare
	for light in world_lights:
		light.light_color = glow_colors[world]
	devil.visible = devil_active
	var tween := create_tween().set_parallel()
	tween.tween_property(calm_player, "volume_db", -60.0 if nightmare else music_db, 0.6)
	tween.tween_property(intense_player, "volume_db", music_db if nightmare else -60.0, 0.6)
	world_icon.texture = world_icons[world]
	clock_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4) if nightmare else Color(0.65, 0.95, 1.0))
	_devil_eye(live_cam).environment = _devil_sight()  # the live Devil Cam sees this world's fog
	_refresh_minimap()

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
	devil_cell = options[fair_rng.randi_range(0, options.size() - 1)]
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

# --- Boxes, keys, exit, Devil ----------------------------------------------

## The closed box in your cell that you're facing (within BOX_FACE_ANGLE of your view: the grid decides, not physics),
## else -1. None while both hands hold the map.
func _box_in_reach() -> int:
	var i := layout.boxes.find(player_cell)
	if i < 0 or box_opened[i] or paper_map.is_up():
		return -1
	var forward := -camera.global_transform.basis.z
	var to_box := box_nodes[i].global_position - camera.global_position
	return i if Vector2(forward.x, forward.z).normalized().dot(Vector2(to_box.x, to_box.z).normalized()) > cos(deg_to_rad(BOX_FACE_ANGLE)) else -1

## Click: you kneel at it and your fist works the lid loose (_tick_box); _reveal_box shows what's inside. Reduce Motion
## skips the kneel: the lid just comes up.
func _open_box(i: int) -> void:
	box_opened[i] = true
	if Settings.reduce_motion:
		_start_lid(i)
		return
	opening_box = i
	kneel_box = i
	open_t = 0.0

## The lid creaks loose (it hears that, if it's awake and near) and swings up.
func _start_lid(i: int) -> void:
	box_nodes[i].open()
	box_open_player.play()
	_noise(player_cell, DevilBrain.NOISE_BOX)

## The lid is up: its key is yours (your left fist takes it if you're still kneeling there), or there's nothing but
## dust.
func _reveal_box(i: int) -> void:
	var key := layout.sigils.find(layout.boxes[i])
	if key >= 0:
		if opening_box == i:
			key_in_box = key
		else:
			_take_key(key)
		return
	box_nodes[i].puff()
	box_empty_player.play()
	_flash_message("EMPTY")
	_refresh_minimap()

## Kneeling at a box (KeyBox's beats; user, 15 Oct 2026): the lid starts when your right fist takes it, the key comes
## up in your left and flies to the HUD from there. Your view sinks and turns to the box while your fists work, and
## rises again once you're done or stand.
func _tick_box(delta: float) -> void:
	if opening_box >= 0:
		open_t += delta
		if open_t >= KeyBox.GRIP_AT and not box_nodes[opening_box].is_open:
			_start_lid(opening_box)
		if key_in_box >= 0 and open_t >= KeyBox.FLY_AT:
			_take_key_from_fist()
		if open_t >= KeyBox.END:
			opening_box = -1
	kneel_w = KeyBox.kneel_at(open_t) if opening_box >= 0 else move_toward(kneel_w, 0.0, delta / KNEEL_RISE)
	if kneel_w <= 0.0:
		kneel_box = -1
	camera_pivot.position = Vector3(0.0, EYE_HEIGHT, 0.0)
	if kneel_box < 0:
		box_hands.visible = false
		return
	var box := box_nodes[kneel_box]
	camera_pivot.position += Vector3.DOWN * KNEEL_DROP * kneel_w + player.global_basis.inverse() * (-box.global_basis.z * KNEEL_LEAN * kneel_w)
	var aim := Basis.looking_at(box.inside_point() - camera.global_position)
	camera.quaternion = camera.quaternion.slerp((camera_pivot.global_basis.inverse() * aim).get_rotation_quaternion(), kneel_w)
	var holding := key_in_box >= 0 and open_t >= KeyBox.TAKE_AT
	box_hands.pose(camera.global_transform, box, open_t, kneel_w, layout.sigils.has(layout.boxes[kneel_box]),
			Color(SIGIL_COLORS[layout.sigil_worlds[key_in_box]], 1.0) if holding else Color(0, 0, 0, 0))

## The key comes out of your fist: it pops there and flies to the HUD.
func _take_key_from_fist() -> void:
	var key := key_in_box
	key_in_box = -1
	if box_hands.visible:
		sigil_nodes[key].global_position = box_hands.key_point()
		sigil_nodes[key].scale = Vector3.ONE * HELD_KEY_SCALE
	_take_key(key)

## Up off your knees at once (you moved, it flipped, it lunged, the map came out): the lid still comes up and a key
## in sight is still yours.
func _stand_up() -> void:
	if opening_box < 0:
		return
	var i := opening_box
	opening_box = -1
	if not box_nodes[i].is_open:
		_start_lid(i)
	if key_in_box >= 0:
		_take_key_from_fist()

## The floor stopped while you knelt (caught, fell): a lid your fist hadn't touched stays shut and the box can be
## opened again after a revive; a key already in sight is yours, as when you stand.
func _abandon_box() -> void:
	if opening_box >= 0 and not box_nodes[opening_box].is_open:
		box_opened[opening_box] = false
		opening_box = -1
	_stand_up()
	kneel_box = -1
	kneel_w = 0.0
	if box_hands != null:
		box_hands.visible = false

## Onto your knees before the box: the body slides KNEEL_GAP before its front.
func _kneel_glide() -> Vector3:
	var box := box_nodes[opening_box]
	var to := box.global_position + box.global_basis.z * KNEEL_GAP - player.global_position
	return (Vector3(to.x, 0.0, to.z) * KNEEL_PULL).limit_length(feel.walk_speed)

## Your body (the Devil Cams see it): it turns toward where it walks or backs away (DevilRig.heading), its head on
## where you look; it kneels at a box with its hands on it and raises the map while you read.
func _pose_player(velocity: Vector3, delta: float) -> void:
	var fear := clampf(1.0 - float(_devil_distance()) / heartbeat_tiles, 0.0, 1.0) if devil_active else 0.0
	var winded := 1.0 if rest_left > 0.0 else 1.0 - stamina
	var gait := DevilRig.heading(player.global_basis.inverse() * velocity)
	var turn := gait.x
	if kneel_box >= 0:
		turn = lerp_angle(turn, wrapf(box_nodes[kneel_box].rotation.y - yaw, -PI, PI), kneel_w)
	body_turn = lerp_angle(body_turn, turn, clampf(DEVIL_TURN_SPEED * 0.5 * delta, 0.0, 1.0))
	gait_speed = gait.y
	map_w = move_toward(map_w, 1.0 if paper_map.is_up() else 0.0, delta * MAP_RAISE)
	player_mesh.rotation.y = deg_to_rad(PLAYER_MESH_YAW) + body_turn
	_pose_body(player_rig.flee(gait_speed, delta, fear, winded, Vector2(-body_turn, pitch)), kneel_box, open_t, kneel_w, map_w)

## After the gait (`y`, its vertical offset): the kneel at box `i` (`t` s in, `w` down) and the map (`map_up`, 0..1).
## Live and in the Devil Cam replay.
func _pose_body(y: float, i: int, t: float, w: float, map_up: float) -> void:
	player_rig.hold_map(map_up)
	if i >= 0 and w > 0.0:
		y = lerpf(y, player_rig.kneel(w), w)
	player_mesh.position.y = PLAYER_MESH_Y + y  # before the reach: it aims from where the body really is
	if i < 0 or w <= 0.0:
		return
	var box := box_nodes[i]
	var left := KeyBox.left_hand(t, layout.sigils.has(layout.boxes[i]))
	var held := box.inside_point().lerp(player_rig.before_eyes(), left.y)
	player_rig.reach("Right", box.grip_point(), w * KeyBox.lid_reach(t))
	player_rig.grip("Right", KeyBox.lid_grip(t))
	player_rig.reach("Left", held, w * left.x)
	player_rig.grip("Left", left.z)
	player_rig.watch(held, w)

func _take_key(i: int) -> void:
	if sigil_collected[i]:
		return
	sigil_collected[i] = true
	sigil_nodes[i].visible = true
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
	if RunState.is_race():
		_race_split()
	_refresh_minimap()

func _open_exit() -> void:
	exit_open = true
	enrage_left = DEVIL_ENRAGE_DURATION
	_noise(player_cell, 1 << 20)  # it hears the last key from anywhere
	director.menace = maxf(director.menace, Director.PEAK_AT)
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
	_screen_flash(Color(1.0, 0.85, 0.5, 0.55))
	var tween := create_tween()
	tween.tween_property(flash_rect, "color", Color(1.0, 0.85, 0.5, 0.0), 0.6)
	tween.tween_callback(_win_game).set_delay(0.2)

## Seconds per cell: DevilBrain's rubber band (far = faster, close = slower), enraged once the exit opens.
func _devil_step_interval() -> float:
	var enraged := enrage_left > 0.0
	var ratio := rule.devil_base_ratio * devil_speed * DevilBrain.WORLD_SPEED[NIGHTMARE if follow_flips else world] * (DEVIL_ENRAGE_MULTIPLIER if enraged else 1.0)
	var speed := DevilBrain.speed(_devil_distance(), feel.walk_speed, feel.walk_speed * feel.sprint_multiplier, ratio, enraged)
	if not devil_retreating and not (director.phase == Director.Phase.PEAK and brain.mode() == "chase"):
		speed = minf(speed, DevilBrain.CALM_SPEEDS[brain.mode()])  # before the peak it prowls, it doesn't run
	return CELL_SIZE / speed

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
	var in_sight := devil_active and _devil_distance() <= DevilBrain.SIGHT_TILES and DevilBrain.line_of_sight(layout, world, devil_cell, player_cell)
	var at_wall := thin_wall != DevilBrain.NOWHERE and devil_cell == thin_wall_from
	if moved.length_squared() > 0.000001:
		face = moved
	elif at_wall:
		face = cell_to_world(thin_wall) - devil.position  # at the wall, staring through it at you; claws up once it pounds
	elif in_sight:
		face = player.global_position - devil.position  # paused but sees you: turn to track you
	if face != Vector3.ZERO:
		devil.rotation.y = lerp_angle(devil.rotation.y, atan2(face.x, face.z), clampf(DEVIL_TURN_SPEED * delta, 0.0, 1.0))
	var speed := moved.length() / delta if delta > 0.0 else 0.0
	# Its head stays on you while you're in sight; one tile away the claws come up, at a lunge they rake.
	var reach := 1.0 if lunge_left > 0.0 or (at_wall and flip.warning_active) else (0.4 if in_sight and _devil_distance() <= 1 else 0.0)
	devil_mesh.position.y = -DEVIL_Y + devil_rig.prowl(speed, delta, camera.global_position if in_sight or at_wall else Vector3.INF, reach)

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
	var sees := _devil_sees()
	brain.sense(sees, false, delta)
	var gap := _devil_distance()
	# It never backs off at RELAX: past the peak it just slows to a prowl (_devil_step_interval).
	if director.advance(delta, sees, gap <= Director.NEAR_TILES, gap <= Director.HEARD_TILES):
		brain.sense(false, true, 0.0)  # a Director hint: it catches your scent and picks up the pace
	devil_timer += delta
	# Next cell only once the body is on its current cell centre: it walks corridors, never cuts a wall corner.
	if devil_timer >= _devil_step_interval() and devil.position.distance_to(_devil_world_position()) < 0.05:
		devil_timer = 0.0
		_step_devil()
	_tick_wall(delta)
	_check_catch(delta)

## One cell along the BFS shortest path to you (or to its retreat spot), through open cells only.
func _step_devil() -> void:
	prev_devil_cell = devil_cell
	if devil_retreating and steps_since_retreat >= rule.devil_respawn_steps and not circles.protects(player_cell):
		devil_retreating = false
	# ponytail: an echo is always reachable while both worlds share one maze (FloorLayout.NIGHTMARE_CHANGE = 0). Above 0
	# a flip can wall one off and it stands frozen until it senses you: then drop an echo it can't reach (BFS from
	# devil_cell) before stepping. You are always reachable (_move_devil_into_world).
	devil_cell = layout.next_step(world, devil_cell, devil_target if devil_retreating else _devil_goal())
	if devil_cell != prev_devil_cell:
		devil_facing = devil_cell - prev_devil_cell

## Where it walks: always at you (user, 9 Oct 2026), unless an Echo Step echo draws it aside. With Flipping Time coming
## it may take the wall beside you instead, to break through when the world flips (_tick_wall).
func _devil_goal() -> Vector2i:
	if thin_wall != DevilBrain.NOWHERE:
		return thin_wall_from
	return brain.target(devil_cell, player_cell)

## It sees you: ahead of it down a straight corridor (DevilBrain.sees), or your flashlight beam pointed at it from
## farther (Lantern Heart hides the beam).
func _devil_sees() -> bool:
	if DevilBrain.sees(layout, world, devil_cell, devil_facing, player_cell):
		return true
	if not flashlight_on or beam_hidden or not DevilBrain.line_of_sight(layout, world, player_cell, devil_cell, DevilBrain.BEAM_TILES):
		return false
	var forward := -camera.global_transform.basis.z
	var to_devil := devil.global_position - camera.global_position
	return Vector2(forward.x, forward.z).normalized().dot(Vector2(to_devil.x, to_devil.z).normalized()) > cos(deg_to_rad(flashlight.spot_angle))

## A noise at `cell` carrying `radius` path tiles (master plan §7). At your cell it hears you (it knows where you
## are for a while); elsewhere it goes to look.
func _noise(cell: Vector2i, radius: int) -> void:
	if not _hears(cell, radius):
		return
	if cell == player_cell:
		brain.sense(false, true, 0.0)
	else:
		brain.investigate(cell)

## The Devil (awake) is within `radius` path tiles of `cell`: it would hear a noise there.
func _hears(cell: Vector2i, radius: int) -> bool:
	if not devil_active:
		return false
	var from := player_dist if cell == player_cell else layout.distances(world, cell)
	var reach := from[devil_cell.y * layout.size + devil_cell.x]
	return reach >= 0 and reach <= radius

## A random open cell `near`..`far` path tiles from you (your own cell if there is none).
func _cell_near_player(near: int, far: int) -> Vector2i:
	var spots: Array[Vector2i] = []
	for i in player_dist.size():
		if player_dist[i] >= near and player_dist[i] <= far:
			spots.append(layout.cell_at(i))
	return spots[fair_rng.randi_range(0, spots.size() - 1)] if not spots.is_empty() else player_cell

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
		_stand_up()

## Through the wall, each frame it hunts: rooms side by side, the way round long (DevilBrain.thin_wall). Flipping Time
## coming: it slips to the wall beside you, waits, and through the warning pounds it until the flip breaks it through
## (_breach_thin_wall); otherwise it slams it once as it passes you. An echo or a safe circle calls it off.
func _tick_wall(delta: float) -> void:
	knock_left = maxf(knock_left - delta, 0.0)
	pound_left = maxf(pound_left - delta, 0.0)
	if devil_retreating or brain.interest != DevilBrain.NOWHERE:
		thin_wall = DevilBrain.NOWHERE
		return
	# It re-picks the wall each time it or you change cells, until it stands there pounding through the warning. Only
	# while you're in a room (the walls it breaks are between rooms): in a passage it keeps the room you just left.
	var plan := Vector4i(player_cell.x, player_cell.y, devil_cell.x, devil_cell.y)
	var in_room := player_cell.x % 2 == 1 and player_cell.y % 2 == 1
	var committed := flip.warning_active and thin_wall != DevilBrain.NOWHERE and devil_cell == thin_wall_from
	if flip.forced_active or flip.next_forced_in > THIN_WALL_LOOKAHEAD or thin_walls >= THIN_WALLS_PER_FLOOR:
		thin_wall_plan = Vector4i(-1, -1, -1, -1)
	elif in_room and plan != thin_wall_plan and not committed:
		thin_wall_plan = plan
		_arm_thin_wall()
	var arrived := devil.position.distance_to(_devil_world_position()) < 0.05
	if thin_wall != DevilBrain.NOWHERE:
		if flip.warning_active and arrived and devil_cell == thin_wall_from and pound_left <= 0.0:
			pound_left = THIN_WALL_POUND
			if not pounded:
				pounded = true
				_flash_message("It's breaking through the wall...")
			_slam_wall(thin_wall, thin_wall * 2 - thin_wall_from)
		return
	var wall := DevilBrain.wall_between(layout, world, player_cell, devil_cell)
	if arrived and knock_left <= 0.0 and wall != DevilBrain.NOWHERE:
		knock_left = KNOCK_COOLDOWN
		_slam_wall(wall, player_cell)

## Flipping Time is coming: the wall beside you it can reach in time and break through, or none (DevilBrain.thin_wall).
func _arm_thin_wall() -> void:
	var reach := floori((flip.next_forced_in - THIN_WALL_LEAD) / _devil_step_interval())
	var wall := DevilBrain.NOWHERE
	if reach >= 0:
		wall = DevilBrain.thin_wall(layout, world, player_cell, layout.distances(world, devil_cell), _devil_distance(), reach)
	if wall != thin_wall:
		pounded = false
	thin_wall = wall
	thin_wall_from = wall * 2 - player_cell if wall != DevilBrain.NOWHERE else DevilBrain.NOWHERE

## Debug builds (F9): the Devil in the room beside you across a wall and Flipping Time in a moment, to see a breach now.
func _debug_thin_wall() -> void:
	if flip.forced_active:
		_flash_message("F9: wait for WAKE")
		return
	for d in FloorLayout.DIRS:
		var far := player_cell + d * 2
		if DevilBrain.wall_between(layout, world, player_cell, far) == DevilBrain.NOWHERE \
				or player_dist[far.y * layout.size + far.x] < 2 + DevilBrain.BREACH_SAVING:
			continue
		if not devil_active:
			_wake_devil()
		devil_cell = far
		prev_devil_cell = far
		devil.position = _devil_world_position()
		devil_retreating = false
		brain.interest = DevilBrain.NOWHERE
		thin_walls = 0
		flip.next_forced_in = flip.warning_time + 0.5
		return
	_flash_message("F9: no wall beside you with a room behind it")

## The flip lands while it stands at the wall beside you: the wall bursts and it reels in the hole for THIN_WALL_STUN,
## the fair window instead of _keep_devil_fair's teleport. False (nothing happens) if it never got there.
func _breach_thin_wall() -> bool:
	var wall := thin_wall
	thin_wall = DevilBrain.NOWHERE
	if wall == DevilBrain.NOWHERE or not devil_active or devil_retreating or devil_cell != thin_wall_from:
		return false
	thin_walls += 1
	_break_wall(wall)
	_slam_wall(wall, wall * 2 - thin_wall_from, true)
	devil_stun = THIN_WALL_STUN
	RunState.log_event("breach", {"floor": rule.floor_number, "act": rule.act, "gap": _devil_distance()})
	return true

## `cell` is open from now on, in both worlds: the grid, then its block, trims and collision in whichever wall set holds
## it, any landmark paint on its faces, and the distances that ran round it. Chunks of it stay on the floor.
func _break_wall(cell: Vector2i) -> void:
	layout.open_cell(cell)
	var at := cell_to_world(cell)
	var flat := Vector2(at.x, at.z)
	for body: Node in [get_node("SharedWalls"), wake_walls, nightmare_walls]:
		for child in body.get_children():
			var shape := child as CollisionShape3D
			if shape != null and Vector2(shape.position.x, shape.position.z).is_equal_approx(flat):
				shape.disabled = true
			var blocks := child as MultiMeshInstance3D
			if blocks == null:
				continue
			for i in blocks.multimesh.instance_count:
				var origin := blocks.multimesh.get_instance_transform(i).origin
				if Vector2(origin.x, origin.z).is_equal_approx(flat):
					blocks.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), origin))
	var marks := get_node_or_null("Landmarks")
	if marks != null:
		for child in marks.get_children():
			var mark := child as Node3D
			if mark != null and absf(mark.position.x - at.x) <= CELL_SIZE * 0.55 and absf(mark.position.z - at.z) <= CELL_SIZE * 0.55:
				mark.queue_free()  # a glyph painted on it
	_rubble(at, 1.0)
	player_dist = layout.distances(world, player_cell)
	from_spawn = layout.distances(FloorLayout.ANY, layout.spawn)
	exit_dist = [layout.distances(WAKE, layout.exit), layout.distances(NIGHTMARE, layout.exit)]

## Chunks of broken wall strewn on the floor within `spread` m of `at` (no collision: you walk over them).
func _rubble(at: Vector3, spread: float) -> void:
	var chunk := BoxMesh.new()
	chunk.size = Vector3.ONE * 0.22
	var rubble := MultiMesh.new()
	rubble.transform_format = MultiMesh.TRANSFORM_3D
	rubble.mesh = chunk
	rubble.instance_count = 9
	for i in rubble.instance_count:
		var tumble := Basis.from_euler(Vector3(randf(), randf(), randf()) * TAU).scaled(Vector3.ONE * randf_range(0.5, 1.4))
		rubble.set_instance_transform(i, Transform3D(tumble, at + Vector3(randf_range(-spread, spread), 0.06, randf_range(-spread, spread))))
	var pile := MultiMeshInstance3D.new()
	pile.name = "Rubble"
	pile.multimesh = rubble
	pile.material_override = shared_wall_material
	add_child(pile)

## A blow on the wall at `cell`: a thud you feel near it, dust and red light off its face toward the open cell `side`
## beside it. `breach` = the blow that breaks it (or that it tears out with): louder, harder, the dust thrown out.
func _slam_wall(cell: Vector2i, side: Vector2i, breach := false) -> void:
	var at := cell_to_world(cell)
	var path := BREAK_SFX if breach else SLAM_SFX
	var delivered := ResourceLoader.exists(path)
	slam_player.stream = load(path) if delivered else crack_player.stream  # stand-in: the floor crack, pitched down
	slam_player.pitch_scale = 1.0 if delivered else (0.42 if breach else 0.6)
	slam_player.volume_db = 4.0 if breach else 0.0
	slam_player.unit_size = SLAM_UNIT
	slam_player.position = at + Vector3(0, WALL_HEIGHT * 0.5, 0)
	slam_player.play()
	var force := (2.0 if breach else 1.0) * clampf(1.0 - player.global_position.distance_to(at) / SLAM_FEEL, 0.0, 1.0)
	if player_rig != null and force > 0.05:
		player_rig.startle(force)
	var jolt := create_tween()
	for i in 4:
		jolt.tween_callback(_shake.bind(SLAM_SHAKE * force * (1.0 - i * 0.25))).set_delay(0.04)
	jolt.tween_callback(_shake.bind(0.0)).set_delay(0.04)
	var face := Vector3(side.x - cell.x, 0, side.y - cell.y)
	slam_light.position = at + face * (CELL_SIZE * 0.5 + 0.4) + Vector3(0, 1.4, 0)  # inside the block it lights nothing
	slam_light.light_energy = Settings.flash(SLAM_LIGHT * (2.0 if breach else 1.0))
	create_tween().tween_property(slam_light, "light_energy", 0.0, 0.5)
	slam_dust.position = at + face * (CELL_SIZE * 0.5 + 0.05) + Vector3(0, WALL_HEIGHT - 0.15, 0)
	slam_dust.emission_box_extents = Vector3(absf(face.z), 0, absf(face.x)) * CELL_SIZE * 0.45 + Vector3(0.03, 0.05, 0.03)
	slam_dust.direction = face if breach else Vector3.DOWN
	slam_dust.initial_velocity_max = 1.4 if breach else 0.6
	slam_dust.restart()

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
	get_tree().create_timer(SPAWN_TELEGRAPH).timeout.connect(func() -> void:
		if devil_spawning:  # a revive meanwhile put it back to sleep
			_wake_devil()
			_start_wake_cut())

func _wake_devil() -> void:
	devil_spawning = false
	devil_active = true
	_count("devil_wakes")
	devil.position = _devil_world_position()
	devil.visible = true
	_burst_out()

## It wakes inside a wall beside its cell and tears out of it toward you (user, 12 Oct 2026: the breach's sudden
## entrance at "Something woke up"). Still behind you and far away (_try_spawn_devil); the wall stays (the maze doesn't
## change), rubble spills out.
func _burst_out() -> void:
	var wall := DevilBrain.burst_wall(layout, world, devil_cell, layout.next_step(world, devil_cell, player_cell) - devil_cell)
	if wall == DevilBrain.NOWHERE:
		return
	var out := Vector3(devil_cell.x - wall.x, 0, devil_cell.y - wall.y)
	devil.position = cell_to_world(wall) + Vector3(0, DEVIL_Y, 0)  # inside the stone: it walks out
	devil.rotation.y = atan2(out.x, out.z)
	_slam_wall(wall, devil_cell, true)
	slam_player.unit_size = WAKE_HEARD
	_rubble(cell_to_world(devil_cell) - out * 0.7, 0.6)

## "Something woke up behind you..." (user, 12 Oct 2026): the camera leaves you for the Devil tearing out of its wall,
## watches it roar (echoing down the corridors), then rushes back along the corridors into your eyes. The game holds
## still meanwhile (game_state "waking"); any key skips it; Reduce Motion cuts back instead of rushing.
func _start_wake_cut() -> void:
	var route := layout.route(devil_cell, player_cell)
	if game_state != "playing" or get_tree().paused or route.size() < 2:
		return
	if paper_map.opening:
		_close_map("wake")
	_stand_up()
	box_hands.visible = false
	game_state = "waking"
	wake_t = 0.0
	wake_devil_from = devil.position
	var eyes := camera_pivot.global_position
	wake_cam_at = cell_to_world(route[1]) + Vector3(0, 1.0, 0)  # one cell down its way to you, low, looking up at it
	wake_cam_look = cell_to_world(devil_cell) + Vector3(0, 1.5, 0)
	var way := PackedVector3Array([wake_cam_at])
	for i in range(2, route.size()):
		way.append(cell_to_world(route[i]) + Vector3(0, eyes.y, 0))
	way.append(eyes)
	var first := way.size() - 1  # only the last WAKE_RUSH_TAIL m: farther than that, it cuts there from the roar
	var kept := 0.0
	while first > 0 and kept < WAKE_RUSH_TAIL:
		kept += way[first].distance_to(way[first - 1])
		first -= 1
	wake_path = _rounded(_rounded(way.slice(first)))  # corners cut twice: it swoops round them instead of snapping
	wake_path_length = 0.0
	for i in range(1, wake_path.size()):
		wake_path_length += wake_path[i - 1].distance_to(wake_path[i])
	wake_rush = WAKE_RUSH_TIME * clampf(wake_path_length / WAKE_RUSH_TAIL, 0.6, 1.0)
	camera.top_level = true
	camera.global_transform = Transform3D(Basis(), wake_cam_at).looking_at(wake_cam_look)
	wake_light.position = wake_cam_look.lerp(wake_cam_at, 0.5) + Vector3(0, 1.0, 0)
	wake_light.visible = true
	get_node("HUD").visible = false
	_letterbox(true)

## One frame of the wake cut: it walks out of the stone, roars (the camera creeping in, shaking), then the camera
## rushes the corridors back to you and hands over.
func _tick_wake(delta: float) -> void:
	wake_t += delta
	var tear := clampf(wake_t / WAKE_TEAR, 0.0, 1.0)
	devil.position = wake_devil_from.lerp(_devil_world_position(), tear)
	var roar := wake_t - WAKE_TEAR
	if roar >= WAKE_ROAR_SOUND and roar - delta < WAKE_ROAR_SOUND:
		roar_player.play()  # breath drawn in the coil; the sound lands with the burst
	if roar >= 0.0 and roar < WAKE_ROAR:
		devil_mesh.position.y = -DEVIL_Y + devil_rig.roar(roar, delta, camera.global_position)
	else:  # claws first out of the stone, then the body; after the roar it stands and watches the camera go
		devil_mesh.position.y = -DEVIL_Y + devil_rig.prowl(CELL_SIZE / WAKE_TEAR if tear < 1.0 else 0.0, delta,
				Vector3.INF if tear < 1.0 else camera.global_position, 1.0 if tear < 0.5 else 0.0)
	if roar < WAKE_ROAR:
		var look := wake_cam_look + Vector3(0, 0.6 * clampf((roar - 0.25) / 0.35, 0.0, 1.0), 0)  # up to its face with the burst
		var creep := wake_cam_at.move_toward(look, 0.4 * clampf(roar / WAKE_ROAR, 0.0, 1.0))
		camera.global_transform = Transform3D(Basis(), creep).looking_at(look)
		_shake(0.05 * DevilRig.roar_force(roar))
		return
	var s := (roar - WAKE_ROAR) / wake_rush
	if s >= 1.0 or Settings.reduce_motion:
		_end_wake_cut()
		return
	_shake(0.0)
	var along := smoothstep(0.0, 1.0, s) * wake_path_length
	var at := _along_wake_path(along)
	var ahead := _along_wake_path(minf(along + 6.0, wake_path_length)) - at
	var goal := Basis.looking_at(ahead) if ahead.length() > 0.05 else camera_pivot.global_basis
	goal = goal.slerp(camera_pivot.global_basis, clampf((s - 0.8) / 0.2, 0.0, 1.0)).orthonormalized()  # land facing your way
	var first_frame := roar - delta < WAKE_ROAR  # a cut from the roar: no swing from the old shot
	var turned := goal if first_frame else camera.global_basis.orthonormalized().slerp(goal, 1.0 - exp(-10.0 * delta))
	camera.global_transform = Transform3D(turned, at)

## Chaikin's corner cutting: each leg's quarter points instead of its corners; the ends stay put.
func _rounded(points: PackedVector3Array) -> PackedVector3Array:
	var smooth := PackedVector3Array([points[0]])
	for i in range(points.size() - 1):
		smooth.append(points[i].lerp(points[i + 1], 0.25))
		smooth.append(points[i].lerp(points[i + 1], 0.75))
	smooth.append(points[points.size() - 1])
	return smooth

## The point `d` metres along the rush back to you.
func _along_wake_path(d: float) -> Vector3:
	for i in range(1, wake_path.size()):
		var leg := wake_path[i - 1].distance_to(wake_path[i])
		if d <= leg:
			return wake_path[i - 1].lerp(wake_path[i], d / leg if leg > 0.0 else 1.0)
		d -= leg
	return wake_path[wake_path.size() - 1]

## Back into your eyes; the game picks up where it held (a key skips straight here).
func _end_wake_cut() -> void:
	wake_t = -1.0
	devil.position = _devil_world_position()
	camera.top_level = false
	camera.transform = Transform3D()
	_shake(0.0)
	wake_light.visible = false
	get_node("HUD").visible = true
	_letterbox(false)
	game_state = "playing"

## Black bars over the top and bottom of the screen while the camera is away from you.
func _letterbox(on: bool) -> void:
	if letterbox == null:
		letterbox = CanvasLayer.new()
		letterbox.layer = 5
		for top: bool in [true, false]:
			var bar := ColorRect.new()
			bar.color = Color.BLACK
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bar.anchor_right = 1.0
			bar.anchor_top = 0.0 if top else 1.0 - WAKE_BARS
			bar.anchor_bottom = WAKE_BARS if top else 1.0
			letterbox.add_child(bar)
		add_child(letterbox)
	letterbox.visible = on

## A bus that echoes down the corridors (a big reverb and two taps), sent on to SFX so the slider still covers it.
## Buses live in the AudioServer, not the scene: made once per game launch.
func _echo_bus() -> StringName:
	if AudioServer.get_bus_index(ECHO_BUS) < 0:
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, ECHO_BUS)
		AudioServer.set_bus_send(index, Settings.SFX_BUS)
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.9
		reverb.damping = 0.3
		reverb.wet = 0.5
		AudioServer.add_bus_effect(index, reverb)
		var taps := AudioEffectDelay.new()
		taps.tap1_delay_ms = 280.0
		taps.tap1_level_db = -8.0
		taps.tap2_delay_ms = 560.0
		taps.tap2_level_db = -14.0
		AudioServer.add_bus_effect(index, taps)
	return ECHO_BUS

func _seen_by_player(cell: Vector2i) -> bool:
	return DevilBrain.line_of_sight(layout, world, player_cell, cell) or circles.index_at(cell) >= 0

## In a safe circle: it backs off (visibly, at its own speed) to the nearest spot far from you.
func _start_retreat(distance := CIRCLE_RETREAT_DISTANCE) -> void:
	if lunge_left > 0.0:
		_close_call("CLOSE CALL")  # dove into the circle mid-lunge
	devil_retreating = true
	steps_since_retreat = 0
	lunge_left = 0.0
	var from_devil := layout.distances(world, devil_cell)
	var best := -1
	for i in player_dist.size():
		if player_dist[i] >= distance and from_devil[i] >= 0 and (best < 0 or from_devil[i] < from_devil[best]):
			best = i
	devil_target = layout.cell_at(best) if best >= 0 else devil_cell

# --- Fear Shards (plans/06 P2) ------------------------------------------------------

## Shards for something you did: counted now, popped on the HUD, banked by _bank().
func _earn(amount: int, why := "") -> void:
	if not RunState.banks():
		return  # the same maze again would be a farm (the Long Night pays its medals instead)
	amount = roundi(amount * shard_factor)
	floor_shards += amount
	_pop(("+%d  %s" % [amount, why]).strip_edges())

## A "+3" under the status plate (and its shard counter) that drifts up and fades; pops landing together stack
## downwards.
func _pop(text: String) -> void:
	var pop := _hud_label(get_node("HUD"), "Pop", 22, Control.PRESET_TOP_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT)
	pop.text = text
	pop.add_theme_color_override("font_color", SHARD_COLOR)
	pop.offset_left = -PLATE_MARGIN.x - PLATE_SIZE.x
	pop.offset_right = -PLATE_MARGIN.x - PLATE_INSET.z
	pop.offset_top = PLATE_MARGIN.y + PLATE_SIZE.y
	live_pops += 1
	pop.position.y += maxf(SHARD_POP_GAP, pop.get_minimum_size().y) * (live_pops - 1) + SHARD_POP_RISE
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
	_count("close_calls")
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
	if fixed_seed != 0 or not RunState.banks() or (floor_shards == 0 and floor_finds.is_empty() and floor_stats.is_empty()):
		return news  # a debug floor never touches the save; practice and the Long Night bank nothing
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
	_screen_flash(Color(1, 1, 1, 0.85))
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
	# Every step counts, walked before or not: after a revive (or a backtrack) every cell is old, and only counting new
	# ones left it standing at its retreat spot for good.
	steps_since_retreat += 1
	if not visited.has(cell):
		visited[cell] = true
		circles.on_new_cell()
	brain.record(cell)
	if bonus_chests.has(cell):
		_open_detour_chest(cell)
	if cell == layout.exit and not exit_open:
		var missing := layout.sigils.size() - sigils_collected
		_flash_message("THE CHEST IS LOCKED   find %d more key%s" % [missing, "" if missing == 1 else "s"])
	if traps.creak(cell):
		creak_player.play()
	var holds := traps.holds
	match traps.step(cell):
		TrapField.State.CRACKED:
			_noise(cell, DevilBrain.NOISE_CRACK)
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
	snapshot = {"cell": player_cell, "time_left": time_left, "traps": traps.states.duplicate(), "trail": brain.trail.size()}
	if devil_active and not devil_retreating:
		_start_retreat()

func _refresh_circles() -> void:
	for i in circles.cells.size():
		var fill := circles.charge[i] / circles.capacity
		if circle_decals:
			circle_materials[i].albedo_color = Color(CIRCLE_COLOR * (0.15 + 1.1 * fill), 1.0)
		else:
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
	_screen_flash(Color(0.55, 0.05, 0.0, 0.35))
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
	camera.cull_mask |= PLAYER_LAYER  # from the rim it watches your body fall

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

## Camera shake via lens offset, so it never fights look, bob or flip roll. Reduce Motion stills it.
func _shake(amount: float) -> void:
	if Settings.reduce_motion:
		amount = 0.0
	camera.h_offset = randf_range(-amount, amount)
	camera.v_offset = randf_range(-amount, amount)

## A full-screen flash, dimmed by Reduce Flashing (the fall's fade to black isn't a flash and sets the rect itself).
func _screen_flash(color: Color) -> void:
	flash_rect.color = Color(color, Settings.flash(color.a))

## Spawn -> every box (nearest first) -> exit, in path tiles: what the clock budgets for. Every box, not just the
## keys': you can't know which hold them, so the clock is fair even when the last box you try is the one.
func _tour_tiles() -> int:
	var total := 0
	var at := layout.spawn
	var left: Array[Vector2i] = layout.boxes.duplicate()
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
	env.tonemap_exposure = Settings.brightness
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
		music.bus = Settings.MUSIC_BUS
		(music.stream as AudioStreamMP3).loop = true
		music.play()
	win_player = _audio("WinSfx", "res://assets/audio/sfx_win.mp3", -4.0)
	lose_player = _audio("LoseSfx", "res://assets/audio/sfx_lose.mp3", -4.0)
	flip_player = _audio("FlipSfx", "res://assets/audio/sfx_flip.mp3", -6.0)
	warning_player = _audio("FlippingTimeWarning", "res://assets/audio/sfx_flipping_warning.mp3", -4.0)
	sigil_player = _audio("SigilSfx", "res://assets/audio/sfx_sigil.mp3", -6.0)
	# Stand-ins until the box sounds are delivered: the floor creak for the lid, the floor crack pitched down to a knock.
	box_open_player = _audio("BoxOpen", BOX_OPEN_SFX if ResourceLoader.exists(BOX_OPEN_SFX) else "res://assets/audio/sfx_floor_creak.mp3", -6.0)
	box_empty_player = _audio("BoxEmpty", BOX_EMPTY_SFX if ResourceLoader.exists(BOX_EMPTY_SFX) else "res://assets/audio/sfx_floor_crack.mp3", -10.0)
	if not ResourceLoader.exists(BOX_EMPTY_SFX):
		box_empty_player.pitch_scale = 0.55
	devil_approach_player = _audio("DevilApproach", "res://assets/audio/sfx_devil_approach.mp3", -10.0)
	heartbeat_player = _audio("Heartbeat", "res://assets/audio/sfx_heartbeat.mp3", -20.0)
	(heartbeat_player.stream as AudioStreamMP3).loop = true
	alarm_player = _audio("LowTimeAlarm", "res://assets/audio/sfx_low_time.mp3", -8.0)
	crack_player = _audio("FloorCrack", "res://assets/audio/sfx_floor_crack.mp3", -6.0)
	fall_player = _audio("FloorCollapse", "res://assets/audio/sfx_floor_crack.mp3", 0.0)
	creak_player = _audio("FloorCreak", "res://assets/audio/sfx_floor_creak.mp3", -12.0)
	circle_player = _audio("SafeCircle", "res://assets/audio/sfx_safe_circle.mp3", -6.0)
	telegraph_player = _audio("DevilWakes", "res://assets/audio/sfx_devil_wakes.mp3", -4.0)
	breath_calm = _breath_loop("BreathCalm", "res://assets/audio/sfx_breath_calm.mp3")
	breath_heavy = _breath_loop("BreathHeavy", "res://assets/audio/sfx_breath_heavy.mp3")

## A breathing loop, started silent (_update_breath fades it in); no file yet = no sound.
func _breath_loop(node_name: String, path: String) -> AudioStreamPlayer:
	var audio := AudioStreamPlayer.new()
	audio.name = node_name
	audio.volume_linear = 0.0
	audio.bus = Settings.SFX_BUS
	add_child(audio)
	if ResourceLoader.exists(path):
		audio.stream = load(path)
		(audio.stream as AudioStreamMP3).loop = true
		audio.play()
	return audio

func _audio(node_name: String, path: String, volume_db: float) -> AudioStreamPlayer:
	var audio := AudioStreamPlayer.new()
	audio.name = node_name
	audio.stream = load(path)
	audio.volume_db = volume_db
	audio.bus = Settings.SFX_BUS  # the two music loops move to MUSIC_BUS in _build_audio
	add_child(audio)
	return audio

## One sound, light and dust cloud for every blow on a wall (_slam_wall moves them to it); the wake cut's roar (on the
## echo bus) and its red fill light.
func _build_devil_fx() -> void:
	roar_player = AudioStreamPlayer.new()
	roar_player.name = "DevilRoar"
	var delivered := ResourceLoader.exists(ROAR_SFX)
	roar_player.stream = load(ROAR_SFX if delivered else "res://assets/audio/sfx_devil_wakes.mp3")
	roar_player.pitch_scale = 1.0 if delivered else 0.8  # stand-in: its waking growl, deeper
	roar_player.bus = _echo_bus()
	add_child(roar_player)
	wake_light = OmniLight3D.new()
	wake_light.light_color = Color(1.0, 0.25, 0.15)
	wake_light.light_energy = 1.2
	wake_light.omni_range = CELL_SIZE * 2.0
	wake_light.visible = false
	add_child(wake_light)
	slam_player = AudioStreamPlayer3D.new()
	slam_player.name = "WallSlam"
	slam_player.bus = Settings.SFX_BUS
	add_child(slam_player)
	slam_light = OmniLight3D.new()
	slam_light.light_color = Color(1.0, 0.12, 0.05)
	slam_light.light_energy = 0.0
	slam_light.omni_range = CELL_SIZE * 1.4
	add_child(slam_light)
	slam_dust = CPUParticles3D.new()
	slam_dust.emitting = false
	slam_dust.one_shot = true
	slam_dust.explosiveness = 0.85
	slam_dust.amount = 48
	slam_dust.lifetime = 1.6
	slam_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	slam_dust.spread = 35.0
	slam_dust.gravity = Vector3(0, -3.0, 0)
	slam_dust.scale_amount_min = 0.4
	slam_dust.scale_amount_max = 1.2
	var grain := SphereMesh.new()  # lit grit: flat unshaded squares read as confetti in the red world
	grain.radius = 0.015
	grain.height = 0.03
	grain.radial_segments = 4
	grain.rings = 2
	var grit := StandardMaterial3D.new()
	grit.albedo_color = Color(0.42, 0.4, 0.38)
	grit.roughness = 1.0
	grain.material = grit
	slam_dust.mesh = grain
	add_child(slam_dust)

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
	ceiling_material = StandardMaterial3D.new()
	ceiling_material.albedo_color = Color(0.008, 0.012, 0.02)
	ceiling_material.roughness = 1.0
	ceiling.material_override = ceiling_material
	add_child(ceiling)

	trim_material = _trim_material()
	if Art.dress(trim_material, "wall_trim", TRIM_TILE):
		trim_material.albedo_color = Color(0.8, 0.78, 0.76)
		trim_material.emission_energy_multiplier = 0.35
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
				var mark := landmarks.at(cell)
				if (x + y) % world_light_spacing == 0 and (mark < 0 or not landmarks.lit(mark)):
					light_cells.append(cell)
				if (x + y) % 2 == 0:
					accent_cells.append(cell)
	shared_wall_material = _wall_material()
	_build_wall_set("SharedWalls", shared, LAYER_SHARED, shared_wall_material)
	var wake_material := _wall_material()
	_dress(wake_material, "wall", WAKE)
	wake_walls = _build_wall_set("WakeWalls", wake_only, LAYER_WAKE, wake_material)
	var nightmare_material := _wall_material()
	_dress(nightmare_material, "wall", NIGHTMARE)
	nightmare_walls = _build_wall_set("NightmareWalls", nightmare_only, LAYER_NIGHTMARE, nightmare_material)

	var lamp := Art.model("ceiling_lamp")
	var bulb_y := CEILING_HEIGHT - 0.12
	if lamp != null:
		bulb_y = CEILING_HEIGHT - LAMP_BULB_DROP
		_build_lamps(lamp, light_cells)
	else:
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
		light.position = cell_to_world(cell) + Vector3(0, bulb_y, 0)
		add_child(light)
		world_lights.append(light)

	if Art.tex(Art.WORLD + "wake_floor_albedo.jpg") == null:  # the neon strips belong to the plain floor
		var accent_mesh := BoxMesh.new()
		accent_mesh.size = Vector3(CELL_SIZE * 0.72, 0.012, 0.04)
		add_child(_multimesh(accent_mesh, accent_material, accent_cells, 0.015))

## The delivered ceiling lamp on every light cell (one draw call), with a bulb glowing in the world's colour in each cage.
func _build_lamps(scene: PackedScene, cells: Array[Vector2i]) -> void:
	var lamp_mesh := _first_mesh(scene)
	var lamps := _multimesh(lamp_mesh, null, cells, CEILING_HEIGHT - 0.09 - lamp_mesh.get_aabb().end.y)
	lamps.name = "Lamps"
	add_child(lamps)
	var bulb := SphereMesh.new()
	bulb.radius = LAMP_BULB_RADIUS
	bulb.height = LAMP_BULB_RADIUS * 2.0
	add_child(_multimesh(bulb, light_material, cells, CEILING_HEIGHT - LAMP_BULB_DROP))

func _first_mesh(scene: PackedScene) -> Mesh:
	var model := scene.instantiate()
	var mesh := (model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	model.free()
	return mesh

## `material` wears `surface`'s delivered textures for world `look`, tinted for it (Art.dress); without them it keeps
## its plain colour.
func _dress(material: StandardMaterial3D, surface: String, look: int) -> void:
	if Art.dress(material, SURFACE_WORLDS[look] + "_" + surface, Vector3.ONE * CELL_SIZE):
		var tint := SURFACE_TINTS[look].darkened(CEILING_DARKEN if surface == "ceiling" else 0.0)
		material.albedo_color = _act_tint(tint) if look == WAKE else tint

## One world's walls: one static body (shared box shape per cell) + 3 multimeshes = 3 draw calls.
func _build_wall_set(set_name: String, cells: Array[Vector2i], layer: int, material: StandardMaterial3D) -> Node3D:
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
	body.add_child(_multimesh(wall_mesh, material, cells, WALL_HEIGHT * 0.5))
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
	# Face down the first open corridor, not into the spawn corner's wall.
	for d in FloorLayout.DIRS:
		if layout.is_open(WAKE, player_cell + d):
			yaw = atan2(-float(d.x), -float(d.y))
			break
	player.rotation.y = yaw
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
	player_mesh.rotation_degrees.y = PLAYER_MESH_YAW
	ModelFit.fit_height(player_mesh, WALL_HEIGHT * PLAYER_HEIGHT_RATIO, PLAYER_MESH_Y)
	player.add_child(player_mesh)
	player_rig = DevilRig.new(player_mesh, false)
	player_rig.unstick_hands()
	player_rig.walk_pace = feel.walk_speed
	player_rig.sprint_pace = feel.walk_speed * feel.sprint_multiplier
	for part: MeshInstance3D in player_mesh.find_children("*", "MeshInstance3D", true, false):
		part.layers = PLAYER_LAYER

	camera_pivot = Node3D.new()
	camera_pivot.position.y = EYE_HEIGHT
	player.add_child(camera_pivot)
	camera = Camera3D.new()
	camera.current = true
	camera.cull_mask &= ~PLAYER_LAYER  # never the inside of your own head
	camera.fov = feel.base_fov
	camera_pivot.add_child(camera)
	box_hands = BoxHands.new()
	box_hands.name = "BoxHands"
	add_child(box_hands)
	box_hands.build(HANDS_LAYER)
	flashlight = SpotLight3D.new()
	flashlight.name = "Flashlight"
	flashlight.light_color = MetaState.light_color()
	flashlight.light_energy = feel.flashlight_energy * beam_energy
	flashlight.spot_range = feel.flashlight_range * beam_range
	flashlight.spot_angle = feel.flashlight_angle * beam_angle
	flashlight.shadow_enabled = true
	flashlight.shadow_bias = FLASHLIGHT_SHADOW_BIAS.x
	flashlight.shadow_normal_bias = FLASHLIGHT_SHADOW_BIAS.y
	camera.add_child(flashlight)

	footstep_player = AudioStreamPlayer.new()
	footstep_player.name = "Footsteps"
	footstep_player.bus = Settings.SFX_BUS
	footstep_player.stream = _build_footstep_stream()
	footstep_player.max_polyphony = 2
	player.add_child(footstep_player)

func _build_goal() -> void:
	goal = Node3D.new()
	goal.name = "ExitPortal"
	goal.position = cell_to_world(layout.exit)
	add_child(goal)

	var circle := Art.decal(Art.DECALS + "exit_circle.png", EXIT_DECAL_SIZE, Color.WHITE, true)
	if circle != null:
		exit_decal = true
		circle.name = "ExitCircle"
		circle.position.y = 0.02
		goal.add_child(circle)
		goal_material = circle.material_override
	else:
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
	var arch := Art.model("gate_arch") if rule.is_gate else null
	if arch != null:
		# The Gate itself, closed, at the back of the exit cell behind the chest (floor 10 only).
		var gate := arch.instantiate() as Node3D
		gate.name = "GateArch"
		gate.rotation.y = chest.rotation.y
		var depth := ModelFit.mesh_bounds(gate).size.z
		gate.position = -Vector3(sin(chest.rotation.y), 0, cos(chest.rotation.y)) * (CELL_SIZE - depth) * 0.5
		goal.add_child(gate)
	chest.key_turned.connect(_on_key_turned)
	chest.opened.connect(_on_chest_opened)

	goal_light = OmniLight3D.new()
	goal_light.omni_range = 4.0
	goal.add_child(goal_light)
	_set_exit_look()

## Locked: dim and red. Open (all keys): bright green.
func _set_exit_look() -> void:
	var color := Color(0.1, 1.0, 0.45) if exit_open else Color(0.35, 0.05, 0.08)
	goal_material.albedo_color = Color(color * (1.6 if exit_open else 2.2), 1.0) if exit_decal else color
	goal_material.emission = color * (0.65 if exit_open else 0.3)
	goal_light.light_color = color
	goal_light.light_energy = 2.5 if exit_open else 0.6

## Chests down dead ends (Vault, Greed: plans/06 B3), each a real detour off the route, glowing faintly.
func _build_detour_chests() -> void:
	var taken: Array[Vector2i] = [layout.devil_spawn]
	taken.append_array(layout.boxes)
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

## The Sanctuary's altar (delivered model) down a dead end, facing the way in, lit soft blue. Solid: you walk round it.
func _build_altar() -> void:
	var altar_scene := Art.model("sanctuary_altar") if rule.is_sanctuary else null
	if altar_scene == null:
		return
	var taken: Array[Vector2i] = [layout.devil_spawn, layout.spawn, layout.exit]
	taken.append_array(layout.boxes)
	taken.append_array(circles.cells)
	taken.append_array(traps.cells)
	taken.append_array(bonus_chests.keys())
	var spots := layout.detours(1, taken, traps.cells)
	if spots.is_empty():
		return
	var altar := Node3D.new()
	altar.name = "Altar"
	altar.position = cell_to_world(spots[0])
	add_child(altar)
	for d in FloorLayout.DIRS:
		if layout.is_open(FloorLayout.ANY, spots[0] + d):
			altar.rotation.y = atan2(float(d.x), float(d.y))
	altar.add_child(altar_scene.instantiate())
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_SHARED
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = ALTAR_SIZE
	shape.shape = box
	shape.position.y = ALTAR_SIZE.y * 0.5
	body.add_child(shape)
	altar.add_child(body)
	var light := OmniLight3D.new()
	light.light_color = ALTAR_LIGHT
	light.light_energy = 1.2
	light.omni_range = 3.5
	light.position = Vector3(0, ALTAR_SIZE.y + 0.4, 0.4)
	altar.add_child(light)

## NIGHTMARE set dressing (delivered decals): blood on a few floors, claw marks on a few walls, the same for a floor
## seed. Shown only in NIGHTMARE (_apply_world).
func _build_dressing() -> void:
	dressing = Node3D.new()
	dressing.name = "Dressing"
	add_child(dressing)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "dressing"])
	var floors: Array[Vector2i] = []
	for y in layout.size:
		for x in layout.size:
			var cell := Vector2i(x, y)
			if layout.is_open(NIGHTMARE, cell) and not traps.cells.has(cell) and not circles.cells.has(cell) \
					and cell != layout.exit and not layout.boxes.has(cell):
				floors.append(cell)
	for i in BLOOD_DECALS:
		var blood := Art.decal(Art.DECALS + "decal_blood.png", rng.randf_range(1.0, 1.7), Color.WHITE, false)
		if blood == null or floors.is_empty():
			break
		blood.position = cell_to_world(floors[rng.randi() % floors.size()]) + Vector3(rng.randf_range(-0.5, 0.5), 0.012, rng.randf_range(-0.5, 0.5))
		blood.rotation.y = rng.randf() * TAU
		dressing.add_child(blood)
	for i in SCRATCH_DECALS + HANDPRINT_DECALS:
		var art := "decal_scratches.png" if i < SCRATCH_DECALS else "decal_handprint.png"
		var scratch := Art.decal(Art.DECALS + art, rng.randf_range(0.9, 1.4) if i < SCRATCH_DECALS else rng.randf_range(0.45, 0.65), Color(1, 1, 1, 0.85), false)
		if scratch == null or floors.is_empty():
			continue
		var cell := floors[rng.randi() % floors.size()]
		var walls: Array[Vector2i] = []
		for d in FloorLayout.DIRS:
			if not layout.is_open(NIGHTMARE, cell + d):
				walls.append(d)
		if walls.is_empty():
			scratch.free()
			continue
		var d: Vector2i = walls[rng.randi() % walls.size()]
		scratch.rotation = Vector3(PI * 0.5, atan2(-float(d.x), -float(d.y)), 0)
		scratch.position = cell_to_world(cell) + Vector3(d.x, 0, d.y) * (CELL_SIZE * 0.5 - 0.015) + Vector3(0, rng.randf_range(0.9, 1.6), 0)
		dressing.add_child(scratch)

## Landmarks (plans/07), the same in both worlds: a coloured or flickering lamp (seen from afar), a glyph painted on a
## wall, a statue with a candle, a debris pile. Delivered art replaces each stand-in (assets/ASSET_PROMPTS.md §3b).
func _build_landmarks() -> void:
	var root := Node3D.new()
	root.name = "Landmarks"
	add_child(root)
	var lamp_scene := Art.model("ceiling_lamp")
	var lamp_mesh := _first_mesh(lamp_scene) if lamp_scene != null else null
	for i in landmarks.cells.size():
		var at := cell_to_world(landmarks.cells[i])
		var side := landmarks.sides[i]
		var corner := side + Vector2i(side.y, side.x) if side != Vector2i.ZERO else Vector2i(1, 1)
		var spot := at + Vector3(corner.x, 0, corner.y) * LANDMARK_CORNER
		var facing := atan2(-float(corner.x), -float(corner.y))
		match landmarks.kinds[i]:
			Landmarks.Kind.LAMP, Landmarks.Kind.FLICKER:
				var glow := _glow_material(landmarks.color(i))
				var fixture := MeshInstance3D.new()
				if lamp_mesh != null:
					fixture.mesh = lamp_mesh
					fixture.position = at + Vector3(0, CEILING_HEIGHT - 0.09 - lamp_mesh.get_aabb().end.y, 0)
				else:
					var box := BoxMesh.new()
					box.size = Vector3(0.5, 0.05, 0.5)
					fixture.mesh = box
					fixture.material_override = glow
					fixture.position = at + Vector3(0, CEILING_HEIGHT - 0.12, 0)
				root.add_child(fixture)
				var bulb := MeshInstance3D.new()
				var sphere := SphereMesh.new()
				sphere.radius = LAMP_BULB_RADIUS * 1.6
				sphere.height = sphere.radius * 2.0
				bulb.mesh = sphere
				bulb.material_override = glow
				bulb.position = at + Vector3(0, CEILING_HEIGHT - LAMP_BULB_DROP, 0)
				root.add_child(bulb)
				var halo := MeshInstance3D.new()
				var quad := QuadMesh.new()
				quad.size = Vector2.ONE * LANDMARK_HALO
				halo.mesh = quad
				halo.material_override = _halo_material(landmarks.color(i))
				halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				halo.position = at + Vector3(0, minf(bulb.position.y, CEILING_HEIGHT - LANDMARK_HALO * 0.5), 0)
				root.add_child(halo)
				var light := _landmark_light(root, bulb.position, landmarks.color(i), LANDMARK_LIGHT.x, LANDMARK_LIGHT.y)
				if landmarks.kinds[i] == Landmarks.Kind.FLICKER:
					flicker_light = light
					flicker_bulb = glow
					flicker_halo = halo
			Landmarks.Kind.GLYPH:
				var number := landmarks.variants[i] + 1
				var paint: Node3D = Art.decal(Art.DECALS + "glyph_%d.png" % number, LANDMARK_GLYPH_SIZE, Color.WHITE, false)
				if paint != null:
					paint.rotation = Vector3(PI * 0.5, atan2(-float(side.x), -float(side.y)), 0)
				else:
					var label := Label3D.new()
					label.text = Landmarks.GLYPHS[landmarks.variants[i]]
					label.font = DeathScreen.ui_font()
					label.font_size = 160
					label.pixel_size = LANDMARK_GLYPH_SIZE / 160.0
					label.modulate = LANDMARK_GLYPH_COLOR
					label.outline_size = 0
					label.rotation.y = atan2(-float(side.x), -float(side.y))
					paint = label
				paint.position = at + Vector3(side.x, 0, side.y) * (CELL_SIZE * 0.5 - 0.02) + Vector3(0, LANDMARK_GLYPH_Y, 0)
				root.add_child(paint)
			Landmarks.Kind.STATUE:
				var statue := _landmark_prop(root, "landmark_statue", LANDMARK_STATUE_HEIGHT, spot, facing)
				if statue.get_child_count() == 1:  # stand-in: a hooded figure on a plinth
					var stone := StandardMaterial3D.new()
					stone.albedo_color = Color(0.3, 0.3, 0.32)
					stone.roughness = 1.0
					_stand_in(statue, BoxMesh.new(), Vector3(0.55, 0.35, 0.55), Vector3(0, 0.175, 0), stone)
					_stand_in(statue, CapsuleMesh.new(), Vector3(0.42, 1.3, 0.42), Vector3(0, 1.0, 0), stone)
					_stand_in(statue, SphereMesh.new(), Vector3(0.3, 0.34, 0.3), Vector3(0, 1.78, 0.02), stone)
				var flame := MeshInstance3D.new()
				var drop := SphereMesh.new()
				drop.radius = 0.03
				drop.height = 0.08
				flame.mesh = drop
				flame.material_override = _glow_material(LANDMARK_CANDLE)
				flame.position = spot + Vector3(-corner.x, 0, -corner.y) * 0.35 + Vector3(0, 0.12, 0)
				root.add_child(flame)
				_landmark_light(root, flame.position + Vector3(0, 0.2, 0), LANDMARK_CANDLE, 0.9, 3.2)
			Landmarks.Kind.DEBRIS:
				var pile := _landmark_prop(root, "landmark_debris", LANDMARK_DEBRIS_HEIGHT, spot, facing)
				if pile.get_child_count() == 1:  # stand-in: broken crates and a plank
					var wood := StandardMaterial3D.new()
					wood.albedo_color = Color(0.36, 0.25, 0.16)
					wood.roughness = 0.95
					var crate := _stand_in(pile, BoxMesh.new(), Vector3(0.7, 0.45, 0.55), Vector3(0, 0.225, 0), wood)
					crate.rotation.y = 0.3
					var top := _stand_in(pile, BoxMesh.new(), Vector3(0.45, 0.35, 0.4), Vector3(0.05, 0.62, 0.05), wood)
					top.rotation.y = -0.5
					var plank := _stand_in(pile, BoxMesh.new(), Vector3(1.1, 0.06, 0.2), Vector3(-0.2, 0.4, -0.25), wood)
					plank.rotation = Vector3(0, 0.9, 0.6)

## An unshaded material glowing `color` (landmark bulbs, the candle flame).
func _glow_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material

## A soft camera-facing glow (additive, radial falloff drawn in code) in `color`.
func _halo_material(color: Color) -> StandardMaterial3D:
	var falloff := GradientTexture2D.new()
	falloff.fill = GradientTexture2D.FILL_RADIAL
	falloff.fill_from = Vector2(0.5, 0.5)
	falloff.fill_to = Vector2(0.5, 0.0)
	falloff.gradient = Gradient.new()
	falloff.gradient.set_color(0, Color.WHITE)
	falloff.gradient.set_color(1, Color(1, 1, 1, 0))
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_texture = falloff
	material.albedo_color = Color(color, 0.7)
	return material

func _landmark_light(parent: Node3D, at: Vector3, color: Color, energy: float, reach: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.position = at
	parent.add_child(light)
	return light

## A solid prop in a cell corner, facing the cell centre: the delivered `model_name` fitted to `height`, or an empty
## pivot (only its collision child) for the caller to fill with a stand-in.
func _landmark_prop(parent: Node3D, model_name: String, height: float, at: Vector3, facing: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = at
	pivot.rotation.y = facing
	parent.add_child(pivot)
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_SHARED
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, height, 0.6)
	shape.shape = box
	shape.position.y = height * 0.5
	body.add_child(shape)
	pivot.add_child(body)
	var scene := Art.model(model_name)
	if scene != null:
		var model := scene.instantiate() as Node3D
		pivot.add_child(model)
		ModelFit.fit_height(model, height, 0.0)
	return pivot

func _stand_in(parent: Node3D, mesh: PrimitiveMesh, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	if mesh is BoxMesh:
		(mesh as BoxMesh).size = size
	elif mesh is CapsuleMesh:
		(mesh as CapsuleMesh).radius = size.x * 0.5
		(mesh as CapsuleMesh).height = size.y
	elif mesh is SphereMesh:
		(mesh as SphereMesh).radius = size.x * 0.5
		(mesh as SphereMesh).height = size.y
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	parent.add_child(part)
	return part

## The flickering landmark lamp drops out twice per LANDMARK_FLICKER_BEAT, so it reads from down a corridor.
func _flicker_landmark() -> void:
	if flicker_light == null:
		return
	var beat := fmod(Time.get_ticks_msec() * 0.001, LANDMARK_FLICKER_BEAT)
	var on := 0.08 if beat < 0.09 or (beat > 0.22 and beat < 0.3) else 1.0
	flicker_light.light_energy = LANDMARK_LIGHT.x * on
	flicker_bulb.albedo_color = flicker_light.light_color.darkened(1.0 - on)
	flicker_halo.visible = on > 0.5

## A box per layout.boxes cell, against a wall and facing into the cell: the back wall of a dead end (so it faces the
## way in), else a wall across from a way in, else any wall (a box on the route never blocks it). The keys (the
## sigils' rules, the key art, glowing in the colour of their world) wait hidden inside theirs until the lid comes
## up; with the Locksmith omen their boxes glint.
func _build_boxes() -> void:
	var glint := RunState.mod("key_glow", 1.0) > 1.0
	for i in layout.boxes.size():
		var cell := layout.boxes[i]
		var key := layout.sigils.find(cell)
		var back := Vector2i.ZERO
		for d in FloorLayout.DIRS:
			if not layout.is_open(FloorLayout.ANY, cell + d) and (back == Vector2i.ZERO or layout.is_open(FloorLayout.ANY, cell - d)):
				back = d
		var box := KeyBox.new()
		box.name = "KeyBox%d" % i
		box.position = cell_to_world(cell) + Vector3(back.x, 0, back.y) * (CELL_SIZE * 0.5 - KeyBox.DEPTH * 0.5 - BOX_WALL_GAP)
		box.rotation.y = atan2(float(-back.x), float(-back.y))
		add_child(box)
		box.build(LAYER_SHARED, SIGIL_COLORS[layout.sigil_worlds[key]] if key >= 0 and glint else Color(0, 0, 0, 0))
		box.opened.connect(_reveal_box.bind(i))
		box_nodes.append(box)
		box_opened.append(false)
	for i in layout.sigils.size():
		var key := KeyPickup.new()
		key.name = "Key%d" % i
		key.visible = false
		var box := box_nodes[layout.boxes.find(layout.sigils[i])]
		key.position = Vector3(0, box.top + 0.15, 0)
		key.scale = Vector3.ONE * BOX_KEY_SCALE
		box.add_child(key)
		key.build(SIGIL_COLORS[layout.sigil_worlds[i]], i * 1.3, RunState.mod("key_glow", 1.0))
		sigil_nodes.append(key)
		sigil_collected.append(false)

## A blue floor ring per circle; its glow is the drain meter.
func _build_circles() -> void:
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.8
	ring_mesh.outer_radius = 0.95
	for cell in circles.cells:
		var ring := Art.decal(Art.DECALS + "safe_circle.png", CIRCLE_DECAL_SIZE, CIRCLE_COLOR, true)
		var material: StandardMaterial3D
		if ring != null:
			circle_decals = true
			material = ring.material_override
			ring.position = cell_to_world(cell) + Vector3(0, 0.025, 0)
		else:
			material = StandardMaterial3D.new()
			material.albedo_color = Color(0.2, 0.55, 1.0)
			material.emission_enabled = true
			material.emission = Color(0.25, 0.6, 1.0)
			ring = MeshInstance3D.new()
			ring.mesh = ring_mesh
			ring.scale = Vector3(1.0, 0.15, 1.0)
			ring.position = cell_to_world(cell) + Vector3(0, 0.03, 0)
			ring.material_override = material
		ring.name = "SafeCircle%d" % circle_materials.size()
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
	var dust_mesh: Mesh
	var puff := Art.fx_material(Art.Fx.SMOKE, Color(0.42, 0.37, 0.33, 0.85), false)
	if puff != null:
		dust_mesh = QuadMesh.new()
		(dust_mesh as QuadMesh).size = Vector2.ONE * 0.45
		dust_mesh.material = puff
	else:
		dust_mesh = BoxMesh.new()
		(dust_mesh as BoxMesh).size = Vector3.ONE * 0.035
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
	for part: MeshInstance3D in devil_mesh.find_children("*", "MeshInstance3D", true, false):
		part.layers = DEVIL_LAYER  # the Devil Cam looks out of its eyes, not at its skull

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.02, 0.02)
	light.light_energy = 1.2
	light.omni_range = 3.0
	devil.add_child(light)
	if ghost_sight:
		ghost_glow = MeshInstance3D.new()
		ghost_glow.name = "GhostGlow"
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * GHOST_GLOW_SIZE
		ghost_glow.mesh = quad
		var glow := _halo_material(GHOST_GLOW_COLOR)
		glow.no_depth_test = true  # through the walls
		ghost_glow.material_override = glow
		ghost_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost_glow.layers = DEVIL_LAYER  # never in its own eyes (the Devil Cams)
		ghost_glow.position.y = WALL_HEIGHT * DEVIL_HEIGHT_RATIO * 0.6 - DEVIL_Y
		ghost_glow.visible = false
		devil.add_child(ghost_glow)

## Ghost Sight: its glow shows through the walls while it hunts within GHOST_SIGHT_TILES of you.
func _update_ghost_glow() -> void:
	if ghost_glow != null:
		ghost_glow.visible = devil_active and game_state == "playing" and _devil_distance() <= GHOST_SIGHT_TILES

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)
	has_map = RunState.mod("minimap", 1.0) > 0.0
	paper_map = PaperMap.new(_new_map(), feel.base_fov)
	paper_map.name = "PaperMap"
	hud.add_child(paper_map)
	_build_status(hud)
	_build_devil_corner(hud)
	stamina_bar = ProgressBar.new()  # bottom centre, only while you're short of breath
	stamina_bar.name = "Stamina"
	stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamina_bar.show_percentage = false
	stamina_bar.max_value = 1.0
	stamina_bar.step = 0.0
	stamina_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	stamina_bar.offset_left = -90
	stamina_bar.offset_right = 90
	stamina_bar.offset_top = -48
	stamina_bar.offset_bottom = -42
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0, 0, 0, 0.5)
	track.set_corner_radius_all(3)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = MainMenu.BONE
	stamina_bar.add_theme_stylebox_override("background", track)
	stamina_bar.add_theme_stylebox_override("fill", fill)
	stamina_bar.visible = false
	hud.add_child(stamina_bar)
	# Just under the centre while a closed box is in reach (_update_hud): the delivered icon, else the menu's chest.
	open_prompt = _hud_image(hud, "OpenPrompt", _hud_art("icon_open.png", Art.cell(MainMenu.ART + "ui_icons.png", MainMenu.Icon.CHEST, MainMenu.ICON_CELL)))
	open_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	open_prompt.offset_left = -22
	open_prompt.offset_right = 22
	open_prompt.offset_top = 40
	open_prompt.offset_bottom = 84
	open_prompt.visible = false
	var smoke :=Art.tex(Art.HUD + "banner.png")
	if smoke != null:
		# Smoke behind the centre messages, multiplied in (its white vanishes); shown with a message.
		banner = _hud_image(hud, "Banner", smoke)
		var multiply := CanvasItemMaterial.new()
		multiply.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
		banner.material = multiply
		banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
		banner.offset_left = -560
		banner.offset_right = 560
		banner.offset_top = 40
		banner.offset_bottom = 260
		banner.visible = false

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

	_build_hints(hud)

	# The run's build: its omens, curse and descents (plans/06 P4).
	omens_label = RichTextLabel.new()
	omens_label.name = "Omens"
	omens_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	omens_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	omens_label.offset_left = 24
	omens_label.offset_top = -80
	omens_label.offset_bottom = -46
	omens_label.add_theme_font_override("normal_font", DeathScreen.ui_font())
	omens_label.add_theme_font_size_override("normal_font_size", 16)
	omens_label.add_theme_color_override("default_color", OMEN_COLOR)
	hud.add_child(omens_label)
	for i in RunState.run_cards.size():
		var id := RunState.run_cards[i]
		if i > 0:
			omens_label.add_text("   ")
		var sigil := CardChoice.art(id) if Cards.kind(id) == "omen" else null
		if sigil != null:
			omens_label.add_image(sigil, 24, 24, OMEN_COLOR)
			omens_label.add_text(" ")
		omens_label.add_text(("CURSED: " if Cards.kind(id) == "curse" else "") + Cards.find(id)["name"])

	var dread := Art.tex(Art.HUD + "nightmare_overlay.png")
	if dread != null:
		nightmare_overlay = _hud_overlay(hud, "NightmareOverlay", dread)
	var warning_art := Art.tex(Art.HUD + "flip_warning_overlay.png")
	if warning_art != null:
		warning_overlay = _hud_overlay(hud, "WarningOverlay", warning_art)

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
	_build_pause_menu(overlays)

## Esc: the floor stops under a dark veil with RESUME and QUIT TO MENU (Esc and Q do the same). Quitting banks nothing:
## the floor replays when the run resumes.
func _build_pause_menu(overlays: CanvasLayer) -> void:
	var veil := ColorRect.new()
	veil.name = "PauseMenu"
	veil.color = Color(0.0, 0.0, 0.0, 0.65)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.visible = false
	overlays.add_child(veil)
	pause_menu = veil
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 14)
	veil.add_child(column)
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", DeathScreen.ui_font())
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", MainMenu.BONE)
	column.add_child(title)
	for entry: Array in [["Resume", "RESUME   [ESC]", _toggle_pause], ["Quit", "QUIT TO MENU   [Q]", _to_menu]]:
		var button := Button.new()
		button.name = entry[0]
		button.text = entry[1]
		button.flat = true
		button.add_theme_font_override("font", DeathScreen.ui_font())
		button.add_theme_font_size_override("font_size", 24)
		button.add_theme_color_override("font_color", MainMenu.BONE)
		button.add_theme_color_override("font_focus_color", GOLD)
		button.add_theme_color_override("font_hover_color", GOLD)
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.pressed.connect(entry[2])
		column.add_child(button)
	var hint := Label.new()
	hint.text = "R TWICE RUNS IT AGAIN FROM THE START" if RunState.is_race() else "R TWICE RESTARTS THE ACT ON A NEW MAZE"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", DeathScreen.ui_font())
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.55, 0.7, 0.82, 0.85))
	column.add_child(hint)

func _hud_label(hud: CanvasLayer, node_name: String, font_size: int, preset: Control.LayoutPreset, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.name = node_name
	label.set_anchors_preset(preset)
	label.horizontal_alignment = align
	label.add_theme_font_override("font", DeathScreen.ui_font())
	label.add_theme_font_size_override("font_size", font_size)
	hud.add_child(label)
	return label

## A minimap of this floor, for the sheet of the paper map: the real layout, boxes, circles, traps and landmarks.
func _new_map() -> Control:
	var map: Control = preload("res://scripts/minimap.gd").new()
	map.layout = layout
	map.fog_colors = fog_colors
	map.glow_colors = glow_colors
	map.box_opened = box_opened
	map.circles = circles
	map.traps = traps
	map.landmarks = landmarks
	map.crack_reveal = roundi(RunState.mod("crack_reveal", 0.0))
	return map

func _hud_image(hud: CanvasLayer, node_name: String, texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = node_name
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(rect)
	return rect

## A full-screen glow painted on black (added, so the black vanishes), hidden until its moment.
func _hud_overlay(hud: CanvasLayer, node_name: String, texture: Texture2D) -> TextureRect:
	var overlay := _hud_image(hud, node_name, texture)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	overlay.material = additive
	overlay.visible = false
	return overlay

## The status plate (top right), icons instead of words: the floor count and its rule cards; the world and the
## clock, the flip; the keys (then the chest they open) and the shards. Each icon is the delivered images/hud/ art
## (assets/MISSING_ASSETS.md), else one of the menu's icons standing in.
func _build_status(hud: CanvasLayer) -> void:
	var plate_art := Art.tex(Art.HUD + "hud_plate.png")
	if plate_art != null:
		var plate := _hud_image(hud, "Plate", plate_art)
		plate.modulate.a = 0.85
		_on_plate(plate, Vector4.ZERO)
	var rows := VBoxContainer.new()
	rows.name = "Status"
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.grow_horizontal = Control.GROW_DIRECTION_BEGIN  # a floor with many cards grows left, never off-screen
	hud.add_child(rows)
	_on_plate(rows, PLATE_INSET)
	var menu_icons := MainMenu.ART + "ui_icons.png"
	var death_icons := DeathScreen.ART + "gameover_icons.png"

	floor_label = _plate_label(20, MainMenu.BONE)
	floor_label.text = "%d/%d" % [rule.floor_in_act, StageRule.FLOORS_PER_ACT]
	if RunState.is_daily():
		floor_label.text = "%d/%d" % [RunState.daily_floor, Daily.FLOORS]
	elif RunState.is_race():
		floor_label.text = "#%d" % RunState.race_week
	elif rule.act == StageRule.ABYSS_ACT:
		floor_label.text = str(rule.floor_in_act)  # the depth
	var stairs := _hud_art("icon_floor.png", Art.cell(menu_icons, MainMenu.Icon.MAZE, MainMenu.ICON_CELL))
	var chips: Array = []  # the floor's rule cards (its opening flash names them)
	for id in RunState.floor_cards:
		var card := CardChoice.art(id)
		if card != null:
			chips.append(_plate_icon(card, CARD_CHIP))
	_plate_row(rows, [_plate_icon(stairs, Vector2.ONE * FLOOR_ICON), floor_label], chips)

	var hourglass := Art.cell(death_icons, DeathScreen.Icon.HOURGLASS, DeathScreen.ICON_CELL)
	world_icons.assign([_hud_art("icon_wake.png", hourglass), _hud_art("icon_nightmare.png", hourglass)])
	world_icon = _plate_icon(world_icons[WAKE], Vector2.ONE * PLATE_ICON)
	clock_label = _plate_label(28, Color.WHITE)
	# Red, and only while Flipping Time holds you (_update_hud): there is no flip button to show.
	flip_icon = _plate_icon(_hud_art("icon_flip.png", Art.cell(death_icons, DeathScreen.Icon.RETRY, DeathScreen.ICON_CELL)), Vector2.ONE * PLATE_ICON)
	flip_icon.modulate = FLIP_BLOCKED
	flip_icon.visible = false
	flip_label = _plate_label(22, MainMenu.BONE)
	_plate_row(rows, [world_icon, clock_label], [flip_icon, flip_label])

	key_hud = KeyHud.new()
	key_hud.name = "Keys"
	key_hud.build(layout.sigils.size())
	var chest := _hud_art("icon_chest.png", Art.cell(menu_icons, MainMenu.Icon.CHEST, MainMenu.ICON_CELL))
	chest_icon = _plate_icon(chest, Vector2.ONE * PLATE_ICON)
	chest_icon.visible = false
	var gem := _hud_art("icon_shards.png", Art.cell(menu_icons, MainMenu.Icon.GEM, MainMenu.ICON_CELL))
	shard_label = _plate_label(24, SHARD_COLOR)
	_plate_row(rows, [key_hud, chest_icon], [_plate_icon(gem, Vector2.ONE * PLATE_ICON * 0.8), shard_label])

## Pins `control` to the status plate's rect (top right), shrunk by `inset` (left, top, right, bottom).
func _on_plate(control: Control, inset: Vector4) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	control.offset_left = -PLATE_MARGIN.x - PLATE_SIZE.x + inset.x
	control.offset_top = PLATE_MARGIN.y + inset.y
	control.offset_right = -PLATE_MARGIN.x - inset.z
	control.offset_bottom = PLATE_MARGIN.y + PLATE_SIZE.y - inset.w

## The delivered images/hud/<file>, else `stand_in` until it arrives.
func _hud_art(file: String, stand_in: Texture2D) -> Texture2D:
	var art := Art.tex(Art.HUD + file)
	return art if art != null else stand_in

## An icon on the status plate, kept to its own shape inside `side`.
func _plate_icon(texture: Texture2D, side: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = side
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

## A number on the status plate, outlined so it reads over the plate's smoke.
func _plate_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", DeathScreen.ui_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 6)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

## One row of the status plate: `left` from its left edge, `right` against its right edge.
func _plate_row(rows: VBoxContainer, left: Array, right: Array) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	rows.add_child(row)
	for item: Control in left:
		row.add_child(item)
	var gap := Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	for item: Control in right:
		row.add_child(item)

## The controls along the bottom: each key on a keycap (once the art exists), then what it does.
func _build_hints(hud: CanvasLayer) -> void:
	var row := HBoxContainer.new()
	row.name = "Hints"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	row.offset_left = 24
	row.offset_top = -42
	row.offset_bottom = -10
	row.add_theme_constant_override("separation", 8)
	hud.add_child(row)
	var cap := Art.tex(Art.HUD + "keycap.png")
	var wide_cap := Art.tex(Art.HUD + "keycap_wide.png")
	for hint: Array in HINTS:
		var key: String = hint[0]
		var label := Label.new()
		label.text = key
		label.add_theme_font_override("font", DeathScreen.ui_font())
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", MainMenu.BONE)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if cap != null:
			var art := TextureRect.new()
			art.texture = wide_cap if key.length() > 1 else cap
			art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art.stretch_mode = TextureRect.STRETCH_SCALE
			art.custom_minimum_size = Vector2(maxf(32.0, 13.0 * key.length() + 26.0), 32)
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			art.add_child(label)
			row.add_child(art)
		else:
			row.add_child(label)
		var action := Label.new()
		action.text = ("RUN IT AGAIN" if key == "R R" and RunState.is_race() else hint[1]) + "   "
		action.add_theme_font_override("font", DeathScreen.ui_font())
		action.add_theme_font_size_override("font_size", 15)
		action.add_theme_color_override("font_color", Color(0.55, 0.7, 0.82, 0.85))
		action.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(action)

func _format_time(seconds: float) -> String:
	var total := int(seconds)
	@warning_ignore("integer_division")
	return "%d:%02d" % [total / 60, total % 60]

func _update_hud() -> void:
	clock_label.text = Race.format(elapsed) if RunState.is_race() else _format_time(maxf(time_left, 0.0))
	clock_label.modulate = Color(1.0, 0.35, 0.3, 0.6 + 0.4 * absf(sin(elapsed * 6.0))) if panic else Color.WHITE
	# The flip icon shows only while Flipping Time holds you, red, with the seconds until your controls come back.
	flip_icon.visible = flip.forced_active
	flip_label.text = str(ceili(maxf(flip.forced_left, 0.0))) if flip.forced_active else ""
	var winded := rest_left > 0.0  # red, refilling over the rest
	stamina_bar.value = 1.0 - rest_left / feel.sprint_recover_time if winded else stamina
	stamina_bar.visible = stamina < 1.0
	stamina_bar.modulate = FLIP_BLOCKED if winded else Color.WHITE
	chest_icon.visible = exit_open
	open_prompt.visible = _box_in_reach() >= 0
	shard_label.text = str(MetaState.shards + floor_shards)
	if warning_label.visible:
		warning_label.text = "FLIPPING TIME  %d
CONTROLS WILL INVERT" % maxi(ceili(flip.next_forced_in), 0)
		warning_label.modulate.a = 0.55 + 0.45 * sin(elapsed * 18.0)

## Heartbeat inside heartbeat_tiles (louder as it closes), its breath inside DEVIL_NEAR_DISTANCE.
func _update_devil_audio() -> void:
	var d := _devil_distance() if devil_active else 999
	if nightmare_overlay != null:
		nightmare_overlay.modulate.a = lerpf(NIGHTMARE_OVERLAY_ALPHA.y, NIGHTMARE_OVERLAY_ALPHA.x, clampf(float(d) / heartbeat_tiles, 0.0, 1.0))
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

## Your breath: the calm loop, crossfading to panting while a sprint is spent (sprinting or resting after one).
func _update_breath(delta: float) -> void:
	var heavy := stamina < 1.0
	var step := delta / feel.breath_fade_time
	breath_calm.volume_linear = move_toward(breath_calm.volume_linear, 0.0 if heavy else db_to_linear(feel.breath_volume_db), step)
	breath_heavy.volume_linear = move_toward(breath_heavy.volume_linear, db_to_linear(feel.breath_heavy_volume_db) if heavy else 0.0, step)

func _stop_tension_audio() -> void:
	for audio in [devil_approach_player, heartbeat_player, alarm_player, breath_calm, breath_heavy]:
		audio.stop()
	devil_approach_playing = false
	warning_label.visible = false
	if warning_overlay != null:
		warning_overlay.visible = false

## Floor clear (2D): a short overlay, then the next floor with a new maze and a fresh clock.
## The Gate (F10) clears the act instead: the next act opens for good and the run ends at the menu.
func _win_game() -> void:
	if game_state == "won":
		return
	game_state = "won"
	win_player.play()
	_stop_tension_audio()
	if RunState.is_race():
		_finish_race()
		return
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
	var last_daily := RunState.is_daily() and RunState.daily_floor == Daily.FLOORS
	if RunState.is_daily() and fixed_seed == 0:
		RunState.note_daily(Daily.mark(grade, chased_time), elapsed)
	elif fixed_seed == 0:
		MetaState.note_clear(rule.floor_number)
	if last_daily and RunState.mode == "daily":
		_count("daily_clears")
		_earn(Daily.CLEAR_SHARDS, "DAILY")
	var earned := "GRADE %s   ·   +%d SHARDS" % [grade, floor_shards]
	# Read before this clear is banked: an ending plays the first time only.
	var ending := _gate_ending() if rule.is_gate and fixed_seed == 0 else ""
	if fixed_seed == 0:
		RunState.note_floor(grade, sprinted)
		RunState.log_event("floor", {"floor": rule.floor_number, "act": rule.act, "mode": RunState.mode, "grade": grade,
				"time": snappedf(elapsed, 0.1), "cards": RunState.floor_cards})
	_bank()
	if last_daily:
		if fixed_seed == 0:
			RunState.end_run()
		_show_message("%s  CLEARED\n%s" % [_daily_name(), earned])
		get_tree().create_timer(FLOOR_CLEAR_TIME).timeout.connect(_finish_daily)
		return
	# Save progress now (with the picks it owes), so quitting during the overlay still lands past this floor.
	if not rule.is_gate:
		if fixed_seed == 0:
			RunState.advance_floor()
		_show_message("%s CLEARED   %s to spare\n%s" % [_where(rule), _format_time(time_left), earned])
		get_tree().create_timer(FLOOR_CLEAR_TIME).timeout.connect(_offer_picks)
		return
	if fixed_seed == 0:
		for line in RunState.master_act(grade):
			_pop(line)
		RunState.clear_gate()
	if rule.act == StageRule.ACT_COUNT:
		_show_message("YOU ESCAPED THE DESCENT\n" + earned)
	elif rule.act >= LiveOps.released_acts:
		_show_message("ACT %d CLEARED\nACT %d ARRIVES SOON\n%s" % [rule.act, rule.act + 1, earned])
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
func _daily_name() -> String:
	return "DAILY #%d" % Daily.number(RunState.daily_date)

## The Daily's last floor is cleared: a ranked run ends on its result, ready to copy and paste anywhere.
func _finish_daily() -> void:
	if RunState.mode != "daily":
		_show_ending(_daily_name() + "  ·  PRACTICE", "Practice cleared. Today's ranked result stands, and tomorrow brings a new maze.")
		return
	var cleared := Daily.result.filter(func(square: String) -> bool: return square != "died").size()
	_show_ending(_daily_name() + "  ·  CLEARED", "%d / %d floors in %s. Copy your result and paste it anywhere: Discord, X, a group chat. Tomorrow brings a new maze." % [
			cleared, Daily.FLOORS, _format_time(Daily.result_time)], Daily.share_text(RunState.daily_date, Daily.result, Daily.result_time))

## The Long Night (plans/11): the medals' par, and the week's best run walking beside you once there is one.
func _start_race() -> void:
	race_par = Race.par(layout, feel.walk_speed)
	var samples := Race.load_ghost(RunState.race_week)
	if samples.is_empty():
		return
	race_ghost = RaceGhost.new()
	race_ghost.name = "RaceGhost"
	race_ghost.samples = samples
	race_ghost.position.y = PLAYER_HEIGHT
	add_child(race_ghost)
	race_ghost.build(PLAYER_MODEL, WALL_HEIGHT * PLAYER_HEIGHT_RATIO, PLAYER_MESH_Y, PLAYER_MESH_YAW, feel.walk_speed,
			feel.walk_speed * feel.sprint_multiplier, HANDS_LAYER)  # you see it, the Devil Cams never do

## Every race frame: this run's ghost sample when one is due, and the best run's ghost where it was by now.
func _tick_race(delta: float) -> void:
	if RaceGhost.due(race_tape.size(), elapsed):
		race_tape.append_array([player.global_position.x, player.global_position.z, yaw + body_turn])
	if race_ghost != null:
		race_ghost.seek(elapsed, delta, player.global_position)

## A key taken in the Long Night: its split, against the best run's at the same key (the last one under the exit's call).
func _race_split() -> void:
	race_splits.append(elapsed)
	var n := race_splits.size()
	var line := "%d/%d   %s" % [n, layout.sigils.size(), Race.format(elapsed)]
	if Race.splits.size() >= n:
		line += "   %+.1f" % (elapsed - Race.splits[n - 1])
	if exit_open:
		_show_message("ALL KEYS FOUND — GET TO THE CHEST\n" + line)
	else:
		_flash_message(line)

## Out of the Long Night: the time and medal kept (Race.finish), a new best's ghost saved and sent to the board, then
## its page once the chest has opened.
func _finish_race() -> void:
	race_tape.append_array([player.global_position.x, player.global_position.z, yaw + body_turn])
	var was := Race.best
	var result := Race.finish(RunState.race_week, elapsed, race_splits, race_par)
	if result["best"]:
		Race.save_ghost(RunState.race_week, race_tape)
		if RunState.race_week == Race.this_week():  # a run begun before Monday's reset stays off the new board
			Portal.submit_time(roundi(elapsed * 1000.0))
	RunState.end_run()
	RunState.log_event("race", {"week": RunState.race_week, "time": snappedf(elapsed, 0.1), "medal": result["medal"],
			"best": result["best"], "keys": layout.sigils.size()})
	_show_message("ESCAPED  ·  %s" % Race.format(elapsed))
	get_tree().create_timer(FLOOR_CLEAR_TIME).timeout.connect(_show_race_result.bind(result, was))

func _show_race_result(result: Dictionary, was: float) -> void:
	var got: String = result["medal"]
	var lines: Array[String] = []
	if not result["best"]:
		lines.append("%s. Your best this week stands: %s." % [Race.format(elapsed), Race.format(Race.best)])
	elif was > 0.0:
		lines.append("%s: a new best, %.1f s faster." % [Race.format(elapsed), was - elapsed])
	else:
		lines.append("%s: your first time this week." % Race.format(elapsed))
	lines.append("%s medal%s." % [got.to_upper(), ": +%d shards" % result["shards"] if result["shards"] > 0 else ""])
	var times := Race.medal_times(race_par)
	for id: String in ["silver", "gold", "devil"]:
		if elapsed > times[id]:
			lines.append("Next: %s at %s." % [id.to_upper(), Race.format(times[id])])
			break
	if result["best"] and Portal.ready():
		lines.append("On the CrazyGames board: the top 3 and the top 1%, 5% and 10% earn trophies when the week ends.")
	lines.append("Your ghost runs your best with you next time. A new maze opens every Monday.")
	_show_ending("THE LONG NIGHT  #%d  ·  %s" % [RunState.race_week, got.to_upper()], "\n".join(lines),
			Race.share_text(RunState.race_week, Race.best, Race.top_medal()), _restart_game)

## `again` (optional) adds RUN IT AGAIN, focused first: the Long Night's next try.
func _show_ending(title: String, text: String, share := "", again := Callable()) -> void:
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
	if not share.is_empty():
		var copy := Button.new()
		copy.name = "CopyResult"
		copy.text = "COPY RESULT"
		copy.flat = true
		copy.add_theme_font_size_override("font_size", 20)
		copy.add_theme_color_override("font_color", GOLD)
		copy.pressed.connect(func() -> void:
			Daily.copy(share)
			copy.text = "COPIED")
		column.add_child(copy)
	column.add_child(carry_on)
	carry_on.grab_focus()
	if again.is_valid():
		var retry := Button.new()
		retry.name = "RunAgain"
		retry.text = "RUN IT AGAIN"
		retry.flat = true
		retry.add_theme_font_size_override("font_size", 20)
		retry.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		retry.add_theme_color_override("font_focus_color", GOLD)
		retry.add_theme_color_override("font_hover_color", GOLD)
		retry.pressed.connect(func() -> void:
			page.queue_free()
			again.call())
		column.add_child(retry)
		column.move_child(retry, carry_on.get_index())
		retry.grab_focus()
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
		return "CHOOSE YOUR DOOR  ·  " + _where(StageRule.for_floor(RunState.current_floor))
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
	"devil": ["THE DEVIL GOT YOU", "It always finds you, but up close it is slower than your walk: keep moving. It is slower in WAKE, and a safe circle holds it off."],
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
	if RunState.is_daily() and fixed_seed == 0:
		RunState.note_daily("died", elapsed)
	elif fixed_seed == 0 and RunState.is_campaign():
		MetaState.note_death(rule.floor_number)  # hidden mercy (plans/06 G3)
	if fixed_seed == 0:
		RunState.log_event("death", {"floor": rule.floor_number, "act": rule.act, "mode": RunState.mode, "cause": cause,
				"time": snappedf(elapsed, 0.1), "progress": snappedf(clampf(_progress(), 0.0, 1.0), 0.01),
				"world": world, "flipping": flip.forced_active,
				"map_up": paper_map.is_up(), "since_map": snappedf(elapsed - map_closed_at, 0.1) if map_closed_at >= 0.0 else -1.0})
	var news := _bank()  # dying keeps every shard
	# Death ends the run now (quitting here can't buy a retry of this maze); a revive brings it back.
	if fixed_seed == 0:
		RunState.end_run()
	var steps := maxi(exit_dist[world][player_cell.y * layout.size + player_cell.x], 0)
	var floor_progress := clampf(_progress(), 0.0, 1.0)
	var abyss := rule.act == StageRule.ABYSS_ACT
	# The Voice's floor lines (the first floor, the Gate) are an act's; the Abyss has neither.
	var comeback := Lore.voice(cause, MetaState.stat("deaths"), floor_progress, 0 if abyss else rule.floor_in_act)
	var detail := "%d m from the exit   ·   Act %d, floor %d / %d   ·   best floor %d / %d\n%s" % [
		roundi(steps * CELL_SIZE), rule.act, rule.floor_in_act, StageRule.FLOORS_PER_ACT,
		mini(RunState.best_floor, StageRule.LAST_FLOOR), StageRule.LAST_FLOOR, comeback]
	if abyss:
		detail = "%d m from the exit   ·   The Abyss, depth %d   ·   deepest %d\n%s" % [roundi(steps * CELL_SIZE),
				rule.floor_in_act, MetaState.abyss_best, comeback]
	if RunState.is_daily():
		detail = "%d m from the exit   ·   Daily #%d, floor %d / %d\n%s" % [roundi(steps * CELL_SIZE),
				Daily.number(RunState.daily_date), RunState.daily_floor, Daily.FLOORS, comeback]
	var can_revive := not snapshot.is_empty() and RunState.revives_left() > 0
	var revive_text := "%d LEFT  ·  [V]" % RunState.revives_left() if not snapshot.is_empty() else "REACH A SAFE CIRCLE FIRST"
	var progress := MetaState.unlock_progress()
	var business := "+%d SHARDS THIS RUN   ·   %s   ·   %s" % [RunState.run_shards + floor_shards,
			"UNLOCK READY" if progress >= 1.0 else "NEXT UNLOCK %d%%" % floori(progress * 100.0), _shortcut_line()]
	var retry := "NEW RUN  ·  THE ABYSS  ·  [R]" if abyss else "NEW RUN  ·  ACT %d  ·  [R]" % rule.act
	if fixed_seed == 0 and RunState.has_sanctuary():
		retry = "FROM THE SANCTUARY  ·  [R]"
	var share := ""
	if RunState.is_daily():
		retry = "PRACTICE  ·  [R]"
		revive_text = "ONE LIFE IN THE DAILY"
		business = "%s  ·  FLOOR %d / %d" % [_daily_name(), RunState.daily_floor, Daily.FLOORS]
		if RunState.mode == "daily":
			share = Daily.share_text(RunState.daily_date, Daily.result, Daily.result_time)
	if RunState.is_race():
		detail = "%d m from the exit   ·   The Long Night #%d, keys %d / %d\n%s" % [roundi(steps * CELL_SIZE),
				RunState.race_week, sigils_collected, layout.sigils.size(), comeback]
		retry = "RUN IT AGAIN  ·  [R]"
		revive_text = "NO REVIVES IN THE LONG NIGHT"
		business = "THE LONG NIGHT  #%d  ·  %s" % [RunState.race_week, "BEST " + Race.format(Race.best) if Race.best > 0.0 else "NO TIME YET"]
	if not news.is_empty():
		business += "\n" + "   ·   ".join(news)
	death_screen.show_death(DEATH_TEXT[cause][0], DEATH_TEXT[cause][1], detail, revive_text, can_revive, retry, business, share)
	get_node("HUD").visible = false  # the death screen stands alone
	if cause == "devil" and tape.size() >= 5:
		_start_devil_cam()

func _record_tape(delta: float) -> void:
	_tape_clock += delta
	if _tape_clock < TAPE_STEP or not devil_active:
		return
	_tape_clock = 0.0
	tape.append([devil.position, devil.rotation.y, player.global_position, kneel_box, open_t, kneel_w, map_w,
			yaw + body_turn, gait_speed])
	if tape.size() > roundi(TAPE_SECONDS / TAPE_STEP):
		tape.pop_front()

## Devil Cam (plans/06 C6): the last seconds again, through its eyes, in a corner of the death screen. Clip bait.
func _start_devil_cam() -> void:
	devil_cam = _devil_view()
	devil_cam.name = "DevilCam"
	devil_cam.position = Vector2(16, 16)
	devil_cam.size = DEVIL_CAM_SIZE
	death_screen.add_child(devil_cam)
	var tag := Label.new()
	tag.name = "DevilCamTag"
	tag.text = "DEVIL CAM"
	tag.position = Vector2(26, 20)
	tag.add_theme_font_override("font", DeathScreen.ui_font())
	tag.add_theme_font_size_override("font_size", 16)
	tag.add_theme_color_override("font_color", MainMenu.BLOOD)
	death_screen.add_child(tag)
	_replay_time = 0.0
	_replay(0.0)

## One frame of the Devil Cam: both of you where you were (looping, a little slowed), its eye on you.
func _replay(delta: float) -> void:
	_replay_time = fmod(_replay_time + delta * REPLAY_SPEED, TAPE_STEP * (tape.size() - 1))
	var at := _replay_time / TAPE_STEP
	var i := mini(floori(at), tape.size() - 2)
	var t := at - i
	var a: Array = tape[i]
	var b: Array = tape[i + 1]
	devil.position = (a[0] as Vector3).lerp(b[0], t)
	devil.rotation.y = lerp_angle(a[1], b[1], t)
	player.global_position = (a[2] as Vector3).lerp(b[2], t)
	if player_rig != null:
		# Your body as it was: the way it faced and walked, glancing back at it, a box it knelt at (its lid swinging
		# again), the map up. The mesh turns, not the body, so your camera stays put.
		player_mesh.rotation.y = deg_to_rad(PLAYER_MESH_YAW) + lerp_angle(a[7], b[7], t) - player.rotation.y
		var box: int = (a if t < 0.5 else b)[3]
		var since: float = lerpf(a[4], b[4], t)
		if box >= 0 and box_nodes[box].is_open:
			box_nodes[box].lid.rotation.x = KeyBox.lid_angle(since - KeyBox.GRIP_AT)
		var y := player_rig.flee(lerpf(a[8], b[8], t), delta, 1.0, 0.0, Vector2.ZERO, true)
		_pose_body(y, box, since, lerpf(a[5], b[5], t), lerpf(a[6], b[6], t))
	devil_mesh.position.y = -DEVIL_Y + devil_rig.prowl(((b[0] as Vector3) - a[0]).length() / TAPE_STEP, delta, Vector3.INF, 0.0)
	_aim_devil_eye(_devil_eye(devil_cam))

## A window out of the Devil's eyes: its own camera on the shared maze, blind to its own skull, seeing in the dark by
## its red glare (the eye's only child: a real light, so the maze shows it too).
func _devil_view() -> SubViewportContainer:
	var frame := SubViewportContainer.new()
	frame.stretch = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view := SubViewport.new()
	view.world_3d = get_viewport().find_world_3d()
	frame.add_child(view)
	var eye := Camera3D.new()
	eye.cull_mask = 0xFFFFF & ~DEVIL_LAYER & ~HANDS_LAYER
	eye.fov = 70.0
	eye.environment = _devil_sight()
	var glare := SpotLight3D.new()
	glare.light_color = Color(1.0, 0.3, 0.25)
	glare.light_energy = DEVIL_GLARE.x
	glare.spot_range = DEVIL_GLARE.y
	glare.spot_angle = DEVIL_GLARE.z
	eye.add_child(glare)
	view.add_child(eye)
	eye.current = true
	return frame

func _devil_eye(frame: SubViewportContainer) -> Camera3D:
	return frame.get_child(0).get_child(0) as Camera3D

## This world's look, brighter and with thinner fog: it sees in the dark.
func _devil_sight() -> Environment:
	var sight := env.duplicate() as Environment
	sight.ambient_light_energy = env.ambient_light_energy * DEVIL_SIGHT.x
	sight.tonemap_exposure = env.tonemap_exposure * DEVIL_SIGHT.y
	sight.fog_density = env.fog_density * DEVIL_SIGHT.z
	return sight

## Its eyes on you while it can see you; round a corner, on the way ahead.
func _aim_devil_eye(eye: Camera3D) -> void:
	eye.global_position = devil.global_position + Vector3(0, DEVIL_EYE - DEVIL_Y, 0)
	var target := eye.global_position + Vector3(sin(devil.rotation.y), -0.1, cos(devil.rotation.y))
	if DevilBrain.line_of_sight(layout, world, world_to_cell(devil.global_position), world_to_cell(player.global_position)):
		target = player.global_position + Vector3(0, 0.3, 0)
	var gap := target - eye.global_position
	if Vector2(gap.x, gap.z).length() > 0.1:  # never straight down at you mid-lunge: look_at can't aim along UP
		eye.look_at(target)

## The top-left corner while it hunts (user, 9 Oct 2026): a live Devil Cam, and under it the Devil's icon and how far
## it is along the corridors. Hidden while nothing hunts.
func _build_devil_corner(hud: CanvasLayer) -> void:
	devil_corner = VBoxContainer.new()
	devil_corner.name = "DevilCorner"
	devil_corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	devil_corner.position = Vector2(16, 16)
	devil_corner.visible = false
	hud.add_child(devil_corner)
	live_cam = _devil_view()
	live_cam.name = "LiveCam"
	live_cam.custom_minimum_size = LIVE_CAM_SIZE
	devil_corner.add_child(live_cam)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	devil_corner.add_child(row)
	var demon := Art.cell(MainMenu.ART + "ui_icons.png", MainMenu.Icon.DEMON, MainMenu.ICON_CELL)
	row.add_child(_plate_icon(_hud_art("icon_devil.png", demon), Vector2.ONE * PLATE_ICON))
	devil_meter = _plate_label(26, Color.WHITE)  # tinted by its row: bone, amber, then red
	row.add_child(devil_meter)

## Its live eyes and its distance, which pulse faster, amber then red, as it closes in. Only while it hunts on a live
## floor: its glare lights the real maze, so it goes out with the corner.
func _update_devil_corner() -> void:
	var on := devil_active and game_state == "playing"
	devil_corner.visible = on
	var eye := _devil_eye(live_cam)
	(eye.get_child(0) as SpotLight3D).visible = on
	if not on:
		return
	_aim_devil_eye(eye)
	var d := _devil_distance()
	var metres := d * CELL_SIZE
	devil_meter.text = "%d m" % roundi(metres) if d < 999 else "--"
	var color := MainMenu.BONE
	if metres <= DEVIL_METER_WARN.x:
		color = MainMenu.BLOOD
	elif metres <= DEVIL_METER_WARN.y:
		color = Color(1.0, 0.6, 0.2)
	var urgency := clampf(1.0 - metres / DEVIL_METER_WARN.y, 0.0, 1.0)
	(devil_meter.get_parent() as Control).modulate = Color(color, 0.55 + 0.45 * absf(sin(elapsed * (2.0 + 8.0 * urgency))))

func _stop_devil_cam() -> void:
	if devil_cam == null:
		return
	for node: Node in [devil_cam, death_screen.get_node_or_null("DevilCamTag")]:
		if node != null:
			death_screen.remove_child(node)
			node.queue_free()
	devil_cam = null
	devil.position = _devil_world_position()
	for box in box_nodes:
		if box.is_open:
			box.lid.rotation.x = KeyBox.lid_angle(KeyBox.LID_TIME)  # the replay swung it

## How far the next act's shortcut is (just the Gate once that act is open; the escape in the last act; your deepest
## in the Abyss).
func _shortcut_line() -> String:
	if rule.act == StageRule.ABYSS_ACT:
		var to_beat := MetaState.abyss_best + 2 - rule.floor_in_act
		return "%d FLOOR%s TO BEAT YOUR DEEPEST" % [to_beat, "" if to_beat == 1 else "S"]
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
	_stop_devil_cam()
	get_node("HUD").visible = true
	floor_revives += 1
	# Its rewarded ad already played on the death screen (DeathScreen._leave, Ads).
	death_screen.visible = false
	_return_to_circle()
	for breath: AudioStreamPlayer in [breath_calm, breath_heavy]:
		if breath.stream != null:
			breath.play()  # the death stopped your breathing
	warning_label.visible = flip.warning_active
	if warning_overlay != null:
		warning_overlay.visible = flip.warning_active
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_flash_message("REVIVED   %d left this act" % RunState.revives_left())

## Back to the last safe circle you used (the spawn if none yet) with its clock and floor cracks; the Devil sleeps.
func _return_to_circle() -> void:
	var at: Dictionary = snapshot if not snapshot.is_empty() else {"cell": layout.spawn, "time_left": time_left, "traps": traps.states.duplicate(), "trail": 1}
	var cell: Vector2i = at["cell"]
	brain.rewind(at["trail"])  # it wakes behind you again, never on the path you walked after this circle
	player.global_position = cell_to_world(cell) + Vector3(0, PLAYER_HEIGHT, 0)
	player.velocity = Vector3.ZERO
	camera_pivot.position = Vector3(0.0, EYE_HEIGHT, 0.0)
	camera_pivot.rotation.x = pitch
	player.rotation = Vector3(0.0, yaw, 0.0)
	player_mesh.rotation_degrees.y = PLAYER_MESH_YAW  # the Devil Cam turned it to run along the tape
	body_turn = 0.0
	camera.top_level = false
	camera.transform = Transform3D()
	camera.cull_mask &= ~PLAYER_LAYER
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
	# It goes back to sleep instead of standing where it caught you: it wakes again later, behind you, far away and
	# out of sight, with the usual telegraph (_try_spawn_devil), and not while you're still in the circle.
	devil_active = false
	devil_spawning = false
	devil_retreating = false
	devil_stun = 0.0
	thin_wall = DevilBrain.NOWHERE
	devil.visible = false
	game_state = "playing"

## TRY AGAIN: a new run from this act's first floor on a new maze, or, after a death past the act's Sanctuary, back to
## it (plans/10 §4). R R mid-floor always starts the act over. A debug seed just reloads.
func _restart_game() -> void:
	_bank()
	if fixed_seed == 0 and RunState.is_daily():
		RunState.start_daily(true)
	elif fixed_seed == 0 and RunState.is_race():
		RunState.start_race()  # the same maze again, from the start
	elif fixed_seed == 0:
		var to_sanctuary := game_state == "lost" and RunState.restart_at_sanctuary()
		if not to_sanctuary:
			RunState.start_run(rule.act, true, true)  # a retry keeps the act's start kit: straight back in, no picks
	get_tree().reload_current_scene()

## Push the live world and your position to the paper map's sheet while it's in your hands (grid cells, floats); a
## put-away map shows nothing, so it is never a live GPS. It marks the Devil where it is (user, 9 Oct 2026).
func _refresh_minimap() -> void:
	if paper_map == null or not paper_map.is_up():
		return
	var map := paper_map.sheet
	var forward := -player.global_transform.basis.z
	map.world = world
	map.exit_open = exit_open
	map.player_pos = Vector2(player.global_position.x, player.global_position.z) / CELL_SIZE
	map.facing = Vector2(forward.x, forward.z).angle()
	map.devil_awake = devil_active
	map.devil_pos = Vector2(devil.position.x, devil.position.z) / CELL_SIZE
	map.devil_distance = _devil_distance() * CELL_SIZE if _devil_distance() < 999 else -1.0

## M: the paper map comes out of your back pocket, or goes back once it's open; halfway out or in, M waits. Not on a
## no-map floor, not with the Devil close.
func _toggle_map() -> void:
	match paper_map.state():
		PaperMap.State.OPEN:
			_close_map("hand")
		PaperMap.State.CLOSED:
			if not has_map:
				_flash_message("No map on this floor.")
			elif _map_unsafe():
				_flash_message("Not now. It's close.")
			else:
				_stand_up()
				paper_map.open()
				map_opened_at = elapsed
				_refresh_minimap()
				if fixed_seed == 0:
					RunState.log_event("map_open", {"floor": rule.floor_number, "act": rule.act, "world": world,
							"devil": _devil_distance() if devil_active else -1})

## Back in the pocket, and how long it was out for the playtest log. `reason`: "hand" (M), "devil" (snapped shut by
## _map_unsafe), "wake" (the Devil wakes) or "end" (gone at once: the floor is over).
func _close_map(reason: String) -> void:
	if paper_map.opening:
		map_closed_at = elapsed
		if fixed_seed == 0:
			RunState.log_event("map_close", {"floor": rule.floor_number, "reason": reason,
					"held": snappedf(elapsed - map_opened_at, 0.1), "devil": _devil_distance() if devil_active else -1})
	if reason == "end":
		paper_map.stow()
	else:
		paper_map.close(reason != "hand")

## Too dangerous to read: close enough to hear its heartbeat (path tiles), or at its pace right now it reaches you
## within feel.map_snap_time. Path length, not straight-line distance, and its real speed (rubber band, prowl, rage).
func _map_unsafe() -> bool:
	return _devil_close() or (devil_active and _devil_distance() * _devil_step_interval() <= feel.map_snap_time)

## Close enough to hear its heartbeat.
func _devil_close() -> bool:
	return devil_active and _devil_distance() <= HEARTBEAT_TILES

func _show_message(text: String) -> void:
	if state_label == null:
		return
	state_label.text = text
	if banner != null:
		banner.visible = text != ""

## A message that clears itself after 2.5 s (unless the game ended meanwhile; a wake cut still clears it).
func _flash_message(text: String) -> void:
	_show_message(text)
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if game_state in ["playing", "waking"] and state_label.text == text:
			_show_message(""))

func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * CELL_SIZE, 0, cell.y * CELL_SIZE)

func world_to_cell(position: Vector3) -> Vector2i:
	return Vector2i(round(position.x / CELL_SIZE), round(position.z / CELL_SIZE))
