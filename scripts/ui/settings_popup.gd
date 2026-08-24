class_name SettingsPopup
extends CanvasLayer
## Title-screen settings popup (N5-2): chrome paper panel (lattice corners
## baked in, N3-13), split into 게임/오디오 tabs (N1-2-REVISED — owner
## report: the close button spilled past the panel with all rows stacked
## in one column). 게임 holds joystick opacity + language; 오디오 holds the
## three volume sliders. Every change applies immediately through the
## SaveManager autoload; sliders persist on drag end, the toggle right away.
## One wood CTA closes it — no quit button anywhere (mobile).

signal locale_changed
## N9-111: the combat HUD's gear button pauses the tree to open this popup
## and needs the moment it closes to hand the pause back.
signal closed

const LAYER_ABOVE_TITLE := 10
const PANEL_MARGIN_X := 48.0
## Tall enough for the 오디오 tab (3 slider rows), the taller of the two:
## header 72 + margins 64 + tab bar 48 + 3 rows (72 each) + close 64 + gaps.
const PANEL_HEIGHT := 560.0
const HEADER_HEIGHT := 72.0
const BODY_MARGIN := 32.0
const ROW_HEIGHT := 56.0
const SLIDER_STEP := 0.01
const CTA_HEIGHT := 64.0
const TOGGLE_WIDTH := 160.0
const TRACK_RADIUS := 4
const TRACK_MARGIN := 4.0
const TAB_HEIGHT := 48.0
const TAB_CORNER_RADIUS := 10
const TAB_BORDER_WIDTH := 2

const TAB_GAME := "game"
const TAB_AUDIO := "audio"
const TAB_ORDER: Array[String] = [TAB_GAME, TAB_AUDIO]

## Locale display names are intentionally not localized — each language shows
## its own name so the toggle stays readable in either state.
const LOCALE_NAMES := {"ko": "한국어", "en": "English"}

var _root: Control
var _header_label: Label
var _row_labels: Dictionary = {}
var _language_button: Button
var _panel: PanelContainer
var _resolution_button: Button
var _damage_button: Button

## N9-156 window presets (portrait pairs and their landscape twins). "" leaves
## the window as the platform made it.
const RESOLUTIONS: Array[String] = [
	"", "540x960", "810x1440", "1080x1920", "960x540", "1440x810", "1920x1080"
]
var _close_button: Button
var _tab_buttons: Dictionary = {}
var _tab_pages: Dictionary = {}
var _active_tab: String = TAB_GAME


func _ready() -> void:
	# N9-35: this is opened from the combat pause screen, which pauses the whole
	# tree. Without this the panel draws but every slider and toggle is inert,
	# which reads as a frozen game rather than as a settings screen.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = LAYER_ABOVE_TITLE
	_root = Control.new()
	_root.name = "Blocker"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var panel := PanelContainer.new()
	panel.name = "PaperPanel"
	panel.add_theme_stylebox_override("panel", UiIcons.paper_panel())
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	_panel = panel
	_layout_panel()
	_root.add_child(panel)
	_root.resized.connect(_layout_panel)
	var layout := Control.new()
	layout.name = "Layout"
	panel.add_child(layout)
	layout.add_child(_make_header())
	layout.add_child(_make_body())
	_refresh_texts()
	visible = false


## N9-163: the paper clamps inside every viewport (landscape hands us 540
## design px against the 560 portrait height) and caps at the design band.
func _layout_panel() -> void:
	if _panel == null:
		return
	var root_size: Vector2 = _root.size if _root.size.y > 0.0 else Vector2(540, 960)
	var half_h: float = minf(PANEL_HEIGHT, root_size.y - 32.0) / 2.0
	var half_w: float = minf(492.0, root_size.x - PANEL_MARGIN_X * 2.0) / 2.0
	_panel.offset_top = -half_h
	_panel.offset_bottom = half_h
	_panel.offset_left = -half_w
	_panel.offset_right = half_w


