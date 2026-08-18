class_name Pickups
extends RefCounted
## Pure helpers for N5-5 destructible-prop pickups and elite reward chests.
## All inputs are plain Dictionaries parsed from data/pickups.json by the
## caller, so every function is testable headless with fixture data. The
## caller owns the RNG so a fixed seed replays the same rolls.

const KIND_NOTHING := "nothing"
const KIND_GOLD := "gold"
const KIND_HEALTH := "health"
const KIND_NUKE := "nuke"
const KIND_MAGNET := "magnet"
const KINDS: Array[String] = [KIND_NOTHING, KIND_GOLD, KIND_HEALTH, KIND_NUKE, KIND_MAGNET]
## Kinds that keep the field from becoming a vending machine — their combined
## weight share must stay at or above _rules.plain_share_min (validated).
const PLAIN_KINDS: Array[String] = [KIND_NOTHING, KIND_GOLD]
const CHEST_COUNTS: Array[String] = ["1", "3", "5"]


## Roll the break table once. Returns a KINDS entry (KIND_NOTHING on empty or
## malformed data, so a broken table never crashes a run).
static func roll_break(pickups: Dictionary, rng: RandomNumberGenerator) -> String:
	var table: Array = pickups.get("break_table", [])
	if table.is_empty():
		return KIND_NOTHING
	var weights: Array[float] = []
	for entry: Dictionary in table:
		weights.append(float(entry.get("weight", 0.0)))
	var picked: Dictionary = table[StageField.pick_weighted(weights, rng.randf())]
	return String(picked.get("kind", KIND_NOTHING))


## Chest count weights with the luck bend applied: each count's base weight is
## multiplied by (1 + luck * luck_shift[count]). Shift 0 leaves a count at its
## base weight, so luck only ever pushes probability TOWARD the shifted
## (higher) counts — base rates are the luck-0 distribution.
static func chest_weights(chest: Dictionary, luck: float) -> Dictionary:
	var base: Dictionary = chest.get("weights", {})
	var shift: Dictionary = chest.get("luck_shift", {})
	var bent: Dictionary = {}
	for count: String in base:
		bent[count] = float(base[count]) * (1.0 + maxf(luck, 0.0) * float(shift.get(count, 0.0)))
	return bent


## Roll the reward count for one chest (1, 3 or 5) at the given luck stat.
static func roll_chest_count(
	chest: Dictionary, luck: float, rng: RandomNumberGenerator
) -> int:
	var bent: Dictionary = chest_weights(chest, luck)
	var counts: Array[String] = []
	var weights: Array[float] = []
	for count: String in CHEST_COUNTS:
		if bent.has(count):
			counts.append(count)
			weights.append(float(bent[count]))
	if counts.is_empty():
		return 1
	return int(counts[StageField.pick_weighted(weights, rng.randf())])


## N6-3 heal-budget math: the expected max-HP fraction of healing one run
## offers — break_table health share x breaks x health ratio, plus one
## elite_heal per elite kill. Counts are the caller's (schedule or measured),
## so the same function prices both the intended and the actual budget.
static func heal_budget(pickups: Dictionary, breaks: int, elite_kills: int) -> float:
	var table: Array = pickups.get("break_table", [])
	var total: float = 0.0
	var health_weight: float = 0.0
	for entry: Variant in table:
		if entry is not Dictionary:
			continue
		var weight: float = float((entry as Dictionary).get("weight", 0.0))
		total += weight
		if String((entry as Dictionary).get("kind", "")) == KIND_HEALTH:
			health_weight = weight
	var health_share: float = health_weight / total if total > 0.0 else 0.0
	var pickup_ratio: float = float((pickups.get("health", {}) as Dictionary).get("hp_ratio", 0.0))
	var elite_ratio: float = float(
		(pickups.get("elite_heal", {}) as Dictionary).get("hp_ratio", 0.0)
	)
	return float(breaks) * health_share * pickup_ratio + float(elite_kills) * elite_ratio


## The damage one nuke deals to one enemy: the full data damage for trash,
## the capped value for elites and the boss so the payoff can never one-shot
## a set-piece fight.
static func nuke_damage(pickups: Dictionary, capped_target: bool) -> float:
	var nuke: Dictionary = pickups.get("nuke", {})
	if capped_target:
		return float(nuke.get("elite_boss_damage", 0.0))
	return float(nuke.get("damage", 0.0))


## Data contract for pickups.json (consumed by tools/validate_data.gd and the
## unit suite). Returns human-readable violations; empty = valid.
## `luck_cap` is the meta tree's luck stat cap — the 5-reward chest must stay
## below certainty even at capped luck.
static func data_issues(pickups: Dictionary, luck_cap: float) -> Array[String]:
	var issues: Array[String] = []
	_break_table_issues(pickups, issues)
	_effect_issues(pickups, issues)
	_chest_issues(pickups, luck_cap, issues)
	return issues


