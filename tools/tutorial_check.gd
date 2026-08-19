extends Node
## N9-36 evidence harness: walks the first-run guide page by page and asserts
## the world is held for exactly as long as the script says it is.
##
## This exists because the bug it guards was invisible to every other check.
## The guide "worked" — pages advanced, tests passed — while the opening rush
## and the auto-attack both ran underneath the lesson about walking. Only a
## probe that reads the spawner and the weapons WHILE a given page is up can
## tell a staged tutorial from a narrated ambush.
## Run (rendered, for the screenshots): godot --path . res://tools/tutorial_check.tscn

const STAGE_SCENE := "res://scenes/stage.tscn"
const SETTLE_FRAMES := 6
const FRAMES_PER_PAGE := 10

var _stage: Stage
var _spawner: Spawner
var _guide: GuideDialog
var _step: int = 0
var _page: int = -1
var _failed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# A fresh profile is what puts the guide on screen at all. In memory only —
	# the harness must never write over a real save.
	if SaveService.instance != null:
		SaveService.instance.profile = SaveProfile.default_profile()
	_stage = (load(STAGE_SCENE) as PackedScene).instantiate()
	add_child(_stage)
	_spawner = _stage.get_node("World/Spawner")


func _process(_delta: float) -> void:
	_step += 1
	if _step < SETTLE_FRAMES:
		return
	# Only look for the dialog before the walk starts. The guide frees itself
	# on the last page, so a later null here means "finished", not "missing".
	if _page < 0 and _guide == null:
		_guide = _stage.get_node_or_null("GuideDialog")
		if _guide == null and _step > SETTLE_FRAMES * 4:
			_fail("the guide never opened on a fresh profile")
			_finish()
		return
	if (_step - SETTLE_FRAMES) % FRAMES_PER_PAGE != 0:
		return
	_page += 1
	if _page >= Ftue.GUIDE_PAGES.size():
		_finish()
		return
	_check_page(_page)
	_advance(_page)


func _check_page(index: int) -> void:
	var page: Dictionary = Ftue.GUIDE_PAGES[index]
	var await_action: String = String(page.get("await", ""))
	var should_hold: bool = index < Ftue.COMBAT_FROM_PAGE
	var firing: bool = false
	for weapon: AutoWeapon in _stage._weapon_nodes.values():
		if not weapon.hold_fire:
			firing = true
			break
	if _spawner.waves_held != should_hold:
		_fail("page %d: waves_held=%s, expected %s" % [
			index, str(_spawner.waves_held), str(should_hold)
		])
	if firing == should_hold:
		_fail("page %d: weapons firing=%s while hold expected %s" % [
			index, str(firing), str(should_hold)
		])
	print("CHECK page %d await=%-6s held=%s live_enemies=%d" % [
		index, await_action if not await_action.is_empty() else "-",
		str(_spawner.waves_held), _spawner.active_enemies().size()
	])
	_capture("user://tutorial_page_%d.png" % index)


## Fakes whatever the page is waiting for, so the probe can walk the whole
## script without a human at the controls.
func _advance(index: int) -> void:
	var await_action: String = String(Ftue.GUIDE_PAGES[index].get("await", ""))
	if await_action.is_empty():
		_guide._on_next_pressed()
	else:
		_guide.notify_action(await_action)


func _capture(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	get_viewport().get_texture().get_image().save_png(path)


func _finish() -> void:
	if _spawner != null and _spawner.waves_held:
		_fail("the world was still held after the last page")
	print("TUTORIAL CHECK: " + ("FAIL" if _failed else "PASS"))
	get_tree().quit(1 if _failed else 0)


func _fail(message: String) -> void:
	_failed = true
	push_error("tutorial_check: " + message)
