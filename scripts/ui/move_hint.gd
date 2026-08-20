class_name MoveHint
extends Control
## One-shot movement hint (N6-1, GDD §28): four pulsing chevrons and a short
## label over the joystick area, shown only while the profile has never seen
## it. Purely visual — Stage owns the dismiss-on-first-input rule and the
## persisted flag (Ftue.mark_move_hint_seen); this node never eats input.
## Callers: Stage._ready adds it to the Hud layer; tools/playtest.gd reads it.

const HINT_LABEL := "끌어서 이동"
# 70px keeps all four chevrons on screen from the corner-anchored joystick
# (center ~92px from the left/bottom edges on the 540x960 viewport).
const ARROW_DISTANCE := 70.0
const ARROW_HALF_WIDTH := 10.0
const ARROW_LENGTH := 14.0
const LABEL_OFFSET_Y := -128.0
const PULSE_HZ := 1.4
const PULSE_ALPHA_MIN := 0.45
const PULSE_ALPHA_MAX := 1.0

## The joystick control this hint decorates; set by the stage before add.
var target: Control

var _time: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.name = "HintLabel"
	label.text = UiLocale.t(HINT_LABEL)
	label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_BODY)
	label.add_theme_color_override("font_color", UiPalette.GOLD)
	label.add_theme_color_override("font_outline_color", UiPalette.INK)
	label.add_theme_constant_override("outline_size", 6)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	# Deferred: the joystick's anchored rect only exists after the first layout.
	_place_label.call_deferred(label)


func _place_label(label: Label) -> void:
	if target == null:
		return
	var center: Vector2 = target.get_global_rect().get_center()
	label.size = Vector2(target.get_global_rect().size.x * 2.0, 28.0)
	label.position = center + Vector2(-label.size.x / 2.0, LABEL_OFFSET_Y)


func _process(delta: float) -> void:
	_time += delta
	var pulse: float = 0.5 + 0.5 * sin(_time * TAU * PULSE_HZ)
	modulate.a = lerpf(PULSE_ALPHA_MIN, PULSE_ALPHA_MAX, pulse)
	queue_redraw()


func _draw() -> void:
	if target == null:
		return
	var center: Vector2 = target.get_global_rect().get_center()
	for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		_draw_arrow(center + direction * ARROW_DISTANCE, direction)


## Outward-pointing chevron triangle in the gold token with an ink outline
## triangle behind it, so it stays legible on any ground tile.
func _draw_arrow(tip_base: Vector2, direction: Vector2) -> void:
	var side: Vector2 = direction.orthogonal() * ARROW_HALF_WIDTH
	var tip: Vector2 = tip_base + direction * ARROW_LENGTH
	var outline_grow: Vector2 = direction * 3.0
	draw_colored_polygon(PackedVector2Array([
		tip + outline_grow,
		tip_base - outline_grow + side * 1.3,
		tip_base - outline_grow - side * 1.3,
	]), UiPalette.INK)
	draw_colored_polygon(PackedVector2Array([
		tip, tip_base + side, tip_base - side,
	]), UiPalette.GOLD)
