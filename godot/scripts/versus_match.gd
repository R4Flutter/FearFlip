class_name VersusMatch
extends Node
## One VERSUS round in the game scene (plans/12), on both players' machines. The runner's machine is the referee: its
## main.gd plays the real floor with the Devil node following the other player's Devil (devil_sample), and this tells
## the Devil's game what happens (report, heard, snapped, round_over) and where the runner is while the Devil could see
## them. The Devil's machine steers main.gd's player body as the Devil (its legs, eyes and glare; no map, no boxes) and
## shows the rest from those reports: the runner's body on a puppet, what it hears as 3D sound and a ripple through the
## walls, the flips, the lids, the keys and the clock. Then both show the round, and after round 2 the match.

## A heard sound's ripple: how long it lasts, its radius from and to (m), its colour; the map's carries wider.
const RIPPLE_TIME := 1.0
const RIPPLE_SIZE := Vector2(0.3, 1.8)
const RIPPLE_COLOR := Color(1.0, 0.25, 0.2, 0.85)
const RIPPLE_WIDE := 1.5
## Heard is heard: a sound it hears plays loud enough from wherever it came.
const HEARD_UNIT := 8.0
## The runner's puppet goes out of sight this long after the last SEEN.
const PUPPET_HIDE := 0.35
## The Devil's eyes sit a little above yours; its glare lights the maze red.
const DEVIL_RISE := 0.2
const DEVIL_GLARE := Color(1.0, 0.3, 0.25)
## The runner's torch on the puppet.
const BEAM_RANGE := 12.0
const BEAM_ANGLE := 28.0
const BEAM_ENERGY := 2.2
const RESULT_NAMES: Array[String] = ["escaped", "caught", "time", "runner_left", "devil_left"]

var main: Node3D
## This machine runs the floor (the referee), or is the Devil.
var runner := true
var started := false
var over := false
var peer_gone := false
## This game stood still long enough for the other one to call it gone (a hidden browser tab stops the game loop).
var away := false
## Referee: the other player's Devil, and how many times the referee moved it (a POS sent before the last snap is
## dropped); false once that player left and the AI took over.
var devil_track := Versus.Track.new()
var epoch := 0
var remote_devil := true
## Devil: the runner as last seen and its SEEN flags; awake after the head start; a lunge or a miss's stun from the
## referee; enraged once the exit opens.
var runner_track := Versus.Track.new()
var runner_flags := 0
var awake := false
var lunge_left := 0.0
var stun_left := 0.0
var enraged := false
var puppet: Node3D
var beam: SpotLight3D
var _steps: AudioStreamRandomizer
var _send_clock := 0.0
var _frame_at := INF
var _leaving := false
var _me_next := false
var _peer_next := false
var _page: ColorRect
var _status: Label
var _next_button: Button


## Called once main.gd has built the floor: hold it until both are ready (READY, then the referee's GO).
func begin(game: Node3D) -> void:
	main = game
	runner = Versus.i_run()
	_frame_at = Versus.dealt_at  # a floor loading past the limit stood still too (a tab hidden as it loads)
	main.game_state = "waiting"
	if not runner:
		_become_devil()
	Net.send([Versus.READY, Versus.round_number])
	main._show_message("%s\nWAITING FOR %s" % [main._floor_title(), Versus.peer()])
	RunState.log_event("versus_round", {"round": Versus.round_number, "runner": runner, "hard": Versus.hard})


## The Devil's machine: your body becomes the Devil (its legs on the runner's, its eyes, its red glare), and the runner's
## body (built as yours) moves onto a puppet the referee steers.
func _become_devil() -> void:
	var body: CharacterBody3D = main.player
	body.position = main.cell_to_world(main.layout.devil_spawn) + Vector3(0, main.PLAYER_HEIGHT, 0)  # its lair, far off
	main.player_cell = main.layout.devil_spawn
	main.feel = Versus.devil_feel(main.feel)
	main.camera_pivot.position.y = main.EYE_HEIGHT + DEVIL_RISE
	main.camera.environment = main._devil_sight()
	main.flashlight.light_color = DEVIL_GLARE
	main.flashlight_on = true
	main.flashlight.visible = true
	puppet = Node3D.new()
	puppet.name = "Runner"
	puppet.visible = false
	main.add_child(puppet)
	var runner_body: Node3D = main.player_mesh
	runner_body.reparent(puppet, false)
	for part: MeshInstance3D in runner_body.find_children("*", "MeshInstance3D", true, false):
		part.layers = 1  # yours were hidden from your own eyes; theirs aren't
	beam = SpotLight3D.new()
	beam.spot_range = BEAM_RANGE
	beam.spot_angle = BEAM_ANGLE
	beam.light_energy = BEAM_ENERGY
	beam.position.y = main.EYE_HEIGHT
	puppet.add_child(beam)
	_steps = main._build_footstep_stream()


