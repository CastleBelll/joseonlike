extends RefCounted
## Weapon mods: mod_for lookup and RunState.apply_weapon_mod — material
## consumption, in-place swap with level inheritance, and every refusal path.

const GAME_DATA_SCRIPT := preload("res://scripts/core/game_data.gd")
const RUN_STATE_SCRIPT := preload("res://scripts/core/run_state.gd")

const FIXTURES_DIR := "res://tests/core/fixtures"


func run() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(_test_mod_for_lookup())
	failures.append_array(_test_apply_consumes_and_swaps())
	failures.append_array(_test_apply_refusals())
	return failures


func _test_mod_for_lookup() -> Array[String]:
	var failures: Array[String] = []
	var data := _loaded_data()

	if data.mod_for("poison_knife", "whetstone") != "sharp_knife":
		failures.append("mod_for(poison_knife, whetstone) did not resolve sharp_knife")
	if data.mod_for("old_talisman", "whetstone") != "":
		failures.append("a pair without a recipe returned a non-empty mod")

	data.free()
	return failures


func _test_apply_consumes_and_swaps() -> Array[String]:
	var failures: Array[String] = []
	var data := _loaded_data()
	var run: Node = RUN_STATE_SCRIPT.new()
	run.content = data

	run.grant_weapon("poison_knife")
	run.grant_weapon("poison_knife")  # level 2, so inheritance is observable
	run.add_loot("whetstone")

	if not run.apply_weapon_mod("poison_knife", "whetstone"):
		failures.append("a valid mod was refused")
	if run.weapon_level("sharp_knife") != 2:
		failures.append("sharp_knife level = %d, expected the inherited 2" % run.weapon_level("sharp_knife"))
	if run.weapon_level("poison_knife") != 0:
		failures.append("poison_knife still held after the mod")
	if run.loot_count("whetstone") != 0:
		failures.append("the whetstone was not consumed")

	run.free()
	data.free()
	return failures


func _test_apply_refusals() -> Array[String]:
	var failures: Array[String] = []
	var data := _loaded_data()
	var run: Node = RUN_STATE_SCRIPT.new()
	run.content = data

	_mute_expected_warnings(true)
	if run.apply_weapon_mod("old_talisman", "whetstone"):
		failures.append("a pair without a recipe was applied")
	if run.apply_weapon_mod("poison_knife", "whetstone"):
		failures.append("modded a weapon the run does not hold")
	run.grant_weapon("poison_knife")
	if run.apply_weapon_mod("poison_knife", "whetstone"):
		failures.append("modded with no material in stock")
	run.add_loot("whetstone")
	run.grant_weapon("sharp_knife")
	if run.apply_weapon_mod("poison_knife", "whetstone"):
		failures.append("modded into an already-held result weapon")
	if run.loot_count("whetstone") != 1:
		failures.append("a refused mod still consumed the material")
	_mute_expected_warnings(false)

	if run.weapon_level("poison_knife") != 1:
		failures.append("a refused mod still changed the loadout")

	run.free()
	data.free()
	return failures


func _loaded_data() -> Node:
	var data: Node = GAME_DATA_SCRIPT.new()
	var result: Error = data.load_from_dir(FIXTURES_DIR)
	if result != OK:
		push_error("test_weapon_mods: fixtures failed to load (error %d)" % result)
	return data


## Refusal paths deliberately push_warning; muting keeps the runner output
## meaningful (same discipline as test_game_data).
func _mute_expected_warnings(muted: bool) -> void:
	Engine.print_error_messages = not muted
