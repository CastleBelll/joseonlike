extends Node
## Read-only access to the JSON content under res://data.
##
## Frozen contract: ARCHITECTURE.md section 3.2. Every accessor returns a deep
## copy, so a caller that mutates a result cannot corrupt the shared cache that
## the rest of the game reads from.

const DATA_DIR := "res://data"
const FILE_EXTENSION := ".json"

## Collections the game cannot run without. A missing or malformed file here is
## fatal for load_all(); silently continuing with empty content would surface
## much later as unexplained empty menus and zero-damage weapons.
const REQUIRED_COLLECTIONS: Array[String] = [
	"characters",
	"weapons",
	"monsters",
	"stages",
	"passives",
	"evolutions",
	"achievements",
	"loot",
	"drop_tables",
	"weapon_mods",
]

const COLLECTION_CHARACTERS := "characters"
const COLLECTION_WEAPONS := "weapons"
const COLLECTION_MONSTERS := "monsters"
const COLLECTION_STAGES := "stages"
const COLLECTION_PASSIVES := "passives"
const COLLECTION_EVOLUTIONS := "evolutions"
const COLLECTION_ACHIEVEMENTS := "achievements"
const COLLECTION_LOOT := "loot"
const COLLECTION_DROP_TABLES := "drop_tables"
const COLLECTION_WEAPON_MODS := "weapon_mods"

## Mod rule fields (data/weapon_mods.json, GDD v2 section 33).
const MOD_WEAPON := "weapon_id"
const MOD_LOOT := "loot_id"
const MOD_RESULT := "result_weapon"

## JSON objects are keyed by id, so entries carry no id field of their own.
## The list accessors inject it because UI code iterates without the key.
const ID_KEY := "id"

## Evolution rule fields (data/evolutions.json, ARCHITECTURE.md section 4).
const RULE_REQUIRES_WEAPON := "requires_weapon"
const RULE_REQUIRES_PASSIVE := "requires_passive"
const RULE_MIN_WEAPON_LEVEL := "min_weapon_level"
const RULE_MIN_PASSIVE_STACKS := "min_passive_stacks"
const RULE_RESULT_WEAPON := "result_weapon"

## Source of the live weapon levels and passive stacks that evolution rules are
## checked against. Defaults to the RunState autoload; tests inject a throwaway
## instance so they never mutate global run state.
var run_state: Node = null

var _collections: Dictionary = {}
var _loaded: bool = false


func load_all() -> Error:
	return load_from_dir(DATA_DIR)


## Parses every required collection out of `dir_path`. Exposed separately from
## load_all() so tests can run against small fixtures instead of shipped content.
func load_from_dir(dir_path: String) -> Error:
	var parsed: Dictionary = {}

	for collection_name: String in REQUIRED_COLLECTIONS:
		var path: String = "%s/%s%s" % [dir_path, collection_name, FILE_EXTENSION]
		var collection: Variant = _parse_object_file(path)
		if collection == null:
			return ERR_PARSE_ERROR
		parsed[collection_name] = collection

	# Swap in only after every file parsed cleanly, so a bad file can never leave
	# a half-loaded cache behind.
	_collections = parsed
	_loaded = true
	return OK


func character(id: String) -> Dictionary:
	return _lookup(COLLECTION_CHARACTERS, id)


func weapon(id: String) -> Dictionary:
	return _lookup(COLLECTION_WEAPONS, id)


func monster(id: String) -> Dictionary:
	return _lookup(COLLECTION_MONSTERS, id)


func stage(id: String) -> Dictionary:
	return _lookup(COLLECTION_STAGES, id)


func passive(id: String) -> Dictionary:
	return _lookup(COLLECTION_PASSIVES, id)


func loot(id: String) -> Dictionary:
	return _lookup(COLLECTION_LOOT, id)


## The weapon a (weapon, loot material) pair mods into, or "" when no recipe
## matches. Unlike evolution_for this checks no run thresholds: holding the
## material is the whole requirement, and RunState owns that check.
func mod_for(weapon_id: String, loot_id: String) -> String:
	if not _loaded:
		push_error("GameData.mod_for called before load_all()")
		return ""

	var mods: Dictionary = _collections.get(COLLECTION_WEAPON_MODS, {})
	for rule_id: String in mods.keys():
		var entry: Variant = mods[rule_id]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var rule: Dictionary = entry
		if String(rule.get(MOD_WEAPON, "")) != weapon_id:
			continue
		if String(rule.get(MOD_LOOT, "")) != loot_id:
			continue
		return String(rule.get(MOD_RESULT, ""))

	return ""


