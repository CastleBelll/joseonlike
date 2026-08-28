class_name TitleScreen
extends Control
## Title screen layout (N1-1) with the N1-2 art layers, DESIGN.md §4.
## Sky and village are full-bleed 540x960 textures exported at 2x. The logo
## is set as glowing text (not a baked signboard image) so it re-flows with
## locale instantly and can carry a live pulse animation.
## "start" routes to the stage scene (N3-1); other targets do not exist yet,
## so their presses only emit menu_selected.

signal menu_selected(id: String)

const STAGE_SCENE := "res://scenes/stage.tscn"
const CAMP_SCENE := "res://scenes/camp.tscn"

const SKY_TEXTURE := "res://asset/title/bg_sky.png"
const VILLAGE_TEXTURE := "res://asset/title/bg_village.png"
## N9-157 (owner: 배경을 게임 픽셀 밀도의 픽셀아트로, 가로판도): composed
## per-orientation backdrops; the sky+village pair stays the fallback.
const BACKDROP_PORTRAIT := "res://asset/title/backdrop_portrait.png"
const BACKDROP_LANDSCAPE := "res://asset/title/backdrop_landscape.png"

# Owner direction: logo sits lower than the moon, clear of the rooftops.
const LOGO_TOP_OFFSET := 240.0
const LOGO_HEIGHT := 96.0
const LOGO_FONT_SIZE := 56
const LOGO_OUTLINE_SIZE := 9
const LOGO_GLOW_OUTLINE_SIZE := 20
const LOGO_GLOW_ALPHA_MIN := 0.12
const LOGO_GLOW_ALPHA_MAX := 0.42
const LOGO_PULSE_SEC := 1.8

const MENU_WIDTH_RATIO := 0.85
## N9-153: the menu never grows past the portrait design band on wide screens.
const MENU_MAX_WIDTH := 460.0
const MENU_BUTTON_HEIGHT := 72
const MENU_BUTTON_FONT_SIZE := 26
const MENU_BOTTOM_MARGIN := 48
## Final-verify note: 48 here vs 44 everywhere else — one size for one dial.
const UTILITY_BUTTON_SIZE := 44

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
	_play_music("title")
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
			SceneFadeLayer.go(self, CAMP_SCENE)
			return
		if SaveService.instance != null:
			var routed: String = Ftue.route_character(SaveService.instance.profile)
			if routed != SaveService.instance.selected_character():
				SaveService.instance.set_selected_character(routed)
		SceneFadeLayer.go(self, STAGE_SCENE)
	elif id == "settings" and _settings_popup != null:
		_settings_popup.open()


## Re-applies every locale-sensitive text in place; called when the settings
## popup toggles the language so the change shows immediately.
func refresh_texts() -> void:
	var game_name: String = UiLocale.text("title.game_name")
	(get_node("Logo") as Label).text = game_name
	(get_node("LogoGlow") as Label).text = game_name
	var settings_button: Button = get_node("CornerUtilities/SettingsButton")
	settings_button.tooltip_text = UiLocale.text("title.settings")
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
	if ResourceLoader.exists(BACKDROP_PORTRAIT, "Texture2D"):
		var backdrop: TextureRect = _pixel_texture_rect("Backdrop", _backdrop_path())
		backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(backdrop)
		resized.connect(func() -> void:
			backdrop.texture = load(_backdrop_path()))
		return
	var sky: TextureRect = _pixel_texture_rect("SkyBackground", SKY_TEXTURE)
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sky)

	var village: TextureRect = _pixel_texture_rect("VillageBackdrop", VILLAGE_TEXTURE)
	village.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(village)


## The orientation's own composition when it exists — a landscape crop of a
## portrait painting loses the gate and the moon; a real landscape piece keeps
## both (N9-157).
func _backdrop_path() -> String:
	var wide: bool = size.x > size.y
	if wide and ResourceLoader.exists(BACKDROP_LANDSCAPE, "Texture2D"):
		return BACKDROP_LANDSCAPE
	return BACKDROP_PORTRAIT


## Builds the glowing title text: a soft wide-outline glow layer behind a
## crisp gold label on top, both centered in a full-width band under the
## moon. The glow layer's outline alpha is pulsed in _animate_logo to read
## as a slow breathing light instead of a static signboard.
func _build_logo() -> void:
	var game_name: String = UiLocale.text("title.game_name")

	var glow := _logo_label("LogoGlow", game_name)
	glow.add_theme_color_override("font_color", Color(0, 0, 0, 0))
	glow.add_theme_color_override("font_outline_color", UiPalette.GOLD)
	glow.add_theme_constant_override("outline_size", LOGO_GLOW_OUTLINE_SIZE)
	add_child(glow)

	var logo := _logo_label("Logo", game_name)
	logo.add_theme_color_override("font_color", UiPalette.GOLD)
	logo.add_theme_color_override("font_outline_color", UiPalette.INK)
	logo.add_theme_constant_override("outline_size", LOGO_OUTLINE_SIZE)
	logo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	logo.add_theme_constant_override("shadow_offset_x", 0)
	logo.add_theme_constant_override("shadow_offset_y", 4)
	add_child(logo)

	_animate_logo(glow)


