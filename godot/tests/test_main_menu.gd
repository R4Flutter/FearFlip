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
	RunState.best_floor = 1
	MetaState.acts_unlocked = 1
	MetaState.shards = MetaState.STARTER_SHARDS


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


func test_one_shard_pill_and_the_unfinished_business_cards() -> void:
	MetaState.shards = 35
	RunState.best_floor = 7
	var menu := _spawn_menu(7)
	var pills := menu._top_bar.get_children().filter(func(node: Node) -> bool: return node is PanelContainer)
	assert_eq(pills.size(), 1, "one currency: Fear Shards")
	assert_true(_texts(menu._top_bar).has("35"), "the pill shows the banked shards")
	var cards := _texts(menu._right)
	assert_true(cards.has("NEXT UNLOCK"), str(cards))
	assert_true(cards.has("35/%d" % MetaState.FIRST_UNLOCK_COST), str(cards))
	assert_true(cards.has("ACT 2 SHORTCUT"), str(cards))
	assert_true(cards.has("4 FLOORS TO GO"), "floor 7 reached: 7, 8, 9 and the Gate are left")


func _texts(root: Node) -> Array:
	return root.find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text)
