extends Node
## First-boot guide dialogue check (N9-4): opens the real GuideDialog with
## Ftue.GUIDE_PAGES, screenshots page 1, advances through every page and
## asserts `finished` fires exactly after the last one. Run:
##   godot --path . res://tools/guide_check.tscn

const SHOT_PATH := "user://guide_check.png"

var _finished_count: int = 0


func _ready() -> void:
	var guide := GuideDialog.new()
	add_child(guide)
	guide.finished.connect(func() -> void: _finished_count += 1)
	guide.open(Ftue.GUIDE_PAGES)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(SHOT_PATH)
	print("GUIDE shot: " + ProjectSettings.globalize_path(SHOT_PATH))

	var button: Button = guide.get_node("Blocker/Panel/Row/Column/ButtonRow/NextButton")
	for i: int in range(Ftue.GUIDE_PAGES.size() - 1):
		button.pressed.emit()
		if _finished_count != 0:
			push_error("FAIL guide_check: finished fired early at page %d" % (i + 1))
			get_tree().quit(0)
			return
	button.pressed.emit()
	if _finished_count == 1 and not guide.visible:
		print("PASS guide_check: %d pages advanced, finished fired once" % Ftue.GUIDE_PAGES.size())
	else:
		push_error("FAIL guide_check: finished=%d visible=%s" % [_finished_count, guide.visible])
	get_tree().quit(0)
