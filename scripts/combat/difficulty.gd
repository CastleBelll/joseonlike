class_name Difficulty
extends RefCounted
## Pure difficulty-ladder and run-length helpers (N9-22). The genre research
## (retention audit, 2026-08-19) found a single stat-meta curve is
## structurally unable to keep a maxed player tense — a difficulty ladder is
## what re-tightens the game. Everything here is a static function over plain
## Dictionaries so the headless suite covers it; SaveService owns persistence.

const PATH := "res://data/difficulties.json"
const CLEARED_KEY := "cleared_difficulties"
const SELECTED_KEY := "difficulty"
const RUN_LENGTH_KEY := "run_length"


static func load_config() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if data is not Dictionary:
		push_error("difficulty: cannot parse " + PATH)
		return {}
	return data


static func default_id(config: Dictionary) -> String:
	return String((config.get("_config", {}) as Dictionary).get("default_id", ""))


static func default_run_length(config: Dictionary) -> String:
	return String((config.get("_config", {}) as Dictionary).get("default_run_length", ""))


## Selected tier id from the profile, clamped to something actually
## unlocked — a stale or hand-edited save can never start a locked night.
## Headless tools without SaveService fall back to the default tier.
static func selected_id(config: Dictionary) -> String:
	if SaveService.instance == null:
		return default_id(config)
	var profile: Dictionary = SaveService.instance.profile
	var cleared: Array = profile.get(CLEARED_KEY, [])
	var chosen: String = String(
		(profile.get("settings", {}) as Dictionary).get(SELECTED_KEY, "")
	)
	if chosen.is_empty() or not is_unlocked(config, chosen, cleared):
		return default_id(config)
	return chosen


static func selected_run_length(config: Dictionary) -> String:
	if SaveService.instance == null:
		return default_run_length(config)
	var chosen: String = String(
		(SaveService.instance.profile.get("settings", {}) as Dictionary).get(RUN_LENGTH_KEY, "")
	)
	if chosen.is_empty() or run_length(config, chosen).is_empty():
		return default_run_length(config)
	return chosen


## Entries sorted by rank — the ladder's display and unlock order.
static func ladder(config: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for raw: Variant in config.get("difficulties", []):
		if raw is Dictionary:
			entries.append(raw)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("rank", 0)) < int(b.get("rank", 0))
	)
	return entries


static func entry(config: Dictionary, id: String) -> Dictionary:
	for candidate: Dictionary in ladder(config):
		if String(candidate.get("id", "")) == id:
			return _first_run_softened(config, candidate)
	return {}


## The first run is short (see _first_run_scaled) — but shortening the clock
## alone compresses the same waves into a fifth of the time, which measured as
## a bot dying at 36.9s on what is supposed to be the teaching run. The tier is
## softened to match, through the same lookup both the stage and the spawner
## already share.
static func _first_run_softened(config: Dictionary, tier: Dictionary) -> Dictionary:
	if not _is_first_run():
		return tier
	var settings: Dictionary = config.get("_config", {})
	var softened: Dictionary = tier.duplicate(true)
	for field: String in [
		"spawn_count_mult", "elite_count_mult",
	]:
		softened[field] = float(tier.get(field, 1.0)) * float(
			settings.get("first_run_spawn_scale", 1.0)
		)
	softened["enemy_hp_mult"] = float(tier.get("enemy_hp_mult", 1.0)) * float(
		settings.get("first_run_enemy_hp_scale", 1.0)
	)
	softened["enemy_damage_mult"] = float(tier.get("enemy_damage_mult", 1.0)) * float(
		settings.get("first_run_enemy_damage_scale", 1.0)
	)
	return softened


static func _is_first_run() -> bool:
	if SaveService.instance == null:
		return false
	var stats: Dictionary = SaveService.instance.profile.get("stats", {})
	return int(stats.get("runs_played", 0)) <= 0


static func run_length(config: Dictionary, id: String) -> Dictionary:
	for raw: Variant in config.get("run_lengths", []):
		if raw is Dictionary and String((raw as Dictionary).get("id", "")) == id:
			return _first_run_scaled(config, raw)
	return {}


