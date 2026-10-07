class_name MainMenu
extends Control
## Title dashboard. Key art (hellscape + additive demon apparition + flickering braziers) under fog,
## embers and lightning, with the hero on his own parallax layer. The left column is the real menu;
## the right side previews the planned meta game, and anything not built yet answers "coming soon".
## Focusing a play control wakes the demon, reddens the fog and turns the word FLIP upside down.
## Art lives in assets/images/menu/ (originals in src/, ignored by Godot); see PROMPTS.md there.

const GAME_SCENE := "res://scenes/main.tscn"
const ART := "res://assets/images/menu/"
const UI_FONT := "res://assets/fonts/ui.ttf"
const MUSIC := "res://assets/audio/sfx_ambient_calm.mp3"
const FLIP_SFX := "res://assets/audio/sfx_flip.mp3"
const MUSIC_DB := -14.0
const SILENT_DB := -40.0

# Motion: anything answering the player stays under 200 ms on a strong ease-out (Quint);
# only ambient motion (drift, fog, embers, the intro) is allowed to be slow.
const FOCUS_TIME := 0.18
const PRESS_TIME := 0.1
const PRESS_SCALE := 0.97
const HOVER_SCALE := 1.05
const FLIP_IN_TIME := 0.16
const FLIP_OUT_TIME := 0.3
const WORD_FLIP_TIME := 0.36
const STAGGER := 0.06
const IDLE_ALPHA := 0.88
const FOCUS_SHIFT := 10.0
const ICON_POP := 1.15
const CARD_RISE := 6.0
const CARD_ZOOM := 1.08
const ENTER_SLIDE := 48.0
const LOGO_SLAM := 1.6
const BLEED := 40.0
const PARALLAX_PX := 14.0
const PARALLAX_FOLLOW := 4.0
const HERO_DEPTH := 1.8  # the hero is closer than the key art, so he slides further
const HERO_BREATH := 1.012
const FLICKER_FOLLOW := 10.0
const INTRO_ZOOM := 1.12
const DRIFT_ZOOM := 1.04
const DRIFT_TIME := 26.0
const DEMON_ALPHA := Vector2(0.45, 0.75)
const DEMON_SWELL := 1.03
const DEMON_BREATH := 3.6
const THUNDER_EVERY := Vector2(6.0, 13.0)
const PRELOAD_AFTER := 1.0

# Layout, in the 1280x720 design space.
const VIEW := Vector2(1280, 720)
const MARGIN := 24.0
const LOGO_H := 118.0
const LOGO_SPLIT := 0.565  # x fraction of logo.png between FEAR and FLIP
const MENU_TOP := 146.0
const ROW_SIZE := Vector2(268, 66)
const ROW_GAP := 8
const RIGHT_W := 454.0
const QUEST_TOP := 72.0
const QUEST_SIZE := Vector2(376, 82)
const PLAY_TOP := 382.0
const PLAY_SIZE := Vector2(454, 151)
const CARD_TOP := 546.0
const CARD_SIZE := Vector2(146, 150)
const CARD_GAP := 8.0
const HERO_X := 300.0
const HERO_H := 500.0
const HERO_SINK := 14.0
# Spots on menu_bg.png, as fractions of the image.
const PORTAL := Vector2(0.715, 0.40)
const PORTAL_SIZE := Vector2(0.16, 0.3)
const BRAZIERS := [Vector2(0.335, 0.565), Vector2(0.383, 0.565), Vector2(0.522, 0.625),
		Vector2(0.815, 0.695), Vector2(0.888, 0.53), Vector2(0.972, 0.64)]
const BRAZIER_SIZE := Vector2(0.06, 0.1)
const DEMON_AT := Vector2(0.56, 0.14)
const DEMON_SIZE := Vector2(0.38, 0.47)

const ICON_CELL := 160
const ICON_COLUMNS := 4
enum Icon { MAZE, HELMET, DEMON, CHART, GEAR, CHEST, TARGET, STAR, CROWN, MAIL, COIN, GEM }

const BONE := Color(0.92, 0.88, 0.82)
const BLOOD := Color(0.95, 0.2, 0.15)
const DIM := Color(0.7, 0.68, 0.7)
const GOLD := Color(1.0, 0.76, 0.28)
const EMBER := Color(1.0, 0.42, 0.12)
const PANEL_FILL := Color(0.05, 0.03, 0.06, 0.8)
const PANEL_BORDER := Color(0.45, 0.3, 0.25)
const FOG_CALM := Color(0.5, 0.18, 0.42, 0.16)
const FOG_AWAKE := Color(0.7, 0.08, 0.05, 0.26)
const DEMON_AWAKE := Color(1.6, 1.4, 1.4)
const DEMON_STRUCK := Color(2.4, 2.2, 2.4)
const LIGHTNING := Color(0.55, 0.45, 1.0, 0.22)
const CARDS := [
	["CLASSIC", "STANDARD MAZE", "card_classic", Color(1.0, 0.75, 0.3)],
	["TIME TRIAL", "BEAT THE CLOCK", "card_time_trial", Color(0.35, 0.7, 1.0)],
	["MULTIPLAYER", "PLAY WITH FRIENDS", "card_multiplayer", Color(0.75, 0.4, 1.0)],
]

# The act picker (plans/06 P1). Art is optional: act_N.png / act_locked.png in ART, see PROMPTS.md.
const ACT_CARD_SIZE := Vector2(200, 290)
const ACT_CARD_GAP := 14
const LOCK_SIZE := Vector2(110, 110)
const LOCKED_TINT := Color(0.35, 0.33, 0.38)
const ROMAN: Array[String] = ["I", "II", "III", "IV", "V"]
## One colour per act (cold, blood, violet, ember, crimson): the card's border, numeral and art stand-in.
const ACT_TINTS: Array[Color] = [Color(0.35, 0.6, 1.0), Color(0.95, 0.2, 0.15), Color(0.65, 0.35, 1.0),
		Color(1.0, 0.5, 0.15), Color(0.8, 0.05, 0.1)]

