extends McpTestSuite
## plans/06 P9: live ops. The week's cursed card joins the run-start curse offer; an event (Blood Moon, Frozen
## Nightmare) adds its rule cards to the decks and its cosmetics to the Altar while it runs; acts not released yet
## stay shut (the Act 4 and Act 5 drops); the CrazyGames bridge stays out of the way off the web.

const SAVE := "user://test_run_state.cfg"
const PROFILE := "user://test_profile.cfg"
const WINTER := "2026-12-20"
const SUMMER := "2026-07-01"

## Read as the suite is built, before any setup() turns live ops on for a test.
var _on_by_default: bool = LiveOps.on


func suite_name() -> String:
	return "live_ops"


func setup() -> void:
	MetaState.profile_path = PROFILE
	RunState.save_path = SAVE
	for path in [PROFILE, SAVE]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	MetaState._loaded = false
	RunState._loaded = false
	RunState.load_save()
	LiveOps.on = true
	LiveOps.date = SUMMER


func teardown() -> void:
	LiveOps.on = false
	LiveOps.date = ""
	LiveOps.released_acts = StageRule.ACT_COUNT
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE))
	MetaState._loaded = false
	RunState._loaded = false
	RunState.load_save()


func test_live_ops_stay_off_under_the_test_runner() -> void:
	assert_false(_on_by_default, "a test turns them on, with its own date")
	LiveOps.on = false
	LiveOps.date = WINTER
	assert_eq(LiveOps.cursed_week(), "")
	assert_eq(LiveOps.event(), {})


# --- E6: Cursed Week ------------------------------------------------------------------------------------

func test_each_week_has_one_cursed_card_from_monday_to_sunday() -> void:
	var monday := Cards.weekly("2026-10-05")
	for day: String in ["2026-10-06", "2026-10-08", "2026-10-11"]:
		assert_eq(Cards.weekly(day), monday, day)
	assert_ne(Cards.weekly("2026-10-12"), monday, "a new one every Monday")
	assert_eq(Cards.week_days_left("2026-10-05"), 7)
	assert_eq(Cards.week_days_left("2026-10-11"), 1, "Sunday is its last day")
	var seen := {}
	for week in Cards.WEEKLY.size():
		seen[Cards.weekly(Time.get_date_string_from_unix_time(Time.get_unix_time_from_datetime_string("2026-10-05") + week * 7 * 86400))] = true
	assert_eq(seen.size(), Cards.WEEKLY.size(), "every cursed card has its week")
	for card: Dictionary in Cards.WEEKLY:
		assert_eq(Cards.kind(card["id"]), "curse", card["id"])
		var mods: Dictionary = card["mods"]
		assert_gt(mods.size(), 2, "%s: a cost, a consolation and its shards" % card["id"])
		assert_true(Cards.fold([card["id"]], "shards", 1.0) >= 1.4, "%s pays more than most curses" % card["id"])


func test_the_cursed_week_joins_the_curse_offer() -> void:
	MetaState.unlock_act(2)
	RunState.start_run(1)
	assert_eq(RunState.picks[0], "curse")
	var offer := RunState.pick_options()
	assert_eq(offer[0], "no_curse", "you can always decline")
	assert_eq(offer.size(), 4, "still four cards")
	var week := LiveOps.cursed_week()
	assert_true(offer.has(week), str(offer))
	RunState.take(week)
	assert_true(RunState.run_cards.has(week))
	assert_true(RunState.act_stars()[2], "it counts as the run's curse for the third star")
	assert_true(RunState.mod("shards", 1.0) >= 1.4)


# --- E7: events -------------------------------------------------------------------------------------------

func test_events_switch_on_by_date() -> void:
	assert_eq(Cards.event_on(SUMMER), {})
	assert_eq(Cards.event_on("2026-12-15").get("id"), "frozen_nightmare")
	assert_eq(Cards.event_on("2027-01-07").get("id"), "frozen_nightmare", "across the new year")
	assert_eq(Cards.event_on("2027-01-08"), {})
	assert_eq(Cards.event_on("2026-10-31").get("id"), "blood_moon")
	LiveOps.date = WINTER
	assert_eq(LiveOps.event().get("id"), "frozen_nightmare")


func test_an_event_adds_its_rule_cards_to_every_deck() -> void:
	var winter: Array[String] = []
	for card: Dictionary in Cards.RULES:
		if card.get("event") == "frozen_nightmare":
			winter.append(card["id"])
	assert_gt(winter.size(), 1)
	for act in range(1, StageRule.ABYSS_ACT + 1):
		assert_false(Cards.deck(act).any(winter.has), "act %d: no winter cards out of season" % act)
		assert_true(winter.all(Cards.deck(act, "frozen_nightmare").has), "act %d: all of them in season" % act)
	assert_eq(_floors_with(winter), 0, "summer floors never deal them")
	LiveOps.date = WINTER
	assert_gt(_floors_with(winter), 0, "winter floors do")


## Of 120 fresh act-1 floors (40 runs x 3), how many deal one of `cards`.
func _floors_with(cards: Array[String]) -> int:
	var count := 0
	for run in 40:
		RunState.start_run(1)
		for i in 3:
			RunState.advance_floor()
			if RunState.floor_cards.any(cards.has):
				count += 1
	return count


