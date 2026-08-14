class_name AutoWeapon
extends Node2D
## Data-driven auto-attack (N3-3): every cooldown_sec, fire one straight
## projectile at the nearest live enemy within the view-radius firing range.
## All balance numbers come from data/weapons.json.

signal hit_landed(amount: float, at: Vector2, boss_hit: bool)

const WEAPONS_PATH := "res://data/weapons.json"
## Cooldown can shrink per level and per attack-speed stacks; never let it
## reach zero or the weapon would fire every frame.
const MIN_COOLDOWN_SEC := 0.05
## N4-1: modded weapons tint their projectile so the transformation is
## visible on the field; anything unlisted keeps the plain talisman paper.
const TINTS: Dictionary = {
	"fire_talisman": UiPalette.WEAPON_FIRE,
	"phoenix_talisman": UiPalette.WEAPON_FIRE,
	"lightning_talisman": UiPalette.WEAPON_LIGHTNING,
	"beopgeom": UiPalette.WEAPON_SEAL,
}

var weapon_id: String = ""

var _stats: Dictionary = {}
var _level: int = 1
var _grade: String = ""
var _grades: Dictionary = {}
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
	_grades = WeaponGrade.config(weapons)
	_grade = String(_stats.get("grade", ""))
	_speed = float(_stats.get("speed", 0.0))
	_recompute()


## N3-6 level-up: weapon level drives the per_level curve from weapons.json.
func set_level(level: int) -> void:
	_level = level
	_recompute()


## N4-2 grade raise: the run grade compounds the data-driven step factors on
## top of the level curve.
func set_grade(grade: String) -> void:
	_grade = grade
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
	_damage = WeaponGrade.stat_at(_stats, "damage", _level, _grade, _grades) * _damage_scale
	_cooldown = maxf(
		WeaponGrade.stat_at(_stats, "cooldown_sec", _level, _grade, _grades) * _cooldown_scale,
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
		_player.global_position, direction, _speed, _damage, _spawner, _player, _tint()
	)
	return true


## Weapon-id tint by default; a grade step flagged "tinted" (N4-2) recolors
## the projectile with the run grade's tier color so the raise reads on field.
func _tint() -> Color:
	if WeaponGrade.has_flag(_grades, String(_stats.get("grade", "")), _grade, "tinted"):
		return Loot.TIER_COLORS.get(_grade, UiPalette.PAPER)
	return TINTS.get(weapon_id, UiPalette.PAPER)


func _create_projectile() -> Projectile:
	var projectile := Projectile.new()
	projectile.hit_landed.connect(
		func(amount: float, at: Vector2, boss_hit: bool) -> void:
			hit_landed.emit(amount, at, boss_hit)
	)
	projectile.finished.connect(_on_projectile_finished)
	return projectile


func _on_projectile_finished(projectile: Projectile) -> void:
	_pool.release(projectile)
