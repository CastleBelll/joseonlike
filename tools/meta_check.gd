extends Node
## 명부수 screen layout check (N7-1): loads the meta tree scene with a
## returning profile injected in memory (some ranks owned, gold to spend,
## nothing written to disk), selects a node, screenshots it, and quits.
## Run: godot --path . res://tools/meta_check.tscn

const SHOT_PATH := "user://meta_check.png"
const BRANCH_SHOT_PATH := "user://meta_check_branch.png"
## N11-18 rewired the tree; these are current ids.
const SELECTED_NODE := "coin_eye"
## N7-2: second shot on the taoist branch tab, mid-branch node selected.
const BRANCH_NODE := "chain_reach"


func _ready() -> void:
	if SaveService.instance != null:
		# In-memory only — the write lock guarantees no disk pollution.
		var profile: Dictionary = SaveProfile.apply_run_result(
			SaveProfile.default_profile(), 287.0, 132, 875, true
		)
		# N11-24: "--full" grants every node one rank, so the capture shows the
		# map a long-running profile actually sees — the reveal rule keeps a
		# fresh profile down to a handful of discs, which hides the layout.
		var full: bool = "--full" in OS.get_cmdline_user_args()
		if full:
			var tree: Dictionary = MetaTree.load_tree()
			var granted: Dictionary = {}
			for entry: Variant in MetaTree.nodes(tree):
				granted[String((entry as Dictionary)["id"])] = 1
			profile["meta_tree"] = granted
			profile["unlocks"] = ["warrior", "archer"]
		else:
			profile["meta_tree"] = {"coin_eye": 2, "luck_seed": 1, "skill_power": 1}
		SaveService.instance.profile = profile
		SaveService.instance._write_locked = true
		SaveService.instance._write_lock_reason = "a harness is using a throwaway profile"
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
	# N11-14: the branches GROW for GROW_SEC when a tab opens, so a two-frame
	# capture photographed the animation instead of the layout.
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("META shot: " + ProjectSettings.globalize_path(path))