func _logo_label(node_name: String, text: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = LOGO_TOP_OFFSET
	label.offset_bottom = LOGO_TOP_OFFSET + LOGO_HEIGHT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", LOGO_FONT_SIZE)
	return label


## Slow breathing glow: the wide-outline layer's alpha eases between a faint
## and a bright state on an infinite loop (owner direction: "약간 애니메이션").
## No-op outside the SceneTree so the headless build_ui() test stays pure.
func _animate_logo(glow: Label) -> void:
	if not is_inside_tree():
		return
	var tween := create_tween()
	tween.set_loops()
	tween.tween_method(
		func(a: float) -> void:
			glow.add_theme_color_override("font_outline_color", Color(UiPalette.GOLD, a)),
		LOGO_GLOW_ALPHA_MIN, LOGO_GLOW_ALPHA_MAX, LOGO_PULSE_SEC
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(
		func(a: float) -> void:
			glow.add_theme_color_override("font_outline_color", Color(UiPalette.GOLD, a)),
		LOGO_GLOW_ALPHA_MAX, LOGO_GLOW_ALPHA_MIN, LOGO_PULSE_SEC
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## The art is exported at 2x logical size; forcing the rect to the logical
## size renders every exported 2x2 block as one screen pixel (NEAREST is the
## project-wide canvas default), keeping the art pixel-crisp.
func _pixel_texture_rect(node_name: String, texture_path: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = node_name
	rect.texture = load(texture_path)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# N9-153 (owner: 전체화면 가로에서 타이틀이 옆으로 늘어난다): cover, not
	# scale — the portrait art crops to the aspect instead of distorting.
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	return rect


## Owner direction: settings is icon-only (no wood-button chrome), matching
## the flat corner-icon pattern already used by CombatHud's pause button.
## 수행자 선택 is no longer offered from the title — returning players reach
## it from the base camp (Camp.destination_after_title routes them there).
func _build_utilities() -> void:
	var row := HBoxContainer.new()
	row.name = "CornerUtilities"
	# N9-146 (owner: 톱니바퀴는 모든 화면 우측 상단 고정): screen-anchored
	# top-right, matching the combat gear's corner.
	row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	row.position = Vector2(-UTILITY_BUTTON_SIZE - UiPalette.SPACE_MD, UiPalette.SPACE_MD)
	row.add_theme_constant_override("separation", UiPalette.SPACE_SM)

	var settings := Button.new()
	settings.name = "SettingsButton"
	settings.flat = true
	settings.tooltip_text = UiLocale.text("title.settings")
	settings.custom_minimum_size = Vector2(UTILITY_BUTTON_SIZE, UTILITY_BUTTON_SIZE)
	# F40: the HD gear's rim IS the plate — full 44px, same as the HUD dial.
	var icon: TextureRect = UiIcons.icon_rect(UiIcons.hud_icon("settings"), UTILITY_BUTTON_SIZE)
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.position = -icon.custom_minimum_size / 2.0
	settings.add_child(icon)
	settings.pressed.connect(func() -> void: menu_selected.emit("settings"))
	row.add_child(settings)
	add_child(row)


func _build_menu() -> void:
	var stack := VBoxContainer.new()
	stack.name = "MenuButtons"
	stack.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	stack.grow_horizontal = Control.GROW_DIRECTION_BOTH
	stack.custom_minimum_size = Vector2(
		minf(MENU_MAX_WIDTH, size.x * MENU_WIDTH_RATIO if size.x > 0.0 else MENU_MAX_WIDTH),
		0.0
	)
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
		# Owner direction: the sole CTA reads bigger and bolder than the
		# shared WoodButton default (body-text sized, meant for dense rows).
		button.add_theme_font_size_override("font_size", MENU_BUTTON_FONT_SIZE)
		button.pressed.connect(func() -> void: menu_selected.emit(id))
		stack.add_child(button)
	add_child(stack)

	var first_button: Button = stack.get_child(0)
	if first_button.is_inside_tree():
		first_button.grab_focus()


## N9-1a: the autoload is absent in node-free headless tests, so every caller
## goes through this guard rather than assuming music exists.
func _play_music(track_id: String) -> void:
	if MusicService.instance != null:
		MusicService.instance.play(track_id)
