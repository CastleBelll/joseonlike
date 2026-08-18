class_name CombatMath
extends RefCounted
## Pure damage/aggro/spawn/targeting math for N3-3..N3-5. Node-free so the
## headless unit suite can drive it directly (tests/unit/test_combat.gd).


static func apply_damage(hp: float, damage: float) -> float:
	return maxf(hp - damage, 0.0)


static func is_dead(hp: float) -> bool:
	return hp <= 0.0


## N6-2 low-health warning gate: true while alive at or under the data
## threshold fraction (effects.json hit_feedback.low_hp_threshold). Boundary
## inclusive so crossing exactly onto the threshold already warns.
static func is_low_hp(hp: float, hp_max: float, threshold: float) -> bool:
	if hp_max <= 0.0 or is_dead(hp):
		return false
	return hp <= hp_max * threshold


## Shared window rule for the player invulnerability window and the
## per-enemy contact cooldown: a hit exactly at the boundary lands.
static func can_hit(time_since_last_hit: float, cooldown: float) -> bool:
	return time_since_last_hit >= cooldown


## N6-3 timed-shield rule (축지 blink, 회생부 revive): a new grant only ever
## EXTENDS the remaining window to its own duration — grants never sum, so
## repeated casts cannot stack shield on top of shield.
static func grace_extend(left: float, grant: float) -> float:
	return maxf(left, grant)


## Countdown for the same window; never goes below zero.
static func grace_tick(left: float, delta: float) -> float:
	return maxf(left - delta, 0.0)


## Zero when already on target so a stacked enemy does not jitter.
static func chase_direction(from: Vector2, to: Vector2) -> Vector2:
	return (to - from).normalized() if from != to else Vector2.ZERO


## Below this squared slide length a block counts as head-on.
const HEAD_ON_EPSILON := 0.01


## Obstacle steering for the chase (N3-9): keep the component that slides
## along the blocking wall, and when the block is head-on (slide ~ zero) walk
## the wall tangent in the enemy's fixed avoid direction, so a blocked enemy
## always makes progress around a solid prop instead of grinding into it.
static func avoid_direction(
	desired: Vector2, block_normal: Vector2, avoid_sign: float
) -> Vector2:
	if block_normal == Vector2.ZERO or desired == Vector2.ZERO:
		return desired
	var along_wall: Vector2 = desired.slide(block_normal)
	if along_wall.length_squared() > HEAD_ON_EPSILON:
		return along_wall.normalized()
	return Vector2(block_normal.y, -block_normal.x) * avoid_sign


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


## Camera view rectangle grown by `margin` on every side (N3-15). The rect —
## not the old half-diagonal circle — is what "visible" means for targeting
## and projectile life, so nothing tracks or flies where the player can't see.
static func view_rect(camera_center: Vector2, view_size: Vector2, margin: float) -> Rect2:
	var margin_vector := Vector2(margin, margin)
	return Rect2(
		camera_center - view_size / 2.0 - margin_vector, view_size + margin_vector * 2.0
	)


static func outside_view(
	position: Vector2, camera_center: Vector2, view_size: Vector2, margin: float
) -> bool:
	return not view_rect(camera_center, view_size, margin).has_point(position)


## N3-15 targeting: nearest candidate that is BOTH inside the visible view
## rect (+margin) and within the weapon's own range. -1 when nothing
## qualifies — the weapon holds fire rather than shooting off-screen.
static func nearest_visible_index(
	from: Vector2,
	camera_center: Vector2,
	view_size: Vector2,
	margin: float,
	candidates: Array[Vector2],
	max_range: float
) -> int:
	var visible: Rect2 = view_rect(camera_center, view_size, margin)
	var best: int = -1
	var best_distance_squared: float = max_range * max_range
	for i: int in range(candidates.size()):
		if not visible.has_point(candidates[i]):
			continue
		var distance_squared: float = from.distance_squared_to(candidates[i])
		if distance_squared <= best_distance_squared:
			best = i
			best_distance_squared = distance_squared
	return best


## N6-4 uniform aim fallback for every targeting weapon: nearest visible
## enemy in range first, else nearest visible destructible, else a point at
## max range along the player's facing direction (weapons never go silent —
## destructibles are targets too, and an empty view still fires forward).
## Returns {"kind": "enemy"|"breakable"|"facing", "index": int, "point": Vector2};
## index is -1 for the facing fallback.
static func fallback_aim(
	from: Vector2,
	camera_center: Vector2,
	view_size: Vector2,
	margin: float,
	enemies: Array[Vector2],
	breakables: Array[Vector2],
	max_range: float,
	facing_direction: Vector2
) -> Dictionary:
	var enemy_index: int = nearest_visible_index(
		from, camera_center, view_size, margin, enemies, max_range
	)
	if enemy_index >= 0:
		return {"kind": "enemy", "index": enemy_index, "point": enemies[enemy_index]}
	var break_index: int = nearest_visible_index(
		from, camera_center, view_size, margin, breakables, max_range
	)
	if break_index >= 0:
		return {"kind": "breakable", "index": break_index, "point": breakables[break_index]}
	var direction: Vector2 = facing_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT  # never fired a zero-length aim
	return {"kind": "facing", "index": -1, "point": from + direction * max_range}


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
