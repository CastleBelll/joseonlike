extends Node
## Single place that knows scene paths, so gameplay code never hardcodes them.
##
## Frozen contract: ARCHITECTURE.md section 3.5.
##
## The camp, character-select, results, and stage scenes are built by the
## meta-ui and combat worktrees. Until they land, routing to them reports the
## missing path and leaves the current scene running rather than crashing.

const CAMP_SCENE := "res://scenes/basecamp/camp.tscn"
const CHARACTER_SELECT_SCENE := "res://scenes/ui/character_select.tscn"
const STAGE_SCENE := "res://scenes/combat/stage.tscn"
const RESULTS_SCENE := "res://scenes/ui/results.tscn"

## Payload for the results screen. change_scene_to_file() cannot pass arguments,
## so the results controller reads it from here on _ready.
var last_result: Dictionary = {}


func goto_camp() -> void:
	_goto(CAMP_SCENE)


func goto_character_select() -> void:
	_goto(CHARACTER_SELECT_SCENE)


func goto_stage(stage_id: String) -> void:
	if GameData.stage(stage_id).is_empty():
		# GameData already reported the unknown id; do not double-log it.
		return
	_goto(STAGE_SCENE)


func goto_results(result: Dictionary) -> void:
	last_result = result.duplicate(true)
	_goto(RESULTS_SCENE)


func _goto(scene_path: String) -> void:
	if not ResourceLoader.exists(scene_path):
		push_error("SceneRouter: no scene at %s; staying on the current scene" % scene_path)
		return

	if get_tree() == null:
		push_error("SceneRouter: not inside a scene tree; cannot route to %s" % scene_path)
		return

	# Deferred so a caller can route from _ready() without the tree freeing the
	# scene that is still mid-initialisation.
	_change_scene_deferred.call_deferred(scene_path)


func _change_scene_deferred(scene_path: String) -> void:
	var tree := get_tree()
	if tree == null:
		push_error("SceneRouter: scene tree went away before routing to %s" % scene_path)
		return

	var change_error: Error = tree.change_scene_to_file(scene_path)
	if change_error != OK:
		push_error("SceneRouter: failed to change to %s (error %d)" % [scene_path, change_error])
