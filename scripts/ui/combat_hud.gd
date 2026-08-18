class_name CombatHud
extends Control
## Minimal combat HUD (N3-7), captures _04/_06 grammar: pause/info top-left,
## large outlined pixel timer top-centre, a full-width thin XP bar, "Lv.N"
## under the bar on the left and skull/coin counters stacked on the right.
## Icons and numbers sit directly on the world — no chips, no panels. The
## skull/coin/pause/info glyphs are the real asset/ui/hud icons (N3-13),
## displayed at integer multiples of their 16px logical size for crisp NEAREST
## sampling.

const TITLE_SCENE := "res://scenes/title.tscn"

const TOP_MARGIN := 20.0
const TIMER_FONT_SIZE := 48
const TIMER_OUTLINE_SIZE := 8
const BUTTON_SIZE := 44.0  # UiPalette.TOUCH_TARGET_MIN
const BAR_TOP := 92.0
const BAR_HEIGHT := 8.0
const BAR_MARGIN_X := 8.0
# N6-2 HUD HP bar: a second thin strip right under the XP bar — same minimal
# grammar (token colours, no chip background, no numbers).
const HP_BAR_GAP := 2.0
const HP_BAR_HEIGHT := 5.0
const HP_BAR_BOTTOM := BAR_TOP + BAR_HEIGHT + HP_BAR_GAP + HP_BAR_HEIGHT
const COUNTER_ROW_HEIGHT := 36.0
const COUNTER_STACK_WIDTH := 144.0
# 2x of the 16px logical HUD icon (asset/ui/README.md) — the capture's
# counter icons read ~30 logical px, and 2x NEAREST stays pixel-crisp.
const ICON_SIZE := 32.0
const CORNER_ICON_SIZE := 32.0
const OVERLAY_PANEL_MARGIN_X := 64.0
const OVERLAY_PANEL_HEIGHT := 260.0
const OVERLAY_BUTTON_HEIGHT := 56.0
# N9-3e pause build summary: weapon cells (icon + Lv) and passive lines.
const BUILD_WEAPON_COLUMNS := 6
const BUILD_CELL_SIZE := 52.0
const BUILD_ICON_SIZE := 32.0
const BUILD_CELL_HEIGHT := 66.0
const BUILD_PASSIVE_COLUMNS := 2
const BUILD_PASSIVE_ROW_HEIGHT := 26.0
# N5-1 boss bar: thin strip across the very top, above the timer.
const BOSS_BAR_TOP := 8.0
const BOSS_BAR_HEIGHT := 6.0
# N3-8 player-hit vignette edge thickness and peak opacity.
const VIGNETTE_THICKNESS := 28.0
const VIGNETTE_MAX_ALPHA := 0.45

## N4-4b: a bottom-right active button was tapped; the stage gates the
## cooldown and executes the effect.
signal active_pressed(active_id: String)

# N4-4b active cluster: bottom-right, mirroring the joystick's bottom-left
# footprint so neither covers the play centre.
const ACTIVE_BUTTON_SIZE := 64.0
const ACTIVE_CLUSTER_MARGIN := 32.0

var _elapsed: float = 0.0
var _timer_label: Label
var _xp_bar: ProgressBar
var _hp_bar: ProgressBar
var _hp_fill: StyleBoxFlat
var _level_label: Label
var _kill_label: Label
var _gold_label: Label
var _pause_overlay: Control
var _pause_panel: PanelContainer
var _build_section: VBoxContainer
var _resume_button: Button
## Stage installs this; called on every pause open so the summary is always
## the live build (no push-sync to drift). Returns
## {"weapons": [{"id", "name", "level"}], "passives": [{"name", "stacks", "max"}]}.
var build_provider: Callable
var _boss_bar: ProgressBar
var _vignette: DamageVignette
var _screen_flash: ScreenFlash
var _active_buttons: Dictionary = {}  # active id -> ActiveButton


func _ready() -> void:
	build_ui()


