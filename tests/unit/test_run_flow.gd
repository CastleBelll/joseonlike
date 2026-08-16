extends RefCounted
## Guards the N5-1 pure run-flow logic (RunFlow): boss spawn timing from
## stage data, the outcome arbiter, and the result-screen summary.

const EPSILON := 0.001


func test_boss_spawn_time_uses_boss_at_sec() -> bool:
	var stage: Dictionary = {"duration_sec": 600, "boss_at_sec": 540}
	return absf(RunFlow.boss_spawn_time(stage) - 540.0) < EPSILON


func test_boss_spawn_time_falls_back_to_stage_end() -> bool:
	var stage: Dictionary = {"duration_sec": 600}
	return absf(RunFlow.boss_spawn_time(stage) - 600.0) < EPSILON


func test_boss_spawn_time_clamps_to_duration() -> bool:
	var stage: Dictionary = {"duration_sec": 600, "boss_at_sec": 900}
	return absf(RunFlow.boss_spawn_time(stage) - 600.0) < EPSILON


func test_boss_spawn_time_no_data_means_no_boss() -> bool:
	var stage: Dictionary = {}
	return RunFlow.boss_spawn_time(stage) == RunFlow.NO_BOSS


func test_boss_spawn_time_reads_real_stage_data() -> bool:
	var data: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/stages.json")
	)
	if data is not Dictionary:
		return false
	var stage: Dictionary = (data as Dictionary).get("bamboo_forest", {})
	var at: float = RunFlow.boss_spawn_time(stage)
	return at > 0.0 and at <= float(stage.get("duration_sec", 0.0))


func test_outcome_running_when_nothing_ended() -> bool:
	return RunFlow.resolve_outcome(false, false, false) == RunFlow.OUTCOME_NONE


func test_outcome_defeat_on_player_death() -> bool:
	return RunFlow.resolve_outcome(true, false, false) == RunFlow.OUTCOME_DEFEAT


func test_outcome_victory_on_boss_kill() -> bool:
	return RunFlow.resolve_outcome(false, true, false) == RunFlow.OUTCOME_VICTORY


func test_outcome_victory_on_timeout() -> bool:
	return RunFlow.resolve_outcome(false, false, true) == RunFlow.OUTCOME_VICTORY


func test_outcome_player_death_beats_simultaneous_boss_kill() -> bool:
	return RunFlow.resolve_outcome(true, true, true) == RunFlow.OUTCOME_DEFEAT


func test_summary_formats_time_and_totals() -> bool:
	var summary: Dictionary = RunFlow.build_summary(605.0, 123, 45)
	var time_ok: bool = String(summary["time_text"]) == "10:05"
	return time_ok and int(summary["kills"]) == 123 and int(summary["gold"]) == 45


func test_summary_zero_run_is_presentable() -> bool:
	var summary: Dictionary = RunFlow.build_summary(0.0, 0, 0)
	var time_ok: bool = String(summary["time_text"]) == "0:00"
	return time_ok and int(summary["kills"]) == 0 and int(summary["gold"]) == 0


func test_summary_carries_death_cause() -> bool:
	var summary: Dictionary = RunFlow.build_summary(10.0, 1, 2, "숲의 원혼")
	var default_summary: Dictionary = RunFlow.build_summary(10.0, 1, 2)
	return String(summary["death_cause"]) == "숲의 원혼" \
		and String(default_summary["death_cause"]) == ""


func test_death_cause_passes_named_killers_through() -> bool:
	# Ordinary monster, elite (derived name) and boss all come pre-localized.
	var passed: bool = RunFlow.death_cause_text("숲의 원혼") == "숲의 원혼"
	passed = passed and RunFlow.death_cause_text("정예 죽림 거한") == "정예 죽림 거한"
	passed = passed and RunFlow.death_cause_text("죽림 정령왕") == "죽림 정령왕"
	return passed


func test_death_cause_elite_and_boss_names_resolve_from_data() -> bool:
	# The names the result screen would print come from Enemy.setup's stats
	# dict — derive the elite exactly as the spawner does and check both paths.
	var monsters: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/monsters.json")
	)
	if monsters is not Dictionary:
		return false
	var elite: Dictionary = Enemy.derive_elite_stats(
		monsters["bamboo_brute"], monsters["bamboo_brute_elite"]
	)
	var boss_name: String = String((monsters["bamboo_spirit_lord"] as Dictionary)["name_ko"])
	return RunFlow.death_cause_text(String(elite["name_ko"])) == "정예 죽림 거한" \
		and RunFlow.death_cause_text(boss_name) == "죽림 정령왕"


