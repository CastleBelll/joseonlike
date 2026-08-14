class_name LootChoiceController
extends CanvasLayer
## Pause-and-choose popup for special loot (GDD v2 section 33): use the
## material on an owned weapon, keep it, or salvage it for run gold.
##
## EventBus-driven like LevelUpChoice: listens for EventBus.loot_collected,
## filters on the loot's data-declared `special` flag, and defers behind any
## other pause owner (level-up panel, pause menu) via a pending queue so two
## overlays never fight for get_tree().paused.

const OPTION_KEEP := "keep"
const OPTION_SALVAGE := "salvage"
const OPTION_USE_PREFIX := "use:"

const FIELD_SPECIAL := "special"
const FIELD_SALVAGE_GOLD := "salvage_gold"
const KEY_ID := "id"

@onready var _dim: ColorRect = $Dim
@onready var _panel: Panel = $Panel
@onready var _title_label: Label = $Panel/Margin/Box/TitleLabel
@onready var _choices_box: VBoxContainer = $Panel/Margin/Box/ChoicesBox

var _pending: Array[String] = []
var _current_loot_id: String = ""


func _ready() -> void:
	layer = 21
	process_mode = Node.PROCESS_MODE_ALWAYS

	_dim.color = Color(UiPalette.INK.r, UiPalette.INK.g, UiPalette.INK.b, 0.72)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", UiPalette.nine_slice_panel())
	_title_label.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	_title_label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_TITLE)

	visible = false
	EventBus.loot_collected.connect(_on_loot_collected)


func _on_loot_collected(loot_id: String) -> void:
	var loot_data: Dictionary = GameData.loot(loot_id)
	if not bool(loot_data.get(FIELD_SPECIAL, false)):
		return
	_pending.append(loot_id)


## The queue drains here rather than in the signal handler because another
## overlay may own the pause when the pickup lands; polling one flag per frame
## is the cheapest handover that cannot deadlock.
func _process(_delta: float) -> void:
	if _pending.is_empty() or visible or get_tree().paused:
		return
	_show_for(_pending.pop_front())


func _show_for(loot_id: String) -> void:
	_current_loot_id = loot_id
	var loot_data: Dictionary = GameData.loot(loot_id)
	_title_label.text = LocaleText.ui("loot_choice_title_template") % LocaleText.field(loot_data, "name")
	_render_options(build_options(loot_id, loot_data, RunState.weapons, GameData))
	visible = true
	get_tree().paused = true


## Pure view-model builder (see LevelUpChoice.build_choice_view_models):
## `content` is GameData or a fixture-backed instance, so tests can call this
## without the scene tree. One "use" option per owned weapon with a recipe
## whose result is not already held, then keep, then salvage.
static func build_options(loot_id: String, loot_data: Dictionary, owned_weapons: Array[Dictionary], content: Node) -> Array[Dictionary]:
	var options: Array[Dictionary] = []

	var owned_ids: Dictionary = {}
	for entry: Dictionary in owned_weapons:
		owned_ids[String(entry.get(KEY_ID, ""))] = true

	for entry: Dictionary in owned_weapons:
		var weapon_id: String = String(entry.get(KEY_ID, ""))
		if weapon_id.is_empty():
			continue
		var result_id: String = String(content.mod_for(weapon_id, loot_id))
		if result_id.is_empty() or owned_ids.has(result_id):
			continue
		var source_name: String = LocaleText.field(content.weapon(weapon_id), "name")
		var result_name: String = LocaleText.field(content.weapon(result_id), "name")
		options.append({
			"id": OPTION_USE_PREFIX + weapon_id,
			"label": LocaleText.ui("kind_loot_use"),
			"name": LocaleText.ui("loot_use_template") % [source_name, result_name],
		})

	options.append({
		"id": OPTION_KEEP,
		"label": "",
		"name": LocaleText.ui("loot_keep"),
		"description": LocaleText.ui("loot_keep_desc"),
	})
	options.append({
		"id": OPTION_SALVAGE,
		"label": "",
		"name": LocaleText.ui("loot_salvage"),
		"description": LocaleText.ui("loot_salvage_template") % int(loot_data.get(FIELD_SALVAGE_GOLD, 0)),
	})
	return options


func _render_options(options: Array[Dictionary]) -> void:
	for child in _choices_box.get_children():
		child.queue_free()

	var first_button: Button = null
	for option in options:
		var button := Button.new()
		var name_text: String = String(option.get("name", ""))
		var label_text: String = String(option.get("label", ""))
		var description: String = String(option.get("description", ""))
		var lines: Array[String] = []
		if not label_text.is_empty():
			lines.append("[%s] %s" % [label_text, name_text])
		else:
			lines.append(name_text)
		if not description.is_empty():
			lines.append(description)
		button.text = "\n".join(lines)
		button.custom_minimum_size = Vector2(0, UiPalette.TOUCH_TARGET_MIN)
		button.focus_mode = Control.FOCUS_ALL
		UiPalette.apply_button_style(button)
		button.pressed.connect(_on_option_selected.bind(String(option.get("id", ""))))
		_choices_box.add_child(button)
		if first_button == null:
			first_button = button
	if first_button != null:
		first_button.grab_focus()


func _on_option_selected(option_id: String) -> void:
	UiSound.play_click(self)
	if option_id.begins_with(OPTION_USE_PREFIX):
		RunState.apply_weapon_mod(option_id.trim_prefix(OPTION_USE_PREFIX), _current_loot_id)
	elif option_id == OPTION_SALVAGE:
		var gold: int = RunState.salvage_loot(_current_loot_id)
		if gold > 0:
			EventBus.loot_salvaged.emit(_current_loot_id, gold)
	# OPTION_KEEP: the pickup already banked the material, nothing to do.
	_hide_panel()


## Unconditional unpause is safe under the same contract as LevelUpChoice:
## while this panel is visible its full-rect Dim (MOUSE_FILTER_STOP, layer 21)
## blocks every lower pause owner (HUD pause is button-only), and the pending
## queue never opens this panel while someone else holds the pause.
func _hide_panel() -> void:
	_current_loot_id = ""
	visible = false
	get_tree().paused = false
