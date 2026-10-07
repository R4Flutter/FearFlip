extends McpTestSuite
## Title screen: the run and the acts unlocked decide the rows; the act picker abandons nothing until an
## act is picked, and locked acts can't be started.


func suite_name() -> String:
	return "main_menu"


func _spawn_menu(floor_number: int, acts_unlocked := 1, run_over := false) -> MainMenu:
	RunState.save_path = "user://test_run_state.cfg"
	MetaState.profile_path = "user://test_profile.cfg"
	RunState._loaded = true
	MetaState._loaded = true
	RunState.current_floor = floor_number
	RunState.run_over = run_over
	MetaState.acts_unlocked = acts_unlocked
	var menu: MainMenu = load("res://scenes/main_menu.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(menu)
	track(menu)
	return menu


func teardown() -> void:
	RunState.current_floor = 1
	RunState.run_over = false
	MetaState.acts_unlocked = 1


func test_fresh_run_offers_play_only() -> void:
	var menu := _spawn_menu(1)
	assert_true(menu._menu.has_node("Play"))
	assert_false(menu._menu.has_node("Continue"))
	assert_false(menu._menu.has_node("NewRun"), "one act unlocked: nothing to choose")


func test_run_in_progress_offers_continue_and_the_act_picker() -> void:
	var menu := _spawn_menu(12, 2)
	assert_true(menu._menu.has_node("Continue"))
	assert_true(menu._menu.has_node("NewRun"))
	menu._open_acts()
	assert_true(menu._acts.visible)
	assert_false((menu._acts.find_child("Act2", true, false) as Button).disabled)
	assert_true((menu._acts.find_child("Act3", true, false) as Button).disabled, "Act 3 is locked")
	assert_eq(RunState.current_floor, 12, "opening the picker abandons nothing")
	menu._close_acts()
	assert_eq(RunState.current_floor, 12)


func test_cleared_act_plays_the_next_one() -> void:
	var menu := _spawn_menu(10, 2, true)
	assert_true(menu._menu.has_node("Play"), "the run is over: PLAY, not CONTINUE")
	var sub: Label = menu._menu.get_node("Play/Content/Sub")
	assert_true(sub.text.begins_with("ACT 2"), sub.text)
	assert_true(menu._menu.has_node("NewRun"), "two acts open: the picker is offered")
