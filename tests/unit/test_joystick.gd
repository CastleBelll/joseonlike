extends RefCounted
## Guards the N6-4 floating-joystick stick math (TouchJoystick statics):
## the origin anchors at the touch point, the knob clamps to the base radius,
## and the output is the unit-disc move vector the player consumes.

const EPSILON := 0.001
const RADIUS := 60.0


func test_knob_follows_touch_inside_radius() -> bool:
	var origin := Vector2(400.0, 300.0)
	var offset: Vector2 = TouchJoystick.knob_offset(origin, origin + Vector2(30.0, 0.0), RADIUS)
	return (offset - Vector2(30.0, 0.0)).length() < EPSILON


func test_knob_clamps_to_base_radius() -> bool:
	var origin := Vector2(100.0, 700.0)
	var offset: Vector2 = TouchJoystick.knob_offset(origin, origin + Vector2(200.0, 0.0), RADIUS)
	return (offset - Vector2(RADIUS, 0.0)).length() < EPSILON


func test_clamp_preserves_drag_direction() -> bool:
	var origin := Vector2(50.0, 50.0)
	var offset: Vector2 = TouchJoystick.knob_offset(origin, origin + Vector2(300.0, 300.0), RADIUS)
	var expected: Vector2 = Vector2(300.0, 300.0).normalized() * RADIUS
	return (offset - expected).length() < EPSILON


func test_output_is_unit_normalized() -> bool:
	var origin := Vector2(270.0, 480.0)
	# Half-radius pull reads as half speed; a beyond-radius pull caps at 1.
	var half: Vector2 = TouchJoystick.output_vector(origin, origin + Vector2(0.0, 30.0), RADIUS)
	var capped: Vector2 = TouchJoystick.output_vector(origin, origin + Vector2(0.0, 500.0), RADIUS)
	return (half - Vector2(0.0, 0.5)).length() < EPSILON \
		and absf(capped.length() - 1.0) < EPSILON


func test_output_zero_at_origin_and_degenerate_radius() -> bool:
	var origin := Vector2(10.0, 10.0)
	var still: Vector2 = TouchJoystick.output_vector(origin, origin, RADIUS)
	var degenerate: Vector2 = TouchJoystick.output_vector(origin, origin + Vector2.ONE, 0.0)
	return still == Vector2.ZERO and degenerate == Vector2.ZERO
