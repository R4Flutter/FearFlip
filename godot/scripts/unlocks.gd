class_name Unlocks
extends RefCounted
## The meta hub's tables (plans/06 P5). The Altar (D2) sells options, never raw power: more omens in the pool,
## starting omen slots, flashlights (side-grades; their mods live in Cards.TORCHES) and the colour of your light
## and of your flip. Challenges (D5) are lifetime counters (MetaState.stats, banked with each floor) that pay
## shards or an Altar item. MetaState holds what a profile owns and has done; this holds what there is.

const KINDS: Array[String] = ["omen", "slot", "torch", "light", "flash"]
## Gear: one of each kind is worn (MetaState.equip); the free one until you pick another.
const EQUIP_KINDS: Array[String] = ["torch", "light", "flash"]
## Altar items. Omens and torches take their name, text and mods from Cards. "after" = owned first; cost 0 = yours
## from the start. Prices climb gently: for a new profile the next unlock is never more than 2 runs away (P5 gate).
const ALTAR: Array[Dictionary] = [
	{"id": "twin_flip", "kind": "omen", "cost": 70},
	{"id": "feather_step", "kind": "omen", "cost": 90},
	{"id": "cartographer", "kind": "omen", "cost": 110},
	{"id": "locksmith", "kind": "omen", "cost": 130},
	{"id": "blood_pact", "kind": "omen", "cost": 150},
	{"id": "ghost_sight", "kind": "omen", "cost": 170},
	{"id": "last_breath", "kind": "omen", "cost": 200},
	{"id": "lantern_heart", "kind": "omen", "cost": 220},
	{"id": "echo_step", "kind": "omen", "cost": 240},
	{"id": "soft_soles", "kind": "omen", "cost": 260},
	{"id": "slot_1", "kind": "slot", "cost": 180, "name": "OMEN SLOT I", "text": "Every run starts with an omen pick."},
	{"id": "slot_2", "kind": "slot", "cost": 300, "after": "slot_1", "name": "OMEN SLOT II", "text": "Every run starts with a second omen pick."},
	{"id": "old_torch", "kind": "torch", "cost": 0},
	{"id": "lantern", "kind": "torch", "cost": 100},
	{"id": "uv_light", "kind": "torch", "cost": 160, "after": "lantern"},
	{"id": "camera_flash", "kind": "torch", "cost": 240, "after": "uv_light"},
	{"id": "cold_light", "kind": "light", "cost": 0, "name": "COLD LIGHT", "text": "The torch's own pale blue.", "color": Color(0.68, 0.82, 1.0)},
	{"id": "ember_light", "kind": "light", "cost": 80, "name": "EMBER LIGHT", "text": "A warm orange beam, like the last of a fire.", "color": Color(1.0, 0.72, 0.45)},
	{"id": "bone_light", "kind": "light", "cost": 120, "name": "BONE LIGHT", "text": "Plain white, the colour of old paper.", "color": Color(1.0, 0.96, 0.88)},
	{"id": "blood_light", "kind": "light", "cost": 140, "name": "BLOOD LIGHT", "text": "Red, so you see the maze the way he does.", "color": Color(1.0, 0.42, 0.38)},
	{"id": "spectral_light", "kind": "light", "cost": 180, "name": "SPECTRAL LIGHT", "text": "A sickly green glow, cold as a ghost story.", "color": Color(0.6, 1.0, 0.72)},
	{"id": "world_flash", "kind": "flash", "cost": 0, "name": "WORLD FLASH", "text": "Each flip flashes the colour of the world you land in."},
	{"id": "gold_flash", "kind": "flash", "cost": 100, "name": "GOLD FLASH", "text": "Each flip flashes gold.", "color": Color(1.0, 0.78, 0.3)},
	{"id": "void_flash", "kind": "flash", "cost": 150, "name": "VOID FLASH", "text": "Each flip blinks violet-black, like falling asleep.", "color": Color(0.3, 0.0, 0.45)},
]

