extends RefCounted
## Guards the N9-60 endless-night escalation (Endless). The mode cannot be
## played to its interesting part in a test, so what is checked is the shape of
## the curve and the two ways it could quietly break: a loop that arms no waves
## at all, and one that replays the gentle opening forever.

const EPSILON := 0.001

const CONFIG: Dictionary = {
	"loop_from_sec": 120.0,
	"loop_period_sec": 180.0,
	"count_growth_per_loop": 0.25,
	"hp_growth_per_loop": 0.45,
	"damage_growth_per_loop": 0.3,
	"boss_repeat_sec": 220.0,
}

const WAVES: Array = [
	{"at_sec": 0.0, "monster_id": "a", "count": 10, "interval_sec": 0.7},
	{"at_sec": 120.0, "monster_id": "b", "count": 8, "interval_sec": 1.0},
	{"at_sec": 240.0, "monster_id": "c", "count": 4, "interval_sec": 2.0},
]


func test_only_the_flagged_run_length_is_endless() -> bool:
	return Endless.is_endless({"endless": true}) \
		and not Endless.is_endless({"duration_scale": 1.0})


func test_the_first_pass_is_loop_zero() -> bool:
	# Before the loop point the night is the stage exactly as written.
	return Endless.loop_index(0.0, CONFIG) == 0 \
		and Endless.loop_index(119.0, CONFIG) == 0


func test_loops_advance_one_period_at_a_time() -> bool:
	return Endless.loop_index(121.0, CONFIG) == 1 \
		and Endless.loop_index(299.0, CONFIG) == 1 \
		and Endless.loop_index(301.0, CONFIG) == 2


func test_loop_start_matches_the_index() -> bool:
	return absf(Endless.loop_start_sec(1, CONFIG) - 120.0) < EPSILON \
		and absf(Endless.loop_start_sec(3, CONFIG) - 480.0) < EPSILON


func test_growth_is_linear_not_exponential() -> bool:
	# Ten loops in, an exponential curve would be past 40x. Linear keeps the
	# long middle playable, which is the part an endless run is about.
	var third: float = Endless.loop_scale(3, 0.45)
	var tenth: float = Endless.loop_scale(10, 0.45)
	return absf(third - 2.35) < EPSILON and absf(tenth - 5.5) < EPSILON


func test_loop_scale_ignores_a_negative_growth() -> bool:
	return absf(Endless.loop_scale(4, -1.0) - 1.0) < EPSILON


func test_the_opening_never_replays() -> bool:
	# The 0s wave is the opening rush. Replaying it every loop would make an
	# endless night get EASIER as it went on.
	for wave: Dictionary in Endless.loop_waves(WAVES, CONFIG, 1):
		if String(wave["monster_id"]) == "a":
			return false
	return true


func test_looped_waves_are_retimed_into_their_loop() -> bool:
	var waves: Array[Dictionary] = Endless.loop_waves(WAVES, CONFIG, 2)
	# Loop 2 starts at 300s; the 120s wave is its first beat, the 240s wave
	# comes 120s later.
	return waves.size() == 2 \
		and absf(float(waves[0]["at_sec"]) - 300.0) < EPSILON \
		and absf(float(waves[1]["at_sec"]) - 420.0) < EPSILON


func test_looped_waves_carry_more_monsters_each_time() -> bool:
	var first: Array[Dictionary] = Endless.loop_waves(WAVES, CONFIG, 1)
	var fourth: Array[Dictionary] = Endless.loop_waves(WAVES, CONFIG, 4)
	# 8 -> round(8 * 1.25) = 10 -> round(8 * 2.0) = 16.
	return int(first[0]["count"]) == 10 and int(fourth[0]["count"]) == 16


func test_a_wave_never_scales_down_to_nothing() -> bool:
	# A count of 1 with rounding must still spawn something; a zero-count wave
	# is a beat the player waits through for no reason.
	var tiny: Array = [{"at_sec": 120.0, "monster_id": "b", "count": 1, "interval_sec": 1.0}]
	var zeroed: Dictionary = {"loop_from_sec": 120.0, "loop_period_sec": 60.0,
		"count_growth_per_loop": 0.0}
	return int(Endless.loop_waves(tiny, zeroed, 1)[0]["count"]) >= 1


func test_loop_zero_arms_nothing() -> bool:
	# Loop 0 IS the stage's own schedule; arming it again would double it.
	return Endless.loop_waves(WAVES, CONFIG, 0).is_empty()


func test_data_issues_catch_a_loop_that_would_be_silent() -> bool:
	var silent: Dictionary = {
		"endless": {
			"loop_from_sec": 9999.0, "loop_period_sec": 60.0, "boss_repeat_sec": 60.0,
			"hp_growth_per_loop": 0.1, "damage_growth_per_loop": 0.1,
			"count_growth_per_loop": 0.1,
		},
		"waves": WAVES,
	}
	return Endless.data_issues(silent, "x").size() == 1


func test_data_issues_require_the_growth_numbers() -> bool:
	# Omitted growth would play as a flat grind and nothing else would say so.
	var bare: Dictionary = {
		"endless": {"loop_from_sec": 120.0, "loop_period_sec": 60.0, "boss_repeat_sec": 60.0},
		"waves": WAVES,
	}
	return Endless.data_issues(bare, "x").size() == 3


func test_a_stage_without_the_block_is_exempt() -> bool:
	return Endless.data_issues({"waves": WAVES}, "x").is_empty()


func test_shipped_stage_and_run_length_agree() -> bool:
	# The endless run length must exist, and the stage it plays must declare a
	# loop — otherwise the option is selectable and does nothing.
	var stages: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/stages.json")
	)
	var difficulties: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/difficulties.json")
	)
	if stages is not Dictionary or difficulties is not Dictionary:
		return false
	var found: bool = false
	for raw: Variant in (difficulties as Dictionary).get("run_lengths", []):
		if raw is Dictionary and Endless.is_endless(raw):
			found = true
	var stage: Dictionary = (stages as Dictionary).get("bamboo_forest", {})
	return found and not (stage.get(Endless.FLAG, {}) as Dictionary).is_empty() \
		and Endless.data_issues(stage, "bamboo_forest").is_empty()
