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
	# The label carries the NUMBER; whether it also carries the word depends on
	# whether the kit cap already says it (see test_the_level_is_stated_once).
	passed = passed and (hud.get_node("LevelLabel") as Label).text.contains("3")
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
	# Owner (2026-08-28): the top HP strip is gone — the character carries its
	# own bar. set_hp keeps only the screen-level low-health vignette signal.
	var hud := CombatHud.new()
	hud.build_ui()
	var passed: bool = hud.get_node_or_null("HpBar") == null
	var vignette: Control = hud.get_node("DamageVignette")
	hud.set_hp(20.0, 100.0, 0.25, 0.9)
	passed = passed and vignette.visible
	hud.set_hp(80.0, 100.0, 0.25, 0.9)
	passed = passed and not vignette.visible
	hud.free()
	if not passed:
		push_error("test_combat_hud: hp removal broke the vignette signal")
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
	var run: Control = hud.belongings_run("Weapons")
	var passed: bool = run != null
	passed = passed and run.get_child_count() == LevelUp.WEAPON_SLOTS
	var passives: Control = hud.belongings_run("Passives")
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
	var run: Control = hud.belongings_run("Passives")
	# The budget draws as cells; anything past it is counted, never dropped.
	var expected: int = LevelUp.PASSIVE_SLOTS + (1 if over.size() > LevelUp.PASSIVE_SLOTS else 0)
	var passed: bool = run != null and run.get_child_count() == expected
	hud.free()
	if not passed:
		push_error("test_combat_hud: belongings row clamps overflowing passives")
	return passed


func test_materials_appear_and_overflow_collapses() -> bool:
	var few: Array = [{"id": "whetstone", "count": 2}]
	var hud: CombatHud = _belongings_hud([], [], few)
	var run: Control = hud.belongings_run("Materials")
	var passed: bool = run != null and run.get_child_count() == 1
	hud.free()
	var many: Array = []
	for i: int in range(CombatHud.BELONGINGS_MATERIAL_MAX + 3):
		many.append({"id": "whetstone", "count": 1})
	var over_hud: CombatHud = _belongings_hud([], [], many)
	var over_run: Control = over_hud.belongings_run("Materials")
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
	var passed: bool = hud.belongings_run("Materials") == null
	hud.free()
	if not passed:
		push_error("test_combat_hud: empty material run should not be built")
	return passed


func test_row_never_reaches_under_the_counter_stack() -> bool:
	# QA (auto, b735bc0 H2): the first version read offset_right — the INTENT —
	# on an EMPTY row, so it could not see a container widening past its own
	# offsets, which is exactly how the row got under the counters from seven
	# passives on. Two contracts now, because they hold for different reasons.
	var hud := CombatHud.new()
	hud.build_ui()
	var row: Control = hud.get_node("Belongings")
	# 1. Structural, true at ANY width: the row is not a Container, so nothing
	#    inside can widen it, and what overflows is clipped rather than drawn.
	var passed: bool = not (row is Container)
	passed = passed and row.clip_contents
	passed = passed and row.mouse_filter == Control.MOUSE_FILTER_IGNORE
	var materials: Array = []
	for i: int in range(CombatHud.BELONGINGS_MATERIAL_MAX + 2):
		materials.append({"id": "whetstone", "count": 9})
	var weapons: Array = []
	for i: int in range(LevelUp.WEAPON_SLOTS):
		weapons.append({"id": "sword", "grade": "epic"})
	# 2. Numeric, on the widths a device actually resolves to: the worst build
	#    fits inside the clamp, so the clip above never has to save it.
	for width: float in [540.0, 720.0, 960.0, 1280.0]:
		for count: int in [0, 4, 7, 17]:
			var passives: Array = []
			for i: int in range(count):
				passives.append({"id": "attack_damage", "stacks": 9})
			hud.size = Vector2(width, 960.0)
			hud._layout_belongings()
			hud.set_belongings(weapons, passives, materials)
			passed = passed and row.offset_right 				<= -(CombatHud.COUNTER_STACK_WIDTH)
			# Outside a SceneTree nothing lays out, so the meaningful number is
			# the width the content DEMANDS — the very thing that widened the
			# container past its offsets before.
			var demand: float = hud._belongings_lines_box.get_combined_minimum_size().x
			passed = passed and row.offset_left + demand 				<= width - CombatHud.COUNTER_STACK_WIDTH
	hud.free()
	if not passed:
		push_error("test_combat_hud: belongings row runs under the counters")
	return passed