## Challenges: once MetaState.stat(stat) reaches goal they pay "shards" or "item" (an Altar item; its price in
## shards if you own it already). The counters are MetaState.record()'s keys.
const CHALLENGES: Array[Dictionary] = [
	{"id": "first_light", "name": "FIRST LIGHT", "text": "Clear a floor.", "stat": "floors", "goal": 1, "shards": 10},
	{"id": "night_shift", "name": "NIGHT SHIFT", "text": "Clear 10 floors.", "stat": "floors", "goal": 10, "shards": 25},
	{"id": "deep_sleeper", "name": "DEEP SLEEPER", "text": "Clear 25 floors.", "stat": "floors", "goal": 25, "item": "bone_light"},
	{"id": "insomniac", "name": "INSOMNIAC", "text": "Clear 50 floors.", "stat": "floors", "goal": 50, "shards": 80},
	{"id": "the_long_night", "name": "THE LONG NIGHT", "text": "Clear 100 floors.", "stat": "floors", "goal": 100, "shards": 150},
	{"id": "keyholder", "name": "KEYHOLDER", "text": "Pick up 10 keys.", "stat": "sigils", "goal": 10, "shards": 15},
	{"id": "ring_of_keys", "name": "RING OF KEYS", "text": "Pick up 50 keys.", "stat": "sigils", "goal": 50, "shards": 40},
	{"id": "warden", "name": "WARDEN", "text": "Pick up 200 keys.", "stat": "sigils", "goal": 200, "shards": 100},
	{"id": "finders_keepers", "name": "FINDERS KEEPERS", "text": "Open 10 chests.", "stat": "chests", "goal": 10, "shards": 20},
	{"id": "chest_hunter", "name": "CHEST HUNTER", "text": "Open 25 chests.", "stat": "chests", "goal": 25, "item": "locksmith"},
	{"id": "hoarder", "name": "HOARDER", "text": "Open 75 chests.", "stat": "chests", "goal": 75, "shards": 80},
	{"id": "too_close", "name": "TOO CLOSE", "text": "Survive 5 Close Calls.", "stat": "close_calls", "goal": 5, "shards": 20},
	{"id": "nerves_of_steel", "name": "NERVES OF STEEL", "text": "Survive 25 Close Calls.", "stat": "close_calls", "goal": 25, "item": "gold_flash"},
	{"id": "untouchable", "name": "UNTOUCHABLE", "text": "Survive 75 Close Calls.", "stat": "close_calls", "goal": 75, "shards": 120},
	{"id": "slip_away", "name": "SLIP AWAY", "text": "Flip out of its reach 3 times (Phase Dodge).", "stat": "phase_dodges", "goal": 3, "shards": 20},
	{"id": "phase_walker", "name": "PHASE WALKER", "text": "10 Phase Dodges.", "stat": "phase_dodges", "goal": 10, "item": "echo_step"},
	{"id": "between_worlds", "name": "BETWEEN WORLDS", "text": "30 Phase Dodges.", "stat": "phase_dodges", "goal": 30, "shards": 100},
	{"id": "blink", "name": "BLINK", "text": "Flip 50 times.", "stat": "flips", "goal": 50, "shards": 15},
	{"id": "flicker", "name": "FLICKER", "text": "Flip 250 times.", "stat": "flips", "goal": 250, "item": "void_flash"},
	{"id": "world_weary", "name": "WORLD WEARY", "text": "Flip 1,000 times.", "stat": "flips", "goal": 1000, "shards": 100},
	{"id": "clean_escape", "name": "CLEAN ESCAPE", "text": "Earn an S grade.", "stat": "grade_s", "goal": 1, "shards": 15},
	{"id": "perfectionist", "name": "PERFECTIONIST", "text": "Earn 10 S grades.", "stat": "grade_s", "goal": 10, "shards": 50},
	{"id": "flawless", "name": "FLAWLESS", "text": "Earn 30 S grades.", "stat": "grade_s", "goal": 30, "shards": 120},
	{"id": "awakened", "name": "AWAKENED", "text": "Clear Act 1.", "stat": "clears_act_1", "goal": 1, "shards": 50},
	{"id": "no_longer_hunted", "name": "NO LONGER HUNTED", "text": "Clear Act 2.", "stat": "clears_act_2", "goal": 1, "shards": 75},
	{"id": "mind_unbroken", "name": "MIND UNBROKEN", "text": "Clear Act 3.", "stat": "clears_act_3", "goal": 1, "shards": 100},
	{"id": "steady_hands", "name": "STEADY HANDS", "text": "Clear Act 4.", "stat": "clears_act_4", "goal": 1, "shards": 125},
	{"id": "breaker_broken", "name": "THE BREAKER BROKEN", "text": "Clear Act 5 and escape.", "stat": "clears_act_5", "goal": 1, "shards": 200},
	{"id": "no_second_chances", "name": "NO SECOND CHANCES", "text": "Clear an act without a revive.", "stat": "acts_clean", "goal": 1, "shards": 60},
	{"id": "cursed_and_alive", "name": "CURSED AND ALIVE", "text": "Clear an act with a curse.", "stat": "acts_cursed", "goal": 1, "shards": 80},
	{"id": "soft_steps", "name": "SOFT STEPS", "text": "Clear Act 1 without sprinting.", "stat": "act1_no_sprint", "goal": 1, "item": "soft_soles"},
	{"id": "gatecrasher", "name": "GATECRASHER", "text": "Earn an S grade on a Gate.", "stat": "gate_s", "goal": 1, "shards": 60},
	{"id": "going_deeper", "name": "GOING DEEPER", "text": "Descend from a Gate.", "stat": "descents", "goal": 1, "shards": 40},
	{"id": "no_way_back", "name": "NO WAY BACK", "text": "Descend 3 times.", "stat": "descents", "goal": 3, "shards": 100},
	{"id": "deep_run", "name": "DEEP RUN", "text": "Floor 1 to floor 50 in one run.", "stat": "deep_runs", "goal": 1, "shards": 300},
	{"id": "again_and_again", "name": "AGAIN AND AGAIN", "text": "Die 10 times. It's how you learn.", "stat": "deaths", "goal": 10, "shards": 25},
	{"id": "light_feet", "name": "LIGHT FEET", "text": "Crack 10 floors under you and keep walking.", "stat": "cracks", "goal": 10, "shards": 20},
	{"id": "reader", "name": "READER", "text": "Find 5 lore notes.", "stat": "notes", "goal": 5, "shards": 25},
	{"id": "archivist", "name": "ARCHIVIST", "text": "Find all 30 lore notes.", "stat": "notes", "goal": 30, "shards": 150},
	{"id": "safe_haven", "name": "SAFE HAVEN", "text": "Step into 20 safe circles.", "stat": "circles", "goal": 20, "shards": 15},
]


## An Altar item with its card's name, text and mods ({} for an unknown id).
static func item(id: String) -> Dictionary:
	for entry: Dictionary in ALTAR:
		if entry["id"] == id:
			return Cards.find(id).merged(entry)
	return {}


static func challenge(id: String) -> Dictionary:
	for entry: Dictionary in CHALLENGES:
		if entry["id"] == id:
			return entry
	return {}


## The free item of a gear kind: worn until you equip another.
static func default_gear(kind: String) -> String:
	for entry: Dictionary in ALTAR:
		if entry["kind"] == kind and entry["cost"] == 0:
			return entry["id"]
	return ""
