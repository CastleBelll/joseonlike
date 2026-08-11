extends Control
## Achievement and quest list. Achievements are fully data-driven from
## GameData.all_achievements() + AchievementTracker (icon, progress bar,
## locked/unlocked state). Quests render an honest empty state instead of
## fabricated rows: QuestTracker (scripts/meta/quests.gd) already tracks raw
## daily/story counters and claim flags, but no quest content file exists
## yet (data/quests.json is explicitly "not part of the frozen schema" per
## quests.gd's own header) -- there is no id/name/target list to enumerate.
## Reported to the coordinator as a content gap rather than inventing quest
## names this screen would have no real data behind.

@onready var _title_label: Label = $Title
@onready var _back_button: Button = $BackButton
@onready var _achievements_title_label: Label = $ScrollContainer/Box/AchievementsTitleLabel
@onready var _achievements_box: VBoxContainer = $ScrollContainer/Box/AchievementsBox
@onready var _quests_title_label: Label = $ScrollContainer/Box/QuestsTitleLabel
@onready var _quests_empty_label: Label = $ScrollContainer/Box/QuestsEmptyLabel


func _ready() -> void:
	_title_label.text = LocaleText.ui("achievements_quests_title")
	_title_label.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	_title_label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_TITLE)

	UiPalette.apply_button_style(_back_button)
	_back_button.pressed.connect(_on_back_pressed)

	_achievements_title_label.text = LocaleText.ui("achievements_section_title")
	_achievements_title_label.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	_achievements_title_label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_BODY)

	_quests_title_label.text = LocaleText.ui("quests_section_title")
	_quests_title_label.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	_quests_title_label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_BODY)
	_quests_empty_label.text = LocaleText.ui("quests_coming_soon")
	_quests_empty_label.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)

	_render_achievements()


func _render_achievements() -> void:
	for child in _achievements_box.get_children():
		child.queue_free()

	var achievements: Array[Dictionary] = GameData.all_achievements()
	for achievement in achievements:
		_achievements_box.add_child(_build_achievement_row(achievement))


func _build_achievement_row(achievement: Dictionary) -> Control:
	var achievement_id: String = String(achievement.get("id", ""))
	var unlocked: bool = AchievementTracker.is_unlocked(achievement_id)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiPalette.nine_slice_panel())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiPalette.SPACING_SM)
	card.add_child(row)

	var icon_texture: Texture2D = UiPalette.achievement_icon(achievement_id)
	if icon_texture != null:
		var icon := TextureRect.new()
		icon.texture = icon_texture
		icon.custom_minimum_size = Vector2(32, 32)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = Color.WHITE if unlocked else UiPalette.DISABLED_TINT
		row.add_child(icon)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", UiPalette.SPACING_XS)
	row.add_child(box)

	var name_label := Label.new()
	name_label.text = LocaleText.field(achievement, "name")
	name_label.add_theme_color_override("font_color", UiPalette.TEXT_ON_DARK)
	name_label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_BODY)
	box.add_child(name_label)

	var target: int = int(achievement.get("target", 0))
	var counter_key: String = String(achievement.get("counter_key", ""))
	var progress: int = AchievementTracker.counter(counter_key) if not counter_key.is_empty() else 0

	var progress_bar := ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 12)
	progress_bar.show_percentage = false
	progress_bar.max_value = max(target, 1)
	progress_bar.value = clampi(progress, 0, max(target, 1))
	progress_bar.add_theme_stylebox_override("background", UiPalette.panel_style(UiPalette.INK.lerp(Color.BLACK, 0.2), Color.TRANSPARENT, 0, 4))
	progress_bar.add_theme_stylebox_override("fill", UiPalette.panel_style(UiPalette.GOLD, Color.TRANSPARENT, 0, 4))
	box.add_child(progress_bar)

	var progress_label := Label.new()
	progress_label.text = "%d / %d" % [min(progress, target), target]
	progress_label.add_theme_color_override("font_color", UiPalette.TEXT_ON_DARK)
	progress_label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_LABEL)
	box.add_child(progress_label)

	var state_icon := TextureRect.new()
	state_icon.texture = UiPalette.ICON_CHECK if unlocked else UiPalette.ICON_LOCK
	state_icon.custom_minimum_size = Vector2(24, 24)
	state_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(state_icon)

	return card


func _on_back_pressed() -> void:
	UiSound.play_click(self)
	SceneRouter.goto_camp()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
