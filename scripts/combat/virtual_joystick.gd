class_name TouchJoystick
extends Control
## Floating touch joystick (N6-4; fixed bottom-left pad until N3-1). A touch
## anywhere in the play area anchors the stick origin at the touch point and
## drags from there; releasing hides it. N9-15: the resting pad no longer
## draws at all — the stick is invisible until a drag starts (owner
## direction), and the FTUE move hint still anchors to this control's rect.
## Named TouchJoystick
## because Godot 4.7 ships a native VirtualJoystick class. Listens in _input
## so a drag that leaves the origin keeps working; touches are never consumed,
## and only the captured finger index moves the stick, so a second finger on
## an active-skill button can never cancel movement.

const BASE_RADIUS := 60.0  # 120px base diameter
const KNOB_RADIUS := 24.0  # 48px knob diameter
const BASE_ALPHA := 0.35
## R15: darkens the base's kit disc so it sits behind the full-value knob.
const BASE_DISC_DIM := 0.55
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


## A pause stops this node receiving input, so the touch-release that ends the
## current drag is never delivered — the captured finger index would survive
## into the unpaused world and reject every later touch, leaving the stick
## frozen at a stale origin. Every screen that freezes the run (guide pages,
## level-up cards, pause, result) goes through the tree pause, so releasing
## here covers all of them at once instead of at each call site.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_release()


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


## N6-5: the persisted joystick_opacity setting scales every draw alpha —
## read at draw time so a settings change applies live, no wiring needed.
## Node-free tools and tests (no autoload) fall back to full opacity.
func _opacity() -> float:
	if SaveService.instance == null:
		return SaveProfile.JOYSTICK_OPACITY_MAX
	return clampf(
		float(SaveService.instance.get_setting(SaveProfile.JOYSTICK_OPACITY_KEY)),
		SaveProfile.JOYSTICK_OPACITY_MIN, SaveProfile.JOYSTICK_OPACITY_MAX
	)


func _draw() -> void:
	# N9-15 (owner direction): nothing renders while untouched — the stick
	# appears only under an active drag, at the actual touch origin anywhere
	# on screen (no clip_contents, so drawing outside this control's rect is
	# fine). The FTUE move hint anchors to this control's RECT, not to any
	# drawn pad, so it still points at the right place.
	# N6-5: neutral overlay tones — the wood family is reserved for real buttons.
	if _touch_index == -1:
		return
	var opacity: float = _opacity()
	var center: Vector2 = _origin - global_position
	# Resweep play R15: the knob went ceramic while the base stayed a flat
	# circle with a hairline ring — the pad now draws the same kit disc,
	# dimmed well below the knob so the pair reads as base and handle.
	var base: Texture2D = UiIcons.kit_texture("disc_0")
	if base != null:
		var base_size := Vector2.ONE * BASE_RADIUS * 2.0
		draw_texture_rect(
			base, Rect2(center - base_size / 2.0, base_size), false,
			Color(BASE_DISC_DIM, BASE_DISC_DIM, BASE_DISC_DIM, BASE_ALPHA * opacity)
		)
	else:
		draw_circle(
			center, BASE_RADIUS, Color(UiPalette.JOYSTICK_BASE, BASE_ALPHA * opacity)
		)
		draw_arc(
			center, BASE_RADIUS - RING_WIDTH / 2.0, 0.0, TAU, RING_POINT_COUNT,
			Color(UiPalette.JOYSTICK_RING, RING_ALPHA * opacity), RING_WIDTH
		)
	# F21: the grey disc was the last un-chromed control on screen. The kit's
	# ceramic disc is the knob now — still quiet next to the wood buttons,
	# but of the same material world. The flat circle stays as the fallback.
	var knob: Texture2D = UiIcons.kit_texture("disc_0")
	if knob != null:
		var knob_size := Vector2.ONE * KNOB_RADIUS * 2.0
		draw_texture_rect(
			knob, Rect2(center + _knob_offset - knob_size / 2.0, knob_size),
			false, Color(1.0, 1.0, 1.0, KNOB_ALPHA * opacity)
		)
	else:
		draw_circle(
			center + _knob_offset, KNOB_RADIUS,
			Color(UiPalette.JOYSTICK_KNOB, KNOB_ALPHA * opacity)
		)
