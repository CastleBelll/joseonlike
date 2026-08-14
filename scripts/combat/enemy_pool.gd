class_name EnemyPool
extends RefCounted
## Minimal enemy reuse (N3-4): released enemies are hidden and parked instead
## of freed, so waves never instance per spawn after warm-up.

var _parent: Node
var _free: Array[Enemy] = []


func _init(parent: Node) -> void:
	_parent = parent


func acquire() -> Enemy:
	var enemy: Enemy = _free.pop_back() if not _free.is_empty() else _create()
	enemy.visible = true
	enemy.set_physics_process(true)
	enemy.process_mode = Node.PROCESS_MODE_INHERIT
	return enemy


func release(enemy: Enemy) -> void:
	enemy.visible = false
	enemy.set_physics_process(false)
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	_free.append(enemy)


func _create() -> Enemy:
	var enemy := Enemy.new()
	_parent.add_child(enemy)
	return enemy
