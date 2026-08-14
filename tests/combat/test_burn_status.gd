extends RefCounted
## BurnStatus: refresh-not-stack application, chunked tick release, expiry
## remainder, and inert edge cases.

const STEP_SEC: float = 1.0 / 60.0
const EPSILON: float = 0.0001


func run() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(_test_total_damage_equals_dps_times_duration())
	failures.append_array(_test_no_damage_between_ticks())
	failures.append_array(_test_reapply_refreshes_not_stacks())
	failures.append_array(_test_inert_without_apply())
	failures.append_array(_test_invalid_apply_is_ignored())
	return failures


func _test_total_damage_equals_dps_times_duration() -> Array[String]:
	var failures: Array[String] = []
	var burn := BurnStatus.new()
	burn.apply(4.0, 3.0)

	var total: float = 0.0
	for _frame in int(4.0 / STEP_SEC):
		total += burn.advance(STEP_SEC)

	if absf(total - 12.0) > EPSILON:
		failures.append("4 dps for 3 s should deal 12 total, dealt %f" % total)
	if burn.is_active():
		failures.append("burn still active after its duration fully elapsed")
	return failures


func _test_no_damage_between_ticks() -> Array[String]:
	var failures: Array[String] = []
	var burn := BurnStatus.new()
	burn.apply(4.0, 3.0)

	# Frames strictly inside the first tick window release nothing.
	var frames_before_tick: int = int(BurnStatus.TICK_SEC / STEP_SEC) - 2
	for _frame in frames_before_tick:
		if burn.advance(STEP_SEC) > 0.0:
			failures.append("damage released before the first %.1f s tick" % BurnStatus.TICK_SEC)
			break
	return failures


func _test_reapply_refreshes_not_stacks() -> Array[String]:
	var failures: Array[String] = []
	var burn := BurnStatus.new()
	burn.apply(4.0, 3.0)
	burn.apply(2.0, 5.0)

	if absf(burn.dps - 4.0) > EPSILON:
		failures.append("weaker reapply lowered dps to %f" % burn.dps)
	if absf(burn.left_sec - 5.0) > EPSILON:
		failures.append("longer reapply did not extend duration (left %f)" % burn.left_sec)

	burn.apply(6.0, 1.0)
	if absf(burn.dps - 6.0) > EPSILON:
		failures.append("stronger reapply did not raise dps")
	if absf(burn.left_sec - 5.0) > EPSILON:
		failures.append("shorter reapply truncated the remaining duration")
	return failures


func _test_inert_without_apply() -> Array[String]:
	var burn := BurnStatus.new()
	if burn.is_active():
		return ["a fresh burn must be inactive"]
	if burn.advance(1.0) != 0.0:
		return ["an inactive burn dealt damage"]
	return []


func _test_invalid_apply_is_ignored() -> Array[String]:
	var burn := BurnStatus.new()
	burn.apply(0.0, 3.0)
	burn.apply(4.0, 0.0)
	burn.apply(-1.0, -1.0)
	if burn.is_active():
		return ["zero/negative applications must not activate a burn"]
	return []
