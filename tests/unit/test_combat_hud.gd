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


## B0-1 belongings row (owner: 전리품도 뭘 먹었는지 보이지도 않고). Asserts the
## contracts, not the pixel sizes — the row has been retuned twice already and
## pinning literals here only breaks the suite on legitimate layout work.
func _belongings_hud(
	weapons: Array, passives: Array, materials: Array
) -> CombatHud:
	var hud := CombatHud.new()
	hud.build_ui()
	hud.set_belongings(weapons, passives, materials)
	return hud


func test_empty_slots_are_drawn_so_the_budget_is_visible() -> bool:
	# One weapon of four held: the other three must still occupy cells, because
	# "what is left" is exactly the fact the pause screen used to hold alone.
	var hud: CombatHud = _belongings_hud([{"id": "sword"}], [], [])
	var run: Control = hud.get_node_or_null("Belongings/Weapons")
	var passed: bool = run != null
	passed = passed and run.get_child_count() == LevelUp.WEAPON_SLOTS
	var passives: Control = hud.get_node_or_null("Belongings/Passives")
	passed = passed and passives != null
	passed = passed and passives.get_child_count() == LevelUp.PASSIVE_SLOTS
	hud.free()
	if not passed:
		push_error("test_combat_hud: belongings row hides the empty slots")
	return passed


func test_field_passives_past_the_budget_are_still_drawn() -> bool:
	# N9-55 lets a walked-to passive exceed the slot budget on purpose. Clamping
	# the row to four would hide something the player crossed the map for.
	var over: Array = []
	for i: int in range(LevelUp.PASSIVE_SLOTS + 2):
		over.append({"id": "attack_damage", "stacks": 1})
	var hud: CombatHud = _belongings_hud([], over, [])
	var run: Control = hud.get_node_or_null("Belongings/Passives")
	var passed: bool = run != null and run.get_child_count() == over.size()
	hud.free()
	if not passed:
		push_error("test_combat_hud: belongings row clamps overflowing passives")
	return passed


func test_materials_appear_and_overflow_collapses() -> bool:
	var few: Array = [{"id": "whetstone", "count": 2}]
	var hud: CombatHud = _belongings_hud([], [], few)
	var run: Control = hud.get_node_or_null("Belongings/Materials")
	var passed: bool = run != null and run.get_child_count() == 1
	hud.free()
	var many: Array = []
	for i: int in range(CombatHud.BELONGINGS_MATERIAL_MAX + 3):
		many.append({"id": "whetstone", "count": 1})
	var over_hud: CombatHud = _belongings_hud([], [], many)
	var over_run: Control = over_hud.get_node_or_null("Belongings/Materials")
	# Capped cells plus exactly one "+N" label, so the slots are never pushed
	# off the right edge no matter how many loot types a run banks.
	passed = passed and over_run != null
	passed = passed and over_run.get_child_count() == CombatHud.BELONGINGS_MATERIAL_MAX + 1
	over_hud.free()
	if not passed:
		push_error("test_combat_hud: material cells or the +N overflow are wrong")
	return passed


func test_no_materials_means_no_material_node() -> bool:
	# An empty container still claims the group separation and shifts the slots.
	var hud: CombatHud = _belongings_hud([{"id": "sword"}], [], [])
	var passed: bool = hud.get_node_or_null("Belongings/Materials") == null
	hud.free()
	if not passed:
		push_error("test_combat_hud: empty material run should not be built")
	return passed


func test_row_never_reaches_under_the_counter_stack() -> bool:
	# The counters are right-anchored; the row is left-anchored and must stop
	# short of them at every width, which is what keeps portrait from colliding.
	var hud: CombatHud = _belongings_hud([{"id": "sword"}], [], [])
	var row: Control = hud.get_node("Belongings")
	var passed: bool = row.mouse_filter == Control.MOUSE_FILTER_IGNORE
	for width: float in [360.0, 540.0, 960.0, 1280.0]:
		hud.size = Vector2(width, 640.0)
		hud._layout_belongings()
		var right: float = width + row.offset_right
		passed = passed and right <= width - CombatHud.COUNTER_STACK_WIDTH
	hud.free()
	if not passed:
		push_error("test_combat_hud: belongings row runs under the counters")
	return passed


func test_badge_downscales_large_art_once() -> bool:
	# N9-55's trap: a 512px export drawn at 22px through NEAREST becomes a solid
	# block. badge() must hand back something at the requested size, and hand
	# back the SAME object next time rather than resizing per frame.
	var icon: Texture2D = UiIcons.weapon_icon("sword")
	if icon == null:
		return true  # no art installed in this checkout; nothing to guard
	var small: Texture2D = UiIcons.badge(icon, 22)
	var passed: bool = small != null and small.get_width() == 22
	passed = passed and UiIcons.badge(icon, 22) == small
	# At or above the source size there is nothing to fix.
	passed = passed and UiIcons.badge(icon, icon.get_width() + 8) == icon
	if not passed:
		push_error("test_combat_hud: badge downscale or its cache is broken")
	return passed


func test_cells_are_the_size_they_declare() -> bool:
	# The kit slot frame is a 9-slice, and a StyleBoxTexture pads its content by
	# the texture margin unless that is cleared — which silently doubled every
	# cell and pushed the run under the counter stack (captures/b0-1). The frame
	# is decoration, so the declared size has to be the real size.
	var hud: CombatHud = _belongings_hud([{"id": "sword"}], [], [])
	var cell: Control = hud.get_node("Belongings/Weapons").get_child(0)
	var passed: bool = cell.get_combined_minimum_size().x <= CombatHud.BELONGINGS_SLOT
	passed = passed and cell.get_combined_minimum_size().y <= CombatHud.BELONGINGS_SLOT
	# And the row clips, so no build size can ever draw past the clamp.
	passed = passed and (hud.get_node("Belongings") as Control).clip_contents
	hud.free()
	if not passed:
		push_error("test_combat_hud: belongings cells exceed their declared size")
	return passed
