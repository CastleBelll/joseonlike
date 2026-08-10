extends RefCounted
## Spawner wave scheduling against a synthetic stage dictionary.

const WaveScheduleScript = preload("res://scripts/combat/wave_schedule.gd")
const Fixtures = preload("res://tests/combat/fixtures/combat_fixtures.gd")

const EPSILON: float = 0.0001


func run() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(_test_expansion())
	failures.append_array(_test_cursor_walk())
	failures.append_array(_test_malformed_waves())
	return failures


func _test_expansion() -> Array[String]:
	var stage_data: Dictionary = Fixtures.stage_with_waves()
	var events: Array[Dictionary] = WaveScheduleScript.expand(stage_data["waves"])
	var failures: Array[String] = []

	# 3 goblins from t=0 every 2s, plus 2 late goblins from t=10 every 5s.
	if events.size() != 5:
		failures.append("expected 5 spawn events, got %d" % events.size())
		return failures

	var expected_times: Array[float] = [0.0, 2.0, 4.0, 10.0, 15.0]
	for index in expected_times.size():
		var actual: float = float(events[index][WaveScheduleScript.KEY_TIME_SEC])
		if absf(actual - expected_times[index]) > EPSILON:
			failures.append("event %d: expected t=%f, got t=%f" % [index, expected_times[index], actual])

	# Waves are declared out of order in the fixture; expansion must sort them.
	if String(events[0][WaveScheduleScript.KEY_MONSTER_ID]) != "test_goblin":
		failures.append("earliest event should belong to the earliest wave")
	if String(events[4][WaveScheduleScript.KEY_MONSTER_ID]) != "late_goblin":
		failures.append("latest event should belong to the later wave")
	return failures


func _test_cursor_walk() -> Array[String]:
	var events: Array[Dictionary] = WaveScheduleScript.expand(Fixtures.stage_with_waves()["waves"])
	var failures: Array[String] = []

	# The t=0 event is due on the very first tick.
	if WaveScheduleScript.count_due(events, 0, 0.0) != 1:
		failures.append("t=0 event should be due immediately")
	if WaveScheduleScript.count_due(events, 0, 4.0) != 3:
		failures.append("three events should be due by t=4")
	# Already-consumed events must not be counted again.
	if WaveScheduleScript.count_due(events, 3, 60.0) != 2:
		failures.append("cursor should skip events already spawned")
	if WaveScheduleScript.count_due(events, 5, 600.0) != 0:
		failures.append("an exhausted schedule should report nothing due")
	if WaveScheduleScript.count_due(events, 0, -1.0) != 0:
		failures.append("nothing is due before the run starts")
	return failures


func _test_malformed_waves() -> Array[String]:
	var failures: Array[String] = []
	var waves: Array = [
		{"at_sec": 1.0, "monster_id": "", "count": 5, "interval_sec": 1.0},
		{"at_sec": 1.0, "monster_id": "ghost", "count": 0, "interval_sec": 1.0},
		{"at_sec": 1.0, "monster_id": "ghost", "count": 2},
	]
	var events: Array[Dictionary] = WaveScheduleScript.expand(waves)
	# Only the last wave contributes; a missing interval falls back to the minimum.
	if events.size() != 2:
		failures.append("expected 2 events from malformed waves, got %d" % events.size())
		return failures
	if float(events[1][WaveScheduleScript.KEY_TIME_SEC]) <= float(events[0][WaveScheduleScript.KEY_TIME_SEC]):
		failures.append("a missing interval_sec must still separate spawns")
	if not WaveScheduleScript.expand([]).is_empty():
		failures.append("a stage with no waves should produce no events")
	return failures
