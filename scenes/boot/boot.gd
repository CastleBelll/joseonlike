extends Node
## Entry point: load content, then hand control to the base camp.

func _ready() -> void:
	var load_result: Error = GameData.load_all()
	if load_result != OK:
		push_error("Content load failed with error %d; staying on boot screen" % load_result)
		return

	SaveManager.load_profile()
	SceneRouter.goto_camp()
