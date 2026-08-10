class_name BowWeapon
extends WeaponBase
## Ranged category. Looses arrows at the nearest enemy; extra projectiles fan out
## around that aim line. Holds fire when the screen is empty.

const TINT: Color = Color(0.85, 0.95, 1.0)
const LIFETIME_SEC: float = 3.0
const RADIUS_PX: float = 5.0
const MULTI_SHOT_SPREAD_RAD: float = PI * 0.18


func _fire() -> bool:
	var archer: Node2D = player()
	if archer == null:
		return false
	var target: Node2D = nearest_enemy()
	if target == null:
		return false
	var aim: Vector2 = (target.global_position - archer.global_position).normalized()
	var hit: Dictionary = roll_hit()
	var root: Node = spawn_root()
	var directions: PackedVector2Array = CombatMath.spread_directions(
		aim, projectile_count(), MULTI_SHOT_SPREAD_RAD
	)
	for direction in directions:
		var arrow := Projectile.new()
		arrow.damage = float(hit["amount"])
		arrow.is_crit = bool(hit["is_crit"])
		arrow.pierce_left = pierce()
		arrow.speed = projectile_speed()
		arrow.lifetime_sec = LIFETIME_SEC
		arrow.radius_px = RADIUS_PX * area_scale()
		arrow.tint = TINT
		arrow.texture = vfx_texture()
		arrow.impact_effect = EffectPool.weapon_effect(weapon_id)
		arrow.direction = direction
		arrow.global_position = archer.global_position
		arrow.configure_for_player()
		root.add_child(arrow)
	return true
