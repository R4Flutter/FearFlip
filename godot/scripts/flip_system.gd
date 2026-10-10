class_name FlipSystem
extends RefCounted
## Flipping Time (FEARFLIP_3D_GAME_APPROACH.md §4). There is no flip button (user, 10 Oct 2026): the world flips on
## its own, at random. NIGHTMARE takes you after a warning, then lets go. Pure logic: main.gd feeds time and whether
## the player's spot is open in each world; everything visual listens to `flipped`.

## `forced` is always true now that every flip is Flipping Time's; kept so listeners read the same.
signal flipped(world: int, forced: bool)
## Fired once, `warning_time` seconds before Flipping Time pulls the player into NIGHTMARE.
signal flipping_time_warning

const WAKE := FloorLayout.World.WAKE
const NIGHTMARE := FloorLayout.World.NIGHTMARE

## Tunables (all targets to playtest).
var first_forced_at := 45.0
## arm() lands the first Flipping Time up to this share before or after first_forced_at, at random.
var first_jitter := 0.25
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
var next_forced_in := 0.0
var forced_active := false
var forced_left := 0.0
var warning_active := false
var forced_count := 0
var _rng := RandomNumberGenerator.new()


func _init(rng_seed: int = 0) -> void:
	_rng.seed = rng_seed
	next_forced_in = first_forced_at


## Sets the first Flipping Time at a random moment around first_forced_at (after the floor sets the tunables).
func arm() -> void:
	next_forced_in = first_forced_at * _rng.randf_range(1.0 - first_jitter, 1.0 + first_jitter)


## A forced flip never puts the player inside a wall: it waits until their spot is open.
func advance(delta: float, wake_open: bool, nightmare_open: bool) -> void:
	if forced_active:
		forced_left -= delta
		if forced_left <= 0.0 and wake_open:
			forced_active = false
			next_forced_in = maxf(_rng.randf_range(forced_interval_min, forced_interval_max) - interval_ramp * forced_count, min_forced_interval)
			_set_world(WAKE)
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
			_set_world(NIGHTMARE)


func _set_world(new_world: int) -> void:
	world = new_world
	flipped.emit(world, true)
