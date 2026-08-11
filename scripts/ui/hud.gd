extends CanvasLayer
## Run HUD: HP bar, XP bar + level, boss bar (only while a boss is alive),
## timer, kill count, active weapon chips, and a pause affordance. Reads
## only EventBus signals, RunState, and GameData -- never a reference to a
## combat/player node.
##
## The pause menu is owned here as an overlay (not a routed SceneRouter
## screen) since it only needs Resume/Settings/Quit over the paused run.
##
## Damage/pickup toasts were removed on player feedback -- players do not
## want every hit taken or XP pickup announced. asset/ui/feedback/
## (damage_toast_9slice.png, pickup_toast_9slice.png) is unused as a result;
## reported rather than kept wired to a feature that no longer exists.

const ICON_DIR := "res://asset/ui/hud/icons"
const BAR_BACKGROUND: Texture2D = preload("res://asset/ui/hud/bar_background_9slice.png")
const HP_FILL: Texture2D = preload("res://asset/ui/hud/hp_fill_9slice.png")
const XP_FILL: Texture2D = preload("res://asset/ui/hud/xp_fill_9slice.png")
const BOSS_FILL: Texture2D = preload("res://asset/ui/hud/boss_fill_9slice.png")
const TIMER_FRAME: Texture2D = preload("res://asset/ui/hud/timer_frame_9slice.png")

const BAR_MARGIN := 6

@onready var _hp_icon: TextureRect = $Root/Margin/MainBox/TopRow/HpIcon
@onready var _hp_bar: ProgressBar = $Root/Margin/MainBox/TopRow/HpBar
@onready var _hp_label: Label = $Root/Margin/MainBox/TopRow/HpBar/HpLabel
@onready var _level_icon: TextureRect = $Root/Margin/MainBox/TopRow/LevelIcon
@onready var _level_label: Label = $Root/Margin/MainBox/TopRow/LevelLabel
@onready var _pause_button: Button = $Root/Margin/MainBox/TopRow/PauseButton
@onready var _xp_icon: TextureRect = $Root/Margin/MainBox/XpRow/XpIcon
@onready var _xp_bar: ProgressBar = $Root/Margin/MainBox/XpRow/XpBar
@onready var _boss_row: HBoxContainer = $Root/Margin/MainBox/BossRow
@onready var _boss_icon: TextureRect = $Root/Margin/MainBox/BossRow/BossIcon
@onready var _boss_bar: ProgressBar = $Root/Margin/MainBox/BossRow/BossBar
@onready var _timer_panel: PanelContainer = $Root/Margin/MainBox/StatsRow/TimerPanel
@onready var _timer_icon: TextureRect = $Root/Margin/MainBox/StatsRow/TimerPanel/TimerBox/TimerIcon
@onready var _time_label: Label = $Root/Margin/MainBox/StatsRow/TimerPanel/TimerBox/TimeLabel
@onready var _kills_icon: TextureRect = $Root/Margin/MainBox/StatsRow/KillsIcon
@onready var _kills_label: Label = $Root/Margin/MainBox/StatsRow/KillsLabel
@onready var _weapons_row: HBoxContainer = $Root/Margin/MainBox/WeaponsRow
@onready var _weapons_empty_label: Label = $Root/Margin/MainBox/WeaponsEmptyLabel

@onready var _pause_overlay: Control = $PauseOverlay
@onready var _pause_title: Label = $PauseOverlay/Panel/PanelMargin/PanelBox/PauseTitle
@onready var _resume_button: Button = $PauseOverlay/Panel/PanelMargin/PanelBox/ResumeButton
@onready var _quit_button: Button = $PauseOverlay/Panel/PanelMargin/PanelBox/QuitButton

var _max_hp: float = 0.0
var _current_hp: float = 0.0
var _boss_active: bool = false


func _ready() -> void:
	layer = 10
	_hp_icon.texture = _icon("hp")
	_level_icon.texture = _icon("level")
	_boss_icon.texture = _icon("boss")
	_timer_icon.texture = _icon("timer")
	_kills_icon.texture = _icon("kills")
	_pause_icon_setup()

	_style_bar(_hp_bar, HP_FILL)
	_style_bar(_xp_bar, XP_FILL)
	_style_bar(_boss_bar, BOSS_FILL)
	_xp_icon.texture = UiPalette.ICON_XP
	_style_timer_panel()
	_boss_row.visible = false

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
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_defeated.connect(_on_boss_defeated)

	_setup_pause_overlay()

	_refresh_max_hp()
	_current_hp = _max_hp
	_update_hp_display()
	_update_level_display()
	_update_xp_display()
	_refresh_weapons()
	_update_stats_row()


