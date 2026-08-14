extends SceneTree
## Headless content validator: godot --headless --path . --script tools/validate_data.gd
##
## Fails loudly (nonzero exit, one message per problem naming file/id/field) on any
## schema violation in data/*.json: unknown cross-reference ids, enum values outside
## the frozen sets, missing required fields, non-snake_case ids, and values that are
## negative or zero where that makes no sense.
##
## validate_all() is a static func so tests/data/test_content.gd can call it directly
## (via preload) without re-implementing these checks, per the tests/run_tests.gd
## `func run() -> Array[String]` contract.

const DATA_DIR := "res://data"

const CHARACTER_UNLOCK_TYPES: Array[String] = ["default", "achievement", "gold"]
const WEAPON_CATEGORIES: Array[String] = ["melee", "ranged", "spiritual"]
const WEAPON_GRADES: Array[String] = ["common", "rare", "epic", "legendary", "mythic"]
const MONSTER_BEHAVIOURS: Array[String] = ["chase", "ranged", "charger", "swarm", "boss"]
const PASSIVE_STAT_KEYS: Array[String] = [
	"attack_damage", "attack_speed", "move_speed", "crit_chance",
	"max_hp", "xp_gain", "luck", "skill_power",
]
const ACHIEVEMENT_COUNTER_KEYS: Array[String] = [
	"boss_defeated", "enemy_killed", "run_completed", "level_reached", "weapon_evolved",
]

const CHARACTER_REQUIRED: Array[String] = [
	"name_ko", "name_en", "role", "base_hp", "base_speed", "starting_weapon", "unlock",
]
const WEAPON_REQUIRED: Array[String] = [
	"name_ko", "name_en", "category", "grade", "damage", "cooldown_sec",
	"projectile_count", "pierce", "area_scale", "speed", "max_level", "per_level",
	"evolution_only", "sprite",
]
const PASSIVE_REQUIRED: Array[String] = ["name_ko", "name_en", "stat", "per_stack", "max_stacks"]
const EVOLUTION_REQUIRED: Array[String] = [
	"requires_weapon", "requires_passive", "min_weapon_level", "min_passive_stacks", "result_weapon",
]
const MONSTER_REQUIRED: Array[String] = [
	"name_ko", "name_en", "hp", "damage", "speed", "xp_drop", "gold_drop", "behaviour",
	"collision_radius", "sprite",
]
const STAGE_REQUIRED: Array[String] = ["name_ko", "name_en", "duration_sec", "boss_id", "waves"]
const WAVE_REQUIRED: Array[String] = ["at_sec", "monster_id", "count", "interval_sec"]
const ACHIEVEMENT_REQUIRED: Array[String] = ["name_ko", "name_en", "counter_key", "target", "reward"]
const LOOT_TIERS: Array[String] = ["common", "uncommon", "rare", "epic", "legendary", "mythic"]
const LOOT_REQUIRED: Array[String] = ["name_ko", "name_en", "tier", "tags", "special"]
const DROP_REQUIRED: Array[String] = ["loot_id", "chance"]


func _init() -> void:
	var errors := validate_all()
	if errors.is_empty():
		print_rich("[color=green]PASS[/color] data validation: no errors")
		quit(0)
		return

	for message in errors:
		print_rich("[color=red]FAIL[/color] %s" % message)
	print_rich("[color=red]%d error(s) found[/color]" % errors.size())
	quit(1)


