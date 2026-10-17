class_name Portal
extends RefCounted
## The CrazyGames SDK bridge (plans/06 P9, master plan §12), web builds only. Cloud saves ride the SDK's data module
## (up to 1 MB, synced across devices for logged-in players, browser storage for guests): each save file is pushed as
## it's written, stamped with the time, and pulled before it's read only when the cloud's copy is newer than this
## device's last write (the SDK holds writes back about a second, so a tab closed right after a save leaves the cloud
## behind). A new best Long Night time goes to the leaderboard (invited games only; one board a game, weekly seasons
## Monday 09:00 UTC, lowest first; the head include in export_presets.cfg holds its key and encrypts the score). Off the
## web, or before the SDK is ready, every call does nothing.

## Save file -> data module key.
const KEYS := {"user://profile.cfg": "fearflip_profile", "user://save.cfg": "fearflip_run"}
## When this device last wrote each save file (unix seconds).
const STAMPS := "user://cloud_stamps.cfg"


## The SDK has finished initializing (the head include sets the flag). eval hands a JS boolean back as an int (0/1) and
## int == bool is a script error, so `and` takes its truth.
static func ready() -> bool:
	return OS.has_feature("web") and JavaScriptBridge.eval("!!(window.fearflipSdk && window.fearflipSdk.ready)", true)


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


## The CrazyGames user token (a JWT the SDK keeps fresh; the Long Night server verifies it, plans/11 v2), or "" for a
## guest, off the web, or when the SDK hasn't answered within ~10 s.
static func user_token() -> String:
	if not ready():
		return ""
	var got: Array = []
	var take := func(args: Array) -> void: got.append(args[0] if not args.is_empty() and args[0] is String else "")
	var ok := JavaScriptBridge.create_callback(take)
	var fail := JavaScriptBridge.create_callback(take)  # userNotAuthenticated: a guest
	var crazy: Variant = JavaScriptBridge.get_interface("CrazyGames")
	crazy.SDK.user.getUserToken().then(ok, fail)
	var tree := Engine.get_main_loop() as SceneTree
	for _frame in 600:
		if not got.is_empty():
			break
		await tree.process_frame
	return got[0] if not got.is_empty() else ""


## A new best Long Night time in milliseconds (plans/11): the board keeps each player's lowest this season. It holds
## the race now, not Abyss depth (plans/06 F4): one maze for everyone is a fair comparison, depths in different mazes
## aren't. Only without a Race.SERVER: with one, the server verifies the run and submits it itself.
static func submit_time(ms: int) -> void:
	if ready():
		JavaScriptBridge.eval("window.fearflipSubmitScore && window.fearflipSubmitScore(%d)" % ms, true)


## VERSUS (plans/12): CrazyGames' invite link to room `code` (their Invite button shows it in the page around the
## game while a room waits), and the room of the link this page was opened from ("" if none: instant multiplayer).
## Names per CrazyGames' SDK v3 game module; web only.
static func show_invite(code: String) -> void:
	if ready():
		JavaScriptBridge.eval("window.CrazyGames.SDK.game.showInviteButton(%s)" % JSON.stringify({"room": code}), true)


static func hide_invite() -> void:
	if ready():
		JavaScriptBridge.eval("window.CrazyGames.SDK.game.hideInviteButton()", true)


static func invite_link(code: String) -> String:
	if not ready():
		return ""
	var link: Variant = JavaScriptBridge.eval("window.CrazyGames.SDK.game.inviteLink(%s)" % JSON.stringify({"room": code}), true)
	return link if link is String else ""


static func invite_room() -> String:
	if not ready():
		return ""
	var room: Variant = JavaScriptBridge.eval("window.CrazyGames.SDK.game.getInviteParam('room')", true)
	return room if room is String else ""


## The CrazyGames username in the user token (user_token), or "" for a guest or off the web.
static func username() -> String:
	var token: String = await user_token()
	var parts := token.split(".")
	if parts.size() != 3:
		return ""
	var body := parts[1].replace("-", "+").replace("_", "/")
	body += "=".repeat((4 - body.length() % 4) % 4)
	var claims: Variant = JSON.parse_string(Marshalls.base64_to_utf8(body))
	return str(claims.get("username", "")) if claims is Dictionary else ""
