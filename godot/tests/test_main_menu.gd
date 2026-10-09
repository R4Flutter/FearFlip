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
	MetaState.ranks_open = 0
	MetaState.rank = 0
	MetaState.abyss_best = 0
	RunState.start_floor = 1
	RunState.mode = "campaign"
	Daily.played = ""
	Daily.result.clear()
	Daily.quest_day = ""


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


func test_locked_acts_wear_the_padlock_until_the_act_before_is_cleared() -> void:
	var menu := _spawn_menu(10, 2, true)
	for act in range(1, StageRule.ACT_COUNT + 1):
		var locked := act > 2
		assert_eq(menu._right.get_node("Stars%d" % act).find_child("Lock", true, false) != null, locked, "tile %d" % act)
		assert_eq(menu._acts.find_child("Act%d" % act, true, false).find_child("Lock", true, false) != null, locked,
				"card %d" % act)


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
	for row: String in ["Daily", "Altar", "Mirror", "Bestiary", "Archive"]:
		assert_true(menu._menu.has_node(row), row)
	assert_true(menu._top_bar.has_node("Guide"), "how to play sits up top, by the shards")
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
	menu._open_mirror()
	assert_true(_texts(menu._screen).any(func(text: String) -> bool: return text.contains("BEST FLOOR 7 / 50")))


func test_back_from_the_daily_the_campaign_returns() -> void:
	RunState.mode = "practice"
	var menu := _spawn_menu(1)
	assert_eq(RunState.mode, "campaign", "the menu always shows the campaign")
	assert_true(menu._menu.has_node("Play"))


func test_the_daily_screen_shows_today() -> void:
	var menu := _spawn_menu(1)
	assert_true(_texts(menu._right).has("DAILY #%d" % Daily.number(Daily.today())), "its status on the dashboard")
	menu._open_daily()
	var texts := _texts(menu._screen)
	assert_true(texts.any(func(text: String) -> bool: return text.begins_with("DAILY NIGHTMARE #%d" % Daily.number(Daily.today()))), str(texts))
	assert_true(texts.any(func(text: String) -> bool: return text.contains(Cards.find(Daily.omen(Daily.today()))["name"])), "the day's omen")
	for id in Daily.quest_ids:
		assert_true(texts.has(Daily.quest(id)["text"].to_upper()), "quest %s" % id)
	assert_ne(menu._screen.find_child("PlayRanked", true, false), null, "the ranked try is open")
	assert_eq(menu._screen.find_child("CopyResult", true, false), null, "nothing to copy yet")


func test_after_the_ranked_try_the_daily_offers_practice_and_its_result() -> void:
	Daily.played = Daily.today()
	Daily.result.assign(["clean", "s", "died"])
	Daily.result_time = 200.0
	var menu := _spawn_menu(1)
	menu._open_daily()
	assert_eq(menu._screen.find_child("PlayRanked", true, false), null)
	assert_ne(menu._screen.find_child("Practice", true, false), null)
	assert_eq(menu._screen.find_child("Squares", true, false).get_child_count(), 3, "a square per floor played")
	var copy: Button = menu._screen.find_child("CopyResult", true, false)
	copy.pressed.emit()
	assert_eq(copy.text, "COPIED")


func test_one_reroll_from_the_daily_screen() -> void:
	var menu := _spawn_menu(1)
	menu._open_daily()
	var first := Daily.quest_ids[0]
	(menu._screen.find_child("Reroll_" + first, true, false) as Button).pressed.emit()
	assert_false(Daily.quest_ids.has(first), "swapped for another")
	assert_eq(menu._screen.find_children("Reroll_*", "Button", true, false).size(), 0, "one free reroll a day")


# --- plans/06 P8: the Abyss and the Nightmare Ranks ----------------------------------------------------

func test_the_abyss_waits_beside_the_acts_until_floor_50_falls() -> void:
	var menu := _spawn_menu(1, StageRule.ACT_COUNT, true)
	var abyss := menu._acts.find_child("Act%d" % StageRule.ABYSS_ACT, true, false) as Button
	assert_ne(abyss, null, "the Abyss card sits beside the acts")
	assert_true(abyss.disabled, "locked until floor 50 falls")
	assert_true(_texts(abyss).has("CLEAR ACT 5 TO OPEN"), str(_texts(abyss)))
	assert_eq(menu._acts.find_child("Ranks", true, false), null, "no ranks before floor 50 falls")


func test_after_floor_50_the_abyss_and_the_ranks_open() -> void:
	MetaState.stats = {"clears_act_%d" % StageRule.ACT_COUNT: 1}
	MetaState.ranks_open = 3
	MetaState.rank = 1
	MetaState.abyss_best = 9
	var menu := _spawn_menu(1, StageRule.ACT_COUNT, true)
	var abyss := menu._acts.find_child("Act%d" % StageRule.ABYSS_ACT, true, false) as Button
	assert_false(abyss.disabled)
	assert_true(_texts(abyss).has("DEEPEST 9"), str(_texts(abyss)))
	var ranks: Control = menu._acts.find_child("Ranks", true, false)
	assert_ne(ranks, null, "the rank picker")
	var up := ranks.find_child("RankUp", true, false) as Button
	for i in 3:
		up.pressed.emit()
	assert_eq(MetaState.rank, 3, "never past the ranks open")
	assert_true(_texts(ranks).has("NIGHTMARE RANK 3"), str(_texts(ranks)))
	var down := ranks.find_child("RankDown", true, false) as Button
	for i in 4:
		down.pressed.emit()
	assert_eq(MetaState.rank, 0)
	assert_true(_texts(ranks).has("NO RANK"), str(_texts(ranks)))
	assert_true(_texts(menu._right).has("THE ABYSS"), "the dashboard's goal card turns to the depths")


func test_continue_names_the_depth_in_the_abyss() -> void:
	MetaState.stats = {"clears_act_%d" % StageRule.ACT_COUNT: 1}
	RunState.start_floor = StageRule.LAST_FLOOR + 1
	var menu := _spawn_menu(StageRule.LAST_FLOOR + 7, StageRule.ACT_COUNT)
	var sub: Label = menu._menu.get_node("Continue/Content/Sub")
	assert_eq(sub.text, "DEPTH 7  ·  THE ABYSS")


func _texts(root: Node) -> Array:
	return root.find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text)