static func validate_all() -> Array[String]:
	var errors: Array[String] = []

	var characters := _load_json("characters.json", errors)
	var weapons := _load_json("weapons.json", errors)
	var passives := _load_json("passives.json", errors)
	var evolutions := _load_json("evolutions.json", errors)
	var monsters := _load_json("monsters.json", errors)
	var stages := _load_json("stages.json", errors)
	var achievements := _load_json("achievements.json", errors)
	var loot := _load_json("loot.json", errors)
	var drop_tables := _load_json("drop_tables.json", errors)

	_validate_characters(characters, weapons, achievements, errors)
	_validate_weapons(weapons, evolutions, errors)
	_validate_passives(passives, errors)
	_validate_evolutions(evolutions, weapons, passives, errors)
	_validate_monsters(monsters, errors)
	_validate_stages(stages, monsters, errors)
	_validate_achievements(achievements, errors)
	_validate_loot(loot, errors)
	_validate_drop_tables(drop_tables, monsters, loot, errors)

	return errors


static func _load_json(filename: String, errors: Array[String]) -> Dictionary:
	var path := "%s/%s" % [DATA_DIR, filename]
	if not FileAccess.file_exists(path):
		errors.append("%s: file not found" % filename)
		return {}

	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append("%s: root must be a JSON object keyed by id" % filename)
		return {}
	return parsed


static func _is_snake_case(id: String) -> bool:
	if id.is_empty():
		return false
	var regex := RegEx.new()
	regex.compile("^[a-z][a-z0-9_]*$")
	return regex.search(id) != null


static func _missing_fields(entry: Dictionary, required: Array[String]) -> Array[String]:
	var missing: Array[String] = []
	for key in required:
		if not entry.has(key):
			missing.append(key)
	return missing


static func _check_ids(file: String, collection: Dictionary, errors: Array[String]) -> void:
	for id in collection.keys():
		if not (id is String) or not _is_snake_case(id):
			errors.append("%s: id '%s' is not snake_case" % [file, id])


## Numeric fields only; returns NAN (never satisfies <, <=, > comparisons) for a
## missing or non-numeric value so a malformed field fails its check instead of
## crashing the validator.
static func _num(entry: Dictionary, key: String) -> float:
	var value: Variant = entry.get(key)
	if value is float or value is int:
		return float(value)
	return NAN


# ---- data/characters.json ----

static func _validate_characters(characters: Dictionary, weapons: Dictionary, achievements: Dictionary, errors: Array[String]) -> void:
	var file := "characters.json"
	_check_ids(file, characters, errors)

	for id in characters.keys():
		var c: Dictionary = characters[id]
		var missing := _missing_fields(c, CHARACTER_REQUIRED)
		for field in missing:
			errors.append("%s: '%s' missing required field '%s'" % [file, id, field])
		if not missing.is_empty():
			continue

		if _num(c, "base_hp") <= 0.0:
			errors.append("%s: '%s'.base_hp must be > 0" % [file, id])
		if _num(c, "base_speed") <= 0.0:
			errors.append("%s: '%s'.base_speed must be > 0" % [file, id])

		var starting_weapon: String = c.get("starting_weapon", "")
		if not weapons.has(starting_weapon):
			errors.append("%s: '%s'.starting_weapon '%s' does not exist in weapons.json" % [file, id, starting_weapon])

		var unlock: Variant = c.get("unlock")
		if not (unlock is Dictionary):
			errors.append("%s: '%s'.unlock must be an object" % [file, id])
			continue

		var unlock_type: String = unlock.get("type", "")
		if not CHARACTER_UNLOCK_TYPES.has(unlock_type):
			errors.append("%s: '%s'.unlock.type '%s' is not one of %s" % [file, id, unlock_type, CHARACTER_UNLOCK_TYPES])
		elif unlock_type == "achievement":
			var achievement_id: String = unlock.get("achievement_id", "")
			if not achievements.has(achievement_id):
				errors.append("%s: '%s'.unlock.achievement_id '%s' does not exist in achievements.json" % [file, id, achievement_id])
		elif unlock_type == "gold":
			if _num(unlock, "cost") <= 0.0:
				errors.append("%s: '%s'.unlock.cost must be > 0" % [file, id])


