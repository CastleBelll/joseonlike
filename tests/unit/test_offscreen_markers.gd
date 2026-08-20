extends RefCounted
## Guards the N9-57 edge-arrow placement (OffscreenMarkers). Field passives sit
## beyond the screen on purpose, so these arrows are the only thing that says
## they exist — placement that is subtly wrong points the player at nothing.

const EPSILON := 0.01
## The project's portrait resolution.
const SCREEN := Vector2(540.0, 960.0)


func test_a_target_already_on_screen_needs_no_arrow() -> bool:
	var bounds: Rect2 = OffscreenMarkers.marker_bounds(SCREEN)
	var inside: Vector2 = bounds.position + bounds.size / 2.0 + Vector2(20.0, 20.0)
	return not bool(OffscreenMarkers.edge_marker(inside, bounds)["needed"])


func test_arrow_lands_on_the_bound_the_target_lies_past() -> bool:
	var bounds := Rect2(Vector2.ZERO, Vector2(200.0, 100.0))
	# Straight out to the right: the arrow belongs on the right edge, level
	# with the centre.
	var marker: Dictionary = OffscreenMarkers.edge_marker(Vector2(900.0, 50.0), bounds)
	var at: Vector2 = marker["at"]
	return bool(marker["needed"]) and absf(at.x - 200.0) < EPSILON \
		and absf(at.y - 50.0) < EPSILON


func test_arrow_points_at_the_target() -> bool:
	var bounds := Rect2(Vector2.ZERO, Vector2(200.0, 200.0))
	var marker: Dictionary = OffscreenMarkers.edge_marker(Vector2(100.0, -400.0), bounds)
	# Straight up from the centre.
	return absf(float(marker["angle"]) - (-PI / 2.0)) < EPSILON


func test_diagonal_target_stops_at_the_nearer_bound() -> bool:
	# A wide, short rect: this target leaves through the TOP, not the side, and
	# an arrow parked on the side edge would point off the screen.
	var bounds := Rect2(Vector2.ZERO, Vector2(400.0, 100.0))
	var marker: Dictionary = OffscreenMarkers.edge_marker(Vector2(600.0, -450.0), bounds)
	var at: Vector2 = marker["at"]
	return absf(at.y) < EPSILON and at.x > 0.0 and at.x < 400.0


func test_arrow_never_leaves_the_bounds() -> bool:
	# Every direction, well outside: each arrow has to stay inside the rect it
	# was given, or it draws under the HUD or off the screen entirely.
	var bounds: Rect2 = OffscreenMarkers.marker_bounds(SCREEN)
	var centre: Vector2 = bounds.position + bounds.size / 2.0
	for i: int in range(32):
		var target: Vector2 = centre + Vector2.from_angle(TAU * float(i) / 32.0) * 5000.0
		var at: Vector2 = OffscreenMarkers.edge_marker(target, bounds)["at"]
		# grow() absorbs the float error of landing exactly on an edge.
		if not bounds.grow(EPSILON).has_point(at):
			return false
	return true


func test_marker_bounds_stay_clear_of_the_hud() -> bool:
	var bounds: Rect2 = OffscreenMarkers.marker_bounds(SCREEN)
	# The active-skill buttons live at the bottom; the timer and bars at the top.
	return bounds.position.y >= OffscreenMarkers.TOP_INSET \
		and bounds.end.y <= SCREEN.y - OffscreenMarkers.BOTTOM_INSET \
		and bounds.position.x >= OffscreenMarkers.EDGE_MARGIN \
		and bounds.end.x <= SCREEN.x - OffscreenMarkers.EDGE_MARGIN


func test_marker_bounds_survive_a_degenerate_screen() -> bool:
	# A zero-size viewport happens for one frame during setup; a negative rect
	# would put every arrow somewhere nonsensical.
	var bounds: Rect2 = OffscreenMarkers.marker_bounds(Vector2.ZERO)
	return bounds.size.x > 0.0 and bounds.size.y > 0.0


func test_distance_fades_but_never_disappears() -> bool:
	var near: float = OffscreenMarkers.distance_alpha(0.0)
	var far: float = OffscreenMarkers.distance_alpha(100000.0)
	return absf(near - 1.0) < EPSILON and absf(far - OffscreenMarkers.MIN_ALPHA) < EPSILON


func test_distance_alpha_is_monotonic() -> bool:
	var previous: float = 2.0
	for step: int in range(20):
		var alpha: float = OffscreenMarkers.distance_alpha(float(step) * 150.0)
		if alpha > previous + EPSILON:
			return false
		previous = alpha
	return true


func test_target_at_the_exact_centre_is_not_an_arrow() -> bool:
	# A zero-length direction has no angle; drawing it would be an arrow
	# pointing at an arbitrary heading.
	var bounds := Rect2(Vector2.ZERO, Vector2(100.0, 100.0))
	return not bool(OffscreenMarkers.edge_marker(Vector2(50.0, 50.0), bounds)["needed"])


## N9-63 motion (owner: "지금은 너무 정적이네"). The arrow moves, but its job is
## still to point at something — so what is asserted is that the sway stays
## SMALL. An arrow free to swing past its target is worse than a still one.
func test_sway_never_leaves_its_bearing() -> bool:
	var worst: float = 0.0
	for step: int in range(200):
		var angle: float = OffscreenMarkers.wobble_angle(float(step) * 0.037, 0.0)
		worst = maxf(worst, absf(angle))
	# A quarter turn would let the arrow point at open field.
	return worst <= OffscreenMarkers.WOBBLE_MAX_RAD + EPSILON and worst < PI / 4.0


func test_sway_actually_moves() -> bool:
	# The whole point of the change: a constant would be the static arrow the
	# owner rejected.
	var seen_low: bool = false
	var seen_high: bool = false
	for step: int in range(200):
		var angle: float = OffscreenMarkers.wobble_angle(float(step) * 0.037, 0.0)
		if angle < -OffscreenMarkers.WOBBLE_MAX_RAD * 0.8:
			seen_low = true
		if angle > OffscreenMarkers.WOBBLE_MAX_RAD * 0.8:
			seen_high = true
	return seen_low and seen_high


func test_bob_stays_within_a_few_pixels() -> bool:
	var worst: float = 0.0
	for step: int in range(200):
		worst = maxf(worst, absf(OffscreenMarkers.bob_offset(float(step) * 0.041, 0.0)))
	return worst <= OffscreenMarkers.BOB_PX + EPSILON


func test_arrows_do_not_move_in_lockstep() -> bool:
	# Identical motion on every arrow reads as one animated ornament rather
	# than as several separate things out there.
	var first: float = OffscreenMarkers.wobble_angle(0.5, 0.0)
	var second: float = OffscreenMarkers.wobble_angle(0.5, OffscreenMarkers.PHASE_STEP)
	return absf(first - second) > 0.01


func test_motion_is_centred_on_zero() -> bool:
	# A biased sway would leave every arrow permanently mis-aimed to one side.
	# Averaged over WHOLE periods. Any other window leaves part of a cycle
	# hanging and the mean drifts for reasons that have nothing to do with bias.
	var period: float = 1.0 / OffscreenMarkers.WOBBLE_HZ
	var samples: int = 900
	var total: float = 0.0
	for step: int in range(samples):
		total += OffscreenMarkers.wobble_angle(
			period * 3.0 * float(step) / float(samples), 0.0
		)
	return absf(total / float(samples)) < 0.01
