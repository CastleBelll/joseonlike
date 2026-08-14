class_name AutoWeapon
extends Node2D
## Data-driven auto-attack (N3-3): every cooldown_sec, fire one straight
## projectile at the nearest live enemy within the view-radius firing range.
## All balance numbers come from data/weapons.json.

signal hit_landed(amount: float, at: Vector2)

const WEAPONS_PATH := "res://data/weapons.json"
## Cooldown can shrink per level and per attack-speed stacks; never let it
## reach zero or the weapon would fire every frame.
const MIN_COOLDOWN_SEC := 0.05

var weapon_id: String = ""

var _stats: Dictionary = {}
var _level: int = 1
var _damage_scale: float = 1.0
var _cooldown_scale: float = 1.0
var _damage: float = 0.0
var _cooldown: float = 0.0
var _speed: float = 0.0
var _cooldown_left: float = 0.0
var _player: Player
var _spawner: Spawner
var _pool: NodePool


func setup(id: String, player: Player, spawner: Spawner) -> void:
	_player = player
	_spawner = spawner
	_pool = NodePool.new(self, _create_projectile)
	var weapons: Variant = JSON.parse_string(FileAccess.get_file_as_string(WEAPONS_PATH))
	if weapons is not Dictionary or not (weapons as Dictionary).has(id):
		push_error("auto_weapon: unknown weapon id '%s' in %s" % [id, WEAPONS_PATH])
		return
	weapon_id = id
	_stats = weapons[id]
	_speed = float(_stats.get("speed", 0.0))
	_recompute()


## N3-6 level-up: weapon level drives the per_level curve from weapons.json.
func set_level(level: int) -> void:
	_level = level
	_recompute()


## N3-6 passives: run-wide damage multiplier and cooldown multiplier
## (attack speed as 1 / (1 + bonus), computed by the stage).
func set_scales(damage_scale: float, cooldown_scale: float) -> void:
	_damage_scale = damage_scale
	_cooldown_scale = cooldown_scale
	_recompute()


func _recompute() -> void:
	if _stats.is_empty():
		return
	_damage = LevelUp.weapon_stat_at(_stats, "damage", _level) * _damage_scale
	_cooldown = maxf(
		LevelUp.weapon_stat_at(_stats, "cooldown_sec", _level) * _cooldown_scale,
		MIN_COOLDOWN_SEC
	)


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	_cooldown_left -= delta
	if _cooldown_left > 0.0:
		return
	if _try_fire():
		_cooldown_left = _cooldown  # no target keeps the shot ready, VS-style


func _try_fire() -> bool:
	var enemies: Array[Enemy] = _spawner.active_enemies()
	var positions: Array[Vector2] = []
	for enemy: Enemy in enemies:
		positions.append(enemy.global_position)
	var firing_range: float = get_viewport_rect().size.length() / 2.0
	var index: int = CombatMath.nearest_index(_player.global_position, positions, firing_range)
	if index < 0:
		return false
	var direction: Vector2 = CombatMath.chase_direction(
		_player.global_position, positions[index]
	)
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT  # enemy exactly on the player; any heading hits
	var projectile: Projectile = _pool.acquire()
	projectile.launch(
		_player.global_position, direction, _speed, _damage, _spawner, _player
	)
	return true


func _create_projectile() -> Projectile:
	var projectile := Projectile.new()
	projectile.hit_landed.connect(
		func(amount: float, at: Vector2) -> void: hit_landed.emit(amount, at)
	)
	projectile.finished.connect(_on_projectile_finished)
	return projectile


func _on_projectile_finished(projectile: Projectile) -> void:
	_pool.release(projectile)
