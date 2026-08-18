class_name TutorialRing
extends Control
## N9-14 tutorial highlight: a pulsing GOLD rounded ring drawn around a
## target control's global rect so the guide can say "press THIS". Pure
## draw node — never eats input.

const PADDING := 8.0
const WIDTH_MIN := 2.0
const WIDTH_MAX := 5.0
const PULSE_HZ := 1.4
const CORNER_RADIUS := 14.0

var _target := Rect2()
var _phase: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func aim(target_global: Rect2) -> void:
	_target = target_global.grow(PADDING)
	queue_redraw()


func _process(delta: float) -> void:
	_phase += delta * PULSE_HZ
	queue_redraw()


func _draw() -> void:
	if not _target.has_area():
		return
	var pulse: float = 0.5 + 0.5 * sin(_phase * TAU)
	var rect := Rect2(_target.position - global_position, _target.size)
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = Color(UiPalette.GOLD, 0.55 + 0.45 * pulse)
	style.set_border_width_all(int(lerpf(WIDTH_MIN, WIDTH_MAX, pulse)))
	style.set_corner_radius_all(int(CORNER_RADIUS))
	draw_style_box(style, rect)
