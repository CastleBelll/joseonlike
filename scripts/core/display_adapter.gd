extends Node
## N9-154 (owner: 가로모드에서 글씨가 너무 작아 보인다): the stretch base is
## portrait 540x960, so a sideways phone fits the TALL base into a SHORT
## window and renders everything at roughly half the physical size. This
## autoload swaps the content scale base to 960x540 whenever the window is
## wider than tall — text, HUD and the world all keep their portrait physical
## size, and aspect "expand" still hands wide screens their extra view.

const PORTRAIT_BASE := Vector2i(540, 960)
const LANDSCAPE_BASE := Vector2i(960, 540)


func _ready() -> void:
	_apply_orientation_base()
	get_tree().root.size_changed.connect(_apply_orientation_base)


func _apply_orientation_base() -> void:
	var window: Window = get_tree().root
	var wide: bool = window.size.x > window.size.y
	var wanted: Vector2i = LANDSCAPE_BASE if wide else PORTRAIT_BASE
	if window.content_scale_size != wanted:
		window.content_scale_size = wanted
