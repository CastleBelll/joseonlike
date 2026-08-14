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
const PASSIVE_FIELDS: Array[String] = ["per_stack", "max_stacks"]
const ORB_FIELDS: Array[String] = [
	"magnet_radius_px", "collect_radius_px", "magnet_accel_px_s2", "max_speed_px_s"
]
# N3-9 prop field contract (data/props.json).
const PROP_FIELD_FIELDS: Array[String] = [
	"width_px", "height_px", "edge_margin_px", "solid_count", "decor_count",
	"min_gap_px", "spawn_clear_radius_px", "max_attempts_per_prop"
]
const PROP_ALLOWED_KEYS: Array[String] = [
	"size", "collision", "solid", "weight", "shape", "texture", "placeholder"
]
const PROP_SHAPES: Array[String] = ["rect", "round"]

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
	# N3-6 power-up pool: every passive needs a display name and a usable
	# stack contract, and every offerable stat id must still exist in the file.
	var passives: Dictionary = _load(DATA_DIR + "/passives.json")
	for passive_id: String in passives:
		var passive: Dictionary = passives[passive_id]
		_require_positive_numbers(passive, PASSIVE_FIELDS, "passives." + passive_id)
		if String(passive.get("name_ko", "")).is_empty():
			_fail("passives.%s.name_ko missing or empty" % passive_id)
	for offered_id: String in LevelUp.OFFERABLE_PASSIVES:
		if not passives.has(offered_id):
			_fail("LevelUp.OFFERABLE_PASSIVES id '%s' not in passives.json" % offered_id)
	var progression: Dictionary = _load(DATA_DIR + "/progression.json")
	_require_positive_numbers(
		progression.get("xp_curve", {}), XP_CURVE_FIELDS, "progression.xp_curve"
	)
	_require_positive_numbers(progression.get("orb", {}), ORB_FIELDS, "progression.orb")
	# growth 1.0 or below would make the level-up loop free or non-terminating.
	if float((progression.get("xp_curve", {}) as Dictionary).get("growth", 0.0)) <= 1.0:
		_fail("progression.xp_curve.growth must be greater than 1.0")
	_check_props()


## N3-9 prop catalogue: sizes positive, collision boxes inside sprite bounds,
## weights positive, unknown keys/placeholders/shapes rejected.
func _check_props() -> void:
	var data: Dictionary = _load(DATA_DIR + "/props.json")
	_require_positive_numbers(data.get("field", {}), PROP_FIELD_FIELDS, "props.field")
	var catalog: Dictionary = data.get("props", {})
	if catalog.is_empty():
		_fail("props.json 'props' missing or empty")
	for prop_id: String in catalog:
		var prop: Dictionary = catalog[prop_id]
		var label: String = "props." + prop_id
		for key: String in prop:
			if key not in PROP_ALLOWED_KEYS:
				_fail("%s has unknown key '%s'" % [label, key])
		if prop.get("solid") is not bool:
			_fail(label + ".solid missing or not a bool")
		if float(prop.get("weight", 0.0)) <= 0.0:
			_fail(label + ".weight missing or not positive")
		if String(prop.get("shape", "")) not in PROP_SHAPES:
			_fail(label + ".shape must be one of " + str(PROP_SHAPES))
		if not String(prop.get("texture", "")).begins_with("res://"):
			_fail(label + ".texture must be a res:// path")
		if not StageField.PLACEHOLDER_COLORS.has(String(prop.get("placeholder", ""))):
			_fail(label + ".placeholder not a known palette token")
		var size: Array = prop.get("size", [])
		if size.size() != 2 or float(size[0]) <= 0.0 or float(size[1]) <= 0.0:
			_fail(label + ".size must be [width, height] with positive numbers")
			continue
		_check_prop_collision(prop, label, float(size[0]), float(size[1]))


## Collision boxes are relative to the bottom-center origin: the sprite spans
## x in [-w/2, w/2] and y in [-h, 0], and the box must sit inside that.
func _check_prop_collision(
	prop: Dictionary, label: String, width: float, height: float
) -> void:
	if not bool(prop.get("solid", false)):
		if prop.has("collision"):
			_fail(label + " is decor and must not define a collision box")
		return
	var box: Array = prop.get("collision", [])
	if box.size() != 4:
		_fail(label + ".collision must be [x, y, width, height]")
		return
	var box_w: float = float(box[2])
	var box_h: float = float(box[3])
	if box_w <= 0.0 or box_h <= 0.0:
		_fail(label + ".collision width/height must be positive")
		return
	var inside: bool = (
		float(box[0]) >= -width / 2.0
		and float(box[0]) + box_w <= width / 2.0
		and float(box[1]) >= -height
		and float(box[1]) + box_h <= 0.0
	)
	if not inside:
		_fail(label + ".collision box exceeds the sprite bounds")


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