func _process(delta: float) -> void:
	if main == null or _leaving or _stood_still():
		return
	Net.poll()
	for msg in Net.drain():
		_take(msg)
	if _leaving:
		return
	Net.keep_alive()
	if not peer_gone and (not Net.connected() or Net.silent_for() > _silence_limit()):
		_peer_left()
	if not started or over:
		return
	_send_clock += delta
	var due := _send_clock >= 1.0 / Versus.SEND_HZ
	if due:
		_send_clock = 0.0
	if runner:
		if due:
			_send_seen()
	else:
		_devil_frame(delta, due)


func _take(msg: Array) -> void:
	match msg[0]:
		Versus.PEER_LEFT:
			_peer_left()
		Versus.READY:
			if runner and not started and msg[1] == Versus.round_number:
				Net.send([Versus.GO, Versus.round_number])
				_start()
		Versus.GO:
			if not runner and not started and msg[1] == Versus.round_number:
				_start()
		Versus.POS:
			if runner and msg[1] >= epoch:
				devil_track.push(_now(), Vector3(msg[2], main.DEVIL_Y, msg[3]), msg[4], msg[5])
		Versus.SEEN:
			if not runner:
				runner_track.push(_now(), Vector3(msg[1], 0.0, msg[2]), msg[3], msg[4])
				runner_flags = msg[5]
		Versus.HEARD:
			if not runner and started and not over:
				_hear(Vector2i(msg[1], msg[2]), msg[3])
		Versus.EVENT:
			if not runner and not over:
				_event(msg[1], msg[2], msg[3])
		Versus.END:
			if not runner and not over and msg[1] == Versus.round_number:
				_end(msg[2], msg[3])
		Versus.NEXT:
			if over and msg[1] == Versus.round_number:
				_peer_next = true
				_maybe_next()
		Versus.START:
			if over and not Versus.host:
				Versus.match_seed = msg[1]
				Versus.hard = msg[2] != 0
				if msg[3] == 1:
					Versus.results.clear()
				Versus.round_number = msg[3]
				_begin_next()


func _start() -> void:
	started = true
	main.game_state = "playing"
	main._show_message("")
	if runner:
		main._flash_message("RUN  ·  IT WAKES IN %d S" % roundi(Versus.HEAD_START))


# --- The referee ------------------------------------------------------------------------------------------------

## Where the referee's Devil heads: [position, facing, speed] of the other player's Devil, DELAY behind; [] before any.
func devil_sample() -> Array:
	return devil_track.sample(_now())


## Something the Devil's game shows (Versus.Event), with its numbers.
func report(kind: int, a := 0.0, b := 0.0) -> void:
	if runner and started and not over and remote_devil:
		Net.send([Versus.EVENT, kind, float(a), float(b)])


## A footstep or the map opening at your cell: sent if the Devil would hear it (path tiles, main.gd::_hears).
func heard(kind: int, radius: int) -> void:
	if runner and started and not over and remote_devil and main._hears(main.player_cell, radius):
		Net.send([Versus.HEARD, main.player_cell.x, main.player_cell.y, kind])


## The referee moved the Devil (a forced flip kept it fair, or a flip walled its cell): it jumps there too, and anything
## it sent before it knew is dropped.
func snapped() -> void:
	if not runner or not remote_devil:
		return
	epoch += 1
	devil_track.clear()
	var at: Vector3 = main.devil.position
	report(Versus.Event.SNAP, at.x, at.z)


