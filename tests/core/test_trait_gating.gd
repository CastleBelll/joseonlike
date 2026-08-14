extends RefCounted
## Synergy passives are offered only while an owned weapon can trigger them:
## burn_power needs a weapon with on_hit_status in the loadout.

const GAME_DATA_SCRIPT := preload("res://scripts/core/game_data.gd")
const RUN_STATE_SCRIPT := preload("res://scripts/core/run_state.gd")

const FIXTURES_DIR := "res://tests/core/fixtures"


func run() -> Array[String]:
	var failures: Array[String] = []
	var data: Node = GAME_DATA_SCRIPT.new()
	if data.load_from_dir(FIXTURES_DIR) != OK:
		data.free()
		return ["fixtures failed to load"]
	var run: Node = RUN_STATE_SCRIPT.new()
	run.content = data

	# short_bow has no on_hit payloads, so burn_power must not be offered.
	run.grant_weapon("short_bow")
	if _offers_stat(run, "burn_power"):
		failures.append("burn_power offered without a burning weapon")

	# fire_talisman carries on_hit_status, so the gate opens.
	run.grant_weapon("fire_talisman")
	if not _offers_stat(run, "burn_power"):
		failures.append("burn_power not offered despite a burning weapon")

	run.free()
	data.free()
	return failures


func _offers_stat(run: Node, stat: String) -> bool:
	for choice: Dictionary in run._passive_choices():
		if String(choice.get("id", "")) == stat:
			return true
	return false
