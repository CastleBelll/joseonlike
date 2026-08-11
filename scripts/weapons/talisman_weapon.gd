class_name TalismanWeapon
extends WeaponBase
## Spiritual category (old_talisman). Wards spin around the hunter for a moment,
## then peel off and home onto whatever is closest.

const TINT: Color = Color(1.0, 0.85, 0.35)
const ORBIT_SEC: float = 0.9
const ORBIT_RADIUS_PX: float = 46.0
const ORBIT_ANGULAR_SPEED_RAD: float = 3.4
const HOMING_TURN_RATE_RAD: float = 4.5
const LIFETIME_SEC: float = 5.0
const RADIUS_PX: float = 7.0
const FULL_TURN_RAD: float = TAU


func _fire() -> bool:
	var caster: Node2D = player()
	if caster == null:
		return false
	var count: int = projectile_count()
	var hit: Dictionary = roll_hit()
	var root: Node = spawn_root()
	for index in count:
		var phase: float = FULL_TURN_RAD * float(index) / float(count)
		root.add_child(_make_ward(caster, phase, hit))
	return true


func _make_ward(caster: Node2D, phase_rad: float, hit: Dictionary) -> Projectile:
	var ward := Projectile.new()
	ward.damage = float(hit["amount"])
	ward.is_crit = bool(hit["is_crit"])
	ward.pierce_left = pierce()
	ward.speed = projectile_speed()
	ward.lifetime_sec = LIFETIME_SEC
	ward.radius_px = RADIUS_PX * area_scale()
	ward.tint = TINT
	ward.texture = WeaponArt.travel_texture(weapon_id)
	ward.impact_effect = WeaponArt.impact_for_weapon(weapon_id)
	ward.homing_turn_rate_rad = HOMING_TURN_RATE_RAD
	ward.orbit_target = caster
	ward.orbit_radius_px = ORBIT_RADIUS_PX * area_scale()
	ward.orbit_angular_speed_rad = ORBIT_ANGULAR_SPEED_RAD
	ward.orbit_sec = ORBIT_SEC
	ward.orbit_phase_rad = phase_rad
	ward.direction = Vector2.RIGHT.rotated(phase_rad)
	ward.global_position = caster.global_position + ward.direction * ward.orbit_radius_px
	ward.configure_for_player()
	return ward
