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
const TIER_DIR := "res://asset/ui/level_up"
const GRADE_TO_TIER := {
	"common": "common",
	"rare": "rare",
	"epic": "legendary",
}
const CARD_MARGIN := 12

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


func _build_choice_card(model: Dictionary) -> Button:
	var tier: String = String(model.get("tier", "common"))

	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 96)
	button.focus_mode = Control.FOCUS_ALL
	_style_tier_card(button, tier)
	button.pressed.connect(_on_choice_selected.bind(String(model.get("id", ""))))

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", UiPalette.SPACING_SM)
	button.add_child(row)

	var icon_texture: Texture2D = model.get("icon")
	if icon_texture != null:
		var icon := TextureRect.new()
		icon.texture = icon_texture
		icon.custom_minimum_size = Vector2(32, 32)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", UiPalette.SPACING_XS)
	row.add_child(box)

	var kind_label_text: String = String(model.get("kind_label", ""))
	if not kind_label_text.is_empty():
		var kind_label := Label.new()
		kind_label.text = kind_label_text
		kind_label.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
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

	var tier_icon_texture: Texture2D = _tier_icon(tier)
	if tier_icon_texture != null:
		var tier_icon := TextureRect.new()
		tier_icon.texture = tier_icon_texture
		tier_icon.custom_minimum_size = Vector2(20, 20)
		tier_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tier_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tier_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(tier_icon)

	return button


static func _style_tier_card(button: Button, tier: String) -> void:
	var texture: Texture2D = _card_texture(tier)
	if texture == null:
		UiPalette.apply_button_style(button)
		return

	var normal := _card_nine_slice(texture)
	var focused := _card_nine_slice(texture)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", focused)
	button.add_theme_stylebox_override("pressed", focused)
	button.add_theme_stylebox_override("focus", UiPalette.panel_style(Color.TRANSPARENT, UiPalette.VERMILION, 3, 6))
	button.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	button.add_theme_color_override("font_hover_color", UiPalette.TEXT_ON_PAPER)
	button.add_theme_color_override("font_pressed_color", UiPalette.TEXT_ON_PAPER)
	button.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_BODY)
	button.custom_minimum_size.y = max(button.custom_minimum_size.y, UiPalette.TOUCH_TARGET_MIN)


static func _card_nine_slice(texture: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = CARD_MARGIN
	style.texture_margin_right = CARD_MARGIN
	style.texture_margin_top = CARD_MARGIN
	style.texture_margin_bottom = CARD_MARGIN
	return style


static func _card_texture(tier: String) -> Texture2D:
	var path: String = "%s/card_%s_9slice.png" % [TIER_DIR, tier]
	return load(path) if ResourceLoader.exists(path) else null


static func _tier_icon(tier: String) -> Texture2D:
	var path: String = "%s/tier_%s.png" % [TIER_DIR, tier]
	return load(path) if ResourceLoader.exists(path) else null


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
