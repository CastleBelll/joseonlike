class_name MeleeArc
extends Area2D
## Short-lived swing hitbox spawned in front of the player. Each enemy inside it
## is hit once, then the arc disappears.

const PLAYER_PROJECTILE_LAYER: int = 1 << 2
const ENEMY_LAYER: int = 1 << 1
const DEFAULT_RADIUS_PX: float = 34.0
const DEFAULT_LIFETIME_SEC: float = 0.18
const ARC_POINTS: int = 9
const ARC_SPAN_RAD: float = PI * 0.75
const PLACEHOLDER_TINT: Color = Color(1.0, 0.93, 0.72, 0.55)

var damage: float = 0.0
var is_crit: bool = false
var radius_px: float = DEFAULT_RADIUS_PX
var lifetime_sec: float = DEFAULT_LIFETIME_SEC
var facing: Vector2 = Vector2.RIGHT

var _age_sec: float = 0.0
var _hit_ids: Array[int] = []


func _ready() -> void:
	collision_layer = PLAYER_PROJECTILE_LAYER
	collision_mask = ENEMY_LAYER
	rotation = facing.angle()
	_ensure_shape()
	_ensure_visual()
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_age_sec += delta
	if _age_sec >= lifetime_sec:
		_despawn()


func _on_body_entered(body: Node2D) -> void:
	if not body.has_method(&"take_damage"):
		return
	var body_id: int = body.get_instance_id()
	if _hit_ids.has(body_id):
		return
	_hit_ids.append(body_id)
	body.take_damage(damage, is_crit)


## A circle offset along the facing axis approximates a swing arc closely enough
## for the vertical slice, and costs one shape instead of a polygon per swing.
func _ensure_shape() -> void:
	if get_node_or_null(^"CollisionShape2D") != null:
		return
	var shape := CircleShape2D.new()
	shape.radius = radius_px
	var collider := CollisionShape2D.new()
	collider.name = "CollisionShape2D"
	collider.shape = shape
	collider.position = Vector2(radius_px * 0.6, 0.0)
	# Deferred: these areas are spawned from inside a physics callback, and the
	# physics server rejects a new shape while it is flushing queries.
	add_child.call_deferred(collider)


func _ensure_visual() -> void:
	if get_node_or_null(^"Polygon2D") != null:
		return
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	for index in ARC_POINTS:
		var angle: float = -ARC_SPAN_RAD * 0.5 + ARC_SPAN_RAD * float(index) / float(ARC_POINTS - 1)
		points.append(Vector2.RIGHT.rotated(angle) * radius_px * 1.3)
	var polygon := Polygon2D.new()
	polygon.name = "Polygon2D"
	polygon.polygon = points
	polygon.color = PLACEHOLDER_TINT
	add_child(polygon)


func _despawn() -> void:
	if is_inside_tree():
		queue_free()
