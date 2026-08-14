class_name TalismanWeapon
extends WeaponBase
## Spiritual category. The hunter throws paper charms straight at the nearest
## visible enemy; extra charms fan out wider than the bow's arrows because
## area coverage is the talisman's identity (GDD section 7).
##
## No orbit, no homing: the old ward circled the caster and then steered like
## a missile, which read as random motion and could chase enemies the player
## cannot see (owner feedback 2026-08-14). A charm now flies where it is
## thrown, and holds fire when the screen is empty — same contract as the bow.

const TINT: Color = Color(1.0, 0.85, 0.35)
const LIFETIME_SEC: float = 4.0
const RADIUS_PX: float = 7.0
const MULTI_SHOT_SPREAD_RAD: float = PI * 0.3


func _fire() -> bool:
	var caster: Node2D = player()
	if caster == null:
		return false
	var target: Node2D = nearest_enemy()
	if target == null:
		return false
	var aim: Vector2 = (target.global_position - caster.global_position).normalized()
	var hit: Dictionary = roll_hit()
	var root: Node = spawn_root()
	var directions: PackedVector2Array = CombatMath.spread_directions(
		aim, projectile_count(), MULTI_SHOT_SPREAD_RAD
	)
	for direction in directions:
		root.add_child(_make_charm(caster, direction, hit))
	return true


func _make_charm(caster: Node2D, direction: Vector2, hit: Dictionary) -> Projectile:
	var charm := Projectile.new()
	charm.damage = float(hit["amount"])
	charm.is_crit = bool(hit["is_crit"])
	charm.pierce_left = pierce()
	charm.speed = projectile_speed()
	charm.lifetime_sec = LIFETIME_SEC
	charm.radius_px = RADIUS_PX * area_scale()
	charm.tint = TINT
	charm.texture = WeaponArt.travel_texture(weapon_id)
	charm.impact_effect = WeaponArt.impact_for_weapon(weapon_id)
	charm.direction = direction
	charm.global_position = caster.global_position
	charm.on_hit_status = data().get("on_hit_status", {})
	charm.configure_for_player()
	return charm
