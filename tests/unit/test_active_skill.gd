extends RefCounted
## N4-4b active-skill coverage: 축지 blink destination clamping (solid props,
## field bounds, standstill) and the cooldown display/gating contracts —
## through the pure ActiveSkill statics the stage runtime consumes.

const FIELD := Rect2(-1024.0, -1024.0, 2048.0, 2048.0)


func test_blink_travels_full_distance_when_clear() -> bool:
	var destination: Vector2 = ActiveSkill.blink_destination(
		Vector2.ZERO, Vector2.RIGHT, 140.0, INF, FIELD
	)
	return destination == Vector2(140.0, 0.0)


func test_blink_stops_at_the_blocking_prop() -> bool:
	var destination: Vector2 = ActiveSkill.blink_destination(
		Vector2.ZERO, Vector2.RIGHT, 140.0, 60.0, FIELD
	)
	return destination == Vector2(60.0, 0.0)


func test_blink_never_travels_backwards_on_point_blank_block() -> bool:
	var destination: Vector2 = ActiveSkill.blink_destination(
		Vector2(5.0, 5.0), Vector2.RIGHT, 140.0, -10.0, FIELD
	)
	return destination == Vector2(5.0, 5.0)


func test_blink_clamps_into_the_field_bounds() -> bool:
	var destination: Vector2 = ActiveSkill.blink_destination(
		Vector2(1000.0, 0.0), Vector2.RIGHT, 140.0, INF, FIELD
	)
	return destination == Vector2(1024.0, 0.0)


func test_blink_from_standstill_stays_put_on_zero_direction() -> bool:
	var from := Vector2(33.0, 44.0)
	return ActiveSkill.blink_destination(from, Vector2.ZERO, 140.0, INF, FIELD) == from


func test_cooldown_fraction_maps_left_time_to_display() -> bool:
	return (
		ActiveSkill.cooldown_fraction(8.0, 8.0) == 1.0
		and ActiveSkill.cooldown_fraction(4.0, 8.0) == 0.5
		and ActiveSkill.cooldown_fraction(0.0, 8.0) == 0.0
		and ActiveSkill.cooldown_fraction(9.0, 8.0) == 1.0
		and ActiveSkill.cooldown_fraction(1.0, 0.0) == 0.0
	)


## The stage gates triggers with the shared CombatMath window rule — ready
## exactly at the boundary, blocked one tick before it.
func test_cooldown_gate_uses_the_shared_window_rule() -> bool:
	return (
		CombatMath.can_hit(8.0, 8.0)
		and not CombatMath.can_hit(7.99, 8.0)
	)