## Where you are, only while the Devil could see you (Versus.runner_visible): otherwise it has nothing to read.
func _send_seen() -> void:
	if not remote_devil or not Versus.runner_visible(main.layout, main.world, main.devil_cell, main.player_cell, main._devil_distance()):
		return
	var body: CharacterBody3D = main.player
	var flags := 0
	if main.kneel_w > 0.3:
		flags |= Versus.KNEEL
	if main.paper_map.is_up():
		flags |= Versus.MAP_UP
	if main.rest_left > 0.0:
		flags |= Versus.WINDED
	if main.flashlight_on:
		flags |= Versus.LIGHT
	Net.send([Versus.SEEN, body.global_position.x, body.global_position.z, float(main.yaw + main.body_turn),
			Vector2(body.velocity.x, body.velocity.z).length(), flags])


## The referee's round is over (main.gd: caught, out of time, or at the exit with every key).
func round_over(result: int) -> void:
	if over:
		return
	over = true
	var seconds := snappedf(main.elapsed, 0.1)
	_record(result, seconds)
	if not peer_gone:
		Net.send([Versus.END, Versus.round_number, result, seconds])
		Net.log_line({"result": RESULT_NAMES[result], "seconds": seconds, "mode": "hard" if Versus.hard else "easy",
				"round": Versus.round_number})
	get_tree().create_timer(main.FLOOR_CLEAR_TIME).timeout.connect(_show_round)


# --- The Devil ---------------------------------------------------------------------------------------------------

## The Devil can move: awake, not stunned by a missed lunge, the menu not up.
func lets_move() -> bool:
	if main.pause_menu.visible:
		return false
	return runner or (awake and stun_left <= 0.0)


## Your speed on your legs: the Devil is slower in WAKE and faster enraged; the runner as ever.
func pace() -> float:
	return 1.0 if runner else Versus.devil_pace(main.world == main.NIGHTMARE, enraged)


## The Devil's lunge (the referee saw it reach your cell): it springs at the runner as the referee's Devil does.
func steer(velocity: Vector3) -> Vector3:
	if runner or lunge_left <= 0.0 or not puppet.visible:
		return velocity
	var to: Vector3 = puppet.global_position - main.player.global_position
	return Vector3(to.x, 0.0, to.z).normalized() * main.LUNGE_SPEED


func _devil_frame(delta: float, due: bool) -> void:
	main.elapsed += delta
	main.time_left = maxf(main.time_left - delta, 0.0)
	stun_left = maxf(stun_left - delta, 0.0)
	lunge_left = maxf(lunge_left - delta, 0.0)
	if main.warning_label.visible:
		main.flip.next_forced_in = maxf(main.flip.next_forced_in - delta, 0.0)
	main._strobe_lights(main.warning_label.visible)
	var body: CharacterBody3D = main.player
	main.devil.global_position = Vector3(body.global_position.x, main.DEVIL_Y, body.global_position.z)  # its roar is yours
	if not awake:
		main._show_message("IT SLEEPS  ·  %d\nLISTEN" % ceili(maxf(Versus.HEAD_START - main.elapsed, 0.0)))
	main._update_hud()
	if main.warning_label.visible:
		main.warning_label.text = "FLIPPING TIME  %d\nTHEIR CONTROLS INVERT" % maxi(ceili(main.flip.next_forced_in), 0)
	if due:
		var forward := -body.global_basis.z
		Net.send([Versus.POS, epoch, body.global_position.x, body.global_position.z, atan2(forward.x, forward.z),
				Vector2(body.velocity.x, body.velocity.z).length()])
	_pose_puppet(delta)