## Every result_weapon named by an evolutions.json rule, as a set (Dictionary
## used for O(1) `.has()`; values are unused). Shared by the evolves_to and
## evolution_only reachability checks so an id must be an actual evolution
## payoff, not merely another entry in weapons.json.
static func _result_weapons(evolutions: Dictionary) -> Dictionary:
	var produced: Dictionary = {}
	for rule_id in evolutions.keys():
		var entry: Variant = evolutions[rule_id]
		if not (entry is Dictionary):
			continue
		var result_weapon: Variant = entry.get("result_weapon")
		if result_weapon is String and not result_weapon.is_empty():
			produced[result_weapon] = true
	return produced


# ---- data/weapons.json ----

static func _validate_weapons(weapons: Dictionary, evolutions: Dictionary, errors: Array[String]) -> void:
	var file := "weapons.json"
	_check_ids(file, weapons, errors)

	var produced_weapons: Dictionary = _result_weapons(evolutions)

	for id in weapons.keys():
		var w: Dictionary = weapons[id]
		var missing := _missing_fields(w, WEAPON_REQUIRED)
		for field in missing:
			errors.append("%s: '%s' missing required field '%s'" % [file, id, field])
		if not missing.is_empty():
			continue

		var category: String = w.get("category", "")
		if not WEAPON_CATEGORIES.has(category):
			errors.append("%s: '%s'.category '%s' is not one of %s" % [file, id, category, WEAPON_CATEGORIES])
		var grade: String = w.get("grade", "")
		if not WEAPON_GRADES.has(grade):
			errors.append("%s: '%s'.grade '%s' is not one of %s" % [file, id, grade, WEAPON_GRADES])

		if _num(w, "damage") <= 0.0:
			errors.append("%s: '%s'.damage must be > 0" % [file, id])
		if _num(w, "cooldown_sec") <= 0.0:
			errors.append("%s: '%s'.cooldown_sec must be > 0" % [file, id])
		if _num(w, "projectile_count") <= 0.0:
			errors.append("%s: '%s'.projectile_count must be > 0" % [file, id])
		if _num(w, "pierce") < 0.0:
			errors.append("%s: '%s'.pierce must be >= 0" % [file, id])
		if _num(w, "area_scale") <= 0.0:
			errors.append("%s: '%s'.area_scale must be > 0" % [file, id])
		if _num(w, "speed") < 0.0:
			errors.append("%s: '%s'.speed must be >= 0" % [file, id])
		if _num(w, "max_level") <= 0.0:
			errors.append("%s: '%s'.max_level must be > 0" % [file, id])

		var per_level: Variant = w.get("per_level")
		if not (per_level is Dictionary) or per_level.is_empty():
			errors.append("%s: '%s'.per_level must be a non-empty object" % [file, id])

		var evolution_only: Variant = w.get("evolution_only")
		if not (evolution_only is bool):
			errors.append("%s: '%s'.evolution_only must be a boolean" % [file, id])
		elif evolution_only == true and not produced_weapons.has(id):
			errors.append("%s: '%s' is evolution_only but no evolutions.json rule produces it — it is unreachable" % [file, id])

		if w.has("evolves_to"):
			var evolves_to: String = w.get("evolves_to", "")
			if not evolves_to.is_empty():
				if not weapons.has(evolves_to):
					errors.append("%s: '%s'.evolves_to '%s' does not exist in weapons.json" % [file, id, evolves_to])
				elif not produced_weapons.has(evolves_to):
					errors.append("%s: '%s'.evolves_to '%s' has no evolutions.json rule that produces it — dead pointer" % [file, id, evolves_to])

		var sprite: String = w.get("sprite", "")
		if not sprite.begins_with("res://"):
			errors.append("%s: '%s'.sprite must be a res:// path" % [file, id])
		elif not FileAccess.file_exists(sprite):
			errors.append("%s: '%s'.sprite '%s' does not exist" % [file, id, sprite])


# ---- data/passives.json ----