## Drop table for a monster, or {} for monsters that drop nothing. Unlike the
## other keyed accessors this does not push_error on a missing id: most
## monsters legitimately have no table, and death handling asks for every kill.
func drop_table(monster_id: String) -> Dictionary:
	if not _loaded:
		push_error("GameData.drop_table(\"%s\") called before load_all()" % monster_id)
		return {}

	var tables: Dictionary = _collections.get(COLLECTION_DROP_TABLES, {})
	if not tables.has(monster_id):
		return {}

	var entry: Variant = tables[monster_id]
	if typeof(entry) != TYPE_DICTIONARY:
		push_error("GameData: drop_tables entry \"%s\" is not a JSON object" % monster_id)
		return {}

	return (entry as Dictionary).duplicate(true)


## Returns the evolved weapon id for a weapon+passive pair, or "" when no rule
## matches or the run has not yet met the rule's level and stack thresholds.
func evolution_for(weapon_id: String, passive_id: String) -> String:
	if not _loaded:
		push_error("GameData.evolution_for called before load_all()")
		return ""

	var run: Node = _run()
	if run == null:
		push_error("GameData.evolution_for has no run state to check thresholds against")
		return ""

	var evolutions: Dictionary = _collections.get(COLLECTION_EVOLUTIONS, {})
	for rule_id: String in evolutions.keys():
		var entry: Variant = evolutions[rule_id]
		if typeof(entry) != TYPE_DICTIONARY:
			continue

		var rule: Dictionary = entry
		if String(rule.get(RULE_REQUIRES_WEAPON, "")) != weapon_id:
			continue
		if String(rule.get(RULE_REQUIRES_PASSIVE, "")) != passive_id:
			continue
		if run.weapon_level(weapon_id) < int(rule.get(RULE_MIN_WEAPON_LEVEL, 0)):
			continue
		if run.passive_stacks(passive_id) < int(rule.get(RULE_MIN_PASSIVE_STACKS, 0)):
			continue

		return String(rule.get(RULE_RESULT_WEAPON, rule_id))

	return ""


func all_characters() -> Array[Dictionary]:
	return _all(COLLECTION_CHARACTERS)


func all_achievements() -> Array[Dictionary]:
	return _all(COLLECTION_ACHIEVEMENTS)


## Additive to the frozen contract: RunState needs the full pool to build
## level-up choices, and the keyed accessors cannot enumerate.
func all_weapons() -> Array[Dictionary]:
	return _all(COLLECTION_WEAPONS)


func all_passives() -> Array[Dictionary]:
	return _all(COLLECTION_PASSIVES)


## Every evolution rule, id injected. evolution_for() only answers "is this pair
## satisfied right now"; a caller that must reason about a rule the run has not
## met yet -- such as weighting the passive still gating it -- needs the rules
## themselves.
func all_evolutions() -> Array[Dictionary]:
	return _all(COLLECTION_EVOLUTIONS)


func _lookup(collection_name: String, id: String) -> Dictionary:
	if not _loaded:
		push_error("GameData.%s(\"%s\") called before load_all()" % [collection_name, id])
		return {}

	var collection: Dictionary = _collections.get(collection_name, {})
	if not collection.has(id):
		push_error("GameData: unknown %s id \"%s\"" % [collection_name, id])
		return {}

	var entry: Variant = collection[id]
	if typeof(entry) != TYPE_DICTIONARY:
		push_error("GameData: %s entry \"%s\" is not a JSON object" % [collection_name, id])
		return {}

	return (entry as Dictionary).duplicate(true)


func _all(collection_name: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not _loaded:
		push_error("GameData.all_%s() called before load_all()" % collection_name)
		return entries

	var collection: Dictionary = _collections.get(collection_name, {})
	for id: String in collection.keys():
		var entry: Variant = collection[id]
		if typeof(entry) != TYPE_DICTIONARY:
			push_error("GameData: %s entry \"%s\" is not a JSON object" % [collection_name, id])
			continue

		var copy: Dictionary = (entry as Dictionary).duplicate(true)
		copy[ID_KEY] = id
		entries.append(copy)

	return entries


## Returns the parsed object, or null after reporting exactly which file failed.
func _parse_object_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("GameData: missing data file %s" % path)
		return null

	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("GameData: %s is empty or unreadable (error %d)" % [path, FileAccess.get_open_error()])
		return null

	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("GameData: %s is not valid JSON at line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null

	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("GameData: %s must be a JSON object keyed by id" % path)
		return null

	return json.data


func _run() -> Node:
	return run_state if run_state != null else RunState
