extends RefCounted
## N9-166: the nights are a ladder. The ruined village is the SECOND night, so
## its wave budget has to weigh more than the bamboo forest's — it measured
## LIGHTER (906 spawns / 16.8k HP against 1196 / 25.4k) while claiming to be
## the step up. This guards the direction, not the exact numbers.

const STAGES_PATH := "res://data/stages.json"
const MONSTERS_PATH := "res://data/monsters.json"
const FIRST_NIGHT := "bamboo_forest"
const SECOND_NIGHT := "ruined_village"
## A second night that only matches the first is not a second night. 15% is
## the smallest gap that survives rounding a wave count.
const MIN_STEP := 1.15


func _json(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}


## What one stage's waves ask of the player: total body HP to chew through and
## total contact damage standing on the field. Elites resolve through their
## base monster, the same way the spawner builds them.
func _budget(stage: Dictionary, monsters: Dictionary) -> Dictionary:
	var hp: float = 0.0
	var damage: float = 0.0
	for wave: Dictionary in stage.get("waves", []):
		var entry: Dictionary = monsters.get(String(wave.get("monster_id", "")), {})
		var count: float = float(wave.get("count", 0))
		if entry.has("elite_of"):
			var base: Dictionary = monsters.get(String(entry["elite_of"]), {})
			hp += float(base.get("hp", 0.0)) * float(entry.get("hp_mult", 1.0)) * count
			damage += (
				float(base.get("damage", 0.0)) * float(entry.get("damage_mult", 1.0)) * count
			)
			continue
		hp += float(entry.get("hp", 0.0)) * count
		damage += float(entry.get("damage", 0.0)) * count
	return {"hp": hp, "damage": damage}


func test_the_second_night_weighs_more_than_the_first() -> bool:
	var stages: Dictionary = _json(STAGES_PATH)
	var monsters: Dictionary = _json(MONSTERS_PATH)
	var first: Dictionary = _budget(stages.get(FIRST_NIGHT, {}), monsters)
	var second: Dictionary = _budget(stages.get(SECOND_NIGHT, {}), monsters)
	var passed: bool = float(first["hp"]) > 0.0 and float(first["damage"]) > 0.0
	if not passed:
		push_error("test_night_ladder: the first night has no wave budget to compare against")
		return false
	for key: String in ["hp", "damage"]:
		var ratio: float = float(second[key]) / float(first[key])
		if ratio < MIN_STEP:
			push_error(
				"test_night_ladder: night 2 %s is %.2fx night 1, under the %.2fx step"
				% [key, ratio, MIN_STEP]
			)
			passed = false
	return passed


## Both nights carry an elite: the forest's brute and the village's armour.
## An elite-less night reads as a flat wave list no matter what the counts say.
func test_every_night_fields_an_elite() -> bool:
	var stages: Dictionary = _json(STAGES_PATH)
	var monsters: Dictionary = _json(MONSTERS_PATH)
	var passed: bool = true
	for stage_id: String in [FIRST_NIGHT, SECOND_NIGHT]:
		var has_elite: bool = false
		for wave: Dictionary in (stages.get(stage_id, {}) as Dictionary).get("waves", []):
			if (monsters.get(String(wave.get("monster_id", "")), {}) as Dictionary).has("elite_of"):
				has_elite = true
				break
		if not has_elite:
			push_error("test_night_ladder: %s never fields an elite" % stage_id)
			passed = false
	return passed