func _process(_delta: float) -> void:
	_update_stats_row()


func _icon(id: String) -> Texture2D:
	var path: String = "%s/%s.png" % [ICON_DIR, id]
	return load(path) if ResourceLoader.exists(path) else null


## PRESET_CENTER + a hand-computed -custom_minimum_size*0.5 offset does NOT
## centre a manually-added, non-container-managed child: custom_minimum_size
## never becomes the node's actual `size` outside a Container's layout pass,
## so the offset was computed against a size the icon never actually had --
## the icon rendered at its texture's real (larger) footprint, centred on
## the wrong point, reading as pushed toward the bottom-right of the button.
## Anchoring FULL_RECT and letting STRETCH_KEEP_ASPECT_CENTERED centre the
## texture within whatever rect the button actually resolves to needs no
## manual size/offset math at all, so it cannot drift out of sync with it.
func _pause_icon_setup() -> void:
	UiPalette.apply_button_style(_pause_button)
	_pause_button.text = ""
	var icon := TextureRect.new()
	icon.texture = _icon("pause")
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_button.add_child(icon)
	_pause_button.pressed.connect(_on_pause_pressed)


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


## boss_spawned/boss_defeated exist on EventBus, but there is no boss-health
## signal yet -- the bar shows presence (full while alive) rather than a
## live health readout. Report to combat if per-hit boss HP is needed.
func _on_boss_spawned(_boss_id: String) -> void:
	_boss_active = true
	_boss_bar.max_value = 1.0
	_boss_bar.value = 1.0
	_boss_row.visible = true


func _on_boss_defeated(_boss_id: String) -> void:
	_boss_active = false
	_boss_row.visible = false


func _on_enemy_killed(_monster_id: String, _position: Vector2) -> void:
	_update_stats_row()


func _update_stats_row() -> void:
	_time_label.text = _format_time(RunState.elapsed_sec)
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


## Icon + level only -- the chip is a fixed 44x44 slot and the weapon's full
## name does not fit at a readable size in it. GameData.weapon(weapon_id)
## still backs the icon lookup; the name itself is simply not shown here.
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
	label.text = "Lv%d" % level
	label.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	label.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_LABEL)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)

	return chip


func _style_bar(bar: ProgressBar, fill: Texture2D) -> void:
	bar.add_theme_stylebox_override("background", _nine_slice(BAR_BACKGROUND))
	bar.add_theme_stylebox_override("fill", _nine_slice(fill))
	bar.show_percentage = false


func _style_timer_panel() -> void:
	_timer_panel.add_theme_stylebox_override("panel", _nine_slice(TIMER_FRAME, 8))


func _nine_slice(texture: Texture2D, margin: int = BAR_MARGIN) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = margin
	style.texture_margin_right = margin
	style.texture_margin_top = margin
	style.texture_margin_bottom = margin
	return style


func _setup_pause_overlay() -> void:
	_pause_title.text = LocaleText.ui("pause_title")
	_pause_title.add_theme_color_override("font_color", UiPalette.TEXT_ON_PAPER)
	_pause_title.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_TITLE)

	_resume_button.text = LocaleText.ui("pause_resume")
	_quit_button.text = LocaleText.ui("pause_quit_to_title")
	for button in [_resume_button, _quit_button]:
		UiPalette.apply_button_style(button)

	_resume_button.pressed.connect(_on_resume_pressed)
	_quit_button.pressed.connect(_on_quit_to_title_pressed)

	_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_overlay.visible = false


func _on_pause_pressed() -> void:
	UiSound.play_click(self)
	_open_pause_overlay()


func _open_pause_overlay() -> void:
	if _pause_overlay.visible:
		return
	_pause_overlay.visible = true
	get_tree().paused = true
	_resume_button.grab_focus()


func _close_pause_overlay() -> void:
	if not _pause_overlay.visible:
		return
	_pause_overlay.visible = false
	get_tree().paused = false


func _on_resume_pressed() -> void:
	UiSound.play_click(self)
	_close_pause_overlay()


func _on_quit_to_title_pressed() -> void:
	UiSound.play_click(self)
	get_tree().paused = false
	SceneRouter.goto_title()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _pause_overlay.visible:
			_close_pause_overlay()
		else:
			_open_pause_overlay()
		get_viewport().set_input_as_handled()