static func _validate_passives(passives: Dictionary, errors: Array[String]) -> void:
	var file := "passives.json"
	_check_ids(file, passives, errors)

	for id in passives.keys():
		var p: Dictionary = passives[id]
		var missing := _missing_fields(p, PASSIVE_REQUIRED)
		for field in missing:
			errors.append("%s: '%s' missing required field '%s'" % [file, id, field])
		if not missing.is_empty():
			continue

		var stat: String = p.get("stat", "")
		if not PASSIVE_STAT_KEYS.has(stat):
			errors.append("%s: '%s'.stat '%s' is not one of the frozen 8 stat keys %s" % [file, id, stat, PASSIVE_STAT_KEYS])
		if _num(p, "per_stack") <= 0.0:
			errors.append("%s: '%s'.per_stack must be > 0" % [file, id])
		if _num(p, "max_stacks") <= 0.0:
			errors.append("%s: '%s'.max_stacks must be > 0" % [file, id])


# ---- data/evolutions.json ----

static func _validate_evolutions(evolutions: Dictionary, weapons: Dictionary, passives: Dictionary, errors: Array[String]) -> void:
	var file := "evolutions.json"
	_check_ids(file, evolutions, errors)

	for id in evolutions.keys():
		var e: Dictionary = evolutions[id]
		var missing := _missing_fields(e, EVOLUTION_REQUIRED)
		for field in missing:
			errors.append("%s: '%s' missing required field '%s'" % [file, id, field])
		if not missing.is_empty():
			continue

		var requires_weapon: String = e.get("requires_weapon", "")
		if not weapons.has(requires_weapon):
			errors.append("%s: '%s'.requires_weapon '%s' does not exist in weapons.json" % [file, id, requires_weapon])
		var requires_passive: String = e.get("requires_passive", "")
		if not passives.has(requires_passive):
			errors.append("%s: '%s'.requires_passive '%s' does not exist in passives.json" % [file, id, requires_passive])
		var result_weapon: String = e.get("result_weapon", "")
		if not weapons.has(result_weapon):
			errors.append("%s: '%s'.result_weapon '%s' does not exist in weapons.json" % [file, id, result_weapon])

		if _num(e, "min_weapon_level") <= 0.0:
			errors.append("%s: '%s'.min_weapon_level must be > 0" % [file, id])
		if _num(e, "min_passive_stacks") <= 0.0:
			errors.append("%s: '%s'.min_passive_stacks must be > 0" % [file, id])


# ---- data/monsters.json ----

static func _validate_monsters(monsters: Dictionary, errors: Array[String]) -> void:
	var file := "monsters.json"
	_check_ids(file, monsters, errors)

	for id in monsters.keys():
		var m: Dictionary = monsters[id]
		var missing := _missing_fields(m, MONSTER_REQUIRED)
		for field in missing:
			errors.append("%s: '%s' missing required field '%s'" % [file, id, field])
		if not missing.is_empty():
			continue

		var behaviour: String = m.get("behaviour", "")
		if not MONSTER_BEHAVIOURS.has(behaviour):
			errors.append("%s: '%s'.behaviour '%s' is not one of %s" % [file, id, behaviour, MONSTER_BEHAVIOURS])

		if _num(m, "hp") <= 0.0:
			errors.append("%s: '%s'.hp must be > 0" % [file, id])
		if _num(m, "damage") <= 0.0:
			errors.append("%s: '%s'.damage must be > 0" % [file, id])
		if _num(m, "speed") < 0.0:
			errors.append("%s: '%s'.speed must be >= 0" % [file, id])
		if _num(m, "xp_drop") <= 0.0:
			errors.append("%s: '%s'.xp_drop must be > 0" % [file, id])
		if _num(m, "gold_drop") < 0.0:
			errors.append("%s: '%s'.gold_drop must be >= 0" % [file, id])

		var collision_radius: float = _num(m, "collision_radius")
		if collision_radius <= 0.0:
			errors.append("%s: '%s'.collision_radius must be > 0" % [file, id])

		var sprite: String = m.get("sprite", "")
		if not sprite.begins_with("res://"):
			errors.append("%s: '%s'.sprite must be a res:// path" % [file, id])
		elif not FileAccess.file_exists(sprite):
			errors.append("%s: '%s'.sprite '%s' does not exist" % [file, id, sprite])
		elif collision_radius > 0.0:
			# A typo-sized radius (e.g. the full canvas instead of the body) would
			# make the enemy an invisible wall, so cap it against the real sprite.
			# Image.load() prints an "export" warning that doesn't apply here — this
			# validator only ever runs headless from source, never from an export.
			var image := Image.new()
			if image.load(sprite) == OK:
				var half_width: float = image.get_width() / 2.0
				if collision_radius > half_width:
					errors.append("%s: '%s'.collision_radius %.1f exceeds half the sprite width (%dpx wide, max %.1f)" % [file, id, collision_radius, image.get_width(), half_width])


