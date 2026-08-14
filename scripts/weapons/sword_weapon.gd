class_name SwordWeapon
extends WeaponBase
## Melee category. Sweeps an arc in the direction the hunter is facing; extra
## projectile_count levels add follow-up sweeps fanned around that facing.

## Matched to the authored swing art: wide_sword_arc content is 39 px across,
## so a radius of 20 covers what the art appears to cover. The offset clears
## the hunter's own 8 px body so the swing reads as being in front of them
## rather than on top of them.
const ARC_RADIUS_PX: float = 20.0
const ARC_OFFSET_PX: float = 26.0
const ARC_LIFETIME_SEC: float = 0.18
const MULTI_SWING_SPREAD_RAD: float = PI * 0.6


func _fire() -> bool:
	var wielder: Node2D = player()
	if wielder == null:
		return false
	var hit: Dictionary = roll_hit()
	var root: Node = spawn_root()
	var directions: PackedVector2Array = CombatMath.spread_directions(
		facing(), projectile_count(), MULTI_SWING_SPREAD_RAD
	)
	for direction in directions:
		var arc := MeleeArc.new()
		arc.damage = float(hit["amount"])
		arc.is_crit = bool(hit["is_crit"])
		arc.radius_px = ARC_RADIUS_PX * area_scale()
		arc.offset_px = ARC_OFFSET_PX * area_scale()
		arc.lifetime_sec = ARC_LIFETIME_SEC
		arc.facing = direction
		arc.texture = WeaponArt.melee_texture(weapon_id)
		arc.impact_effect = WeaponArt.impact_for_weapon(weapon_id)
		arc.lifesteal_fraction = float(data().get("lifesteal", 0.0))
		arc.global_position = wielder.global_position
		root.add_child(arc)
	return true
