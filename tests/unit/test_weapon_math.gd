extends RefCounted
## Guards the N4-4a taoist mechanic math (WeaponMath) and the level-up card
## contract for the new archetypes (LevelUp.runtime_can_fire, mechanic_text).

const EPSILON := 0.001

# Fixture matching data/weapons.json shapes (synthetic numbers).
const EXPLOSION_WEAPON := {
	"mechanic": "explosion", "speed": 240.0,
	"explosion": {"radius_px": 90.0},
}
const CHAIN_WEAPON := {
	"mechanic": "chain", "speed": 300.0,
	"chain": {"jumps": 3, "falloff": 0.7, "range_px": 150.0},
}
const ARC_WEAPON := {
	"mechanic": "melee_arc", "speed": 0.0,
	"arc": {"angle_deg": 160.0, "knockback_scale": 2.5},
}
const ORBIT_WEAPON := {
	"mechanic": "orbit", "speed": 0.0, "projectile_count": 2,
	"orbit": {"radius_px": 70.0, "speed_deg_s": 150.0},
	"on_hit_status": {"id": "burn", "dps": 3.0, "duration_sec": 2.0},
}
const PIERCE_WEAPON := {
	"mechanic": "pierce", "speed": 340.0, "pierce": 99,
}


func test_explosion_selects_only_targets_inside_radius() -> bool:
	var positions: Array[Vector2] = [
		Vector2(10.0, 0.0),   # inside
		Vector2(0.0, 89.9),   # inside near the edge
		Vector2(90.0, 0.0),   # exactly on the boundary — inclusive
		Vector2(0.0, 91.0),   # outside
		Vector2(200.0, 200.0)  # far outside
	]
	var hits: Array[int] = WeaponMath.targets_in_radius(Vector2.ZERO, positions, 90.0)
	return hits == [0, 1, 2]


func test_explosion_empty_crowd_hits_nothing() -> bool:
	var positions: Array[Vector2] = []
	return WeaponMath.targets_in_radius(Vector2.ZERO, positions, 90.0).is_empty()


func test_chain_sequence_never_repeats_and_prefers_nearest() -> bool:
	var positions: Array[Vector2] = [
		Vector2(10.0, 0.0), Vector2(30.0, 0.0), Vector2(60.0, 0.0)
	]
	var struck: Array[int] = []
	var from := Vector2.ZERO
	for _jump: int in range(3):
		var index: int = WeaponMath.chain_next_index(from, positions, struck, 100.0)
		if index < 0:
			return false
		if struck.has(index):
			return false  # a chain must never bounce back to a struck enemy
		struck.append(index)
		from = positions[index]
	# Nearest-first from each new position: 0 -> 1 -> 2.
	return struck == [0, 1, 2]


func test_chain_dies_outside_range() -> bool:
	var positions: Array[Vector2] = [Vector2(200.0, 0.0)]
	var exclude: Array[int] = []
	return WeaponMath.chain_next_index(Vector2.ZERO, positions, exclude, 150.0) == -1


func test_chain_falloff_compounds_per_jump() -> bool:
	var falloff: float = float((CHAIN_WEAPON["chain"] as Dictionary)["falloff"])
	return (
		absf(WeaponMath.chain_damage(10.0, falloff, 0) - 10.0) < EPSILON
		and absf(WeaponMath.chain_damage(10.0, falloff, 1) - 7.0) < EPSILON
		and absf(WeaponMath.chain_damage(10.0, falloff, 2) - 4.9) < EPSILON
	)


func test_arc_hits_by_angle_and_radius() -> bool:
	var positions: Array[Vector2] = [
		Vector2(50.0, 0.0),    # dead ahead — hit
		Vector2(0.0, 50.0),    # 90° off an aim of 0 with a 160° arc — miss
		Vector2(-50.0, 0.0),   # behind — miss
		Vector2(40.0, 20.0),   # ~27° off — hit
		Vector2(120.0, 0.0)    # ahead but out of reach (110 + 8) — miss
	]
	var radii: Array[float] = [8.0, 8.0, 8.0, 8.0, 8.0]
	var hits: Array[int] = WeaponMath.arc_hits(
		Vector2.ZERO, 0.0, deg_to_rad(160.0), 110.0, positions, radii
	)
	return hits == [0, 3]


func test_arc_reach_includes_the_enemy_body_radius() -> bool:
	var positions: Array[Vector2] = [Vector2(117.0, 0.0)]
	var radii: Array[float] = [8.0]
	var hits: Array[int] = WeaponMath.arc_hits(
		Vector2.ZERO, 0.0, deg_to_rad(160.0), 110.0, positions, radii
	)
	return hits == [0]  # 117 <= 110 + 8