const HOW_TO := [
	["WASD  ·  MOUSE", "Move and look. Shift sprints, F toggles the flashlight."],
	["E  /  SPACE", "Flip between WAKE and NIGHTMARE. Each world has its own walls."],
	["FLIPPING TIME", "Sometimes the Nightmare takes you on its own, and your controls invert."],
	["KEYS", "Find every key, then open the chest. Some keys only exist in the Nightmare."],
	["THE DEVIL", "Slower in WAKE and slower up close. Flip to lose it, or stand in a safe circle."],
	["THE DESCENT", "Five acts of ten floors. Escape floor 10, the Gate, to open the next act. Dying restarts the act."],
	["ESC  ·  R R", "Pause. Press R twice to restart the act on a new maze."],
]

const ATMOS_SHADER := """
shader_type canvas_item;
uniform sampler2D noise : repeat_enable, filter_linear;
uniform vec4 fog_color : source_color;
uniform float vignette = 0.7;
uniform float grain = 0.035;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 drift = vec2(TIME * 0.012, TIME * 0.004);
	float fog = texture(noise, UV * vec2(1.4, 0.8) + drift).r * texture(noise, UV * 0.6 - drift * 1.7).r;
	fog *= smoothstep(0.1, 1.0, UV.y);
	float v = smoothstep(0.4, 1.05, distance(UV, vec2(0.5)) * 1.2) * vignette;
	float a = clamp(fog * fog_color.a * 3.0, 0.0, 1.0);
	vec3 col = mix(fog_color.rgb, vec3(0.0), v);
	a += v * (1.0 - a);
	col = mix(col, vec3(hash(floor(FRAGCOORD.xy * 0.5) + floor(TIME * 24.0) * 7.0)), grain);
	a += grain * (1.0 - a);
	COLOR = vec4(col, a);
}
"""

## A light band sweeping across the big PLAY button every couple of seconds.
const SWEEP_SHADER := """
shader_type canvas_item;
uniform float speed = 0.4;
uniform float strength = 0.5;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float t = fract(TIME * speed) * 2.6 - 0.8;
	float band = 1.0 - smoothstep(0.0, 0.07, abs(UV.x + UV.y * 0.3 - t));
	c.rgb += band * strength * c.a;
	COLOR = c * COLOR;
}
"""

var _body: Font
var _display: Font
var _additive: CanvasItemMaterial
var _frame: Texture2D
var _frame_active: Texture2D
var _icons: Texture2D
var _stage: Control
var _demon: TextureRect
var _portal: TextureRect
var _glows: Array[TextureRect] = []
var _hero: TextureRect
var _hero_rise := 0.0
var _flash: ColorRect
var _atmos: ShaderMaterial
var _logo: Control
var _flip_word: TextureRect
var _menu: VBoxContainer
var _how_row: Button
var _quit: Button
var _right: Control
var _top_bar: HBoxContainer
var _quests: Array[Control] = []
var _play: Button
var _cards: Array[Button] = []
var _toast: Label
var _how_to: Control
var _how_box: Control
var _how_back: Button
var _acts: Control
var _fade: ColorRect
var _music: AudioStreamPlayer
var _flip_sfx: AudioStreamPlayer
var _thunder: Timer
var _world_tween: Tween
var _parallax := Vector2.ZERO
var _nightmare_on := false
var _leaving := false


func _ready() -> void:
	RunState.load_save()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_body = _base_font()
	_display = _tracked(_body, 1)
	_additive = CanvasItemMaterial.new()
	_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_frame = load(ART + "ui_frame.png")
	_frame_active = load(ART + "ui_frame_active.png")
	_icons = load(ART + "ui_icons.png")
	_build_stage()
	_build_column()
	_build_right()
	_build_toast()
	_build_how_to()
	_build_acts()
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)
	_build_audio()
	_intro()


func _process(delta: float) -> void:
	# Decorative parallax trails the mouse with exponential smoothing, so it has weight, not a hard lock.
	var target := (get_local_mouse_position() / size - Vector2(0.5, 0.5)) * -2.0 * PARALLAX_PX
	_parallax = _parallax.lerp(target, 1.0 - exp(-PARALLAX_FOLLOW * delta))
	_stage.position = Vector2(-BLEED, -BLEED) + _parallax
	_hero.position = Vector2(HERO_X, size.y - HERO_H + HERO_SINK + _hero_rise) + _parallax * HERO_DEPTH
	var flicker := 1.0 - exp(-FLICKER_FOLLOW * delta)
	for glow in _glows:
		glow.modulate.a = lerpf(glow.modulate.a, randf_range(0.45, 1.0), flicker)
	_portal.modulate.a = 0.75 + 0.2 * sin(Time.get_ticks_msec() * 0.0017)


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if _how_to.visible or _acts.visible:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
			if _how_to.visible:
				_close_how_to()
			else:
				_close_acts()
			accept_event()
		return
	# Nothing is focused until asked (so the demon doesn't wake on load); the first nav key lands on top.
	if get_viewport().gui_get_focus_owner() == null and (event.is_action_pressed("ui_down")
			or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_accept")):
		(_menu.get_child(0) as Control).grab_focus()
		accept_event()


# --- Flow -------------------------------------------------------------------------------------

## One tap (plans/06 G1): resume the run in progress, else start the highest act unlocked.
func _play_now() -> void:
	if _leaving:
		return
	if not RunState.has_progress():
		RunState.start_run(MetaState.acts_unlocked)
	_start()


## Picking an act starts a fresh run there (abandoning any run in progress).
func _pick_act(act: int) -> void:
	if not _leaving and RunState.start_run(act):
		_start()


## Into the maze with whatever run RunState holds.
func _start() -> void:
	if _leaving:
		return
	_leaving = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	_thunder.stop()
	_flip_sfx.play()
	_set_nightmare(true)
	_shake(10.0, 0.35)
	_flash.color = Color(BLOOD, 0.0)
	var hit := _retarget(_flash).set_parallel(false)
	hit.tween_property(_flash, "color:a", 0.45, 0.05)
	hit.tween_property(_flash, "color:a", 0.0, 0.5)
	if ResourceLoader.load_threaded_get_status(GAME_SCENE) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(GAME_SCENE)
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_fade, "color:a", 1.0, 0.5).set_delay(0.2)
	tween.tween_property(_music, "volume_db", SILENT_DB, 0.7)
	await tween.finished
	get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(GAME_SCENE) as PackedScene)


