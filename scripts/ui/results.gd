extends Control
## End-of-run summary. change_scene_to_file() cannot pass arguments, so
## SceneRouter.goto_results(result) stashes a deep copy in
## SceneRouter.last_result and this reads it back in _ready(). That stash
## persists after this screen closes, so treat it defensively: an empty
## dictionary (direct scene load, a second visit) renders the empty state
## instead of a summary of zeros.

@onready var _empty_label: Label = $EmptyLabel
@onready var _content_root: VBoxContainer = $ContentRoot
@onready var _title_label: Label = $ContentRoot/TitleLabel
@onready var _time_label: Label = $ContentRoot/StatsBox/TimeLabel
@onready var _kills_label: Label = $ContentRoot/StatsBox/KillsLabel
@onready var _gold_label: Label = $ContentRoot/StatsBox/GoldLabel
@onready var _achievements_title_label: Label = $ContentRoot/AchievementsTitleLabel
@onready var _achievements_box: VBoxContainer = $ContentRoot/ScrollContainer/AchievementsBox
@onready var _return_button: Button = $ContentRoot/ReturnButton


func _ready() -> void:
	_empty_label.text = LocaleText.ui("no_result_data")
	_empty_label.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	_achievements_title_label.text = LocaleText.ui("new_achievements_label")
	_achievements_title_label.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)

	_return_button.text = LocaleText.ui("return_to_camp")
	_return_button.custom_minimum_size = Vector2(0, 56)
	UiPalette.apply_button_style(_return_button, UiPalette.VERMILION_DARK, UiPalette.TEXT_ON_DARK)
	_return_button.pressed.connect(_on_return_pressed)

	for label in [_time_label, _kills_label, _gold_label]:
		label.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
		label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_BODY)

	display_result(SceneRouter.last_result)
	_return_button.grab_focus()


## Exposed (not `_`-prefixed) so tests can drive rendering without going
## through SceneRouter.
func display_result(result: Dictionary) -> void:
	var has_result: bool = not result.is_empty()
	_content_root.visible = has_result
	_empty_label.visible = not has_result
	if not has_result:
		return

	var victory: bool = bool(result.get("victory", false))
	_title_label.text = LocaleText.ui("victory_title") if victory else LocaleText.ui("defeat_title")
	_title_label.add_theme_color_override("font_color", UiPalette.SUCCESS if victory else UiPalette.DANGER)
	_title_label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_TITLE)

	_time_label.text = "%s %s" % [LocaleText.ui("time_label"), _format_time(float(result.get("time_sec", 0.0)))]
	_kills_label.text = "%s %d" % [LocaleText.ui("kills_label"), int(result.get("kills", 0))]
	_gold_label.text = "%s %d" % [LocaleText.ui("gold_label"), int(result.get("gold", 0))]

	_render_achievements()


func _render_achievements() -> void:
	for child in _achievements_box.get_children():
		child.queue_free()

	var newly: Array[Dictionary] = AchievementTracker.newly_unlocked_since_snapshot()
	if newly.is_empty():
		var empty_row := Label.new()
		empty_row.text = LocaleText.ui("no_new_achievements")
		empty_row.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
		_achievements_box.add_child(empty_row)
		return

	for achievement in newly:
		var row := Label.new()
		row.text = "\U0001F3C6 %s" % LocaleText.field(achievement, "name")
		row.add_theme_color_override("font_color", UiPalette.GOLD)
		row.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_BODY)
		_achievements_box.add_child(row)


func _format_time(seconds: float) -> String:
	var total: int = int(seconds)
	return "%02d:%02d" % [total / 60, total % 60]


func _on_return_pressed() -> void:
	SceneRouter.goto_camp()
