extends Node
## First-boot guide dialogue check (N9-4): opens the real GuideDialog with
## Ftue.GUIDE_PAGES, screenshots page 1, advances through every page and
## asserts `finished` fires exactly after the last one. Run:
##   godot --path . res://tools/guide_check.tscn

const SHOT_PATH := "user://guide_check.png"

var _finished_count: int = 0


## Runs the dialog's own _process long enough to clear a page's dwell.
func _drain_dwell(guide: GuideDialog, dwell_sec: float) -> void:
	if dwell_sec <= 0.0:
		return
	var waited: float = 0.0
	while waited <= dwell_sec + 0.1:
		await get_tree().process_frame
		waited += get_process_delta_time()


func _ready() -> void:
	var guide := GuideDialog.new()
	add_child(guide)
	guide.finished.connect(func() -> void: _finished_count += 1)
	guide.open(Ftue.GUIDE_PAGES)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(SHOT_PATH)
	print("GUIDE shot: " + ProjectSettings.globalize_path(SHOT_PATH))

	# N9-14: tap-through pages advance on the button; await pages hide it
	# and only advance when the matching action is reported.
	var button: Button = guide.get_node("Blocker/Panel/Row/Column/ButtonRow/NextButton")
	var awaits: Array[String] = []
	for i: int in range(Ftue.GUIDE_PAGES.size()):
		var await_action: String = String(Ftue.GUIDE_PAGES[i].get("await", ""))
		if await_action.is_empty():
			if not button.visible:
				push_error("FAIL guide_check: tap page %d hid its button" % i)
				get_tree().quit(0)
				return
			button.pressed.emit()
		else:
			awaits.append(await_action)
			if button.visible:
				push_error("FAIL guide_check: await page %d still shows its button" % i)
				get_tree().quit(0)
				return
			# A wrong action must not advance the page.
			guide.notify_action("wrong_action")
			if _finished_count != 0:
				push_error("FAIL guide_check: wrong action advanced the guide")
				get_tree().quit(0)
				return
			guide.notify_action(await_action)
			# N9-44 dwell: a page with "dwell_sec" holds after the action so the
			# blink or the burst is actually watched. The harness has to let
			# that time pass or it reads the NEXT page mid-hold.
			await _drain_dwell(guide, float(Ftue.GUIDE_PAGES[i].get("dwell_sec", 0.0)))
		if _finished_count != 0 and i < Ftue.GUIDE_PAGES.size() - 1:
			push_error("FAIL guide_check: finished fired early at page %d" % i)
			get_tree().quit(0)
			return
	if _finished_count == 1 and not guide.visible and awaits.size() >= 2:
		print("PASS guide_check: %d pages (%d interactive) advanced, finished once"
			% [Ftue.GUIDE_PAGES.size(), awaits.size()])
	else:
		push_error("FAIL guide_check: finished=%d visible=%s awaits=%d"
			% [_finished_count, guide.visible, awaits.size()])
	get_tree().quit(0)
