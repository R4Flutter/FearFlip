class_name LiveOps
extends RefCounted
## Live ops (plans/06 P9): what switches on by date, and which acts are out. The week's cursed card (Cards.WEEKLY)
## joins the run-start curse offer; an event (Cards.EVENTS: Blood Moon, Frozen Nightmare) adds its rule cards to every
## deck and sells its cosmetics at the Altar while it runs. Off under the test runner (like the playtest log) unless a
## test turns it on with its own `date`.

static var on := RunState.is_game()
## The day live ops read: "" = today (UTC, like the Daily).
static var date := ""
## Acts players can reach: ship Acts 1-3, then raise this for the Act 4 and Act 5 drops, one update each (plans/06 §2).
static var released_acts := StageRule.ACT_COUNT


static func today() -> String:
	return date if date != "" else Daily.today()


## This week's cursed card ("" while live ops are off).
static func cursed_week() -> String:
	return Cards.weekly(today()) if on else ""


## The event running today ({} when there is none, or while live ops are off).
static func event() -> Dictionary:
	return Cards.event_on(today()) if on else {}


## An Altar item can be bought now: an event's cosmetics only while it runs.
static func in_season(item: Dictionary) -> bool:
	return not item.has("event") or event().get("id") == item["event"]