func test_passives_past_the_cap_collapse_instead_of_being_clipped() -> bool:
	# The clip is the hard boundary, but on its own it would swallow pickups the
	# player walked across the map for. The run collapses into a counted "+N".
	var many: Array = []
	for i: int in range(LevelUp.PASSIVE_SLOTS + 3):
		many.append({"id": "attack_damage", "stacks": 1})
	var hud: CombatHud = _belongings_hud([], many, [])
	var run: Control = hud.belongings_run("Passives")
	var passed: bool = run.get_child_count() == LevelUp.PASSIVE_SLOTS + 1
	var tail: Node = run.get_child(run.get_child_count() - 1)
	passed = passed and tail.name == "Overflow"
	passed = passed and (tail as Label).text == "+3"
	hud.free()
	if not passed:
		push_error("test_combat_hud: passive overflow is not collapsed into +N")
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
	var cell: Control = hud.belongings_run("Weapons").get_child(0)
	var passed: bool = cell.get_combined_minimum_size().x <= CombatHud.BELONGINGS_SLOT
	passed = passed and cell.get_combined_minimum_size().y <= CombatHud.BELONGINGS_SLOT
	# And the row clips, so no build size can ever draw past the clamp.
	passed = passed and (hud.get_node("Belongings") as Control).clip_contents
	hud.free()
	if not passed:
		push_error("test_combat_hud: belongings cells exceed their declared size")
	return passed


func test_landscape_splits_the_row_and_portrait_does_not() -> bool:
	# Owner (가로모드일때 무기 가로배치하고 그 밑으로 패시브 배치): landscape puts
	# weapons on one line and passives on the next; portrait keeps one line,
	# where height is the scarce axis rather than width.
	var hud := CombatHud.new()
	hud.build_ui()
	hud.size = Vector2(960.0, 540.0)
	hud._layout_belongings()
	hud.set_belongings([{"id": "sword"}], [{"id": "attack_damage", "stacks": 2}], [])
	var passed: bool = hud.get_node_or_null("Belongings/Lines/Line1") != null
	passed = passed and hud.belongings_run("Weapons").get_parent().name == "Line0"
	passed = passed and hud.belongings_run("Passives").get_parent().name == "Line1"
	# Rotating must re-split without the stage pushing the build again.
	hud.size = Vector2(540.0, 960.0)
	hud._layout_belongings()
	passed = passed and hud.get_node_or_null("Belongings/Lines/Line1") == null
	passed = passed and hud.belongings_run("Weapons") != null
	passed = passed and hud.belongings_run("Passives") != null
	hud.free()
	if not passed:
		push_error("test_combat_hud: belongings row does not follow the orientation")
	return passed


func test_landscape_puts_the_bars_above_the_clock() -> bool:
	# Owner (경험치, 체력이 상단으로 가고). Portrait keeps the clock on top.
	var hud := CombatHud.new()
	hud.build_ui()
	hud.size = Vector2(960.0, 540.0)
	hud._layout_top_band()
	var xp: Control = hud.get_node("XpBar")
	var clock: Control = hud.get_node("TimerLabel")
	var passed: bool = xp.offset_top < clock.offset_top
	hud.size = Vector2(540.0, 960.0)
	hud._layout_top_band()
	passed = passed and clock.offset_top < xp.offset_top
	# Whatever the order, nothing below may start above the bar.
	passed = passed and (hud.get_node("Counters") as Control).offset_top > xp.offset_bottom
	passed = passed and hud._belongings.offset_top > xp.offset_bottom
	hud.free()
	if not passed:
		push_error("test_combat_hud: top band order is wrong for the orientation")
	return passed


func test_pause_uses_the_new_hud_sheet() -> bool:
	# Owner (일시정지 표시는 새로운 UI chrome에 있어 일시정지가 그거 써).
	var fresh: Texture2D = UiIcons.hud_icon("pause")
	var passed: bool = fresh != null
	if ResourceLoader.exists("res://asset/ui/hud/build/pause.png"):
		passed = passed and fresh.resource_path == "res://asset/ui/hud/build/pause.png"
	if not passed:
		push_error("test_combat_hud: pause icon is not the owner's new sheet")
	return passed


## B0-2: the evolution signal. The gate is two facts (level reached, material
## held) and neither used to be visible without pausing.
const MODS: Dictionary = {
	"sharp_sword_mod": {
		"weapon_id": "sword", "loot_id": "whetstone",
		"result_weapon": "sharp_sword", "level_required": 5,
	},
	"ghost_sword_mod": {
		"weapon_id": "sword", "loot_id": "ghost_iron",
		"result_weapon": "ghost_sword", "level_required": 5,
	},
}


