extends RefCounted
## N4-2 guards: WeaponGrade ladder/multiplier math, the grade-up level-up
## choice, elite stat derivation (Enemy.derive_elite_stats) and the pacing
## invariants + soft-enrage ramp (RunFlow). Fixture dicts mirror the
## data/weapons.json "_grades" block, monsters.json and stages.json shapes.

const GRADES := {
	"ladder": ["common", "rare", "mythic"],
	"steps": {
		"rare": {"mult": {"damage": 2.0, "cooldown_sec": 0.5}},
		"mythic": {"mult": {"damage": 3.0}, "tinted": true},
	},
}
const WEAPONS := {
	"talisman": {
		"name_ko": "낡은 부적", "grade": "common", "damage": 12.0,
		"cooldown_sec": 1.2, "speed": 260.0, "max_level": 3,
		"per_level": {"damage": 3.0, "cooldown_sec": -0.2},
		"evolution_only": false,
	},
}
const BRUTE := {
	"name_ko": "죽림 거한", "hp": 85.0, "damage": 18.0, "speed": 70.0,
	"xp_drop": 8, "behaviour": "charger",
	"collision_radius": 18.5, "sprite": "res://asset/monsters/bamboo_brute",
}
const ELITE := {
	"name_ko": "정예 죽림 거한", "elite_of": "bamboo_brute", "hp_mult": 6.0,
	"damage_mult": 1.5, "speed_mult": 0.85, "size_mult": 1.6, "reward_mult": 6.0,
}
const ENRAGE := {
	"start_sec": 920.0, "ramp_sec": 120.0,
	"hp_mult_max": 3.0, "damage_mult_max": 2.5, "speed_mult_max": 1.3,
}


func _rungs() -> Array[String]:
	return WeaponGrade.ladder(GRADES)


func test_ladder_order_and_top() -> bool:
	var rungs: Array[String] = _rungs()
	return (
		rungs == (["common", "rare", "mythic"] as Array[String])
		and WeaponGrade.index_of(rungs, "rare") == 1
		and not WeaponGrade.is_top(rungs, "rare")
		and WeaponGrade.is_top(rungs, "mythic")
	)


func test_next_clamps_at_top() -> bool:
	var rungs: Array[String] = _rungs()
	return (
		WeaponGrade.next(rungs, "common") == "rare"
		and WeaponGrade.next(rungs, "rare") == "mythic"
		and WeaponGrade.next(rungs, "mythic") == "mythic"
	)


func test_unknown_grade_reads_as_bottom() -> bool:
	var rungs: Array[String] = _rungs()
	return (
		WeaponGrade.index_of(rungs, "no_such_grade") == 0
		and WeaponGrade.next(rungs, "no_such_grade") == "rare"
	)


func test_highest_picks_ladder_max() -> bool:
	var rungs: Array[String] = _rungs()
	return (
		WeaponGrade.highest(rungs, "rare", "common") == "rare"
		and WeaponGrade.highest(rungs, "common", "mythic") == "mythic"
		and WeaponGrade.highest(rungs, "rare", "rare") == "rare"
	)


func test_multiplier_compounds_steps_above_base() -> bool:
	return (
		is_equal_approx(WeaponGrade.multiplier(GRADES, "common", "rare", "damage"), 2.0)
		and is_equal_approx(WeaponGrade.multiplier(GRADES, "common", "mythic", "damage"), 6.0)
		and is_equal_approx(WeaponGrade.multiplier(GRADES, "rare", "mythic", "damage"), 3.0)
	)


func test_multiplier_is_one_at_or_below_base() -> bool:
	return (
		is_equal_approx(WeaponGrade.multiplier(GRADES, "common", "common", "damage"), 1.0)
		and is_equal_approx(WeaponGrade.multiplier(GRADES, "rare", "common", "damage"), 1.0)
		# mythic's step defines no cooldown factor — missing fields multiply by 1.
		and is_equal_approx(WeaponGrade.multiplier(GRADES, "rare", "mythic", "cooldown_sec"), 1.0)
	)