## The runner where the referee last said, DELAY behind, in their gait: kneeling at a box, the map up, panting.
func _pose_puppet(delta: float) -> void:
	var got := runner_track.sample(_now())
	if got.is_empty() or runner_track.age(_now()) > PUPPET_HIDE:
		puppet.visible = false
		return
	var at: Vector3 = got[0]
	var body: CharacterBody3D = main.player
	puppet.visible = true
	puppet.position = Vector3(at.x, body.global_position.y, at.z)  # the same capsule as yours stands as high
	puppet.rotation.y = got[1]
	var near := puppet.position.distance_to(body.global_position)
	var fear := clampf(1.0 - near / (main.CELL_SIZE * main.HEARTBEAT_TILES), 0.0, 1.0)
	var rig: DevilRig = main.player_rig
	var y := rig.flee(got[2], delta, fear, 1.0 if runner_flags & Versus.WINDED else 0.0, Vector2.ZERO)
	rig.hold_map(1.0 if runner_flags & Versus.MAP_UP else 0.0)
	if runner_flags & Versus.KNEEL:
		y = rig.kneel(1.0)
	(main.player_mesh as Node3D).position.y = main.PLAYER_MESH_Y + y
	beam.visible = runner_flags & Versus.LIGHT != 0


## A sound it heard: from that cell, as 3D sound and a ripple seen through the walls (people often play muted).
func _hear(cell: Vector2i, kind: int) -> void:
	if not main.layout.is_open(FloorLayout.ANY, cell):  # the runner only ever stands on an open cell
		return
	var at: Vector3 = main.cell_to_world(cell)
	var sound := AudioStreamPlayer3D.new()
	sound.stream = load(PaperMap.OPEN_SOUND) if kind == Versus.Sound.MAP else _steps
	sound.bus = Settings.SFX_BUS
	sound.unit_size = HEARD_UNIT
	sound.volume_db = 4.0 if kind == Versus.Sound.SPRINT else 0.0
	sound.position = at + Vector3(0, 0.2, 0)
	main.add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	ring.mesh = torus
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.no_depth_test = true
	look.albedo_color = RIPPLE_COLOR
	ring.material_override = look
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = at + Vector3(0, 0.05, 0)
	ring.scale = Vector3.ONE * RIPPLE_SIZE.x
	main.add_child(ring)
	var wide := RIPPLE_SIZE.y * (RIPPLE_WIDE if kind != Versus.Sound.STEP else 1.0)
	var tween := ring.create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector3.ONE * wide, RIPPLE_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(look, "albedo_color:a", 0.0, RIPPLE_TIME)
	tween.chain().tween_callback(ring.queue_free)


func _event(kind: int, a: float, b: float) -> void:
	match kind:
		Versus.Event.WARN:
			main.flip.next_forced_in = a
			main.warning_player.play()
			main.warning_label.visible = true
			if main.warning_overlay != null:
				main.warning_overlay.visible = true
		Versus.Event.FLIP:
			var world := clampi(int(a), main.WAKE, main.NIGHTMARE)
			main._apply_world(world)
			main.camera.environment = main._devil_sight()  # this world's fog, through its eyes
			main.flip_player.play()
			main.warning_label.visible = false
			if main.warning_overlay != null:
				main.warning_overlay.visible = false
			main._screen_flash(Color(main.SIGIL_COLORS[world], 0.6))
			main.flash_rect.create_tween().tween_property(main.flash_rect, "color:a", 0.0, 0.3)
		Versus.Event.BOX:
			var i := int(a)
			if i >= 0 and i < main.box_nodes.size() and not main.box_opened[i]:
				main.box_opened[i] = true
				main.box_nodes[i].open()
				if b == 0.0:
					main.box_nodes[i].puff()
		Versus.Event.KEY:
			var count := int(b)
			if count > main.sigils_collected and count <= main.layout.sigils.size():
				main.key_hud.fly_in(count - 1, main.get_viewport().get_visible_rect().size * 0.5)
				main.sigils_collected = count
				if count == main.layout.sigils.size():
					main.key_hud.all_found()
		Versus.Event.EXIT:
			enraged = true
			main.exit_open = true
			main._set_exit_look()
			main._flash_message("THEY HAVE EVERY KEY  ·  GUARD THE EXIT")
		Versus.Event.WAKE:
			awake = true
			main._show_message("")
			main.roar_player.play()
			main._flash_message("HUNT  ·  LISTEN FOR THEIR STEPS")
		Versus.Event.LUNGE:
			lunge_left = main.LUNGE_TIME
		Versus.Event.STUN:
			lunge_left = 0.0
			stun_left = a
		Versus.Event.SNAP:
			epoch += 1
			var body: CharacterBody3D = main.player
			body.global_position = Vector3(a, body.global_position.y, b)
			body.velocity = Vector3.ZERO
			main._flash_message("THE FLIP THREW YOU BACK")


