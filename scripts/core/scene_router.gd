extends Node
## Single place that knows scene paths, so gameplay code never hardcodes them.
##
## STUB — owned by the core-engine worktree. Signatures frozen, see
## ARCHITECTURE.md section 3.5.

func goto_camp() -> void:
	_not_ready("camp")


func goto_character_select() -> void:
	_not_ready("character_select")


func goto_stage(stage_id: String) -> void:
	_not_ready("stage:%s" % stage_id)


func goto_results(result: Dictionary) -> void:
	_not_ready("results")


func _not_ready(destination: String) -> void:
	push_warning("SceneRouter cannot route to %s yet" % destination)
