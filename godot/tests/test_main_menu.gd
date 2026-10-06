extends McpTestSuite
## Title screen: the run in progress decides the rows; abandoning a run takes a second press.


func suite_name() -> String:
	return "main_menu"


func _spawn_menu(floor_number: int) -> MainMenu:
	RunState.save_path = "user://test_run_state.cfg"
	RunState._loaded = true
	RunState.current_floor = floor_number
	var menu: MainMenu = load("res://scenes/main_menu.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(menu)
	track(menu)
	return menu


func test_fresh_run_offers_play_only() -> void:
	var menu := _spawn_menu(1)
	assert_true(menu._menu.has_node("Play"))
	assert_false(menu._menu.has_node("Continue"))
	assert_false(menu._menu.has_node("NewRun"))


func test_new_run_needs_a_second_press() -> void:
	var menu := _spawn_menu(12)
	assert_true(menu._menu.has_node("Continue"))
	menu._on_new_run()
	assert_true(menu._new_run_armed, "first press only arms")
	assert_false(menu._leaving)
	assert_eq(RunState.current_floor, 12, "the run survives the first press")
	menu._disarm_new_run()
	assert_false(menu._new_run_armed, "leaving the row disarms it")
	RunState.current_floor = 1
