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
