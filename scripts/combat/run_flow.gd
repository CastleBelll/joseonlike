class_name RunFlow
extends RefCounted
## Pure run-outcome logic for N5-1: boss spawn timing from stage data, the
## victory/defeat arbiter over the three end conditions, and the result-screen
## summary. Node-free so the headless suite drives it directly
## (tests/unit/test_run_flow.gd).

const OUTCOME_NONE := ""
const OUTCOME_VICTORY := "victory"
const OUTCOME_DEFEAT := "defeat"

## boss_spawn_time returns this when the stage defines no boss timing at all.
const NO_BOSS := -1.0


## Boss spawn second for a stage dict (data/stages.json entry): boss_at_sec
## when set, else the stage end, never past duration_sec. NO_BOSS when the
## stage has neither field.
static func boss_spawn_time(stage: Dictionary) -> float:
	var duration: float = float(stage.get("duration_sec", 0.0))
	var at: float = float(stage.get("boss_at_sec", 0.0))
	if at > 0.0:
		return minf(at, duration) if duration > 0.0 else at
	return duration if duration > 0.0 else NO_BOSS


## Arbiter over the three run-end conditions. Player death wins ties (dying
## to the boss's final hit in the same frame it dies is still a defeat);
## timeout counts as victory — the GDD's post-15:00 phase is post-clear
## lingering, not a fail state.
static func resolve_outcome(player_dead: bool, boss_dead: bool, time_up: bool) -> String:
	if player_dead:
		return OUTCOME_DEFEAT
	if boss_dead or time_up:
		return OUTCOME_VICTORY
	return OUTCOME_NONE


## Result-screen payload; time_text reuses the HUD's m:ss formatting.
static func build_summary(elapsed_sec: float, kills: int, gold: int) -> Dictionary:
	return {
		"time_text": CombatHud.format_time(elapsed_sec),
		"kills": kills,
		"gold": gold,
	}