## N9-44 (owner: "처음 튜토리얼 끝나고는 1분 안에 게임이 끝나게"): the very
## first run is shortened by folding an extra scale into the chosen length.
## Doing it HERE rather than in the stage is what keeps the spawner and the
## stage agreeing — both read their schedule through this one function, and a
## clock that disagreed with the wave table would strand the boss.
## runs_played is read straight off the profile rather than through Ftue, to
## keep this class free of a dependency that would close a cycle back through
## SaveService.
static func _first_run_scaled(config: Dictionary, length: Dictionary) -> Dictionary:
	var scale: float = float(
		(config.get("_config", {}) as Dictionary).get("first_run_duration_scale", 1.0)
	)
	if scale >= 1.0 or not _is_first_run():
		return length
	var scaled: Dictionary = length.duplicate(true)
	scaled["duration_scale"] = float(length.get("duration_scale", 1.0)) * scale
	return scaled


## A tier is open when it needs no predecessor, or the predecessor is in the
## profile's cleared list. Unknown ids are closed — never crash, never grant.
static func is_unlocked(config: Dictionary, id: String, cleared: Array) -> bool:
	var found: Dictionary = entry(config, id)
	if found.is_empty():
		return false
	var required: String = String(found.get("unlock_after", ""))
	return required.is_empty() or cleared.has(required)


## Highest-rank unlocked tier — what the camp offers by default so a
## returning player is never dropped back to the easiest night.
static func highest_unlocked(config: Dictionary, cleared: Array) -> String:
	var best: String = default_id(config)
	for candidate: Dictionary in ladder(config):
		var id: String = String(candidate.get("id", ""))
		if is_unlocked(config, id, cleared):
			best = id
	return best


## Pure fold: records a cleared tier. Returns {"profile", "changed"} so the
## caller skips the disk write when the tier was already cleared.
static func mark_cleared(profile: Dictionary, id: String) -> Dictionary:
	if id.is_empty():
		return {"profile": profile, "changed": false}
	var cleared: Array = profile.get(CLEARED_KEY, [])
	if cleared.has(id):
		return {"profile": profile, "changed": false}
	var next: Dictionary = profile.duplicate(true)
	var updated: Array = (next.get(CLEARED_KEY, []) as Array).duplicate()
	updated.append(id)
	next[CLEARED_KEY] = updated
	return {"profile": next, "changed": true}


## Stage entry with the tier's multipliers folded in: wave counts, boss hp and
## the enrage ceilings all scale, so one data table drives every tier.
## `duration_scale` from the run-length choice stretches the whole schedule —
## wave times, surge, boss and enrage move together so the shape is preserved.
static func apply(stage: Dictionary, tier: Dictionary, length: Dictionary) -> Dictionary:
	if tier.is_empty() and length.is_empty():
		return stage
	var scaled: Dictionary = stage.duplicate(true)
	var spawn_mult: float = float(tier.get("spawn_count_mult", 1.0))
	var elite_mult: float = float(tier.get("elite_count_mult", 1.0))
	var time_scale: float = maxf(float(length.get("duration_scale", 1.0)), 0.1)

	scaled["duration_sec"] = float(stage.get("duration_sec", 0.0)) * time_scale
	for key: String in ["boss_at_sec", "surge_at_sec"]:
		if stage.has(key):
			scaled[key] = float(stage[key]) * time_scale

	var enrage: Dictionary = (stage.get("soft_enrage", {}) as Dictionary).duplicate()
	if not enrage.is_empty():
		enrage["start_sec"] = float(enrage.get("start_sec", 0.0)) * time_scale
		# The ceiling compounds with the tier so a late 역병 night really bites.
		enrage["hp_mult_max"] = float(enrage.get("hp_mult_max", 1.0)) \
			* float(tier.get("enemy_hp_mult", 1.0))
		enrage["damage_mult_max"] = float(enrage.get("damage_mult_max", 1.0)) \
			* float(tier.get("enemy_damage_mult", 1.0))
		scaled["soft_enrage"] = enrage

	var waves: Array = []
	for raw: Variant in stage.get("waves", []):
		if raw is not Dictionary:
			continue
		var wave: Dictionary = (raw as Dictionary).duplicate()
		wave["at_sec"] = float(wave.get("at_sec", 0.0)) * time_scale
		var is_elite: bool = String(wave.get("monster_id", "")).ends_with("_elite")
		var mult: float = elite_mult if is_elite else spawn_mult
		wave["count"] = maxi(1, int(round(float(wave.get("count", 0)) * mult)))
		waves.append(wave)
	scaled["waves"] = waves
	return scaled


