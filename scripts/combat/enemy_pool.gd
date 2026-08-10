class_name EnemyPool
extends Node
## Fixed-size recycling pool for enemies.
##
## A stage spawns hundreds of monsters per minute; instantiating and freeing a
## scene per monster is the fastest way to lose 60fps on a mid-range Android
## device. Instances are created once, then re-armed via Enemy.activate().

## Hard ceiling on live monsters. Waves that would exceed it are dropped rather
## than queued, so a stalled player cannot build an unbounded backlog.
const MAX_CONCURRENT_ENEMIES: int = 200
## Allocated up front to keep the first minute free of instantiation spikes.
const PREWARM_COUNT: int = 48

var _scene: PackedScene = null
var _container: Node = null
var _idle: Array[Enemy] = []
var _active_count: int = 0
var _created_count: int = 0


func setup(enemy_scene: PackedScene, container: Node) -> void:
	_scene = enemy_scene
	_container = container
	if _scene == null or _container == null:
		push_error("EnemyPool.setup requires both an enemy scene and a container")
		return
	for _index in PREWARM_COUNT:
		var enemy: Enemy = _instantiate()
		if enemy == null:
			return
		_idle.append(enemy)


func active_count() -> int:
	return _active_count


func has_capacity() -> bool:
	return _active_count < MAX_CONCURRENT_ENEMIES


## Returns a live enemy, or null when the pool is at its cap or misconfigured.
func acquire(monster_id: String, data: Dictionary, spawn_position: Vector2) -> Enemy:
	if not has_capacity():
		return null
	var enemy: Enemy = _idle.pop_back() if not _idle.is_empty() else _instantiate()
	if enemy == null:
		return null
	_active_count += 1
	enemy.activate(monster_id, data, spawn_position)
	return enemy


## Deactivates every live enemy, e.g. when the run ends.
func release_all() -> void:
	if _container == null:
		return
	for child in _container.get_children():
		var enemy: Enemy = child as Enemy
		if enemy != null and enemy.is_active:
			enemy.deactivate()


func _instantiate() -> Enemy:
	if _scene == null or _container == null:
		return null
	var enemy: Enemy = _scene.instantiate() as Enemy
	if enemy == null:
		push_error("EnemyPool: scene does not extend Enemy")
		return null
	_created_count += 1
	enemy.name = "Enemy_%d" % _created_count
	enemy.despawned.connect(_on_enemy_despawned)
	_container.add_child(enemy)
	return enemy


func _on_enemy_despawned(enemy: Enemy) -> void:
	_active_count = maxi(_active_count - 1, 0)
	if not _idle.has(enemy):
		_idle.append(enemy)