func test_stat_at_combines_level_curve_and_grade() -> bool:
	var stats: Dictionary = WEAPONS["talisman"]
	return (
		is_equal_approx(WeaponGrade.stat_at(stats, "damage", 2, "rare", GRADES), 30.0)
		and is_equal_approx(WeaponGrade.stat_at(stats, "damage", 1, "common", GRADES), 12.0)
		and is_equal_approx(WeaponGrade.stat_at(stats, "cooldown_sec", 1, "rare", GRADES), 0.6)
	)


func test_tinted_flag_only_from_active_steps() -> bool:
	return (
		WeaponGrade.has_flag(GRADES, "common", "mythic", "tinted")
		and not WeaponGrade.has_flag(GRADES, "common", "rare", "tinted")
		and not WeaponGrade.has_flag(GRADES, "mythic", "mythic", "tinted")
	)


func test_candidates_offer_grade_up_below_top_only() -> bool:
	var below: Array[Dictionary] = LevelUp.candidates(
		WEAPONS, {}, {"talisman": 1}, {}, {"talisman": "rare"}, GRADES
	)
	var at_top: Array[Dictionary] = LevelUp.candidates(
		WEAPONS, {}, {"talisman": 1}, {}, {"talisman": "mythic"}, GRADES
	)
	var count_grade_ups := func(pool: Array[Dictionary]) -> int:
		var found: int = 0
		for choice: Dictionary in pool:
			if String(choice["kind"]) == LevelUp.KIND_GRADE_UP:
				found += 1
		return found
	return count_grade_ups.call(below) == 1 and count_grade_ups.call(at_top) == 0


func test_grade_up_card_shows_next_grade_and_real_numbers() -> bool:
	var choice := {"kind": LevelUp.KIND_GRADE_UP, "id": "talisman"}
	var pill: String = LevelUp.grade_text(choice, WEAPONS, {}, GRADES)
	var desc: String = LevelUp.describe(choice, WEAPONS, {}, {"talisman": 1}, {}, {}, GRADES)
	return pill == "희귀" and desc == "등급 일반→희귀 · 피해 12→24"


func test_weapon_up_description_reflects_run_grade() -> bool:
	var choice := {"kind": LevelUp.KIND_WEAPON_UP, "id": "talisman"}
	var desc: String = LevelUp.describe(
		choice, WEAPONS, {}, {"talisman": 1}, {}, {"talisman": "rare"}, GRADES
	)
	return desc == "피해 24→30 · 쿨다운 0.6초→0.5초"


func test_elite_stats_derive_from_base() -> bool:
	var derived: Dictionary = Enemy.derive_elite_stats(BRUTE, ELITE)
	return (
		is_equal_approx(float(derived["hp"]), 510.0)
		and is_equal_approx(float(derived["damage"]), 27.0)
		and is_equal_approx(float(derived["speed"]), 59.5)
		and is_equal_approx(float(derived["collision_radius"]), 29.6)
		and int(derived["xp_drop"]) == 48
		and not derived.has("gold_drop")  # N6-5: monsters never carry gold
		and is_equal_approx(float(derived["size_scale"]), 1.6)
		and String(derived["name_ko"]) == "정예 죽림 거한"
	)


func test_elite_keeps_base_behaviour_and_sprite_and_inputs_unchanged() -> bool:
	var base: Dictionary = BRUTE.duplicate()
	var derived: Dictionary = Enemy.derive_elite_stats(base, ELITE)
	return (
		String(derived["behaviour"]) == "charger"
		and String(derived["sprite"]) == "res://asset/monsters/bamboo_brute"
		and base == BRUTE
	)


func test_real_stage_schedules_have_no_issues() -> bool:
	var stages: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/stages.json")
	)
	for stage_id: String in stages:
		if not RunFlow.schedule_issues(stages[stage_id]).is_empty():
			return false
	return not stages.is_empty()