static func _break_table_issues(pickups: Dictionary, issues: Array[String]) -> void:
	var table: Array = pickups.get("break_table", [])
	var seen: Array[String] = []
	var total: float = 0.0
	var plain: float = 0.0
	for entry: Variant in table:
		if entry is not Dictionary:
			issues.append("break_table entry is not an object")
			continue
		var kind: String = String((entry as Dictionary).get("kind", ""))
		var weight: float = float((entry as Dictionary).get("weight", 0.0))
		if kind not in KINDS:
			issues.append("break_table kind '%s' unknown" % kind)
			continue
		if kind in seen:
			issues.append("break_table kind '%s' duplicated" % kind)
		seen.append(kind)
		if weight <= 0.0:
			issues.append("break_table.%s.weight must be positive" % kind)
		total += weight
		if kind in PLAIN_KINDS:
			plain += weight
	for kind: String in KINDS:
		if kind not in seen:
			issues.append("break_table missing kind '%s'" % kind)
	# The intent guard: exciting drops (health/nuke/magnet) must stay uncommon
	# or every field prop becomes a vending machine.
	var share_min: float = float(
		(pickups.get("_rules", {}) as Dictionary).get("plain_share_min", 0.0)
	)
	if share_min <= 0.0 or share_min >= 1.0:
		issues.append("_rules.plain_share_min must be in (0, 1)")
	elif total > 0.0 and plain / total < share_min:
		issues.append("break_table plain share %.2f below plain_share_min %.2f" % [
			plain / total, share_min
		])


static func _effect_issues(pickups: Dictionary, issues: Array[String]) -> void:
	if int((pickups.get("gold", {}) as Dictionary).get("amount", 0)) <= 0:
		issues.append("gold.amount must be positive")
	var health: Dictionary = pickups.get("health", {})
	var ratio: float = float(health.get("hp_ratio", 0.0))
	if ratio <= 0.0 or ratio > 1.0:
		issues.append("health.hp_ratio must be in (0, 1]")
	if int(health.get("full_hp_gold", 0)) <= 0:
		issues.append("health.full_hp_gold must be positive")
	# N6-3 elite-kill heal: a reward slice, never a full refill — capped below
	# the pickup heal wouldn't be wrong, but the hard contract is (0, 0.5].
	var elite_ratio: float = float(
		(pickups.get("elite_heal", {}) as Dictionary).get("hp_ratio", 0.0)
	)
	if elite_ratio <= 0.0 or elite_ratio > 0.5:
		issues.append("elite_heal.hp_ratio must be in (0, 0.5]")
	var nuke: Dictionary = pickups.get("nuke", {})
	if float(nuke.get("damage", 0.0)) <= 0.0:
		issues.append("nuke.damage must be positive")
	var capped: float = float(nuke.get("elite_boss_damage", 0.0))
	if capped <= 0.0:
		issues.append("nuke.elite_boss_damage must be positive")
	elif capped >= float(nuke.get("damage", 0.0)):
		issues.append("nuke.elite_boss_damage must be below nuke.damage")
	if float(nuke.get("ring_radius_px", 0.0)) <= 0.0:
		issues.append("nuke.ring_radius_px must be positive")
	if float((pickups.get("magnet", {}) as Dictionary).get("ring_radius_px", 0.0)) <= 0.0:
		issues.append("magnet.ring_radius_px must be positive")


static func _chest_issues(pickups: Dictionary, luck_cap: float, issues: Array[String]) -> void:
	var chest: Dictionary = pickups.get("chest", {})
	var weights: Dictionary = chest.get("weights", {})
	var shift: Dictionary = chest.get("luck_shift", {})
	var complete: bool = true
	for count: String in CHEST_COUNTS:
		if float(weights.get(count, 0.0)) <= 0.0:
			issues.append("chest.weights.%s missing or not positive" % count)
			complete = false
		if float(shift.get(count, -1.0)) < 0.0:
			issues.append("chest.luck_shift.%s missing or negative" % count)
			complete = false
	for count: String in weights:
		if count not in CHEST_COUNTS:
			issues.append("chest.weights key '%s' not one of %s" % [count, str(CHEST_COUNTS)])
	if complete:
		# Base escalation: 1 must be the common case, 5 the rare one.
		if not (
			float(weights["1"]) > float(weights["3"])
			and float(weights["3"]) > float(weights["5"])
		):
			issues.append("chest.weights must strictly decrease from 1 to 3 to 5")
		# Luck must actually bend toward the top count…
		if float(shift["5"]) <= float(shift["1"]):
			issues.append("chest.luck_shift.5 must exceed chest.luck_shift.1")
		# …but never make it dominant at capped luck: common, not guaranteed.
		var bent: Dictionary = chest_weights(chest, luck_cap)
		var total: float = 0.0
		for count: String in bent:
			total += float(bent[count])
		if total > 0.0 and float(bent.get("5", 0.0)) / total >= 0.5:
			issues.append(
				"chest 5-reward probability at luck cap %.2f reaches %.2f (must stay below 0.5)" % [
					luck_cap, float(bent.get("5", 0.0)) / total
				]
			)
	if float(chest.get("open_radius_px", 0.0)) <= 0.0:
		issues.append("chest.open_radius_px must be positive")
	if int(chest.get("fallback_gold", 0)) <= 0:
		issues.append("chest.fallback_gold must be positive")