# ---- data/stages.json ----

static func _validate_stages(stages: Dictionary, monsters: Dictionary, errors: Array[String]) -> void:
	var file := "stages.json"
	_check_ids(file, stages, errors)

	for id in stages.keys():
		var s: Dictionary = stages[id]
		var missing := _missing_fields(s, STAGE_REQUIRED)
		for field in missing:
			errors.append("%s: '%s' missing required field '%s'" % [file, id, field])
		if not missing.is_empty():
			continue

		if _num(s, "duration_sec") <= 0.0:
			errors.append("%s: '%s'.duration_sec must be > 0" % [file, id])

		var boss_id: String = s.get("boss_id", "")
		if not monsters.has(boss_id):
			errors.append("%s: '%s'.boss_id '%s' does not exist in monsters.json" % [file, id, boss_id])
		elif monsters[boss_id].get("behaviour", "") != "boss":
			errors.append("%s: '%s'.boss_id '%s' does not have behaviour 'boss'" % [file, id, boss_id])

		var waves: Variant = s.get("waves")
		if not (waves is Array):
			errors.append("%s: '%s'.waves must be an array" % [file, id])
			continue

		for i in range(waves.size()):
			var wave: Variant = waves[i]
			if not (wave is Dictionary):
				errors.append("%s: '%s'.waves[%d] must be an object" % [file, id, i])
				continue

			var wave_missing := _missing_fields(wave, WAVE_REQUIRED)
			for field in wave_missing:
				errors.append("%s: '%s'.waves[%d] missing required field '%s'" % [file, id, i, field])
			if not wave_missing.is_empty():
				continue

			var monster_id: String = wave.get("monster_id", "")
			if not monsters.has(monster_id):
				errors.append("%s: '%s'.waves[%d].monster_id '%s' does not exist in monsters.json" % [file, id, i, monster_id])
			if _num(wave, "at_sec") < 0.0:
				errors.append("%s: '%s'.waves[%d].at_sec must be >= 0" % [file, id, i])
			if _num(wave, "count") <= 0.0:
				errors.append("%s: '%s'.waves[%d].count must be > 0" % [file, id, i])
			if _num(wave, "interval_sec") <= 0.0:
				errors.append("%s: '%s'.waves[%d].interval_sec must be > 0" % [file, id, i])


# ---- data/achievements.json ----

