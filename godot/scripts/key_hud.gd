class_name KeyHud
extends Control
## Key slots on the status plate (top right; sized for a container row). A grabbed key leaps from where it was on
## screen, arcs up and spins into its slot, and the slot flashes and bounces: the Subway Surfers pickup.
## With all keys found the slots breathe gold; at the chest they empty one by one.

const SLOT_HEIGHT := 40.0
const SLOT_GAP := 6.0
const FLY_TIME := 0.6
## The flyer starts this many times the slot size and shrinks into it.
const FLY_SCALE := 2.4
const ARC_HEIGHT := 180.0
const EMPTY := Color(0.6, 0.6, 0.66, 0.6)
const LIT := Color(1, 1, 1, 1)
const GOLD := Color(1.0, 0.85, 0.45)

var slots: Array[TextureRect] = []
var _pulse: Tween


func build(count: int) -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var slot_size := _slot_size()
	custom_minimum_size = Vector2(count * slot_size.x + (count - 1) * SLOT_GAP, slot_size.y)
	for i in count:
		var slot := _key_rect(slot_size)
		slot.position = Vector2(i * (slot_size.x + SLOT_GAP), 0)
		slot.modulate = EMPTY
		add_child(slot)
		slots.append(slot)


## A key collected at `from` (screen position) flies into slot `index`.
func fly_in(index: int, from: Vector2) -> void:
	var slot := slots[index]
	var flyer := _key_rect(slot.size)
	flyer.top_level = true
	flyer.scale = Vector2.ONE * FLY_SCALE
	add_child(flyer)
	var target := slot.global_position + slot.size * 0.5
	var control := from.lerp(target, 0.4) + Vector2(0, -ARC_HEIGHT)
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		var u := 1.0 - t
		flyer.global_position = u * u * from + 2.0 * u * t * control + t * t * target - flyer.size * 0.5
		flyer.scale = Vector2.ONE * lerpf(FLY_SCALE, 1.0, t)
		flyer.rotation = t * TAU, 0.0, 1.0, FLY_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(flyer.queue_free)
	tween.tween_callback(_light.bind(slot))


## Every key found: the slots breathe gold until the chest takes them.
func all_found() -> void:
	_pulse = create_tween().set_loops()
	_pulse.tween_property(self, "modulate", GOLD * 1.4, 0.45).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(self, "modulate", Color.WHITE, 0.45).set_trans(Tween.TRANS_SINE)


## A key left for the chest: its slot goes dark.
func spend(index: int) -> void:
	if _pulse != null:
		_pulse.kill()
		modulate = Color.WHITE
	var tween := create_tween()
	tween.tween_property(slots[index], "scale", Vector2.ONE * 1.3, 0.08)
	tween.tween_property(slots[index], "scale", Vector2.ONE, 0.12)
	tween.parallel().tween_property(slots[index], "modulate", EMPTY, 0.2)


func _light(slot: TextureRect) -> void:
	slot.modulate = LIT * 2.2
	slot.scale = Vector2.ONE * 1.7
	var tween := create_tween().set_parallel()
	tween.tween_property(slot, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(slot, "modulate", LIT, 0.35)


func _key_rect(rect_size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = Art.key_icon()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = MOUSE_FILTER_IGNORE
	rect.size = rect_size
	rect.pivot_offset = rect_size * 0.5
	return rect


static func _slot_size() -> Vector2:
	var texture := Art.key_icon()
	return Vector2(SLOT_HEIGHT * texture.get_width() / texture.get_height(), SLOT_HEIGHT)