## Per-monster stat scaling for the tier. The boss uses its own hp multiplier
## so tier pressure on the boss can be tuned apart from the trash curve.
static func scale_monster(stats: Dictionary, tier: Dictionary, is_boss: bool) -> Dictionary:
	if tier.is_empty():
		return stats
	var scaled: Dictionary = stats.duplicate(true)
	var hp_mult: float = float(
		tier.get("boss_hp_mult", 1.0) if is_boss else tier.get("enemy_hp_mult", 1.0)
	)
	scaled["hp"] = float(stats.get("hp", 0.0)) * hp_mult
	scaled["damage"] = float(stats.get("damage", 0.0)) * float(tier.get("enemy_damage_mult", 1.0))
	scaled["speed"] = float(stats.get("speed", 0.0)) * float(tier.get("enemy_speed_mult", 1.0))
	return scaled


## Reward multiplier for a tier + length pair (gold banks, xp orbs).
static func reward_mult(tier: Dictionary, length: Dictionary, key: String) -> float:
	return float(tier.get(key, 1.0)) * float(length.get(key, 1.0))


## Data contract for validate_data: unique ascending ranks, resolvable
## unlock_after ids, exactly one open tier, positive multipliers, and a
## default id that exists and is itself open.
static func data_issues(config: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	var entries: Array[Dictionary] = ladder(config)
	if entries.is_empty():
		issues.append("difficulties list is empty")
		return issues
	var ids: Array[String] = []
	var ranks: Array[int] = []
	var roots: int = 0
	for tier: Dictionary in entries:
		var id: String = String(tier.get("id", ""))
		if id.is_empty():
			issues.append("a difficulty has no id")
			continue
		if ids.has(id):
			issues.append("difficulty id '%s' duplicated" % id)
		ids.append(id)
		var rank: int = int(tier.get("rank", 0))
		if ranks.has(rank):
			issues.append("difficulty '%s' reuses rank %d" % [id, rank])
		ranks.append(rank)
		if String(tier.get("unlock_after", "")).is_empty():
			roots += 1
		for key: String in [
			"enemy_hp_mult", "enemy_damage_mult", "enemy_speed_mult",
			"spawn_count_mult", "elite_count_mult", "boss_hp_mult",
			"gold_mult", "xp_mult",
		]:
			if float(tier.get(key, 0.0)) <= 0.0:
				issues.append("difficulty '%s' has a non-positive %s" % [id, key])
	for tier: Dictionary in entries:
		var required: String = String(tier.get("unlock_after", ""))
		if not required.is_empty() and not ids.has(required):
			issues.append(
				"difficulty '%s' unlocks after unknown '%s'"
				% [String(tier.get("id", "")), required]
			)
	if roots != 1:
		issues.append(
			"expected exactly one difficulty with an empty unlock_after, found %d" % roots
		)
	var fallback: String = default_id(config)
	if not ids.has(fallback):
		issues.append("default_id '%s' is not a difficulty" % fallback)
	elif not String(entry(config, fallback).get("unlock_after", "")).is_empty():
		issues.append("default_id '%s' is itself locked" % fallback)

	var lengths: Array = config.get("run_lengths", [])
	if lengths.is_empty():
		issues.append("run_lengths list is empty")
	var length_ids: Array[String] = []
	for raw: Variant in lengths:
		if raw is not Dictionary:
			issues.append("a run_length entry is not an object")
			continue
		var length: Dictionary = raw
		var lid: String = String(length.get("id", ""))
		if lid.is_empty() or length_ids.has(lid):
			issues.append("run_length id '%s' missing or duplicated" % lid)
		length_ids.append(lid)
		if float(length.get("duration_scale", 0.0)) <= 0.0:
			issues.append("run_length '%s' has a non-positive duration_scale" % lid)
		if float(length.get("gold_mult", 0.0)) <= 0.0:
			issues.append("run_length '%s' has a non-positive gold_mult" % lid)
	var default_length: String = default_run_length(config)
	if not length_ids.has(default_length):
		issues.append("default_run_length '%s' is not a run_length" % default_length)
	return issues
