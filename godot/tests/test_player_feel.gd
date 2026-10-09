extends McpTestSuite
## Feel-gate rules: footsteps follow real movement, never fire while still or airborne.


func suite_name() -> String:
	return "player_feel"


func _count_steps(feel: PlayerFeel, speed: float, seconds: float, on_floor: bool) -> int:
	var phase: float = 0.0
	var steps: int = 0
	var dt: float = 1.0 / 60.0
	for _frame in int(seconds * 60.0):
		var next_phase: float = feel.advance_step_phase(phase, speed, dt, on_floor)
		if PlayerFeel.crossed_step(phase, next_phase):
			steps += 1
		phase = next_phase
	return steps


func test_no_steps_when_standing_still() -> void:
	assert_eq(_count_steps(PlayerFeel.new(), 0.0, 5.0, true), 0)


func test_no_steps_below_min_speed() -> void:
	var feel := PlayerFeel.new()
	assert_eq(_count_steps(feel, feel.min_step_speed * 0.5, 5.0, true), 0)


func test_no_steps_in_air() -> void:
	assert_eq(_count_steps(PlayerFeel.new(), 4.0, 2.0, false), 0)


func test_step_count_matches_distance() -> void:
	var feel := PlayerFeel.new()
	feel.step_length = 0.75
	# 3 m/s for 2 s = 6 m = 8 steps of 0.75 m (allow one for frame rounding).
	var steps: int = _count_steps(feel, 3.0, 2.0, true)
	assert_true(steps >= 7 and steps <= 8, "expected ~8 steps, got %d" % steps)


func test_sprint_steps_faster_than_walk() -> void:
	var feel := PlayerFeel.new()
	var walk: int = _count_steps(feel, feel.walk_speed, 3.0, true)
	var sprint: int = _count_steps(feel, feel.walk_speed * feel.sprint_multiplier, 3.0, true)
	assert_gt(sprint, walk)


func test_sprint_is_a_ten_second_cycle() -> void:
	var feel := PlayerFeel.new()
	assert_true(is_equal_approx(feel.sprint_time + feel.sprint_recover_time, 10.0), "4 s sprint + 6 s rest")


func test_bob_is_lowest_at_footfall() -> void:
	var feel := PlayerFeel.new()
	var at_footfall: Vector3 = feel.bob_offset(PI, 1.0)
	var mid_step: Vector3 = feel.bob_offset(PI * 1.5, 1.0)
	assert_true(at_footfall.y < mid_step.y, "head should dip on footfall")
	assert_eq(feel.bob_offset(1.0, 0.0), Vector3.ZERO, "no bob at zero intensity")
