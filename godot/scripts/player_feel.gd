class_name PlayerFeel
extends Resource
## First-person feel tunables (movement, look, head-bob, FOV breathing, flashlight, footsteps).
## Edit res://resources/player_feel.tres in the Inspector; no code changes needed.

@export_group("Movement")
@export_range(0.5, 8.0, 0.1, "suffix:m/s") var walk_speed: float = 3.0
@export_range(1.0, 2.5, 0.05) var sprint_multiplier: float = 1.5
## Longest sprint, in seconds.
@export_range(0.5, 20.0, 0.5, "suffix:s") var sprint_time: float = 4.0
## Rest after any sprint ends (run dry or let go) before the next (sprint_time + this = the 10 s cycle).
@export_range(0.5, 20.0, 0.5, "suffix:s") var sprint_recover_time: float = 6.0
## How fast you reach walk speed. Lower = heavier, more dread.
@export_range(1.0, 60.0, 0.5, "suffix:m/s²") var acceleration: float = 12.0
## How fast you stop when keys are released. Higher = snappier stops.
@export_range(1.0, 60.0, 0.5, "suffix:m/s²") var friction: float = 16.0
@export_range(0.0, 1.0, 0.05) var air_control: float = 0.3

@export_group("Look")
@export_range(0.0005, 0.01, 0.0001) var mouse_sensitivity: float = 0.0025
@export_range(0.5, 6.0, 0.1, "suffix:rad/s") var stick_look_speed: float = 2.5
@export_range(0.5, 1.55, 0.01, "suffix:rad") var max_pitch: float = 1.35
@export_range(0.05, 0.9, 0.05) var stick_deadzone: float = 0.2

@export_group("Head Bob")
## Distance per footstep. Bob cycle and footstep cadence both follow it.
@export_range(0.3, 2.0, 0.05, "suffix:m") var step_length: float = 0.8
@export_range(0.0, 0.15, 0.005, "suffix:m") var bob_amplitude: float = 0.04
@export_range(0.0, 1.0, 0.05) var bob_sway_ratio: float = 0.5
@export_range(1.0, 20.0, 0.5) var bob_blend_speed: float = 8.0

@export_group("FOV Breathing")
@export_range(50.0, 100.0, 0.5, "suffix:°") var base_fov: float = 72.0
@export_range(0.0, 4.0, 0.05, "suffix:°") var breath_fov_amplitude: float = 0.6
@export_range(0.05, 2.0, 0.01, "suffix:Hz") var breath_rate: float = 0.22
@export_range(0.05, 3.0, 0.01, "suffix:Hz") var sprint_breath_rate: float = 0.75
@export_range(0.0, 15.0, 0.5, "suffix:°") var sprint_fov_boost: float = 4.0
@export_range(1.0, 20.0, 0.5) var fov_blend_speed: float = 5.0

@export_group("Flashlight")
@export_range(0.0, 10.0, 0.1) var flashlight_energy: float = 3.2
@export_range(2.0, 30.0, 0.5, "suffix:m") var flashlight_range: float = 12.0
@export_range(5.0, 60.0, 0.5, "suffix:°") var flashlight_angle: float = 30.0
## Constant subtle wobble, as a fraction of energy.
@export_range(0.0, 0.5, 0.01) var flicker_strength: float = 0.08
## Chance per second of a short dip. Kept brief so it never blinds the player.
@export_range(0.0, 1.0, 0.01, "suffix:/s") var stutter_chance: float = 0.06
@export_range(0.02, 0.5, 0.01, "suffix:s") var stutter_duration: float = 0.12
@export_range(0.0, 1.0, 0.05) var stutter_energy_ratio: float = 0.25

@export_group("Footsteps")
## Real level (plain player, no 3D falloff). The footstep WAVs peak at -3 dBFS: walk + sprint boost above ~+3 dB starts to clip.
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var footstep_volume_db: float = 2.0
@export_range(0.0, 12.0, 0.5, "suffix:dB") var sprint_footstep_boost_db: float = 2.0
## Below this real speed no steps play and the bob stops advancing.
@export_range(0.0, 2.0, 0.05, "suffix:m/s") var min_step_speed: float = 0.4

@export_group("Breathing")
## Your slow, nervous breath while you walk the maze (sfx_breath_calm.mp3).
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var breath_volume_db: float = -24.0
## Panting while you sprint and while you rest after one (sfx_breath_heavy.mp3).
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var breath_heavy_volume_db: float = -15.0
## Seconds to crossfade between the two.
@export_range(0.1, 3.0, 0.1, "suffix:s") var breath_fade_time: float = 0.6

@export_group("Paper Map")
## Walking speed with the map in your hands (x walk speed); no sprint and no flip until it's back in the pocket.
@export_range(0.1, 1.0, 0.05) var map_walk_ratio: float = 0.25
## The map snaps shut once the Devil, at its pace right now, would reach you within this many seconds (on top of
## heartbeat range): the snap and your first steps fit inside it, so a forced close is never a free catch.
@export_range(1.0, 12.0, 0.5, "suffix:s") var map_snap_time: float = 5.0


## One footstep per PI of phase. The phase advances only on the floor and above min_step_speed.
func advance_step_phase(phase: float, horizontal_speed: float, delta: float, on_floor: bool) -> float:
	if not on_floor or horizontal_speed < min_step_speed:
		return phase
	return phase + horizontal_speed / step_length * PI * delta


static func crossed_step(old_phase: float, new_phase: float) -> bool:
	return floorf(new_phase / PI) > floorf(old_phase / PI)


## Camera offset: lowest point at each footfall, side sway alternates per step.
func bob_offset(phase: float, intensity: float) -> Vector3:
	var s: float = sin(phase)
	return Vector3(s * bob_amplitude * bob_sway_ratio, -bob_amplitude * (1.0 - absf(s)), 0.0) * intensity
