class_name CombatMath
extends RefCounted
## Pure damage/aggro/spawn/targeting math for N3-3..N3-5. Node-free so the
## headless unit suite can drive it directly (tests/unit/test_combat.gd).


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


## Index of the candidate nearest to `from` within `max_range`, -1 when none
## qualifies. A candidate exactly at the range boundary is targetable.
static func nearest_index(from: Vector2, candidates: Array[Vector2], max_range: float) -> int:
	var best: int = -1
	var best_distance_squared: float = max_range * max_range
	for i: int in range(candidates.size()):
		var distance_squared: float = from.distance_squared_to(candidates[i])
		if distance_squared <= best_distance_squared:
			best = i
			best_distance_squared = distance_squared
	return best


static func projectile_position(
	start: Vector2, direction: Vector2, speed: float, elapsed: float
) -> Vector2:
	return start + direction * speed * elapsed


## Magnet pull ramp for XP orbs: speed grows every frame inside the pickup
## radius but never past `max_speed`.
static func accelerated_speed(
	current: float, acceleration: float, delta: float, max_speed: float
) -> float:
	return minf(current + acceleration * delta, max_speed)
