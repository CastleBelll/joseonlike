class_name TouchJoystick
extends Control
## Floating touch joystick (N6-4; fixed bottom-left pad until N3-1). A touch
## anywhere in the play area anchors the stick origin at the touch point and
## drags from there; releasing hides it. The resting pad keeps drawing inside
## this control's rect as the affordance hint — the FTUE move hint points at
## it, so a fresh player still sees where movement lives. Named TouchJoystick
## because Godot 4.7 ships a native VirtualJoystick class. Listens in _input
## so a drag that leaves the origin keeps working; touches are never consumed,
## and only the captured finger index moves the stick, so a second finger on
## an active-skill button can never cancel movement.

const BASE_RADIUS := 60.0  # 120px base diameter
const KNOB_RADIUS := 24.0  # 48px knob diameter
const BASE_ALPHA := 0.35
const RING_ALPHA := 0.6
const KNOB_ALPHA := 0.75
const RING_WIDTH := 3.0
const RING_POINT_COUNT := 48

## Unit-clamped move vector; Vector2.ZERO while untouched.
var output := Vector2.ZERO

## Set by the stage: returns true when a screen point lands on an interactive
## HUD control (active buttons, pause, info) — those taps are never captured,
## so the HUD keeps tap priority over the floating stick.
var blocks_touch := Callable()

var _touch_index: int = -1
var _origin := Vector2.ZERO
var _knob_offset := Vector2.ZERO


## Pure stick math (unit-tested headless): the knob offset is the touch's
## pull from the origin clamped to the base radius…
static func knob_offset(origin: Vector2, touch: Vector2, radius: float) -> Vector2:
	return (touch - origin).limit_length(radius)


## …and the output is that offset normalized to the unit disc.
static func output_vector(origin: Vector2, touch: Vector2, radius: float) -> Vector2:
	if radius <= 0.0:
		return Vector2.ZERO
	return knob_offset(origin, touch, radius) / radius


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _touch_index == -1 and not _is_blocked(event.position):
			_touch_index = event.index
			_origin = event.position
			_update_knob(event.position)
	elif event.index == _touch_index:
		_release()


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _touch_index:
		_update_knob(event.position)


func _is_blocked(point: Vector2) -> bool:
	return blocks_touch.is_valid() and bool(blocks_touch.call(point))


func _update_knob(screen_position: Vector2) -> void:
	_knob_offset = knob_offset(_origin, screen_position, BASE_RADIUS)
	output = output_vector(_origin, screen_position, BASE_RADIUS)
	queue_redraw()


func _release() -> void:
	_touch_index = -1
	_knob_offset = Vector2.ZERO
	output = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	# Resting hint at the home rect while untouched; the live stick draws at
	# the actual touch origin anywhere on screen (no clip_contents, so drawing
	# outside this control's rect is fine).
	var center: Vector2 = size / 2.0 if _touch_index == -1 else _origin - global_position
	draw_circle(center, BASE_RADIUS, Color(UiPalette.NIGHT_BROWN, BASE_ALPHA))
	draw_arc(
		center, BASE_RADIUS - RING_WIDTH / 2.0, 0.0, TAU, RING_POINT_COUNT,
		Color(UiPalette.WOOD_BORDER, RING_ALPHA), RING_WIDTH
	)
	draw_circle(center + _knob_offset, KNOB_RADIUS, Color(UiPalette.WOOD, KNOB_ALPHA))