## The referee's END: the round is over on this side too.
func _end(result: int, seconds: float) -> void:
	over = true
	_record(result, seconds)
	main.game_state = "won" if result == Versus.Result.CAUGHT else "lost"
	main._stop_tension_audio()
	_show_round()


# --- Both ----------------------------------------------------------------------------------------------------------

func _record(result: int, seconds: float) -> void:
	Versus.results.append({"host_ran": runner == Versus.host, "result": result, "seconds": seconds})
	RunState.log_event("versus", {"round": Versus.round_number, "runner": runner, "result": RESULT_NAMES[result],
			"time": seconds, "hard": Versus.hard})


## The other player is gone (the relay said so, or they went silent: a closed or hidden tab). The referee plays on
## against the AI; the Devil wins a round its runner fled.
func _peer_left() -> void:
	if peer_gone:
		return
	peer_gone = true
	Net.leave()  # the relay tells the other game, so a tab hidden past the limit comes back to a match that's over
	if over or not started:
		if _page == null:
			_show_round()
		_paint_status()
	elif runner:
		remote_devil = false
		main._flash_message("YOUR DEVIL FLED  ·  THE MAZE HUNTS YOU NOW")
	else:
		_end(Versus.Result.RUNNER_LEFT, snappedf(main.elapsed, 0.1))


## How long the other player may go quiet: seconds in a round, longer while a floor loads or a page shows.
func _silence_limit() -> float:
	return Versus.SILENT_LIMIT if started and not over else Versus.LOAD_LIMIT


## Back after standing still (a hidden browser tab stops the game loop) long enough that the other game may have called
## this one gone: this player left, and the round is over here too rather than played on as a ghost of the match. A
## PING_EVERY short of the limit, since the last thing sent may have gone out that much before the stop.
func _stood_still() -> bool:
	var now := _now()
	var still := maxf(now - _frame_at, 0.0)
	_frame_at = now
	if peer_gone or still <= _silence_limit() - Versus.PING_EVERY:
		return false
	away = true
	peer_gone = true
	Net.leave()
	if started and not over:
		_end(Versus.Result.RUNNER_LEFT if runner else Versus.Result.DEVIL_LEFT, snappedf(main.elapsed, 0.1))
		return true
	_next_button = null  # a page already up goes, NEXT with it: the match is over
	if _page != null:
		_page.queue_free()
		_page = null
	_show_round()
	return true


## The round's page: what happened from your side, then the next round (or, after round 2, the match and a rematch).
func _show_round() -> void:
	if _page != null:
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	main._show_message("")
	main.get_node("HUD").visible = false
	_page = ColorRect.new()
	_page.name = "VersusRound"
	_page.color = Color(0.0, 0.0, 0.0, 0.9)
	_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	main.get_node("Overlays").add_child(_page)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 20)
	_page.add_child(column)
	_add_label(column, _title(), 34, main.GOLD)
	var words := _add_label(column, _lines(), 19, MainMenu.BONE)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.custom_minimum_size.x = main.ENDING_WIDTH
	_status = _add_label(column, "", 16, Color(0.55, 0.7, 0.82, 0.9))
	if not peer_gone and started:
		_next_button = _add_button(column, "NEXT ROUND   [ENTER]" if Versus.round_number == 1 else "REMATCH   [ENTER]", _next_pressed)
		_next_button.grab_focus()
	var leave := _add_button(column, "LEAVE", _leave)
	if _next_button == null:
		leave.grab_focus()
	_paint_status()
	_page.modulate.a = 0.0
	_page.create_tween().tween_property(_page, "modulate:a", 1.0, 0.4)


