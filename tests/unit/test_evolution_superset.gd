extends RefCounted
## N9-97: a same-mechanic evolution may never grow LESS than its base.
##
## This is the defect the owner caught twice by feel before it was measured:
## 화염 부적 capped at +2 milestone pierce while 낡은 부적 grew +5, so the
## "upgrade" traded the base's best stat away and lost the dps race. The same
## hole existed in seven more pairs — smaller explosion growth, missing chain
## falloff, a summon that never gains speed. Each was patched at L8; this
## keeps the whole class of defect from returning.
##
## Mechanic-CHANGING evolutions (직선 부적 → 폭발/연쇄/저주) are exempt on
## purpose: losing pierce when you stop being a pierce weapon is the identity
## change, not a regression. Only pairs sharing a mechanic are held to the
## superset rule.

const WEAPONS_PATH := "res://data/weapons.json"
const MODS_PATH := "res://data/weapon_mods.json"

const EPSILON := 0.0001


func test_same_mechanic_evolutions_keep_the_growth_axis() -> bool:
	var weapons: Dictionary = _load(WEAPONS_PATH)
	var mods: Dictionary = _load(MODS_PATH)
	var passed: bool = true
	var checked: int = 0
	for mod_id: String in mods:
		if mod_id.begins_with("_"):
			continue
		var mod: Dictionary = mods[mod_id]
		var base: Dictionary = weapons.get(String(mod.get("weapon_id", "")), {})
		var evo: Dictionary = weapons.get(String(mod.get("result_weapon", "")), {})
		if base.is_empty() or evo.is_empty():
			continue
		if String(base.get("mechanic", "")) != String(evo.get("mechanic", "")):
			continue
		checked += 1
		var base_totals: Dictionary = _milestone_totals(base)
		var evo_totals: Dictionary = _milestone_totals(evo)
		for key: String in base_totals:
			# cooldown milestones would be negative-good; no pair ships any,
			# and holding them to "not less" would invert their meaning.
			if key.ends_with("cooldown_sec"):
				continue
			if float(evo_totals.get(key, 0.0)) < float(base_totals[key]) - EPSILON:
				push_error(
					"test_evolution_superset: %s grows '%s' to %s but evolution %s only to %s"
					% [
						mod.get("weapon_id"), key, str(base_totals[key]),
						mod.get("result_weapon"), str(evo_totals.get(key, 0.0)),
					]
				)
				passed = false
	if checked == 0:
		push_error("test_evolution_superset: no same-mechanic pairs found")
		return false
	return passed


## The tier multiplier that makes an evolution hit harder per shot must exist
## and actually favour the evolution.
func test_the_evolution_tier_multiplier_is_a_buff() -> bool:
	var weapons: Dictionary = _load(WEAPONS_PATH)
	var mult: float = float(
		(weapons.get("_evolution", {}) as Dictionary).get("damage_mult", 0.0)
	)
	return mult > 1.0


func _milestone_totals(entry: Dictionary) -> Dictionary:
	var totals: Dictionary = {}
	for milestone: Variant in (entry.get("milestones", {}) as Dictionary).values():
		_fold(milestone as Dictionary, "", totals)
	return totals


func _fold(delta: Dictionary, prefix: String, totals: Dictionary) -> void:
	for key: String in delta:
		if delta[key] is Dictionary:
			_fold(delta[key] as Dictionary, prefix + key + ".", totals)
		else:
			var full: String = prefix + key
			totals[full] = float(totals.get(full, 0.0)) + float(delta[key])


func _load(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
