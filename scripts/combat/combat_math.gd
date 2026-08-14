class_name CombatMath
extends RefCounted
## Pure combat formulas: weapon stat scaling, damage, crit and cooldown.
##
## Deliberately free of autoload and scene-tree access. The headless test runner
## executes before autoloads exist, so any file it loads must not reference
## EventBus / GameData / RunState — those values arrive here as plain arguments.

## Weapon levels are 1-based, so a level-1 weapon gets zero per_level deltas.
const MIN_LEVEL: int = 1

## Crit payout has no home in data/*.json yet: passives.json exposes crit_chance
## but no crit_damage stat. Keep it a named constant until the schema gains one.
const CRIT_MULTIPLIER: float = 2.0

## Floor so an extreme attack_speed stack cannot produce a zero-length cooldown
## and fire every frame.
const MIN_COOLDOWN_SEC: float = 0.05

## An attack_speed total of -1.0 would divide by zero; clamp the divisor instead.
const MIN_SPEED_MULTIPLIER: float = 0.1

## skill_power scales spiritual weapons only, matching the Taoist fantasy in the GDD.
const CATEGORY_SPIRITUAL: String = "spiritual"

const KEY_DAMAGE: String = "damage"
const KEY_COOLDOWN: String = "cooldown_sec"
const KEY_PROJECTILE_COUNT: String = "projectile_count"
const KEY_PIERCE: String = "pierce"
const KEY_AREA_SCALE: String = "area_scale"
const KEY_SPEED: String = "speed"
const KEY_MAX_LEVEL: String = "max_level"
const KEY_PER_LEVEL: String = "per_level"
const KEY_CATEGORY: String = "category"

const DEFAULT_PROJECTILE_COUNT: int = 1
const DEFAULT_PIERCE: int = 0
const DEFAULT_AREA_SCALE: float = 1.0
const DEFAULT_SPEED: float = 200.0
const DEFAULT_COOLDOWN_SEC: float = 1.0
const DEFAULT_MAX_LEVEL: int = 8


## Base value plus per_level delta applied (level - 1) times.
static func stat_at_level(weapon_data: Dictionary, level: int, key: String, default_value: float) -> float:
	var base_value: float = float(weapon_data.get(key, default_value))
	var per_level: Dictionary = weapon_data.get(KEY_PER_LEVEL, {})
	var delta: float = float(per_level.get(key, 0.0))
	return base_value + delta * float(clamp_level(level) - MIN_LEVEL)


## Integer flavour of stat_at_level for counters such as projectile_count.
static func int_stat_at_level(weapon_data: Dictionary, level: int, key: String, default_value: int) -> int:
	return maxi(0, int(floor(stat_at_level(weapon_data, level, key, float(default_value)))))


static func clamp_level(level: int) -> int:
	return maxi(level, MIN_LEVEL)


static func max_level(weapon_data: Dictionary) -> int:
	return maxi(MIN_LEVEL, int(weapon_data.get(KEY_MAX_LEVEL, DEFAULT_MAX_LEVEL)))


## Damage before crit. attack_damage is a fractional bonus (0.15 == +15%);
## skill_power stacks on top of it for spiritual weapons only.
static func base_damage(
	weapon_data: Dictionary,
	level: int,
	attack_damage_bonus: float,
	skill_power_bonus: float
) -> float:
	var raw: float = stat_at_level(weapon_data, level, KEY_DAMAGE, 0.0)
	var multiplier: float = 1.0 + attack_damage_bonus
	if String(weapon_data.get(KEY_CATEGORY, "")) == CATEGORY_SPIRITUAL:
		multiplier += skill_power_bonus
	return maxf(raw * maxf(multiplier, 0.0), 0.0)


static func is_crit(crit_chance: float, crit_roll: float) -> bool:
	return crit_roll < clampf(crit_chance, 0.0, 1.0)


## Full hit resolution. crit_roll is injected (never rolled here) so the caller
## owns randomness and tests stay deterministic.
static func resolve_hit(
	weapon_data: Dictionary,
	level: int,
	attack_damage_bonus: float,
	skill_power_bonus: float,
	crit_chance: float,
	crit_roll: float
) -> Dictionary:
	var amount: float = base_damage(weapon_data, level, attack_damage_bonus, skill_power_bonus)
	var critical: bool = is_crit(crit_chance, crit_roll)
	if critical:
		amount *= CRIT_MULTIPLIER
	return {"amount": amount, "is_crit": critical}