func test_evolution_mark_needs_both_the_level_and_the_material() -> bool:
	# Level short: nothing, however much material is in the bag.
	var passed: bool = LevelUp.evolution_mark(
		"sword", MODS, {"whetstone": 3}, {"sword": 4}
	) == LevelUp.EVOLUTION_NONE
	# Level met, material missing: say so, so the player knows what to hunt.
	passed = passed and LevelUp.evolution_mark(
		"sword", MODS, {}, {"sword": 5}
	) == LevelUp.EVOLUTION_WAITING
	# Both: it can be taken right now.
	passed = passed and LevelUp.evolution_mark(
		"sword", MODS, {"whetstone": 1}, {"sword": 5}
	) == LevelUp.EVOLUTION_READY
	# A weapon with no recipe at all never marks.
	passed = passed and LevelUp.evolution_mark(
		"bow", MODS, {"whetstone": 1}, {"bow": 8}
	) == LevelUp.EVOLUTION_NONE
	if not passed:
		push_error("test_combat_hud: evolution_mark gate is wrong")
	return passed


func test_ready_wins_over_waiting_and_taken_paths_stop_counting() -> bool:
	# Two paths, one ready: the slot has room for one mark and "you can act now"
	# is the more useful of the two.
	var passed: bool = LevelUp.evolution_mark(
		"sword", MODS, {"ghost_iron": 1}, {"sword": 5}
	) == LevelUp.EVOLUTION_READY
	# Owning a result retires that path; the other one still counts.
	passed = passed and LevelUp.evolution_mark(
		"sword", MODS, {"ghost_iron": 1}, {"sword": 5, "sharp_sword": 1}
	) == LevelUp.EVOLUTION_READY
	# ...and holding the material for a path already taken must NOT light up:
	# the whetstone is spent knowledge here, not an available card.
	passed = passed and LevelUp.evolution_mark(
		"sword", MODS, {"whetstone": 1}, {"sword": 5, "sharp_sword": 1}
	) == LevelUp.EVOLUTION_WAITING
	# Every path retired: no mark, even holding the materials.
	passed = passed and LevelUp.evolution_mark(
		"sword", MODS, {"whetstone": 1, "ghost_iron": 1},
		{"sword": 5, "sharp_sword": 1, "ghost_sword": 1}
	) == LevelUp.EVOLUTION_NONE
	# Replaced counts as retired too.
	passed = passed and LevelUp.evolution_mark(
		"sword", MODS, {"whetstone": 1}, {"sword": 5}, ["sharp_sword"]
	) == LevelUp.EVOLUTION_WAITING
	if not passed:
		push_error("test_combat_hud: evolution_mark path bookkeeping is wrong")
	return passed


func test_the_slot_draws_the_mark_only_when_there_is_one() -> bool:
	var hud: CombatHud = _belongings_hud([
		{"id": "sword", "evolution": LevelUp.EVOLUTION_READY},
		{"id": "wolto", "evolution": LevelUp.EVOLUTION_NONE},
	], [], [])
	var run: Control = hud.belongings_run("Weapons")
	var passed: bool = run.get_child(0).get_node_or_null("EvolutionMark") != null
	passed = passed and run.get_child(1).get_node_or_null("EvolutionMark") == null
	# An empty slot must never sprout one either.
	passed = passed and run.get_child(3).get_node_or_null("EvolutionMark") == null
	# The mark must not grow the cell past the size the row is clamped around.
	var cell: Control = run.get_child(0)
	passed = passed and cell.get_combined_minimum_size().x <= CombatHud.BELONGINGS_SLOT
	hud.free()
	if not passed:
		push_error("test_combat_hud: evolution mark is drawn on the wrong slots")
	return passed


func test_ready_and_waiting_are_told_apart() -> bool:
	# Two states because "go find the material" and "pick the card" are
	# different instructions; one colour for both would say neither.
	var ready: CombatHud = _belongings_hud(
		[{"id": "sword", "evolution": LevelUp.EVOLUTION_READY}], [], []
	)
	var waiting: CombatHud = _belongings_hud(
		[{"id": "sword", "evolution": LevelUp.EVOLUTION_WAITING}], [], []
	)
	var a: Label = ready.belongings_run("Weapons").get_child(0).get_node("EvolutionMark")
	var b: Label = waiting.belongings_run("Weapons").get_child(0).get_node("EvolutionMark")
	var passed: bool = a.get_theme_color("font_color") != b.get_theme_color("font_color")
	ready.free()
	waiting.free()
	if not passed:
		push_error("test_combat_hud: ready and waiting evolution marks look the same")
	return passed


