extends RefCounted
## Guards the N3-13 icon/chrome binding (UiIcons): data ids resolve straight
## to textures, unknown ids return null so callers keep their letter-glyph
## fallback, and the chrome 9-slices carry the asset/ui/README.md margins.


func test_icons_bind_by_id() -> bool:
	var passed: bool = UiIcons.weapon_icon("sword") != null
	passed = passed and UiIcons.loot_icon("bamboo") != null
	passed = passed and UiIcons.hud_icon("skull") != null
	if not passed:
		push_error("test_ui_icons: committed icon ids failed to load")
	return passed


func test_missing_icon_returns_null() -> bool:
	var passed: bool = UiIcons.weapon_icon("no_such_weapon") == null
	passed = passed and UiIcons.loot_icon("no_such_loot") == null
	passed = passed and UiIcons.weapon_icon("") == null
	if not passed:
		push_error("test_ui_icons: missing ids must return null, not crash")
	return passed


## N10-14: this pinned the old chrome's exact plate sizes (56x24 wood, 112x112
## paper) and its logical margins, so swapping in the owner's UI kit broke a
## test that was never about those numbers. What a 9-slice actually has to
## satisfy is that its corners fit: margins must be positive and the two
## opposite ones must not overlap inside the texture, or the frame smears.
func test_chrome_nine_slice_margins() -> bool:
	var plates: Dictionary = {
		"wood": UiIcons.wood_button("normal"),
		"paper": UiIcons.paper_panel(),
	}
	var passed: bool = true
	for name: String in plates:
		var plate: StyleBox = plates[name]
		if plate is not StyleBoxTexture:
			push_error("test_ui_icons: %s chrome is not a 9-slice texture" % name)
			return false
		var box: StyleBoxTexture = plate as StyleBoxTexture
		var size: Vector2 = box.texture.get_size()
		for side: Array in [
			[box.texture_margin_left, box.texture_margin_right, size.x, "x"],
			[box.texture_margin_top, box.texture_margin_bottom, size.y, "y"],
		]:
			var near: float = side[0]
			var far: float = side[1]
			var extent: float = side[2]
			if near <= 0.0 or far <= 0.0 or near + far >= extent:
				push_error("test_ui_icons: %s 9-slice %s margins %s+%s do not fit %s" % [
					name, side[3], near, far, extent
				])
				passed = false
	return passed


func test_wood_button_apply_uses_chrome_and_keeps_gold_focus() -> bool:
	var button := Button.new()
	WoodButton.apply(button)
	var passed: bool = true
	for state: String in ["normal", "hover", "pressed"]:
		passed = passed and button.get_theme_stylebox(state) is StyleBoxTexture
	var focus: StyleBox = button.get_theme_stylebox("focus")
	passed = passed and focus is StyleBoxFlat
	passed = passed and (focus as StyleBoxFlat).border_color == UiPalette.GOLD
	button.free()
	if not passed:
		push_error("test_ui_icons: WoodButton chrome states or focus ring broken")
	return passed


## QA (visual, b735bc0 H2): the wood CTA measured 1.57:1 against the kit plank.
## WOOD_TEXT was picked for the old flat orange plate and stayed behind when
## N10-14 swapped in dark wood art, so every 출정 / 계속하기 / 본거지로 went
## nearly invisible. This pins the ratio rather than the colour, so the guard
## survives a repaint of either side.
const WCAG_AA := 4.5
## Measured from asset/ui/chrome/build/plate_brown.png across the band a label
## occupies — the average a glyph actually sits on, not the plank's extremes.
const PLATE_BAND := Color("#734728")


static func _relative_luminance(c: Color) -> float:
	var parts: Array[float] = [c.r, c.g, c.b]
	var out: Array[float] = []
	for v: float in parts:
		out.append(v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4))
	return 0.2126 * out[0] + 0.7152 * out[1] + 0.0722 * out[2]


static func _contrast(a: Color, b: Color) -> float:
	var la: float = _relative_luminance(a)
	var lb: float = _relative_luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func test_wood_button_label_clears_wcag_aa_on_the_plank() -> bool:
	var ratio: float = _contrast(UiPalette.TEXT_ON_DARK, PLATE_BAND)
	var passed: bool = ratio >= WCAG_AA
	if not passed:
		push_error(
			"test_ui_icons: wood button label is %.2f:1 on the plank, under %.1f:1"
			% [ratio, WCAG_AA]
		)
	# And the colour it replaced must still fail, or this test proves nothing.
	if _contrast(UiPalette.WOOD_TEXT, PLATE_BAND) >= WCAG_AA:
		push_error("test_ui_icons: the plank or WOOD_TEXT moved — re-measure both")
		return false
	return passed
