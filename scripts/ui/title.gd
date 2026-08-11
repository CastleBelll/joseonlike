extends Control
## Title / main menu screen -- JOSEONLIKE's boot destination
## (SceneRouter.goto_title(), core-engine).
##
## asset/UI_ART_REPORT.md item 1: five actions (Start, Continue, Settings,
## Credits, Quit) plus a version plaque. Start/Continue sit in the lower
## thumb zone; Settings/Credits are a secondary row above Quit.

const TITLE_EN: Texture2D = preload("res://asset/title/joseonlike_en.png")
const TITLE_KO: Texture2D = preload("res://asset/title/joseonlike_ko.png")
const BACKDROP: Texture2D = preload("res://asset/stage/backdrops/main_menu.png")
const VERSION_PLAQUE: Texture2D = preload("res://asset/ui/main/version_plaque_9slice.png")

const ICON_START: Texture2D = preload("res://asset/ui/main/start.png")
const ICON_CONTINUE: Texture2D = preload("res://asset/ui/main/continue.png")
const ICON_SETTINGS: Texture2D = preload("res://asset/ui/main/settings.png")
const ICON_CREDITS: Texture2D = preload("res://asset/ui/main/credits.png")
const ICON_QUIT: Texture2D = preload("res://asset/ui/main/quit.png")

## No version-numbering scheme exists yet (project.godot has no app version
## field); this is a placeholder for the plaque, not a real release number.
const VERSION_TEXT := "M1"

@onready var _backdrop: TextureRect = $Backdrop
@onready var _logo: TextureRect = $Logo
@onready var _start_button: Button = $Actions/StartButton
@onready var _continue_button: Button = $Actions/ContinueButton
@onready var _settings_button: Button = $Actions/SecondaryRow/SettingsButton
@onready var _credits_button: Button = $Actions/SecondaryRow/CreditsButton
@onready var _quit_button: Button = $Actions/QuitButton
@onready var _version_plaque: NinePatchRect = $VersionPlaque
@onready var _version_label: Label = $VersionPlaque/VersionLabel
@onready var _credits_panel: Panel = $CreditsPanel
@onready var _credits_body: Label = $CreditsPanel/PanelMargin/PanelBox/CreditsBody
@onready var _credits_close: Button = $CreditsPanel/PanelMargin/PanelBox/CreditsClose

var _return_focus_target: Control = null


func _ready() -> void:
	_backdrop.texture = BACKDROP
	_logo.texture = LocaleText.texture(TITLE_KO, TITLE_EN)

	_configure_action(_start_button, ICON_START, "menu_start")
	_start_button.pressed.connect(_on_start_pressed)

	_configure_action(_continue_button, ICON_CONTINUE, "menu_continue")
	_continue_button.disabled = not _has_existing_profile()
	_continue_button.pressed.connect(_on_start_pressed)

	_configure_action(_settings_button, ICON_SETTINGS, "menu_settings")
	_settings_button.pressed.connect(_on_settings_pressed)

	_configure_action(_credits_button, ICON_CREDITS, "menu_credits")
	_credits_button.pressed.connect(_on_credits_pressed)

	_configure_action(_quit_button, ICON_QUIT, "menu_quit")
	_quit_button.pressed.connect(_on_quit_pressed)

	_version_plaque.texture = VERSION_PLAQUE
	_version_plaque.patch_margin_left = 8
	_version_plaque.patch_margin_top = 8
	_version_plaque.patch_margin_right = 8
	_version_plaque.patch_margin_bottom = 8
	_version_label.text = VERSION_TEXT
	_version_label.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	_version_label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_LABEL)

	_credits_panel.add_theme_stylebox_override("panel", UiPalette.nine_slice_panel())
	_credits_body.text = LocaleText.ui("credits_body")
	_credits_body.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	_credits_close.text = LocaleText.ui("close")
	UiPalette.apply_button_style(_credits_close)
	_credits_close.pressed.connect(_close_credits)
	_credits_panel.visible = false

	(_continue_button if not _continue_button.disabled else _start_button).grab_focus()


## Icon (left) + label (right) inside the existing button chrome, matching
## the pattern already used for camp buildings/character cards.
func _configure_action(button: Button, icon_texture: Texture2D, label_key: String) -> void:
	UiPalette.apply_button_style(button)
	button.custom_minimum_size.y = max(button.custom_minimum_size.y, 56.0)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", UiPalette.SPACING_SM)
	button.add_child(row)

	var icon := TextureRect.new()
	icon.texture = icon_texture
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var label := Label.new()
	label.text = LocaleText.ui(label_key)
	label.add_theme_color_override("font_color", UiPalette.TEXT_ON_DARK)
	label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_BODY)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)


## No multi-slot profile screen exists in M1 (one SaveManager file, not
## slots); a returning player is anyone who has finished at least one run.
func _has_existing_profile() -> bool:
	return AchievementTracker.counter("run_completed") > 0


func _on_start_pressed() -> void:
	UiSound.play_click(self)
	SceneRouter.goto_camp()


func _on_settings_pressed() -> void:
	UiSound.play_click(self)
	SceneRouter.goto_settings()


## No dedicated credits screen exists (or is asked for); a lightweight
## in-place panel matches how camp's building placeholders already work.
func _on_credits_pressed() -> void:
	UiSound.play_click(self)
	_return_focus_target = _credits_button
	_credits_panel.visible = true
	_credits_close.grab_focus()


func _close_credits() -> void:
	UiSound.play_click(self)
	_credits_panel.visible = false
	if is_instance_valid(_return_focus_target):
		_return_focus_target.grab_focus()
	_return_focus_target = null


func _on_quit_pressed() -> void:
	UiSound.play_click(self)
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if _credits_panel.visible and event.is_action_pressed("ui_cancel"):
		_close_credits()
		get_viewport().set_input_as_handled()
