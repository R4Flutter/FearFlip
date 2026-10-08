extends McpTestSuite
## plans/06 P6: the Daily Nightmare. The same maze all day and a new one tomorrow, quests picked by the date with
## one free reroll, the streak and its freezes, the share line, one ranked try a day, and a Daily that never
## touches the campaign's save.

const PROFILE := "user://test_profile.cfg"
const SAVE := "user://test_run_state.cfg"
const DAY := "2026-10-20"
const NEXT_DAY := "2026-10-21"


func suite_name() -> String:
	return "daily"


func setup() -> void:
	MetaState.profile_path = PROFILE
	RunState.save_path = SAVE
	_fresh()


func teardown() -> void:
	if RunState.is_daily():
		RunState.leave_daily()
	_fresh()
	RunState.start_run(1)


func test_the_same_maze_all_day_and_a_new_one_tomorrow() -> void:
	assert_eq(Daily.seed_of(DAY), Daily.seed_of(DAY))
	assert_ne(Daily.seed_of(DAY), Daily.seed_of(NEXT_DAY))
	assert_eq(Daily.number(Daily.FIRST_DAY), 1, "Daily #1 is the first day")
	assert_eq(Daily.number(NEXT_DAY) - Daily.number(DAY), 1)
	var seen := {}
	for daily_floor in range(1, Daily.FLOORS + 1):
		var cards := Daily.cards(DAY, daily_floor)
		assert_eq(cards, Daily.cards(DAY, daily_floor), "floor %d deals the same cards all day" % daily_floor)
		assert_eq(cards.size(), Daily.FINALE_CARDS if daily_floor == Daily.FLOORS else 1)
		for id in cards:
			assert_eq(Cards.kind(id), "rule", id)
			assert_false(seen.has(id), "%s only once a Daily" % id)
			seen[id] = true
	var omen := Daily.omen(DAY)
	assert_eq(omen, Daily.omen(DAY), "one omen for everyone")
	assert_true(Cards.omen_pool(99).has(omen), "an omen that works")


func test_quests_repeat_for_the_date_and_a_reroll_swaps_one() -> void:
	var quests := Daily.quests(DAY)
	assert_eq(quests, Daily.quests(DAY))
	assert_eq(quests.size(), Daily.QUEST_COUNT)
	var stats := {}
	for id in quests:
		stats[Daily.quest(id)["stat"]] = true
	assert_eq(stats.size(), Daily.QUEST_COUNT, "never two quests on one counter")
	var swapped := Daily.quests(DAY, quests[0])
	assert_eq(swapped.size(), Daily.QUEST_COUNT)
	assert_false(swapped.has(quests[0]), "the rerolled quest is gone")
	assert_true(swapped.has(quests[1]) and swapped.has(quests[2]), "the others stay")
	var other_days := 0
	for day in range(1, 8):
		if Daily.quests("2026-11-%02d" % day) != quests:
			other_days += 1
	assert_gt(other_days, 5, "a new day, new quests")


func test_every_quest_is_well_formed() -> void:
	var ids := {}
	for quest: Dictionary in Daily.QUESTS:
		assert_false(ids.has(quest["id"]), quest["id"])
		ids[quest["id"]] = true
		assert_gt(quest["goal"], 0, quest["id"])
		assert_true(quest["shards"] >= 15 and quest["shards"] <= 30, "%s pays 15-30" % quest["id"])
	assert_true(ids.size() >= 20, "a pool of about 25: %d" % ids.size())


func test_the_streak_counts_days_and_freezes_cover_misses() -> void:
	assert_eq(Daily.next_streak(0, 0, "", DAY), [1, 0], "a first Daily")
	assert_eq(Daily.next_streak(4, 0, DAY, DAY), [4, 0], "the same day twice counts once")
	assert_eq(Daily.next_streak(4, 0, DAY, NEXT_DAY), [5, 0])
	assert_eq(Daily.next_streak(4, 0, DAY, "2026-10-22"), [1, 0], "a missed day starts again, no penalty")
	assert_eq(Daily.next_streak(4, 1, DAY, "2026-10-22"), [5, 0], "a freeze covers it")
	assert_eq(Daily.next_streak(4, 1, DAY, "2026-10-23"), [1, 1], "one freeze can't cover two days")
	assert_eq(Daily.next_streak(6, 0, DAY, NEXT_DAY), [7, 1], "seven days earn a freeze")
	assert_eq(Daily.next_streak(13, 2, DAY, NEXT_DAY), [14, 2], "two at most")


func test_the_share_line() -> void:
	var line := Daily.share_text(Daily.FIRST_DAY, ["clean", "clean", "chased", "s", "died"], 401.0)
	assert_eq(line, "FearFlip Daily #1 🟦🟦🟥⭐💀 4/5 · 6:41")
	assert_eq(Daily.share_text(DAY, ["died"], 59.0), "FearFlip Daily #%d 💀 0/5 · 0:59" % Daily.number(DAY))
	assert_eq(Daily.mark("S", 30.0), "s", "an S beats being chased")
	assert_eq(Daily.mark("B", Daily.CHASED_SECONDS + 1.0), "chased")
	assert_eq(Daily.mark("A", 2.0), "clean")


