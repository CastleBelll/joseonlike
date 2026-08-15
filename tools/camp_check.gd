extends Node
## Camp screen layout check (N5-3): loads the camp scene with a returning
## profile injected in memory (nothing written to disk), screenshots it, and
## quits. Run: godot --path . res://tools/camp_check.tscn

const SHOT_PATH := "user://camp_check.png"


func _ready() -> void:
	if SaveService.instance != null:
		# In-memory only — save_profile() is never called here.
		var profile: Dictionary = SaveProfile.apply_run_result(
			SaveProfile.default_profile(), 287.0, 132, 875, true
		)
		# N5-4: one unseen discovery so the shot proves the camp hint line.
		profile = Bestiary.record_discovery(
			profile, Bestiary.KIND_MONSTERS, "forest_goblin"
		)["profile"]
		SaveService.instance.profile = profile
	var camp: Control = (load("res://scenes/camp.tscn") as PackedScene).instantiate()
	add_child(camp)
	_capture()


func _capture() -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(SHOT_PATH)
	print("CAMP shot: " + ProjectSettings.globalize_path(SHOT_PATH))
	get_tree().quit(0)