## The picker is the second step before abandoning a run: nothing is lost until an act is picked.
func _open_acts() -> void:
	_acts.visible = true
	_acts.modulate.a = 0.0
	_retarget(_acts).tween_property(_acts, "modulate:a", 1.0, 0.2)
	var act := RunState.act() if RunState.has_progress() else MetaState.acts_unlocked
	(_acts.find_child("Act%d" % act, true, false) as Control).grab_focus()


func _close_acts() -> void:
	var tween := _retarget(_acts)
	tween.tween_property(_acts, "modulate:a", 0.0, 0.14)
	tween.chain().tween_callback(_acts.hide)
	(_menu.get_node("NewRun") as Control).grab_focus()


func _soon(what: String) -> void:
	_toast.text = "%s  ·  COMING SOON" % what
	var tween := _retarget(_toast).set_parallel(false)
	tween.tween_property(_toast, "modulate:a", 1.0, 0.15)
	tween.tween_interval(1.4)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.4)


func _open_how_to() -> void:
	_how_box.pivot_offset = _how_box.size * 0.5
	_how_to.visible = true
	_how_to.modulate.a = 0.0
	_how_box.scale = Vector2.ONE * PRESS_SCALE
	var tween := _retarget(_how_to)
	tween.tween_property(_how_to, "modulate:a", 1.0, 0.2)
	tween.tween_property(_how_box, "scale", Vector2.ONE, 0.2)
	_how_back.grab_focus()


func _close_how_to() -> void:
	var tween := _retarget(_how_to)
	tween.tween_property(_how_to, "modulate:a", 0.0, 0.14)
	tween.chain().tween_callback(_how_to.hide)
	_how_row.grab_focus()


# --- Motion -----------------------------------------------------------------------------------

## First impression (once per launch, so it may take its time): the camera settles out of a push-in,
## the hero rises, the logo slams down and shakes the screen, then both sides cascade in.
func _intro() -> void:
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(_fade, "color:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_music, "volume_db", MUSIC_DB, 2.0)
	_stage.scale = Vector2.ONE * INTRO_ZOOM
	tween.tween_property(_stage, "scale", Vector2.ONE, 2.6).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(_drift).set_delay(2.6)
	_hero_rise = ENTER_SLIDE
	_hero.modulate.a = 0.0
	tween.tween_property(self, "_hero_rise", 0.0, 1.4).set_delay(0.2).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(_hero, "modulate:a", 1.0, 0.8).set_delay(0.2)

	_logo.scale = Vector2.ONE * LOGO_SLAM
	_logo.modulate.a = 0.0
	tween.tween_property(_logo, "modulate:a", 1.0, 0.2).set_delay(0.45)
	tween.tween_property(_logo, "scale", Vector2.ONE, 0.32).set_delay(0.45).set_ease(Tween.EASE_IN)
	tween.tween_callback(_shake.bind(7.0, 0.3)).set_delay(0.77)

	var delay := 0.8
	for row: Control in _menu.get_children():
		var content: Control = row.get_node("Content")
		row.modulate.a = 0.0
		tween.tween_property(row, "modulate:a", 1.0, 0.4).set_delay(delay)
		tween.tween_property(content, "position:x", 0.0, 0.5).from(-ENTER_SLIDE).set_delay(delay)
		delay += STAGGER
	if _quit:
		_quit.modulate.a = 0.0
		tween.tween_property(_quit, "modulate:a", 1.0, 0.4).set_delay(delay)

	delay = 0.9
	for node: Control in [_top_bar] + _quests:
		node.modulate.a = 0.0
		tween.tween_property(node, "modulate:a", 1.0, 0.4).set_delay(delay)
		tween.tween_property(node, "position:x", node.position.x, 0.5).from(node.position.x + ENTER_SLIDE).set_delay(delay)
		delay += STAGGER
	_play.modulate.a = 0.0
	tween.tween_property(_play, "modulate:a", 1.0, 0.3).set_delay(delay)
	tween.tween_property(_play, "scale", Vector2.ONE, 0.6).from(Vector2.ONE * 0.7).set_delay(delay).set_trans(Tween.TRANS_BACK)
	delay += STAGGER * 2.0
	for card in _cards:
		card.modulate.a = 0.0
		tween.tween_property(card, "modulate:a", 1.0, 0.4).set_delay(delay)
		tween.tween_property(card, "position:y", card.position.y, 0.5).from(card.position.y + ENTER_SLIDE).set_delay(delay)
		delay += STAGGER

	_flip_word.scale.y = -1.0
	tween.tween_property(_flip_word, "scale:y", 1.0, 0.5).set_delay(delay + 0.2).set_trans(Tween.TRANS_BACK)
	# The floor's GLBs are heavy: start loading them while the player is still reading the menu.
	tween.tween_callback(func() -> void: ResourceLoader.load_threaded_request(GAME_SCENE)).set_delay(PRELOAD_AFTER)
	_thunder.start(THUNDER_EVERY.x)


func _drift() -> void:
	var drift := _stage.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	drift.tween_property(_stage, "scale", Vector2.ONE * DRIFT_ZOOM, DRIFT_TIME)
	drift.tween_property(_stage, "scale", Vector2.ONE, DRIFT_TIME)


## The signature beat: the demon wakes under any play control. Fast in (the game answering), slower out.
func _set_nightmare(on: bool) -> void:
	if _leaving and not on:
		return
	_nightmare_on = on
	if _world_tween:
		_world_tween.kill()
	var time := FLIP_IN_TIME if on else FLIP_OUT_TIME
	_world_tween = create_tween().set_parallel().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_world_tween.tween_property(_atmos, "shader_parameter/fog_color", FOG_AWAKE if on else FOG_CALM, time)
	_world_tween.tween_property(_demon, "modulate", DEMON_AWAKE if on else Color.WHITE, time)
	_world_tween.tween_property(_flip_word, "scale:y", -1.0 if on else 1.0, WORD_FLIP_TIME).set_trans(Tween.TRANS_BACK)


## Lightning: a double flicker that lights the demon up. Gentle (low alpha, >= 6 s apart), not a strobe.
func _on_thunder() -> void:
	_thunder.start(randf_range(THUNDER_EVERY.x, THUNDER_EVERY.y))
	if _nightmare_on or _how_to.visible or _acts.visible or _leaving:
		return
	_flash.color = Color(LIGHTNING, 0.0)
	var flash := _retarget(_flash).set_parallel(false)
	flash.tween_property(_flash, "color:a", LIGHTNING.a, 0.04)
	flash.tween_property(_flash, "color:a", 0.04, 0.06)
	flash.tween_property(_flash, "color:a", LIGHTNING.a * 0.7, 0.04)
	flash.tween_property(_flash, "color:a", 0.0, 0.6)
	var demon := _retarget(_demon).set_parallel(false)
	demon.tween_property(_demon, "modulate", DEMON_STRUCK, 0.05)
	demon.tween_property(_demon, "modulate", Color.WHITE, 0.9)


func _shake(strength: float, time: float) -> void:
	const STEPS := 6
	var tween := _retarget(self).set_parallel(false)
	for i in STEPS:
		var jolt := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength * (1.0 - float(i) / STEPS)
		tween.tween_property(self, "position", jolt, time / (STEPS + 1))
	tween.tween_property(self, "position", Vector2.ZERO, time / (STEPS + 1))


func _highlight(content: Control, on: bool) -> void:
	var icon: Control = content.get_node("Icon")
	var tween := _retarget(content)
	tween.tween_property(content, "position:x", FOCUS_SHIFT if on else 0.0, FOCUS_TIME)
	tween.tween_property(content, "modulate:a", 1.0 if on else IDLE_ALPHA, FOCUS_TIME)
	tween.tween_property(icon, "scale", Vector2.ONE * (ICON_POP if on else 1.0), FOCUS_TIME)
	tween.tween_property(content.get_node("Title"), "theme_override_colors/font_color", Color.WHITE if on else BONE, FOCUS_TIME)
	if not content.has_meta("primary"):
		tween.tween_property(content.get_node("Active"), "modulate:a", 1.0 if on else 0.0, FOCUS_TIME)
	if on:
		var wiggle := _retarget(icon).set_parallel(false)
		for angle: float in [-0.2, 0.15, -0.07, 0.0]:
			wiggle.tween_property(icon, "rotation", angle, 0.07)


func _card_highlight(content: Control, on: bool) -> void:
	var tween := _retarget(content)
	tween.tween_property(content, "position:y", -CARD_RISE if on else 0.0, FOCUS_TIME)
	tween.tween_property(content.get_node("Border"), "modulate", Color(1.8, 1.8, 1.8) if on else Color.WHITE, FOCUS_TIME)
	tween.tween_property(content.get_node("Art"), "scale", Vector2.ONE * (CARD_ZOOM if on else 1.0), 0.4)


func _grow(node: Control, on: bool) -> void:
	_retarget(node).tween_property(node, "scale", Vector2.ONE * (HOVER_SCALE if on else 1.0), FOCUS_TIME)


func _press(node: Control, down: bool) -> void:
	var tween := node.create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2.ONE * (PRESS_SCALE if down else 1.0), PRESS_TIME)


