extends McpTestSuite
## plans/06 P7: the Director's menace meter (calm, build-up, peak, relax), the Devil's senses (it no longer knows
## where you are), and hidden mercy, which kicks in after 3 deaths on one floor and resets once it's cleared.

const PROFILE := "user://test_profile.cfg"
const SAVE := "user://test_run_state.cfg"


func suite_name() -> String:
	return "director"


func setup() -> void:
	MetaState.profile_path = PROFILE
	RunState.save_path = SAVE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	MetaState._loaded = false
	RunState._loaded = false
	RunState.load_save()


func teardown() -> void:
	setup()


func test_menace_rises_with_what_it_senses_and_falls_without() -> void:
	var director := Director.new(1)
	director.advance(1.0, true, false, false)
	assert_eq(director.menace, Director.RISE_SEEN, "seen")
	director.menace = 0.0
	director.advance(1.0, false, true, false)
	assert_eq(director.menace, Director.RISE_NEAR, "near")
	director.menace = 0.0
	director.advance(1.0, false, false, true)
	assert_eq(director.menace, Director.RISE_HEARD, "you can hear it")
	director.advance(1.0, false, false, false)
	assert_eq(director.menace, 0.0, "falls, never below 0")
	director.advance(10.0, true, true, true)
	assert_eq(director.menace, 100.0, "never above 100")


func test_a_long_calm_builds_with_hints() -> void:
	var director := Director.new(1)
	var hints := 0
	for i in roundi(Director.CALM_LIMIT / 0.5) - 1:
		hints += int(director.advance(0.5, false, false, false))
	assert_eq(director.phase, Director.Phase.CALM)
	assert_eq(hints, 0)
	assert_true(director.advance(0.5, false, false, false), "calm long enough: the Devil gets a hint")
	assert_eq(director.phase, Director.Phase.BUILD)
	hints = 0
	for i in roundi(Director.HINT_EVERY * 3 / 0.5):
		hints += int(director.advance(0.5, false, false, false))
	assert_eq(hints, 3, "a fuzzy hint every %.0f s while it builds" % Director.HINT_EVERY)


func test_mercy_spaces_the_hints_out() -> void:
	var plain := Director.new(1)
	var kind := Director.new(1)
	kind.hint_stretch = 1.0 / 0.7
	var hints := [0, 0]
	for i in roundi((Director.CALM_LIMIT + 60.0) / 0.5):
		hints[0] += int(plain.advance(0.5, false, false, false))
		hints[1] += int(kind.advance(0.5, false, false, false))
	assert_lt_or_eq(hints[1], hints[0] * 0.75)


func test_a_peak_is_short_and_followed_by_relief() -> void:
	var director := Director.new(1)
	while director.phase != Director.Phase.PEAK:
		director.advance(0.25, true, true, true)
	assert_true(director.menace >= Director.PEAK_AT)
	for i in roundi(Director.PEAK_LIMIT / 0.25) + 1:
		director.advance(0.25, true, true, true)
	assert_eq(director.phase, Director.Phase.RELAX, "a chase never lasts past %.0f s" % Director.PEAK_LIMIT)
	for i in roundi(Director.RELAX_TIME.y / 0.25) + 1:
		director.advance(0.25, false, false, false)
	assert_eq(director.phase, Director.Phase.CALM, "then it's quiet again")


func test_losing_it_for_a_while_ends_the_peak() -> void:
	var director := Director.new(2)
	while director.phase != Director.Phase.PEAK:
		director.advance(0.25, true, true, true)
	for i in roundi(Director.LOST_LIMIT / 0.25) + 1:
		director.advance(0.25, false, true, true)
	assert_eq(director.phase, Director.Phase.RELAX, "out of its sight long enough")


func test_it_only_sees_ahead_down_a_straight_corridor() -> void:
	var layout := FloorLayout.generate(5, 7, 2)
	var world := FloorLayout.World.NIGHTMARE
	var cell := Vector2i(-1, -1)
	var dir := Vector2i.ZERO
	# Find two open cells in a straight line two apart.
	for i in layout.size * layout.size:
		var c := layout.cell_at(i)
		for d: Vector2i in FloorLayout.DIRS:
			if layout.is_open(world, c) and layout.is_open(world, c + d) and layout.is_open(world, c + d * 2):
				cell = c
				dir = d
				break
		if cell.x >= 0:
			break
	assert_true(DevilBrain.sees(layout, world, cell, dir, cell + dir * 2), "ahead, in line")
	assert_false(DevilBrain.sees(layout, world, cell + dir * 2, dir, cell), "behind its back")
	assert_true(DevilBrain.sees(layout, world, cell + dir, dir, cell), "right next to it, any side")
	assert_true(DevilBrain.sees(layout, world, cell, Vector2i.ZERO, cell + dir * 2), "fresh from its spawn it looks every way")


func test_without_a_sense_it_follows_your_scent_or_its_interest() -> void:
	var brain := DevilBrain.new()
	for cell: Vector2i in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]:
		brain.record(cell, true)
	assert_eq(brain.target(Vector2i(1, 1), Vector2i(9, 9)), Vector2i(2, 1), "your trail, not you")
	assert_eq(brain.mode(), "patrol")
	brain.investigate(Vector2i(5, 5))
	assert_eq(brain.target(Vector2i(1, 1), Vector2i(9, 9)), Vector2i(5, 5), "a noise or a hint draws it")
	assert_eq(brain.mode(), "investigate")
	assert_eq(brain.target(Vector2i(5, 5), Vector2i(9, 9)), Vector2i(2, 1), "nothing there: back to your scent")
	brain.sense(true, false, 0.1)
	assert_eq(brain.target(Vector2i(1, 1), Vector2i(9, 9)), Vector2i(9, 9), "it senses you: straight at you")
	assert_eq(brain.mode(), "chase")


func test_mercy_after_three_deaths_on_a_floor_until_it_is_cleared() -> void:
	RunState.start_run(1)
	RunState.current_floor = 3
	var speed := RunState.mod("devil_speed", 1.0)
	for i in MetaState.MERCY_DEATHS - 1:
		MetaState.note_death(3)
	assert_eq(RunState.mod("extra_circles", 0.0), 0.0, "two deaths: nothing yet")
	MetaState.note_death(3)
	assert_eq(RunState.mod("extra_circles", 0.0), 1.0, "a third: one more safe circle")
	assert_true(RunState.mod("devil_speed", 1.0) < speed, "and a slower Devil")
	assert_lt_or_eq(RunState.mod("hint_stretch", 1.0) * 0.7, 1.01)
	assert_true(RunState.mod("hint_stretch", 1.0) > 1.0, "and fewer hints")
	assert_false(RunState.floor_cards.has("mercy"), "never shown: it's hidden")
	RunState.current_floor = 4
	assert_eq(RunState.mod("extra_circles", 0.0), 0.0, "only on the floor that keeps killing you")
	RunState.current_floor = 3
	MetaState.note_clear(3)
	assert_eq(RunState.mod("extra_circles", 0.0), 0.0, "cleared: gone")
	for i in MetaState.MERCY_DEATHS:
		MetaState.note_death(3)
	RunState.start_daily(true)
	assert_eq(RunState.mod("devil_speed", 1.0), Cards.fold(RunState.floor_cards + RunState.run_cards, "devil_speed", 1.0), "never in the Daily")
	RunState.leave_daily()


func assert_lt_or_eq(actual: float, limit: float) -> void:
	assert_true(actual <= limit, "%.3f > %.3f" % [actual, limit])