static func _validate_achievements(achievements: Dictionary, errors: Array[String]) -> void:
	var file := "achievements.json"
	_check_ids(file, achievements, errors)

	for id in achievements.keys():
		var a: Dictionary = achievements[id]
		var missing := _missing_fields(a, ACHIEVEMENT_REQUIRED)
		for field in missing:
			errors.append("%s: '%s' missing required field '%s'" % [file, id, field])
		if not missing.is_empty():
			continue

		var counter_key: String = a.get("counter_key", "")
		if not ACHIEVEMENT_COUNTER_KEYS.has(counter_key):
			errors.append("%s: '%s'.counter_key '%s' is not an emitted stat_recorded key %s" % [file, id, counter_key, ACHIEVEMENT_COUNTER_KEYS])
		if _num(a, "target") <= 0.0:
			errors.append("%s: '%s'.target must be > 0" % [file, id])

		var reward: Variant = a.get("reward")
		if not (reward is Dictionary):
			errors.append("%s: '%s'.reward must be an object" % [file, id])
			continue

		var reward_type: Variant = reward.get("type", "")
		if not (reward_type is String) or (reward_type as String).is_empty():
			errors.append("%s: '%s'.reward.type must be a non-empty string" % [file, id])
		if _num(reward, "amount") <= 0.0:
			errors.append("%s: '%s'.reward.amount must be > 0" % [file, id])


# ---- data/loot.json ----

static func _validate_loot(loot: Dictionary, errors: Array[String]) -> void:
	var file := "loot.json"
	_check_ids(file, loot, errors)

	for id in loot.keys():
		var entry: Variant = loot[id]
		if not (entry is Dictionary):
			errors.append("%s: '%s' must be an object" % [file, id])
			continue

		var l: Dictionary = entry
		var missing := _missing_fields(l, LOOT_REQUIRED)
		for field in missing:
			errors.append("%s: '%s' missing required field '%s'" % [file, id, field])
		if not missing.is_empty():
			continue

		var tier: String = l.get("tier", "")
		if not LOOT_TIERS.has(tier):
			errors.append("%s: '%s'.tier '%s' is not one of %s" % [file, id, tier, LOOT_TIERS])

		var tags: Variant = l.get("tags")
		if not (tags is Array) or (tags as Array).is_empty():
			errors.append("%s: '%s'.tags must be a non-empty array" % [file, id])
		else:
			for tag in (tags as Array):
				if not (tag is String) or (tag as String).is_empty():
					errors.append("%s: '%s'.tags entries must be non-empty strings" % [file, id])
					break

		if not (l.get("special") is bool):
			errors.append("%s: '%s'.special must be a boolean" % [file, id])


# ---- data/drop_tables.json ----

static func _validate_drop_tables(drop_tables: Dictionary, monsters: Dictionary, loot: Dictionary, errors: Array[String]) -> void:
	var file := "drop_tables.json"

	for monster_id in drop_tables.keys():
		if not monsters.has(monster_id):
			errors.append("%s: table key '%s' does not exist in monsters.json" % [file, monster_id])

		var entry: Variant = drop_tables[monster_id]
		if not (entry is Dictionary):
			errors.append("%s: '%s' must be an object" % [file, monster_id])
			continue

		var drops: Variant = (entry as Dictionary).get("drops")
		if not (drops is Array) or (drops as Array).is_empty():
			errors.append("%s: '%s'.drops must be a non-empty array" % [file, monster_id])
			continue

		for i in range((drops as Array).size()):
			var drop: Variant = (drops as Array)[i]
			if not (drop is Dictionary):
				errors.append("%s: '%s'.drops[%d] must be an object" % [file, monster_id, i])
				continue

			var drop_missing := _missing_fields(drop, DROP_REQUIRED)
			for field in drop_missing:
				errors.append("%s: '%s'.drops[%d] missing required field '%s'" % [file, monster_id, i, field])
			if not drop_missing.is_empty():
				continue

			var loot_id: String = drop.get("loot_id", "")
			if not loot.has(loot_id):
				errors.append("%s: '%s'.drops[%d].loot_id '%s' does not exist in loot.json" % [file, monster_id, i, loot_id])

			var chance := _num(drop, "chance")
			if not (chance > 0.0 and chance <= 1.0):
				errors.append("%s: '%s'.drops[%d].chance must be in (0, 1]" % [file, monster_id, i])