## One live tween per node: a new state retargets from wherever the last one left off.
func _retarget(node: Node) -> Tween:
	if node.has_meta("tween"):
		(node.get_meta("tween") as Tween).kill()
	var tween := node.create_tween().set_parallel().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	node.set_meta("tween", tween)
	return tween


# --- Build: world -----------------------------------------------------------------------------

## Key art on an oversized, slowly drifting stage. The AspectRatioContainer gives the art its own
## aspect, so glows and the demon can be pinned to spots on the image as fractions.
func _build_stage() -> void:
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.offset_left = -BLEED
	_stage.offset_top = -BLEED
	_stage.offset_right = BLEED
	_stage.offset_bottom = BLEED
	_stage.resized.connect(func() -> void: _stage.pivot_offset = _stage.size * 0.5)
	add_child(_stage)
	var bg: Texture2D = load(ART + "menu_bg.png")
	var fit := AspectRatioContainer.new()
	fit.ratio = float(bg.get_width()) / bg.get_height()
	fit.stretch_mode = AspectRatioContainer.STRETCH_COVER
	fit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fit.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(fit)
	var art := Control.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fit.add_child(art)
	_image(art, bg, TextureRect.STRETCH_SCALE, true)
	var glow := _glow_texture(EMBER, 64)
	_portal = _pin(art, glow, PORTAL, PORTAL_SIZE)
	for spot: Vector2 in BRAZIERS:
		_glows.append(_pin(art, glow, spot, BRAZIER_SIZE))
	# Painted on black, added onto the sky: black vanishes and the demon reads as an apparition.
	_demon = _pin(art, load(ART + "menu_demon.png"), DEMON_AT, DEMON_SIZE)
	_demon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_demon.resized.connect(func() -> void: _demon.pivot_offset = _demon.size * 0.5)
	_demon.self_modulate.a = DEMON_ALPHA.x
	var breath := _demon.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breath.tween_property(_demon, "self_modulate:a", DEMON_ALPHA.y, DEMON_BREATH)
	breath.parallel().tween_property(_demon, "scale", Vector2.ONE * DEMON_SWELL, DEMON_BREATH)
	breath.tween_property(_demon, "self_modulate:a", DEMON_ALPHA.x, DEMON_BREATH)
	breath.parallel().tween_property(_demon, "scale", Vector2.ONE, DEMON_BREATH)

	var shade_texture := _gradient(Color(0, 0, 0, 0.8), Color(0, 0, 0, 0), Vector2(1, 0))
	shade_texture.gradient.set_offset(1, 0.45)
	_image(self, shade_texture, TextureRect.STRETCH_SCALE, true)

	_flash = ColorRect.new()
	_flash.color = Color(LIGHTNING, 0.0)
	_flash.material = _additive
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_flash)

	var hero: Texture2D = load(ART + "menu_hero.png")
	_hero = _image(self, hero, TextureRect.STRETCH_KEEP_ASPECT)
	_hero.size = Vector2(HERO_H * hero.get_width() / hero.get_height(), HERO_H)
	_hero.pivot_offset = Vector2(_hero.size.x * 0.5, _hero.size.y)
	var stance := _hero.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	stance.tween_property(_hero, "scale:y", HERO_BREATH, 2.4)
	stance.tween_property(_hero, "scale:y", 1.0, 2.4)

	var embers := CPUParticles2D.new()
	embers.amount = 70
	embers.lifetime = 7.0
	embers.preprocess = 7.0
	embers.texture = _glow_texture(Color.WHITE, 16)
	embers.material = _additive
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(VIEW.x * 0.55, 20)
	embers.position = Vector2(VIEW.x * 0.5, VIEW.y + 20)
	embers.direction = Vector2.UP
	embers.spread = 18.0
	embers.gravity = Vector2(0, -12)
	embers.initial_velocity_min = 18.0
	embers.initial_velocity_max = 55.0
	embers.scale_amount_min = 0.3
	embers.scale_amount_max = 1.1
	var ramp := Gradient.new()
	ramp.set_color(0, Color(EMBER, 0.0))
	ramp.set_color(1, Color(BLOOD, 0.0))
	ramp.add_point(0.15, Color(1.0, 0.6, 0.25))
	embers.color_ramp = ramp
	add_child(embers)

	var noise := NoiseTexture2D.new()
	noise.seamless = true
	noise.width = 512
	noise.height = 512
	var fast := FastNoiseLite.new()
	fast.frequency = 0.008
	noise.noise = fast
	var shader := Shader.new()
	shader.code = ATMOS_SHADER
	_atmos = ShaderMaterial.new()
	_atmos.shader = shader
	_atmos.set_shader_parameter("noise", noise)
	_atmos.set_shader_parameter("fog_color", FOG_CALM)
	var atmos := ColorRect.new()
	atmos.material = _atmos
	atmos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	atmos.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(atmos)


