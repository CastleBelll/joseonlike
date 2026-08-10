extends RefCounted
## Cooldown scaling with the attack_speed passive. Firing rate is the single
## biggest lever in an auto-combat game, so its clamps matter as much as its math.

const CombatMathScript = preload("res://scripts/combat/combat_math.gd")
const Fixtures = preload("res://tests/combat/fixtures/combat_fixtures.gd")

const EPSILON: float = 0.0001


func run() -> Array[String]:
	var failures: Array[String] = []
	var weapon: Dictionary = Fixtures.spiritual_weapon()

	# 1.0s base, -0.1s per level.
	failures.append_array(_expect("level 1, no passive", CombatMathScript.cooldown_at_level(weapon, 1, 0.0), 1.0))
	failures.append_array(_expect("level 3, no passive", CombatMathScript.cooldown_at_level(weapon, 3, 0.0), 0.8))

	# attack_speed is a rate bonus: +60% turns 0.8s into 0.8 / 1.6.
	failures.append_array(_expect("level 3, +60% attack_speed", CombatMathScript.cooldown_at_level(weapon, 3, 0.6), 0.5))
	failures.append_array(_expect("level 1, +100% attack_speed", CombatMathScript.cooldown_at_level(weapon, 1, 1.0), 0.5))

	# A negative attack_speed must slow the weapon, never invert or divide by zero.
	var slowed: float = CombatMathScript.cooldown_at_level(weapon, 1, -0.5)
	if slowed <= 1.0:
		failures.append("negative attack_speed should lengthen the cooldown, got %f" % slowed)
	failures.append_array(_expect("attack_speed -1.0 is clamped", CombatMathScript.cooldown_at_level(weapon, 1, -1.0), 10.0))

	# An absurd stack must still leave a measurable gap between shots.
	failures.append_array(_expect(
		"extreme attack_speed hits the floor",
		CombatMathScript.cooldown_at_level(weapon, 1, 100.0),
		CombatMathScript.MIN_COOLDOWN_SEC
	))

	# A weapon without cooldown_sec must not fire every frame.
	var no_cooldown: Dictionary = {"damage": 5.0}
	failures.append_array(_expect(
		"missing cooldown_sec falls back",
		CombatMathScript.cooldown_at_level(no_cooldown, 1, 0.0),
		CombatMathScript.DEFAULT_COOLDOWN_SEC
	))
	return failures


func _expect(label: String, actual: float, expected: float) -> Array[String]:
	if absf(actual - expected) <= EPSILON:
		return []
	return ["%s: expected %f, got %f" % [label, expected, actual]]
