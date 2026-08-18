extends Node
## N6-5 joystick evidence: boots the real stage with an in-memory profile
## pinned to a given joystick_opacity (write-locked — the dev profile on disk
## is never touched), waits for the HUD to settle, screenshots, quits.
## Run: godot --path . res://tools/joystick_check.tscn -- --opacity=0.4

const STAGE_SCENE := "res://scenes/stage.tscn"
const SETTLE_SEC := 0.8

var _stage: Stage
var _elapsed: float = 0.0
var _done := false
var _opacity: float = SaveProfile.JOYSTICK_OPACITY_MAX


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--opacity="):
			_opacity = float(arg.get_slice("=", 1))
	if SaveService.instance != null:
		SaveService.instance._write_locked = true
		SaveService.instance.set_setting(SaveProfile.JOYSTICK_OPACITY_KEY, _opacity, false)
	_stage = (load(STAGE_SCENE) as PackedScene).instantiate()
	add_child(_stage)


func _process(delta: float) -> void:
	_elapsed += delta
	if _done or _elapsed < SETTLE_SEC:
		return
	_done = true
	_capture()


func _capture() -> void:
	await RenderingServer.frame_post_draw
	var out_path: String = "user://joystick_%02d.png" % int(round(_opacity * 100.0))
	get_viewport().get_texture().get_image().save_png(out_path)
	print("JOYSTICK CHECK shot: " + ProjectSettings.globalize_path(out_path))
	get_tree().quit(0)