## An additive sprite centred on a spot of the key art, sized as a fraction of it.
func _pin(art: Control, texture: Texture2D, center: Vector2, extent: Vector2) -> TextureRect:
	var rect := _image(art, texture, TextureRect.STRETCH_SCALE)
	rect.material = _additive
	# Far sides first: a near anchor set past its opposite one doesn't stick.
	rect.set_anchor_and_offset(SIDE_RIGHT, center.x + extent.x * 0.5, 0.0)
	rect.set_anchor_and_offset(SIDE_BOTTOM, center.y + extent.y * 0.5, 0.0)
	rect.set_anchor_and_offset(SIDE_LEFT, center.x - extent.x * 0.5, 0.0)
	rect.set_anchor_and_offset(SIDE_TOP, center.y - extent.y * 0.5, 0.0)
	return rect


# --- Build: left column -----------------------------------------------------------------------

func _build_column() -> void:
	_logo = _build_logo()
	_menu = VBoxContainer.new()
	_menu.position = Vector2(MARGIN, MENU_TOP)
	_menu.add_theme_constant_override("separation", ROW_GAP)
	add_child(_menu)
	if RunState.has_progress():
		var rule := StageRule.for_floor(RunState.current_floor)
		_row("CONTINUE", "FLOOR %d / %d  ·  %s" % [rule.floor_in_act, StageRule.FLOORS_PER_ACT, rule.act_name.to_upper()],
				Icon.MAZE, _start, true)
	else:
		var top := MetaState.acts_unlocked
		_row("PLAY", "ACT %d  ·  %s" % [top, StageRule.ACT_NAMES[top - 1].to_upper()], Icon.MAZE, _play_now, true)
	if RunState.has_progress() or MetaState.acts_unlocked > 1:
		_row("NEW RUN", "CHOOSE YOUR ACT", Icon.TARGET, _open_acts)
	_row("CHARACTER", "SKINS & GEAR", Icon.HELMET, _soon.bind("CHARACTER"))
	_how_row = _row("THE DEVIL", "HOW TO SURVIVE", Icon.DEMON, _open_how_to)
	_row("PROGRESSION", "BEST FLOOR %d / %d" % [RunState.best_floor, StageRule.LAST_FLOOR], Icon.CHART,
			_soon.bind("ACHIEVEMENTS"))
	_row("SETTINGS", "AUDIO, CONTROLS", Icon.GEAR, _soon.bind("SETTINGS"))
	_row("SHOP", "SKINS, EFFECTS", Icon.CHEST, _soon.bind("SHOP"))
	if not OS.has_feature("web"):
		_quit = _text_button(self, "QUIT", 14)
		_quit.position = Vector2(MARGIN + 4, VIEW.y - 40)
		_quit.pressed.connect(get_tree().quit)


## logo.png split in two at the gap, so FLIP can turn over on its own.
func _build_logo() -> Control:
	var texture: Texture2D = load(ART + "logo.png")
	var logo := Control.new()
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.size = Vector2(LOGO_H * texture.get_width() / texture.get_height(), LOGO_H)
	logo.position = Vector2(MARGIN - 6, 14)
	logo.pivot_offset = logo.size * 0.5
	add_child(logo)
	var split := roundf(texture.get_width() * LOGO_SPLIT)
	var fear := _image(logo, _atlas(texture, Rect2(0, 0, split, texture.get_height())), TextureRect.STRETCH_SCALE)
	fear.size = Vector2(logo.size.x * LOGO_SPLIT, LOGO_H)
	_flip_word = _image(logo, _atlas(texture, Rect2(split, 0, texture.get_width() - split, texture.get_height())),
			TextureRect.STRETCH_SCALE)
	_flip_word.position.x = fear.size.x
	_flip_word.size = Vector2(logo.size.x - fear.size.x, LOGO_H)
	_flip_word.pivot_offset = _flip_word.size * 0.5
	return logo


