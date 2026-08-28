extends RefCounted
## Owner (전체화면에서 요소들이 너무 크다): the content scale base must stop a
## big window from upscaling the phone-sized design past MAX_UI_SCALE. Guards
## the orientation swap (N9-154) at the same time.


func test_design_sizes_keep_their_base() -> bool:
	var passed: bool = (
		DisplayAdapterService.base_for(Vector2i(540, 960)) == DisplayAdapterService.PORTRAIT_BASE
		and DisplayAdapterService.base_for(Vector2i(960, 540)) == DisplayAdapterService.LANDSCAPE_BASE
	)
	if not passed:
		push_error("test_display_adapter: a design-size window no longer keeps its base")
	return passed


func test_big_window_caps_the_upscale() -> bool:
	var passed: bool = true
	for window: Vector2i in [
		Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(1280, 1024), Vector2i(1080, 1920)
	]:
		var base: Vector2i = DisplayAdapterService.base_for(window)
		var scale: float = float(window.y) / float(base.y)
		if scale > DisplayAdapterService.MAX_UI_SCALE + 0.01:
			push_error(
				"test_display_adapter: %dx%d upscales %.2fx, past the %.2fx cap"
				% [window.x, window.y, scale, DisplayAdapterService.MAX_UI_SCALE]
			)
			passed = false
		# Never smaller than the design base — that would shrink a phone's UI.
		if base.y < DisplayAdapterService.LANDSCAPE_BASE.y:
			push_error("test_display_adapter: base fell below the design floor")
			passed = false
	return passed


func test_capped_base_keeps_the_window_aspect() -> bool:
	# A grown base must match the window's own ratio, or the stretch crops.
	var window := Vector2i(1920, 1080)
	var base: Vector2i = DisplayAdapterService.base_for(window)
	var window_ratio: float = float(window.x) / float(window.y)
	var base_ratio: float = float(base.x) / float(base.y)
	var passed: bool = absf(window_ratio - base_ratio) < 0.01
	if not passed:
		push_error(
			"test_display_adapter: grown base ratio %.3f != window ratio %.3f"
			% [base_ratio, window_ratio]
		)
	return passed


## Owner (모바일에서 전체적으로 너무 작아, 2026-08-28): a phone whose CSS
## viewport is narrower than the 540 design base gets a SHRUNKEN base now, so
## logical pixels approach CSS pixels and the whole UI draws bigger. Portrait
## floors at MIN_BASE_FACTOR_PORTRAIT; landscape screens are built to exactly
## 540 of height and do not shrink at all.
func test_a_narrow_phone_gets_a_bigger_ui() -> bool:
	# iPhone-class portrait at 3x (390 CSS wide): css_scale 0.72 -> floored at
	# 0.9, so the base shrinks to 486x864 and the apparent scale rises.
	var floor_base := Vector2i(486, 864)
	var passed: bool = (
		DisplayAdapterService.base_for(Vector2i(1170, 2532), 3.0) == floor_base
	)
	# 2x Android-class portrait (540 CSS wide) is exactly the design base — no
	# shrink, no growth.
	passed = passed and (
		DisplayAdapterService.base_for(Vector2i(1080, 1920), 2.0)
		== DisplayAdapterService.PORTRAIT_BASE
	)
	# A landscape phone keeps the full landscape base: the camp measured a
	# 27px overflow at 0.9, so landscape holds its ground.
	passed = passed and (
		DisplayAdapterService.base_for(Vector2i(2532, 1170), 3.0)
		== DisplayAdapterService.LANDSCAPE_BASE
	)
	if not passed:
		push_error("test_display_adapter: the narrow-phone base shrink is wrong")
	return passed


func test_the_desktop_cap_that_motivated_this_still_bites() -> bool:
	# The cap exists because a 1080-tall fullscreen at ratio 1 rendered a
	# phone-sized UI across a monitor (전체화면에서 요소들이 너무 크다). The
	# ratio-aware cap must not have un-fixed that.
	var monitor := Vector2i(1920, 1080)
	var base: Vector2i = DisplayAdapterService.base_for(monitor, 1.0)
	var passed: bool = base != DisplayAdapterService.LANDSCAPE_BASE
	passed = passed and base.y > DisplayAdapterService.LANDSCAPE_BASE.y
	# And the ratio never shrinks the cap below its ratio-1 meaning.
	passed = passed and DisplayAdapterService.base_for(monitor, 0.5) == base
	if not passed:
		push_error("test_display_adapter: the desktop fullscreen cap regressed")
	return passed
