extends RefCounted
## Loot data access: loot() round-trip, drop_table() lookup, tableless
## monsters staying silent, and copy isolation for drop tables.

const GAME_DATA_SCRIPT := preload("res://scripts/core/game_data.gd")

const FIXTURES_DIR := "res://tests/core/fixtures"

const MUTATED_CHANCE := 999.0


func run() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(_test_loot_round_trip())
	failures.append_array(_test_unknown_loot_returns_empty())
	failures.append_array(_test_drop_table_lookup())
	failures.append_array(_test_tableless_monster_is_silent())
	failures.append_array(_test_drop_table_returns_deep_copy())
	return failures


func _test_loot_round_trip() -> Array[String]:
	var failures: Array[String] = []
	var data := _loaded_data()

	var whetstone: Dictionary = data.loot("whetstone")
	if String(whetstone.get("name_en", "")) != "Whetstone":
		failures.append("loot(\"whetstone\").name_en did not round-trip")
	if whetstone.get("special") != true:
		failures.append("loot(\"whetstone\").special should be true")
	if String(whetstone.get("tier", "")) != "rare":
		failures.append("loot(\"whetstone\").tier did not round-trip")

	data.free()
	return failures


func _test_unknown_loot_returns_empty() -> Array[String]:
	var failures: Array[String] = []
	var data := _loaded_data()

	_mute_expected_errors(true)
	var missing: Dictionary = data.loot("no_such_loot")
	_mute_expected_errors(false)

	if not missing.is_empty():
		failures.append("loot(unknown id) returned %d keys, expected {}" % missing.size())

	data.free()
	return failures


func _test_drop_table_lookup() -> Array[String]:
	var failures: Array[String] = []
	var data := _loaded_data()

	var table: Dictionary = data.drop_table("forest_goblin")
	var drops: Variant = table.get("drops")
	if not (drops is Array) or (drops as Array).size() != 2:
		failures.append("drop_table(\"forest_goblin\").drops should have 2 entries")
	else:
		var first: Dictionary = (drops as Array)[0]
		if String(first.get("loot_id", "")) != "beast_fang":
			failures.append("drop_table first loot_id did not round-trip")

	data.free()
	return failures


func _test_tableless_monster_is_silent() -> Array[String]:
	var failures: Array[String] = []
	var data := _loaded_data()

	# Most monsters have no table; this must return {} without a push_error,
	# so no muting here — a printed error would surface in the runner output.
	var table: Dictionary = data.drop_table("no_table_monster")
	if not table.is_empty():
		failures.append("drop_table(tableless monster) returned %d keys, expected {}" % table.size())

	data.free()
	return failures


func _test_drop_table_returns_deep_copy() -> Array[String]:
	var failures: Array[String] = []
	var data := _loaded_data()

	var first: Dictionary = data.drop_table("forest_goblin")
	((first["drops"] as Array)[0] as Dictionary)["chance"] = MUTATED_CHANCE

	var second: Dictionary = data.drop_table("forest_goblin")
	var chance: float = float(((second["drops"] as Array)[0] as Dictionary).get("chance", 0.0))
	if is_equal_approx(chance, MUTATED_CHANCE):
		failures.append("mutating a returned drop table corrupted the cache")

	data.free()
	return failures


func _loaded_data() -> Node:
	var data: Node = GAME_DATA_SCRIPT.new()
	var result: Error = data.load_from_dir(FIXTURES_DIR)
	if result != OK:
		push_error("test_loot_data: fixtures failed to load (error %d)" % result)
	return data


## Cases that deliberately trip push_error mute it, so anything still printed
## by the runner is a real problem.
func _mute_expected_errors(muted: bool) -> void:
	Engine.print_error_messages = not muted
