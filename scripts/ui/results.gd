extends Control
## End-of-run summary. change_scene_to_file() cannot pass arguments, so
## SceneRouter.goto_results(result) stashes a deep copy in
## SceneRouter.last_result and this reads it back in _ready(). That stash
## persists after this screen closes, so treat it defensively: an empty
## dictionary (direct scene load, a second visit) renders the empty state
## instead of a summary of zeros.
##
## asset/UI_ART_REPORT.md item 9: the rising-sun/laurel victory banner and
## broken-wreath/moon defeat banner carry the outcome structurally (shape,
## not colour); TitleLabel's text stays alongside it rather than replacing
## it, since an icon/banner never substitutes for the text it pairs with
## elsewhere in this project (locked-state, achievement rows, etc).

const VICTORY_BANNER: Texture2D = preload("res://asset/ui/results/victory_banner.png")
const DEFEAT_BANNER: Texture2D = preload("res://asset/ui/results/defeat_banner.png")
const ICON_REWARD_CHEST: Texture2D = preload("res://asset/ui/results/reward_chest.png")
const ICON_NEW_UNLOCK: Texture2D = preload("res://asset/ui/results/new_unlock.png")
const REWARD_CALLOUT: Texture2D = preload("res://asset/ui/results/reward_callout_9slice.png")
const UNLOCK_CALLOUT: Texture2D = preload("res://asset/ui/results/unlock_callout_9slice.png")
const CALLOUT_MARGIN := 10

@onready var _empty_label: Label = $EmptyLabel
@onready var _content_root: VBoxContainer = $ContentRoot
@onready var _banner: TextureRect = $ContentRoot/Banner
@onready var _title_label: Label = $ContentRoot/TitleLabel
@onready var _time_label: Label = $ContentRoot/StatsBox/TimeLabel
@onready var _kills_label: Label = $ContentRoot/StatsBox/KillsLabel
@onready var _gold_callout: PanelContainer = $ContentRoot/StatsBox/GoldCallout
@onready var _gold_icon: TextureRect = $ContentRoot/StatsBox/GoldCallout/GoldRow/GoldIcon
@onready var _gold_label: Label = $ContentRoot/StatsBox/GoldCallout/GoldRow/GoldLabel
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
	UiPalette.apply_button_style(_return_button)
	_return_button.pressed.connect(_on_return_pressed)

	_gold_icon.texture = ICON_REWARD_CHEST
	_gold_callout.add_theme_stylebox_override("panel", _callout_style(REWARD_CALLOUT))
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
	_banner.texture = VICTORY_BANNER if victory else DEFEAT_BANNER
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
		_achievements_box.add_child(_build_achievement_row(achievement))


func _build_achievement_row(achievement: Dictionary) -> Control:
	var callout := PanelContainer.new()
	callout.add_theme_stylebox_override("panel", _callout_style(UNLOCK_CALLOUT))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiPalette.SPACING_SM)
	callout.add_child(row)

	var unlock_icon := TextureRect.new()
	unlock_icon.texture = ICON_NEW_UNLOCK
	unlock_icon.custom_minimum_size = Vector2(20, 20)
	unlock_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(unlock_icon)

	var icon_texture: Texture2D = UiPalette.achievement_icon(String(achievement.get("id", "")))
	if icon_texture != null:
		var icon := TextureRect.new()
		icon.texture = icon_texture
		icon.custom_minimum_size = Vector2(32, 32)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)

	var label := Label.new()
	label.text = LocaleText.field(achievement, "name")
	label.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_BODY)
	row.add_child(label)

	return callout


func _callout_style(texture: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = CALLOUT_MARGIN
	style.texture_margin_right = CALLOUT_MARGIN
	style.texture_margin_top = CALLOUT_MARGIN
	style.texture_margin_bottom = CALLOUT_MARGIN
	return style


func _format_time(seconds: float) -> String:
	var total: int = int(seconds)
	return "%02d:%02d" % [total / 60, total % 60]


func _on_return_pressed() -> void:
	UiSound.play_click(self)
	SceneRouter.goto_camp()
