extends Control
## Audio + language settings. Only reachable from the title screen (never
## mid-run -- routing through SceneRouter frees the current scene, which
## would silently abandon a live stage, so this is not offered from the
## in-run pause overlay; see hud.gd).
##
## asset/UI_ART_REPORT.md item 8: master/music/effects volume sliders using
## slider_{track,fill}_9slice.png + slider_knob.png, and a language toggle
## using toggle_{off,on}.png.
##
## Volumes persist via SaveManager.get_value/set_value (the frozen general
## key/value store already used by scripts/meta/achievements.gd). The
## project defines no "Music"/"Effects" audio buses yet -- only the engine's
## default "Master" bus exists (no custom bus layout in project.godot) -- so
## those two sliders persist their value and apply it the moment a bus by
## that name exists, but have no audible effect today. Reported to the
## coordinator as a gap rather than silently faking a working slider.

const ICON_DIR := "res://asset/ui/settings"
const SLIDER_TRACK: Texture2D = preload("res://asset/ui/settings/slider_track_9slice.png")
const SLIDER_FILL: Texture2D = preload("res://asset/ui/settings/slider_fill_9slice.png")
const SLIDER_KNOB: Texture2D = preload("res://asset/ui/settings/slider_knob.png")
const TOGGLE_OFF: Texture2D = preload("res://asset/ui/settings/toggle_off.png")
const TOGGLE_ON: Texture2D = preload("res://asset/ui/settings/toggle_on.png")
const SLIDER_MARGIN := 6

const BUS_ROWS := [
	{"id": "master_audio", "bus": "Master", "label_key": "settings_master_volume"},
	{"id": "music", "bus": "Music", "label_key": "settings_music_volume"},
	{"id": "effects", "bus": "Effects", "label_key": "settings_effects_volume"},
]
const VOLUME_SAVE_PREFIX := "settings_volume_"
const LANGUAGE_SAVE_KEY := "settings_language"

@onready var _title_label: Label = $Title
@onready var _back_button: Button = $BackButton
@onready var _sliders_box: VBoxContainer = $ScrollContainer/Box/SlidersBox
@onready var _language_icon: TextureRect = $ScrollContainer/Box/LanguageRow/LanguageIcon
@onready var _language_label: Label = $ScrollContainer/Box/LanguageRow/LanguageLabel
@onready var _language_toggle: TextureButton = $ScrollContainer/Box/LanguageRow/LanguageToggle

var _row_labels: Array[Label] = []


func _ready() -> void:
	_title_label.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	_title_label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_TITLE)

	UiPalette.apply_button_style(_back_button)
	_back_button.pressed.connect(_on_back_pressed)

	_build_volume_rows()
	_setup_language_row()
	_apply_locale_text()


func _build_volume_rows() -> void:
	for row in BUS_ROWS:
		_sliders_box.add_child(_build_volume_row(row))


func _build_volume_row(row: Dictionary) -> Control:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", UiPalette.SPACING_XS)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", UiPalette.SPACING_SM)
	container.add_child(header)

	var icon := TextureRect.new()
	icon.texture = _icon(String(row["id"]))
	icon.custom_minimum_size = Vector2(24, 24)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(icon)

	var label := Label.new()
	label.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_BODY)
	header.add_child(label)
	_row_labels.append(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(0, UiPalette.TOUCH_TARGET_MIN)
	slider.add_theme_stylebox_override("slider", _nine_slice(SLIDER_TRACK, SLIDER_MARGIN))
	slider.add_theme_stylebox_override("grabber_area", _nine_slice(SLIDER_FILL, SLIDER_MARGIN))
	slider.add_theme_stylebox_override("grabber_area_highlight", _nine_slice(SLIDER_FILL, SLIDER_MARGIN))
	slider.add_theme_icon_override("grabber", SLIDER_KNOB)
	slider.add_theme_icon_override("grabber_highlight", SLIDER_KNOB)
	slider.add_theme_icon_override("grabber_disabled", SLIDER_KNOB)
	container.add_child(slider)

	var bus_name: String = String(row["bus"])
	slider.value = float(SaveManager.get_value(VOLUME_SAVE_PREFIX + bus_name, 1.0))
	_apply_bus_volume(bus_name, slider.value)
	slider.value_changed.connect(_on_volume_changed.bind(bus_name))

	return container


func _on_volume_changed(value: float, bus_name: String) -> void:
	SaveManager.set_value(VOLUME_SAVE_PREFIX + bus_name, value)
	_apply_bus_volume(bus_name, value)


## Bus may not exist yet (see header comment); the value still persists.
func _apply_bus_volume(bus_name: String, linear_volume: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(max(linear_volume, 0.0001)))


func _setup_language_row() -> void:
	_language_icon.texture = _icon("language")
	_language_label.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	_language_label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_BODY)

	_language_toggle.texture_normal = TOGGLE_OFF
	_language_toggle.texture_pressed = TOGGLE_ON
	_language_toggle.toggle_mode = true
	_language_toggle.custom_minimum_size = Vector2(UiPalette.TOUCH_TARGET_MIN, UiPalette.TOUCH_TARGET_MIN)
	_language_toggle.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED

	var saved_locale: String = String(SaveManager.get_value(LANGUAGE_SAVE_KEY, TranslationServer.get_locale()))
	_language_toggle.button_pressed = saved_locale.begins_with("ko")
	TranslationServer.set_locale("ko" if _language_toggle.button_pressed else "en")
	_language_toggle.toggled.connect(_on_language_toggled)


func _on_language_toggled(is_korean: bool) -> void:
	UiSound.play_click(self)
	TranslationServer.set_locale("ko" if is_korean else "en")
	SaveManager.set_value(LANGUAGE_SAVE_KEY, "ko" if is_korean else "en")
	_apply_locale_text()


func _apply_locale_text() -> void:
	_title_label.text = LocaleText.ui("settings_title")
	_back_button.text = LocaleText.ui("back_button")
	_language_label.text = LocaleText.ui("settings_language")
	for i in range(BUS_ROWS.size()):
		_row_labels[i].text = LocaleText.ui(String(BUS_ROWS[i]["label_key"]))


func _icon(id: String) -> Texture2D:
	var path: String = "%s/%s.png" % [ICON_DIR, id]
	return load(path) if ResourceLoader.exists(path) else null


func _nine_slice(texture: Texture2D, margin: int) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = margin
	style.texture_margin_right = margin
	style.texture_margin_top = margin
	style.texture_margin_bottom = margin
	return style


func _on_back_pressed() -> void:
	UiSound.play_click(self)
	SceneRouter.goto_title()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
