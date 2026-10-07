extends McpTestSuite
## Flip rules (FEARFLIP_3D_GAME_APPROACH.md §4): cooldown, blocked flips, announced Flipping Time,
## and no flip ever lands the player inside a wall.

const WAKE := FloorLayout.World.WAKE
const NIGHTMARE := FloorLayout.World.NIGHTMARE


func suite_name() -> String:
	return "flip_system"


func _run(flip: FlipSystem, seconds: float, wake_open := true, nightmare_open := true) -> void:
	var dt := 1.0 / 60.0
	for _frame in int(seconds * 60.0):
		flip.advance(dt, wake_open, nightmare_open)


func test_manual_flip_then_cooldown() -> void:
	var flip := FlipSystem.new()
	assert_true(flip.request_flip(true))
	assert_eq(flip.world, NIGHTMARE)
	assert_false(flip.request_flip(true), "cooldown should refuse")
	_run(flip, flip.cooldown + 0.1)
	assert_true(flip.request_flip(true))
	assert_eq(flip.world, WAKE)


func test_twin_flip_holds_two_charges_that_refill_one_at_a_time() -> void:
	var flip := FlipSystem.new()
	flip.charges = 2
	flip.charges_left = 2
	assert_true(flip.request_flip(true))
	assert_true(flip.request_flip(true), "a second flip right away")
	assert_false(flip.request_flip(true), "both spent")
	_run(flip, flip.cooldown + 0.1)
	assert_eq(flip.charges_left, 1, "one charge back per cooldown")
	_run(flip, flip.cooldown + 0.1)
	assert_eq(flip.charges_left, 2)
	_run(flip, flip.cooldown * 2.0)
	assert_eq(flip.charges_left, 2, "never more than it holds")


func test_blocked_flip_is_denied() -> void:
	var flip := FlipSystem.new()
	var denied: Array[int] = []
	flip.flip_denied.connect(func() -> void: denied.append(1))
	assert_false(flip.request_flip(false))
	assert_eq(flip.world, WAKE)
	assert_eq(denied.size(), 1)


func test_flipping_time_is_announced_then_returns() -> void:
	var flip := FlipSystem.new()
	var events: Array[String] = []
	flip.flipping_time_warning.connect(func() -> void: events.append("warn"))
	flip.flipped.connect(func(world: int, forced: bool) -> void: events.append("%d:%s" % [world, forced]))
	_run(flip, flip.first_forced_at - flip.warning_time - 0.1)
	assert_true(events.is_empty(), "nothing before the warning")
	_run(flip, flip.warning_time + 0.2)
	assert_eq(events, ["warn", "%d:true" % NIGHTMARE])
	assert_false(flip.request_flip(true), "no manual flip during Flipping Time")
	_run(flip, flip.forced_duration_max + 0.1)
	assert_eq(flip.world, WAKE)
	assert_gt(flip.next_forced_in, flip.warning_time)


func test_forced_flip_waits_for_open_spot() -> void:
	var flip := FlipSystem.new()
	_run(flip, flip.first_forced_at + 1.0, true, false)
	assert_eq(flip.world, WAKE, "never pulled into a NIGHTMARE wall")
	_run(flip, 0.1)
	assert_eq(flip.world, NIGHTMARE)
	_run(flip, flip.forced_duration_max + 1.0, false, true)
	assert_eq(flip.world, NIGHTMARE, "never returned into a WAKE wall")
	_run(flip, 0.1)
	assert_eq(flip.world, WAKE)


func test_flipping_time_ramps_up() -> void:
	var flip := FlipSystem.new(3)
	var durations: Array[float] = []
	var gaps: Array[float] = []
	flip.flipped.connect(func(world: int, _forced: bool) -> void:
		if world == NIGHTMARE:
			durations.append(flip.forced_left)
		else:
			gaps.append(flip.next_forced_in))
	_run(flip, 400.0)
	assert_gt(durations.size(), 4)
	assert_true(durations.max() <= flip.forced_duration_max)
	assert_true(durations.back() > durations.front(), "Nightmare should hold longer over time")
	assert_true(gaps.back() < gaps.front(), "Flipping Time should come sooner over time")
	assert_true(gaps.min() >= flip.min_forced_interval)