## A menu entry: a flat Button (focus + clicks) holding free-placed content we can slide and tint.
## The primary row (play) always wears the hot frame and lets it pulse.
func _row(title: String, sub: String, icon: Icon, action: Callable, primary := false) -> Button:
	var row := Button.new()
	row.name = title.to_pascal_case()
	row.flat = true
	row.custom_minimum_size = ROW_SIZE
	_menu.add_child(row)
	var content := _holder(row, "Content")
	content.modulate.a = IDLE_ALPHA
	content.pivot_offset = Vector2(0, ROW_SIZE.y * 0.5)  # press scales from the left edge
	_image(content, _frame, TextureRect.STRETCH_SCALE, true)
	var active := _image(content, _frame_active, TextureRect.STRETCH_SCALE, true)
	active.name = "Active"
	active.modulate.a = 0.0
	if primary:
		content.set_meta("primary", true)
		var pulse := active.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(active, "modulate:a", 1.0, 0.9)
		pulse.tween_property(active, "modulate:a", 0.6, 0.9)
	var glyph := _image(content, _icon(icon), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	glyph.name = "Icon"
	glyph.position = Vector2(20, 10)
	glyph.size = Vector2(46, 46)
	glyph.pivot_offset = glyph.size * 0.5
	var big := _label(content, title, 22, BONE)
	big.name = "Title"
	big.position = Vector2(74, 9)
	var small := _label(content, sub, 11, DIM)
	small.name = "Sub"
	small.position = Vector2(75, 38)
	row.pressed.connect(action)
	_hoverable(row)
	row.focus_entered.connect(_highlight.bind(content, true))
	row.focus_exited.connect(_highlight.bind(content, false))
	row.button_down.connect(_press.bind(content, true))
	row.button_up.connect(_press.bind(content, false))
	if primary:
		row.focus_entered.connect(_set_nightmare.bind(true))
		row.focus_exited.connect(_set_nightmare.bind(false))
	return row


# --- Build: right side ------------------------------------------------------------------------

func _build_right() -> void:
	_right = Control.new()
	_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_right.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_right.offset_left = -RIGHT_W - MARGIN
	_right.offset_right = -MARGIN
	add_child(_right)

	_top_bar = HBoxContainer.new()
	_top_bar.alignment = BoxContainer.ALIGNMENT_END
	_top_bar.add_theme_constant_override("separation", 8)
	_top_bar.position = Vector2(0, 14)
	_top_bar.size = Vector2(RIGHT_W, 46)
	_right.add_child(_top_bar)
	_pill(Icon.COIN)
	_pill(Icon.GEM)
	_icon_button(Icon.CROWN, "PREMIUM")
	_icon_button(Icon.MAIL, "INBOX")
	_icon_button(Icon.GEAR, "SETTINGS")

	_quest(QUEST_TOP, "DAILY CHALLENGE", 5, Icon.TARGET)
	_quest(QUEST_TOP + QUEST_SIZE.y + 10, "NEXT REWARD", 10, Icon.STAR)
	_build_play()
	for i in CARDS.size():
		_card(i)


## No economy yet: the counters read 0 and "+" says so.
func _pill(icon: Icon) -> void:
	var pill := PanelContainer.new()
	var style := _panel_style(PANEL_BORDER, 1)
	style.content_margin_left = 8
	style.content_margin_right = 4
	pill.add_theme_stylebox_override("panel", style)
	_top_bar.add_child(pill)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	pill.add_child(row)
	_image(row, _icon(icon), TextureRect.STRETCH_KEEP_ASPECT_CENTERED).custom_minimum_size = Vector2(30, 30)
	var amount := _label(row, "0", 18, BONE)
	amount.custom_minimum_size.x = 44
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text_button(row, "+", 22).pressed.connect(_soon.bind("SHOP"))


func _icon_button(icon: Icon, what: String) -> void:
	var button := Button.new()
	button.icon = _icon(icon)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(46, 46)
	button.add_theme_stylebox_override("normal", _panel_style(PANEL_BORDER, 1))
	button.add_theme_stylebox_override("hover", _panel_style(PANEL_BORDER, 1))
	button.add_theme_stylebox_override("pressed", _panel_style(BLOOD, 2, PANEL_FILL.darkened(0.5)))
	button.pressed.connect(_soon.bind(what))
	_top_bar.add_child(button)
	_hoverable(button)
	button.add_theme_stylebox_override("focus", _panel_style(BLOOD, 2, Color.TRANSPARENT))


## A goal card. Progress is the best floor reached; there are no rewards to claim yet.
func _quest(y: float, title: String, goal: int, icon: Icon) -> void:
	var panel := Control.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = Vector2(RIGHT_W - QUEST_SIZE.x, y)
	panel.size = QUEST_SIZE
	_right.add_child(panel)
	_quests.append(panel)
	_image(panel, _frame, TextureRect.STRETCH_SCALE, true)
	_place(_image(panel, _icon(icon), TextureRect.STRETCH_KEEP_ASPECT_CENTERED), Vector2(22, 15), Vector2(52, 52))
	_label(panel, title, 17, BONE).position = Vector2(86, 11)
	_label(panel, "REACH FLOOR %d" % goal, 11, DIM).position = Vector2(87, 34)
	var done := mini(RunState.best_floor, goal)
	var bar := ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	bar.max_value = goal
	bar.value = done
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0, 0, 0, 0.6)
	track.set_corner_radius_all(3)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = GOLD
	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", fill)
	panel.add_child(bar)
	_place(bar, Vector2(87, 56), Vector2(166, 7))
	_label(panel, "%d/%d" % [done, goal], 11, BONE).position = Vector2(260, 50)
	_place(_image(panel, _icon(Icon.CHEST), TextureRect.STRETCH_KEEP_ASPECT_CENTERED), Vector2(304, 15), Vector2(52, 52))


