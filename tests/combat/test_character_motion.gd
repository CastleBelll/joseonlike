extends RefCounted
## Procedural motion replaces animation frames, so its integer contract is the
## thing that must not drift: fractional offsets or a wrong direction bucket are
## exactly the failures the asset report rejected generated frames for.

const MotionScript = preload("res://scripts/combat/character_motion.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(_test_direction_buckets())
	failures.append_array(_test_idle_cycle())
	failures.append_array(_test_walk_cycle_and_mirror())
	failures.append_array(_test_all_offsets_are_whole_pixels())
	failures.append_array(_test_recoil())
	return failures


func _test_direction_buckets() -> Array[String]:
	# Screen space: +y is down, so (0,-1) is north.
	var cases: Dictionary = {
		"east": Vector2(1, 0),
		"south": Vector2(0, 1),
		"west": Vector2(-1, 0),
		"north": Vector2(0, -1),
		"south-east": Vector2(1, 1),
		"south-west": Vector2(-1, 1),
		"north-east": Vector2(1, -1),
		"north-west": Vector2(-1, -1),
	}
	var failures: Array[String] = []
	for expected: Variant in cases.keys():
		var actual: String = MotionScript.direction_name(cases[expected])
		if actual != String(expected):
			failures.append("direction for %s: expected %s, got %s" % [cases[expected], expected, actual])
	# A vector just off an axis must not flip to the neighbouring rotation.
	if MotionScript.direction_name(Vector2(1.0, 0.2)) != "east":
		failures.append("a shallow angle should stay on the nearest rotation")
	# No input means no direction to read.
	if MotionScript.direction_name(Vector2.ZERO) != MotionScript.DEFAULT_DIRECTION:
		failures.append("zero vector should fall back to the default rotation")
	return failures


func _test_idle_cycle() -> Array[String]:
	var failures: Array[String] = []
	# 4 Hz: one frame every 0.25s, cycling [0, -1, -1, 0] on y.
	var expected: Array[int] = [0, -1, -1, 0]
	for index in expected.size():
		var at: float = float(index) * 0.25 + 0.01
		var offset: Vector2i = MotionScript.idle_offset(at)
		if offset.y != expected[index]:
			failures.append("idle frame %d: expected y=%d, got y=%d" % [index, expected[index], offset.y])
		if offset.x != 0:
			failures.append("idle must never move x, got x=%d" % offset.x)
	# The cycle repeats rather than running off the end of the array.
	if MotionScript.idle_offset(1.01) != MotionScript.idle_offset(0.01):
		failures.append("idle cycle should wrap after 1s at 4 Hz")
	return failures


func _test_walk_cycle_and_mirror() -> Array[String]:
	var failures: Array[String] = []
	# 8 Hz: one frame every 0.125s.
	var first_step: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 0)]
	for index in first_step.size():
		var at: float = float(index) * 0.125 + 0.01
		var offset: Vector2i = MotionScript.walk_offset(at)
		if offset != first_step[index]:
			failures.append("walk frame %d: expected %s, got %s" % [index, first_step[index], offset])
	# The second step mirrors x so the two strides differ.
	var second_step: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]
	for index in second_step.size():
		var at: float = 0.5 + float(index) * 0.125 + 0.01
		var offset: Vector2i = MotionScript.walk_offset(at)
		if offset != second_step[index]:
			failures.append("mirrored walk frame %d: expected %s, got %s" % [index, second_step[index], offset])
	# The third step returns to the original x sequence.
	if MotionScript.walk_offset(1.01) != MotionScript.walk_offset(0.01):
		failures.append("walk should return to the unmirrored step after two steps")
	return failures


## The whole point of the procedural approach: no subpixel motion anywhere.
func _test_all_offsets_are_whole_pixels() -> Array[String]:
	var failures: Array[String] = []
	for offset: Vector2i in MotionScript.IDLE_OFFSETS:
		if absi(offset.x) > 1 or absi(offset.y) > 1:
			failures.append("idle offset %s exceeds one pixel" % offset)
	for offset: Vector2i in MotionScript.WALK_OFFSETS:
		if absi(offset.x) > 1 or absi(offset.y) > 1:
			failures.append("walk offset %s exceeds one pixel" % offset)
	if MotionScript.DIRECTION_NAMES.size() != MotionScript.DIRECTION_COUNT:
		failures.append("expected %d rotations" % MotionScript.DIRECTION_COUNT)
	return failures


func _test_recoil() -> Array[String]:
	var failures: Array[String] = []
	if MotionScript.recoil_offset(Vector2.RIGHT) != Vector2i(-1, 0):
		failures.append("recoil should push opposite the aim")
	if MotionScript.recoil_offset(Vector2.UP) != Vector2i(0, 1):
		failures.append("recoil should push opposite an upward aim")
	if MotionScript.recoil_offset(Vector2.ZERO) != Vector2i.ZERO:
		failures.append("no aim means no recoil")
	var diagonal: Vector2i = MotionScript.recoil_offset(Vector2(1, 1))
	if absi(diagonal.x) > 1 or absi(diagonal.y) > 1:
		failures.append("recoil must stay within one pixel, got %s" % diagonal)
	return failures
