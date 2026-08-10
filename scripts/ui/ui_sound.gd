class_name UiSound
extends RefCounted
## Fire-and-forget UI SFX. Not an autoload (project.godot is coordinator-
## owned), so this spawns a throwaway AudioStreamPlayer under the caller's
## tree root and frees it when playback finishes.

const CLICK: AudioStream = preload("res://asset/audio/sfx/ui_click.wav")
const LEVEL_UP: AudioStream = preload("res://asset/audio/sfx/level_up.wav")


static func play_click(from_node: Node) -> void:
	_play(from_node, CLICK)


static func play_level_up(from_node: Node) -> void:
	_play(from_node, LEVEL_UP)


static func _play(from_node: Node, stream: AudioStream) -> void:
	var tree: SceneTree = from_node.get_tree()
	if tree == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	tree.root.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
