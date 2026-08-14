class_name Enemy
extends CharacterBody2D
## Data-driven monster. Everything except the behaviour code comes from
## GameData.monster(id): hp, damage, speed, behaviour, xp_drop, gold_drop, sprite.
##
## Instances are pooled by EnemyPool, so all per-run state is (re)initialised in
## activate() rather than _ready().

signal despawned(enemy: Enemy)

const ENEMY_GROUP: StringName = &"enemy"
const PLAYER_GROUP: StringName = &"player"
const PROJECTILE_ROOT_GROUP: StringName = &"projectile_root"

const BEHAVIOUR_CHASE: String = "chase"
const BEHAVIOUR_RANGED: String = "ranged"
const BEHAVIOUR_CHARGER: String = "charger"
const BEHAVIOUR_SWARM: String = "swarm"
const BEHAVIOUR_BOSS: String = "boss"

const KEY_HP: String = "hp"
const KEY_DAMAGE: String = "damage"
const KEY_SPEED: String = "speed"
const KEY_BEHAVIOUR: String = "behaviour"
const KEY_XP_DROP: String = "xp_drop"
const KEY_GOLD_DROP: String = "gold_drop"
const KEY_SPRITE: String = "sprite"
const KEY_COLLISION_RADIUS: String = "collision_radius"

const DEFAULT_HP: float = 10.0
const DEFAULT_DAMAGE: float = 5.0
const DEFAULT_SPEED: float = 50.0

const PLACEHOLDER_TINT: Color = Color(0.85, 0.35, 0.4)
const BOSS_TINT: Color = Color(0.75, 0.25, 0.85)
const HIT_FLASH_SEC: float = 0.08
const HIT_FLASH_TINT: Color = Color(2.0, 2.0, 2.0)

## Ranged monsters hold this distance and shoot; inside the inner band they back
## off, so they never turn into accidental melee attackers.
const RANGED_PREFERRED_PX: float = 220.0
const RANGED_HYSTERESIS_PX: float = 40.0
const RANGED_COOLDOWN_SEC: float = 2.0
const RANGED_PROJECTILE_SPEED: float = 190.0
const RANGED_PROJECTILE_LIFETIME_SEC: float = 5.0

const CHARGER_WINDUP_SEC: float = 0.7
const CHARGER_DASH_SEC: float = 0.45
const CHARGER_RECOVER_SEC: float = 1.1
const CHARGER_DASH_MULTIPLIER: float = 3.2

## Swarmers weave instead of stacking into one pixel-perfect column.
const SWARM_WEAVE_HZ: float = 2.5
const SWARM_WEAVE_STRENGTH: float = 0.45

const BOSS_BURST_SEC: float = 3.5
const BOSS_BURST_PROJECTILES: int = 8
const BOSS_SPEED_SCALE: float = 0.75

var monster_id: String = ""
var max_hp: float = DEFAULT_HP
var hp: float = DEFAULT_HP
var contact_damage: float = DEFAULT_DAMAGE
var move_speed: float = DEFAULT_SPEED
var behaviour: String = BEHAVIOUR_CHASE
var xp_drop: int = 0
var gold_drop: int = 0
var is_active: bool = false

var _attack_cooldown_left: float = 0.0
var _charge_phase_left: float = 0.0
var _is_dashing: bool = false
var _charge_direction: Vector2 = Vector2.ZERO
var _weave_phase: float = 0.0
var _hit_flash_left: float = 0.0
## Procedural walk substitute recorded in asset/monster/WALK_STATUS.json after
## generated walk frames were measured and rejected. Same contract as the
## player: whole pixels, vertical only, reset on any state change.
var _bob_time: float = 0.0
var _rng: RandomNumberGenerator = CombatRng.create()
var _burn: BurnStatus = BurnStatus.new()
var _seal: SealStatus = SealStatus.new()

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _collider: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	deactivate()


func is_boss() -> bool:
	return behaviour == BEHAVIOUR_BOSS


