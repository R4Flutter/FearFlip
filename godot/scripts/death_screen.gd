class_name DeathScreen
extends Control
## Death screen (plans/05 §3.8): what killed you and the rule that beats it, how close you were,
## then RETRY (same maze, instant) or REVIVE (back to the last safe circle you used).

signal retry_pressed
signal revive_pressed

var _title: Label
var _rule: Label
var _detail: Label
var _revive: Button
var _retry: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.0, 0.0, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.custom_minimum_size = Vector2(760, 0)
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	_title = _label(box, 54, Color(1.0, 0.25, 0.2))
	_rule = _label(box, 24, Color(1.0, 0.85, 0.7))
	_detail = _label(box, 18, Color(0.75, 0.82, 0.9))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	box.add_child(buttons)
	_retry = _button(buttons, "RETRY  [R]", 30)
	_retry.pressed.connect(func() -> void: retry_pressed.emit())
	_revive = _button(buttons, "REVIVE  [V]", 22)
	_revive.pressed.connect(func() -> void: revive_pressed.emit())
	visible = false


func show_death(title: String, rule: String, detail: String, revive_text: String, can_revive: bool) -> void:
	_title.text = title
	_rule.text = rule
	_detail.text = detail
	_revive.text = revive_text
	_revive.disabled = not can_revive
	visible = true
	_retry.grab_focus()


func _label(parent: Control, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _button(parent: Control, text: String, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220, 64)
	button.add_theme_font_size_override("font_size", font_size)
	parent.add_child(button)
	return button