func _process(delta: float) -> void:
	# Inherits the pausable process mode, so the clock freezes with the tree.
	_elapsed += delta
	_timer_label.text = format_time(_elapsed)


## m:ss count-up per captures _04/_06 ("0:00", "0:12").
static func format_time(seconds: float) -> String:
	var total: int = maxi(0, floori(seconds))
	return "%d:%02d" % [floori(total / 60.0), total % 60]


## Public and separate from _ready so the headless suite can construct the
## HUD without a SceneTree (same pattern as TitleScreen.build_ui).
func build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # never eat joystick touches
	_build_vignette()
	_build_screen_flash()
	_build_corner_buttons()
	_build_timer()
	_build_xp_bar()
	_build_hp_bar()
	_build_level_label()
	_build_counters()
	_build_boss_bar()
	_build_pause_overlay()


## N6-4 floating joystick contract: true when the point lands on an
## interactive HUD button (actives, pause, info, overlay buttons), so the
## joystick never captures — and never swallows — those taps. Walks the live
## tree instead of a hand-kept list so future buttons are covered for free.
func blocks_point(point: Vector2) -> bool:
	return _hits_button(self, point)


func _hits_button(node: Node, point: Vector2) -> bool:
	for child: Node in node.get_children():
		if child is Button and (child as Button).is_visible_in_tree() \
				and not (child as Button).disabled \
				and (child as Button).get_global_rect().has_point(point):
			return true
		if _hits_button(child, point):
			return true
	return false


func set_level(level: int) -> void:
	_level_label.text = "Lv.%d" % level


func set_xp(current: int, needed: int) -> void:
	_xp_bar.max_value = maxi(needed, 1)
	_xp_bar.value = current


## N6-2 pure HUD HP view-model, node-free for the headless suite: bar range,
## clamped value, fill ratio and the low-HP flag (CombatMath threshold rule).
static func hp_view(hp: float, hp_max: float, threshold: float) -> Dictionary:
	var bar_max: float = maxf(hp_max, 1.0)
	var value: float = clampf(hp, 0.0, bar_max)
	return {
		"max": bar_max,
		"value": value,
		"ratio": value / bar_max,
		"low": CombatMath.is_low_hp(hp, hp_max, threshold),
	}


## N6-2: HUD HP readout plus the low-HP warning. `threshold` and `pulse_sec`
## come from data (effects.json hit_feedback) via the stage — the HUD never
## reads data files itself. While low, the fill turns vermilion AND the edge
## vignette pulses continuously (never colour alone).
func set_hp(hp: float, hp_max: float, threshold: float, pulse_sec: float) -> void:
	var view: Dictionary = hp_view(hp, hp_max, threshold)
	_hp_bar.max_value = float(view["max"])
	_hp_bar.value = float(view["value"])
	var low: bool = bool(view["low"])
	_hp_fill.bg_color = UiPalette.VERMILION if low else UiPalette.SUCCESS
	_vignette.set_looping(low, pulse_sec)


func set_kills(count: int) -> void:
	_kill_label.text = str(count)


func set_gold(amount: int) -> void:
	_gold_label.text = str(amount)


## N5-1 boss bar: shown only while the boss lives.
func show_boss_bar() -> void:
	_boss_bar.visible = true


func set_boss_hp(current: float, hp_max: float) -> void:
	_boss_bar.max_value = maxf(hp_max, 1.0)
	_boss_bar.value = current


func hide_boss_bar() -> void:
	_boss_bar.visible = false


## N3-8 player-hit feedback; duration comes from data/effects.json (stage).
func pulse_damage(duration: float) -> void:
	_vignette.pulse(duration)


## N3-17 벽사진: one full-screen tinted flash that fades out — the emergency
## burst reads across the whole view. Duration from data (weapon_effects).
func flash_screen(color: Color, duration: float) -> void:
	_screen_flash.flash(color, duration)


