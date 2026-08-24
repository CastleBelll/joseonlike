class_name DisplayAdapterService
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
	# N9-156: the saved window preset applies on boot, desktop only — the
	# browser and a phone own their window.
	var desktop: bool = not OS.has_feature("web") and not OS.has_feature("mobile")
	if desktop and SaveService.instance != null:
		apply_resolution(String(SaveService.instance.get_setting("resolution")))


## "WxH" preset from the settings popup; "" or anything unparsable leaves the
## window alone. Centered after the resize so the window never walks off.
static func apply_resolution(preset: String) -> void:
	if OS.has_feature("web") or OS.has_feature("mobile"):
		return
	var parts: PackedStringArray = preset.split("x")
	if parts.size() != 2:
		return
	var wanted := Vector2i(maxi(int(parts[0]), 320), maxi(int(parts[1]), 320))
	DisplayServer.window_set_size(wanted)
	var screen: Vector2i = DisplayServer.screen_get_size()
	DisplayServer.window_set_position((screen - wanted) / 2)


func _apply_orientation_base() -> void:
	var window: Window = get_tree().root
	var wide: bool = window.size.x > window.size.y
	var wanted: Vector2i = LANDSCAPE_BASE if wide else PORTRAIT_BASE
	if window.content_scale_size != wanted:
		window.content_scale_size = wanted
