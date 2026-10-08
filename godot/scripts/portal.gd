class_name Portal
extends RefCounted
## The CrazyGames SDK bridge (plans/06 P9, master plan §12), web builds only. Cloud saves ride the SDK's data module
## (up to 1 MB, synced across devices for logged-in players, browser storage for guests): each save file is pushed as
## it's written and pulled before it's read. A new deepest Abyss run goes to the leaderboard (invited games only; the
## head include in export_presets.cfg holds its key and encrypts the score). Off the web, or before the SDK is ready,
## every call does nothing.

## Save file -> data module key.
const KEYS := {"user://profile.cfg": "fearflip_profile", "user://save.cfg": "fearflip_run"}


## The SDK has finished initializing (the head include sets the flag).
static func ready() -> bool:
	return OS.has_feature("web") and JavaScriptBridge.eval("!!(window.fearflipSdk && window.fearflipSdk.ready)", true) == true


## Before `path` is read: the cloud copy, if there is one, replaces the local file.
static func pull(path: String) -> void:
	if not KEYS.has(path) or not ready():
		return
	var text: Variant = JavaScriptBridge.eval("window.CrazyGames.SDK.data.getItem(%s)" % JSON.stringify(KEYS[path]), true)
	if text is String and not (text as String).is_empty():
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string(text)


## After `path` is written: the same text to the cloud.
static func push(path: String) -> void:
	if KEYS.has(path) and ready():
		JavaScriptBridge.eval(set_item_js(KEYS[path], FileAccess.get_file_as_string(path)), true)


static func set_item_js(key: String, text: String) -> String:
	return "window.CrazyGames.SDK.data.setItem(%s, %s)" % [JSON.stringify(key), JSON.stringify(text)]


## A new deepest Abyss run (plans/06 F4): the leaderboard keeps each player's best.
static func submit_depth(depth: int) -> void:
	if ready():
		JavaScriptBridge.eval("window.fearflipSubmitDepth && window.fearflipSubmitDepth(%d)" % depth, true)