func open() -> void:
	_layout_panel()
	visible = true
	_close_button.grab_focus()
	if SfxService.instance != null:
		SfxService.instance.play("ui_open")


func _on_close_pressed() -> void:
	if SfxService.instance != null:
		SfxService.instance.play("ui_close")
	SaveService.instance.save_profile()
	visible = false
	closed.emit()


func _on_slider_changed(key: String, value: float) -> void:
	# Applies live but skips the disk write — drag end persists once.
	SaveService.instance.set_setting(key, value, false)


func _on_slider_drag_ended(changed: bool) -> void:
	if changed:
		SaveService.instance.save_profile()


func _on_language_pressed() -> void:
	var current: String = String(SaveService.instance.get_setting("locale"))
	var next: String = "en" if current == "ko" else "ko"
	SaveService.instance.set_setting("locale", next)
	_refresh_texts()
	locale_changed.emit()


## Locale-sensitive texts live here so the toggle updates the open popup.
func _refresh_texts() -> void:
	_header_label.text = UiLocale.text("settings.title")
	for key: String in _row_labels.keys():
		(_row_labels[key] as Label).text = UiLocale.text("settings." + String(key))
	_language_button.text = String(LOCALE_NAMES[String(SaveService.instance.get_setting("locale"))])
	if _damage_button != null:
		_damage_button.text = UiLocale.text(
			"settings.on" if bool(SaveService.instance.get_setting("show_damage_numbers"))
			else "settings.off"
		)
	if _resolution_button != null:
		var preset: String = String(SaveService.instance.get_setting("resolution"))
		_resolution_button.text = preset if not preset.is_empty() else UiLocale.t("자동")
	_close_button.text = UiLocale.text("settings.close")
	(_tab_buttons[TAB_GAME] as Button).text = UiLocale.text("settings.tab_game")
	(_tab_buttons[TAB_AUDIO] as Button).text = UiLocale.text("settings.tab_audio")


func _make_header() -> Control:
	var header := Control.new()
	header.name = "Header"
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_bottom = HEADER_HEIGHT
	_header_label = _label("", UiPalette.FONT_SIZE_TITLE, UiPalette.INK)
	_header_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_header_label)
	return header


func _make_body() -> Control:
	var body := VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", UiPalette.SPACE_MD)
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.offset_left = BODY_MARGIN
	body.offset_right = -BODY_MARGIN
	body.offset_top = HEADER_HEIGHT
	body.offset_bottom = -BODY_MARGIN

	body.add_child(_make_tab_bar())

	# Owner (itch 전체화면 가로에서 닫기 버튼이 종이 밖으로): the paper clamps to
	# the viewport but a fixed row stack cannot shrink with it. The pages ride
	# in a scroll that absorbs the clamp, so the CTA never leaves the sheet.
	var pages_scroll := ScrollContainer.new()
	pages_scroll.name = "PagesScroll"
	pages_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pages_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var pages := VBoxContainer.new()
	pages.name = "Pages"
	pages.add_theme_constant_override("separation", UiPalette.SPACE_MD)
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages_scroll.add_child(pages)
	body.add_child(pages_scroll)

	var game_page := VBoxContainer.new()
	game_page.name = "GamePage"
	game_page.add_theme_constant_override("separation", UiPalette.SPACE_MD)
	# N6-5: joystick opacity slider — floored so the stick can never be
	# dragged fully invisible by accident.
	game_page.add_child(_make_slider_row(
		SaveProfile.JOYSTICK_OPACITY_KEY, SaveProfile.JOYSTICK_OPACITY_MIN
	))
	game_page.add_child(_make_language_row())
	game_page.add_child(_make_damage_row())
	# The browser and a phone own their window; the preset row is desktop-only.
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		game_page.add_child(_make_resolution_row())
	# N9-159 (owner: itch 풀스크린이 세로 박스만 늘린다): the embed keeps its
	# portrait ratio, so the page's own fullscreen never hands us a wide
	# canvas. The browser fullscreen API does — this button asks for it
	# directly (DisplayServer maps to requestFullscreen on web).
	if OS.has_feature("web"):
		game_page.add_child(_make_fullscreen_row())
	pages.add_child(game_page)
	_tab_pages[TAB_GAME] = game_page

	var audio_page := VBoxContainer.new()
	audio_page.name = "AudioPage"
	audio_page.add_theme_constant_override("separation", UiPalette.SPACE_MD)
	for key: String in SaveProfile.VOLUME_KEYS:
		audio_page.add_child(_make_slider_row(key))
	pages.add_child(audio_page)
	_tab_pages[TAB_AUDIO] = audio_page

	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.custom_minimum_size = Vector2(0.0, CTA_HEIGHT)
	WoodButton.apply(_close_button)
	_close_button.pressed.connect(_on_close_pressed)
	body.add_child(_close_button)

	_select_tab(_active_tab)
	return body


