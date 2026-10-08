class_name Unlocks
extends RefCounted
## The meta hub's tables (plans/06 P5). The Altar (D2) sells options, never raw power: more omens in the pool,
## starting omen slots, flashlights (side-grades; their mods live in Cards.TORCHES) and the colour of your light
## and of your flip. MetaState holds what a profile owns; this holds what there is.

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


## An Altar item with its card's name, text and mods ({} for an unknown id).
static func item(id: String) -> Dictionary:
	for entry: Dictionary in ALTAR:
		if entry["id"] == id:
			return Cards.find(id).merged(entry)
	return {}


## The free item of a gear kind: worn until you equip another.
static func default_gear(kind: String) -> String:
	for entry: Dictionary in ALTAR:
		if entry["kind"] == kind and entry["cost"] == 0:
			return entry["id"]
	return ""
