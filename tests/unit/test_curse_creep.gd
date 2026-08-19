extends RefCounted
## Guards the N9-30 살 creep geometry: the thread stays anchored on both
## corpses, hangs to one side in between, and never collapses onto the straight
## line a bolt would draw.

const EPSILON := 0.01


func test_the_thread_is_anchored_at_both_corpses() -> bool:
	var from := Vector2(100.0, 50.0)
	var to := Vector2(300.0, 90.0)
	# Both ends must land exactly, or the thread visibly detaches from the
	# enemy it is supposed to be crawling out of (or into).
	var start: Vector2 = CurseCreep.bead_point(from, to, 0.0, 40.0, 0.0)
	var end: Vector2 = CurseCreep.bead_point(from, to, 1.0, 40.0, 0.0)
	return start.distance_to(from) < EPSILON and end.distance_to(to) < EPSILON


func test_the_middle_hangs_off_the_straight_line() -> bool:
	var from := Vector2.ZERO
	var to := Vector2(200.0, 0.0)
	var middle: Vector2 = CurseCreep.bead_point(from, to, 0.5, 30.0, 0.0)
	# Straight across would be (100, 0); the sag is the whole difference
	# between a creep and 뇌부's bolt.
	return absf(middle.x - 100.0) < EPSILON and absf(absf(middle.y) - 30.0) < EPSILON


func test_the_sag_peaks_in_the_middle_and_never_at_the_ends() -> bool:
	var from := Vector2.ZERO
	var to := Vector2(200.0, 0.0)
	var quarter: float = absf(CurseCreep.bead_point(from, to, 0.25, 30.0, 0.0).y)
	var middle: float = absf(CurseCreep.bead_point(from, to, 0.5, 30.0, 0.0).y)
	var three_quarter: float = absf(CurseCreep.bead_point(from, to, 0.75, 30.0, 0.0).y)
	return middle > quarter and middle > three_quarter and quarter > 0.0


func test_a_negative_sag_curls_the_other_way() -> bool:
	var from := Vector2.ZERO
	var to := Vector2(200.0, 0.0)
	var up: float = CurseCreep.bead_point(from, to, 0.5, 30.0, 0.0).y
	var down: float = CurseCreep.bead_point(from, to, 0.5, -30.0, 0.0).y
	return signf(up) != signf(down) and absf(up) > EPSILON


func test_wobble_offsets_the_bead_without_moving_it_along_the_path() -> bool:
	var from := Vector2.ZERO
	var to := Vector2(200.0, 0.0)
	var plain: Vector2 = CurseCreep.bead_point(from, to, 0.5, 0.0, 0.0)
	var nudged: Vector2 = CurseCreep.bead_point(from, to, 0.5, 0.0, 5.0)
	# Perpendicular only, by the full amount: the crawl position along the
	# thread is unchanged. Magnitude, not sign — which side "perpendicular"
	# points is Vector2.orthogonal's convention, not this class's contract.
	return absf(nudged.x - plain.x) < EPSILON \
		and absf(absf(nudged.y - plain.y) - 5.0) < EPSILON


func test_a_zero_length_spread_does_not_produce_nan() -> bool:
	# Two enemies stacked exactly: the direction is degenerate, and a NaN here
	# would poison every draw call for the rest of the creep.
	var point: Vector2 = CurseCreep.bead_point(Vector2.ONE, Vector2.ONE, 0.5, 20.0, 1.0)
	return not (is_nan(point.x) or is_nan(point.y))
