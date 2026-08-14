class_name LevelUpChoiceController
extends CanvasLayer
## Pause-and-choose level-up panel. EventBus-driven only: listens for
## EventBus.level_reached(level, choices) and emits
## EventBus.upgrade_chosen(choice_id) on selection. Handles 1-3 choices (and
## defensively 0) without layout breakage; choices stack vertically in a
## scroll container so extra options never overflow the screen.

## Per-kind text color coding was removed: GOLD/VERMILION/SUCCESS all fail
## WCAG AA against the vermilion button chrome (checked -- see
## asset/M1_ASSET_REPORT.md). Kind stays distinguishable via its own label
## text (unchanged) plus a passive icon for "passive" choices.
const KIND_LABEL_KEYS := {
	"weapon_new": "kind_weapon_new",
	"weapon_upgrade": "kind_weapon_upgrade",
	"passive": "kind_passive",
}

## asset/UI_ART_REPORT.md item 7: card_{tier}_9slice.png (96x64) and
## tier_{tier}.png (32x32) so a rare pick reads as rare without relying on
## colour alone (common = one corner notch, rare = two, legendary =
## crown/three-notched top). data/weapons.json's "grade" field ("common",
## "rare", "epic") is the closest existing tier signal -- reused rather than
## adding a new core field, with "epic" read as the top "legendary" art tier.
## Passives carry no grade in data/passives.json, so they render at the
## common tier (they are small incremental stat bumps, never a headline pick).
const GRADE_TO_TIER := {
	"common": "common",
	"rare": "rare",
	"epic": "legendary",
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
	_panel.add_theme_stylebox_override("panel", UiPalette.nine_slice_panel())
	_title_label.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	_title_label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_TITLE)
	_empty_label.text = LocaleText.ui("no_choices")
	_empty_label.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	_empty_close_button.text = LocaleText.ui("close")
	UiPalette.apply_button_style(_empty_close_button)
	_empty_close_button.pressed.connect(_hide_panel)

	visible = false
	EventBus.level_reached.connect(_on_level_reached)


func _on_level_reached(level: int, choices: Array[Dictionary]) -> void:
	_title_label.text = LocaleText.ui("level_up_title_template") % level
	render_choices(choices)
	_show_panel()


## Pure view-model builder -- no scene-tree/node access, so tests can call it
## directly on the class without instancing the scene. kind_label is "" when
## kind doesn't match a known KIND_LABEL_KEYS entry.
static func build_choice_view_models(choices: Array[Dictionary]) -> Array[Dictionary]:
	var models: Array[Dictionary] = []
	for choice in choices:
		var kind: String = String(choice.get("kind", ""))
		var choice_id: String = String(choice.get("id", ""))
		var label_key: String = String(KIND_LABEL_KEYS.get(kind, ""))
		models.append({
			"id": choice_id,
			"kind": kind,
			"kind_label": LocaleText.ui(label_key) if not label_key.is_empty() else "",
			"name": LocaleText.field(choice, "name"),
			"description": LocaleText.field(choice, "description"),
			# Passive choice ids are the passive_id itself (RunState._passive_choices),
			# so the icon lookup can key off it directly.
			"icon": UiPalette.passive_icon(choice_id) if kind == "passive" else null,
			"tier": _tier_for(kind, choice_id),
		})
	return models


## weapon_new/weapon_upgrade choice ids are the weapon_id itself
## (RunState._weapon_upgrade_choices/_new_weapon_choices), so the tier reads
## straight off data/weapons.json's "grade" field for those two kinds.
static func _tier_for(kind: String, choice_id: String) -> String:
	if kind == "weapon_new" or kind == "weapon_upgrade":
		var weapon: Dictionary = GameData.weapon(choice_id)
		var grade: String = String(weapon.get("grade", "common"))
		return String(GRADE_TO_TIER.get(grade, "common"))
	return "common"


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


## DESIGN.md selection-card grammar: bright paper card with a vermilion
## frame, a square dark icon well on the left, big name + data description,
## and a grade pill in text (never colour alone) on the right.
func _build_choice_card(model: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 104)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_stylebox_override("normal", UiPalette.panel_style(UiPalette.PAPER.lightened(0.45), UiPalette.VERMILION, 3, 10))
	button.add_theme_stylebox_override("hover", UiPalette.panel_style(UiPalette.PAPER.lightened(0.6), UiPalette.VERMILION, 3, 10))
	button.add_theme_stylebox_override("pressed", UiPalette.panel_style(UiPalette.PAPER.lightened(0.3), UiPalette.VERMILION, 3, 10))
	button.add_theme_stylebox_override("focus", UiPalette.panel_style(Color.TRANSPARENT, UiPalette.GOLD, 3, 10))
	button.pressed.connect(_on_choice_selected.bind(String(model.get("id", ""))))

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", UiPalette.SPACING_SM)
	margin.add_theme_constant_override("margin_right", UiPalette.SPACING_SM)
	margin.add_theme_constant_override("margin_top", UiPalette.SPACING_SM)
	margin.add_theme_constant_override("margin_bottom", UiPalette.SPACING_SM)
	button.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UiPalette.SPACING_MD)
	margin.add_child(row)

	# Icon well: dark square so any icon art pops, like the benchmark cards.
	var well := PanelContainer.new()
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.custom_minimum_size = Vector2(64, 64)
	well.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	well.add_theme_stylebox_override("panel", UiPalette.panel_style(UiPalette.INK, Color.TRANSPARENT, 0, 8))
	row.add_child(well)
	var icon_texture: Texture2D = _choice_icon(model)
	if icon_texture != null:
		var icon := TextureRect.new()
		icon.texture = icon_texture
		icon.custom_minimum_size = Vector2(48, 48)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		well.add_child(icon)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", UiPalette.SPACING_XS)
	row.add_child(box)

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

	var pill := _grade_pill(model)
	if pill != null:
		row.add_child(pill)

	return button


## Weapon choices show their weapon icon; passives keep their passive icon.
func _choice_icon(model: Dictionary) -> Texture2D:
	var icon_texture: Texture2D = model.get("icon")
	if icon_texture != null:
		return icon_texture
	var kind: String = String(model.get("kind", ""))
	if kind == "weapon_new" or kind == "weapon_upgrade":
		var sprite_path: String = String(GameData.weapon(String(model.get("id", ""))).get("sprite", ""))
		if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
			return load(sprite_path)
	return null


## Text pill naming the grade (weapons) or the kind (passives): the grade is
## information, so it is words, never colour alone.
func _grade_pill(model: Dictionary) -> Control:
	var kind: String = String(model.get("kind", ""))
	var text: String
	if kind == "weapon_new" or kind == "weapon_upgrade":
		var grade: String = String(GameData.weapon(String(model.get("id", ""))).get("grade", "common"))
		text = LocaleText.ui("grade_%s" % grade)
	else:
		text = String(model.get("kind_label", ""))
	if text.is_empty():
		return null

	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	pill.add_theme_stylebox_override("panel", UiPalette.panel_style(UiPalette.VERMILION, Color.TRANSPARENT, 0, 12))
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", UiPalette.TEXT_ON_DARK)
	label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_LABEL)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(label)
	return pill


func _on_choice_selected(choice_id: String) -> void:
	UiSound.play_click(self)
	EventBus.upgrade_chosen.emit(choice_id)
	_hide_panel()


func _show_panel() -> void:
	UiSound.play_level_up(self)
	visible = true
	get_tree().paused = true


func _hide_panel() -> void:
	UiSound.play_click(self)
	visible = false
	get_tree().paused = false
