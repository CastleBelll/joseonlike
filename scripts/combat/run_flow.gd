class_name RunFlow
extends RefCounted
## Pure run-outcome logic for N5-1: boss spawn timing from stage data, the
## victory/defeat arbiter over the three end conditions, and the result-screen
## summary. Node-free so the headless suite drives it directly
## (tests/unit/test_run_flow.gd).

const OUTCOME_NONE := ""
const OUTCOME_VICTORY := "victory"
const OUTCOME_DEFEAT := "defeat"

## N6-2: shown when a death has no attributable source (a raw id or a blank
## line on the result screen would read as a bug, not a message).
const DEATH_CAUSE_UNKNOWN := "알 수 없는 존재"

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
## `death_cause` is the killer's localized display name — empty for a run that
## did not end in a death (or an unattributable one; see death_cause_text).
static func build_summary(
	elapsed_sec: float, kills: int, gold: int, death_cause: String = ""
) -> Dictionary:
	return {
		"time_text": CombatHud.format_time(elapsed_sec),
		"kills": kills,
		"gold": gold,
		"death_cause": death_cause,
	}


## N6-2 killer attribution: the raw recorded source name, or the neutral
## fallback when nothing attributable landed the killing blow. Elites and the
## boss pass through as their own localized names (Enemy.setup stores the
## already-resolved name_ko, elite derivation included).
static func death_cause_text(raw_name: String) -> String:
	var trimmed: String = raw_name.strip_edges()
	return trimmed if not trimmed.is_empty() else DEATH_CAUSE_UNKNOWN


