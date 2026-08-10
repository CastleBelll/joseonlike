class_name WeaponEvolution
extends Node
## Weapon evolution: when a weapon levels or a passive stacks, look for a
## (weapon_id, passive_id) pair that GameData maps to an evolved weapon, swap the
## weapon in place and announce it on EventBus.
##
## The matching rules are static and dependency-injected (`resolver`), so tests
## can exercise them with a synthetic lookup. Autoloads are reached through
## `/root/...` node lookups rather than the global identifiers, because the
## headless test runner loads this file before autoloads exist and the global
## identifiers would fail to compile there.

signal evolved(from_id: String, to_id: String)

const KEY_FROM_ID: String = "from_id"
const KEY_TO_ID: String = "to_id"
const KEY_PASSIVE_ID: String = "passive_id"
const KEY_MIN_WEAPON_LEVEL: String = "min_weapon_level"
const KEY_MIN_PASSIVE_STACKS: String = "min_passive_stacks"

## evolutions.json carries min_weapon_level / min_passive_stacks, but the frozen
## GameData.evolution_for(weapon_id, passive_id) signature cannot return them.
## Callers may pass a `requirements` dictionary keyed by evolved weapon id to
## apply those gates; with none supplied the pair match alone is authoritative.
const DEFAULT_MIN_WEAPON_LEVEL: int = 1
const DEFAULT_MIN_PASSIVE_STACKS: int = 1

var _game_data: Object = null
var _event_bus: Object = null


func _ready() -> void:
	_game_data = get_node_or_null(^"/root/GameData")
	_event_bus = get_node_or_null(^"/root/EventBus")
	if _game_data == null:
		push_warning("WeaponEvolution: GameData autoload missing, evolutions disabled")


## First matching evolution for the owned passives, or {} when none applies.
## `resolver` has the shape func(weapon_id: String, passive_id: String) -> String.
static func find_match(
	weapon_id: String,
	weapon_level: int,
	passives: Dictionary,
	resolver: Callable,
	requirements: Dictionary = {}
) -> Dictionary:
	if weapon_id.is_empty() or not resolver.is_valid():
		return {}
	for passive_key in passives.keys():
		var passive_id: String = String(passive_key)
		var evolved_id: String = String(resolver.call(weapon_id, passive_id))
		if evolved_id.is_empty() or evolved_id == weapon_id:
			continue
		if not _meets_requirements(evolved_id, weapon_level, int(passives[passive_key]), requirements):
			continue
		return {
			KEY_FROM_ID: weapon_id,
			KEY_TO_ID: evolved_id,
			KEY_PASSIVE_ID: passive_id,
		}
	return {}


## Evaluates the live GameData/RunState pair and emits on a match.
## Returns the evolved weapon id, or "" when nothing evolved.
func evaluate(weapon_id: String, weapon_level: int, passives: Dictionary, requirements: Dictionary = {}) -> String:
	if _game_data == null:
		return ""
	var match_result: Dictionary = find_match(
		weapon_id, weapon_level, passives, Callable(_game_data, "evolution_for"), requirements
	)
	if match_result.is_empty():
		return ""
	var to_id: String = String(match_result[KEY_TO_ID])
	announce(weapon_id, to_id)
	return to_id


## Emits the swap on both the local signal (weapon holder listens) and EventBus
## (UI and achievements listen).
func announce(from_id: String, to_id: String) -> void:
	evolved.emit(from_id, to_id)
	if _event_bus != null:
		_event_bus.weapon_evolved.emit(from_id, to_id)


static func _meets_requirements(
	evolved_id: String,
	weapon_level: int,
	passive_stacks: int,
	requirements: Dictionary
) -> bool:
	var rule: Dictionary = requirements.get(evolved_id, {})
	var min_level: int = int(rule.get(KEY_MIN_WEAPON_LEVEL, DEFAULT_MIN_WEAPON_LEVEL))
	var min_stacks: int = int(rule.get(KEY_MIN_PASSIVE_STACKS, DEFAULT_MIN_PASSIVE_STACKS))
	return weapon_level >= min_level and passive_stacks >= min_stacks
