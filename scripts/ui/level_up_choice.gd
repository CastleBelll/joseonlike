class_name LevelUpChoiceController
extends CanvasLayer
## Pause-and-choose level-up panel. EventBus-driven only: listens for
## EventBus.level_reached(level, choices) and emits
## EventBus.upgrade_chosen(choice_id) on selection. Handles 1-3 choices (and
## defensively 0) without layout breakage; choices stack vertically in a
## scroll container so extra options never overflow the screen.

const KIND_STYLE := {
	"weapon_new": {"key": "kind_weapon_new", "color": UiPalette.GOLD},
	"weapon_upgrade": {"key": "kind_weapon_upgrade", "color": UiPalette.VERMILION},
	"passive": {"key": "kind_passive", "color": UiPalette.SUCCESS},
}

@onready var _dim: ColorRect = $Dim
@onready var _panel: Panel = $Panel
@onready var _title_label: Label = $Panel/Margin/Box/TitleLabel
@onready var _scroll: ScrollContainer = $Panel/Margin/Box/ScrollContainer
@onready var _choices_box: VBoxContainer = $Panel/Margin/Box/ScrollContainer/ChoicesBox
@onready var _empty_label: Label = $Panel/Margin/Box/EmptyLabel
@onready var _empty_close_button: Button = $Panel/Margin/Box/EmptyCloseButton


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS

	_dim.color = Color(UiPalette.INK.r, UiPalette.INK.g, UiPalette.INK.b, 0.72)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", UiPalette.panel_style(UiPalette.PAPER_DARK, UiPalette.VERMILION, 2, 12))
	_title_label.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	_title_label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_TITLE)
	_empty_label.text = LocaleText.ui("no_choices")
	_empty_label.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	_empty_close_button.text = LocaleText.ui("close")
	UiPalette.apply_button_style(_empty_close_button, UiPalette.PAPER_DARK, UiPalette.TEXT_ON_PAPER)
	_empty_close_button.pressed.connect(_hide_panel)

	visible = false
	EventBus.level_reached.connect(_on_level_reached)


func _on_level_reached(level: int, choices: Array[Dictionary]) -> void:
	_title_label.text = LocaleText.ui("level_up_title_template") % level
	render_choices(choices)
	_show_panel()


## Pure view-model builder -- no scene-tree/node access, so tests can call it
## directly on the class without instancing the scene. kind_label is "" when
## kind doesn't match a known KIND_STYLE entry.
static func build_choice_view_models(choices: Array[Dictionary]) -> Array[Dictionary]:
	var models: Array[Dictionary] = []
	for choice in choices:
		var kind: String = String(choice.get("kind", ""))
		var style: Dictionary = KIND_STYLE.get(kind, {"key": "", "color": UiPalette.LOCKED})
		var style_key: String = String(style.get("key", ""))
		models.append({
			"id": String(choice.get("id", "")),
			"kind": kind,
			"kind_label": LocaleText.ui(style_key) if not style_key.is_empty() else "",
			"color": style.get("color", UiPalette.LOCKED),
			"name": LocaleText.field(choice, "name"),
			"description": LocaleText.field(choice, "description"),
		})
	return models


## Rebuilds the choice cards from `choices`. Exposed (not `_`-prefixed) so
## tests/integration code can drive rendering directly for 1/2/3 choices
## without going through the EventBus signal.
func render_choices(choices: Array[Dictionary]) -> void:
	for child in _choices_box.get_children():
		child.queue_free()

	var has_choices: bool = not choices.is_empty()
	_scroll.visible = has_choices
	_empty_label.visible = not has_choices
	_empty_close_button.visible = not has_choices

	if not has_choices:
		push_warning("LevelUpChoice: level_reached emitted with no choices")
		return

	var first_card: Control = null
	for model in build_choice_view_models(choices):
		var card: Button = _build_choice_card(model)
		_choices_box.add_child(card)
		if first_card == null:
			first_card = card
	if first_card != null:
		first_card.grab_focus()


func _build_choice_card(model: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 96)
	button.focus_mode = Control.FOCUS_ALL
	UiPalette.apply_button_style(button, UiPalette.PAPER, UiPalette.TEXT_ON_PAPER)
	button.pressed.connect(_on_choice_selected.bind(String(model.get("id", ""))))

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", UiPalette.SPACING_XS)
	button.add_child(box)

	var kind_label_text: String = String(model.get("kind_label", ""))
	if not kind_label_text.is_empty():
		var kind_label := Label.new()
		kind_label.text = kind_label_text
		kind_label.add_theme_color_override("font_color", model.get("color", UiPalette.LOCKED))
		kind_label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_LABEL)
		box.add_child(kind_label)

	var name_label := Label.new()
	name_label.text = String(model.get("name", ""))
	name_label.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	name_label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_BODY)
	box.add_child(name_label)

	var description: String = String(model.get("description", ""))
	if description != "???" and not description.is_empty():
		var description_label := Label.new()
		description_label.text = description
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description_label.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
		description_label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_LABEL)
		box.add_child(description_label)

	return button


func _on_choice_selected(choice_id: String) -> void:
	EventBus.upgrade_chosen.emit(choice_id)
	_hide_panel()


func _show_panel() -> void:
	visible = true
	get_tree().paused = true


func _hide_panel() -> void:
	visible = false
	get_tree().paused = false
