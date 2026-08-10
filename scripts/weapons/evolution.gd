class_name WeaponEvolution
extends Node
## Weapon evolution: when a weapon levels or a passive stacks, ask GameData for
## a (weapon_id, passive_id) pair that resolves to an evolved weapon, and
## announce the swap on EventBus.
##
## GameData.evolution_for() already checks evolutions.json min_weapon_level and
## min_passive_stacks against the live RunState, so a non-empty return is the
## authoritative go-ahead and this file adds no second threshold check.
##
## Autoloads are reached through /root lookups rather than the global
## identifiers, because the headless test runner loads this file before
## autoloads exist and the global identifiers would fail to compile there.

signal evolved(from_id: String, to_id: String)

const KEY_FROM_ID: String = "from_id"
const KEY_TO_ID: String = "to_id"
const KEY_PASSIVE_ID: String = "passive_id"

var _game_data: Object = null
var _event_bus: Object = null


func _ready() -> void:
	_game_data = get_node_or_null(^"/root/GameData")
	_event_bus = get_node_or_null(^"/root/EventBus")
	if _game_data == null:
		push_warning("WeaponEvolution: GameData autoload missing, evolutions disabled")


## First owned passive that evolves `weapon_id`, or {} when none does.
## `resolver` has the shape func(weapon_id: String, passive_id: String) -> String
## and is injected so tests can run without GameData; production passes
## GameData.evolution_for, which owns every threshold rule.
static func find_match(weapon_id: String, passives: Dictionary, resolver: Callable) -> Dictionary:
	if weapon_id.is_empty() or not resolver.is_valid():
		return {}
	for passive_key: Variant in passives.keys():
		var passive_id: String = String(passive_key)
		var evolved_id: String = String(resolver.call(weapon_id, passive_id))
		if evolved_id.is_empty() or evolved_id == weapon_id:
			continue
		return {
			KEY_FROM_ID: weapon_id,
			KEY_TO_ID: evolved_id,
			KEY_PASSIVE_ID: passive_id,
		}
	return {}


## Evaluates the live rules and announces a match.
## Returns the evolved weapon id, or "" when nothing evolved.
func evaluate(weapon_id: String, passives: Dictionary) -> String:
	if _game_data == null:
		return ""
	var match_result: Dictionary = find_match(weapon_id, passives, Callable(_game_data, "evolution_for"))
	if match_result.is_empty():
		return ""
	var to_id: String = String(match_result[KEY_TO_ID])
	announce(weapon_id, to_id)
	return to_id


## Emits the swap on both the local signal (the weapon holder listens) and
## EventBus (HUD and achievements listen).
func announce(from_id: String, to_id: String) -> void:
	evolved.emit(from_id, to_id)
	if _event_bus != null:
		_event_bus.weapon_evolved.emit(from_id, to_id)