## Re-arms a pooled instance from monster data. Safe to call repeatedly.
func activate(new_monster_id: String, data: Dictionary, spawn_position: Vector2) -> void:
	monster_id = new_monster_id
	max_hp = maxf(float(data.get(KEY_HP, DEFAULT_HP)), 1.0)
	hp = max_hp
	contact_damage = maxf(float(data.get(KEY_DAMAGE, DEFAULT_DAMAGE)), 0.0)
	move_speed = maxf(float(data.get(KEY_SPEED, DEFAULT_SPEED)), 0.0)
	behaviour = String(data.get(KEY_BEHAVIOUR, BEHAVIOUR_CHASE))
	xp_drop = maxi(int(data.get(KEY_XP_DROP, 0)), 0)
	gold_drop = maxi(int(data.get(KEY_GOLD_DROP, 0)), 0)

	global_position = spawn_position
	velocity = Vector2.ZERO
	_attack_cooldown_left = RANGED_COOLDOWN_SEC
	_is_dashing = false
	_charge_phase_left = CHARGER_WINDUP_SEC
	_weave_phase = _rng.randf() * TAU
	_hit_flash_left = 0.0
	# Pooled instance: a burn or seal from the previous life must not carry over.
	_burn = BurnStatus.new()
	_seal = SealStatus.new()

	_apply_visuals(data)
	_apply_collision(data)
	_set_enabled(true)


func deactivate() -> void:
	var was_active: bool = is_active
	_set_enabled(false)
	if was_active:
		despawned.emit(self)


func apply_burn(dps: float, duration_sec: float) -> void:
	if not is_active:
		return
	_burn.apply(dps, duration_sec)


## One seal mark; bursts through take_damage at the data-declared threshold so
## a burst kill pays out exactly like a weapon kill.
func apply_seal(burst_at: int, burst_damage: float) -> void:
	if not is_active or burst_damage <= 0.0:
		return
	if _seal.apply(burst_at):
		EffectPool.play(EffectPool.HIT, global_position)
		take_damage(burst_damage)


func take_damage(amount: float, _is_crit: bool = false) -> void:
	if not is_active or amount <= 0.0:
		return
	hp -= amount
	CombatAudio.play_hit()
	# No impact burst here: the damage source plays it, because only the
	# source knows which weapon landed and therefore which paired art to
	# use. Emitting from both stacked two bright cores on one hit.
	_hit_flash_left = HIT_FLASH_SEC
	if _sprite != null:
		_sprite.modulate = HIT_FLASH_TINT
	if hp > 0.0:
		return
	_die()


func _physics_process(delta: float) -> void:
	if not is_active:
		return
	_tick_hit_flash(delta)
	# Through take_damage, not hp directly, so a burn kill pays out drops and
	# counters exactly like a weapon kill.
	var burn_damage: float = _burn.advance(delta)
	if burn_damage > 0.0:
		take_damage(burn_damage)
		if not is_active:
			return
	var target: Node2D = get_tree().get_first_node_in_group(PLAYER_GROUP) as Node2D
	if target == null:
		velocity = Vector2.ZERO
		return
	match behaviour:
		BEHAVIOUR_RANGED:
			_act_ranged(target, delta)
		BEHAVIOUR_CHARGER:
			_act_charger(target, delta)
		BEHAVIOUR_SWARM:
			_act_swarm(target, delta)
		BEHAVIOUR_BOSS:
			_act_boss(target, delta)
		_:
			_act_chase(target)
	move_and_slide()
	_advance_bob(delta)


## Bobs the sprite while moving. Stopping, being hit-stunned or dying resets the
## offset to zero, so it can never leak into collision placement or fight the
## death sequence for the sprite.
func _advance_bob(delta: float) -> void:
	if _sprite == null:
		return
	var moving: bool = velocity.length_squared() > 0.0 and is_active and _hit_flash_left <= 0.0
	if not moving:
		_bob_time = 0.0
		_sprite.position = Vector2.ZERO
		return
	_bob_time += delta
	_sprite.position = Vector2(CharacterMotion.walk_offset(_bob_time))


func _act_chase(target: Node2D) -> void:
	velocity = _direction_to(target) * move_speed


func _act_swarm(target: Node2D, delta: float) -> void:
	_weave_phase += delta * SWARM_WEAVE_HZ
	var forward: Vector2 = _direction_to(target)
	var weave: Vector2 = forward.orthogonal() * sin(_weave_phase) * SWARM_WEAVE_STRENGTH
	velocity = (forward + weave).normalized() * move_speed


func _act_ranged(target: Node2D, delta: float) -> void:
	var to_target: Vector2 = target.global_position - global_position
	var distance: float = to_target.length()
	var forward: Vector2 = to_target.normalized()
	if distance > RANGED_PREFERRED_PX + RANGED_HYSTERESIS_PX:
		velocity = forward * move_speed
	elif distance < RANGED_PREFERRED_PX - RANGED_HYSTERESIS_PX:
		velocity = -forward * move_speed
	else:
		velocity = Vector2.ZERO
	_attack_cooldown_left -= delta
	if _attack_cooldown_left > 0.0:
		return
	_attack_cooldown_left = RANGED_COOLDOWN_SEC
	_shoot(forward)