## N4-4b: one round button per character active, newest to the left so the
## primary (first) skill sits in the thumb corner. Called once at run start.
func build_actives(actives: Array[Dictionary]) -> void:
	if actives.is_empty():
		return
	var row := HBoxContainer.new()
	row.name = "ActiveCluster"
	row.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.offset_right = -ACTIVE_CLUSTER_MARGIN
	row.offset_bottom = -ACTIVE_CLUSTER_MARGIN
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", UiPalette.SPACE_SM)
	for active: Dictionary in actives:
		var button := ActiveButton.new()
		var active_id: String = String(active.get("id", ""))
		button.name = "Active_" + active_id
		button.skill_name = String(active.get("name_ko", active_id))
		button.custom_minimum_size = Vector2(ACTIVE_BUTTON_SIZE, ACTIVE_BUTTON_SIZE)
		button.pressed.connect(
			func() -> void: active_pressed.emit(active_id)
		)
		row.add_child(button)
		_active_buttons[active_id] = button
	add_child(row)


## Remaining-cooldown fraction for one button (1 = just used, 0 = ready).
func set_active_cooldown(active_id: String, fraction: float) -> void:
	var button: ActiveButton = _active_buttons.get(active_id)
	if button != null:
		button.set_cooldown(fraction)


func _build_corner_buttons() -> void:
	var row := HBoxContainer.new()
	row.name = "CornerButtons"
	row.position = Vector2(UiPalette.SPACE_MD, TOP_MARGIN)
	row.add_theme_constant_override("separation", UiPalette.SPACE_SM)
	var pause := _flat_button("PauseButton")
	pause.add_child(_corner_icon("pause"))
	pause.pressed.connect(_on_pause_pressed)
	row.add_child(pause)
	# The info screen is a later feature; the button stays hidden until that
	# screen exists — a visible control that does nothing reads as broken (QA-2).
	var info := _flat_button("InfoButton")
	info.add_child(_corner_icon("info"))
	info.visible = false
	row.add_child(info)
	add_child(row)


func _build_timer() -> void:
	_timer_label = _label(format_time(0.0), TIMER_FONT_SIZE, UiPalette.TEXT_ON_DARK)
	_timer_label.name = "TimerLabel"
	_timer_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_timer_label.offset_top = TOP_MARGIN
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.add_theme_color_override("font_outline_color", UiPalette.INK)
	_timer_label.add_theme_constant_override("outline_size", TIMER_OUTLINE_SIZE)
	add_child(_timer_label)


