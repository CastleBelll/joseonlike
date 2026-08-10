class_name XpPickup
extends Area2D
## Experience orb dropped where an enemy died. Drifts toward the player once it
## is close enough, then reports its value and despawns.
##
## The stage decides what happens to that value (it calls RunState.add_xp), so
## this file stays autoload-free and loadable by the headless test runner.

signal collected(amount: int)

## Preloaded rather than referenced by class_name: the headless test runner
## starts before global script classes are registered, so a bare
## `PlaceholderArt` here would fail to parse under `--script`.
const PlaceholderArtScript = preload("res://scripts/combat/placeholder_art.gd")

const PLAYER_GROUP: StringName = &"player"
const PICKUP_LAYER: int = 1 << 4
const PLAYER_LAYER: int = 1 << 0

const MAGNET_RADIUS_PX: float = 90.0
const MAGNET_SPEED_PX_SEC: float = 420.0
const COLLECT_RADIUS_PX: float = 10.0
const PLACEHOLDER_TINT: Color = Color(0.45, 0.9, 0.55)
const PLACEHOLDER_SCALE: float = 0.4
## Orbs left behind by a player who ran away should not accumulate forever.
const LIFETIME_SEC: float = 60.0

var xp_amount: int = 1

var _age_sec: float = 0.0
var _is_collected: bool = false


func _ready() -> void:
	collision_layer = PICKUP_LAYER
	collision_mask = PLAYER_LAYER
	monitoring = true
	_ensure_shape()
	_ensure_sprite()
	body_entered.connect(_on_body_entered)


func setup(amount: int, spawn_position: Vector2) -> void:
	xp_amount = maxi(amount, 0)
	global_position = spawn_position
	_age_sec = 0.0
	_is_collected = false


func _physics_process(delta: float) -> void:
	_age_sec += delta
	if _age_sec >= LIFETIME_SEC:
		_despawn()
		return
	var player: Node2D = get_tree().get_first_node_in_group(PLAYER_GROUP) as Node2D
	if player == null:
		return
	var offset: Vector2 = player.global_position - global_position
	var distance: float = offset.length()
	if distance > MAGNET_RADIUS_PX:
		return
	if distance <= COLLECT_RADIUS_PX:
		collect()
		return
	global_position += offset / distance * MAGNET_SPEED_PX_SEC * delta


## Reports the orb's value exactly once, then despawns. Returns the amount
## granted, or 0 when it had already been collected.
func collect() -> int:
	if _is_collected:
		return 0
	_is_collected = true
	collected.emit(xp_amount)
	_despawn()
	return xp_amount


func is_collected() -> bool:
	return _is_collected


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(PLAYER_GROUP):
		collect()


func _ensure_shape() -> void:
	if get_node_or_null(^"CollisionShape2D") != null:
		return
	var shape := CircleShape2D.new()
	shape.radius = COLLECT_RADIUS_PX
	var collider := CollisionShape2D.new()
	collider.name = "CollisionShape2D"
	collider.shape = shape
	add_child(collider)


func _ensure_sprite() -> void:
	var sprite: Sprite2D = get_node_or_null(^"Sprite2D") as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)
	if sprite.texture == null:
		sprite.texture = PlaceholderArtScript.placeholder(PLACEHOLDER_TINT)
		sprite.scale = Vector2.ONE * PLACEHOLDER_SCALE


## Guarded because tests build pickups outside the scene tree, where queue_free
## has no tree to defer against.
func _despawn() -> void:
	if is_inside_tree():
		queue_free()
