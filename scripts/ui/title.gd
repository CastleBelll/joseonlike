class_name TitleScreen
extends Control
## Title screen layout (N1-1) with the N1-2 art layers, DESIGN.md §4.
## Sky and village are full-bleed 540x960 textures exported at 2x; the
## signboard logo carries the lettering baked per locale (asset/title/README.md).
## "start" routes to the stage scene (N3-1); other targets do not exist yet,
## so their presses only emit menu_selected.

signal menu_selected(id: String)

const STAGE_SCENE := "res://scenes/stage.tscn"
const SELECT_SCENE := "res://scenes/character_select.tscn"
const CAMP_SCENE := "res://scenes/camp.tscn"

const SKY_TEXTURE := "res://asset/title/bg_sky.png"
const VILLAGE_TEXTURE := "res://asset/title/bg_village.png"
const LOGO_TEXTURES: Dictionary = {
	"ko": "res://asset/title/logo_ko.png",
	"en": "res://asset/title/logo_en.png",
}
# Logical placement from asset/title/build_assets.py's preview composition.
const LOGO_POSITION := Vector2(60, 90)
const LOGO_SIZE := Vector2(420, 200)

const MENU_WIDTH_RATIO := 0.85
const MENU_BUTTON_HEIGHT := 64
const MENU_BOTTOM_MARGIN := 48
const UTILITY_BUTTON_SIZE := 48

var _settings_popup: SettingsPopup


# Owner direction (N5-2): exactly one primary action. No continue button —
# the profile autosaves and the next launch simply resumes; first boot and
# returning player press the same start button.
static func menu_button_defs() -> Array[Dictionary]:
	return [
		{"id": "start", "label": UiLocale.text("title.start")},
	]


func _ready() -> void:
	build_ui()
	_settings_popup = SettingsPopup.new()
	_settings_popup.locale_changed.connect(refresh_texts)
	add_child(_settings_popup)
	menu_selected.connect(_on_menu_selected)


func _on_menu_selected(id: String) -> void:
	if id == "start":
		# N6-1 first-boot routing (GDD §28): the first run is always the
		# taoist, straight into the stage with no camp or select detour.
		# From the second visit on, start lands in the base camp (N5-3)
		# and the run departs from there.
		var profile: Dictionary = SaveProfile.default_profile()
		if SaveService.instance != null:
			profile = SaveService.instance.profile
		if Camp.destination_after_title(profile) == Camp.DEST_CAMP:
			get_tree().change_scene_to_file(CAMP_SCENE)
			return
		if SaveService.instance != null:
			var routed: String = Ftue.route_character(SaveService.instance.profile)
			if routed != SaveService.instance.selected_character():
				SaveService.instance.set_selected_character(routed)
		get_tree().change_scene_to_file(STAGE_SCENE)
	elif id == "select_character":
		get_tree().change_scene_to_file(SELECT_SCENE)
	elif id == "settings" and _settings_popup != null:
		_settings_popup.open()


## Re-applies every locale-sensitive text in place; called when the settings
## popup toggles the language so the change shows immediately.
func refresh_texts() -> void:
	(get_node("Logo") as TextureRect).texture = load(_logo_texture_path())
	var settings_button: Button = get_node("CornerUtilities/SettingsButton")
	settings_button.text = UiLocale.text("title.settings")
	settings_button.tooltip_text = UiLocale.text("title.settings")
	var select_button: Button = get_node("CornerUtilities/SelectCharacterButton")
	select_button.text = UiLocale.text("title.select_character")
	select_button.tooltip_text = UiLocale.text("title.select_character")
	var stack: VBoxContainer = get_node("MenuButtons")
	var defs: Array[Dictionary] = menu_button_defs()
	for i: int in range(mini(defs.size(), stack.get_child_count())):
		(stack.get_child(i) as Button).text = String(defs[i]["label"])


## Builds every child node. Public so the headless test can construct the
## screen without a running SceneTree.
func build_ui() -> void:
	_build_background()
	_build_logo()
	_build_utilities()
	_build_menu()


func _build_background() -> void:
	var sky: TextureRect = _pixel_texture_rect("SkyBackground", SKY_TEXTURE)
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sky)

	var village: TextureRect = _pixel_texture_rect("VillageBackdrop", VILLAGE_TEXTURE)
	village.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(village)


func _build_logo() -> void:
	var logo: TextureRect = _pixel_texture_rect("Logo", _logo_texture_path())
	logo.position = LOGO_POSITION
	logo.size = LOGO_SIZE
	add_child(logo)


## The art is exported at 2x logical size; forcing the rect to the logical
## size renders every exported 2x2 block as one screen pixel (NEAREST is the
## project-wide canvas default), keeping the art pixel-crisp.
func _pixel_texture_rect(node_name: String, texture_path: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = node_name
	rect.texture = load(texture_path)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	return rect


static func _logo_texture_path() -> String:
	return String(LOGO_TEXTURES.get(UiLocale.current_locale, LOGO_TEXTURES[UiLocale.DEFAULT_LOCALE]))


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

	# N2-1 secondary affordance: the single-primary-button rule (N5-2) keeps
	# 수행자 선택 out of the menu stack, so it lives in the utility corner.
	var select_character := Button.new()
	select_character.name = "SelectCharacterButton"
	select_character.text = UiLocale.text("title.select_character")
	select_character.tooltip_text = UiLocale.text("title.select_character")
	select_character.custom_minimum_size = Vector2(0, UTILITY_BUTTON_SIZE)
	WoodButton.apply(select_character)
	select_character.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_LABEL)
	select_character.pressed.connect(func() -> void: menu_selected.emit("select_character"))
	row.add_child(select_character)
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
