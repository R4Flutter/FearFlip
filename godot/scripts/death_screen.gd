class_name DeathScreen
extends Control
## Death screen (plans/05 §3.8): what killed you and the rule that beats it, how close you were,
## then TRY AGAIN (a new run from the act's first floor, plans/06) or REVIVE (back to the last safe
## circle you used).
## Impact first (red flash, glass cracks, shake), then GAME OVER slams down and the choices rise.
## Art: assets/images/menu/ (shares the dashboard's frames, demon and sweep shader).

signal retry_pressed
signal revive_pressed

const ART := "res://assets/images/menu/"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const GLASS_SFX := "res://assets/audio/glass_break.mp3"
const HEART_SFX := "res://assets/audio/sfx_heartbeat.mp3"
const VIEW := Vector2(1280, 720)
const TITLE_H := 130.0
const TITLE_SPLIT := 0.513  # x fraction of gameover_title.png between GAME and OVER
const BUTTON_SIZE := Vector2(360, 117)
const BUTTON_TOP := 440.0
const BUTTON_GAP := 30.0
const ICON_CELL := 160
enum Icon { HEART, RETRY, HOME, SKULL, AD, HOURGLASS }

const DIM_ALPHA := 0.8
const CRACK_ALPHA := 0.3
const DEMON_ALPHA := 0.5
const HOVER_SCALE := 1.06
const FOCUS_TIME := 0.18
const LEAVE_TIME := 0.25
const GOLD := Color(1.0, 0.78, 0.3)
const SPENT := Color(0.4, 0.4, 0.42)
## Unfinished business (plans/06 E5) sits under the menu link: what this run banked, the unlock bar,
## and how far the next shortcut is.
const BUSINESS_TOP := 640.0
const UNLOCK_BAR_SIZE := Vector2(320, 6)

var _stage: Control
var _dim: ColorRect
var _flash: ColorRect
var _cracks: TextureRect
var _demon: TextureRect
var _pool: TextureRect
var _title: Control
var _over: TextureRect
var _cause: Label
var _rule: Label
var _detail: Label
var _retry: Button
var _retry_sub: Label
var _revive: Button
var _revive_sub: Label
var _heart: TextureRect
var _menu: Button
var _business_box: VBoxContainer
var _business: Label
var _unlock_bar: ProgressBar
var _glass: AudioStreamPlayer
var _heartbeat: AudioStreamPlayer
var _additive: CanvasItemMaterial
var _icons: Texture2D
var _font: Font
var _leaving := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = ui_font()
	_icons = load(ART + "gameover_icons.png")
	_additive = CanvasItemMaterial.new()
	_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_dim = _rect(Color(0.05, 0.0, 0.01, 0.0))
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)  # the design space is the 1280x720 viewport
	add_child(_stage)
	# Both painted on black and added on: the black vanishes.
	_cracks = _image(_stage, load(ART + "gameover_cracks.png"), Vector2.ZERO, VIEW)
	_cracks.material = _additive
	_demon = _image(_stage, load(ART + "menu_demon.png"), Vector2(320, -40), Vector2(640, 427))
	_demon.material = _additive
	_demon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# A dark pool behind the words so the burst never fights the text.
	var pool := GradientTexture2D.new()
	pool.fill = GradientTexture2D.FILL_RADIAL
	pool.fill_from = Vector2(0.5, 0.5)
	pool.fill_to = Vector2(0.5, 0.0)
	pool.gradient = Gradient.new()
	pool.gradient.set_color(0, Color(0, 0, 0, 0.85))
	pool.gradient.set_color(1, Color(0, 0, 0, 0))
	_pool = _image(_stage, pool, Vector2(90, 40), Vector2(1100, 640))
	_pool.stretch_mode = TextureRect.STRETCH_SCALE
	_build_title()
	_build_text()
	_retry = _big_button(load(ART + "ui_play_button.png"), Icon.RETRY, "TRY AGAIN", "NEW RUN  ·  [R]", 0)
	_retry_sub = _retry.get_node("Content/Line/Words/Sub")
	_revive = _big_button(load(ART + "ui_revive_button.png"), Icon.HEART, "REVIVE", "", 1)
	_revive_sub = _revive.get_node("Content/Line/Words/Sub")
	_heart = _revive.get_node("Content/Line/Icon")
	_retry.pressed.connect(_leave.bind(false))
	_revive.pressed.connect(_leave.bind(true))
	_menu = _text_link("MAIN MENU   [ESC]")
	_menu.pressed.connect(_to_menu)
	_build_business()
	_flash = _rect(Color(1, 0.1, 0.05, 0.0))
	_glass = _sound(GLASS_SFX, -4.0)
	_heartbeat = _sound(HEART_SFX, -8.0)
	_loops()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _leaving:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_V and not _revive.disabled:
			_leave(true)
			accept_event()
		elif event.keycode == KEY_ESCAPE:
			_to_menu()
			accept_event()