func _valid_stage() -> Dictionary:
	return {
		"boss_at_sec": 900.0,
		"surge_at_sec": 840.0,
		"waves": [
			{"at_sec": 0, "monster_id": "a", "count": 5},
			{"at_sec": 840, "monster_id": "a", "count": 30},
			{"at_sec": 900, "monster_id": "a", "count": 10},
		],
		"soft_enrage": {"start_sec": 920.0},
	}


func test_schedule_valid_fixture_passes() -> bool:
	return RunFlow.schedule_issues(_valid_stage()).is_empty()


func test_schedule_flags_non_monotonic_times() -> bool:
	var stage: Dictionary = _valid_stage()
	(stage["waves"] as Array).insert(1, {"at_sec": 700, "monster_id": "a", "count": 1})
	(stage["waves"] as Array).insert(2, {"at_sec": 300, "monster_id": "a", "count": 1})
	return not RunFlow.schedule_issues(stage).is_empty()


func test_schedule_flags_wave_after_boss() -> bool:
	var stage: Dictionary = _valid_stage()
	(stage["waves"] as Array).append({"at_sec": 950, "monster_id": "a", "count": 1})
	return not RunFlow.schedule_issues(stage).is_empty()


func test_schedule_flags_surge_missing_or_not_peak() -> bool:
	var no_surge: Dictionary = _valid_stage()
	no_surge.erase("surge_at_sec")
	var beaten: Dictionary = _valid_stage()
	(beaten["waves"] as Array).append({"at_sec": 900, "monster_id": "a", "count": 40})
	var after_boss: Dictionary = _valid_stage()
	after_boss["surge_at_sec"] = 900.0
	return (
		not RunFlow.schedule_issues(no_surge).is_empty()
		and not RunFlow.schedule_issues(beaten).is_empty()
		and not RunFlow.schedule_issues(after_boss).is_empty()
	)


## N4-2b: the whole schedule must fit inside the data-declared run length —
## a boss or wave time past duration_sec is a data error, per stage.
func test_schedule_flags_times_beyond_duration() -> bool:
	var fits: Dictionary = _valid_stage()
	fits["duration_sec"] = 1080.0
	var late: Dictionary = _valid_stage()
	late["duration_sec"] = 890.0  # boss at 900 and waves at 900 both overshoot
	var beyond: int = 0
	for issue: String in RunFlow.schedule_issues(late):
		if issue.contains("exceeds duration_sec"):
			beyond += 1
	# One boss overshoot + the single 900s wave = exactly two flags.
	return RunFlow.schedule_issues(fits).is_empty() and beyond == 2


func test_schedule_flags_enrage_before_boss() -> bool:
	var stage: Dictionary = _valid_stage()
	stage["soft_enrage"] = {"start_sec": 800.0}
	return not RunFlow.schedule_issues(stage).is_empty()


func test_enrage_progress_ramps_from_start_to_full() -> bool:
	return (
		is_equal_approx(RunFlow.enrage_progress(900.0, ENRAGE), 0.0)
		and is_equal_approx(RunFlow.enrage_progress(980.0, ENRAGE), 0.5)
		and is_equal_approx(RunFlow.enrage_progress(2000.0, ENRAGE), 1.0)
		and is_equal_approx(RunFlow.enrage_progress(999.0, {}), 0.0)
	)


func test_enrage_stats_scale_a_copy_only() -> bool:
	var base := {"hp": 20.0, "damage": 6.0, "speed": 55.0}
	var full: Dictionary = RunFlow.enrage_stats(base, ENRAGE, 1.0)
	var half: Dictionary = RunFlow.enrage_stats(base, ENRAGE, 0.5)
	return (
		is_equal_approx(float(full["hp"]), 60.0)
		and is_equal_approx(float(full["damage"]), 15.0)
		and is_equal_approx(float(full["speed"]), 71.5)
		and is_equal_approx(float(half["hp"]), 40.0)
		and is_equal_approx(float(base["hp"]), 20.0)
	)
