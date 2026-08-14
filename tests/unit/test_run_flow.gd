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
