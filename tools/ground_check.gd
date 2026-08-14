extends Node
## Ground coverage spot-check (N3-16): boots the real stage, teleports the
## player to the field's bottom-right bound (where the old fixed-field ground
## showed a grey band), lets the smoothed camera settle, screenshots, quits.
## Run: godot --path . res://tools/ground_check.tscn

const STAGE_SCENE := "res://scenes/stage.tscn"
const SHOT_PATH := "user://ground_check_edge.png"
const SETTLE_SEC := 2.0

var _stage: Stage
var _player: Player
var _elapsed: float = 0.0
var _done := false


func _ready() -> void:
	_stage = (load(STAGE_SCENE) as PackedScene).instantiate()
	add_child(_stage)
	_player = _stage.get_node("World/Player")


func _process(delta: float) -> void:
	_elapsed += delta
	# Re-pin every frame: the clamp in Player keeps it on the bound anyway.
	_player.global_position = _player.bounds.end
	if _done or _elapsed < SETTLE_SEC:
		return
	_done = true
	_capture()


func _capture() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(SHOT_PATH)
	print("GROUND CHECK shot: " + ProjectSettings.globalize_path(SHOT_PATH))
	get_tree().quit(0)