func _build_play() -> void:
	_play = Button.new()
	_play.name = "BigPlay"
	_play.flat = true
	_right.add_child(_play)
	_place(_play, Vector2(0, PLAY_TOP), PLAY_SIZE)
	_play.pivot_offset = PLAY_SIZE * 0.5
	var content := _holder(_play, "Content")
	content.pivot_offset = PLAY_SIZE * 0.5
	var art := _image(content, load(ART + "ui_play_button.png"), TextureRect.STRETCH_SCALE, true)
	var sweep := ShaderMaterial.new()
	sweep.shader = Shader.new()
	sweep.shader.code = SWEEP_SHADER
	art.material = sweep

	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 16)
	line.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(line)
	var arrow := Control.new()
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.custom_minimum_size = Vector2(30, 36)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(arrow)
	var triangle := Polygon2D.new()
	triangle.polygon = PackedVector2Array([Vector2(0, 0), Vector2(30, 18), Vector2(0, 36)])
	triangle.color = Color.WHITE
	arrow.add_child(triangle)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.add_theme_constant_override("separation", -8)
	line.add_child(words)
	_label(words, "PLAY", 54, Color.WHITE)
	_label(words, "ENTER THE MAZE", 13, BONE, _tracked(_body, 3)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# A heartbeat: two quick swells, then rest.
	var beat := content.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	for step: Vector2 in [Vector2(1.04, 0.11), Vector2(1.0, 0.13), Vector2(1.025, 0.1), Vector2(1.0, 0.22)]:
		beat.tween_property(content, "scale", Vector2.ONE * step.x, step.y)
	beat.tween_interval(0.9)

	_hoverable(_play)
	_play.pressed.connect(_play_now)
	_play.focus_entered.connect(_grow.bind(_play, true))
	_play.focus_exited.connect(_grow.bind(_play, false))
	_play.focus_entered.connect(_set_nightmare.bind(true))
	_play.focus_exited.connect(_set_nightmare.bind(false))
	_play.button_down.connect(_press.bind(_play, true))
	_play.button_up.connect(_grow.bind(_play, true))


func _card(index: int) -> void:
	var info: Array = CARDS[index]
	var title: String = info[0]
	var tint: Color = info[3]
	var card := Button.new()
	card.name = title.to_pascal_case()
	card.flat = true
	_right.add_child(card)
	_place(card, Vector2(index * (CARD_SIZE.x + CARD_GAP), CARD_TOP), CARD_SIZE)
	_cards.append(card)
	var content := _holder(card, "Content")
	content.clip_contents = true
	var art := _image(content, load(ART + info[2] + ".png"), TextureRect.STRETCH_KEEP_ASPECT_COVERED, true)
	art.name = "Art"
	art.pivot_offset = CARD_SIZE * 0.5
	var shade_texture := _gradient(Color(0, 0, 0, 0), Color(0, 0, 0, 0.92), Vector2(0, 1))
	shade_texture.gradient.set_offset(0, 0.35)
	_image(content, shade_texture, TextureRect.STRETCH_SCALE, true)
	var border := Panel.new()
	border.name = "Border"
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var outline := _panel_style(tint.darkened(0.25), 2, Color.TRANSPARENT)
	outline.set_corner_radius_all(6)
	border.add_theme_stylebox_override("panel", outline)
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(border)
	for text: Array in [[title, 17, Color.WHITE, CARD_SIZE.y - 46], [info[1], 10, BONE, CARD_SIZE.y - 24]]:
		var label := _label(content, text[0], text[1], text[2])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_place(label, Vector2(0, text[3]), Vector2(CARD_SIZE.x, 0))
	if index == 0:
		card.pressed.connect(_play_now)
		card.focus_entered.connect(_set_nightmare.bind(true))
		card.focus_exited.connect(_set_nightmare.bind(false))
	else:
		card.pressed.connect(_soon.bind(title))
		var tag := _label(content, "SOON", 10, Color.WHITE)
		var badge := _panel_style(BLOOD, 0, BLOOD)
		badge.set_content_margin_all(2)
		badge.content_margin_left = 6
		badge.content_margin_right = 6
		tag.add_theme_stylebox_override("normal", badge)
		tag.position = Vector2(CARD_SIZE.x - 46, 8)
	_hoverable(card)
	card.focus_entered.connect(_card_highlight.bind(content, true))
	card.focus_exited.connect(_card_highlight.bind(content, false))


func _build_toast() -> void:
	_toast = _label(self, "", 16, BLOOD)
	_toast.modulate.a = 0.0
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 30)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _build_how_to() -> void:
	var box := _modal("HOW TO SURVIVE")
	box.custom_minimum_size = Vector2(760, 0)
	_how_to = box.get_parent()
	_how_box = box
	_gap(box, 6)
	for line: Array in HOW_TO:
		var entry := HBoxContainer.new()
		entry.add_theme_constant_override("separation", 24)
		box.add_child(entry)
		var key := _label(entry, line[0], 14, BLOOD)
		# One body-line tall and centred, so the key sits on the first line of a wrapped rule.
		key.custom_minimum_size = Vector2(220, 22)
		key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		key.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var text := _label(entry, line[1], 17, BONE, _body)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gap(box, 8)
	_how_back = _text_button(box, "BACK   [ESC]", 20)
	_how_back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_how_back.pressed.connect(_close_how_to)


## Every act as a card. With a run in progress, a warning names the floor that picking an act abandons.
func _build_acts() -> void:
	var box := _modal("CHOOSE YOUR ACT")
	_acts = box.get_parent()
	if RunState.has_progress():
		var floor_in_act := StageRule.for_floor(RunState.current_floor).floor_in_act
		_label(box, "Starting an act abandons your run on floor %d." % floor_in_act, 16, BLOOD, _body)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", ACT_CARD_GAP)
	box.add_child(cards)
	for act in range(1, StageRule.ACT_COUNT + 1):
		_act_card(cards, act)
	var back := _text_button(box, "BACK   [ESC]", 20)
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	back.pressed.connect(_close_acts)


