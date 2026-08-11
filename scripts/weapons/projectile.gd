class_name Projectile
extends Area2D
## Generic combat projectile. Straight, homing, or orbit-then-homing depending on
## the fields the spawning weapon sets before it is added to the tree.
##
## Collision layers come from project.godot: 3 = player_projectile, 4 = enemy_projectile.

const PLAYER_PROJECTILE_LAYER: int = 1 << 2
const ENEMY_PROJECTILE_LAYER: int = 1 << 3
const PLAYER_LAYER: int = 1 << 0
const ENEMY_LAYER: int = 1 << 1

const DEFAULT_RADIUS_PX: float = 6.0
const DEFAULT_LIFETIME_SEC: float = 4.0
const PLACEHOLDER_SCALE: float = 0.5

var damage: float = 0.0
var is_crit: bool = false
## Extra enemies the projectile may pass through. 0 = despawn on first hit.
var pierce_left: int = 0
var speed: float = 200.0
var direction: Vector2 = Vector2.RIGHT
var lifetime_sec: float = DEFAULT_LIFETIME_SEC
var radius_px: float = DEFAULT_RADIUS_PX
var tint: Color = Color.WHITE
## Authored VFX from asset/weapon/projectiles. Left null by enemy shots,
## which have no weapon id and fall back to the tinted placeholder.
var texture: Texture2D = null
## Effect set played where this projectile lands. Enemy shots leave the
## default, so a hit on the player still reads.
var impact_effect: StringName = EffectPool.HIT
var target_group: StringName = &"enemy"

## Radians per second the heading may bend toward the nearest target. 0 = straight.
var homing_turn_rate_rad: float = 0.0

## Orbit phase: while it lasts the projectile circles `orbit_target` instead of
## travelling. Used by the talisman to read as a spirit ward before it strikes.
var orbit_target: Node2D = null
var orbit_radius_px: float = 44.0
var orbit_angular_speed_rad: float = 3.4
var orbit_sec: float = 0.0
var orbit_phase_rad: float = 0.0

var _age_sec: float = 0.0
var _hit_ids: Array[int] = []


func _ready() -> void:
	_ensure_shape()
	_ensure_sprite()
	body_entered.connect(_on_body_entered)
	_aim_sprite()


func configure_for_player() -> void:
	collision_layer = PLAYER_PROJECTILE_LAYER
	collision_mask = ENEMY_LAYER
	target_group = &"enemy"


func configure_for_enemy() -> void:
	collision_layer = ENEMY_PROJECTILE_LAYER
	collision_mask = PLAYER_LAYER
	target_group = &"player"


func _physics_process(delta: float) -> void:
	_age_sec += delta
	if _age_sec >= lifetime_sec:
		_despawn()
		return
	if _age_sec < orbit_sec and is_instance_valid(orbit_target):
		_orbit(delta)
		_aim_sprite()
		return
	if homing_turn_rate_rad > 0.0:
		_steer_toward_target(delta)
	global_position += direction * speed * delta
	_aim_sprite()


## Travel art is authored pointing east, so local +X is rotated onto the
## velocity rather than shipping a sprite per direction. Only the sprite turns;
## the collision circle is rotation-invariant and is left alone.
func _aim_sprite() -> void:
	var sprite: Sprite2D = get_node_or_null(^"Sprite2D") as Sprite2D
	if sprite != null and direction.length_squared() > 0.0:
		sprite.rotation = direction.angle()


func _orbit(delta: float) -> void:
	orbit_phase_rad += orbit_angular_speed_rad * delta
	var offset := Vector2.RIGHT.rotated(orbit_phase_rad) * orbit_radius_px
	global_position = orbit_target.global_position + offset
	# Leave the orbit moving tangentially so the transition reads as a release.
	direction = offset.normalized().orthogonal()


func _steer_toward_target(delta: float) -> void:
	var target: Node2D = _nearest_target()
	if target == null:
		return
	var desired: Vector2 = (target.global_position - global_position).normalized()
	if desired.length_squared() == 0.0:
		return
	var max_turn: float = homing_turn_rate_rad * delta
	direction = direction.normalized().rotated(clampf(direction.angle_to(desired), -max_turn, max_turn))


func _nearest_target() -> Node2D:
	var candidates: Array[Node] = get_tree().get_nodes_in_group(target_group)
	var positions := PackedVector2Array()
	for candidate in candidates:
		var node2d: Node2D = candidate as Node2D
		positions.append(node2d.global_position if node2d != null else Vector2.INF)
	# Same bound as the firing weapon: a ward must not steer toward something
	# the player cannot see any more than a bow should aim at it.
	var index: int = CombatMath.nearest_index_in_bounds(
		global_position, positions,
		CombatMath.visible_world_rect(get_viewport(), WeaponBase.ACQUISITION_MARGIN_PX)
	)
	if index < 0:
		return null
	return candidates[index] as Node2D


func _on_body_entered(body: Node2D) -> void:
	if not body.has_method(&"take_damage"):
		return
	var body_id: int = body.get_instance_id()
	if _hit_ids.has(body_id):
		return
	_hit_ids.append(body_id)
	EffectPool.play(impact_effect, body.global_position)
	body.take_damage(damage, is_crit)
	if pierce_left <= 0:
		_despawn()
		return
	pierce_left -= 1


func _ensure_shape() -> void:
	if get_node_or_null(^"CollisionShape2D") != null:
		return
	var shape := CircleShape2D.new()
	shape.radius = radius_px
	var collider := CollisionShape2D.new()
	collider.name = "CollisionShape2D"
	collider.shape = shape
	# Deferring only matters inside the tree, where the physics server rejects a
	# new shape while it is flushing queries. Outside it, a deferred call has no
	# frame to land on: the callable is dropped once this node is freed and the
	# collider is left with no owner at all, which is a leak, not a shape.
	if is_inside_tree():
		add_child.call_deferred(collider)
	else:
		add_child(collider)


func _ensure_sprite() -> void:
	if get_node_or_null(^"Sprite2D") != null:
		return
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	if texture != null:
		sprite.texture = texture
	else:
		sprite.texture = PlaceholderArt.placeholder(tint)
		sprite.scale = Vector2.ONE * PLACEHOLDER_SCALE
	add_child(sprite)


func _despawn() -> void:
	if is_inside_tree():
		queue_free()
