extends Control
## Character grid driven by GameData.all_characters(). Locked characters stay
## visible with their unlock condition. Selecting an unlocked character seeds
## RunState and routes into the stage via SceneRouter.

## M1 vertical slice is fixed to Bamboo Forest (ARCHITECTURE.md section 7);
## a stage-select step is out of scope until content expands past M1.
const M1_STAGE_ID := "bamboo_forest"

const CardScene := preload("res://scenes/ui/character_card.tscn")

enum State { LOADING, EMPTY, ERROR, READY }

@onready var _title_label: Label = $Title
@onready var _back_button: Button = $BackButton
@onready var _scroll: ScrollContainer = $ScrollContainer
@onready var _grid: GridContainer = $ScrollContainer/CharacterGrid
@onready var _state_label: Label = $StateLabel

var _first_card: Control = null


func _ready() -> void:
	_title_label.text = LocaleText.ui("character_select_title")
	_title_label.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	_title_label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_TITLE)

	_back_button.text = LocaleText.ui("back_button")
	UiPalette.apply_button_style(_back_button, UiPalette.PAPER_DARK, UiPalette.TEXT_ON_PAPER)
	_back_button.pressed.connect(_on_back_pressed)
	_back_button.custom_minimum_size = Vector2(96, 48)

	_state_label.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	_state_label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_BODY)

	_set_state(State.LOADING)
	_load_characters()


func _load_characters() -> void:
	var characters: Array[Dictionary] = GameData.all_characters()
	if characters.is_empty():
		_set_state(State.EMPTY)
		return

	var valid: Array[Dictionary] = _valid_characters(characters)
	if valid.is_empty():
		push_error("CharacterSelect: all_characters() returned no entries with a usable id/unlock")
		_set_state(State.ERROR)
		return

	_populate_grid(valid)
	_set_state(State.READY)


func _valid_characters(characters: Array[Dictionary]) -> Array[Dictionary]:
	var valid: Array[Dictionary] = []
	for character in characters:
		if String(character.get("id", "")).is_empty():
			continue
		if not (character.get("unlock", {}) is Dictionary):
			continue
		valid.append(character)
	return valid


func _populate_grid(characters: Array[Dictionary]) -> void:
	for child in _grid.get_children():
		child.queue_free()
	_first_card = null

	for character in characters:
		var card: Button = CardScene.instantiate()
		_grid.add_child(card)
		var unlocked: bool = is_character_unlocked(character)
		card.configure(character, unlocked, "" if unlocked else unlock_reason_text(character))
		card.character_selected.connect(_on_character_selected)
		if _first_card == null:
			_first_card = card

	if _first_card != null:
		_first_card.grab_focus()


func is_character_unlocked(character: Dictionary) -> bool:
	var unlock: Dictionary = character.get("unlock", {})
	match String(unlock.get("type", "default")):
		"default":
			return true
		"achievement":
			return AchievementTracker.is_unlocked(String(unlock.get("achievement_id", "")))
		"gold":
			return false
		_:
			return false


func unlock_reason_text(character: Dictionary) -> String:
	var unlock: Dictionary = character.get("unlock", {})
	match String(unlock.get("type", "default")):
		"achievement":
			var achievement_id: String = String(unlock.get("achievement_id", ""))
			var achievement: Dictionary = _find_achievement(achievement_id)
			var display_name: String = LocaleText.field(achievement, "name") if not achievement.is_empty() else achievement_id
			return LocaleText.ui("unlock_achievement_template") % display_name
		"gold":
			return LocaleText.ui("unlock_gold_template") % int(unlock.get("cost", 0))
		_:
			return LocaleText.ui("unlock_unknown")


func _find_achievement(achievement_id: String) -> Dictionary:
	for achievement in GameData.all_achievements():
		if String(achievement.get("id", "")) == achievement_id:
			return achievement
	return {}


func _set_state(state: State) -> void:
	match state:
		State.LOADING:
			_state_label.text = LocaleText.ui("loading_label")
			_state_label.visible = true
			_scroll.visible = false
		State.EMPTY:
			_state_label.text = LocaleText.ui("empty_characters")
			_state_label.visible = true
			_scroll.visible = false
		State.ERROR:
			_state_label.text = LocaleText.ui("error_characters")
			_state_label.visible = true
			_scroll.visible = false
		State.READY:
			_state_label.visible = false
			_scroll.visible = true


func _on_character_selected(character_id: String) -> void:
	AchievementTracker.snapshot_before_run()
	RunState.begin(character_id, M1_STAGE_ID)
	SceneRouter.goto_stage(M1_STAGE_ID)


func _on_back_pressed() -> void:
	SceneRouter.goto_camp()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
