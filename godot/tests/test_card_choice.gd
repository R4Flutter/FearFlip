extends McpTestSuite
## plans/06 P3: the one card picker. Doors to pick from with a click or 1-3, once; or a floor's cards
## flashed at its start, with nothing to pick and the game playing on underneath.


func suite_name() -> String:
	return "card_choice"


func _choice() -> CardChoice:
	var choice := CardChoice.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(choice)
	track(choice)
	return choice


func _key(keycode: Key) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = keycode
	key.pressed = true
	return key


func test_a_number_key_picks_its_card_once() -> void:
	var choice := _choice()
	var picked: Array = []
	choice.picked.connect(func(id: String) -> void: picked.append(id))
	choice.offer("CHOOSE YOUR DOOR", ["normal", "vault", "mystery"])
	assert_true(choice.visible)
	assert_eq(choice._row.get_child_count(), 3)
	choice._unhandled_input(_key(KEY_2))
	assert_eq(picked, ["vault"])
	assert_false(choice.visible, "gone once picked")
	choice._unhandled_input(_key(KEY_1))
	assert_eq(picked, ["vault"], "one pick only")


func test_a_click_picks_too() -> void:
	var choice := _choice()
	var picked: Array = []
	choice.picked.connect(func(id: String) -> void: picked.append(id))
	choice.offer("", ["normal", "shrine", "hunt"])
	(choice._row.get_child(2) as Button).pressed.emit()
	assert_eq(picked, ["hunt"])


func test_a_flash_shows_cards_but_takes_no_pick() -> void:
	var choice := _choice()
	var picked: Array = []
	choice.picked.connect(func(id: String) -> void: picked.append(id))
	choice.flash("", ["thick_fog", "vault"])
	assert_true(choice.visible)
	assert_eq(choice._row.get_child_count(), 2)
	choice._unhandled_input(_key(KEY_1))
	assert_eq(picked, [], "nothing to pick")
	assert_eq(choice.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the game plays on underneath")


func test_a_new_offer_replaces_the_last_cards() -> void:
	var choice := _choice()
	choice.flash("", ["thick_fog"])
	choice.offer("", ["normal", "vault", "mystery"])
	assert_eq(choice._row.get_child_count(), 3)
