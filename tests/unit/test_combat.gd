extends RefCounted
## Guards the N3-4 pure combat math (CombatMath) and the data-driven
## player HP / invulnerability contract.

const EPSILON := 0.001
const INVULN := 0.8
const VIEW := Vector2(540.0, 960.0)
const SPAWN_MARGIN := 48.0
const RING_SAMPLES := 16


func test_damage_application_reduces_hp() -> bool:
	return absf(CombatMath.apply_damage(20.0, 6.0) - 14.0) < EPSILON


func test_damage_never_goes_below_zero() -> bool:
	return CombatMath.apply_damage(5.0, 99.0) == 0.0


func test_death_at_exactly_zero_hp() -> bool:
	var hp: float = CombatMath.apply_damage(20.0, 20.0)
	return hp == 0.0 and CombatMath.is_dead(hp)


func test_alive_above_zero_hp() -> bool:
	return not CombatMath.is_dead(0.1)


func test_invuln_window_blocks_second_hit_inside_window() -> bool:
	return not CombatMath.can_hit(INVULN * 0.5, INVULN)


func test_invuln_window_allows_hit_after_window() -> bool:
	return CombatMath.can_hit(INVULN + 0.1, INVULN) and CombatMath.can_hit(INVULN, INVULN)


func test_chase_direction_points_from_enemy_to_player() -> bool:
	var direction: Vector2 = CombatMath.chase_direction(Vector2(10.0, 10.0), Vector2(10.0, 50.0))
	var normalized: bool = absf(direction.length() - 1.0) < EPSILON
	return normalized and direction.distance_to(Vector2.DOWN) < EPSILON


func test_chase_direction_zero_on_target() -> bool:
	return CombatMath.chase_direction(Vector2(3.0, 4.0), Vector2(3.0, 4.0)) == Vector2.ZERO


func test_spawn_ring_is_outside_camera_rect() -> bool:
	var center := Vector2(100.0, -40.0)
	var camera_rect := Rect2(center - VIEW / 2.0, VIEW)
	for i: int in range(RING_SAMPLES):
		var angle: float = TAU * float(i) / float(RING_SAMPLES)
		var spawn: Vector2 = CombatMath.spawn_position(center, VIEW, SPAWN_MARGIN, angle)
		if camera_rect.has_point(spawn):
			return false
	return true


func test_despawn_only_beyond_margin() -> bool:
	var center := Vector2.ZERO
	var near: Vector2 = Vector2(VIEW.length() / 2.0 + 100.0, 0.0)
	var far: Vector2 = Vector2(VIEW.length() / 2.0 + 500.0, 0.0)
	var keeps_near: bool = not CombatMath.should_despawn(near, center, VIEW, 480.0)
	return keeps_near and CombatMath.should_despawn(far, center, VIEW, 480.0)


func test_player_hp_reads_characters_json() -> bool:
	return absf(Player.load_base_hp() - 120.0) < EPSILON


func test_player_invuln_reads_characters_json() -> bool:
	return absf(Player.load_hit_invuln_sec() - INVULN) < EPSILON
