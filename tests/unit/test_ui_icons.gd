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


func test_chrome_nine_slice_margins() -> bool:
	var wood: StyleBox = UiIcons.wood_button("normal")
	var paper: StyleBox = UiIcons.paper_panel()
	var passed: bool = wood is StyleBoxTexture and paper is StyleBoxTexture
	if not passed:
		push_error("test_ui_icons: chrome styleboxes are not 9-slice textures")
		return false
	var wood_margin: float = float(UiIcons.WOOD_MARGIN_LOGICAL * UiIcons.CHROME_SCALE)
	var paper_margin: float = float(UiIcons.PAPER_MARGIN_LOGICAL * UiIcons.CHROME_SCALE)
	passed = (wood as StyleBoxTexture).texture_margin_left == wood_margin
	passed = passed and (wood as StyleBoxTexture).texture_margin_bottom == wood_margin
	passed = passed and (paper as StyleBoxTexture).texture_margin_left == paper_margin
	passed = passed and (paper as StyleBoxTexture).texture_margin_bottom == paper_margin
	# Cropped to the opaque plate, downscaled to 2x logical: the 28x12 wood
	# plate and 56x56 paper plate.
	passed = passed and (wood as StyleBoxTexture).texture.get_size() == Vector2(56.0, 24.0)
	passed = passed and (paper as StyleBoxTexture).texture.get_size() == Vector2(112.0, 112.0)
	if not passed:
		push_error("test_ui_icons: chrome margins or downscale wrong")
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
