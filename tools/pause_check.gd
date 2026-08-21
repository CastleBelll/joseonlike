extends Node
## N9-111 evidence (owner: 일시정지, 톱니 눌러도 안 멈추는데): boots the real
## stage, CLICKS the pause button and the gear through the real input chain
## (viewport push_input, not pressed.emit), and asserts the tree actually
## freezes — the run clock must stop moving. pressed.emit() would bypass
## every input-eating regression this harness exists to catch (a full-rect
## control with the wrong mouse_filter, a sibling drawn over the corner).
## Also screenshots the open pause popup over the minimap for the z-order
## record. Run: godot --path . res://tools/pause_check.tscn

const STAGE_SCENE := "res://scenes/stage.tscn"
const SETTLE_SEC := 1.2
const FREEZE_OBSERVE_SEC := 0.6

var _stage: Stage
var _failed: bool = false
var _elapsed: float = 0.0
var _started: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if SaveService.instance != null:
		var profile: Dictionary = SaveProfile.default_profile()
		(profile["stats"] as Dictionary)["runs_played"] = 1
		profile[Ftue.FTUE_KEY] = {
			Ftue.MOVE_HINT_SEEN: true, Ftue.MOD_EXPLAINED: true,
			Ftue.GUIDE_SEEN: true, Ftue.LEVELUP_EXPLAINED: true,
		}
		# The map unlock matters: the popup once hid behind the late-added
		# minimap, so the shot must include it.
		profile[Unlocks.PROFILE_KEY] = [Unlocks.MAP]
		SaveService.instance.profile = profile
		SaveService.instance._write_locked = true
		SaveService.instance._write_lock_reason = "a harness is using a throwaway profile"
	_stage = (load(STAGE_SCENE) as PackedScene).instantiate()
	# The probe root runs ALWAYS so it can click while paused; the stage must
	# not inherit that, or the harness itself would defeat the pause under test.
	_stage.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_stage)


func _process(delta: float) -> void:
	_elapsed += delta
	if _started or _elapsed < SETTLE_SEC:
		return
	_started = true
	_run_probes()


func _run_probes() -> void:
	var hud: CombatHud = _stage.get_node("Hud/CombatHud")
	# --- pause button stops the world
	_click(hud.get_node("CornerButtons/PauseButton") as Button)
	await get_tree().process_frame
	if not get_tree().paused:
		_fail("pause button click did not pause the tree")
	var overlay: Control = hud.get_node("OverlayLayer/PauseOverlay")
	if not overlay.visible:
		_fail("pause popup did not open from the click")
	var frozen: float = _stage._run_elapsed
	await _wait_real(FREEZE_OBSERVE_SEC)
	if absf(_stage._run_elapsed - frozen) > 0.0001:
		_fail("run clock kept moving while paused (%.3f -> %.3f)"
			% [frozen, _stage._run_elapsed])
	await _shot("pause_over_minimap")
	_click(overlay.find_child("ResumeButton", true, false) as Button)
	await get_tree().process_frame
	if get_tree().paused:
		_fail("resume did not unpause the tree")
	# --- gear freezes exactly like pause and hands it back on close
	_click(hud.get_node("SettingsButton") as Button)
	await get_tree().process_frame
	if not get_tree().paused:
		_fail("gear click did not pause the tree")
	var popup: SettingsPopup = hud._settings_popup
	if popup == null or not popup.visible:
		_fail("gear click did not open the settings popup")
	frozen = _stage._run_elapsed
	await _wait_real(FREEZE_OBSERVE_SEC)
	if absf(_stage._run_elapsed - frozen) > 0.0001:
		_fail("run clock kept moving under the settings popup")
	await _shot("gear_settings_open")
	if popup != null:
		popup._on_close_pressed()
	await get_tree().process_frame
	if get_tree().paused:
		_fail("closing settings did not resume the run")
	print("PAUSE CHECK %s" % ("FAIL" if _failed else "PASS"))
	get_tree().quit(1 if _failed else 0)


## A real click through the input pipeline: press and release at the button's
## on-screen centre, exactly what a finger or the mouse would deliver.
func _click(button: Button) -> void:
	if button == null:
		_fail("probe target button is missing from the tree")
		return
	var center: Vector2 = button.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = center
		event.global_position = center
		get_viewport().push_input(event)


func _wait_real(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _shot(name_stem: String) -> void:
	await RenderingServer.frame_post_draw
	var out_path: String = "user://pause_check_%s.png" % name_stem
	get_viewport().get_texture().get_image().save_png(out_path)
	print("PAUSE CHECK shot: " + ProjectSettings.globalize_path(out_path))


func _fail(reason: String) -> void:
	_failed = true
	push_error("pause_check: " + reason)
