extends Node
## Daily and story quest tracker. Autoloaded for the same reason as
## AchievementTracker: quest counters advance during stage runs.
##
## STUB — owned by the meta-ui worktree.

func _ready() -> void:
	EventBus.stat_recorded.connect(_on_stat_recorded)


func _on_stat_recorded(key: String, amount: int) -> void:
	pass
