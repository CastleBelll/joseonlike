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