func show_death(title: String, rule: String, detail: String, revive_text: String, can_revive: bool,
		retry_text := "NEW RUN  ·  [R]", business := "") -> void:
	_cause.text = title
	_rule.text = rule
	_detail.text = detail
	_business.text = business
	_unlock_bar.value = MetaState.unlock_progress()
	_retry_sub.text = retry_text
	_revive_sub.text = revive_text
	_revive.disabled = not can_revive
	_revive.modulate = Color.WHITE if can_revive else SPENT
	_leaving = false
	visible = true
	_retry.grab_focus()
	_impact()


# --- Motion -----------------------------------------------------------------------------------

## The hit, then the verdict, then the way back. Seen every death, so it's over in ~1.5 s.
func _impact() -> void:
	_glass.play()
	var tween := _retarget(self)
	_flash.color.a = 0.65
	tween.tween_property(_flash, "color:a", 0.0, 0.45)
	tween.tween_property(_dim, "color:a", DIM_ALPHA, 0.6).from(0.0)
	tween.tween_property(_pool, "modulate:a", 1.0, 0.6).from(0.0).set_delay(0.25)
	_cracks.pivot_offset = VIEW * 0.5
	tween.tween_property(_cracks, "scale", Vector2.ONE, 0.18).from(Vector2.ONE * 1.3)
	tween.tween_property(_cracks, "modulate:a", CRACK_ALPHA, 0.9).from(1.0).set_delay(0.1)
	tween.tween_property(_demon, "modulate:a", DEMON_ALPHA, 1.2).from(0.0).set_delay(0.3)
	_shake(12.0, 0.3)

	_title.modulate.a = 0.0
	tween.tween_property(_title, "modulate:a", 1.0, 0.15).set_delay(0.35)
	tween.tween_property(_title, "scale", Vector2.ONE, 0.3).from(Vector2.ONE * 1.8).set_delay(0.35).set_ease(Tween.EASE_IN)
	tween.tween_callback(_shake.bind(8.0, 0.25)).set_delay(0.65)

	var delay := 0.75
	for node: Control in [_cause.get_parent() as Control, _rule, _detail]:
		node.modulate.a = 0.0
		tween.tween_property(node, "modulate:a", 1.0, 0.3).set_delay(delay)
		delay += 0.1
	tween.tween_property(_rule, "visible_ratio", 1.0, 0.7).from(0.0).set_delay(0.85).set_trans(Tween.TRANS_LINEAR)

	delay = 1.1
	for button: Button in [_retry, _revive]:
		button.scale = Vector2.ONE
		var content: Control = button.get_node("Content")
		content.modulate.a = 0.0
		tween.tween_property(content, "modulate:a", 1.0, 0.3).set_delay(delay)
		tween.tween_property(content, "position:y", 0.0, 0.55).from(60.0).set_delay(delay).set_trans(Tween.TRANS_BACK)
		delay += 0.1
	if not _revive.disabled:
		tween.tween_callback(_heartbeat.play).set_delay(delay)
	for node: Control in [_menu, _business_box]:
		node.modulate.a = 0.0
		tween.tween_property(node, "modulate:a", 1.0, 0.4).set_delay(delay)


## Ambient loops, built once: REVIVE beats like a heart, the retry arrow turns, OVER flickers,
## the demon breathes. They idle harmlessly while the screen is hidden.
func _loops() -> void:
	var beat := _revive.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	for step: Vector2 in [Vector2(1.05, 0.11), Vector2(1.0, 0.13), Vector2(1.03, 0.1), Vector2(1.0, 0.22)]:
		beat.tween_property(_heart, "scale", Vector2.ONE * (1.0 + (step.x - 1.0) * 4.0), step.y)
		beat.parallel().tween_property(_revive.get_node("Content"), "scale", Vector2.ONE * step.x, step.y)
	beat.tween_interval(0.8)
	var arrow: Control = _retry.get_node("Content/Line/Icon")
	var turn := arrow.create_tween().set_loops()
	turn.tween_property(arrow, "rotation", TAU, 4.0).from(0.0)
	var flicker := _over.create_tween().set_loops()
	flicker.tween_interval(2.4)
	for alpha: float in [0.35, 1.0, 0.6, 1.0]:
		flicker.tween_property(_over, "modulate:a", alpha, 0.05)
	var breath := _demon.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_demon.pivot_offset = _demon.size * 0.5
	breath.tween_property(_demon, "scale", Vector2.ONE * 1.04, 3.0)
	breath.tween_property(_demon, "scale", Vector2.ONE, 3.0)