## Owner report: 게임/오디오 rows all in one column pushed the close button
## past the panel edge. Splitting into two pill tabs (bestiary_screen.gd's
## pattern) keeps each page short enough to fit, and groups related
## settings instead of one long list.
func _make_tab_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.name = "TabBar"
	bar.add_theme_constant_override("separation", UiPalette.SPACE_SM)
	for tab: String in TAB_ORDER:
		var button := Button.new()
		button.name = "Tab_" + tab
		button.custom_minimum_size = Vector2(0.0, TAB_HEIGHT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_color_override("font_color", UiPalette.WOOD_TEXT)
		button.add_theme_color_override("font_hover_color", UiPalette.WOOD_TEXT)
		button.add_theme_color_override("font_pressed_color", UiPalette.WOOD_TEXT)
		button.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_LABEL)
		button.pressed.connect(_on_tab_pressed.bind(tab))
		bar.add_child(button)
		_tab_buttons[tab] = button
	return bar


func _on_tab_pressed(tab: String) -> void:
	_select_tab(tab)


func _select_tab(tab: String) -> void:
	_active_tab = tab
	for key: String in _tab_pages.keys():
		(_tab_pages[key] as Control).visible = key == tab
	for key: String in _tab_buttons.keys():
		var button: Button = _tab_buttons[key]
		var style := tab_box(key == tab)
		for state: String in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(state, style)


