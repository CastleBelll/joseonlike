extends RefCounted
## Evolution against the real content, driven by data/evolutions.json itself.
##
## The unit test next door proves the matcher; this one proves the thresholds
## are actually reachable and that GameData is the only thing deciding them.
## Rules are read from the JSON rather than hardcoded, so renaming a weapon in
## content-data changes what is tested instead of breaking the test.

const GameDataScript = preload("res://scripts/core/game_data.gd")
const RunStateScript = preload("res://scripts/core/run_state.gd")
const EvolutionScript = preload("res://scripts/weapons/evolution.gd")

const DATA_DIR := "res://data"
const EVOLUTIONS_PATH := "res://data/evolutions.json"


func run() -> Array[String]:
	var rules: Dictionary = _load_rules()
	if rules.is_empty():
		return ["could not read %s" % EVOLUTIONS_PATH]

	var failures: Array[String] = []
	for rule_key: Variant in rules.keys():
		var rule: Dictionary = rules[rule_key]
		failures.append_array(_test_rule(String(rule_key), rule))
	return failures


## Reads evolutions.json directly: GameData exposes no rule enumerator, and the
## point of this test is to check every shipped rule, not a hardcoded list.
func _load_rules() -> Dictionary:
	if not FileAccess.file_exists(EVOLUTIONS_PATH):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(EVOLUTIONS_PATH)) != OK:
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data


func _test_rule(rule_id: String, rule: Dictionary) -> Array[String]:
	var weapon_id: String = String(rule.get("requires_weapon", ""))
	var passive_id: String = String(rule.get("requires_passive", ""))
	var min_level: int = int(rule.get("min_weapon_level", 1))
	var min_stacks: int = int(rule.get("min_passive_stacks", 1))
	var expected: String = String(rule.get("result_weapon", rule_id))

	var failures: Array[String] = []

	# One short of the weapon level: GameData must withhold the evolution.
	var below: Dictionary = _seed(weapon_id, min_level - 1, passive_id, min_stacks)
	if not _find(below, weapon_id).is_empty():
		failures.append("%s: evolved at weapon level %d, below min_weapon_level %d" % [rule_id, min_level - 1, min_level])

	# One short of the passive stacks: likewise.
	var thin: Dictionary = _seed(weapon_id, min_level, passive_id, min_stacks - 1)
	if not _find(thin, weapon_id).is_empty():
		failures.append("%s: evolved at %d stacks, below min_passive_stacks %d" % [rule_id, min_stacks - 1, min_stacks])

	# Exactly at both thresholds: it must fire, and name the right weapon.
	var ready_state: Dictionary = _seed(weapon_id, min_level, passive_id, min_stacks)
	var reached_level: int = int(ready_state["level"])
	var reached_stacks: int = int(ready_state["stacks"])
	if reached_level < min_level or reached_stacks < min_stacks:
		_release(below)
		_release(thin)
		_release(ready_state)
		return failures + ["%s: content caps (%d level / %d stacks) below its own rule (%d / %d)" % [
			rule_id, reached_level, reached_stacks, min_level, min_stacks,
		]]

	var match_result: Dictionary = _find(ready_state, weapon_id)
	_release(below)
	_release(thin)
	_release(ready_state)
	if match_result.is_empty():
		failures.append("%s: no evolution at %s level %d with %s x%d" % [rule_id, weapon_id, min_level, passive_id, min_stacks])
		return failures
	if String(match_result[EvolutionScript.KEY_TO_ID]) != expected:
		failures.append("%s: expected %s, got %s" % [rule_id, expected, match_result[EvolutionScript.KEY_TO_ID]])
	return failures


## Builds a throwaway GameData+RunState pair holding the given weapon level and
## passive stacks. Nothing here touches the live autoloads.
func _seed(weapon_id: String, weapon_level: int, passive_id: String, passive_stacks: int) -> Dictionary:
	var content: Node = GameDataScript.new()
	var run: Node = RunStateScript.new()
	content.run_state = run
	run.content = content
	content.load_from_dir(DATA_DIR)

	for _index in maxi(weapon_level, 0):
		run.grant_weapon(weapon_id)
	for _index in maxi(passive_stacks, 0):
		run.grant_passive(passive_id)

	return {
		"content": content,
		"run": run,
		"level": run.weapon_level(weapon_id),
		"stacks": run.passive_stacks(passive_id),
	}


func _find(state: Dictionary, weapon_id: String) -> Dictionary:
	var content: Node = state["content"]
	var run: Node = state["run"]
	return EvolutionScript.find_match(weapon_id, run.passives, Callable(content, "evolution_for"))


func _release(state: Dictionary) -> void:
	for key: Variant in ["content", "run"]:
		var node: Node = state.get(key)
		if node != null:
			node.free()