func _build_xp_bar() -> void:
	_xp_bar = ProgressBar.new()
	_xp_bar.name = "XpBar"
	_xp_bar.show_percentage = false
	_xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track := StyleBoxFlat.new()
	track.bg_color = UiPalette.NIGHT_BROWN
	track.border_color = UiPalette.WOOD_BORDER
	track.set_border_width_all(1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiPalette.WOOD
	_xp_bar.add_theme_stylebox_override("background", track)
	_xp_bar.add_theme_stylebox_override("fill", fill)
	_xp_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_xp_bar.offset_left = BAR_MARGIN_X
	_xp_bar.offset_right = -BAR_MARGIN_X
	_xp_bar.offset_top = BAR_TOP
	_xp_bar.offset_bottom = BAR_TOP + BAR_HEIGHT
	set_xp(0, 1)
	add_child(_xp_bar)


## Same strip styling as the XP bar, one gap below it; green fill matches the
## under-sprite bar so both readouts are unambiguously "the same number".
func _build_hp_bar() -> void:
	_hp_bar = ProgressBar.new()
	_hp_bar.name = "HpBar"
	_hp_bar.show_percentage = false
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track := StyleBoxFlat.new()
	track.bg_color = UiPalette.NIGHT_BROWN
	track.border_color = UiPalette.WOOD_BORDER
	track.set_border_width_all(1)
	_hp_fill = StyleBoxFlat.new()
	_hp_fill.bg_color = UiPalette.SUCCESS
	_hp_bar.add_theme_stylebox_override("background", track)
	_hp_bar.add_theme_stylebox_override("fill", _hp_fill)
	_hp_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hp_bar.offset_left = BAR_MARGIN_X
	_hp_bar.offset_right = -BAR_MARGIN_X
	_hp_bar.offset_top = BAR_TOP + BAR_HEIGHT + HP_BAR_GAP
	_hp_bar.offset_bottom = HP_BAR_BOTTOM
	_hp_bar.max_value = 1.0
	_hp_bar.value = 1.0
	add_child(_hp_bar)


func _build_level_label() -> void:
	_level_label = _label("Lv.1", UiPalette.FONT_SIZE_LABEL, UiPalette.TEXT_ON_DARK)
	_level_label.name = "LevelLabel"
	_level_label.position = Vector2(
		UiPalette.SPACE_MD, HP_BAR_BOTTOM + UiPalette.SPACE_XS
	)
	add_child(_level_label)


func _build_counters() -> void:
	var stack := VBoxContainer.new()
	stack.name = "Counters"
	stack.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	stack.offset_left = -COUNTER_STACK_WIDTH
	stack.offset_right = -UiPalette.SPACE_MD
	stack.offset_top = HP_BAR_BOTTOM + UiPalette.SPACE_XS
	_kill_label = _counter_row(stack, "Kills", UiIcons.icon_rect(UiIcons.hud_icon("skull"), ICON_SIZE))
	_gold_label = _counter_row(stack, "Gold", UiIcons.icon_rect(UiIcons.hud_icon("coin"), ICON_SIZE))
	add_child(stack)


## One right-aligned icon + number row; returns the number label.
func _counter_row(stack: VBoxContainer, row_name: String, icon: Control) -> Label:
	var row := HBoxContainer.new()
	row.name = row_name
	row.custom_minimum_size = Vector2(0.0, COUNTER_ROW_HEIGHT)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", UiPalette.SPACE_SM)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var value := _label("0", UiPalette.FONT_SIZE_BODY, UiPalette.TEXT_ON_DARK)
	value.name = "Value"
	row.add_child(value)
	stack.add_child(row)
	return value


func _build_boss_bar() -> void:
	_boss_bar = ProgressBar.new()
	_boss_bar.name = "BossBar"
	_boss_bar.show_percentage = false
	_boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track := StyleBoxFlat.new()
	track.bg_color = UiPalette.NIGHT_BROWN
	track.border_color = UiPalette.WOOD_BORDER
	track.set_border_width_all(1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiPalette.VERMILION
	_boss_bar.add_theme_stylebox_override("background", track)
	_boss_bar.add_theme_stylebox_override("fill", fill)
	_boss_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_boss_bar.offset_left = BAR_MARGIN_X
	_boss_bar.offset_right = -BAR_MARGIN_X
	_boss_bar.offset_top = BOSS_BAR_TOP
	_boss_bar.offset_bottom = BOSS_BAR_TOP + BOSS_BAR_HEIGHT
	_boss_bar.visible = false
	add_child(_boss_bar)


func _build_vignette() -> void:
	_vignette = DamageVignette.new()
	_vignette.name = "DamageVignette"
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.visible = false
	add_child(_vignette)


func _build_screen_flash() -> void:
	_screen_flash = ScreenFlash.new()
	_screen_flash.name = "ScreenFlash"
	_screen_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen_flash.visible = false
	add_child(_screen_flash)


## Paper-panel pause overlay (§3 grammar): resume + quit-to-title only.
func _build_pause_overlay() -> void:
	_pause_overlay = Control.new()
	_pause_overlay.name = "PauseOverlay"
	# Must keep taking input while the paused tree is frozen.
	_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_overlay.visible = false
	var panel := PanelContainer.new()
	panel.name = "PaperPanel"
	panel.add_theme_stylebox_override("panel", UiIcons.paper_panel())
	# Full-width band centered vertically; set anchors directly because the
	# wide presets re-derive offsets from the current rect on insertion.
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = OVERLAY_PANEL_MARGIN_X
	panel.offset_right = -OVERLAY_PANEL_MARGIN_X
	panel.offset_top = -OVERLAY_PANEL_HEIGHT / 2.0
	panel.offset_bottom = OVERLAY_PANEL_HEIGHT / 2.0
	_pause_overlay.add_child(panel)
	var pad := MarginContainer.new()
	pad.name = "Pad"
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(side, UiPalette.SPACE_LG)
	panel.add_child(pad)
	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.add_theme_constant_override("separation", UiPalette.SPACE_MD)
	pad.add_child(layout)
	var title := _label("일시 정지", UiPalette.FONT_SIZE_TITLE, UiPalette.VERMILION)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(title)
	_build_section = VBoxContainer.new()
	_build_section.name = "BuildSummary"
	_build_section.add_theme_constant_override("separation", UiPalette.SPACE_SM)
	layout.add_child(_build_section)
	_resume_button = _overlay_button("ResumeButton", "계속하기", _on_resume_pressed)
	layout.add_child(_resume_button)
	layout.add_child(_overlay_button("QuitButton", "타이틀로", _on_quit_pressed))
	_pause_panel = panel
	add_child(_pause_overlay)


func _overlay_button(button_name: String, text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = text
	button.custom_minimum_size = Vector2(0.0, OVERLAY_BUTTON_HEIGHT)
	WoodButton.apply(button)
	button.pressed.connect(handler)
	return button


func _on_pause_pressed() -> void:
	get_tree().paused = true
	if build_provider.is_valid():
		_refresh_build_summary(build_provider.call())
	_pause_overlay.visible = true
	_resume_button.grab_focus()


## Rebuilds the pause overlay's build rows and resizes the centered panel
## deterministically from the row counts (GridContainer minimums are only
## reliable after a layout pass, which a freshly shown overlay hasn't had).
func _refresh_build_summary(summary: Dictionary) -> void:
	for child: Node in _build_section.get_children():
		child.queue_free()
	var weapons: Array = summary.get("weapons", [])
	var passives: Array = summary.get("passives", [])
	var extra_height: float = 0.0

	if not weapons.is_empty():
		var grid := GridContainer.new()
		grid.name = "WeaponGrid"
		grid.columns = BUILD_WEAPON_COLUMNS
		grid.add_theme_constant_override("h_separation", UiPalette.SPACE_SM)
		grid.add_theme_constant_override("v_separation", UiPalette.SPACE_XS)
		for entry: Dictionary in weapons:
			grid.add_child(_build_weapon_cell(entry))
		_build_section.add_child(grid)
		var weapon_rows: int = ceili(float(weapons.size()) / float(BUILD_WEAPON_COLUMNS))
		extra_height += weapon_rows * BUILD_CELL_HEIGHT + UiPalette.SPACE_SM

	if not passives.is_empty():
		var grid := GridContainer.new()
		grid.name = "PassiveGrid"
		grid.columns = BUILD_PASSIVE_COLUMNS
		grid.add_theme_constant_override("h_separation", UiPalette.SPACE_MD)
		for entry: Dictionary in passives:
			var line := _label(
				"%s Lv.%d/%d" % [
					String(entry.get("name", "")),
					int(entry.get("stacks", 0)), int(entry.get("max", 0)),
				],
				UiPalette.FONT_SIZE_LABEL, UiPalette.INK
			)
			line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(line)
		_build_section.add_child(grid)
		var passive_rows: int = ceili(float(passives.size()) / float(BUILD_PASSIVE_COLUMNS))
		extra_height += passive_rows * BUILD_PASSIVE_ROW_HEIGHT + UiPalette.SPACE_SM

	# N9-9: evolution paths open to this build — base → result · material,
	# ✓ when the material is already in the run inventory.
	var evolutions: Array = summary.get("evolutions", [])
	if not evolutions.is_empty():
		var box := VBoxContainer.new()
		box.name = "EvolutionLines"
		var header := _label("개조 경로", UiPalette.FONT_SIZE_LABEL, UiPalette.VERMILION)
		box.add_child(header)
		for line_text: Variant in evolutions:
			box.add_child(_label(
				String(line_text), UiPalette.FONT_SIZE_LABEL, UiPalette.TEXT_MUTED_ON_PAPER
			))
		_build_section.add_child(box)
		extra_height += (evolutions.size() + 1) * BUILD_PASSIVE_ROW_HEIGHT + UiPalette.SPACE_SM

	var half: float = (OVERLAY_PANEL_HEIGHT + extra_height) / 2.0
	_pause_panel.offset_top = -half
	_pause_panel.offset_bottom = half


## One weapon cell: dark icon well with the weapon icon (letter fallback for
## ids without art) and an Lv.N line under it.
func _build_weapon_cell(entry: Dictionary) -> Control:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 2)
	var well := PanelContainer.new()
	well.custom_minimum_size = Vector2(BUILD_CELL_SIZE, BUILD_CELL_SIZE)
	var well_style := StyleBoxFlat.new()
	well_style.bg_color = UiPalette.NIGHT_BROWN
	well_style.set_corner_radius_all(6)
	well.add_theme_stylebox_override("panel", well_style)
	var icon: Texture2D = UiIcons.weapon_icon(String(entry.get("id", "")))
	if icon != null:
		var rect: TextureRect = UiIcons.icon_rect(icon, BUILD_ICON_SIZE)
		rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		well.add_child(rect)
	else:
		var glyph := _label(String(entry.get("name", "?")).left(1), UiPalette.FONT_SIZE_BODY, UiPalette.TEXT_ON_DARK)
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		well.add_child(glyph)
	cell.add_child(well)
	var level := _label("Lv.%d" % int(entry.get("level", 1)), UiPalette.FONT_SIZE_LABEL, UiPalette.INK)
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(level)
	return cell


func _on_resume_pressed() -> void:
	_pause_overlay.visible = false
	get_tree().paused = false


func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)


## Small icon-only button with no panel background, per the captures.
func _flat_button(button_name: String) -> Button:
	var button := Button.new()
	button.name = button_name
	button.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	button.flat = true
	return button


## 2x HUD icon centered inside the 44px flat corner button.
func _corner_icon(icon_name: String) -> Control:
	var rect: TextureRect = UiIcons.icon_rect(UiIcons.hud_icon(icon_name), CORNER_ICON_SIZE)
	rect.set_anchors_preset(Control.PRESET_CENTER)
	return rect


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## N3-17 full-screen active flash (벽사진): one persistent Control drawing a
## translucent tinted rect that fades out. No per-cast instancing.
class ScreenFlash:
	extends Control

	# N3-18: 0.28 flooded the whole night palette olive for the full flash;
	# the burst ring now carries the area read, the flash only punctuates.
	const ALPHA_MAX := 0.14

	var _left: float = 0.0
	var _duration: float = 0.0
	var _color: Color = UiPalette.GOLD

	func flash(color: Color, duration: float) -> void:
		_color = color
		_duration = maxf(duration, 0.01)
		_left = _duration
		visible = true
		queue_redraw()

	func _process(delta: float) -> void:
		if not visible:
			return
		_left -= delta
		if _left <= 0.0:
			visible = false
			return
		queue_redraw()

	func _draw() -> void:
		draw_rect(
			Rect2(Vector2.ZERO, size), Color(_color, ALPHA_MAX * _left / _duration)
		)


## N3-8 screen-edge red pulse on player damage: four vermilion edge bars that
## fade out. One persistent Control — no per-hit instancing. N6-2 adds a
## looping low-HP mode: while active the edges breathe continuously between
## LOOP_ALPHA_MIN and the hit peak, so danger stays visible without ever
## covering the play area; a hit pulse on top still wins while stronger.
class DamageVignette:
	extends Control

	const LOOP_ALPHA_MIN := 0.12

	var _left: float = 0.0
	var _duration: float = 0.0
	var _looping: bool = false
	var _loop_period: float = 1.0
	var _loop_phase: float = 0.0

	func pulse(duration: float) -> void:
		_duration = maxf(duration, 0.01)
		_left = _duration
		visible = true
		queue_redraw()

	## Low-HP warning loop (period from data). Turning it off clears the
	## screen unless a hit pulse is still fading.
	func set_looping(active: bool, period_sec: float) -> void:
		_looping = active
		_loop_period = maxf(period_sec, 0.05)
		if active:
			visible = true
		else:
			_loop_phase = 0.0
			visible = _left > 0.0
		queue_redraw()

	func _process(delta: float) -> void:
		if _looping:
			_loop_phase = fmod(_loop_phase + delta / _loop_period, 1.0)
			_left = maxf(_left - delta, 0.0)
			queue_redraw()
			return
		if _left <= 0.0:
			return
		_left -= delta
		if _left <= 0.0:
			visible = false
			return
		queue_redraw()

	func _draw() -> void:
		var alpha: float = 0.0
		if _left > 0.0 and _duration > 0.0:
			alpha = VIGNETTE_MAX_ALPHA * (_left / _duration)
		if _looping:
			var wave: float = 0.5 + 0.5 * sin(_loop_phase * TAU)
			alpha = maxf(alpha, lerpf(LOOP_ALPHA_MIN, VIGNETTE_MAX_ALPHA, wave))
		var color := Color(UiPalette.VERMILION, alpha)
		var thickness: float = VIGNETTE_THICKNESS
		draw_rect(Rect2(0.0, 0.0, size.x, thickness), color)
		draw_rect(Rect2(0.0, size.y - thickness, size.x, thickness), color)
		draw_rect(Rect2(0.0, thickness, thickness, size.y - thickness * 2.0), color)
		draw_rect(
			Rect2(size.x - thickness, thickness, thickness, size.y - thickness * 2.0),
			color
		)


## N4-4b round active-skill button: wood disc with the skill name, dimmed
## while cooling with a sweep arc showing the remaining fraction. Custom-drawn
## with palette tokens until the AC-3 icon set lands (ASSET_REQUIREMENTS.md).
class ActiveButton:
	extends Button

	const RING_WIDTH := 3.0
	const RING_POINTS := 32
	const COOLING_ALPHA := 0.55
	const FONT_SIZE := 16

	var skill_name: String = ""
	var _fraction: float = 0.0  # remaining cooldown, 1 → 0

	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE

	func set_cooldown(fraction: float) -> void:
		var ready_flip: bool = (_fraction > 0.0) != (fraction > 0.0)
		var moved: bool = absf(fraction - _fraction) > 0.01
		_fraction = fraction
		disabled = fraction > 0.0
		if ready_flip or moved:
			queue_redraw()

	func _draw() -> void:
		var center: Vector2 = size / 2.0
		var radius: float = minf(size.x, size.y) / 2.0 - RING_WIDTH
		var cooling: bool = _fraction > 0.0
		var fill: Color = UiPalette.WOOD_PRESSED if cooling else UiPalette.WOOD
		if cooling:
			fill = Color(fill, COOLING_ALPHA)
		draw_circle(center, radius, fill)
		draw_arc(center, radius, 0.0, TAU, RING_POINTS, UiPalette.WOOD_BORDER, RING_WIDTH)
		if cooling:
			# Sweep from 12 o'clock: the lit arc is the remaining wait.
			draw_arc(
				center, radius - RING_WIDTH * 2.0, -PI / 2.0,
				-PI / 2.0 + TAU * _fraction, RING_POINTS,
				UiPalette.TEXT_ON_DARK, RING_WIDTH
			)
		var font: Font = get_theme_default_font()
		var text_size: Vector2 = font.get_string_size(
			skill_name, HORIZONTAL_ALIGNMENT_CENTER, -1.0, FONT_SIZE
		)
		draw_string(
			font, center + Vector2(-text_size.x / 2.0, text_size.y * 0.35),
			skill_name, HORIZONTAL_ALIGNMENT_CENTER, -1.0, FONT_SIZE,
			UiPalette.WOOD_TEXT
		)
