extends RefCounted
## Evolution trigger conditions.
##
## find_match is static and takes an injected resolver with the same signature as
## GameData.evolution_for, so this runs without content data or autoloads.

const EvolutionScript = preload("res://scripts/weapons/evolution.gd")
const Fixtures = preload("res://tests/combat/fixtures/combat_fixtures.gd")

const TALISMAN: String = "test_talisman"
const EVOLVED_TALISMAN: String = "test_phoenix_talisman"


func run() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(_test_pair_match())
	failures.append_array(_test_no_match())
	failures.append_array(_test_weapon_level_requirement())
	failures.append_array(_test_passive_stack_requirement())
	failures.append_array(_test_guards())
	return failures


func _test_pair_match() -> Array[String]:
	var resolver: Callable = Fixtures.evolution_resolver(Fixtures.evolution_table())
	var result: Dictionary = EvolutionScript.find_match(TALISMAN, 5, {"skill_power": 3}, resolver)
	if result.is_empty():
		return ["owning the paired passive should evolve the weapon"]
	var failures: Array[String] = []
	if String(result[EvolutionScript.KEY_TO_ID]) != EVOLVED_TALISMAN:
		failures.append("expected %s, got %s" % [EVOLVED_TALISMAN, result[EvolutionScript.KEY_TO_ID]])
	if String(result[EvolutionScript.KEY_FROM_ID]) != TALISMAN:
		failures.append("match should report the weapon it replaces")
	if String(result[EvolutionScript.KEY_PASSIVE_ID]) != "skill_power":
		failures.append("match should report the passive that triggered it")
	return failures


func _test_no_match() -> Array[String]:
	var resolver: Callable = Fixtures.evolution_resolver(Fixtures.evolution_table())
	var failures: Array[String] = []
	if not EvolutionScript.find_match(TALISMAN, 8, {"attack_damage": 5}, resolver).is_empty():
		failures.append("an unrelated passive must not evolve the weapon")
	if not EvolutionScript.find_match(TALISMAN, 8, {}, resolver).is_empty():
		failures.append("owning no passives must not evolve the weapon")
	if not EvolutionScript.find_match("unknown_weapon", 8, {"skill_power": 5}, resolver).is_empty():
		failures.append("an unknown weapon must not evolve")
	return failures


func _test_weapon_level_requirement() -> Array[String]:
	var resolver: Callable = Fixtures.evolution_resolver(Fixtures.evolution_table())
	var requirements: Dictionary = {EVOLVED_TALISMAN: {"min_weapon_level": 5}}
	var failures: Array[String] = []
	if not EvolutionScript.find_match(TALISMAN, 4, {"skill_power": 9}, resolver, requirements).is_empty():
		failures.append("weapon below min_weapon_level must not evolve")
	if EvolutionScript.find_match(TALISMAN, 5, {"skill_power": 9}, resolver, requirements).is_empty():
		failures.append("weapon at min_weapon_level should evolve")
	return failures


func _test_passive_stack_requirement() -> Array[String]:
	var resolver: Callable = Fixtures.evolution_resolver(Fixtures.evolution_table())
	var requirements: Dictionary = {EVOLVED_TALISMAN: {"min_passive_stacks": 3}}
	var failures: Array[String] = []
	if not EvolutionScript.find_match(TALISMAN, 8, {"skill_power": 2}, resolver, requirements).is_empty():
		failures.append("passive below min_passive_stacks must not evolve")
	if EvolutionScript.find_match(TALISMAN, 8, {"skill_power": 3}, resolver, requirements).is_empty():
		failures.append("passive at min_passive_stacks should evolve")
	return failures


func _test_guards() -> Array[String]:
	var resolver: Callable = Fixtures.evolution_resolver(Fixtures.evolution_table())
	var failures: Array[String] = []
	if not EvolutionScript.find_match("", 5, {"skill_power": 3}, resolver).is_empty():
		failures.append("an empty weapon id must not evolve")
	if not EvolutionScript.find_match(TALISMAN, 5, {"skill_power": 3}, Callable()).is_empty():
		failures.append("an invalid resolver must not evolve")
	# A resolver that echoes the weapon id back would otherwise loop forever.
	var echo_resolver: Callable = func(weapon_id: String, _passive_id: String) -> String:
		return weapon_id
	if not EvolutionScript.find_match(TALISMAN, 5, {"skill_power": 3}, echo_resolver).is_empty():
		failures.append("evolving into itself must be rejected")
	return failures
