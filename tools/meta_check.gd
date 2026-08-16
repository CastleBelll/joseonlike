extends Node
## 명부수 screen layout check (N7-1): loads the meta tree scene with a
## returning profile injected in memory (some ranks owned, gold to spend,
## nothing written to disk), selects a node, screenshots it, and quits.
## Run: godot --path . res://tools/meta_check.tscn

const SHOT_PATH := "user://meta_check.png"
const BRANCH_SHOT_PATH := "user://meta_check_branch.png"
const SELECTED_NODE := "sharp_talisman"
## N7-2: second shot on the taoist branch tab, mid-branch node selected.
const BRANCH_NODE := "chain_reach"


func _ready() -> void:
	if SaveService.instance != null:
		# In-memory only — the write lock guarantees no disk pollution.
		var profile: Dictionary = SaveProfile.apply_run_result(
			SaveProfile.default_profile(), 287.0, 132, 875, true
		)
		profile["meta_tree"] = {"iron_bones": 2, "wind_steps": 1, "burn_mastery": 1}
		SaveService.instance.profile = profile
		SaveService.instance._write_locked = true
	var screen: MetaTreeScreen = (
		load("res://scenes/meta_tree.tscn") as PackedScene
	).instantiate()
	add_child(screen)
	screen.select_node(SELECTED_NODE)
	await _capture(SHOT_PATH)
	screen.select_node(BRANCH_NODE)
	await _capture(BRANCH_SHOT_PATH)
	get_tree().quit(0)


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("META shot: " + ProjectSettings.globalize_path(path))
