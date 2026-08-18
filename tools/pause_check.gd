extends Node
## Pause-overlay build summary check (N9-3e): builds the real CombatHud,
## installs a representative build_provider (6 weapons + 5 passives), opens
## the pause overlay and screenshots it. Run:
##   godot --path . res://tools/pause_check.tscn

const SHOT_PATH := "user://pause_check.png"


func _ready() -> void:
	var hud := CombatHud.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(hud)
	hud.build_provider = func() -> Dictionary:
		return {
			"weapons": [
				{"id": "old_talisman", "name": "낡은 부적", "level": 5},
				{"id": "noebu", "name": "뇌부", "level": 3},
				{"id": "gyeolgye", "name": "결계", "level": 4},
				{"id": "honbul", "name": "혼불", "level": 2},
				{"id": "seokjang", "name": "석장", "level": 6},
				{"id": "phoenix_talisman", "name": "봉황 부적", "level": 8},
			],
			"passives": [
				{"name": "공격력", "stacks": 3, "max": 5},
				{"name": "이동 속도", "stacks": 1, "max": 5},
				{"name": "최대 체력", "stacks": 2, "max": 5},
				{"name": "행운", "stacks": 4, "max": 5},
				{"name": "경험치 획득", "stacks": 5, "max": 5},
			],
			"evolutions": [
				"낡은 부적 → 뇌부 · 뇌정석 ✓",
				"낡은 부적 → 살 · 도깨비불 필요",
				"결계 → 화염 결계 · 화령석 필요",
			],
		}
	hud._on_pause_pressed()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(SHOT_PATH)
	print("PAUSE shot: " + ProjectSettings.globalize_path(SHOT_PATH))
	var grid: GridContainer = hud.get_node_or_null(
		"PauseOverlay/PaperPanel/Pad/Layout/BuildSummary/WeaponGrid"
	)
	var passives: GridContainer = hud.get_node_or_null(
		"PauseOverlay/PaperPanel/Pad/Layout/BuildSummary/PassiveGrid"
	)
	if grid != null and grid.get_child_count() == 6 \
			and passives != null and passives.get_child_count() == 5:
		print("PASS pause_check: 6 weapon cells + 5 passive lines rendered")
	else:
		push_error("FAIL pause_check: build summary rows missing")
	get_tree().paused = false
	get_tree().quit(0)