func test_death_cause_falls_back_when_unattributable() -> bool:
	# Never a blank line and never a raw id: empty and whitespace both fall
	# back to the neutral text.
	var passed: bool = RunFlow.death_cause_text("") == RunFlow.DEATH_CAUSE_UNKNOWN
	passed = passed and RunFlow.death_cause_text("   ") == RunFlow.DEATH_CAUSE_UNKNOWN
	return passed


func test_opening_spawn_count_counts_only_inside_window() -> bool:
	# Wave A: spawns at 0,1,2,...,9 — 10 inside a 10s window. Wave B starts at
	# 8 with a 4s interval: only its first spawn (8s) fits. Wave C is past the
	# window entirely.
	var stage: Dictionary = {"waves": [
		{"at_sec": 0, "monster_id": "a", "count": 10, "interval_sec": 1.0},
		{"at_sec": 8, "monster_id": "b", "count": 5, "interval_sec": 4.0},
		{"at_sec": 30, "monster_id": "c", "count": 9, "interval_sec": 1.0},
	]}
	return RunFlow.opening_spawn_count(stage, 10.0) == 11


func test_opening_spawn_count_window_edge_excluded() -> bool:
	# A spawn scheduled exactly at the window boundary is outside it.
	var stage: Dictionary = {"waves": [
		{"at_sec": 0, "monster_id": "a", "count": 3, "interval_sec": 10.0},
	]}
	return RunFlow.opening_spawn_count(stage, 10.0) == 1


func test_first_level_xp_time_accumulates_across_waves() -> bool:
	var monsters: Dictionary = {"grunt": {"xp_drop": 2}, "fat": {"xp_drop": 5}}
	var stage: Dictionary = {"waves": [
		{"at_sec": 0, "monster_id": "grunt", "count": 3, "interval_sec": 2.0},
		{"at_sec": 1, "monster_id": "fat", "count": 1, "interval_sec": 1.0},
	]}
	# Timeline: 0s +2, 1s +5 (=7), 2s +2 (=9), 4s +2. Cost 9 → reached at 2s.
	return absf(RunFlow.first_level_xp_time(stage, monsters, 9) - 2.0) < EPSILON


func test_first_level_xp_time_unreachable_is_negative() -> bool:
	var monsters: Dictionary = {"grunt": {"xp_drop": 1}}
	var stage: Dictionary = {"waves": [
		{"at_sec": 0, "monster_id": "grunt", "count": 2, "interval_sec": 1.0},
	]}
	return RunFlow.first_level_xp_time(stage, monsters, 99) < 0.0


func test_opening_issues_flag_thin_rush_and_late_xp() -> bool:
	var monsters: Dictionary = {"grunt": {"xp_drop": 1}}
	var stage: Dictionary = {
		"opening": {
			"rush_window_sec": 20.0, "min_spawns": 18, "first_level_xp_by_sec": 40.0
		},
		"waves": [
			{"at_sec": 0, "monster_id": "grunt", "count": 2, "interval_sec": 2.5},
		],
	}
	# 2 spawns and 2 total XP against a cost of 6: both invariants must fire.
	return RunFlow.opening_issues(stage, monsters, 6.0, 1.5).size() == 2


func test_opening_issues_absent_block_is_exempt() -> bool:
	var stage: Dictionary = {"waves": []}
	return RunFlow.opening_issues(stage, {}, 6.0, 1.5).is_empty()


func test_real_stage_opening_invariants_hold() -> bool:
	# The shipped bamboo_forest must satisfy its own opening contract against
	# the real curve and monster data.
	var stages: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/stages.json")
	)
	var monsters: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/monsters.json")
	)
	if stages is not Dictionary or monsters is not Dictionary:
		return false
	var stage: Dictionary = (stages as Dictionary).get("bamboo_forest", {})
	if (stage.get("opening", {}) as Dictionary).is_empty():
		return false  # the opening contract itself is part of N6-2
	var curve: Dictionary = RunState.load_curve()
	return RunFlow.opening_issues(
		stage, monsters, float(curve["base_xp"]), float(curve["growth"])
	).is_empty()
