extends RefCounted
## Guards the N3-7 combat HUD: timer format, tree-free construction, counter
## updates, xp-bar denominator wiring and the hidden pause overlay.


func test_format_time() -> bool:
	var passed: bool = CombatHud.format_time(0.0) == "0:00"
	passed = passed and CombatHud.format_time(12.4) == "0:12"
	passed = passed and CombatHud.format_time(65.0) == "1:05"
	passed = passed and CombatHud.format_time(725.9) == "12:05"
	passed = passed and CombatHud.format_time(-3.0) == "0:00"
	if not passed:
		push_error("test_combat_hud: format_time broken")
	return passed


func test_build_and_update() -> bool:
	var hud := CombatHud.new()
	hud.build_ui()
	var passed: bool = hud.mouse_filter == Control.MOUSE_FILTER_IGNORE
	var timer: Label = hud.get_node("TimerLabel")
	passed = passed and timer.text == "0:00"
	hud.set_level(3)
	passed = passed and (hud.get_node("LevelLabel") as Label).text == "Lv.3"
	hud.set_kills(35)
	passed = passed and (hud.get_node("Counters/Kills/Value") as Label).text == "35"
	hud.set_gold(1)
	passed = passed and (hud.get_node("Counters/Gold/Value") as Label).text == "1"
	var bar: ProgressBar = hud.get_node("XpBar")
	hud.set_xp(4, 10)
	passed = passed and bar.max_value == 10.0 and bar.value == 4.0
	hud.set_xp(0, 0)  # degenerate curve must not break the bar range
	passed = passed and bar.max_value == 1.0 and bar.value == 0.0
	# N9-111: the overlay rides its own high canvas layer so late-added Hud
	# siblings (minimap, skill discs) can never draw over it; settings moved
	# to the top-right gear and out of the popup.
	var overlay: Control = hud.get_node("OverlayLayer/PauseOverlay")
	passed = passed and not overlay.visible
	passed = passed and overlay.process_mode == Node.PROCESS_MODE_ALWAYS
	passed = passed and (hud.get_node("OverlayLayer") as CanvasLayer).layer > 1
	passed = passed and overlay.find_child("ResumeButton", true, false) is Button
	passed = passed and overlay.find_child("QuitButton", true, false) is Button
	passed = passed and overlay.find_child("SettingsButton", true, false) == null
	passed = passed and hud.get_node("SettingsButton") is Button
	hud.free()
	if not passed:
		push_error("test_combat_hud: HUD construction or updates broken")
	return passed


func test_hp_view_ranges_and_low_flag() -> bool:
	# N6-2 HUD HP view-model: clamped value, ratio, threshold-driven low flag.
	var full: Dictionary = CombatHud.hp_view(100.0, 100.0, 0.25)
	var passed: bool = float(full["ratio"]) == 1.0 and not bool(full["low"])
	var low: Dictionary = CombatHud.hp_view(25.0, 100.0, 0.25)
	passed = passed and bool(low["low"]) and absf(float(low["ratio"]) - 0.25) < 0.001
	var clamped: Dictionary = CombatHud.hp_view(-5.0, 100.0, 0.25)
	passed = passed and float(clamped["value"]) == 0.0
	var degenerate: Dictionary = CombatHud.hp_view(50.0, 0.0, 0.25)
	passed = passed and float(degenerate["max"]) == 1.0 and not bool(degenerate["low"])
	if not passed:
		push_error("test_combat_hud: hp_view broken")
	return passed


func test_hud_hp_bar_tracks_and_warns() -> bool:
	# N6-2: the bar sits under the XP bar, tracks set_hp, turns vermilion and
	# starts the looping vignette when low, and clears both on recovery.
	var hud := CombatHud.new()
	hud.build_ui()
	var bar: ProgressBar = hud.get_node("HpBar")
	var xp_bar: ProgressBar = hud.get_node("XpBar")
	var passed: bool = bar.offset_top > xp_bar.offset_bottom
	hud.set_hp(80.0, 100.0, 0.25, 0.9)
	passed = passed and bar.max_value == 100.0 and bar.value == 80.0
	var fill: StyleBoxFlat = bar.get_theme_stylebox("fill") as StyleBoxFlat
	passed = passed and fill.bg_color == UiPalette.SUCCESS
	var vignette: Control = hud.get_node("DamageVignette")
	passed = passed and not vignette.visible
	hud.set_hp(20.0, 100.0, 0.25, 0.9)
	passed = passed and fill.bg_color == UiPalette.VERMILION and vignette.visible
	hud.set_hp(60.0, 100.0, 0.25, 0.9)
	passed = passed and fill.bg_color == UiPalette.SUCCESS and not vignette.visible
	hud.free()
	if not passed:
		push_error("test_combat_hud: HP bar or low-HP warning broken")
	return passed


func test_run_state_xp_needed() -> bool:
	var curve: Dictionary = RunState.load_curve()
	var expected: int = RunState.xp_to_next(
		RunState.FIRST_LEVEL, float(curve["base_xp"]), float(curve["growth"])
	)
	var state := RunState.new()
	var passed: bool = state.xp_needed() == expected and expected > 0
	if not passed:
		push_error("test_combat_hud: xp_needed does not match the curve")
	return passed


func test_counter_and_corner_icons_use_real_textures() -> bool:
	# N3-13: the skull/coin counters and pause/info corner buttons bind the
	# asset/ui/hud textures — no drawn placeholder glyphs left.
	var hud := CombatHud.new()
	hud.build_ui()
	var passed: bool = true
	for row_name: String in ["Kills", "Gold"]:
		var icon: TextureRect = hud.get_node("Counters/" + row_name).get_child(0) as TextureRect
		passed = passed and icon != null and icon.texture != null
		passed = passed and icon.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
	for button_name: String in ["PauseButton", "InfoButton"]:
		var corner: TextureRect = (
			hud.get_node("CornerButtons/" + button_name).get_child(0) as TextureRect
		)
		passed = passed and corner != null and corner.texture != null
	hud.free()
	if not passed:
		push_error("test_combat_hud: HUD icons are not the asset/ui textures")
	return passed
