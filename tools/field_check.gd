extends Node
## N6-5 wide-field screenshot: boots the real stage, zooms the run camera out
## so most of the 2048px field fits the portrait view, waits for the layout to
## settle, screenshots, quits. Used for the declutter before/after evidence.
## Run: godot --path . res://tools/field_check.tscn -- --out=field.png [--zoom=0.3]

const STAGE_SCENE := "res://scenes/stage.tscn"
const SETTLE_SEC := 1.0
const DEFAULT_ZOOM := 0.3

var _stage: Stage
var _elapsed: float = 0.0
var _done := false
var _out_path: String = "user://field_check.png"
var _zoom: float = DEFAULT_ZOOM


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_path = "user://" + arg.get_slice("=", 1)
		elif arg.begins_with("--zoom="):
			_zoom = maxf(float(arg.get_slice("=", 1)), 0.05)
	_stage = (load(STAGE_SCENE) as PackedScene).instantiate()
	add_child(_stage)


func _process(delta: float) -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera != null:
		camera.zoom = Vector2(_zoom, _zoom)
	_elapsed += delta
	if _done or _elapsed < SETTLE_SEC:
		return
	_done = true
	_capture()


func _capture() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out_path)
	print("FIELD CHECK shot: " + ProjectSettings.globalize_path(_out_path))
	get_tree().quit(0)
