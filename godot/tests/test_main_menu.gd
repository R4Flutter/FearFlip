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
	MetaState.unlocked.clear()
	MetaState.equipped = {}
	MetaState.stats = {}
	MetaState.stars = {}
	MetaState.notes_found = 0


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


func test_the_hub_replaces_every_coming_soon() -> void:
	var menu := _spawn_menu(1)
	for row: String in ["Altar", "Mirror", "Bestiary", "Archive", "HowToPlay"]:
		assert_true(menu._menu.has_node(row), row)
	for gone: String in ["Character", "Progression", "Settings", "Shop"]:
		assert_false(menu._menu.has_node(gone), gone)
	assert_false(menu.has_method("_soon"), "nothing answers COMING SOON any more")
	for act in range(1, StageRule.ACT_COUNT + 1):
		assert_true(menu._right.has_node("Stars%d" % act), "act %d's stars sit where the mode cards were" % act)


func test_the_altar_sells_and_the_dashboard_follows() -> void:
	MetaState.shards = 100
	var menu := _spawn_menu(1)
	menu._open_altar()
	(menu._screen.find_child("twin_flip", true, false) as Button).pressed.emit()
	assert_true(MetaState.owns("twin_flip"))
	assert_eq(MetaState.shards, 30)
	assert_true(_texts(menu._top_bar).has("30"), "the pill follows")
	assert_true(_texts(menu._right).has(Unlocks.item(MetaState.next_unlock())["name"]), "NEXT UNLOCK names what's next")
	assert_true((menu._screen.find_child("lantern", true, false) as Button).disabled, "30 shards: the Lantern is out of reach")


func test_gear_is_bought_then_worn_at_the_altar() -> void:
	MetaState.shards = 999
	var menu := _spawn_menu(1)
	menu._open_altar()
	(menu._screen.find_child("lantern", true, false) as Button).pressed.emit()
	assert_eq(MetaState.wearing("torch"), "old_torch", "bought, not yet worn")
	(menu._screen.find_child("lantern", true, false) as Button).pressed.emit()
	assert_eq(MetaState.wearing("torch"), "lantern")
	assert_false(menu._screen.find_child("uv_light", true, false).disabled, "the Lantern opens the UV Light")


func test_the_mirror_shows_stars_and_challenges() -> void:
	MetaState.stars = {1: [true, false, true]}
	MetaState.stats = {"chests": 7}
	var menu := _spawn_menu(1)
	var tile: Control = menu._right.get_node("Stars1")
	assert_eq((tile.find_child("Star0", true, false) as CanvasItem).modulate, MainMenu.GOLD)
	assert_ne((tile.find_child("Star1", true, false) as CanvasItem).modulate, MainMenu.GOLD)
	menu._open_mirror()
	var texts := _texts(menu._screen)
	assert_true(texts.has(Unlocks.challenge("finders_keepers")["name"]), str(texts))
	assert_true(texts.has("7 / 10"), "its progress")
	menu._close_screen()
	assert_eq(menu._screen, null)


func test_the_bestiary_keeps_what_you_have_not_met_hidden() -> void:
	MetaState.stats = {"devil_wakes": 2, "deaths_devil": 3}
	var menu := _spawn_menu(1)
	menu._open_bestiary()
	var texts := _texts(menu._screen)
	assert_true(texts.has("THE DEVIL"))
	assert_false(texts.has("THE PHANTOM"), "not met yet")
	assert_true(texts.has("???"))
	assert_true(texts.any(func(text: String) -> bool: return text.contains("CAUGHT YOU  3")), str(texts))


func test_the_archive_keeps_found_notes_and_seen_endings() -> void:
	MetaState.notes_found = 2
	MetaState.stats = {"clears_act_1": 1}
	var menu := _spawn_menu(1)
	var inbox: Button = menu._top_bar.get_node("Inbox")
	inbox.pressed.emit()
	var texts := _texts(menu._screen)
	assert_true(texts.has(Lore.NOTES[0]) and texts.has(Lore.NOTES[1]), "the mail is the archive")
	assert_false(texts.has(Lore.NOTES[2]))
	assert_true(texts.has(Lore.ACT_ENDINGS[0]))
	assert_false(texts.has(Lore.ACT_ENDINGS[1]))


func test_an_open_screen_keeps_focus_inside_it() -> void:
	var menu := _spawn_menu(1)
	var play: Button = menu._menu.get_node("Play")
	for open: Callable in [menu._open_altar, menu._open_how_to, menu._open_acts]:
		open.call()
		assert_eq(play.focus_mode, Control.FOCUS_NONE, "keys can't reach PLAY behind the screen")
		if menu._screen != null:
			menu._close_screen()
		elif menu._how_to.visible:
			menu._close_how_to()
		else:
			menu._close_acts()
		assert_eq(play.focus_mode, Control.FOCUS_ALL, "and can again once it closes")


func test_best_floor_lives_in_the_mirror() -> void:
	RunState.best_floor = 7
	var menu := _spawn_menu(1)
	assert_eq((menu._menu.get_node("HowToPlay/Content/Sub") as Label).text, "CONTROLS & RULES")
	menu._open_mirror()
	assert_true(_texts(menu._screen).any(func(text: String) -> bool: return text.contains("BEST FLOOR 7 / 50")))


func _texts(root: Node) -> Array:
	return root.find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text)