## Windup (stand still and telegraph) then a straight dash along the direction
## locked in at the end of the windup.
func _act_charger(target: Node2D, delta: float) -> void:
	_charge_phase_left -= delta
	if _is_dashing:
		velocity = _charge_direction * move_speed * CHARGER_DASH_MULTIPLIER
		if _charge_phase_left <= 0.0:
			_is_dashing = false
			_charge_phase_left = CHARGER_RECOVER_SEC
		return
	velocity = Vector2.ZERO
	if _charge_phase_left > 0.0:
		return
	_charge_direction = _direction_to(target)
	_is_dashing = true
	_charge_phase_left = CHARGER_DASH_SEC


func _act_boss(target: Node2D, delta: float) -> void:
	velocity = _direction_to(target) * move_speed * BOSS_SPEED_SCALE
	_attack_cooldown_left -= delta
	if _attack_cooldown_left > 0.0:
		return
	_attack_cooldown_left = BOSS_BURST_SEC
	for index in BOSS_BURST_PROJECTILES:
		_shoot(Vector2.RIGHT.rotated(TAU * float(index) / float(BOSS_BURST_PROJECTILES)))


func _shoot(direction: Vector2) -> void:
	var root: Node = get_tree().get_first_node_in_group(PROJECTILE_ROOT_GROUP)
	if root == null:
		root = get_tree().current_scene
	if root == null:
		return
	var shot := Projectile.new()
	shot.damage = contact_damage
	shot.speed = RANGED_PROJECTILE_SPEED
	shot.lifetime_sec = RANGED_PROJECTILE_LIFETIME_SEC
	shot.direction = direction.normalized()
	shot.tint = BOSS_TINT if is_boss() else PLACEHOLDER_TINT
	shot.global_position = global_position
	shot.configure_for_enemy()
	root.add_child(shot)


func _die() -> void:
	hp = 0.0
	CombatAudio.play_enemy_death()
	# The corpse is played by the pool, so the enemy instance can return to
	# its own pool immediately instead of lingering as a live node.
	EffectPool.play_monster_death(monster_id, global_position)
	EventBus.enemy_killed.emit(monster_id, global_position)
	EventBus.stat_recorded.emit("enemy_killed", 1)
	deactivate()


func _direction_to(target: Node2D) -> Vector2:
	var offset: Vector2 = target.global_position - global_position
	return offset.normalized() if offset.length_squared() > 0.0 else Vector2.ZERO


func _tick_hit_flash(delta: float) -> void:
	if _hit_flash_left <= 0.0:
		return
	_hit_flash_left = maxf(_hit_flash_left - delta, 0.0)
	if _hit_flash_left <= 0.0 and _sprite != null:
		_sprite.modulate = Color.WHITE


func _apply_visuals(data: Dictionary) -> void:
	if _sprite == null:
		return
	var tint: Color = BOSS_TINT if is_boss() else PLACEHOLDER_TINT
	_sprite.texture = PlaceholderArt.texture_or_placeholder(String(data.get(KEY_SPRITE, "")), tint)
	_sprite.modulate = Color.WHITE


## Hit size comes from data, not from a root scale.
##
## The boss used to get its size from scale = 2.2 on the root, which also scaled
## the collision circle to ~17.6px as a side effect. With the root no longer
## scaled the shape has to be sized explicitly, and monsters.json already ships
## collision_radius for every monster. Pooled instances share the scene's shape
## resource, so it is duplicated per enemy before being resized.
func _apply_collision(data: Dictionary) -> void:
	if _collider == null:
		return
	var radius: float = float(data.get(KEY_COLLISION_RADIUS, 0.0))
	if radius <= 0.0:
		return
	var circle: CircleShape2D = _collider.shape as CircleShape2D
	if circle == null or circle.radius == radius:
		return
	circle = circle.duplicate() as CircleShape2D
	circle.radius = radius
	_collider.shape = circle


func _set_enabled(enabled: bool) -> void:
	is_active = enabled
	_bob_time = 0.0
	if _sprite != null:
		_sprite.position = Vector2.ZERO
	visible = enabled
	set_physics_process(enabled)
	if _collider != null:
		_collider.set_deferred(&"disabled", not enabled)
	if enabled:
		add_to_group(ENEMY_GROUP)
	elif is_in_group(ENEMY_GROUP):
		remove_from_group(ENEMY_GROUP)
