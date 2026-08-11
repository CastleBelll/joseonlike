extends RefCounted
## Target acquisition must stay inside the visible field.
##
## A player reported the talisman homing onto enemies off screen, which spends a
## projectile on something that gives no feedback. Both the firing weapon and the
## homing projectile acquire through CombatMath, so the bound lives there and
## this pins it for both.
##
## A rectangle, not a radius: the viewport is portrait, so at 540x960 the visible
## half-extents are 270 x 480 while a radius reaching the corners is 551. A
## radius would still acquire a target 551 px to the side, twice as far as the
## player can see horizontally, which is the reported bug surviving the fix.

const CombatMathScript = preload("res://scripts/combat/combat_math.gd")

## World rect for a 540x960 viewport centred on the origin.
const VIEW := Rect2(Vector2(-270, -480), Vector2(540, 960))


func run() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(_test_offscreen_targets_are_not_acquired())
	failures.append_array(_test_nearest_visible_still_wins())
	failures.append_array(_test_a_radius_would_not_have_been_enough())
	failures.append_array(_test_unbounded_without_a_viewport())
	return failures


func _test_offscreen_targets_are_not_acquired() -> Array[String]:
	var failures: Array[String] = []
	# Just outside each edge.
	var outside := PackedVector2Array([
		Vector2(400, 0), Vector2(-400, 0), Vector2(0, 600), Vector2(0, -600),
	])
	if CombatMathScript.nearest_index_in_bounds(Vector2.ZERO, outside, VIEW) != -1:
		failures.append("a target outside the visible field must not be acquired")
	# A far off-screen enemy must not beat having no target at all.
	var only_far := PackedVector2Array([Vector2(2000, 2000)])
	if CombatMathScript.nearest_index_in_bounds(Vector2.ZERO, only_far, VIEW) != -1:
		failures.append("a distant off-screen target must not be acquired")
	return failures


func _test_nearest_visible_still_wins() -> Array[String]:
	var failures: Array[String] = []
	# index 0 is closer but off screen; index 2 is the nearest visible one.
	var mixed := PackedVector2Array([Vector2(400, 0), Vector2(0, 300), Vector2(100, 0)])
	var picked: int = CombatMathScript.nearest_index_in_bounds(Vector2.ZERO, mixed, VIEW)
	if picked != 2:
		failures.append("should acquire the nearest VISIBLE target (index 2), got %d" % picked)
	return failures


## The specific failure a radius-based bound would still allow.
func _test_a_radius_would_not_have_been_enough() -> Array[String]:
	var failures: Array[String] = []
	var side := Vector2(400, 0)   # off screen horizontally, well inside a 551 radius
	if side.length() > 551.0:
		failures.append("test sample is outside the corner radius, so it proves nothing")
	if CombatMathScript.nearest_index_in_bounds(Vector2.ZERO, PackedVector2Array([side]), VIEW) != -1:
		failures.append("a target inside the corner radius but off screen must still be rejected")
	return failures


## Headless callers have no viewport; they must not be silently blinded.
func _test_unbounded_without_a_viewport() -> Array[String]:
	var rect: Rect2 = CombatMathScript.visible_world_rect(null, 32.0)
	if not rect.has_point(Vector2(9999, 9999)):
		return ["a null viewport should yield an unbounded rect, got %s" % rect]
	return []
