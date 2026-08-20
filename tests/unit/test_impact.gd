extends RefCounted
## Guards the N9-67 hit feel (Impact). Both effects are judged by eye in play,
## so what is pinned here is the part that ruins a run when it goes wrong: the
## rationing. Freeze on every hit is a slideshow; shake without a ceiling is
## nausea.

const EPSILON := 0.001

const CONFIG: Dictionary = {
	"hitstop": {"hit": 0.0, "crit": 0.045, "elite_kill": 0.07, "nuke": 0.11},
	"shake": {"max": 7.0, "decay_per_sec": 26.0, "hit": 0.0, "crit": 1.1, "kill": 0.8},
}


func test_an_ordinary_hit_never_freezes() -> bool:
	# The rule the whole design rests on: ordinary hits arrive dozens per
	# second and the sum of their freezes would be the frame rate.
	return Impact.hitstop_sec(CONFIG, Impact.HIT) == 0.0


func test_weightier_events_freeze_longer() -> bool:
	return Impact.hitstop_sec(CONFIG, Impact.CRIT) < Impact.hitstop_sec(CONFIG, Impact.NUKE)


func test_an_unknown_kind_is_silent_rather_than_a_crash() -> bool:
	return Impact.hitstop_sec(CONFIG, "meteor") == 0.0 \
		and Impact.shake_amount(CONFIG, "meteor") == 0.0


func test_shake_stops_at_the_ceiling() -> bool:
	# Twenty simultaneous kills must not sum into something unplayable.
	var shake: float = 0.0
	for _i: int in range(20):
		shake = Impact.added_shake(shake, Impact.shake_amount(CONFIG, Impact.KILL), CONFIG)
	return absf(shake - 7.0) < EPSILON


func test_shake_decays_to_nothing() -> bool:
	var shake: float = 7.0
	for _i: int in range(60):
		shake = Impact.decayed_shake(shake, 1.0 / 60.0, CONFIG)
	return shake == 0.0


func test_decay_never_goes_negative() -> bool:
	# A negative amount would flip the offset and shake the camera the wrong
	# way for as long as it lasted.
	return Impact.decayed_shake(0.1, 10.0, CONFIG) == 0.0


func test_the_setting_can_turn_shake_off_entirely() -> bool:
	return Impact.shake_offset(7.0, 1.23, 0.0) == Vector2.ZERO


func test_offset_stays_inside_the_amount() -> bool:
	# The offset is a jitter of at most `amount` px on each axis; more than
	# that and the field visibly leaves the screen.
	for step: int in range(200):
		var offset: Vector2 = Impact.shake_offset(7.0, float(step) * 0.013, 1.0)
		if absf(offset.x) > 7.0 + EPSILON or absf(offset.y) > 7.0 + EPSILON:
			return false
	return true


func test_the_two_axes_do_not_move_together() -> bool:
	# Equal frequencies would slide the camera along a diagonal, which reads as
	# drift rather than as a hit.
	var apart: bool = false
	for step: int in range(200):
		var offset: Vector2 = Impact.shake_offset(5.0, float(step) * 0.011, 1.0)
		if absf(offset.x - offset.y) > 1.0:
			apart = true
	return apart


func test_shipped_data_obeys_its_own_ceilings() -> bool:
	var data: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/effects.json")
	)
	if data is not Dictionary:
		return false
	return Impact.data_issues(
		(data as Dictionary).get("hit_feedback", {}), "effects.hit_feedback"
	).is_empty()


func test_data_issues_reject_a_freeze_on_every_hit() -> bool:
	var broken: Dictionary = {
		"hitstop": {"hit": 0.03},
		"shake": {"max": 5.0, "decay_per_sec": 20.0},
	}
	return Impact.data_issues(broken, "x").size() == 1


func test_data_issues_reject_a_hang_and_a_runaway_ceiling() -> bool:
	var broken: Dictionary = {
		"hitstop": {"hit": 0.0, "crit": 0.9},
		"shake": {"max": 90.0, "decay_per_sec": 20.0},
	}
	return Impact.data_issues(broken, "x").size() == 2


func test_data_issues_reject_shake_that_never_ends() -> bool:
	var broken: Dictionary = {
		"hitstop": {"hit": 0.0},
		"shake": {"max": 5.0, "decay_per_sec": 0.0},
	}
	return Impact.data_issues(broken, "x").size() == 1