func test_orbit_positions_spread_orbs_and_advance_over_time() -> bool:
	var center := Vector2(100.0, 50.0)
	var first: Vector2 = WeaponMath.orbit_position(center, 70.0, 150.0, 0.0, 0, 2)
	var second: Vector2 = WeaponMath.orbit_position(center, 70.0, 150.0, 0.0, 1, 2)
	if absf(center.distance_to(first) - 70.0) > EPSILON:
		return false
	if absf(center.distance_to(second) - 70.0) > EPSILON:
		return false
	# Two orbs sit on opposite sides of the ring.
	if first.distance_to(second) < 140.0 - EPSILON:
		return false
	# One second at 150°/s moves the orb to a genuinely different point.
	var later: Vector2 = WeaponMath.orbit_position(center, 70.0, 150.0, 1.0, 0, 2)
	var expected: Vector2 = center + Vector2.from_angle(deg_to_rad(150.0)) * 70.0
	return first.distance_to(later) > 1.0 and later.distance_to(expected) < EPSILON


func test_pierce_orders_hits_along_the_line() -> bool:
	var positions: Array[Vector2] = [
		Vector2(300.0, 0.0), Vector2(100.0, 0.0), Vector2(200.0, 5.0)
	]
	var radii: Array[float] = [8.0, 8.0, 8.0]
	var hits: Array[int] = WeaponMath.pierce_hits(
		Vector2.ZERO, Vector2.RIGHT, positions, radii, 4.0, 99
	)
	return hits == [1, 2, 0]


func test_pierce_cap_and_line_width_respected() -> bool:
	var positions: Array[Vector2] = [
		Vector2(100.0, 0.0),   # 1st on the line
		Vector2(150.0, 0.0),   # 2nd on the line
		Vector2(200.0, 0.0),   # 3rd — beyond a pierce cap of 1 (2 hits total)
		Vector2(120.0, 40.0),  # off the line — never hit
		Vector2(-50.0, 0.0)    # behind the muzzle — never hit
	]
	var radii: Array[float] = [8.0, 8.0, 8.0, 8.0, 8.0]
	var hits: Array[int] = WeaponMath.pierce_hits(
		Vector2.ZERO, Vector2.RIGHT, positions, radii, 4.0, 1
	)
	return hits == [0, 1]


func test_runtime_gate_offers_every_taoist_mechanic() -> bool:
	return (
		LevelUp.runtime_can_fire(EXPLOSION_WEAPON)
		and LevelUp.runtime_can_fire(CHAIN_WEAPON)
		and LevelUp.runtime_can_fire(ARC_WEAPON)
		and LevelUp.runtime_can_fire(ORBIT_WEAPON)
		and LevelUp.runtime_can_fire(PIERCE_WEAPON)
	)


func test_runtime_gate_rejects_unfireable_entries() -> bool:
	# The 환도 family: no mechanic declared, speed 0 — stays out of the pool.
	var legacy_melee := {"speed": 0.0}
	# A future mechanic the runtime does not implement yet.
	var unknown := {"mechanic": "summon", "speed": 0.0}
	# A projectile mechanic that forgot its speed.
	var stuck := {"mechanic": "chain", "speed": 0.0}
	return (
		not LevelUp.runtime_can_fire(legacy_melee)
		and not LevelUp.runtime_can_fire(unknown)
		and not LevelUp.runtime_can_fire(stuck)
	)


func test_new_weapon_descriptions_carry_mechanic_numbers() -> bool:
	var explosion_text: String = LevelUp.mechanic_text(EXPLOSION_WEAPON)
	var chain_text: String = LevelUp.mechanic_text(CHAIN_WEAPON)
	var arc_text: String = LevelUp.mechanic_text(ARC_WEAPON)
	var orbit_text: String = LevelUp.mechanic_text(ORBIT_WEAPON)
	var pierce_text: String = LevelUp.mechanic_text(PIERCE_WEAPON)
	return (
		explosion_text.contains("90")
		and chain_text.contains("3") and chain_text.contains("70%")
		and arc_text.contains("160") and arc_text.contains("2.5")
		and orbit_text.contains("2") and orbit_text.contains("70")
		and orbit_text.contains("화상")
		and pierce_text.contains("관통")
	)


func test_seal_and_lifesteal_read_on_mod_cards() -> bool:
	var sealed := {
		"mechanic": "pierce", "pierce": 99,
		"on_hit_seal": {"burst_at": 4, "burst_damage_scale": 3.0},
	}
	var vampiric := {
		"mechanic": "melee_arc",
		"arc": {"angle_deg": 170.0, "knockback_scale": 2.8},
		"lifesteal": 0.12,
	}
	var seal_text: String = LevelUp.mechanic_text(sealed)
	var steal_text: String = LevelUp.mechanic_text(vampiric)
	return (
		seal_text.contains("봉인") and seal_text.contains("4")
		and steal_text.contains("흡혈") and steal_text.contains("12%")
	)
