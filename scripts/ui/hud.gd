extends CanvasLayer
## Run HUD: HP bar, XP bar + level, run timer, kill count, active weapon
## chips. Reads only EventBus signals, RunState, and GameData -- never a
## reference to a combat/player node.

@onready var _hp_bar: ProgressBar = $Root/Margin/MainBox/TopRow/HpBar
@onready var _hp_label: Label = $Root/Margin/MainBox/TopRow/HpBar/HpLabel
@onready var _level_label: Label = $Root/Margin/MainBox/TopRow/LevelLabel
@onready var _xp_icon: TextureRect = $Root/Margin/MainBox/XpRow/XpIcon
@onready var _xp_bar: ProgressBar = $Root/Margin/MainBox/XpRow/XpBar
@onready var _time_label: Label = $Root/Margin/MainBox/StatsRow/TimeLabel
@onready var _kills_label: Label = $Root/Margin/MainBox/StatsRow/KillsLabel
@onready var _weapons_row: HBoxContainer = $Root/Margin/MainBox/WeaponsRow
@onready var _weapons_empty_label: Label = $Root/Margin/MainBox/WeaponsEmptyLabel

var _max_hp: float = 0.0
var _current_hp: float = 0.0


func _ready() -> void:
	layer = 10
	_style_bar(_hp_bar, UiPalette.DANGER)
	_style_bar(_xp_bar, UiPalette.GOLD)
	_xp_icon.texture = UiPalette.ICON_XP
	for label in [_hp_label, _level_label, _time_label, _kills_label, _weapons_empty_label]:
		label.add_theme_color_override("font_color", UiPalette.TEXT_ON_DARK)
		label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_LABEL)

	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.player_died.connect(_on_player_died)
	EventBus.xp_gained.connect(_on_xp_gained)
	EventBus.level_reached.connect(_on_level_reached)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.upgrade_chosen.connect(_on_weapons_may_have_changed)
	EventBus.weapon_evolved.connect(_on_weapons_may_have_changed)

	_refresh_max_hp()
	_current_hp = _max_hp
	_update_hp_display()
	_update_level_display()
	_update_xp_display()
	_refresh_weapons()
	_update_stats_row()


func _process(_delta: float) -> void:
	_update_stats_row()


func _refresh_max_hp() -> void:
	if RunState.character_id.is_empty():
		_max_hp = 0.0
		return
	var character: Dictionary = GameData.character(RunState.character_id)
	var base_hp: float = float(character.get("base_hp", 0.0))
	_max_hp = base_hp * (1.0 + RunState.stat_total("max_hp"))


func _on_player_damaged(_amount: float, hp_left: float) -> void:
	_current_hp = hp_left
	_update_hp_display()


func _on_player_died() -> void:
	_current_hp = 0.0
	_update_hp_display()


func _update_hp_display() -> void:
	var display_max: float = max(_max_hp, 1.0)
	_hp_bar.max_value = display_max
	_hp_bar.value = clampf(_current_hp, 0.0, display_max)
	_hp_label.text = "%d/%d" % [int(round(_current_hp)), int(round(_max_hp))]


func _on_xp_gained(_amount: int) -> void:
	_update_xp_display()


func _on_level_reached(level: int, _choices: Array[Dictionary]) -> void:
	_refresh_max_hp()
	_update_hp_display()
	_update_level_display(level)
	_update_xp_display()
	_refresh_weapons()


func _update_level_display(level: int = -1) -> void:
	var shown_level: int = level if level >= 0 else RunState.level
	_level_label.text = "%s %d" % [LocaleText.ui("level_label"), shown_level]


## RunState.xp already tracks progress within the current level (RunState
## subtracts xp_to_next(level) on each level-up), so the bar reads it as-is.
func _update_xp_display() -> void:
	var required: int = RunState.xp_to_next(RunState.level)
	_xp_bar.max_value = max(required, 1)
	_xp_bar.value = clampi(RunState.xp, 0, required)


func _on_enemy_killed(_monster_id: String, _position: Vector2) -> void:
	_update_stats_row()


func _update_stats_row() -> void:
	_time_label.text = "%s %s" % [LocaleText.ui("time_label"), _format_time(RunState.elapsed_sec)]
	_kills_label.text = "%s %d" % [LocaleText.ui("kills_label"), RunState.kills]


func _format_time(seconds: float) -> String:
	var total: int = int(seconds)
	return "%02d:%02d" % [total / 60, total % 60]


func _on_weapons_may_have_changed(_a = null, _b = null) -> void:
	_refresh_weapons()


func _refresh_weapons() -> void:
	for child in _weapons_row.get_children():
		child.queue_free()

	var weapons: Array[Dictionary] = RunState.weapons
	_weapons_empty_label.visible = weapons.is_empty()
	_weapons_row.visible = not weapons.is_empty()

	for weapon_entry in weapons:
		_weapons_row.add_child(_build_weapon_chip(weapon_entry))


func _build_weapon_chip(weapon_entry: Dictionary) -> Control:
	var weapon_id: String = String(weapon_entry.get("id", ""))
	var level: int = int(weapon_entry.get("level", 1))
	var weapon_data: Dictionary = GameData.weapon(weapon_id)

	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UiPalette.nine_slice_panel())
	chip.custom_minimum_size = Vector2(UiPalette.TOUCH_TARGET_MIN, UiPalette.TOUCH_TARGET_MIN)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	chip.add_child(box)

	var icon := TextureRect.new()
	var sprite_path: String = String(weapon_data.get("sprite", ""))
	icon.texture = load(sprite_path) if sprite_path != "" and ResourceLoader.exists(sprite_path) else null
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.visible = icon.texture != null
	box.add_child(icon)

	var label := Label.new()
	var display_name: String = LocaleText.field(weapon_data, "name") if not weapon_data.is_empty() else weapon_id
	label.text = "%s Lv%d" % [display_name, level]
	label.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_LABEL)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)

	return chip


func _style_bar(bar: ProgressBar, fill_color: Color) -> void:
	bar.add_theme_stylebox_override("background", UiPalette.panel_style(UiPalette.INK.lerp(Color.BLACK, 0.2), Color.TRANSPARENT, 0, 4))
	bar.add_theme_stylebox_override("fill", UiPalette.panel_style(fill_color, Color.TRANSPARENT, 0, 4))
	bar.show_percentage = false
