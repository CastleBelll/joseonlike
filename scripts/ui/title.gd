class_name TitleScreen
extends Control
## Title screen layout (N1-1), DESIGN.md §4. The gradient background and the
## logo plaque are placeholders; N1-2 swaps LogoArea and the background bands
## for the AC-2 art. "start" routes to the stage scene (N3-1); other targets
## do not exist yet, so their presses only emit menu_selected.

signal menu_selected(id: String)

const STAGE_SCENE := "res://scenes/stage.tscn"

const MENU_WIDTH_RATIO := 0.85
const MENU_BUTTON_HEIGHT := 64
const MENU_BOTTOM_MARGIN := 48
const LOGO_ANCHOR_SIDE := 0.14
const LOGO_ANCHOR_TOP := 0.12
const LOGO_ANCHOR_BOTTOM := 0.30
const LOGO_FONT_SCALE := 2
const VILLAGE_BAND_RATIO := 0.32
const UTILITY_BUTTON_SIZE := 48
const SKY_TOP_DARKEN := 0.4
const SKY_MID_OFFSET := 0.55


static func menu_button_defs() -> Array[Dictionary]:
	return [
		{"id": "start", "label": UiLocale.text("title.start")},
		{"id": "select_character", "label": UiLocale.text("title.select_character")},
	]


func _ready() -> void:
	build_ui()
	menu_selected.connect(_on_menu_selected)


func _on_menu_selected(id: String) -> void:
	if id == "start":
		get_tree().change_scene_to_file(STAGE_SCENE)


## Builds every child node. Public so the headless test can construct the
## screen without a running SceneTree.
func build_ui() -> void:
	_build_background()
	_build_logo()
	_build_utilities()
	_build_menu()


func _build_background() -> void:
	var sky := TextureRect.new()
	sky.name = "SkyBackground"
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		UiPalette.NIGHT.darkened(SKY_TOP_DARKEN), UiPalette.NIGHT, UiPalette.NIGHT_BROWN,
	])
	gradient.offsets = PackedFloat32Array([0.0, SKY_MID_OFFSET, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2(0.0, 1.0)
	sky.texture = texture
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sky)

	var village := ColorRect.new()
	village.name = "VillageSilhouette"
	village.color = UiPalette.INK
	village.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	village.anchor_top = 1.0 - VILLAGE_BAND_RATIO
	add_child(village)


func _build_logo() -> void:
	var plaque := PanelContainer.new()
	plaque.name = "LogoArea"
	plaque.anchor_left = LOGO_ANCHOR_SIDE
	plaque.anchor_right = 1.0 - LOGO_ANCHOR_SIDE
	plaque.anchor_top = LOGO_ANCHOR_TOP
	plaque.anchor_bottom = LOGO_ANCHOR_BOTTOM
	var style := StyleBoxFlat.new()
	style.bg_color = UiPalette.NIGHT_BROWN
	style.border_color = UiPalette.WOOD_BORDER
	style.set_border_width_all(WoodButton.BORDER_WIDTH)
	style.set_corner_radius_all(WoodButton.CORNER_RADIUS)
	plaque.add_theme_stylebox_override("panel", style)

	var game_name := Label.new()
	game_name.name = "GameName"
	game_name.text = UiLocale.text("title.game_name")
	game_name.add_theme_color_override("font_color", UiPalette.GOLD)
	game_name.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_TITLE * LOGO_FONT_SCALE)
	game_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plaque.add_child(game_name)
	add_child(plaque)


func _build_utilities() -> void:
	var row := HBoxContainer.new()
	row.name = "CornerUtilities"
	row.position = Vector2(UiPalette.SPACE_MD, UiPalette.SPACE_MD)
	row.add_theme_constant_override("separation", UiPalette.SPACE_SM)

	var settings := Button.new()
	settings.name = "SettingsButton"
	settings.text = UiLocale.text("title.settings")
	settings.tooltip_text = UiLocale.text("title.settings")
	settings.custom_minimum_size = Vector2(UTILITY_BUTTON_SIZE, UTILITY_BUTTON_SIZE)
	WoodButton.apply(settings)
	settings.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_LABEL)
	settings.pressed.connect(func() -> void: menu_selected.emit("settings"))
	row.add_child(settings)
	add_child(row)


func _build_menu() -> void:
	var stack := VBoxContainer.new()
	stack.name = "MenuButtons"
	var side_margin: float = (1.0 - MENU_WIDTH_RATIO) / 2.0
	stack.anchor_left = side_margin
	stack.anchor_right = 1.0 - side_margin
	stack.anchor_top = 1.0
	stack.anchor_bottom = 1.0
	stack.offset_bottom = -MENU_BOTTOM_MARGIN
	stack.grow_vertical = Control.GROW_DIRECTION_BEGIN
	stack.add_theme_constant_override("separation", UiPalette.SPACE_LG)

	for def: Dictionary in menu_button_defs():
		var button := Button.new()
		var id: String = def["id"]
		button.name = "MenuButton_" + id
		button.text = def["label"]
		button.custom_minimum_size = Vector2(0, MENU_BUTTON_HEIGHT)
		WoodButton.apply(button)
		button.pressed.connect(func() -> void: menu_selected.emit(id))
		stack.add_child(button)
	add_child(stack)

	var first_button: Button = stack.get_child(0)
	if first_button.is_inside_tree():
		first_button.grab_focus()
