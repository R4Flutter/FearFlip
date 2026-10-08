class_name Daily
extends RefCounted
## The Daily Nightmare (plans/06 P6, E1-E4): one 5-floor mini-act a day, the same for everyone (seeded by the UTC
## date), with fixed cards and a fixed omen. One ranked try (kept in the profile), then unlimited practice. Plus 3
## quests a day (one free reroll), the streak with its freezes, and the share line. today() is the only clock read:
## everything else takes the date ("YYYY-MM-DD", UTC).

const FLOORS := 5
## Campaign floors the Daily borrows its difficulty from: Act 2, without its Sanctuary and Gate.
const STAGE_FLOORS: Array[int] = [11, 12, 13, 14, 19]
## The act whose deck deals the Daily's rule cards: one per floor, FINALE_CARDS on the last.
const DECK_ACT := 2
const FINALE_CARDS := 2
## Daily #1 was the first day there was one.
const FIRST_DAY := "2026-10-08"
## Finishing the ranked Daily pays this (plans/06 D1).
const CLEAR_SHARDS := 25
## A cleared floor counts as chased (a red square) past this many seconds hunted.
const CHASED_SECONDS := 20.0
const MARKS := {"clean": "🟦", "chased": "🟥", "s": "⭐", "died": "💀"}
## The streak (E4): playing the ranked Daily is what counts. Every FREEZE_EVERY days earns a freeze (MAX_FREEZES
## kept); each covers one missed day. Milestones give an Altar item (its price in shards if it's yours already).
const FREEZE_EVERY := 7
const MAX_FREEZES := 2
const STREAK_REWARDS := {3: "bone_light", 7: "gold_flash", 14: "spectral_light", 30: "void_flash"}
## Quests (E3): QUEST_COUNT a day from QUESTS, counted from when they're dealt (MetaState.stats).
const QUEST_COUNT := 3
const QUESTS: Array[Dictionary] = [
	{"id": "q_floors_3", "text": "Clear 3 floors.", "stat": "floors", "goal": 3, "shards": 15},
	{"id": "q_floors_5", "text": "Clear 5 floors.", "stat": "floors", "goal": 5, "shards": 25},
	{"id": "q_floors_8", "text": "Clear 8 floors.", "stat": "floors", "goal": 8, "shards": 30},
	{"id": "q_keys_6", "text": "Pick up 6 keys.", "stat": "sigils", "goal": 6, "shards": 15},
	{"id": "q_keys_10", "text": "Pick up 10 keys.", "stat": "sigils", "goal": 10, "shards": 20},
	{"id": "q_chests_3", "text": "Open 3 chests.", "stat": "chests", "goal": 3, "shards": 15},
	{"id": "q_chests_6", "text": "Open 6 chests.", "stat": "chests", "goal": 6, "shards": 25},
	{"id": "q_close_2", "text": "Survive 2 Close Calls.", "stat": "close_calls", "goal": 2, "shards": 20},
	{"id": "q_close_4", "text": "Survive 4 Close Calls.", "stat": "close_calls", "goal": 4, "shards": 30},
	{"id": "q_dodge_1", "text": "Flip out of its grab (a Phase Dodge).", "stat": "phase_dodges", "goal": 1, "shards": 20},
	{"id": "q_dodge_3", "text": "Make 3 Phase Dodges.", "stat": "phase_dodges", "goal": 3, "shards": 30},
	{"id": "q_flips_25", "text": "Flip 25 times.", "stat": "flips", "goal": 25, "shards": 15},
	{"id": "q_flips_60", "text": "Flip 60 times.", "stat": "flips", "goal": 60, "shards": 20},
	{"id": "q_grade_s_1", "text": "Earn an S grade.", "stat": "grade_s", "goal": 1, "shards": 20},
	{"id": "q_grade_s_3", "text": "Earn 3 S grades.", "stat": "grade_s", "goal": 3, "shards": 30},
	{"id": "q_circles_5", "text": "Step into 5 safe circles.", "stat": "circles", "goal": 5, "shards": 15},
	{"id": "q_cracks_3", "text": "Crack 3 floors and keep walking.", "stat": "cracks", "goal": 3, "shards": 20},
	{"id": "q_flipping_3", "text": "Ride out Flipping Time 3 times.", "stat": "forced_flips", "goal": 3, "shards": 20},
	{"id": "q_hunted_3", "text": "Face the Devil on 3 floors.", "stat": "devil_wakes", "goal": 3, "shards": 15},
	{"id": "q_escapes_3", "text": "Slip out of its reach 3 times.", "stat": "devil_escapes", "goal": 3, "shards": 25},
	{"id": "q_daily_play", "text": "Play today's Daily.", "stat": "daily_runs", "goal": 1, "shards": 15},
	{"id": "q_daily_clear", "text": "Finish today's Daily.", "stat": "daily_clears", "goal": 1, "shards": 30},
	{"id": "q_note_1", "text": "Find a lore note.", "stat": "notes", "goal": 1, "shards": 20},
	{"id": "q_deaths_3", "text": "Die 3 times. It happens.", "stat": "deaths", "goal": 3, "shards": 15},
]