func _title() -> String:
	if away:
		return "YOU WERE AWAY TOO LONG"
	if not started:
		return "%s LEFT" % Versus.peer()
	var last: Dictionary = Versus.results[-1] if not Versus.results.is_empty() else {"result": Versus.Result.RUNNER_LEFT, "seconds": 0.0}
	var time := _clock(last["seconds"])
	var result: int = last["result"]
	if runner:
		match result:
			Versus.Result.ESCAPED:
				return "YOU ESCAPED  ·  %s" % time
			Versus.Result.CAUGHT:
				return "IT CAUGHT YOU  ·  %s" % time
			Versus.Result.TIME:
				return "OUT OF TIME"
		return "%s LEFT" % Versus.peer()
	match result:
		Versus.Result.ESCAPED:
			return "THEY GOT OUT  ·  %s" % time
		Versus.Result.CAUGHT:
			return "YOU CAUGHT THEM  ·  %s" % time
		Versus.Result.TIME:
			return "THEIR CLOCK RAN OUT  ·  YOU WIN THE ROUND"
	return "THE RUNNER FLED  ·  YOU WIN"


func _lines() -> String:
	if away:
		return "Your game stood still (a hidden browser tab pauses it), so the other game called you gone. Make a new room from VERSUS on the dashboard."
	if peer_gone or not started:
		return "The match is over. Make a new room from VERSUS on the dashboard."
	if Versus.round_number == 1:
		return "Round 2 swaps you: %s, on a new maze. The better runner wins the match." % (
				"you are the Devil" if runner else "you run")
	var winner := Versus.winner(Versus.results)
	var mine := "host" if Versus.host else "guest"
	var head := "A DRAW." if winner == "draw" else ("YOU WIN THE MATCH." if winner == mine else "%s WINS THE MATCH." % Versus.peer())
	return "%s\nYou ran: %s.  %s ran: %s." % [head, _run_of(Versus.host), Versus.peer().capitalize(), _run_of(not Versus.host)]


## How the host's (or the guest's) run went, for the match line.
func _run_of(host_ran: bool) -> String:
	for played: Dictionary in Versus.results:
		if played["host_ran"] == host_ran:
			match played["result"]:
				Versus.Result.ESCAPED:
					return "escaped in %s" % _clock(played["seconds"])
				Versus.Result.CAUGHT:
					return "caught at %s" % _clock(played["seconds"])
				Versus.Result.TIME:
					return "out of time"
	return "-"


func _paint_status() -> void:
	if _status == null:
		return
	if peer_gone:
		_status.text = "" if away else "%s LEFT THE ROOM" % Versus.peer()
		if _next_button != null:
			_next_button.disabled = true
	elif _me_next:
		_status.text = "WAITING FOR %s" % Versus.peer()
	elif _peer_next:
		_status.text = "%s IS READY" % Versus.peer()


func _next_pressed() -> void:
	if _me_next or peer_gone:
		return
	_next_button.disabled = true
	_status.text = "..."
	Ads.midgame(_ready_for_next)  # between rounds, never during one


func _ready_for_next() -> void:
	if peer_gone or _leaving:
		return
	_me_next = true
	Net.send([Versus.NEXT, Versus.round_number])
	_paint_status()
	_maybe_next()


## The room's maker starts what comes next once both are ready: round 2, or a new match on a new seed.
func _maybe_next() -> void:
	_paint_status()
	if not (Versus.host and _me_next and _peer_next) or peer_gone:
		return
	if Versus.round_number == 1:
		Versus.round_number = 2
	else:
		Versus.match_seed = Versus.new_seed()
		Versus.round_number = 1
		Versus.results.clear()
	Net.send([Versus.START, Versus.match_seed, int(Versus.hard), Versus.round_number])
	_begin_next()


func _begin_next() -> void:
	_leaving = true
	Versus.dealt_at = _now()
	RunState.start_versus(Versus.round_seed())
	get_tree().reload_current_scene()


func _leave() -> void:
	_leaving = true
	Net.leave()
	main._to_menu()


func _unhandled_input(event: InputEvent) -> void:
	if _page != null and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_leave()


func _add_label(parent: Control, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", DeathScreen.ui_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _add_button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = true
	button.add_theme_font_override("font", DeathScreen.ui_font())
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", MainMenu.BONE)
	button.add_theme_color_override("font_focus_color", main.GOLD)
	button.add_theme_color_override("font_hover_color", main.GOLD)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(action)
	parent.add_child(button)
	return button


static func _clock(seconds: float) -> String:
	return "%d:%02d" % [floori(seconds / 60.0), floori(fmod(seconds, 60.0))]


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
