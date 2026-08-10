extends Node
## Entry point: load content, load the profile, then hand control to the title
## screen, where the GDD flow starts. The title's Start button routes onward to
## the camp.
##
## Content is a hard dependency — routing onward with empty data would produce
## silently broken menus, so a load failure stops here and says so.

## Shown on screen when content is unusable. English on purpose: the localised
## strings live in data/, which is exactly what failed to load.
const LOAD_FAILURE_TEXT := "Content load failed (error %d).\nCheck res://data/*.json and the log."

@onready var _error_label: Label = $ErrorLabel


func _ready() -> void:
	_error_label.visible = false

	var load_result: Error = GameData.load_all()
	if load_result != OK:
		_show_load_failure(load_result)
		return

	SaveManager.load_profile()
	SceneRouter.goto_title()


func _show_load_failure(load_result: Error) -> void:
	push_error("Boot: content load failed with error %d; staying on the boot screen" % load_result)
	_error_label.text = LOAD_FAILURE_TEXT % load_result
	_error_label.visible = true
