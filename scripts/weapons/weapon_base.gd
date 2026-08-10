class_name WeaponBase
extends Node2D
## Base class for every auto-firing weapon.
##
## Combat is automatic (GDD section 6): the base owns the cooldown clock and the
## stat lookups, subclasses only implement _fire(). Every number comes from
## GameData.weapon(id) plus RunState passive totals — nothing is balanced here.

const PLAYER_GROUP: StringName = &"player"
const ENEMY_GROUP: StringName = &"enemy"
## Weapons parent their spawned nodes here so projectiles outlive the swing and
## do not inherit the player's transform.
const PROJECTILE_ROOT_GROUP: StringName = &"projectile_root"

## Gameplay VFX is named by weapon id (asset/M1_ASSET_REPORT.md), so the path
## is derived rather than configured; a missing file falls back to the
## placeholder instead of blocking on art.
const VFX_PATH: String = "res://asset/weapon/projectiles/%s.png"

const STAT_ATTACK_DAMAGE: String = "attack_damage"
const STAT_ATTACK_SPEED: String = "attack_speed"
const STAT_CRIT_CHANCE: String = "crit_chance"
const STAT_SKILL_POWER: String = "skill_power"

signal fired(weapon_id: String)
var weapon_id: String = ""
var level: int = CombatMath.MIN_LEVEL

var _data: Dictionary = {}
var _cooldown_left: float = 0.0
var _rng: RandomNumberGenerator = null


func _ready() -> void:
	_rng = CombatRng.create()
	set_process(not _data.is_empty())


func setup(id: String, start_level: int = CombatMath.MIN_LEVEL) -> void:
	weapon_id = id
	level = CombatMath.clamp_level(start_level)
	_data = GameData.weapon(id)
	if _data.is_empty():
		push_warning("WeaponBase: no data for weapon '%s', it will not fire" % id)
	# Stagger the first shot by a full cooldown so weapons do not all fire on frame one.
	_cooldown_left = current_cooldown()
	set_process(not _data.is_empty())


func data() -> Dictionary:
	return _data


func set_level(new_level: int) -> void:
	var clamped: int = clampi(new_level, CombatMath.MIN_LEVEL, CombatMath.max_level(_data))
	if clamped == level:
		return
	level = clamped


func current_cooldown() -> float:
	return CombatMath.cooldown_at_level(_data, level, _stat(STAT_ATTACK_SPEED))


func roll_hit() -> Dictionary:
	return CombatMath.resolve_hit(
		_data,
		level,
		_stat(STAT_ATTACK_DAMAGE),
		_stat(STAT_SKILL_POWER),
		_stat(STAT_CRIT_CHANCE),
		_rng.randf()
	)


func projectile_count() -> int:
	return CombatMath.projectile_count_at_level(_data, level)


func pierce() -> int:
	return CombatMath.pierce_at_level(_data, level)


func area_scale() -> float:
	return CombatMath.area_scale_at_level(_data, level)


func projectile_speed() -> float:
	return CombatMath.projectile_speed_at_level(_data, level)


func _process(delta: float) -> void:
	if _data.is_empty():
		return
	_cooldown_left -= delta
	if _cooldown_left > 0.0:
		return
	_cooldown_left = current_cooldown()
	if not _fire():
		return
	fired.emit(weapon_id)


## Subclass hook. Returns true when a shot actually went out, so weapons that
## need a target do not report firing at nothing.
func _fire() -> bool:
	push_error("WeaponBase._fire must be overridden by %s" % get_script().resource_path)
	return false


## Aggregated passive value for the live run. Kept in one place so weapons never
## reach into RunState from a dozen call sites.
func _stat(key: String) -> float:
	return RunState.stat_total(key)


## Authored art for this weapon, or null when none is shipped for the id.
func vfx_texture() -> Texture2D:
	var path: String = VFX_PATH % weapon_id
	if weapon_id.is_empty() or not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as Texture2D


func player() -> Node2D:
	return get_tree().get_first_node_in_group(PLAYER_GROUP) as Node2D


func facing() -> Vector2:
	var owner_node: Node2D = player()
	if owner_node == null or not (owner_node.get(&"facing") is Vector2):
		return Vector2.RIGHT
	return owner_node.get(&"facing")


func enemies() -> Array[Node]:
	return get_tree().get_nodes_in_group(ENEMY_GROUP)


func nearest_enemy() -> Node2D:
	var candidates: Array[Node] = enemies()
	var positions := PackedVector2Array()
	for candidate in candidates:
		var node2d: Node2D = candidate as Node2D
		positions.append(node2d.global_position if node2d != null else Vector2.INF)
	var index: int = CombatMath.nearest_index(global_position, positions)
	if index < 0:
		return null
	return candidates[index] as Node2D


## Parent for spawned hitboxes. Falls back to the current scene so a weapon still
## works in a scratch scene that has no dedicated projectile root.
func spawn_root() -> Node:
	var root: Node = get_tree().get_first_node_in_group(PROJECTILE_ROOT_GROUP)
	if root != null:
		return root
	return get_tree().current_scene if get_tree().current_scene != null else get_tree().root
