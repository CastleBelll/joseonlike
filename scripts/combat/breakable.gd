class_name Breakable
extends StaticBody2D
## Destructible solid prop (N5-5). Built once per run by StageField for props
## whose data declares a "breakable" block — it blocks movement exactly like a
## plain solid until PLAYER weapon damage empties its small HP bar, then
## deactivates in place (the fixed set built at run start is the pool; a break
## allocates nothing). Enemies never touch breakables on purpose: their only
## attack is contact damage on the player, so a shattered prop is always the
## player's doing.

signal broke(breakable: Breakable)

const FLASH_SEC := 0.1

var prop_id: String = ""
var hp: float = 0.0
## Half-footprint used by weapon overlap checks — same measure as an enemy's
## contact_radius so the projectile/arc/orbit hit code reads both alike.
var hit_radius: float = 0.0

var _shape: CollisionShape2D
var _flash_left: float = 0.0


func arm(id: String, break_hp: float, radius: float, shape: CollisionShape2D) -> void:
	prop_id = id
	hp = break_hp
	hit_radius = radius
	_shape = shape


func alive() -> bool:
	return hp > 0.0


## Player weapon damage only — nothing else calls this.
func take_weapon_damage(amount: float) -> void:
	if not alive():
		return
	hp -= amount
	if hp > 0.0:
		_flash_left = FLASH_SEC
		modulate = UiPalette.SPRITE_HIT_FLASH
		return
	hp = 0.0
	broke.emit(self)
	# Deactivate in place: invisible, unblocking, no further processing. The
	# node stays parked under the field for the rest of the run.
	visible = false
	_shape.set_deferred("disabled", true)
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if _flash_left <= 0.0:
		return
	_flash_left -= delta
	if _flash_left <= 0.0:
		modulate = Color.WHITE
