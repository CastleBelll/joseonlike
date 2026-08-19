extends RefCounted
## Guards the N10-1a 그슨대 contract: darkness makes it untouchable and it
## grows there, light makes it hittable and pushes it back, and the real data
## actually ships a light for it to be pushed back by.

const EPSILON := 0.001


func _lights() -> Array[Dictionary]:
	return [
		{"position": Vector2(100.0, 0.0), "radius": 50.0},
		{"position": Vector2(-200.0, 80.0), "radius": 30.0},
	]


func test_a_point_is_lit_only_inside_a_radius() -> bool:
	var lights: Array[Dictionary] = _lights()
	# Dead centre, and the second light proves the search does not stop at [0].
	if not CombatMath.is_lit(Vector2(100.0, 0.0), lights):
		return false
	if not CombatMath.is_lit(Vector2(-200.0, 80.0), lights):
		return false
	# Boundary is inclusive: standing exactly on the edge counts as lit, so a
	# shadow cannot hover on the rim being untouchable.
	if not CombatMath.is_lit(Vector2(150.0, 0.0), lights):
		return false
	# One pixel out is dark.
	if CombatMath.is_lit(Vector2(151.0, 0.0), lights):
		return false
	# Far away is dark.
	return not CombatMath.is_lit(Vector2(9000.0, 9000.0), lights)


func test_no_lights_means_total_darkness() -> bool:
	var none: Array[Dictionary] = []
	return not CombatMath.is_lit(Vector2.ZERO, none)


func test_a_zero_radius_light_lights_nothing() -> bool:
	var broken: Array[Dictionary] = [{"position": Vector2.ZERO, "radius": 0.0}]
	return not CombatMath.is_lit(Vector2(1.0, 0.0), broken)


func test_the_shadow_grows_in_the_dark_and_stops_at_max() -> bool:
	var config: Dictionary = {
		"grow_per_sec": 1.0, "lit_shrink_per_sec": 2.0, "max_scale": 2.0,
	}
	var grown: float = CombatMath.shadow_scale(1.0, 0.5, false, config)
	if absf(grown - 1.5) > EPSILON:
		return false
	# A long dark chase cannot swell it past the data ceiling.
	var capped: float = CombatMath.shadow_scale(1.9, 10.0, false, config)
	return absf(capped - 2.0) < EPSILON


func test_the_shadow_shrinks_in_the_light_but_never_below_its_base() -> bool:
	var config: Dictionary = {
		"grow_per_sec": 1.0, "lit_shrink_per_sec": 2.0, "max_scale": 3.0,
	}
	var shrunk: float = CombatMath.shadow_scale(2.0, 0.25, true, config)
	if absf(shrunk - 1.5) > EPSILON:
		return false
	# Standing in a lantern forever leaves it at size 1, not inverted.
	var floored: float = CombatMath.shadow_scale(1.2, 100.0, true, config)
	return absf(floored - 1.0) < EPSILON


func test_contact_damage_rises_with_the_grown_size() -> bool:
	var config: Dictionary = {"damage_per_scale": 5.0}
	# Ungrown, it hits for exactly its base.
	if absf(CombatMath.shadow_damage(7.0, 1.0, config) - 7.0) > EPSILON:
		return false
	# Doubled in size, it hits for base + one full step.
	if absf(CombatMath.shadow_damage(7.0, 2.0, config) - 12.0) > EPSILON:
		return false
	# An ordinary monster passes an empty config and must be unaffected.
	var plain: Dictionary = {}
	return absf(CombatMath.shadow_damage(7.0, 1.0, plain) - 7.0) < EPSILON


func test_the_leash_holds_the_shadow_to_its_haunt() -> bool:
	var anchor := Vector2(500.0, 500.0)
	# Inside, and exactly on the edge, the player is still being hunted.
	if not CombatMath.within_leash(anchor, Vector2(700.0, 500.0), 400.0):
		return false
	if not CombatMath.within_leash(anchor, Vector2(900.0, 500.0), 400.0):
		return false
	# One pixel beyond and it gives up.
	return not CombatMath.within_leash(anchor, Vector2(901.0, 500.0), 400.0)


func test_an_unset_leash_means_no_leash_rather_than_a_frozen_monster() -> bool:
	# A shadow shipped without leash_px must keep chasing, not stand still
	# forever — a silent freeze is far harder to notice than a chase.
	return CombatMath.within_leash(Vector2.ZERO, Vector2(99999.0, 0.0), 0.0)


func test_the_shipped_shadow_can_actually_be_reached_by_a_shipped_light() -> bool:
	var monsters: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/monsters.json")
	)
	var props: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/props.json")
	)
	var has_shadow: bool = false
	for monster_id: String in monsters:
		if (monsters[monster_id] as Dictionary).has("shadow"):
			has_shadow = true
			break
	if not has_shadow:
		return true  # nothing to guard
	var catalog: Dictionary = props.get("props", {})
	for prop_id: String in catalog:
		if float((catalog[prop_id] as Dictionary).get("light_radius_px", 0.0)) > 0.0:
			return true
	return false