## The profile's Daily state (saved in MetaState's file): the last ranked try and its result, the streak, and the
## day's quests (dealt on quest_day; their counters start from quest_base; `rerolled` = the one swapped out).
static var played := ""
static var result: Array[String] = []
static var result_time := 0.0
static var streak := 0
static var best_streak := 0
static var freezes := 0
static var quest_day := ""
static var quest_ids: Array[String] = []
static var quest_base := {}
static var quests_done: Array[String] = []
static var rerolled := ""


static func today() -> String:
	return Time.get_date_string_from_system(true)


static func day_index(date: String) -> int:
	return floori(Time.get_unix_time_from_datetime_string(date) / 86400.0)


static func number(date: String) -> int:
	return day_index(date) - day_index(FIRST_DAY) + 1


## The day's run seed: everyone plays the same floors.
static func seed_of(date: String) -> int:
	return hash(["daily", date]) | 1


## Daily floor `daily_floor`'s rule cards (1..FLOORS): one each, FINALE_CARDS on the last, none twice in a day.
static func cards(date: String, daily_floor: int) -> Array[String]:
	var deck := Cards.draw(seed_of(date), DECK_ACT, FLOORS - 1 + FINALE_CARDS, [])
	return deck.slice(daily_floor - 1, daily_floor - 1 + (FINALE_CARDS if daily_floor == FLOORS else 1))


## The day's omen: the same for everyone, whatever their Altar.
static func omen(date: String) -> String:
	return Cards.omens(seed_of(date), Cards.omen_pool(99), [])[0]


static func quest(id: String) -> Dictionary:
	for entry: Dictionary in QUESTS:
		if entry["id"] == id:
			return entry
	return {}


## The day's quests: shuffled by the date, never two on one counter. `swapped` (a reroll) makes way for the next.
static func quests(date: String, swapped := "") -> Array[String]:
	var order: Array = QUESTS.map(func(entry: Dictionary) -> String: return entry["id"])
	Cards._shuffle(order, hash([date, "quests"]))
	var picked: Array[String] = []
	var counters := {}
	for id: String in order:
		var counter: String = quest(id)["stat"]
		if picked.size() == QUEST_COUNT or id == swapped or counters.has(counter):
			continue
		counters[counter] = true
		picked.append(id)
	return picked


## Playing the ranked Daily on `date` after last playing it on `last` ("" = never): the new [streak, freezes].
## Missed days are covered by freezes when there are enough; otherwise the streak starts again at 1, no penalty.
static func next_streak(days: int, frozen: int, last: String, date: String) -> Array[int]:
	var gap := 0 if last.is_empty() else day_index(date) - day_index(last)
	if not last.is_empty() and gap <= 0:
		return [days, frozen]
	if not last.is_empty() and days > 0 and gap - 1 <= frozen:
		frozen -= gap - 1
		days += 1
	else:
		days = 1
	if days % FREEZE_EVERY == 0:
		frozen = mini(frozen + 1, MAX_FREEZES)
	return [days, frozen]


## How a cleared floor reads on the share line: an S, chased, or clean.
static func mark(grade: String, chased_seconds: float) -> String:
	if grade == "S":
		return "s"
	return "chased" if chased_seconds > CHASED_SECONDS else "clean"