## One act: its art (a tinted panel until act_N.png lands), numeral, name and floors. Locked acts are
## dimmed, padlocked, and name the act whose Gate opens them.
func _act_card(parent: Control, act: int) -> void:
	var unlocked := MetaState.is_act_unlocked(act)
	var tint := ACT_TINTS[act - 1]
	var card := Button.new()
	card.name = "Act%d" % act
	card.flat = true
	card.disabled = not unlocked
	card.custom_minimum_size = ACT_CARD_SIZE
	parent.add_child(card)
	var content := _holder(card, "Content")
	content.clip_contents = true
	var art_path := ART + "act_%d.png" % act
	var art_texture: Texture2D = load(art_path) if ResourceLoader.exists(art_path) \
			else _gradient(tint.darkened(0.55), Color.BLACK, Vector2(0, 1))
	var art := _image(content, art_texture, TextureRect.STRETCH_KEEP_ASPECT_COVERED, true)
	art.name = "Art"
	art.pivot_offset = ACT_CARD_SIZE * 0.5
	var shade := _gradient(Color(0, 0, 0, 0), Color(0, 0, 0, 0.92), Vector2(0, 1))
	shade.gradient.set_offset(0, 0.45)
	_image(content, shade, TextureRect.STRETCH_SCALE, true)
	var border := Panel.new()
	border.name = "Border"
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var outline := _panel_style(tint.darkened(0.25), 2, Color.TRANSPARENT)
	outline.set_corner_radius_all(6)
	border.add_theme_stylebox_override("panel", outline)
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(border)
	var first := StageRule.act_start(act)
	var sub := "FLOORS %d-%d" % [first, first + StageRule.FLOORS_PER_ACT - 1] if unlocked \
			else "CLEAR ACT %d TO OPEN" % (act - 1)
	for line: Array in [[ROMAN[act - 1], 54, tint.lightened(0.35), 18.0],
			[StageRule.ACT_NAMES[act - 1].to_upper(), 20, Color.WHITE, ACT_CARD_SIZE.y - 74],
			[sub, 11, BONE if unlocked else BLOOD, ACT_CARD_SIZE.y - 40]]:
		var label := _label(content, line[0], line[1], line[2])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_place(label, Vector2(0, line[3]), Vector2(ACT_CARD_SIZE.x, 0))
	if not unlocked:
		art.modulate = LOCKED_TINT
		var lock_path := ART + "act_locked.png"
		if ResourceLoader.exists(lock_path):
			_place(_image(content, load(lock_path), TextureRect.STRETCH_KEEP_ASPECT_CENTERED),
					(ACT_CARD_SIZE - LOCK_SIZE) * 0.5, LOCK_SIZE)
		else:
			var lock := _label(content, "LOCKED", 18, DIM)
			lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_place(lock, Vector2(0, ACT_CARD_SIZE.y * 0.5 - 12), Vector2(ACT_CARD_SIZE.x, 0))
	card.pressed.connect(_pick_act.bind(act))
	_hoverable(card)
	card.focus_entered.connect(_card_highlight.bind(content, true))
	card.focus_exited.connect(_card_highlight.bind(content, false))


## A full-screen dim with a titled, centred column, hidden until opened. Returns the column; its parent
## is the modal itself.
func _modal(title: String) -> VBoxContainer:
	var modal := Control.new()
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.visible = false
	add_child(modal)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.94)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 16)
	modal.add_child(box)
	_label(box, title, 32, BONE)
	return box


func _build_audio() -> void:
	_music = AudioStreamPlayer.new()
	_music.stream = load(MUSIC)
	(_music.stream as AudioStreamMP3).loop = true
	_music.volume_db = SILENT_DB
	add_child(_music)
	_music.play()
	_flip_sfx = AudioStreamPlayer.new()
	_flip_sfx.stream = load(FLIP_SFX)
	_flip_sfx.volume_db = -6.0
	add_child(_flip_sfx)
	_thunder = Timer.new()
	_thunder.one_shot = true
	_thunder.timeout.connect(_on_thunder)
	add_child(_thunder)


# --- Helpers ----------------------------------------------------------------------------------

## A dropped-in UI face wins; otherwise a condensed bold system face.
func _base_font() -> Font:
	if ResourceLoader.exists(UI_FONT):
		return load(UI_FONT)
	var system := SystemFont.new()
	system.font_names = PackedStringArray(["Oswald", "Bebas Neue", "Impact", "Arial Narrow", "sans-serif"])
	return system


func _tracked(base: Font, spacing: int) -> Font:
	var font := FontVariation.new()
	font.base_font = base
	font.spacing_glyph = spacing
	return font


func _label(parent: Node, text: String, font_size: int, color: Color, font: Font = null) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font if font else _display)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if font_size >= 16:  # big type sits on busy art; small type would just blur
		label.add_theme_constant_override("outline_size", floori(font_size / 6.0))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	parent.add_child(label)
	return label


func _text_button(parent: Node, text: String, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = true
	button.add_theme_font_override("font", _display)
	button.add_theme_font_size_override("font_size", font_size)
	for state in ["font_color", "font_pressed_color"]:
		button.add_theme_color_override(state, BONE)
	for state in ["font_hover_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, BLOOD)
	parent.add_child(button)
	_hoverable(button)
	return button


## Hover grabs focus, so mouse and keyboard/gamepad share one highlighted state.
func _hoverable(button: Button) -> void:
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.mouse_entered.connect(button.grab_focus)
	button.mouse_exited.connect(func() -> void:
		if button.has_focus():
			button.release_focus()
	)


func _image(parent: Node, texture: Texture2D, stretch: TextureRect.StretchMode, fill := false) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = stretch
	if fill:
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(rect)
	return rect


func _holder(parent: Node, holder_name: String) -> Control:
	var holder := Control.new()
	holder.name = holder_name
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(holder)
	return holder


func _place(node: Control, at: Vector2, extent: Vector2) -> void:
	node.position = at
	node.size = extent


func _icon(index: Icon) -> AtlasTexture:
	return _atlas(_icons, Rect2(Vector2(index % ICON_COLUMNS, floori(index / float(ICON_COLUMNS))) * ICON_CELL,
			Vector2.ONE * ICON_CELL))


func _atlas(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	return atlas


func _panel_style(border: Color, width: int, fill := PANEL_FILL) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(6)
	return style


func _gradient(from: Color, to: Color, fill_to: Vector2) -> GradientTexture2D:
	var texture := GradientTexture2D.new()
	texture.width = 64
	texture.height = 64
	texture.fill_to = fill_to
	texture.gradient = Gradient.new()
	texture.gradient.set_color(0, from)
	texture.gradient.set_color(1, to)
	return texture


func _glow_texture(color: Color, pixels: int) -> GradientTexture2D:
	var texture := _gradient(color, Color(color, 0.0), Vector2(0.5, 0.0))
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.width = pixels
	texture.height = pixels
	return texture


func _gap(parent: Node, height: float) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = height
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(gap)
