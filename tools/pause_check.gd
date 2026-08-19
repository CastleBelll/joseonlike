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
			# N9-25 character sheet, in the shape Stage._pause_build_summary
			# actually produces: a mix of moved and untouched lines so the
			# highlight rule is visible in the shot, and the full 12-line count
			# so the panel is measured at its tallest.
			"stats": [
				{"name": "체력", "value": "118/150", "modified": false},
				{"name": "이동 속도", "value": "104", "modified": true},
				{"name": "공격력", "value": "118%", "modified": true},
				{"name": "공격 속도", "value": "100%", "modified": false},
				{"name": "치명타 확률", "value": "15%", "modified": true},
				{"name": "치명타 피해", "value": "x2.3", "modified": true},
				{"name": "투사체", "value": "+1", "modified": true},
				{"name": "투사체 속도", "value": "100%", "modified": false},
				{"name": "피해 감소", "value": "0%", "modified": false},
				{"name": "자석 범위", "value": "100%", "modified": false},
				{"name": "경험치 획득", "value": "125%", "modified": true},
				{"name": "행운", "value": "+20%", "modified": true},
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
	var stats: GridContainer = hud.get_node_or_null(
		"PauseOverlay/PaperPanel/Pad/Layout/BuildSummary/StatLines/StatGrid"
	)
	# The panel must also still fit the 960px screen at this worst case; a
	# summary that renders every row but runs off the bottom is not a pass.
	var panel: Control = hud.get_node_or_null("PauseOverlay/PaperPanel")
	var fits: bool = panel != null and panel.size.y <= hud.size.y
	if grid != null and grid.get_child_count() == 6 \
			and passives != null and passives.get_child_count() == 5 \
			and stats != null and stats.get_child_count() == 12 and fits:
		print("PASS pause_check: 6 weapons + 5 passives + 12 stat lines, panel %.0fpx" % panel.size.y)
	else:
		push_error("FAIL pause_check: build summary rows missing or panel overflows")
	get_tree().paused = false
	get_tree().quit(0)