## N4-2 wave-schedule invariants for a stage dict. Returns human-readable
## violations (empty = valid): wave times monotonic non-decreasing, no wave
## after the boss, nothing scheduled past duration_sec (N4-2b — run length is
## data, the whole curve must fit inside it), a surge bucket that is the
## strict spawn-count peak and comes before the boss, and soft enrage never
## starting before the boss. Shared by tools/validate_data.gd and the unit suite.
static func schedule_issues(stage: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	var duration: float = float(stage.get("duration_sec", 0.0))
	var boss_at: float = float(stage.get("boss_at_sec", 0.0))
	var surge_at: float = float(stage.get("surge_at_sec", 0.0))
	if duration > 0.0 and boss_at > duration:
		issues.append("boss_at_sec exceeds duration_sec")
	var previous: float = 0.0
	var buckets: Dictionary = {}
	for wave: Dictionary in stage.get("waves", []):
		var at: float = float(wave.get("at_sec", 0.0))
		if at < previous:
			issues.append("wave times not monotonic at %ss" % at)
		previous = at
		if at > boss_at:
			issues.append("wave at %ss starts after the boss" % at)
		if duration > 0.0 and at > duration:
			issues.append("wave at %ss exceeds duration_sec" % at)
		buckets[at] = int(buckets.get(at, 0)) + int(wave.get("count", 0))
	if surge_at <= 0.0 or not buckets.has(surge_at):
		issues.append("surge_at_sec missing or has no wave")
	elif surge_at >= boss_at:
		issues.append("surge must come before the boss")
	else:
		for at: float in buckets:
			if at != surge_at and int(buckets[at]) >= int(buckets[surge_at]):
				issues.append("surge bucket is not the spawn-count peak (beaten at %ss)" % at)
	var enrage: Dictionary = stage.get("soft_enrage", {})
	if not enrage.is_empty() and float(enrage.get("start_sec", 0.0)) < boss_at:
		issues.append("soft_enrage.start_sec before boss_at_sec")
	return issues


## N6-2: spawns scheduled strictly before `window_sec` across every wave —
## the opening-density number the rush invariant checks. Ignores the live cap
## (the cap is far above any sane opening) and kill speed on purpose: this is
## the schedule's promise, not a simulation.
static func opening_spawn_count(stage: Dictionary, window_sec: float) -> int:
	var total: int = 0
	for wave: Dictionary in stage.get("waves", []):
		var at: float = float(wave.get("at_sec", 0.0))
		var interval: float = maxf(float(wave.get("interval_sec", 1.0)), 0.001)
		for k: int in range(int(wave.get("count", 0))):
			if at + float(k) * interval < window_sec:
				total += 1
	return total


## N6-2: the run second at which the schedule has put enough cumulative XP on
## the field to cross `xp_cost` (the level-2 step). A lower bound on the real
## first level-up — kill and pickup delay come on top — so the data bound in
## stages.json "opening" must leave slack. -1.0 when the schedule never
## reaches the cost.
static func first_level_xp_time(
	stage: Dictionary, monsters: Dictionary, xp_cost: int
) -> float:
	var events: Array[Vector2] = []  # x = spawn second, y = xp_drop
	for wave: Dictionary in stage.get("waves", []):
		var monster: Dictionary = monsters.get(String(wave.get("monster_id", "")), {})
		var xp: float = float(monster.get("xp_drop", 0))
		var at: float = float(wave.get("at_sec", 0.0))
		var interval: float = maxf(float(wave.get("interval_sec", 1.0)), 0.001)
		for k: int in range(int(wave.get("count", 0))):
			events.append(Vector2(at + float(k) * interval, xp))
	events.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var cumulative: float = 0.0
	for event: Vector2 in events:
		cumulative += event.y
		if cumulative >= float(xp_cost):
			return event.x
	return -1.0


## N6-2 opening invariants against the stage's own "opening" block (numbers
## in data, never here): a dense rush inside the window and a first level-up
## whose scheduled-XP bound stays inside the promise. Stages without the
## block are exempt — the opening contract is per-stage data.
static func opening_issues(
	stage: Dictionary, monsters: Dictionary, base_xp: float, growth: float
) -> Array[String]:
	var issues: Array[String] = []
	var opening: Dictionary = stage.get("opening", {})
	if opening.is_empty():
		return issues
	var window: float = float(opening.get("rush_window_sec", 0.0))
	var min_spawns: int = int(opening.get("min_spawns", 0))
	if window <= 0.0 or min_spawns <= 0:
		issues.append("opening block missing rush_window_sec/min_spawns")
		return issues
	var spawned: int = opening_spawn_count(stage, window)
	if spawned < min_spawns:
		issues.append("opening rush too thin: %d spawns in %.0fs (need %d)" % [
			spawned, window, min_spawns
		])
	var by_sec: float = float(opening.get("first_level_xp_by_sec", 0.0))
	if by_sec > 0.0:
		var cost: int = RunState.xp_to_next(RunState.FIRST_LEVEL, base_xp, growth)
		var xp_at: float = first_level_xp_time(stage, monsters, cost)
		if xp_at < 0.0 or xp_at > by_sec:
			issues.append("first level-up XP not scheduled by %.0fs (reached at %.1fs)" % [
				by_sec, xp_at
			])
	return issues


## Soft enrage ramp progress in [0, 1]: 0 before start_sec, 1 once ramp_sec
## has fully elapsed (GDD §34 — post-boss lingering gets sharply harder).
static func enrage_progress(elapsed_sec: float, enrage: Dictionary) -> float:
	if enrage.is_empty():
		return 0.0
	var start: float = float(enrage.get("start_sec", 0.0))
	var ramp: float = maxf(float(enrage.get("ramp_sec", 0.0)), 0.001)
	return clampf((elapsed_sec - start) / ramp, 0.0, 1.0)


## Monster stats scaled for the enrage ramp — a new copy, base data untouched.
static func enrage_stats(stats: Dictionary, enrage: Dictionary, progress: float) -> Dictionary:
	if progress <= 0.0:
		return stats
	var scaled: Dictionary = stats.duplicate()
	scaled["hp"] = float(stats.get("hp", 1.0)) * lerpf(
		1.0, float(enrage.get("hp_mult_max", 1.0)), progress
	)
	scaled["damage"] = float(stats.get("damage", 0.0)) * lerpf(
		1.0, float(enrage.get("damage_mult_max", 1.0)), progress
	)
	scaled["speed"] = float(stats.get("speed", 0.0)) * lerpf(
		1.0, float(enrage.get("speed_mult_max", 1.0)), progress
	)
	return scaled
