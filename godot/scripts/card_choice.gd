class_name CardChoice
extends Control
## The one card picker (plans/06 §6): doors, omens, curses and the Gate's RETURN / DESCEND. It also
## flashes a floor's cards for a moment as the floor starts. Click a card or press its number.
## A card's art loads from ART/<id>.png once it exists (prompts in ART/PROMPTS.md); until then each
## card is a panel edged in its kind's colour, with its name and rule.

signal picked(id: String)

const ART := "res://assets/images/cards/"
const CARD_SIZE := Vector2(250, 340)
const CARD_GAP := 28
const ART_HEIGHT := 130.0
const SHOW_TIME := 2.0
const FADE_TIME := 0.4
const HOVER_SCALE := 1.05
const FOCUS_TIME := 0.15
const KIND_COLORS := {"rule": MainMenu.EMBER, "door": MainMenu.GOLD, "gate": MainMenu.BLOOD, "sanctuary": Color(0.35, 0.6, 1.0),
		"omen": Color(0.66, 0.45, 1.0), "curse": Color(0.75, 0.1, 0.4), "choice": MainMenu.BONE}
const KIND_TAGS := {"rule": "RULE", "door": "DOOR", "gate": "THE GATE", "sanctuary": "SANCTUARY", "omen": "OMEN",
		"curse": "CURSE", "choice": "THE WAY ON"}

var _title: Label
var _row: HBoxContainer
var _ids: Array[String] = []
var _pickable := false
var _font: Font
var _fade: Tween


func _ready() -> void:
	# Offsets too: set_anchors_preset() alone keeps an in-tree node at its current (zero) size.
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	_font = DeathScreen.ui_font()
	var column := VBoxContainer.new()
	column.mouse_filter = MOUSE_FILTER_IGNORE
	column.set_anchors_preset(PRESET_CENTER)
	column.grow_horizontal = GROW_DIRECTION_BOTH
	column.grow_vertical = GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 22)
	add_child(column)
	_title = _label(column, 30, MainMenu.BONE)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_row = HBoxContainer.new()
	_row.mouse_filter = MOUSE_FILTER_IGNORE
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", CARD_GAP)
	column.add_child(_row)
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _pickable or not (event is InputEventKey and event.pressed and not event.echo):
		return
	var index: int = (event as InputEventKey).keycode - KEY_1
	if index >= 0 and index < _ids.size():
		if is_inside_tree():
			get_viewport().set_input_as_handled()
		_pick(index)


## Cards to pick from (up to three): emits picked(id) once, then hides.
func offer(title: String, ids: Array) -> void:
	_show(title, ids, true)


## Cards shown for SHOW_TIME, then faded out: nothing to pick, and the game plays on underneath.
func flash(title: String, ids: Array) -> void:
	_show(title, ids, false)
	_fade = create_tween()
	_fade.tween_interval(SHOW_TIME)
	_fade.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	_fade.tween_callback(hide)


func _show(title: String, ids: Array, pickable: bool) -> void:
	if _fade != null:
		_fade.kill()
	_ids.assign(ids)
	_pickable = pickable
	mouse_filter = MOUSE_FILTER_STOP if pickable else MOUSE_FILTER_IGNORE
	_title.text = title
	_title.visible = title != ""
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	for i in _ids.size():
		_row.add_child(_card(_ids[i], i))
	modulate.a = 1.0
	visible = true
	if pickable:
		(_row.get_child(0) as Control).grab_focus()


func _pick(index: int) -> void:
	if not _pickable:
		return
	_pickable = false
	visible = false
	picked.emit(_ids[index])


func _card(id: String, index: int) -> Button:
	var card := Cards.find(id)
	var kind := Cards.kind(id)
	var color: Color = KIND_COLORS.get(kind, MainMenu.BONE)
	var button := Button.new()
	button.name = "Card%d" % index
	button.custom_minimum_size = CARD_SIZE
	button.pivot_offset = CARD_SIZE * 0.5
	button.focus_mode = FOCUS_ALL if _pickable else FOCUS_NONE
	button.mouse_filter = MOUSE_FILTER_STOP if _pickable else MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = MainMenu.PANEL_FILL
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, style)
	var body := VBoxContainer.new()
	body.mouse_filter = MOUSE_FILTER_IGNORE
	body.set_anchors_preset(PRESET_FULL_RECT)
	body.offset_left = 16
	body.offset_top = 14
	body.offset_right = -16
	body.offset_bottom = -14
	body.add_theme_constant_override("separation", 10)
	button.add_child(body)
	_label(body, 13, color).text = KIND_TAGS.get(kind, "")
	if ResourceLoader.exists(ART + id + ".png"):
		var art := TextureRect.new()
		art.mouse_filter = MOUSE_FILTER_IGNORE
		art.texture = load(ART + id + ".png")
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.custom_minimum_size = Vector2(0, ART_HEIGHT)
		body.add_child(art)
	var title := _label(body, 26, Color.WHITE)
	title.text = card.get("name", id)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var text := _label(body, 16, MainMenu.BONE)
	text.text = card.get("text", "")
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_vertical = SIZE_EXPAND_FILL
	if _pickable:
		_label(body, 15, MainMenu.DIM).text = "[%d]" % (index + 1)
		button.pressed.connect(_pick.bind(index))
		button.mouse_entered.connect(button.grab_focus)
		button.focus_entered.connect(_grow.bind(button, true))
		button.focus_exited.connect(_grow.bind(button, false))
	return button


func _grow(node: Control, on: bool) -> void:
	node.create_tween().tween_property(node, "scale", Vector2.ONE * (HOVER_SCALE if on else 1.0), FOCUS_TIME)


func _label(parent: Node, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if font_size >= 16:
		label.add_theme_constant_override("outline_size", floori(font_size / 6.0))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	parent.add_child(label)
	return label
