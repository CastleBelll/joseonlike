extends RefCounted
## Procedural motion replaces animation frames, so its integer contract is the
## thing that must not drift: fractional offsets or a wrong direction bucket are
## exactly the failures the asset report rejected generated frames for.

const MotionScript = preload("res://scripts/combat/character_motion.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(_test_direction_buckets())
	failures.append_array(_test_idle_cycle())
	failures.append_array(_test_walk_cycle_is_pinned())
	failures.append_array(_test_recoil_never_composes())
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


## Pins idle exactly. It was retuned after a player reported that standing still
## read as drifting, so the property that matters is not just the amplitude but
## how much of the cycle sits at rest: a hover is a cycle that is rarely home.
func _test_idle_cycle() -> Array[String]:
	var failures: Array[String] = []
	# 2 Hz: one frame every 0.5s, cycling [0, 0, -1, 0] on y.
	var expected: Array[int] = [0, 0, -1, 0]
	if not is_equal_approx(MotionScript.IDLE_HZ, 2.0):
		failures.append("idle should run at 2 Hz, got %f" % MotionScript.IDLE_HZ)
	for index in expected.size():
		var at: float = float(index) * 0.5 + 0.01
		var offset: Vector2i = MotionScript.idle_offset(at)
		if offset.y != expected[index]:
			failures.append("idle frame %d: expected y=%d, got y=%d" % [index, expected[index], offset.y])
		if offset.x != 0:
			failures.append("idle must never move x, got x=%d" % offset.x)

	# At rest for most of the cycle. Half or more lifted is what read as hovering.
	var resting: int = 0
	for offset: Vector2i in MotionScript.IDLE_OFFSETS:
		if offset == Vector2i.ZERO:
			resting += 1
	if resting < 3:
		failures.append("idle should sit at rest for at least 3 of 4 frames, got %d" % resting)

	# Idle must stay gentler than the walk hop, which is the visible one.
	var idle_peak: int = 0
	var walk_peak: int = 0
	for offset: Vector2i in MotionScript.IDLE_OFFSETS:
		idle_peak = maxi(idle_peak, absi(offset.y))
	for offset: Vector2i in MotionScript.WALK_OFFSETS:
		walk_peak = maxi(walk_peak, absi(offset.y))
	if idle_peak >= walk_peak:
		failures.append("idle peak %d should stay under the walk peak %d" % [idle_peak, walk_peak])

	# The cycle repeats rather than running off the end of the array.
	if MotionScript.idle_offset(2.01) != MotionScript.idle_offset(0.01):
		failures.append("idle cycle should wrap after 2s at 2 Hz")
	return failures


## Pins the walk cycle exactly. These four values are the whole animation, and
## the last version of them was invisible in play, so a silent drift here is a
## silent regression to something nobody can see.
func _test_walk_cycle_is_pinned() -> Array[String]:
	var failures: Array[String] = []
	# 8 Hz: one frame every 0.125s. Vertical hop, every frame moving.
	var expected: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(0, -1), Vector2i(0, -2), Vector2i(0, -1),
	]
	if MotionScript.WALK_OFFSETS != expected:
		failures.append("walk cycle changed: expected %s, got %s" % [expected, MotionScript.WALK_OFFSETS])

	for index in expected.size():
		var at: float = float(index) * 0.125 + 0.01
		var offset: Vector2i = MotionScript.walk_offset(at)
		if offset != expected[index]:
			failures.append("walk frame %d: expected %s, got %s" % [index, expected[index], offset])

	# Horizontal motion is masked by the hunter travelling 11.25 px per frame, so
	# the walk must never spend a frame on x again.
	for offset: Vector2i in MotionScript.WALK_OFFSETS:
		if offset.x != 0:
			failures.append("walk must stay on the vertical axis, got x=%d" % offset.x)

	# Amplitude is the thing that makes it visible; 1 px was not enough.
	var lowest: int = 0
	for offset: Vector2i in MotionScript.WALK_OFFSETS:
		lowest = mini(lowest, offset.y)
	if lowest != -MotionScript.MAX_OFFSET_PX:
		failures.append("walk amplitude should be %d px, got %d" % [MotionScript.MAX_OFFSET_PX, -lowest])

	# Every frame must differ from the one before, or the hop stalls visibly.
	for index in expected.size():
		var here: Vector2i = MotionScript.WALK_OFFSETS[index]
		var next: Vector2i = MotionScript.WALK_OFFSETS[(index + 1) % expected.size()]
		if here == next:
			failures.append("walk frames %d and %d are identical" % [index, (index + 1) % expected.size()])

	if MotionScript.walk_offset(0.5 + 0.01) != MotionScript.walk_offset(0.01):
		failures.append("walk cycle should repeat every 0.5s at 8 Hz")
	return failures


## Recoil replaces the cycle offset; it must never add to it.
func _test_recoil_never_composes() -> Array[String]:
	var failures: Array[String] = []
	var recoil := Vector2i(1, 1)
	# Sampled at the peak of the hop, where composing would give (1, -1).
	var at_peak: float = 0.25 + 0.01
	if MotionScript.walk_offset(at_peak) != Vector2i(0, -2):
		failures.append("test picked the wrong sample point for the hop peak")
	var composed: Vector2i = MotionScript.sprite_offset(at_peak, true, recoil, true)
	if composed != recoil:
		failures.append("recoil should replace the cycle offset, expected %s got %s" % [recoil, composed])

	# And with no recoil active the cycle is untouched.
	var plain: Vector2i = MotionScript.sprite_offset(at_peak, true, recoil, false)
	if plain != Vector2i(0, -2):
		failures.append("without recoil the walk offset should pass through, got %s" % plain)
	if MotionScript.sprite_offset(0.01, false, Vector2i.ZERO, false) != MotionScript.idle_offset(0.01):
		failures.append("standing still should use the idle cycle")

	# Whatever the combination, one tick can never move more than the cap.
	for is_walking: bool in [true, false]:
		for step in 8:
			var sample: float = float(step) * 0.125 + 0.01
			var offset: Vector2i = MotionScript.sprite_offset(sample, is_walking, recoil, step % 2 == 0)
			if absi(offset.x) > MotionScript.MAX_OFFSET_PX or absi(offset.y) > MotionScript.MAX_OFFSET_PX:
				failures.append("offset %s exceeds the %d px cap" % [offset, MotionScript.MAX_OFFSET_PX])
	return failures


## The whole point of the procedural approach: no subpixel motion anywhere.
func _test_all_offsets_are_whole_pixels() -> Array[String]:
	var failures: Array[String] = []
	for offset: Vector2i in MotionScript.IDLE_OFFSETS:
		if absi(offset.x) > 1 or absi(offset.y) > 1:
			failures.append("idle offset %s exceeds one pixel" % offset)
	for offset: Vector2i in MotionScript.WALK_OFFSETS:
		if absi(offset.x) > MotionScript.MAX_OFFSET_PX or absi(offset.y) > MotionScript.MAX_OFFSET_PX:
			failures.append("walk offset %s exceeds %d px" % [offset, MotionScript.MAX_OFFSET_PX])
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
