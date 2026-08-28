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
## How far the base may shrink toward a narrow phone's CSS viewport before
## the layouts give out — measured by the layout sweep's DPR-aware phone
## entries, not chosen. Portrait holds at 0.9 (a 393-CSS phone reads at ~0.81x
## instead of 0.73x); the landscape screens are built to exactly 540 of height
## (the camp overflows 27px at 0.9), so landscape does not shrink at all.
const MIN_BASE_FACTOR_PORTRAIT := 0.9
const MIN_BASE_FACTOR_LANDSCAPE := 1.0


## Owner (폰을 가로로 돌리니 세로 버전이 늘어난다): itch serves the game in a
## fixed portrait iframe, so rotating the phone never hands the canvas a wide
## viewport — the portrait build is simply scaled into a landscape box. Only
## the browser fullscreen API escapes that box, and it needs a real gesture,
## so the first touch takes it. Desktop browsers and the standalone page are
## left alone; a player who leaves fullscreen is not dragged back in.
var _fullscreen_offered := false


func _ready() -> void:
	_apply_orientation_base()
	get_tree().root.size_changed.connect(_apply_orientation_base)
	if not _boxed_mobile_web():
		_fullscreen_offered = true
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


## A mobile browser running us inside someone else's frame — the itch embed.
func _boxed_mobile_web() -> bool:
	if not OS.has_feature("web"):
		return false
	# A touch browser, however the export tags itself — the itch embed is the
	# same box on every phone, and a desktop browser has no touchscreen.
	if not DisplayServer.is_touchscreen_available():
		return false
	var framed: Variant = JavaScriptBridge.eval("window.self !== window.top", true)
	return bool(framed)


## _input, not _unhandled_input: the screens are Controls that stop the event
## at the GUI layer, so an unhandled hook would never see the first tap.
func _input(event: InputEvent) -> void:
	if _fullscreen_offered:
		return
	var pressed: bool = (
		(event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
	)
	if not pressed:
		return
	# One shot: the gesture that starts the game also breaks it out of the
	# embed. Everything after is the player's own call through 설정 → 전체화면.
	_fullscreen_offered = true
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	# The engine call maps to requestFullscreen on the canvas; asking the
	# document directly is the fallback when the canvas request is refused
	# inside a cross-origin frame. Both must run inside this gesture.
	JavaScriptBridge.eval(
		"(function(){var e=document.documentElement;"
		+ "if(!document.fullscreenElement&&e.requestFullscreen){"
		+ "e.requestFullscreen().catch(function(){});}"
		+ "if(screen.orientation&&screen.orientation.unlock){"
		+ "try{screen.orientation.unlock();}catch(x){}}})();",
		true
	)


## The content scale base for one window size: the orientation's design base,
## grown proportionally once the window would upscale it past MAX_UI_SCALE.
## Static so the unit test can prove the cap without a window.
##
## `pixel_ratio` is the display's device-pixel ratio. The cap exists to bound
## the APPARENT size of the UI, and the window size on web arrives in DEVICE
## pixels — a 3x phone reports 1170x2532, scale 2.6 tripped the 1.5 cap, the
## base grew, and every button shrank to ~22 CSS px (owner: ui/ux들이 많이
## 작아). Multiplying the cap by the ratio makes it a CSS-pixel rule again:
## the phone keeps the 540 base and a native-app-sized UI, while the desktop
## monitor that motivated the cap (전체화면에서 요소들이 너무 크다) still
## triggers it at ratio 1.
static func base_for(window_size: Vector2i, pixel_ratio: float = 1.0) -> Vector2i:
	var wide: bool = window_size.x > window_size.y
	var base: Vector2i = LANDSCAPE_BASE if wide else PORTRAIT_BASE
	if window_size.y <= 0:
		return base
	var ratio: float = maxf(pixel_ratio, 1.0)
	var max_scale: float = MAX_UI_SCALE * ratio
	var scale: float = float(window_size.y) / float(base.y)
	if scale > max_scale:
		# Keep the window's own aspect so nothing is cropped or letterboxed;
		# the design bands stay centered and the extra width shows more
		# background.
		return Vector2i(
			maxi(int(round(float(window_size.x) / max_scale)), base.x),
			maxi(int(round(float(window_size.y) / max_scale)), base.y)
		)
	# Owner (모바일에서 전체적으로 너무 작아): a phone's CSS viewport is
	# narrower than the 540 design base, so the whole UI rendered at ~0.73x
	# CSS scale — the first-run guide included. When the window would
	# DOWNSCALE the base, the base shrinks toward the CSS size instead, so
	# logical pixels approach CSS pixels and everything draws bigger. The
	# floor is what the layout sweep proves the screens can still hold —
	# below it the paper panels overflow before the text gets any bigger.
	var css_scale: float = minf(
		float(window_size.x) / ratio / float(base.x),
		float(window_size.y) / ratio / float(base.y)
	)
	if css_scale < 1.0:
		var floor_factor: float = (
			MIN_BASE_FACTOR_LANDSCAPE if wide else MIN_BASE_FACTOR_PORTRAIT
		)
		var factor: float = maxf(css_scale, floor_factor)
		return Vector2i(
			int(round(float(base.x) * factor)),
			int(round(float(base.y) * factor))
		)
	return base


## The display's device-pixel ratio. On web this is the browser's own number;
## natively screen_get_scale answers where the platform supports it and 1.0
## everywhere else, which leaves desktop behaviour exactly as it was.
func _pixel_ratio() -> float:
	if OS.has_feature("web"):
		var ratio: Variant = JavaScriptBridge.eval("window.devicePixelRatio || 1", true)
		if ratio is float or ratio is int:
			return maxf(float(ratio), 1.0)
		return 1.0
	return maxf(DisplayServer.screen_get_scale(), 1.0)


func _apply_orientation_base() -> void:
	var window: Window = get_tree().root
	var wanted: Vector2i = base_for(window.size, _pixel_ratio())
	if window.content_scale_size != wanted:
		window.content_scale_size = wanted