func test_one_ranked_try_a_day_then_practice() -> void:
	RunState.start_daily(false)
	assert_eq(RunState.mode, "daily")
	assert_eq(Daily.played, Daily.today(), "the ranked try is spent as it starts")
	assert_eq(Daily.streak, 1)
	RunState.leave_daily()
	RunState.start_daily(false)
	assert_eq(RunState.mode, "practice", "the ranked try is taken: the rest is practice")
	assert_eq(Daily.streak, 1, "practice doesn't count twice")


func test_the_daily_never_touches_the_campaign() -> void:
	RunState.start_run(1)
	RunState.advance_floor()
	RunState.advance_floor()
	var campaign := RunState.current_floor
	RunState.start_daily(false)
	var today := Daily.today()
	assert_eq(RunState.current_floor, Daily.STAGE_FLOORS[0])
	assert_eq(RunState.floor_cards, Daily.cards(today, 1))
	assert_eq(RunState.run_cards, [Daily.omen(today)], "the day's omen, nothing else")
	assert_eq(RunState.picks, [], "no curse, no omen pick, no doors")
	assert_eq(RunState.revives_left(), 0, "one life")
	RunState.advance_floor()
	assert_eq(RunState.daily_floor, 2)
	assert_eq(RunState.floor_cards, Daily.cards(today, 2))
	assert_eq(RunState.picks, [], "no door choice in the Daily")
	RunState.leave_daily()
	assert_eq(RunState.mode, "campaign")
	assert_eq(RunState.current_floor, campaign, "the campaign comes back from its save, untouched")


func test_a_ranked_result_is_kept_floor_by_floor() -> void:
	RunState.start_daily(false)
	RunState.note_daily("s", 70.0)
	RunState.advance_floor()
	RunState.note_daily("died", 31.5)
	_relaunch()
	assert_eq(Daily.result, ["s", "died"], "a quit or a crash keeps what was played")
	assert_true(absf(Daily.result_time - 101.5) < 0.01)
	RunState.start_daily(true)
	RunState.note_daily("clean", 50.0)
	assert_eq(Daily.result, ["s", "died"], "practice never changes the ranked result")


func test_quests_pay_once_and_one_reroll_a_day() -> void:
	Daily.refresh_quests(Daily.today())
	var id := Daily.quest_ids[0]
	var quest := Daily.quest(id)
	var shards := MetaState.shards
	var news := MetaState.record({quest["stat"]: quest["goal"]})
	assert_true(news.has("QUEST  ·  " + quest["text"]), str(news))
	assert_eq(Daily.progress(id), quest["goal"])
	assert_true(MetaState.shards >= shards + quest["shards"], "it pays its shards")
	shards = MetaState.shards
	MetaState.record({quest["stat"]: 0})
	assert_eq(MetaState.shards, shards, "paid once")
	assert_false(Daily.reroll(id), "a finished quest stays")
	var other := Daily.quest_ids[1]
	var dealt := Daily.quest_ids.duplicate()
	assert_true(Daily.reroll(other))
	assert_false(Daily.quest_ids.has(other))
	var fresh: String = Daily.quest_ids.filter(func(q: String) -> bool: return not dealt.has(q))[0]
	assert_eq(Daily.progress(fresh), 0, "the new quest counts from now")
	assert_false(Daily.reroll(Daily.quest_ids[2]), "one free reroll a day")


func test_streak_milestones_grant_their_reward() -> void:
	var yesterday := Time.get_date_string_from_unix_time(Time.get_unix_time_from_system() - 86400)
	Daily.streak = 2
	Daily.played = yesterday
	var item: String = Daily.STREAK_REWARDS[3]
	assert_false(MetaState.owns(item))
	RunState.start_daily(false)
	assert_eq(Daily.streak, 3)
	assert_true(MetaState.owns(item), "three days in a row: %s" % item)


func test_the_profile_keeps_the_daily_through_a_relaunch() -> void:
	RunState.start_daily(false)
	Daily.refresh_quests(Daily.today())
	var quests := Daily.quest_ids.duplicate()
	Daily.reroll(quests[2])
	var dealt := Daily.quest_ids.duplicate()
	_relaunch()
	assert_eq(Daily.played, Daily.today())
	assert_eq(Daily.streak, 1)
	assert_eq(Daily.quest_ids, dealt, "the day's quests, reroll included")
	assert_ne(Daily.rerolled, "", "and the reroll stays spent")


func _fresh() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	_relaunch()


func _relaunch() -> void:
	MetaState._loaded = false
	RunState._loaded = false
	RunState.mode = "campaign"
	RunState.load_save()
