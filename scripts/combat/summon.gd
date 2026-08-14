class_name Summon
extends CharacterBody2D
## Autonomous ally (신장 소환, N4-4b GDD §11.1): seeks the nearest enemy
## inside the leash radius around the player and strikes on contact; with no
## target it heels back to the player. Same obstacle rule as enemies —
## LAYER_OBSTACLE in the collision mask, so it slides around solid props
## instead of walking through them. Lifetime-limited and pooled by AutoWeapon.

signal struck(amount: float, at: Vector2, boss_hit: bool)
signal expired(summon: Summon)

const CONTACT_RADIUS := 12.0
const BODY_SIZE := Vector2(20.0, 32.0)
const EYE_SIZE := 4.0
## Stop this close to the player when heeling, so the general hovers at the
## master's side instead of vibrating on top of it.
const HEEL_DISTANCE_PX := 48.0

var _player: Player
var _spawner: Spawner
var _damage: float = 0.0
var _speed: float = 0.0
var _leash: float = 0.0
var _attack_cooldown: float = 0.0
var _life_left: float = 0.0
var _attack_timer: float = 0.0
var _status: Dictionary = {}
var _color: Color = UiPalette.ACCENT_TAOIST
var _visual: Node2D
var _facing: int = PlayerMotion.FACING_RIGHT
var _positions: Array[Vector2] = []  # per-frame scratch, reused without alloc


func _ready() -> void:
	collision_layer = 0
	collision_mask = StageField.LAYER_OBSTACLE
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = CONTACT_RADIUS
	shape.shape = circle
	add_child(shape)
	_visual = SummonVisual.new()
	add_child(_visual)


## (Re)arms a pooled instance next to the player.
func arm(
	at: Vector2,
	player: Player,
	spawner: Spawner,
	summon_config: Dictionary,
	damage: float,
	status: Dictionary,
	color: Color
) -> void:
	global_position = at
	_player = player
	_spawner = spawner
	_damage = damage
	_status = status
	_color = color
	_speed = float(summon_config.get("speed", 0.0))
	_leash = float(summon_config.get("leash_px", 0.0))
	_attack_cooldown = float(summon_config.get("attack_cooldown_sec", 1.0))
	_life_left = float(summon_config.get("lifetime_sec", 0.0))
	_attack_timer = 0.0
	_facing = PlayerMotion.FACING_RIGHT
	(_visual as SummonVisual).color = color
	_visual.scale.x = 1.0
	_visual.queue_redraw()


func _physics_process(delta: float) -> void:
	_life_left -= delta
	if _life_left <= 0.0:
		expired.emit(self)
		return
	_attack_timer -= delta
	var enemies: Array[Enemy] = _spawner.active_enemies()
	_positions.clear()
	for enemy: Enemy in enemies:
		_positions.append(enemy.global_position)
	var index: int = WeaponMath.summon_target_index(
		global_position, _player.global_position, _positions, _leash
	)
	var destination: Vector2 = (
		_positions[index] if index >= 0 else _player.global_position
	)
	if index < 0 and global_position.distance_to(destination) <= HEEL_DISTANCE_PX:
		velocity = Vector2.ZERO
	else:
		velocity = CombatMath.chase_direction(global_position, destination) * _speed
	move_and_slide()
	_facing = PlayerMotion.facing_sign(velocity.x, _facing)
	_visual.scale.x = float(_facing)
	if index >= 0 and _attack_timer <= 0.0:
		_try_strike(enemies[index])


func _try_strike(enemy: Enemy) -> void:
	if CombatMath.is_dead(enemy.hp):
		return
	var reach: float = enemy.contact_radius + CONTACT_RADIUS
	if global_position.distance_squared_to(enemy.global_position) > reach * reach:
		return
	_attack_timer = _attack_cooldown
	var at: Vector2 = enemy.global_position
	var boss_hit: bool = enemy.is_boss
	if String(_status.get("id", "")) == "shock":
		enemy.apply_shock(
			float(_status.get("slow_scale", 1.0)),
			float(_status.get("duration_sec", 0.0))
		)
	enemy.take_damage(_damage, CombatMath.chase_direction(global_position, at))
	struck.emit(_damage, at, boss_hit)


## Placeholder art: tinted robed silhouette with an ink outline and a paper
## eye band — palette tokens only; real art in ASSET_REQUIREMENTS.md.
class SummonVisual:
	extends Node2D

	var color: Color = UiPalette.ACCENT_TAOIST

	func _draw() -> void:
		var rect := Rect2(-Summon.BODY_SIZE / 2.0, Summon.BODY_SIZE)
		draw_rect(rect, UiPalette.INK)
		draw_rect(rect.grow(-1.0), color)
		draw_rect(
			Rect2(
				Vector2(Summon.BODY_SIZE.x * 0.1, -Summon.BODY_SIZE.y * 0.3),
				Vector2(Summon.EYE_SIZE, Summon.EYE_SIZE)
			),
			UiPalette.PAPER
		)
