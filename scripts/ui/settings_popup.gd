class_name SettingsPopup
extends CanvasLayer
## Title-screen settings popup (N5-2): chrome paper panel (lattice corners
## baked in, N3-13), three volume sliders (master/music/effects) and a
## 한국어/English toggle. Every change applies immediately through the
## SaveManager autoload; sliders persist on drag end, the toggle right away.
## One wood CTA closes it — no quit button anywhere (mobile).

signal locale_changed

const LAYER_ABOVE_TITLE := 10
const PANEL_MARGIN_X := 48.0
# N6-5: grew from 480 to fit the fourth slider row (joystick opacity).
const PANEL_HEIGHT := 570.0
const HEADER_HEIGHT := 72.0
const BODY_MARGIN := 32.0
const ROW_HEIGHT := 56.0
const SLIDER_STEP := 0.01
const CTA_HEIGHT := 64.0
const TOGGLE_WIDTH := 160.0
const TRACK_RADIUS := 4
const TRACK_MARGIN := 4.0

## Locale display names are intentionally not localized — each language shows
## its own name so the toggle stays readable in either state.
const LOCALE_NAMES := {"ko": "한국어", "en": "English"}

var _root: Control
var _header_label: Label
var _row_labels: Dictionary = {}
var _language_button: Button
var _close_button: Button


func _ready() -> void:
	layer = LAYER_ABOVE_TITLE
	_root = Control.new()
	_root.name = "Blocker"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var panel := PanelContainer.new()
	panel.name = "PaperPanel"
	panel.add_theme_stylebox_override("panel", UiIcons.paper_panel())
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = PANEL_MARGIN_X
	panel.offset_right = -PANEL_MARGIN_X
	panel.offset_top = -PANEL_HEIGHT / 2.0
	panel.offset_bottom = PANEL_HEIGHT / 2.0
	_root.add_child(panel)
	var layout := Control.new()
	layout.name = "Layout"
	panel.add_child(layout)
	layout.add_child(_make_header())
	layout.add_child(_make_body())
	_refresh_texts()
	visible = false


func open() -> void:
	visible = true
	_close_button.grab_focus()


func _on_close_pressed() -> void:
	SaveService.instance.save_profile()
	visible = false


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
	_close_button.text = UiLocale.text("settings.close")


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
	for key: String in SaveProfile.VOLUME_KEYS:
		body.add_child(_make_slider_row(key))
	# N6-5: joystick opacity slider — floored so the stick can never be
	# dragged fully invisible by accident.
	body.add_child(_make_slider_row(
		SaveProfile.JOYSTICK_OPACITY_KEY, SaveProfile.JOYSTICK_OPACITY_MIN
	))
	body.add_child(_make_language_row())
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.custom_minimum_size = Vector2(0.0, CTA_HEIGHT)
	WoodButton.apply(_close_button)
	_close_button.pressed.connect(_on_close_pressed)
	body.add_child(_close_button)
	return body


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
