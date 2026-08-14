class_name WeaponMath
extends RefCounted
## Pure mechanic math for the taoist weapon archetypes (N4-4a, GDD §11.1):
## explosion splash, chain jumps, melee arc, orbit motion, pierce line.
## Node-free so the headless suite drives it directly
## (tests/unit/test_weapon_math.gd); the runtime (AutoWeapon/Projectile)
## consumes the same functions so tests and game agree by construction.


## Explosion splash: indices of every candidate whose center sits within
## `radius` of the impact point. Boundary inclusive.
static func targets_in_radius(
	center: Vector2, positions: Array[Vector2], radius: float
) -> Array[int]:
	var hits: Array[int] = []
	for i: int in range(positions.size()):
		if center.distance_squared_to(positions[i]) <= radius * radius:
			hits.append(i)
	return hits


## Next chain target: nearest candidate to `from` within `max_range` whose
## index is not excluded (already struck this chain). -1 ends the chain.
static func chain_next_index(
	from: Vector2, positions: Array[Vector2], exclude: Array[int], max_range: float
) -> int:
	var best: int = -1
	var best_distance_squared: float = max_range * max_range
	for i: int in range(positions.size()):
		if exclude.has(i):
			continue
		var distance_squared: float = from.distance_squared_to(positions[i])
		if distance_squared <= best_distance_squared:
			best = i
			best_distance_squared = distance_squared
	return best


## Damage after `jump` chain hops; jump 0 is the initial hit at full damage.
static func chain_damage(base: float, falloff: float, jump: int) -> float:
	return base * pow(falloff, float(jump))


## Melee arc swing: indices of candidates whose body (center + own radius)
## reaches into the swing radius AND whose center sits within half the arc
## either side of `aim_angle`. Angles in radians, arc is the full width.
static func arc_hits(
	origin: Vector2,
	aim_angle: float,
	arc_rad: float,
	radius: float,
	positions: Array[Vector2],
	radii: Array[float]
) -> Array[int]:
	var hits: Array[int] = []
	for i: int in range(positions.size()):
		var offset: Vector2 = positions[i] - origin
		var reach: float = radius + radii[i]
		if offset.length_squared() > reach * reach:
			continue
		# An enemy exactly on the origin is inside the swing from any angle.
		if offset != Vector2.ZERO and \
				absf(angle_difference(aim_angle, offset.angle())) > arc_rad / 2.0:
			continue
		hits.append(i)
	return hits


## Orb `index` of `count` orbs after `elapsed` seconds: evenly spread on the
## ring, all advancing together at `speed_deg_s`.
static func orbit_position(
	center: Vector2,
	radius: float,
	speed_deg_s: float,
	elapsed: float,
	index: int,
	count: int
) -> Vector2:
	var angle: float = (
		deg_to_rad(speed_deg_s) * elapsed + TAU * float(index) / float(maxi(count, 1))
	)
	return center + Vector2.from_angle(angle) * radius


## Pierce reference model: indices hit by a projectile flying from `origin`
## along `direction`, ordered by distance along the line. A candidate is on
## the line when its perpendicular distance is within hit_radius + its own
## radius. `pierce` counts enemies passed THROUGH beyond the first, matching
## the weapons.json field — total hits = pierce + 1.
static func pierce_hits(
	origin: Vector2,
	direction: Vector2,
	positions: Array[Vector2],
	radii: Array[float],
	hit_radius: float,
	pierce: int
) -> Array[int]:
	var along: Array[Vector2] = []  # (distance along line, candidate index)
	var forward: Vector2 = direction.normalized()
	for i: int in range(positions.size()):
		var offset: Vector2 = positions[i] - origin
		var distance_along: float = offset.dot(forward)
		if distance_along < 0.0:
			continue  # behind the muzzle; the projectile never reaches it
		var reach: float = hit_radius + radii[i]
		var off_line: float = absf(offset.cross(forward))
		if off_line > reach:
			continue
		along.append(Vector2(distance_along, float(i)))
	along.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var hits: Array[int] = []
	for pair: Vector2 in along.slice(0, pierce + 1):
		hits.append(int(pair.y))
	return hits