## The share line (E2): "FearFlip Daily #37 🟦🟦🟥⭐💀 4/5 · 6:41".
static func share_text(date: String, marks: Array, seconds: float) -> String:
	var squares := "".join(PackedStringArray(marks.map(func(m: String) -> String: return MARKS[m])))
	var cleared := marks.filter(func(m: String) -> bool: return m != "died").size()
	return "FearFlip Daily #%d %s %d/%d · %d:%02d" % [number(date), squares, cleared, FLOORS, floori(seconds / 60.0), floori(seconds) % 60]


static func ranked_open(date: String) -> bool:
	return played != date


## The ranked try begins and is spent (a quit keeps what was played): it moves the streak, which may pay a
## milestone, and counts for the day's quests. Returns what to announce.
static func begin_ranked(date: String) -> Array[String]:
	var next := next_streak(streak, freezes, played, date)
	var news: Array[String] = []
	for milestone: int in STREAK_REWARDS:
		if best_streak < milestone and next[0] >= milestone:
			MetaState.grant(STREAK_REWARDS[milestone])
			news.append("STREAK  ·  %d DAYS" % milestone)
	streak = next[0]
	freezes = next[1]
	best_streak = maxi(best_streak, streak)
	played = date
	result.clear()
	result_time = 0.0
	news.append_array(MetaState.record({"daily_runs": 1}))
	return news


## A ranked floor is over (cleared or died on): its square and its time, kept at once.
static func add_result(square: String, seconds: float) -> void:
	result.append(square)
	result_time += seconds
	MetaState.save()


## Deals `date`'s quests once that day; their counters start from now.
static func refresh_quests(date: String) -> void:
	if quest_day == date:
		return
	quest_day = date
	rerolled = ""
	quests_done.clear()
	quest_ids = quests(date)
	quest_base = MetaState.stats.duplicate()


static func progress(id: String) -> int:
	var entry := quest(id)
	return mini(MetaState.stat(entry["stat"]) - int(quest_base.get(entry["stat"], 0)), entry["goal"])


## After counters are banked (MetaState.record): pays each of the day's quests that just got there.
static func check_quests() -> Array[String]:
	var news: Array[String] = []
	for id in quest_ids:
		if not quests_done.has(id) and progress(id) >= quest(id)["goal"]:
			quests_done.append(id)
			MetaState.shards += quest(id)["shards"]
			news.append("QUEST  ·  " + quest(id)["text"])
	return news


## The day's free reroll: unfinished quest `id` makes way for the next in line, which counts from now.
static func reroll(id: String) -> bool:
	if not rerolled.is_empty() or not quest_ids.has(id) or quests_done.has(id):
		return false
	rerolled = id
	var dealt := quest_ids.duplicate()
	quest_ids = quests(quest_day, id)
	for fresh in quest_ids:
		if not dealt.has(fresh):
			var counter: String = quest(fresh)["stat"]
			quest_base[counter] = MetaState.stat(counter)
	MetaState.save()
	return true


static func load_state(cfg: ConfigFile) -> void:
	played = cfg.get_value("daily", "played", "")
	result.assign(cfg.get_value("daily", "result", []))
	result_time = cfg.get_value("daily", "result_time", 0.0)
	streak = cfg.get_value("daily", "streak", 0)
	best_streak = cfg.get_value("daily", "best_streak", 0)
	freezes = cfg.get_value("daily", "freezes", 0)
	quest_day = cfg.get_value("daily", "quest_day", "")
	quest_ids.assign(cfg.get_value("daily", "quests", []))
	quest_base = cfg.get_value("daily", "quest_base", {})
	quests_done.assign(cfg.get_value("daily", "quests_done", []))
	rerolled = cfg.get_value("daily", "rerolled", "")


static func save_state(cfg: ConfigFile) -> void:
	cfg.set_value("daily", "played", played)
	cfg.set_value("daily", "result", result)
	cfg.set_value("daily", "result_time", result_time)
	cfg.set_value("daily", "streak", streak)
	cfg.set_value("daily", "best_streak", best_streak)
	cfg.set_value("daily", "freezes", freezes)
	cfg.set_value("daily", "quest_day", quest_day)
	cfg.set_value("daily", "quests", quest_ids)
	cfg.set_value("daily", "quest_base", quest_base)
	cfg.set_value("daily", "quests_done", quests_done)
	cfg.set_value("daily", "rerolled", rerolled)