## Static so the pause popup's tabs (N9-112) share the exact same look.
static func tab_box(selected: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = UiPalette.WOOD if selected else UiPalette.PAPER_CARD
	box.border_color = UiPalette.GOLD if selected else UiPalette.WOOD_BORDER
	box.set_border_width_all(TAB_BORDER_WIDTH)
	box.set_corner_radius_all(TAB_CORNER_RADIUS)
	return box


func _make_slider_row(key: String, min_value: float = 0.0) -> Control:
	var row := VBoxContainer.new()
	row.name = key.to_pascal_case()
	row.add_theme_constant_override("separation", UiPalette.SPACE_XS)
	var name_label := _label("", UiPalette.FONT_SIZE_BODY, UiPalette.TEXT_MUTED_ON_PAPER)
	_row_labels[key] = name_label
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.name = "Slider"
	slider.min_value = min_value
	slider.max_value = 1.0
	slider.step = SLIDER_STEP
	slider.value = float(SaveService.instance.get_setting(key))
	slider.custom_minimum_size = Vector2(0.0, UiPalette.TOUCH_TARGET_MIN)
	slider.add_theme_stylebox_override("slider", _track_style(UiPalette.WOOD_BORDER))
	slider.add_theme_stylebox_override("grabber_area", _track_style(UiPalette.WOOD))
	slider.add_theme_stylebox_override("grabber_area_highlight", _track_style(UiPalette.WOOD_HOVER))
	slider.value_changed.connect(func(value: float) -> void: _on_slider_changed(key, value))
	slider.drag_ended.connect(_on_slider_drag_ended)
	row.add_child(slider)
	return row


func _make_damage_row() -> Control:
	var row := HBoxContainer.new()
	row.name = "DamageRow"
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	var name_label := _label("", UiPalette.FONT_SIZE_BODY, UiPalette.TEXT_MUTED_ON_PAPER)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_row_labels["damage_numbers"] = name_label
	row.add_child(name_label)
	_damage_button = Button.new()
	_damage_button.name = "DamageButton"
	_damage_button.custom_minimum_size = Vector2(TOGGLE_WIDTH, UiPalette.TOUCH_TARGET_MIN)
	WoodButton.apply(_damage_button)
	_damage_button.pressed.connect(_on_damage_pressed)
	row.add_child(_damage_button)
	return row


func _on_damage_pressed() -> void:
	var current: bool = bool(SaveService.instance.get_setting("show_damage_numbers"))
	SaveService.instance.set_setting("show_damage_numbers", not current)
	_refresh_texts()


func _make_resolution_row() -> Control:
	var row := HBoxContainer.new()
	row.name = "ResolutionRow"
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	var name_label := _label("", UiPalette.FONT_SIZE_BODY, UiPalette.TEXT_MUTED_ON_PAPER)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_row_labels["resolution"] = name_label
	row.add_child(name_label)
	_resolution_button = Button.new()
	_resolution_button.name = "ResolutionButton"
	_resolution_button.custom_minimum_size = Vector2(TOGGLE_WIDTH, UiPalette.TOUCH_TARGET_MIN)
	WoodButton.apply(_resolution_button)
	_resolution_button.pressed.connect(_on_resolution_pressed)
	row.add_child(_resolution_button)
	return row


func _on_resolution_pressed() -> void:
	var current: String = String(SaveService.instance.get_setting("resolution"))
	var index: int = RESOLUTIONS.find(current)
	var next: String = RESOLUTIONS[(index + 1) % RESOLUTIONS.size()]
	SaveService.instance.set_setting("resolution", next)
	DisplayAdapterService.apply_resolution(next)
	_refresh_texts()


func _make_fullscreen_row() -> Control:
	var row := HBoxContainer.new()
	row.name = "FullscreenRow"
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	var name_label := _label("", UiPalette.FONT_SIZE_BODY, UiPalette.TEXT_MUTED_ON_PAPER)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_row_labels["fullscreen"] = name_label
	row.add_child(name_label)
	var button := Button.new()
	button.name = "FullscreenButton"
	button.custom_minimum_size = Vector2(TOGGLE_WIDTH, UiPalette.TOUCH_TARGET_MIN)
	WoodButton.apply(button)
	button.text = UiLocale.t("전환")
	button.pressed.connect(_on_fullscreen_pressed)
	row.add_child(button)
	return row


func _on_fullscreen_pressed() -> void:
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _make_language_row() -> Control:
	var row := HBoxContainer.new()
	row.name = "LanguageRow"
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	var name_label := _label("", UiPalette.FONT_SIZE_BODY, UiPalette.TEXT_MUTED_ON_PAPER)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_row_labels["language"] = name_label
	row.add_child(name_label)
	_language_button = Button.new()
	_language_button.name = "LanguageButton"
	_language_button.custom_minimum_size = Vector2(TOGGLE_WIDTH, UiPalette.TOUCH_TARGET_MIN)
	WoodButton.apply(_language_button)
	_language_button.pressed.connect(_on_language_pressed)
	row.add_child(_language_button)
	return row


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _track_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(TRACK_RADIUS)
	# Keeps the visible track slim inside the 44px touch target.
	style.content_margin_top = TRACK_MARGIN
	style.content_margin_bottom = TRACK_MARGIN
	return style
