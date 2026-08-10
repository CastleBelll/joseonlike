extends RefCounted
## Evolution trigger conditions.
##
## find_match is static and takes an injected resolver with the same signature
## as GameData.evolution_for, so this runs without content data or autoloads.
## The level and stack thresholds in evolutions.json are GameData's job, not
## this file's: the resolver returning a non-empty id IS the go-ahead, and the
## fixture resolver below models that by gating inside the lookup.

const EvolutionScript = preload("res://scripts/weapons/evolution.gd")
const Fixtures = preload("res://tests/combat/fixtures/combat_fixtures.gd")

const TALISMAN: String = "test_talisman"
const EVOLVED_TALISMAN: String = "test_phoenix_talisman"


func run() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(_test_pair_match())
	failures.append_array(_test_no_match())
	failures.append_array(_test_resolver_owns_thresholds())
	failures.append_array(_test_guards())
	return failures


func _test_pair_match() -> Array[String]:
	var resolver: Callable = Fixtures.evolution_resolver(Fixtures.evolution_table())
	var result: Dictionary = EvolutionScript.find_match(TALISMAN, {"skill_power": 3}, resolver)
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
	if not EvolutionScript.find_match(TALISMAN, {"attack_damage": 5}, resolver).is_empty():
		failures.append("an unrelated passive must not evolve the weapon")
	if not EvolutionScript.find_match(TALISMAN, {}, resolver).is_empty():
		failures.append("owning no passives must not evolve the weapon")
	if not EvolutionScript.find_match("unknown_weapon", {"skill_power": 5}, resolver).is_empty():
		failures.append("an unknown weapon must not evolve")
	return failures


## GameData.evolution_for returns "" until min_weapon_level / min_passive_stacks
## are met. find_match must forward that verdict untouched rather than second
## guessing it, which is what the removed `requirements` parameter used to do.
func _test_resolver_owns_thresholds() -> Array[String]:
	var failures: Array[String] = []
	var blocked: Callable = func(_weapon_id: String, _passive_id: String) -> String:
		return ""
	if not EvolutionScript.find_match(TALISMAN, {"skill_power": 99}, blocked).is_empty():
		failures.append("a resolver that withholds the evolution must be obeyed")

	var allowed: Callable = func(_weapon_id: String, _passive_id: String) -> String:
		return EVOLVED_TALISMAN
	# One stack, weapon level not even supplied: the resolver said yes, so it is yes.
	if EvolutionScript.find_match(TALISMAN, {"skill_power": 1}, allowed).is_empty():
		failures.append("a resolver that grants the evolution must be obeyed")
	return failures


func _test_guards() -> Array[String]:
	var resolver: Callable = Fixtures.evolution_resolver(Fixtures.evolution_table())
	var failures: Array[String] = []
	if not EvolutionScript.find_match("", {"skill_power": 3}, resolver).is_empty():
		failures.append("an empty weapon id must not evolve")
	if not EvolutionScript.find_match(TALISMAN, {"skill_power": 3}, Callable()).is_empty():
		failures.append("an invalid resolver must not evolve")
	# A resolver that echoes the weapon id back would otherwise loop forever.
	var echo_resolver: Callable = func(weapon_id: String, _passive_id: String) -> String:
		return weapon_id
	if not EvolutionScript.find_match(TALISMAN, {"skill_power": 3}, echo_resolver).is_empty():
		failures.append("evolving into itself must be rejected")
	return failures
