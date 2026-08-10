extends Control
## Base camp hub. Four GDD buildings open a placeholder panel (real
## implementations land after M1); "Start Run" is the entry point into a run
## via character select. Navigation, focus, and back-navigation are real.

## asset/SECOND_ASSET_BATCH_REPORT.md structures handoff.
const SPRITE_WORKSHOP := "res://asset/structure/workshop.png"
const SPRITE_ARCHIVE := "res://asset/structure/archive.png"
const SPRITE_TRAINING_GROUND := "res://asset/structure/training_ground.png"
const SPRITE_SHRINE := "res://asset/structure/camp_shrine.png"
## Scenery dressing for the otherwise-empty gap between the building grid and
## Start Run. Picked two of the eight available pieces (a flanking pair) so
## the accent stays modest on a 540-wide portrait screen; the rest didn't
## clearly improve a screen this tight and were left unused.
const SPRITE_STONE_LANTERN := "res://asset/structure/stone_lantern.png"
const SPRITE_JANGSEUNG_PAIR := "res://asset/structure/jangseung_pair.png"

@onready var _title_label: Label = $CampTitle
@onready var _stone_lantern: TextureRect = $StoneLantern
@onready var _jangseung_pair: TextureRect = $JangseungPair
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

	_configure_building(_workshop_button, "building_workshop", SPRITE_WORKSHOP)
	_configure_building(_archive_button, "building_archive", SPRITE_ARCHIVE)
	_configure_building(_training_button, "building_training_ground", SPRITE_TRAINING_GROUND)
	_configure_building(_shrine_button, "building_shrine", SPRITE_SHRINE)

	_load_texture(_stone_lantern, SPRITE_STONE_LANTERN)
	_load_texture(_jangseung_pair, SPRITE_JANGSEUNG_PAIR)

	_start_run_button.text = LocaleText.ui("start_run")
	UiPalette.apply_button_style(_start_run_button)
	_start_run_button.pressed.connect(_on_start_run_pressed)

	_panel_close.text = LocaleText.ui("close")
	UiPalette.apply_button_style(_panel_close)
	_panel_close.pressed.connect(_close_building_panel)
	_panel_title.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	_panel_title.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_TITLE)
	_panel_body.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	_panel_body.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_BODY)
	_building_panel.add_theme_stylebox_override("panel", UiPalette.nine_slice_panel())
	_building_panel.visible = false

	_workshop_button.grab_focus()


func _configure_building(button: Button, label_key: String, sprite_path: String) -> void:
	button.custom_minimum_size = Vector2(236.0, 128.0)
	UiPalette.apply_button_style(button)
	button.pressed.connect(_open_building_panel.bind(button, label_key))

	var label: Label = button.get_node("Box/Label")
	label.text = LocaleText.ui(label_key)
	label.add_theme_color_override("font_color", UiPalette.TEXT_ON_DARK)
	label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_BODY)
	_load_texture(button.get_node("Box/Icon"), sprite_path)


## Sprite paths are kept defensive: a missing/renamed asset hides the icon
## instead of erroring, since the text label alone still identifies the button.
func _load_texture(target: TextureRect, sprite_path: String) -> void:
	target.texture = load(sprite_path) if ResourceLoader.exists(sprite_path) else null
	target.visible = target.texture != null


func _open_building_panel(source_button: Button, label_key: String) -> void:
	UiSound.play_click(self)
	_return_focus_target = source_button
	_panel_title.text = LocaleText.ui(label_key)
	_panel_body.text = LocaleText.ui("building_placeholder_body")
	_building_panel.visible = true
	_panel_close.grab_focus()


func _close_building_panel() -> void:
	if not _building_panel.visible:
		return
	UiSound.play_click(self)
	_building_panel.visible = false
	if is_instance_valid(_return_focus_target):
		_return_focus_target.grab_focus()
	_return_focus_target = null


func _on_start_run_pressed() -> void:
	UiSound.play_click(self)
	SceneRouter.goto_character_select()


func _unhandled_input(event: InputEvent) -> void:
	if _building_panel.visible and event.is_action_pressed("ui_cancel"):
		_close_building_panel()
		get_viewport().set_input_as_handled()