func test_event_cosmetics_are_sold_only_while_it_runs_and_kept_after() -> void:
	MetaState.shards = 9999
	var frost := "frost_light"
	assert_eq(Unlocks.item(frost).get("event"), "frozen_nightmare")
	assert_false(MetaState.can_buy(frost), "out of season")
	LiveOps.date = WINTER
	assert_true(MetaState.buy(frost))
	LiveOps.date = SUMMER
	assert_true(MetaState.owns(frost))
	assert_true(MetaState.equip(frost), "yours to wear all year")
	while MetaState.buy(MetaState.next_unlock()):
		pass
	assert_false(MetaState.owns("frostbite_flash"), "the next-unlock bar never points at a season that's over")


func test_the_daily_screen_shows_the_week_and_the_event() -> void:
	LiveOps.date = WINTER
	var menu: MainMenu = load("res://scenes/main_menu.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(menu)
	track(menu)
	menu._open_daily()
	var texts: Array = menu._screen.find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text)
	var week: String = Cards.find(LiveOps.cursed_week())["name"]
	assert_true(texts.any(func(text: String) -> bool: return text.begins_with("CURSED WEEK  ·  " + week)), str(texts))
	assert_true(texts.any(func(text: String) -> bool: return text.begins_with("FROZEN NIGHTMARE")), str(texts))


# --- the Act 4 and Act 5 drops ----------------------------------------------------------------------------

func test_acts_not_released_yet_stay_shut() -> void:
	LiveOps.released_acts = 3
	MetaState.unlock_act(StageRule.ACT_COUNT)
	assert_eq(MetaState.acts_unlocked, 3, "no further than the acts that are out")
	RunState.start_run(3)
	RunState.current_floor = StageRule.act_start(3) + StageRule.GATE_FLOOR - 1
	RunState.master_act("A")
	RunState.clear_gate()
	assert_true(RunState.run_over, "nothing to descend into yet: the run ends at the Gate")
	assert_eq(RunState.picks, [])
	var menu: MainMenu = load("res://scenes/main_menu.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(menu)
	track(menu)
	var act4 := menu._acts.find_child("Act4", true, false) as Button
	assert_true(act4.disabled)
	var texts: Array = act4.find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text)
	assert_true(texts.has("COMING SOON"), str(texts))


func test_a_gate_before_an_act_still_to_come_says_so() -> void:
	LiveOps.released_acts = 3
	RunState.current_floor = StageRule.act_start(3) + StageRule.GATE_FLOOR - 1
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	main.fixed_seed = 42
	(Engine.get_main_loop() as SceneTree).root.add_child(main)
	track(main)
	RunState.current_floor = 1
	main._win_game()
	assert_true(main.state_label.text.contains("ACT 4 ARRIVES SOON"), main.state_label.text)


# --- CrazyGames bridge --------------------------------------------------------------------------------------

func test_the_portal_bridge_stays_out_of_the_way_off_the_web() -> void:
	assert_false(Portal.ready(), "no SDK on desktop or under tests")
	Portal.push(MetaState.profile_path)
	Portal.pull(MetaState.profile_path)
	Portal.submit_depth(12)
	assert_eq(Portal.KEYS.get("user://profile.cfg"), "fearflip_profile")
	assert_eq(Portal.set_item_js("fearflip_profile", "a\"b\nc"),
			"window.CrazyGames.SDK.data.setItem(\"fearflip_profile\", \"a\\\"b\\nc\")", "quotes and newlines escaped")


## The bridge talks to window.fearflipSdk and window.fearflipSubmitDepth: the Web preset's head include defines them
## and loads the SDK, in a single-threaded build (master plan §12).
func test_the_web_export_loads_the_sdk_the_bridge_expects() -> void:
	var presets := ConfigFile.new()
	assert_eq(presets.load("res://export_presets.cfg"), OK)
	assert_eq(presets.get_value("preset.0", "platform"), "Web")
	assert_eq(presets.get_value("preset.0.options", "variant/thread_support"), false, "single-threaded")
	var head: String = presets.get_value("preset.0.options", "html/head_include", "")
	for needed: String in ["crazygames-sdk-v3.js", "window.fearflipSdk", "window.fearflipSubmitDepth", "submitScore"]:
		assert_true(head.contains(needed), needed)


## The SDK holds writes back about a second: a tab closed right after a save leaves the cloud a save behind. The newer
## copy wins, so that never rolls a player back.
func test_a_cloud_copy_only_wins_when_it_is_newer() -> void:
	assert_true(Portal.cloud_wins({"t": 200.0, "text": "[run]"}, 100.0), "saved on another device since")
	assert_false(Portal.cloud_wins({"t": 100.0, "text": "[run]"}, 200.0), "this device is ahead of the cloud")
	assert_false(Portal.cloud_wins(null, 0.0), "nothing in the cloud yet")
	assert_false(Portal.cloud_wins("[run]", 0.0), "not a stamped copy")


## Act 1 is tuned easy (GEMINI): its deck never speeds the Devil up or wakes it sooner, and an event never changes that.
func test_no_event_makes_act_1_harder_on_the_devil() -> void:
	for event: Dictionary in Cards.EVENTS:
		for id in Cards.deck(1, event["id"]):
			assert_true(Cards.fold([id], "devil_speed", 1.0) <= 1.0, "%s speeds it up in Act 1" % id)
			assert_true(Cards.fold([id], "devil_delay", 1.0) >= 1.0, "%s wakes it sooner in Act 1" % id)
