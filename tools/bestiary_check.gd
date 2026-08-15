extends Node
## 괴이록 screen layout check (N5-4): loads the bestiary scene with a mixed
## in-memory record (some discovered, the rest ???) and screenshots each tab.
## unseen stays 0 so mark_bestiary_seen never writes the injected profile to
## disk. Run: godot --path . res://tools/bestiary_check.tscn

const SHOT_DIR := "user://"


func _ready() -> void:
	if SaveService.instance != null:
		# In-memory only — nothing is persisted (unseen 0 → no seen-write).
		var profile: Dictionary = SaveProfile.default_profile()
		profile["bestiary"] = {
			"monsters": ["forest_goblin", "bamboo_brute"],
			"loot": ["talisman_paper", "dokkaebi_flame", "bamboo"],
			"weapons": ["old_talisman", "hwabu", "hwaryeongbu"],
			"unseen": 0,
		}
		SaveService.instance.profile = profile
	var screen: BestiaryScreen = (
		load("res://scenes/bestiary.tscn") as PackedScene
	).instantiate()
	add_child(screen)
	await _capture("bestiary_check_monsters.png")
	screen._on_tab_pressed(Bestiary.KIND_LOOT)
	await _capture("bestiary_check_loot.png")
	screen._on_tab_pressed(Bestiary.KIND_WEAPONS)
	await _capture("bestiary_check_weapons.png")
	get_tree().quit(0)


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var path: String = SHOT_DIR + file_name
	get_viewport().get_texture().get_image().save_png(path)
	print("BESTIARY shot: " + ProjectSettings.globalize_path(path))
