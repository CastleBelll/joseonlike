extends RefCounted
## GameData: fixture loading, copy isolation, missing ids, malformed content,
## and evolution thresholds.

const GAME_DATA_SCRIPT := preload("res://scripts/core/game_data.gd")
const RUN_STATE_SCRIPT := preload("res://scripts/core/run_state.gd")

const FIXTURES_DIR := "res://tests/core/fixtures"
const MALFORMED_DIR := "res://tests/core/fixtures_malformed"
const ABSENT_DIR := "res://tests/core/fixtures_absent"

const MUTATED_DAMAGE := 999.0


func run() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(_test_loads_fixtures())
	failures.append_array(_test_accessors_return_deep_copies())
	failures.append_array(_test_missing_id_returns_empty())
	failures.append_array(_test_malformed_json_is_reported())
	failures.append_array(_test_missing_file_is_reported())
	failures.append_array(_test_evolution_honours_thresholds())
	failures.append_array(_test_list_accessors_carry_id())
	return failures


func _test_loads_fixtures() -> Array[String]:
	var failures: Array[String] = []
	var data := _loaded_data()

	if String(data.weapon("old_talisman").get("name_en", "")) != "Old Talisman":
		failures.append("weapon(\"old_talisman\").name_en did not round-trip")
	if data.character("taoist").is_empty():
		failures.append("character(\"taoist\") is empty after loading fixtures")
	if data.stage("bamboo_forest").is_empty():
		failures.append("stage(\"bamboo_forest\") is empty after loading fixtures")

	data.free()
	return failures


func _test_accessors_return_deep_copies() -> Array[String]:
	var failures: Array[String] = []
	var data := _loaded_data()

	var first: Dictionary = data.weapon("old_talisman")
	first["damage"] = MUTATED_DAMAGE
	(first["per_level"] as Dictionary)["damage"] = MUTATED_DAMAGE

	var second: Dictionary = data.weapon("old_talisman")
	if is_equal_approx(float(second.get("damage", 0.0)), MUTATED_DAMAGE):
		failures.append("mutating a returned weapon corrupted the cache")
	if is_equal_approx(float((second["per_level"] as Dictionary).get("damage", 0.0)), MUTATED_DAMAGE):
		failures.append("nested dictionaries are shared; the copy is not deep")

	data.free()
	return failures


func _test_missing_id_returns_empty() -> Array[String]:
	var failures: Array[String] = []
	var data := _loaded_data()

	_mute_expected_errors(true)
	var missing_weapon: Dictionary = data.weapon("no_such_weapon")
	var missing_passive: Dictionary = data.passive("no_such_passive")
	_mute_expected_errors(false)

	if not missing_weapon.is_empty():
		failures.append("weapon(unknown id) returned %d keys, expected {}" % missing_weapon.size())
	if not missing_passive.is_empty():
		failures.append("passive(unknown id) returned %d keys, expected {}" % missing_passive.size())

	data.free()
	return failures


func _test_malformed_json_is_reported() -> Array[String]:
	var failures: Array[String] = []
	var data: Node = GAME_DATA_SCRIPT.new()

	_mute_expected_errors(true)
	var result: Error = data.load_from_dir(MALFORMED_DIR)
	_mute_expected_errors(false)

	if result != ERR_PARSE_ERROR:
		failures.append("malformed JSON returned %d, expected ERR_PARSE_ERROR" % result)

	data.free()
	return failures


func _test_missing_file_is_reported() -> Array[String]:
	var failures: Array[String] = []
	var data: Node = GAME_DATA_SCRIPT.new()

	_mute_expected_errors(true)
	var result: Error = data.load_from_dir(ABSENT_DIR)
	_mute_expected_errors(false)

	if result != ERR_PARSE_ERROR:
		failures.append("missing data dir returned %d, expected ERR_PARSE_ERROR" % result)

	data.free()
	return failures


func _test_evolution_honours_thresholds() -> Array[String]:
	var failures: Array[String] = []
	var data := _loaded_data()
	var run: Node = RUN_STATE_SCRIPT.new()
	run.content = data
	data.run_state = run

	# Fixture rule: fire_talisman + skill_power, min level 2, min stacks 2.
	run.grant_weapon("fire_talisman")
	run.grant_passive("skill_power")

	if data.evolution_for("fire_talisman", "skill_power") != "":
		failures.append("evolved below both thresholds")

	run.grant_passive("skill_power")
	if data.evolution_for("fire_talisman", "skill_power") != "":
		failures.append("evolved with stacks met but weapon level 1 < 2")

	run.grant_weapon("fire_talisman")
	var evolved: String = data.evolution_for("fire_talisman", "skill_power")
	if evolved != "phoenix_talisman":
		failures.append("thresholds met but evolution_for returned \"%s\"" % evolved)

	if data.evolution_for("short_bow", "attack_speed") != "":
		failures.append("a pair with no rule returned a non-empty evolution")

	run.free()
	data.free()
	return failures


func _test_list_accessors_carry_id() -> Array[String]:
	var failures: Array[String] = []
	var data := _loaded_data()

	var characters: Array[Dictionary] = data.all_characters()
	if characters.size() != 1:
		failures.append("all_characters() returned %d entries, expected 1" % characters.size())
	elif String(characters[0].get("id", "")) != "taoist":
		failures.append("all_characters() entries do not carry their id")

	if data.all_achievements().is_empty():
		failures.append("all_achievements() is empty despite a fixture entry")

	data.free()
	return failures


func _loaded_data() -> Node:
	var data: Node = GAME_DATA_SCRIPT.new()
	var result: Error = data.load_from_dir(FIXTURES_DIR)
	if result != OK:
		push_error("test_game_data: fixtures failed to load (error %d)" % result)
	return data


## Several cases deliberately trip push_error. Muting keeps the runner output
## meaningful: anything still printed is a real problem.
func _mute_expected_errors(muted: bool) -> void:
	Engine.print_error_messages = not muted
