class_name Enemy
extends CharacterBody2D
## Chasing contact-damage monster (N3-4). Stats come from data/monsters.json;
## the rect visual is a placeholder until the AC-5 monster art lands. All
## behaviours chase for now — ranged/charger AI is a later feature.

signal died(enemy: Enemy)

const VISUAL_HEIGHT_RATIO := 2.4  # slightly taller than wide, like the player
const EYE_RATIO := 0.18
## Enemies overlap the player and each other freely (VS-like feel); damage is
## the proximity check below, never physics. Layer 2 keeps them off the
## player's default layer 1 so nothing pushes anything.
const COLLISION_LAYER_ENEMY := 2

## forest_spirit reads white, forest_goblin green, per DESIGN.md §5.1
## silhouette separation. Unknown ids fall back to the goblin green.
const PLACEHOLDER_COLORS: Dictionary = {
	"forest_goblin": UiPalette.ENEMY_GOBLIN,
	"forest_spirit": UiPalette.ENEMY_SPIRIT,
	"bamboo_brute": UiPalette.ENEMY_BRUTE,
}

var monster_id := ""
var hp: float = 0.0
var contact_radius: float = 0.0
var xp_drop: int = 0

var _damage: float = 0.0
var _speed: float = 0.0
var _contact_cooldown: float = 0.0
var _time_since_contact: float = 0.0
var _target: Player
var _body: ColorRect
var _shape: CollisionShape2D


func _ready() -> void:
	collision_layer = COLLISION_LAYER_ENEMY
	collision_mask = 0
	_shape = CollisionShape2D.new()
	_shape.shape = CircleShape2D.new()
	add_child(_shape)
	_body = ColorRect.new()
	_body.name = "Body"
	add_child(_body)
	var eye := ColorRect.new()
	eye.name = "Eye"
	eye.color = UiPalette.INK
	_body.add_child(eye)


## (Re)arms a pooled instance. Safe to call repeatedly on the same node.
func setup(id: String, stats: Dictionary, target: Player, contact_cooldown: float) -> void:
	monster_id = id
	hp = float(stats.get("hp", 1.0))
	_damage = float(stats.get("damage", 0.0))
	_speed = float(stats.get("speed", 0.0))
	contact_radius = float(stats.get("collision_radius", 10.0))
	xp_drop = int(stats.get("xp_drop", 0))
	_contact_cooldown = contact_cooldown
	_time_since_contact = contact_cooldown  # first touch may hit immediately
	_target = target
	(_shape.shape as CircleShape2D).radius = contact_radius
	_apply_placeholder_visual()


func _physics_process(delta: float) -> void:
	if _target == null:
		return
	_time_since_contact += delta
	velocity = CombatMath.chase_direction(global_position, _target.global_position) * _speed
	move_and_slide()
	_try_contact_damage()


func take_damage(amount: float) -> void:
	hp = CombatMath.apply_damage(hp, amount)
	if CombatMath.is_dead(hp):
		died.emit(self)


func _try_contact_damage() -> void:
	if not CombatMath.can_hit(_time_since_contact, _contact_cooldown):
		return
	var reach: float = contact_radius + Player.CONTACT_RADIUS
	if global_position.distance_squared_to(_target.global_position) > reach * reach:
		return
	if _target.take_hit(_damage):
		_time_since_contact = 0.0


func _apply_placeholder_visual() -> void:
	var size := Vector2(contact_radius * 2.0, contact_radius * VISUAL_HEIGHT_RATIO)
	_body.color = PLACEHOLDER_COLORS.get(monster_id, UiPalette.ENEMY_GOBLIN)
	_body.size = size
	_body.position = -size / 2.0
	var eye := _body.get_node("Eye") as ColorRect
	var eye_side: float = size.x * EYE_RATIO
	eye.size = Vector2(eye_side, eye_side)
	eye.position = Vector2(size.x * 0.55, size.y * 0.2)
