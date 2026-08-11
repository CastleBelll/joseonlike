extends Node
## Single place that knows scene paths, so gameplay code never hardcodes them.
##
## Frozen contract: ARCHITECTURE.md section 3.5.
##
## Every destination below is built by the meta-ui and combat worktrees. Until
## one lands, routing to it reports the missing path and leaves the current scene
## running rather than crashing.
##
## Pause is deliberately absent: it is an overlay owned by hud.gd, because
## changing scene would unload the run being paused.

## Boot's destination and the first screen of the GDD flow. Its Start button
## routes onward through goto_camp().
const TITLE_SCENE := "res://scenes/ui/title.tscn"
## Reached from the main menu; its Back button returns through goto_title().
const SETTINGS_SCENE := "res://scenes/ui/settings.tscn"
const CAMP_SCENE := "res://scenes/basecamp/camp.tscn"
## Entered from the camp's Archive building.
const ACHIEVEMENTS_QUESTS_SCENE := "res://scenes/ui/achievements_quests.tscn"
const CHARACTER_SELECT_SCENE := "res://scenes/ui/character_select.tscn"
## Sits between character select and the run: camp, then character, then area.
## RunState.begin happens after the area is chosen, so routing here carries no
## run state of its own.
const AREA_SELECT_SCENE := "res://scenes/ui/area_select.tscn"
const STAGE_SCENE := "res://scenes/combat/stage.tscn"
const RESULTS_SCENE := "res://scenes/ui/results.tscn"

## Payload for the results screen. change_scene_to_file() cannot pass arguments,
## so the results controller reads it from here on _ready.
var last_result: Dictionary = {}


func goto_title() -> void:
	_goto(TITLE_SCENE)


func goto_settings() -> void:
	_goto(SETTINGS_SCENE)


func goto_camp() -> void:
	_goto(CAMP_SCENE)


func goto_achievements_quests() -> void:
	_goto(ACHIEVEMENTS_QUESTS_SCENE)


func goto_character_select() -> void:
	_goto(CHARACTER_SELECT_SCENE)


func goto_area_select() -> void:
	_goto(AREA_SELECT_SCENE)


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
