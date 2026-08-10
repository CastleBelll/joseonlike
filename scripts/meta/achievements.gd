extends Node
## Achievement counter tracker. Autoloaded so it observes EventBus.stat_recorded
## for the whole app lifetime, including stage runs outside the camp scene.
##
## STUB — owned by the meta-ui worktree, which implements counting, unlocking,
## and exactly-once reward granting on top of SaveManager.

func _ready() -> void:
	EventBus.stat_recorded.connect(_on_stat_recorded)


func _on_stat_recorded(key: String, amount: int) -> void:
	pass
