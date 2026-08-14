class_name NodePool
extends RefCounted
## Generic hide-and-park reuse for the N3-3/N3-5 combat nodes (projectiles,
## XP orbs, damage numbers) — same contract as EnemyPool, but factory-driven
## so one class serves every pooled type without inheritance.

var _parent: Node
var _factory: Callable  # () -> CanvasItem
var _free: Array[CanvasItem] = []


func _init(parent: Node, factory: Callable) -> void:
	_parent = parent
	_factory = factory


func acquire() -> CanvasItem:
	var node: CanvasItem = _free.pop_back() if not _free.is_empty() else _create()
	node.visible = true
	node.process_mode = Node.PROCESS_MODE_INHERIT
	return node


func release(node: CanvasItem) -> void:
	node.visible = false
	node.process_mode = Node.PROCESS_MODE_DISABLED
	_free.append(node)


func _create() -> CanvasItem:
	var node: CanvasItem = _factory.call()
	_parent.add_child(node)
	return node
