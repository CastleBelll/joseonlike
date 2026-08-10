extends Control
## Base camp hub. Four GDD buildings open a placeholder panel (real
## implementations land after M1); "Start Run" is the entry point into a run
## via character select. Navigation, focus, and back-navigation are real.

@onready var _title_label: Label = $CampTitle
@onready var _workshop_button: Button = $BuildingGrid/WorkshopButton
@onready var _archive_button: Button = $BuildingGrid/ArchiveButton
@onready var _training_button: Button = $BuildingGrid/TrainingGroundButton
@onready var _shrine_button: Button = $BuildingGrid/ShrineButton
@onready var _start_run_button: Button = $StartRunButton
@onready var _building_panel: Panel = $BuildingPanel
@onready var _panel_title: Label = $BuildingPanel/PanelMargin/PanelBox/BuildingPanelTitle
@onready var _panel_body: Label = $BuildingPanel/PanelMargin/PanelBox/BuildingPanelBody
@onready var _panel_close: Button = $BuildingPanel/PanelMargin/PanelBox/BuildingPanelClose

var _return_focus_target: Control = null


func _ready() -> void:
	_title_label.text = LocaleText.ui("camp_title")
	_title_label.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	_title_label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_TITLE)

	_configure_building(_workshop_button, "building_workshop")
	_configure_building(_archive_button, "building_archive")
	_configure_building(_training_button, "building_training_ground")
	_configure_building(_shrine_button, "building_shrine")

	_start_run_button.text = LocaleText.ui("start_run")
	UiPalette.apply_button_style(_start_run_button, UiPalette.VERMILION_DARK, UiPalette.TEXT_ON_DARK)
	_start_run_button.pressed.connect(_on_start_run_pressed)

	_panel_close.text = LocaleText.ui("close")
	UiPalette.apply_button_style(_panel_close, UiPalette.PAPER_DARK, UiPalette.TEXT_ON_PAPER)
	_panel_close.pressed.connect(_close_building_panel)
	_panel_title.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	_panel_title.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_TITLE)
	_panel_body.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	_panel_body.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_BODY)
	_building_panel.add_theme_stylebox_override("panel", UiPalette.panel_style(UiPalette.PAPER_DARK, UiPalette.VERMILION, 2, 12))
	_building_panel.visible = false

	_workshop_button.grab_focus()


func _configure_building(button: Button, label_key: String) -> void:
	button.text = LocaleText.ui(label_key)
	button.custom_minimum_size = Vector2(236.0, 128.0)
	UiPalette.apply_button_style(button, UiPalette.PAPER_DARK, UiPalette.TEXT_ON_PAPER)
	button.pressed.connect(_open_building_panel.bind(button, label_key))


func _open_building_panel(source_button: Button, label_key: String) -> void:
	_return_focus_target = source_button
	_panel_title.text = LocaleText.ui(label_key)
	_panel_body.text = LocaleText.ui("building_placeholder_body")
	_building_panel.visible = true
	_panel_close.grab_focus()


func _close_building_panel() -> void:
	if not _building_panel.visible:
		return
	_building_panel.visible = false
	if is_instance_valid(_return_focus_target):
		_return_focus_target.grab_focus()
	_return_focus_target = null


func _on_start_run_pressed() -> void:
	SceneRouter.goto_character_select()


func _unhandled_input(event: InputEvent) -> void:
	if _building_panel.visible and event.is_action_pressed("ui_cancel"):
		_close_building_panel()
		get_viewport().set_input_as_handled()
