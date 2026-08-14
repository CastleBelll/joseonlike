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
	var overlay: Control = hud.get_node("PauseOverlay")
	passed = passed and not overlay.visible
	passed = passed and overlay.process_mode == Node.PROCESS_MODE_ALWAYS
	passed = passed and overlay.find_child("ResumeButton", true, false) is Button
	passed = passed and overlay.find_child("QuitButton", true, false) is Button
	hud.free()
	if not passed:
		push_error("test_combat_hud: HUD construction or updates broken")
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
