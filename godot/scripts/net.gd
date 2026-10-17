class_name Net
extends RefCounted
## VERSUS's link (plans/12): one WebSocket into a room of the relay (server/versus), which passes each binary message to
## the other player. Static, so it outlives the scene changes of a match; whoever shows the room calls poll() every
## frame (the menu, then VersusMatch). What arrives waits in an inbox until drained, so nothing is lost while a floor
## loads; the relay's notices come through it as Versus.PEER_JOINED / PEER_LEFT. Text on the socket is only ever the
## relay's own.

## The deployed relay ("" until `npm run deploy` in server/versus prints it, as wss://...). Debug builds without it use
## the local one (`npm run dev` there).
const SERVER := ""
const DEV_SERVER := "ws://127.0.0.1:8787"
## A room code: five of these (no 0/O or 1/I, which look alike read out), as the relay checks.
const CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const CODE_LENGTH := 5
## Why the link closed, for the page to say.
const PROBLEMS := {4001: "THAT ROOM IS FULL", 4002: "THE GAME SENT TOO MUCH", 4003: "THE GAME SENT TOO FAST"}

static var code := ""
static var peer_here := false
## Why the link closed ("" while it's fine).
static var problem := ""
static var _socket: WebSocketPeer
static var _opened := false
static var _inbox: Array[Array] = []
static var _heard_at := 0.0
static var _sent_at := 0.0


static func server() -> String:
	return SERVER if not SERVER.is_empty() else (DEV_SERVER if OS.is_debug_build() else "")


static func new_code() -> String:
	var letters := ""
	for _i in CODE_LENGTH:
		letters += CODE_CHARS[randi() % CODE_CHARS.length()]
	return letters


## A code as typed (any case, spaces round it), or "" if it can't be one.
static func clean_code(text: String) -> String:
	var typed := text.strip_edges().to_upper()
	if typed.length() != CODE_LENGTH:
		return ""
	for letter in typed:
		if not CODE_CHARS.contains(letter):
			return ""
	return typed


## Into room `room`, leaving any other. False (with `problem` saying why) if it can't even try.
static func join(room: String) -> bool:
	leave()
	if server().is_empty():
		problem = "VERSUS HAS NO SERVER IN THIS BUILD YET"
		return false
	_socket = WebSocketPeer.new()
	if _socket.connect_to_url("%s/room/%s" % [server(), room]) != OK:
		_socket = null
		problem = "THE VERSUS SERVER IS OUT OF REACH"
		return false
	code = room
	problem = ""
	_heard_at = _now()
	return true


static func leave() -> void:
	if _socket != null:
		_socket.close(1000, "bye")
	_socket = null
	_opened = false
	code = ""
	peer_here = false
	_inbox.clear()


static func connected() -> bool:
	return _socket != null and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN


static func send(msg: Array) -> void:
	if connected() and Versus.valid(msg):
		_socket.put_packet(Versus.encode(msg))
		_sent_at = _now()


## A PING when nothing else went out for Versus.PING_EVERY: the peer knows this game still runs.
static func keep_alive() -> void:
	if _now() - _sent_at >= Versus.PING_EVERY:
		send([Versus.PING])


## One line for the relay's logs (one a round: the dashboard's numbers).
static func log_line(data: Dictionary) -> void:
	if connected():
		_socket.send_text(JSON.stringify({"log": data}))


## Everything since the last call, oldest first.
static func drain() -> Array[Array]:
	var got := _inbox
	_inbox = []
	return got


## Seconds since the peer last sent anything.
static func silent_for() -> float:
	return _now() - _heard_at


## Every frame while a room is shown: reads the socket into the inbox, and notes it closing (and why).
static func poll() -> void:
	if _socket == null:
		return
	_socket.poll()
	var state := _socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		_opened = true
		while _socket.get_available_packet_count() > 0:
			var packet := _socket.get_packet()
			if _socket.was_string_packet():
				_notice(packet.get_string_from_utf8())
				continue
			var msg := Versus.decode(packet)
			if not msg.is_empty():
				_heard_at = _now()
				_inbox.append(msg)
	elif state == WebSocketPeer.STATE_CLOSED:
		var why := _socket.get_close_code()
		problem = PROBLEMS.get(why, "THE CONNECTION DROPPED" if _opened else "THE VERSUS SERVER IS OUT OF REACH")
		if peer_here:
			_inbox.append([Versus.PEER_LEFT])
		peer_here = false
		_socket = null
		_opened = false


static func _notice(text: String) -> void:
	var notice: Variant = JSON.parse_string(text)
	if not notice is Dictionary:
		return
	match notice.get("peer", ""):
		"joined":
			peer_here = true
			_heard_at = _now()
			_inbox.append([Versus.PEER_JOINED])
		"left":
			peer_here = false
			_inbox.append([Versus.PEER_LEFT])
	if notice.get("error", "") == "full":
		problem = PROBLEMS[4001]


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
