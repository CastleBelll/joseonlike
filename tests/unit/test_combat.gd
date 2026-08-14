extends RefCounted
## Guards the N3-3..N3-5 pure combat math (CombatMath, RunState) and the
## data-driven player HP / invulnerability / progression contracts.

const EPSILON := 0.001
const INVULN := 0.8
const VIEW := Vector2(540.0, 960.0)
const SPAWN_MARGIN := 48.0
const RING_SAMPLES := 16
# Documented curve (data/BALANCE.md, N4-2b 5-minute rescale):
# xp_to_next(L) = round(6 * 1.5^(L-1)).
const XP_BASE := 6.0
const XP_GROWTH := 1.5


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


func test_starting_weapon_reads_characters_json() -> bool:
	return Player.load_starting_weapon() == "old_talisman"


func test_nearest_visible_picks_closest_valid() -> bool:
	var candidates: Array[Vector2] = [
		Vector2(100.0, 0.0), Vector2(30.0, 40.0), Vector2(0.0, 200.0)
	]
	return CombatMath.nearest_visible_index(
		Vector2.ZERO, Vector2.ZERO, VIEW, 48.0, candidates, 500.0
	) == 1


## The old bug (N3-15): the nearest enemy sat outside the screen and the
## talisman flew off like a guided missile. Off-view candidates must lose to
## a farther on-view one, and an empty field must return -1 (hold fire).
func test_nearest_visible_excludes_out_of_view() -> bool:
	# VIEW is 540x960: x=400 is past the 270+48 right edge, x=200 is inside.
	var candidates: Array[Vector2] = [Vector2(400.0, 0.0), Vector2(200.0, 0.0)]
	var picked: int = CombatMath.nearest_visible_index(
		Vector2.ZERO, Vector2.ZERO, VIEW, 48.0, candidates, 1000.0
	)
	var none: int = CombatMath.nearest_visible_index(
		Vector2.ZERO, Vector2.ZERO, VIEW, 48.0,
		[Vector2(400.0, 0.0)] as Array[Vector2], 1000.0
	)
	return picked == 1 and none == -1


func test_nearest_visible_excludes_out_of_range() -> bool:
	# On screen (y axis has 480px half-extent) but beyond the weapon's range.
	var candidates: Array[Vector2] = [Vector2(0.0, 450.0)]
	var out: int = CombatMath.nearest_visible_index(
		Vector2.ZERO, Vector2.ZERO, VIEW, 48.0, candidates, 420.0
	)
	var boundary: int = CombatMath.nearest_visible_index(
		Vector2.ZERO, Vector2.ZERO, VIEW, 48.0, candidates, 450.0
	)
	return out == -1 and boundary == 0


func test_nearest_visible_empty_returns_minus_one() -> bool:
	var none: Array[Vector2] = []
	return CombatMath.nearest_visible_index(
		Vector2.ZERO, Vector2.ZERO, VIEW, 48.0, none, 500.0
	) == -1


func test_projectile_expires_outside_view_rect() -> bool:
	var margin: float = 48.0
	# Just inside and just outside the right edge (270 + margin).
	var inside: Vector2 = Vector2(VIEW.x / 2.0 + margin - 1.0, 0.0)
	var outside: Vector2 = Vector2(VIEW.x / 2.0 + margin + 1.0, 0.0)
	var keeps: bool = not CombatMath.outside_view(inside, Vector2.ZERO, VIEW, margin)
	return keeps and CombatMath.outside_view(outside, Vector2.ZERO, VIEW, margin)


## Circle despawn would keep a projectile alive here: the corner-distance
## ring reaches ~550px but the rect edge is 270+48. The rect must win.
func test_view_rect_tighter_than_old_circle() -> bool:
	var position := Vector2(400.0, 0.0)
	var circle_kept: bool = not CombatMath.should_despawn(position, Vector2.ZERO, VIEW, 48.0)
	return circle_kept and CombatMath.outside_view(position, Vector2.ZERO, VIEW, 48.0)


func test_projectile_travels_straight() -> bool:
	var at: Vector2 = CombatMath.projectile_position(
		Vector2(10.0, 20.0), Vector2.RIGHT, 260.0, 0.5
	)
	return at.distance_to(Vector2(140.0, 20.0)) < EPSILON


func test_xp_to_next_matches_documented_curve() -> bool:
	var level_1: bool = RunState.xp_to_next(1, XP_BASE, XP_GROWTH) == 6
	var level_5: bool = RunState.xp_to_next(5, XP_BASE, XP_GROWTH) == 30
	var level_19: bool = RunState.xp_to_next(19, XP_BASE, XP_GROWTH) == 8867
	return level_1 and level_5 and level_19


func test_apply_xp_below_threshold_keeps_level() -> bool:
	var result: Dictionary = RunState.apply_xp(1, 0, 4, XP_BASE, XP_GROWTH)
	return int(result["level"]) == 1 and int(result["xp"]) == 4


func test_apply_xp_single_level_up_carries_remainder() -> bool:
	var result: Dictionary = RunState.apply_xp(1, 3, 4, XP_BASE, XP_GROWTH)
	return int(result["level"]) == 2 and int(result["xp"]) == 1


func test_apply_xp_multiple_levels_from_one_grant() -> bool:
	# Costs from level 1: 6, 9, 14, 20 → 49 spent, 1 left at level 5.
	var result: Dictionary = RunState.apply_xp(1, 0, 50, XP_BASE, XP_GROWTH)
	return int(result["level"]) == 5 and int(result["xp"]) == 1


func test_run_state_curve_reads_progression_json() -> bool:
	var curve: Dictionary = RunState.load_curve()
	var base_ok: bool = absf(float(curve.get("base_xp", 0.0)) - XP_BASE) < EPSILON
	return base_ok and absf(float(curve.get("growth", 0.0)) - XP_GROWTH) < EPSILON


func test_magnet_speed_accelerates_and_caps() -> bool:
	var first: float = CombatMath.accelerated_speed(0.0, 1500.0, 0.1, 520.0)
	var accelerates: bool = absf(first - 150.0) < EPSILON
	var capped: bool = CombatMath.accelerated_speed(500.0, 1500.0, 0.1, 520.0) == 520.0
	return accelerates and capped


func test_magnet_pull_points_orb_at_player() -> bool:
	var direction: Vector2 = CombatMath.chase_direction(Vector2(50.0, 0.0), Vector2.ZERO)
	return direction.distance_to(Vector2.LEFT) < EPSILON
