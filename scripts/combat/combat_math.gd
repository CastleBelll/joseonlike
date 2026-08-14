class_name CombatMath
extends RefCounted
## Pure damage/aggro/spawn math for N3-4. Node-free so the headless unit
## suite can drive it directly (tests/unit/test_combat.gd).


static func apply_damage(hp: float, damage: float) -> float:
	return maxf(hp - damage, 0.0)


static func is_dead(hp: float) -> bool:
	return hp <= 0.0


## Shared window rule for the player invulnerability window and the
## per-enemy contact cooldown: a hit exactly at the boundary lands.
static func can_hit(time_since_last_hit: float, cooldown: float) -> bool:
	return time_since_last_hit >= cooldown


## Zero when already on target so a stacked enemy does not jitter.
static func chase_direction(from: Vector2, to: Vector2) -> Vector2:
	return (to - from).normalized() if from != to else Vector2.ZERO


## Point on a ring guaranteed outside the camera rect: the ring radius is the
## rect half-diagonal plus a margin, so every angle clears every rect corner.
static func spawn_position(
	camera_center: Vector2, view_size: Vector2, margin: float, angle: float
) -> Vector2:
	var radius: float = view_size.length() / 2.0 + margin
	return camera_center + Vector2.from_angle(angle) * radius


static func should_despawn(
	enemy_position: Vector2, camera_center: Vector2, view_size: Vector2, despawn_margin: float
) -> bool:
	var limit: float = view_size.length() / 2.0 + despawn_margin
	return enemy_position.distance_to(camera_center) > limit
