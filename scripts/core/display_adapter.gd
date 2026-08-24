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
## Owner (전체화면에서 요소들이 너무 크다): a 1080-tall fullscreen window
## renders the 540 base at 2x, so a phone-sized UI fills a monitor. Past this
## factor the base grows with the window instead — buttons and text keep a
## sane physical size and the wide screen shows more of the field.
const MAX_UI_SCALE := 1.5


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


## The content scale base for one window size: the orientation's design base,
## grown proportionally once the window would upscale it past MAX_UI_SCALE.
## Static so the unit test can prove the cap without a window.
static func base_for(window_size: Vector2i) -> Vector2i:
	var wide: bool = window_size.x > window_size.y
	var base: Vector2i = LANDSCAPE_BASE if wide else PORTRAIT_BASE
	if window_size.y <= 0:
		return base
	var scale: float = float(window_size.y) / float(base.y)
	if scale <= MAX_UI_SCALE:
		return base
	# Keep the window's own aspect so nothing is cropped or letterboxed; the
	# design bands stay centered and the extra width shows more background.
	return Vector2i(
		maxi(int(round(float(window_size.x) / MAX_UI_SCALE)), base.x),
		maxi(int(round(float(window_size.y) / MAX_UI_SCALE)), base.y)
	)


func _apply_orientation_base() -> void:
	var window: Window = get_tree().root
	var wanted: Vector2i = base_for(window.size)
	if window.content_scale_size != wanted:
		window.content_scale_size = wanted
