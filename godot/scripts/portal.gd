class_name Portal
extends RefCounted
## The CrazyGames SDK bridge (plans/06 P9, master plan §12), web builds only. Cloud saves ride the SDK's data module
## (up to 1 MB, synced across devices for logged-in players, browser storage for guests): each save file is pushed as
## it's written, stamped with the time, and pulled before it's read only when the cloud's copy is newer than this
## device's last write (the SDK holds writes back about a second, so a tab closed right after a save leaves the cloud
## behind). A new deepest Abyss run goes to the leaderboard (invited games only; the head include in
## export_presets.cfg holds its key and encrypts the score). Off the web, or before the SDK is ready, every call does
## nothing.

## Save file -> data module key.
const KEYS := {"user://profile.cfg": "fearflip_profile", "user://save.cfg": "fearflip_run"}
## When this device last wrote each save file (unix seconds).
const STAMPS := "user://cloud_stamps.cfg"


## The SDK has finished initializing (the head include sets the flag).
static func ready() -> bool:
	return OS.has_feature("web") and JavaScriptBridge.eval("!!(window.fearflipSdk && window.fearflipSdk.ready)", true) == true


## Before `path` is read: the cloud copy replaces the local file when it's newer than this device's last write.
static func pull(path: String) -> void:
	if not KEYS.has(path) or not ready():
		return
	var stored: Variant = JavaScriptBridge.eval("window.CrazyGames.SDK.data.getItem(%s)" % JSON.stringify(KEYS[path]), true)
	var item: Variant = JSON.parse_string(stored) if stored is String else null
	var stamps := ConfigFile.new()
	stamps.load(STAMPS)
	if not cloud_wins(item, stamps.get_value("written", path, 0.0)):
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(item["text"])
		stamps.set_value("written", path, item["t"])
		stamps.save(STAMPS)


## After `path` is written: the same text to the cloud, stamped.
static func push(path: String) -> void:
	if not KEYS.has(path) or not ready():
		return
	var now := Time.get_unix_time_from_system()
	var stamps := ConfigFile.new()
	stamps.load(STAMPS)
	stamps.set_value("written", path, now)
	stamps.save(STAMPS)
	JavaScriptBridge.eval(set_item_js(KEYS[path], JSON.stringify({"t": now, "text": FileAccess.get_file_as_string(path)})), true)


## A stamped cloud copy ({"t", "text"}) newer than this device's last write of the file.
static func cloud_wins(item: Variant, written: float) -> bool:
	return item is Dictionary and item.has("text") and float(item.get("t", 0.0)) > written


static func set_item_js(key: String, text: String) -> String:
	return "window.CrazyGames.SDK.data.setItem(%s, %s)" % [JSON.stringify(key), JSON.stringify(text)]


## A new deepest Abyss run (plans/06 F4): the leaderboard keeps each player's best.
static func submit_depth(depth: int) -> void:
	if ready():
		JavaScriptBridge.eval("window.fearflipSubmitDepth && window.fearflipSubmitDepth(%d)" % depth, true)
