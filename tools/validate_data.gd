extends SceneTree
## Minimal data validator: every data/*.json must parse as valid JSON, and the
## cross-references the combat systems consume (N3-4) must resolve.
## Contract (see docs/CI.md): godot --headless --path . --script tools/validate_data.gd

const DATA_DIR := "res://data"
const SPAWNING_FIELDS: Array[String] = [
	"live_cap", "spawn_margin_px", "despawn_margin_px", "contact_cooldown_sec"
]
const CHARACTER_FIELDS: Array[String] = ["base_hp", "base_speed", "hit_invuln_sec"]
const MONSTER_FIELDS: Array[String] = ["hp", "damage", "speed", "collision_radius", "xp_drop"]
const XP_CURVE_FIELDS: Array[String] = ["base_xp", "growth"]
const ORB_FIELDS: Array[String] = [
	"magnet_radius_px", "collect_radius_px", "magnet_accel_px_s2", "max_speed_px_s"
]

var _errors: int = 0


func _init() -> void:
	var checked: int = 0
	var dir: DirAccess = DirAccess.open(DATA_DIR)
	if dir == null:
		push_error("validate_data: cannot open " + DATA_DIR)
		quit(1)
		return
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		checked += 1
		var text: String = FileAccess.get_file_as_string(DATA_DIR + "/" + file_name)
		if JSON.parse_string(text) == null:
			_fail("invalid JSON in " + file_name)
	_check_combat_cross_references()
	if _errors > 0:
		print("FAIL %d data validation error(s) across %d json files" % [_errors, checked])
		quit(1)
		return
	print("PASS data validation: %d json files ok" % checked)
	quit(0)


func _check_combat_cross_references() -> void:
	var monsters: Dictionary = _load(DATA_DIR + "/monsters.json")
	var stages: Dictionary = _load(DATA_DIR + "/stages.json")
	var characters: Dictionary = _load(DATA_DIR + "/characters.json")
	for monster_id: String in monsters:
		_require_positive_numbers(monsters[monster_id], MONSTER_FIELDS, "monsters." + monster_id)
	for stage_id: String in stages:
		var stage: Dictionary = stages[stage_id]
		if not monsters.has(stage.get("boss_id", "")):
			_fail("stages.%s.boss_id not in monsters.json" % stage_id)
		_require_positive_numbers(
			stage.get("spawning", {}), SPAWNING_FIELDS, "stages.%s.spawning" % stage_id
		)
		for wave: Dictionary in stage.get("waves", []):
			if not monsters.has(wave.get("monster_id", "")):
				_fail("stages.%s wave monster_id '%s' not in monsters.json" % [
					stage_id, wave.get("monster_id", "")
				])
	var weapons: Dictionary = _load(DATA_DIR + "/weapons.json")
	for character_id: String in characters:
		_require_positive_numbers(
			characters[character_id], CHARACTER_FIELDS, "characters." + character_id
		)
		var starting_weapon: String = String(
			(characters[character_id] as Dictionary).get("starting_weapon", "")
		)
		if not weapons.has(starting_weapon):
			_fail("characters.%s.starting_weapon '%s' not in weapons.json" % [
				character_id, starting_weapon
			])
	var progression: Dictionary = _load(DATA_DIR + "/progression.json")
	_require_positive_numbers(
		progression.get("xp_curve", {}), XP_CURVE_FIELDS, "progression.xp_curve"
	)
	_require_positive_numbers(progression.get("orb", {}), ORB_FIELDS, "progression.orb")
	# growth 1.0 or below would make the level-up loop free or non-terminating.
	if float((progression.get("xp_curve", {}) as Dictionary).get("growth", 0.0)) <= 1.0:
		_fail("progression.xp_curve.growth must be greater than 1.0")


func _require_positive_numbers(entry: Dictionary, fields: Array[String], label: String) -> void:
	for field: String in fields:
		var value: Variant = entry.get(field)
		if (value is not float and value is not int) or float(value) <= 0.0:
			_fail("%s.%s missing or not a positive number" % [label, field])


func _fail(message: String) -> void:
	push_error("validate_data: " + message)
	_errors += 1


func _load(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}
