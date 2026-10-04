class_name FlipSystem
extends RefCounted
## World Flip + Flipping Time (FEARFLIP_3D_GAME_APPROACH.md §4). Pure logic: main.gd feeds time and
## whether the player's spot is open in each world; everything visual listens to `flipped`.

signal flipped(world: int, forced: bool)
signal flip_denied
## Fired once, `warning_time` seconds before Flipping Time pulls the player into NIGHTMARE.
signal flipping_time_warning

const WAKE := FloorLayout.World.WAKE
const NIGHTMARE := FloorLayout.World.NIGHTMARE

## Tunables (all targets to playtest).
var cooldown := 6.0
var first_forced_at := 45.0
var forced_interval_min := 40.0
var forced_interval_max := 60.0
## Each Flipping Time comes this much sooner than the last, down to min_forced_interval.
var interval_ramp := 4.0
var min_forced_interval := 25.0
var warning_time := 3.0
var forced_duration_min := 12.0
var forced_duration_max := 20.0
## Each Flipping Time lasts this much longer than the last, up to forced_duration_max.
var duration_ramp := 2.0

var world: int = WAKE
var cooldown_left := 0.0
var next_forced_in := 0.0
var forced_active := false
var forced_left := 0.0
var warning_active := false
var forced_count := 0
var _rng := RandomNumberGenerator.new()


func _init(rng_seed: int = 0) -> void:
	_rng.seed = rng_seed
	next_forced_in = first_forced_at


func can_flip() -> bool:
	return not forced_active and not warning_active and cooldown_left <= 0.0


## Manual flip. `target_open` = the player's spot is open in the other world.
func request_flip(target_open: bool) -> bool:
	if not can_flip() or not target_open:
		flip_denied.emit()
		return false
	cooldown_left = cooldown
	_set_world(1 - world, false)
	return true


## A forced flip never puts the player inside a wall: it waits until their spot is open.
func advance(delta: float, wake_open: bool, nightmare_open: bool) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	if forced_active:
		forced_left -= delta
		if forced_left <= 0.0 and wake_open:
			forced_active = false
			next_forced_in = maxf(_rng.randf_range(forced_interval_min, forced_interval_max) - interval_ramp * forced_count, min_forced_interval)
			_set_world(WAKE, true)
		return
	next_forced_in -= delta
	if not warning_active and next_forced_in <= warning_time:
		warning_active = true
		flipping_time_warning.emit()
	if next_forced_in <= 0.0 and (world == NIGHTMARE or nightmare_open):
		warning_active = false
		forced_active = true
		forced_left = minf(_rng.randf_range(forced_duration_min, forced_duration_min + duration_ramp * 2.0) + duration_ramp * forced_count, forced_duration_max)
		forced_count += 1
		if world != NIGHTMARE:
			_set_world(NIGHTMARE, true)


func _set_world(new_world: int, forced: bool) -> void:
	world = new_world
	flipped.emit(world, forced)