## Answer the press visually, then hand over: revive bursts gold, retry pulls the cracks back.
func _leave(revive: bool) -> void:
	if _leaving or (revive and _revive.disabled):
		return
	_leaving = true
	var tween := _retarget(self)
	if revive:
		_flash.color = Color(GOLD, 0.0)
		tween.tween_property(_flash, "color:a", 0.6, LEAVE_TIME)
		_heart.pivot_offset = _heart.size * 0.5
		tween.tween_property(_heart, "scale", Vector2.ONE * 3.0, LEAVE_TIME)
	else:
		tween.tween_property(_cracks, "scale", Vector2.ONE * 1.4, LEAVE_TIME).set_ease(Tween.EASE_IN)
		tween.tween_property(_cracks, "modulate:a", 0.0, LEAVE_TIME)
		tween.tween_property(_dim, "color:a", 1.0, LEAVE_TIME)
	await tween.finished
	_flash.color.a = 0.0
	_heart.scale = Vector2.ONE
	(revive_pressed if revive else retry_pressed).emit()


func _to_menu() -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().paused = false
	var tween := _retarget(self)
	tween.tween_property(_dim, "color:a", 1.0, LEAVE_TIME)
	await tween.finished
	get_tree().change_scene_to_file(MENU_SCENE)


func _shake(strength: float, time: float) -> void:
	const STEPS := 6
	var tween := _retarget(_stage).set_parallel(false)
	for i in STEPS:
		var jolt := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength * (1.0 - float(i) / STEPS)
		tween.tween_property(_stage, "position", jolt, time / (STEPS + 1))
	tween.tween_property(_stage, "position", Vector2.ZERO, time / (STEPS + 1))


func _grow(node: Control, on: bool) -> void:
	_retarget(node).tween_property(node, "scale", Vector2.ONE * (HOVER_SCALE if on else 1.0), FOCUS_TIME)


func _retarget(node: Node) -> Tween:
	if node.has_meta("tween"):
		(node.get_meta("tween") as Tween).kill()
	var tween := node.create_tween().set_parallel().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	node.set_meta("tween", tween)
	return tween


# --- Build ------------------------------------------------------------------------------------

## gameover_title.png split at the gap, so OVER can flicker on its own.
func _build_title() -> void:
	var texture: Texture2D = load(ART + "gameover_title.png")
	var width := TITLE_H * texture.get_width() / texture.get_height()
	_title = Control.new()
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.position = Vector2((VIEW.x - width) * 0.5, 80)
	_title.size = Vector2(width, TITLE_H)
	_title.pivot_offset = _title.size * 0.5
	_stage.add_child(_title)
	var split := roundf(texture.get_width() * TITLE_SPLIT)
	_image(_title, _atlas(texture, Rect2(0, 0, split, texture.get_height())), Vector2.ZERO,
			Vector2(width * TITLE_SPLIT, TITLE_H))
	_over = _image(_title, _atlas(texture, Rect2(split, 0, texture.get_width() - split, texture.get_height())),
			Vector2(width * TITLE_SPLIT, 0), Vector2(width * (1.0 - TITLE_SPLIT), TITLE_H))


func _build_text() -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.position = Vector2(0, 222)
	row.size = Vector2(VIEW.x, 44)
	_stage.add_child(row)
	var skull := _image(row, _icon(Icon.SKULL), Vector2.ZERO, Vector2.ZERO)
	skull.custom_minimum_size = Vector2(40, 40)
	_cause = _label(row, 28, MainMenu.BLOOD)
	_cause.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rule = _label(_stage, 18, MainMenu.BONE)
	_detail = _label(_stage, 15, MainMenu.BONE)
	for entry: Array in [[_rule, 278.0], [_detail, 346.0]]:
		var label: Label = entry[0]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.position = Vector2(240, entry[1])
		label.size = Vector2(800, 0)


