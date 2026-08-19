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
## cos(~37°): the stick may clamp the pull, never turn it.
const DIRECTION_TOLERANCE := 0.8

var _stage: Stage
var _spawner: Spawner
var _guide: GuideDialog
var _step: int = 0
var _page: int = -1
var _failed: bool = false
var _finger: int = 0
var _finger_down: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Accumulated input merges drags and flushes them at frame end; the probe
	# reads the stick on the same line it sends the drag, so it needs each
	# event delivered as it is parsed.
	Input.use_accumulated_input = false
	# A fresh profile is what puts the guide on screen at all. In memory only —
	# the harness must never write over a real save.
	if SaveService.instance != null:
		SaveService.instance.profile = SaveProfile.default_profile()
	_stage = (load(STAGE_SCENE) as PackedScene).instantiate()
	# The harness runs while paused so it can drive the guide, but the stage
	# must NOT inherit that: shipped, it is the scene root and pauses with the
	# tree. Hanging it under an ALWAYS node kept the whole world — joystick
	# included — receiving input through every pause, which is precisely the
	# condition the reported bug needs, so the probe would have passed forever.
	_stage.process_mode = Node.PROCESS_MODE_PAUSABLE
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
	_probe_touch(index, await_action)
	_capture("user://tutorial_page_%d.png" % index)


## Puts a real finger on the screen where the script asks the player to act.
## The move page leaves it DOWN across the page change — that is the reported
## sequence, and the pause that follows is what used to swallow the release and
## strand the captured index, so the kill page's drag then went nowhere.
func _probe_touch(index: int, await_action: String) -> void:
	if await_action == Ftue.AWAIT_MOVE:
		_probe_drag(index, Vector2(0.0, -50.0))
		_finger_down = true
		return
	if await_action.is_empty():
		# A tap-through page freezes the world. The player lifts their thumb to
		# reach the button, and THAT release is the one the stick never saw.
		if _finger_down:
			_release_finger()
		return
	if await_action == Ftue.AWAIT_KILL:
		# A different direction on purpose: a stick that never let go would
		# still be reporting the move page's upward pull, which any
		# "produced some output" check would wave through.
		_probe_drag(index, Vector2(50.0, 0.0))
		_release_finger()


## N9-50 (owner report: "도깨비 잡아보는거에서 드래그하면 조이스틱이 굳어서
## 안움직여"). Every earlier check faked the guide's actions, so no probe ever
## put a finger on the screen — and the guide is exactly where a swallowed
## touch hides (N9-44 was the same family). Each page that asks the player to
## act gets a real press and drag through Input, and the stick has to answer.
##
## The move page deliberately keeps the finger DOWN through the page change:
## that is the reported sequence, and the pause that follows is what used to
## eat the release and strand the captured index.
## The drag DIRECTION is what gets asserted, not merely "some output": a stick
## still holding the previous finger keeps reporting the previous vector, which
## a non-zero check would happily accept as working.
func _probe_drag(index: int, pull: Vector2) -> void:
	var origin := Vector2(160.0 + 40.0 * float(index), 700.0)
	_send_touch(origin, true)
	_send_drag(origin + pull)
	var output: Vector2 = _stage._joystick.output
	var want: Vector2 = pull.normalized()
	if output.normalized().dot(want) < DIRECTION_TOLERANCE:
		_fail("page %d: dragged %s, stick reported %s" % [index, want, output])
	else:
		print("CHECK page %d drag %s -> stick %s" % [index, want, output])


## Lifts the finger with a fresh index, the way the next real touch arrives.
func _release_finger() -> void:
	_send_touch(Vector2(160.0, 650.0), false)
	_finger += 1
	_finger_down = false


func _send_touch(at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = _finger
	event.position = at
	event.pressed = pressed
	Input.parse_input_event(event)


func _send_drag(to: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = _finger
	event.position = to
	Input.parse_input_event(event)


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
