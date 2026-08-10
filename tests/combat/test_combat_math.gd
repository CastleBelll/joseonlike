extends RefCounted
## Damage, crit and passive scaling. These formulas decide every hit in the game,
## so they are tested directly rather than through a live weapon node.

const CombatMathScript = preload("res://scripts/combat/combat_math.gd")
const Fixtures = preload("res://tests/combat/fixtures/combat_fixtures.gd")

const EPSILON: float = 0.0001


func run() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(_test_per_level_scaling())
	failures.append_array(_test_attack_damage_passive())
	failures.append_array(_test_skill_power_only_boosts_spiritual())
	failures.append_array(_test_crit())
	failures.append_array(_test_integer_stats())
	failures.append_array(_test_nearest_index())
	return failures


func _test_per_level_scaling() -> Array[String]:
	var weapon: Dictionary = Fixtures.spiritual_weapon()
	var failures: Array[String] = []
	# 10 base, +3 per level, level 3 applies the delta twice.
	failures.append_array(_expect_float("level 1 damage", CombatMathScript.base_damage(weapon, 1, 0.0, 0.0), 10.0))
	failures.append_array(_expect_float("level 3 damage", CombatMathScript.base_damage(weapon, 3, 0.0, 0.0), 16.0))
	# Level 0 must not subtract a delta.
	failures.append_array(_expect_float("level 0 clamps to 1", CombatMathScript.base_damage(weapon, 0, 0.0, 0.0), 10.0))
	return failures


func _test_attack_damage_passive() -> Array[String]:
	var weapon: Dictionary = Fixtures.spiritual_weapon()
	# 16 at level 3, +50% attack_damage.
	return _expect_float("attack_damage +50%", CombatMathScript.base_damage(weapon, 3, 0.5, 0.0), 24.0)


func _test_skill_power_only_boosts_spiritual() -> Array[String]:
	var failures: Array[String] = []
	var spiritual: Dictionary = Fixtures.spiritual_weapon()
	var melee: Dictionary = Fixtures.melee_weapon()
	# Spiritual: 16 * (1 + 0.5 + 0.25).
	failures.append_array(_expect_float(
		"skill_power boosts spiritual", CombatMathScript.base_damage(spiritual, 3, 0.5, 0.25), 28.0
	))
	# Melee: 20 * (1 + 0.5), skill_power ignored.
	failures.append_array(_expect_float(
		"skill_power ignored by melee", CombatMathScript.base_damage(melee, 3, 0.5, 0.25), 30.0
	))
	return failures


func _test_crit() -> Array[String]:
	var weapon: Dictionary = Fixtures.spiritual_weapon()
	var failures: Array[String] = []

	var crit_hit: Dictionary = CombatMathScript.resolve_hit(weapon, 1, 0.0, 0.0, 0.2, 0.05)
	if not bool(crit_hit["is_crit"]):
		failures.append("roll 0.05 under 0.2 crit_chance should crit")
	# Pinned literal, not CRIT_MULTIPLIER: an assertion written in terms of the
	# constant it is checking can never fail when that constant changes.
	failures.append_array(_expect_float("crit damage", float(crit_hit["amount"]), 20.0))

	var normal_hit: Dictionary = CombatMathScript.resolve_hit(weapon, 1, 0.0, 0.0, 0.2, 0.25)
	if bool(normal_hit["is_crit"]):
		failures.append("roll 0.25 above 0.2 crit_chance should not crit")
	failures.append_array(_expect_float("non-crit damage", float(normal_hit["amount"]), 10.0))

	# A roll exactly at the threshold must not crit, or 0% chance would still crit.
	if CombatMathScript.is_crit(0.0, 0.0):
		failures.append("0% crit_chance must never crit")
	return failures


func _test_integer_stats() -> Array[String]:
	var weapon: Dictionary = Fixtures.spiritual_weapon()
	var failures: Array[String] = []
	# projectile_count 1 with +0.5 per level: level 2 floors back to 1, level 3 reaches 2.
	if CombatMathScript.projectile_count_at_level(weapon, 2) != 1:
		failures.append("projectile_count at level 2 should floor to 1")
	if CombatMathScript.projectile_count_at_level(weapon, 3) != 2:
		failures.append("projectile_count at level 3 should be 2")
	if CombatMathScript.projectile_count_at_level(Fixtures.melee_weapon(), 5) != 1:
		failures.append("missing projectile_count should default to 1")
	return failures


func _test_nearest_index() -> Array[String]:
	var failures: Array[String] = []
	var positions := PackedVector2Array([Vector2(100, 0), Vector2(10, 0), Vector2(-40, 0)])
	if CombatMathScript.nearest_index(Vector2.ZERO, positions) != 1:
		failures.append("nearest_index should pick the closest position")
	if CombatMathScript.nearest_index(Vector2.ZERO, PackedVector2Array()) != -1:
		failures.append("nearest_index on an empty list should return -1")
	return failures


func _expect_float(label: String, actual: float, expected: float) -> Array[String]:
	if absf(actual - expected) <= EPSILON:
		return []
	return ["%s: expected %f, got %f" % [label, expected, actual]]
