extends RefCounted
## CombatMath.chain_target_indices: nearest-first order, hit-target exclusion,
## range bound, and the max-target cap.

const CombatMathScript = preload("res://scripts/combat/combat_math.gd")

const RANGE_PX: float = 140.0


func run() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(_test_nearest_first_and_capped())
	failures.append_array(_test_excludes_hit_target_and_out_of_range())
	failures.append_array(_test_degenerate_inputs())
	return failures


func _test_nearest_first_and_capped() -> Array[String]:
	var failures: Array[String] = []
	# index 0 = the hit enemy at origin; 1..4 at increasing distance.
	var positions := PackedVector2Array([
		Vector2.ZERO, Vector2(120, 0), Vector2(30, 0), Vector2(60, 0), Vector2(90, 0),
	])

	var picked: PackedInt32Array = CombatMathScript.chain_target_indices(
		Vector2.ZERO, positions, 0, 2, RANGE_PX)

	if picked != PackedInt32Array([2, 3]):
		failures.append("expected the two nearest [2, 3], got %s" % [picked])
	return failures


func _test_excludes_hit_target_and_out_of_range() -> Array[String]:
	var failures: Array[String] = []
	var positions := PackedVector2Array([
		Vector2.ZERO, Vector2(500, 0), Vector2(100, 0),
	])

	var picked: PackedInt32Array = CombatMathScript.chain_target_indices(
		Vector2.ZERO, positions, 0, 5, RANGE_PX)

	if picked.has(0):
		failures.append("the hit enemy itself was chained")
	if picked.has(1):
		failures.append("an enemy beyond range_px was chained")
	if not picked.has(2):
		failures.append("an in-range enemy was skipped")
	return failures


func _test_degenerate_inputs() -> Array[String]:
	var failures: Array[String] = []
	var positions := PackedVector2Array([Vector2(10, 0)])

	if not CombatMathScript.chain_target_indices(Vector2.ZERO, positions, -1, 0, RANGE_PX).is_empty():
		failures.append("zero max_targets must chain nothing")
	if not CombatMathScript.chain_target_indices(Vector2.ZERO, positions, -1, 3, 0.0).is_empty():
		failures.append("zero range must chain nothing")
	if not CombatMathScript.chain_target_indices(Vector2.ZERO, PackedVector2Array(), -1, 3, RANGE_PX).is_empty():
		failures.append("no candidates must chain nothing")
	return failures