func test_bar_caps_never_hang_off_the_left_edge() -> bool:
	# QA (auto H3 / visual H5): the cap overhangs the bar by half its width, and
	# in portrait the band is inset by less than that — so it hung off the SCREEN.
	var hud := CombatHud.new()
	hud.build_ui()
	var passed: bool = true
	for width: float in [540.0, 720.0, 960.0, 1280.0]:
		hud.size = Vector2(width, 960.0)
		hud._layout_bar_bands()
		for bar_name: String in ["XpBar"]:
			var bar: Control = hud.get_node(bar_name)
			var cap: Control = bar.get_node_or_null("Cap")
			if cap == null:
				continue  # kit art absent in this checkout
			passed = passed and bar.offset_left + cap.position.x >= 0.0
	hud.free()
	if not passed:
		push_error("test_combat_hud: a bar cap hangs off the left edge")
	return passed


func test_the_hp_bar_changes_before_the_emergency() -> bool:
	# QA (visual, b735bc0 H8): at 28% the bar was still full-health green, so the
	# first warning a player got was already the last one.
	var full: Color = CombatHud.hp_fill_color(1.0, false)
	var half: Color = CombatHud.hp_fill_color(0.5, false)
	var nearly: Color = CombatHud.hp_fill_color(0.28, false)
	var critical: Color = CombatHud.hp_fill_color(0.2, true)
	var passed: bool = full == UiPalette.SUCCESS
	# Anything under the warning band has to differ from full health...
	passed = passed and half != full
	passed = passed and nearly != full
	# ...and keep moving as it falls, rather than snapping once.
	passed = passed and nearly != half
	# The threshold still owns the emergency colour.
	passed = passed and critical == UiPalette.VERMILION
	if not passed:
		push_error("test_combat_hud: hp bar does not warn before the threshold")
	return passed


func test_the_boss_bar_joins_the_stack_instead_of_covering_it() -> bool:
	# QA (visual, b735bc0 H7): the boss bar sat at a fixed y that B0-1b moved the
	# landscape bars on top of, so a boss fight covered the Lv badge — and it was
	# the same vermilion as the player's low-health bar, so neither said whose
	# health it was.
	var hud := CombatHud.new()
	hud.build_ui()
	hud.size = Vector2(960.0, 540.0)
	hud._layout_top_band()
	var boss: Control = hud.get_node("BossBar")
	var xp: Control = hud.get_node("XpBar")
	# Hidden: it costs the band nothing.
	var quiet_top: float = xp.offset_top
	var passed: bool = not boss.visible
	hud.show_boss_bar()
	# Showing: it takes the top and pushes the rest down, never overlapping.
	passed = passed and boss.offset_top < xp.offset_top
	passed = passed and boss.offset_bottom <= xp.offset_top
	passed = passed and xp.offset_top > quiet_top
	# And it is not the player's colour.
	var fill: StyleBox = boss.get_theme_stylebox("fill")
	if fill is StyleBoxFlat:
		passed = passed and (fill as StyleBoxFlat).bg_color != UiPalette.VERMILION
	hud.free()
	if not passed:
		push_error("test_combat_hud: the boss bar still fights the player's band")
	return passed


func test_the_level_is_stated_once() -> bool:
	# QA (visual, b735bc0 M7): the kit's xp cap has "Lv." drawn into it and the
	# label under it repeated the word — two things saying level, and the one
	# carrying the word had no number in it.
	var hud := CombatHud.new()
	hud.build_ui()
	hud.set_level(12)
	var label: Label = hud.get_node("LevelLabel")
	var passed: bool = label.text.contains("12")
	if hud.get_node("XpBar").get_node_or_null("Cap") != null or hud._xp_bar_hd:
		# The cap (or the HD track's baked Lv. diamond) says the word, so the
		# label must not say it again.
		passed = passed and not label.text.contains("Lv")
	else:
		# No art, no word anywhere else — the label has to carry it.
		passed = passed and label.text.contains("Lv")
	hud.free()
	if not passed:
		push_error("test_combat_hud: the level readout says its own name twice")
	return passed