## A framed art button: icon + title + hint centred on the panel; hover grows it, focus follows the mouse.
func _big_button(art: Texture2D, icon: Icon, title: String, sub: String, slot: int) -> Button:
	var button := Button.new()
	button.flat = true
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.position = Vector2(VIEW.x * 0.5 - BUTTON_SIZE.x - BUTTON_GAP * 0.5 + slot * (BUTTON_SIZE.x + BUTTON_GAP), BUTTON_TOP)
	button.size = BUTTON_SIZE
	button.pivot_offset = BUTTON_SIZE * 0.5
	_stage.add_child(button)
	var content := Control.new()
	content.name = "Content"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.pivot_offset = BUTTON_SIZE * 0.5
	button.add_child(content)
	var panel := _image(content, art, Vector2.ZERO, BUTTON_SIZE)
	var sweep := ShaderMaterial.new()
	sweep.shader = Shader.new()
	sweep.shader.code = MainMenu.SWEEP_SHADER
	panel.material = sweep
	var line := HBoxContainer.new()
	line.name = "Line"
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 12)
	line.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(line)
	var glyph := _image(line, _icon(icon), Vector2.ZERO, Vector2.ZERO)
	glyph.name = "Icon"
	glyph.custom_minimum_size = Vector2(54, 54)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glyph.pivot_offset = Vector2(27, 27)
	var words := VBoxContainer.new()
	words.name = "Words"
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.add_theme_constant_override("separation", -4)
	line.add_child(words)
	_label(words, 34, Color.WHITE).text = title
	var hint := _label(words, 13, MainMenu.BONE)
	hint.name = "Sub"
	hint.text = sub
	button.mouse_entered.connect(button.grab_focus)
	button.focus_entered.connect(_grow.bind(button, true))
	button.focus_exited.connect(_grow.bind(button, false))
	return button


func _text_link(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = true
	button.icon = _icon(Icon.HOME)
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 26)
	button.add_theme_font_override("font", _font)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", MainMenu.BONE)
	for state in ["font_hover_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, MainMenu.BLOOD)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.position = Vector2(VIEW.x * 0.5 - 90, BUTTON_TOP + BUTTON_SIZE.y + 36)
	button.size = Vector2(180, 34)
	button.mouse_entered.connect(button.grab_focus)
	_stage.add_child(button)
	return button


func _build_business() -> void:
	_business_box = VBoxContainer.new()
	_business_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_business_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_business_box.add_theme_constant_override("separation", 8)
	_business_box.position = Vector2(240, BUSINESS_TOP)
	_business_box.size = Vector2(800, 40)
	_stage.add_child(_business_box)
	_business = _label(_business_box, 15, MainMenu.BONE)
	_business.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_unlock_bar = ProgressBar.new()
	_unlock_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unlock_bar.show_percentage = false
	_unlock_bar.max_value = 1.0
	_unlock_bar.step = 0.0
	_unlock_bar.custom_minimum_size = UNLOCK_BAR_SIZE
	_unlock_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0, 0, 0, 0.6)
	track.set_corner_radius_all(3)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = GOLD
	_unlock_bar.add_theme_stylebox_override("background", track)
	_unlock_bar.add_theme_stylebox_override("fill", fill)
	_business_box.add_child(_unlock_bar)


func _rect(color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(rect)
	return rect


func _image(parent: Node, texture: Texture2D, at: Vector2, extent: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	parent.add_child(rect)
	rect.position = at
	rect.size = extent
	return rect


func _label(parent: Node, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if font_size >= 16:
		label.add_theme_constant_override("outline_size", floori(font_size / 6.0))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	parent.add_child(label)
	return label


func _sound(path: String, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	player.volume_db = volume_db
	add_child(player)
	return player


func _icon(index: Icon) -> AtlasTexture:
	return _atlas(_icons, Rect2(Vector2(index % 3, floori(index / 3.0)) * ICON_CELL, Vector2.ONE * ICON_CELL))


func _atlas(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	return atlas


## Same face as the dashboard: a dropped-in UI font, else a condensed bold system face (CardChoice too).
static func ui_font() -> Font:
	if ResourceLoader.exists(MainMenu.UI_FONT):
		return load(MainMenu.UI_FONT)
	var system := SystemFont.new()
	system.font_names = PackedStringArray(["Oswald", "Bebas Neue", "Impact", "Arial Narrow", "sans-serif"])
	return system
