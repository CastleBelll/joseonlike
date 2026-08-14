extends RefCounted
## LootChoice.build_options: use options appear only for owned weapons with a
## recipe whose result is not already held; keep and salvage always close the
## list; salvage shows the data-declared gold.

const GAME_DATA_SCRIPT := preload("res://scripts/core/game_data.gd")
const LOOT_CHOICE_SCRIPT := preload("res://scripts/ui/loot_choice.gd")

const FIXTURES_DIR := "res://tests/core/fixtures"


func run() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(_test_use_option_for_matching_recipe())
	failures.append_array(_test_use_filtered_when_result_owned())
	failures.append_array(_test_recipeless_loot_offers_keep_and_salvage())
	return failures


func _test_use_option_for_matching_recipe() -> Array[String]:
	var failures: Array[String] = []
	var data := _loaded_data()
	var owned: Array[Dictionary] = [{"id": "poison_knife", "level": 1}]

	var options: Array[Dictionary] = LOOT_CHOICE_SCRIPT.build_options(
		"whetstone", data.loot("whetstone"), owned, data)

	if options.size() != 3:
		failures.append("expected use+keep+salvage, got %d options" % options.size())
	elif String(options[0].get("id", "")) != "use:poison_knife":
		failures.append("first option should be use:poison_knife, got %s" % options[0].get("id"))
	if String(options[-1].get("id", "")) != "salvage":
		failures.append("salvage must close the list")
	elif not String(options[-1].get("description", "")).contains("8"):
		failures.append("salvage description does not show the fixture's 8 gold")

	data.free()
	return failures


func _test_use_filtered_when_result_owned() -> Array[String]:
	var failures: Array[String] = []
	var data := _loaded_data()
	var owned: Array[Dictionary] = [
		{"id": "poison_knife", "level": 1},
		{"id": "sharp_knife", "level": 1},
	]

	var options: Array[Dictionary] = LOOT_CHOICE_SCRIPT.build_options(
		"whetstone", data.loot("whetstone"), owned, data)

	for option in options:
		if String(option.get("id", "")).begins_with("use:"):
			failures.append("offered a mod whose result is already held")
			break

	data.free()
	return failures


func _test_recipeless_loot_offers_keep_and_salvage() -> Array[String]:
	var failures: Array[String] = []
	var data := _loaded_data()
	var owned: Array[Dictionary] = [{"id": "poison_knife", "level": 1}]

	var options: Array[Dictionary] = LOOT_CHOICE_SCRIPT.build_options(
		"beast_fang", data.loot("beast_fang"), owned, data)

	if options.size() != 2:
		failures.append("recipeless loot should offer exactly keep+salvage, got %d" % options.size())
	elif String(options[0].get("id", "")) != "keep":
		failures.append("keep should lead when no recipe matches")

	data.free()
	return failures


func _loaded_data() -> Node:
	var data: Node = GAME_DATA_SCRIPT.new()
	var result: Error = data.load_from_dir(FIXTURES_DIR)
	if result != OK:
		push_error("test_loot_choice: fixtures failed to load (error %d)" % result)
	return data
