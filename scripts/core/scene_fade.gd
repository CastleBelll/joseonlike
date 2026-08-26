class_name SceneFadeLayer
extends CanvasLayer
## Screen transitions (N10-4). Every screen change used to be an instant cut —
## twelve `change_scene_to_file` calls with nothing in between — which is most of
## what the owner meant by 매끄럽지 않다: the game reads as a set of rooms that
## snap rather than a place you move through.
##
## An autoload owns it because the fade has to outlive the scene it is leaving. A
## curtain drawn by the departing screen would be freed halfway through its own
## animation.
##
## The curtain is one flat ColorRect, not a shader: a full-screen alpha ramp is
## the one fade that cannot disturb the pixel grid, and this project has no
## shader pipeline to hang one on.

const LAYER_ABOVE_EVERYTHING := 128
## Timings are read from data/effects.json → "transitions". They live in data
## because they are feel numbers, and feel numbers drift when they live in code.
const EFFECTS_PATH := "res://data/effects.json"
const DEFAULT_OUT_SEC := 0.14
const DEFAULT_IN_SEC := 0.18

var _curtain: ColorRect
var _out_sec: float = DEFAULT_OUT_SEC
var _in_sec: float = DEFAULT_IN_SEC
var _busy: bool = false


func _ready() -> void:
	# The curtain keeps animating while a paused run is left behind — the result
	# screen calls this with the tree still paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = LAYER_ABOVE_EVERYTHING
	_curtain = ColorRect.new()
	_curtain.name = "Curtain"
	_curtain.color = Color(0.0, 0.0, 0.0, 0.0)
	_curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_curtain.visible = false
	add_child(_curtain)
	_load_timings()
	get_tree().node_added.connect(_on_node_added)


func _load_timings() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(EFFECTS_PATH))
	if parsed is not Dictionary:
		return
	var block: Dictionary = (parsed as Dictionary).get("transitions", {})
	_out_sec = maxf(float(block.get("fade_out_sec", DEFAULT_OUT_SEC)), 0.0)
	_in_sec = maxf(float(block.get("fade_in_sec", DEFAULT_IN_SEC)), 0.0)


## What every screen calls instead of `get_tree().change_scene_to_file(path)`.
##
## Static, and it finds the curtain through the tree rather than through the
## autoload name: the headless suite runs with `--script`, which builds no
## autoloads, so a bare `SceneFade.` reference failed to COMPILE every screen
## that used it and took 26 tests down with it. With no curtain — tests, and any
## harness that boots a screen directly — the change still happens, instantly.
static func go(from: Node, path: String) -> void:
	var curtain: SceneFadeLayer = from.get_tree().root.get_node_or_null("SceneFade")
	if curtain == null:
		from.get_tree().change_scene_to_file(path)
		return
	curtain.change_scene(path)


func change_scene(path: String) -> void:
	if _busy:
		return  # a double tap on a menu button must not queue two transitions
	_busy = true
	await _fade(1.0, _out_sec)
	get_tree().change_scene_to_file(path)


## The incoming scene's root is what says the swap actually happened. Waiting on
## the tween alone would lift the curtain before the new screen had drawn, which
## is the same cut it was meant to remove.
func _on_node_added(node: Node) -> void:
	if not _busy or node != get_tree().current_scene:
		return
	_busy = false
	await get_tree().process_frame
	await _fade(0.0, _in_sec)


func _fade(to_alpha: float, seconds: float) -> void:
	_curtain.visible = true
	if seconds <= 0.0:
		_curtain.color.a = to_alpha
		_curtain.visible = to_alpha > 0.0
		return
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_curtain, "color:a", to_alpha, seconds)
	await tween.finished
	_curtain.visible = to_alpha > 0.0
