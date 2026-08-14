class_name Projectile
extends Area2D
## Generic straight-flight combat projectile. Orbit and homing behaviours were
## removed on owner feedback (2026-08-14): a trajectory the player cannot
## predict reads as random, so every projectile now flies exactly where its
## weapon aimed it.
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

## Optional weapons.json on_hit_status payload ({"id","dps","duration_sec"}).
## Empty for weapons and enemy shots that apply nothing.
var on_hit_status: Dictionary = {}

## Optional weapons.json on_hit_chain payload
## ({"targets","damage_scale","range_px"}): every hit arcs scaled damage to
## the nearest other enemies in range. Empty = no chain.
var on_hit_chain: Dictionary = {}

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
	global_position += direction * speed * delta


## Travel art is authored pointing east, so local +X is rotated onto the
## velocity rather than shipping a sprite per direction. The heading never
## changes in flight, so one rotation at _ready is enough. Only the sprite
## turns; the collision circle is rotation-invariant and is left alone.
func _aim_sprite() -> void:
	var sprite: Sprite2D = get_node_or_null(^"Sprite2D") as Sprite2D
	if sprite != null and direction.length_squared() > 0.0:
		sprite.rotation = direction.angle()


func _on_body_entered(body: Node2D) -> void:
	if not body.has_method(&"take_damage"):
		return
	var body_id: int = body.get_instance_id()
	if _hit_ids.has(body_id):
		return
	_hit_ids.append(body_id)
	EffectPool.play(impact_effect, body.global_position)
	body.take_damage(damage, is_crit)
	_apply_on_hit_status(body)
	_apply_on_hit_chain(body)
	if pierce_left <= 0:
		_despawn()
		return
	pierce_left -= 1


func _apply_on_hit_status(body: Node2D) -> void:
	if on_hit_status.is_empty():
		return
	if String(on_hit_status.get("id", "")) == "burn" and body.has_method(&"apply_burn"):
		body.apply_burn(
			float(on_hit_status.get("dps", 0.0)),
			float(on_hit_status.get("duration_sec", 0.0))
		)


## Instant local arcs from the impact point — no extra projectiles, so the
## chain reads as lightning rather than as more shots.
func _apply_on_hit_chain(hit_body: Node2D) -> void:
	if on_hit_chain.is_empty():
		return
	var scaled_damage: float = damage * float(on_hit_chain.get("damage_scale", 0.0))
	if scaled_damage <= 0.0:
		return

	var candidates: Array[Node] = get_tree().get_nodes_in_group(target_group)
	var positions := PackedVector2Array()
	var exclude_index: int = -1
	for index in candidates.size():
		var node2d: Node2D = candidates[index] as Node2D
		positions.append(node2d.global_position if node2d != null else Vector2.INF)
		if candidates[index] == hit_body:
			exclude_index = index

	var picked: PackedInt32Array = CombatMath.chain_target_indices(
		hit_body.global_position,
		positions,
		exclude_index,
		int(on_hit_chain.get("targets", 0)),
		float(on_hit_chain.get("range_px", 0.0))
	)
	for index in picked:
		var target: Node2D = candidates[index] as Node2D
		if target == null or not target.has_method(&"take_damage"):
			continue
		EffectPool.play(impact_effect, target.global_position)
		target.take_damage(scaled_damage, false)


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
