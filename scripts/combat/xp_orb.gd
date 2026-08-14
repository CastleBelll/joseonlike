class_name XpOrb
extends Node2D
## Cyan-green XP orb (N3-5, DESIGN.md §5.1). Sits where the enemy died until
## the player's magnet radius reaches it, then accelerates in and is
## collected on contact. Pooled by the stage.

signal collected(orb: XpOrb)

const GLOW_RADIUS := 5.0
const CORE_RADIUS := 3.0
const GLOW_ALPHA := 0.45

var xp_value: int = 0

var _player: Player
var _magnet_radius_squared: float = 0.0
var _collect_radius_squared: float = 0.0
var _acceleration: float = 0.0
var _max_speed: float = 0.0
var _speed: float = 0.0


func launch(at: Vector2, xp: int, player: Player, orb_config: Dictionary) -> void:
	global_position = at
	xp_value = xp
	_player = player
	var magnet_radius: float = float(orb_config.get("magnet_radius_px", 0.0))
	var collect_radius: float = float(orb_config.get("collect_radius_px", 0.0))
	_magnet_radius_squared = magnet_radius * magnet_radius
	_collect_radius_squared = collect_radius * collect_radius
	_acceleration = float(orb_config.get("magnet_accel_px_s2", 0.0))
	_max_speed = float(orb_config.get("max_speed_px_s", 0.0))
	_speed = 0.0


func _physics_process(delta: float) -> void:
	var distance_squared: float = global_position.distance_squared_to(_player.global_position)
	if distance_squared <= _collect_radius_squared:
		collected.emit(self)
		return
	if distance_squared > _magnet_radius_squared:
		return
	_speed = CombatMath.accelerated_speed(_speed, _acceleration, delta, _max_speed)
	var direction: Vector2 = CombatMath.chase_direction(
		global_position, _player.global_position
	)
	global_position += direction * _speed * delta


func _draw() -> void:
	draw_circle(Vector2.ZERO, GLOW_RADIUS, Color(UiPalette.XP_ORB, GLOW_ALPHA))
	draw_circle(Vector2.ZERO, CORE_RADIUS, UiPalette.XP_ORB)
	draw_circle(Vector2.ZERO, CORE_RADIUS / 2.0, UiPalette.XP_ORB_CORE)
