class_name TouchJoystick
extends Control
## Fixed bottom-left touch joystick (N3-1). Named TouchJoystick because Godot
## 4.7 ships a native VirtualJoystick class. Listens in _input so a drag that
## started on the stick keeps working after the finger leaves its rect, while
## touches elsewhere on the screen are never consumed.

const BASE_RADIUS := 60.0  # 120px base diameter
const KNOB_RADIUS := 24.0  # 48px knob diameter
const BASE_ALPHA := 0.35
const RING_ALPHA := 0.6
const KNOB_ALPHA := 0.75
const RING_WIDTH := 3.0
const RING_POINT_COUNT := 48

## Unit-clamped move vector; Vector2.ZERO while untouched.
var output := Vector2.ZERO

var _touch_index: int = -1
var _knob_offset := Vector2.ZERO


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _touch_index == -1 and get_global_rect().has_point(event.position):
			_touch_index = event.index
			_update_knob(event.position)
	elif event.index == _touch_index:
		_release()


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _touch_index:
		_update_knob(event.position)


func _update_knob(screen_position: Vector2) -> void:
	var center: Vector2 = get_global_rect().get_center()
	_knob_offset = (screen_position - center).limit_length(BASE_RADIUS)
	output = _knob_offset / BASE_RADIUS
	queue_redraw()


func _release() -> void:
	_touch_index = -1
	_knob_offset = Vector2.ZERO
	output = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size / 2.0
	draw_circle(center, BASE_RADIUS, Color(UiPalette.NIGHT_BROWN, BASE_ALPHA))
	draw_arc(
		center, BASE_RADIUS - RING_WIDTH / 2.0, 0.0, TAU, RING_POINT_COUNT,
		Color(UiPalette.WOOD_BORDER, RING_ALPHA), RING_WIDTH
	)
	draw_circle(center + _knob_offset, KNOB_RADIUS, Color(UiPalette.WOOD, KNOB_ALPHA))