## Seconds between shots. attack_speed is a fractional bonus (0.25 == +25% rate).
static func cooldown_at_level(weapon_data: Dictionary, level: int, attack_speed_bonus: float) -> float:
	var raw: float = stat_at_level(weapon_data, level, KEY_COOLDOWN, DEFAULT_COOLDOWN_SEC)
	var multiplier: float = maxf(1.0 + attack_speed_bonus, MIN_SPEED_MULTIPLIER)
	return maxf(raw / multiplier, MIN_COOLDOWN_SEC)


static func projectile_count_at_level(weapon_data: Dictionary, level: int) -> int:
	return maxi(1, int_stat_at_level(weapon_data, level, KEY_PROJECTILE_COUNT, DEFAULT_PROJECTILE_COUNT))


static func pierce_at_level(weapon_data: Dictionary, level: int) -> int:
	return int_stat_at_level(weapon_data, level, KEY_PIERCE, DEFAULT_PIERCE)


static func area_scale_at_level(weapon_data: Dictionary, level: int) -> float:
	return maxf(0.01, stat_at_level(weapon_data, level, KEY_AREA_SCALE, DEFAULT_AREA_SCALE))


static func projectile_speed_at_level(weapon_data: Dictionary, level: int) -> float:
	return maxf(1.0, stat_at_level(weapon_data, level, KEY_SPEED, DEFAULT_SPEED))


## Visible world rectangle, grown by a margin, for target acquisition.
##
## A rectangle rather than a radius, because the viewport is portrait: at
## 540x960 the visible half-extents are 270 x 480, but a radius large enough to
## reach the corners is 551. That radius would acquire a target 551 px to the
## side, twice as far as the player can actually see horizontally, which is the
## off-screen homing that was reported. The rectangle is exact on both axes.
##
## A null viewport yields an unbounded rect, so headless callers and tests are
## not silently constrained.
static func visible_world_rect(viewport: Viewport, margin_px: float) -> Rect2:
	if viewport == null:
		return Rect2(-INF / 4.0, -INF / 4.0, INF / 2.0, INF / 2.0)
	var size: Vector2 = viewport.get_visible_rect().size
	var top_left: Vector2 = viewport.get_canvas_transform().affine_inverse() * Vector2.ZERO
	return Rect2(top_left, size).grow(margin_px)


## Closest position inside `bounds`, or -1 when nothing qualifies. Targets the
## player cannot see are not acquired at all, rather than acquired and missed.
static func nearest_index_in_bounds(origin: Vector2, positions: PackedVector2Array, bounds: Rect2) -> int:
	var best_index: int = -1
	var best_distance_sq: float = INF
	for index in positions.size():
		if not bounds.has_point(positions[index]):
			continue
		var distance_sq: float = origin.distance_squared_to(positions[index])
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			best_index = index
	return best_index


## Up to `max_targets` indices within `range_px` of `origin`, nearest first,
## skipping `exclude_index` (the enemy that was just hit). Chain lightning
## jumps locally from the impact, so unlike acquisition there is no viewport
## bound — the range is the bound.
static func chain_target_indices(
	origin: Vector2,
	positions: PackedVector2Array,
	exclude_index: int,
	max_targets: int,
	range_px: float
) -> PackedInt32Array:
	var picked := PackedInt32Array()
	if max_targets <= 0 or range_px <= 0.0:
		return picked

	var candidates: Array[Vector2i] = []  # x = integer distance-squared key, y = index
	var range_sq: float = range_px * range_px
	for index in positions.size():
		if index == exclude_index:
			continue
		var distance_sq: float = origin.distance_squared_to(positions[index])
		if distance_sq > range_sq:
			continue
		candidates.append(Vector2i(int(distance_sq), index))

	candidates.sort()
	for entry in candidates.slice(0, max_targets):
		picked.append(entry.y)
	return picked


## Index of the closest position, or -1 when there is nothing to shoot at.
static func nearest_index(origin: Vector2, positions: PackedVector2Array) -> int:
	var best_index: int = -1
	var best_distance_sq: float = INF
	for index in positions.size():
		var distance_sq: float = origin.distance_squared_to(positions[index])
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			best_index = index
	return best_index


## Evenly spread `count` directions across `spread_rad` centred on `forward`.
static func spread_directions(forward: Vector2, count: int, spread_rad: float) -> PackedVector2Array:
	var directions := PackedVector2Array()
	var safe_count: int = maxi(count, 1)
	var base_direction: Vector2 = forward.normalized() if forward.length_squared() > 0.0 else Vector2.RIGHT
	if safe_count == 1:
		directions.append(base_direction)
		return directions
	var step: float = spread_rad / float(safe_count - 1)
	for index in safe_count:
		directions.append(base_direction.rotated(-spread_rad * 0.5 + step * float(index)))
	return directions
